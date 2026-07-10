#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import math
import shutil
import subprocess
import tempfile
import wave
from dataclasses import dataclass
from pathlib import Path

import imageio_ffmpeg
import numpy as np


ROOT = Path(__file__).resolve().parents[2]
SR = 48_000
BPM = 72
BEATS_PER_BAR = 4
BARS = 16
BEAT_SAMPLES = int(SR * 60 / BPM)
BAR_SAMPLES = BEAT_SAMPLES * BEATS_PER_BAR
LOOP_SAMPLES = BAR_SAMPLES * BARS
HEADROOM = 0.68

CONTEXT_DIR = ROOT / "audio/music/rendered/contexts"
STEM_DIR = ROOT / "audio/music/rendered/stems"
STINGER_DIR = ROOT / "audio/music/rendered/stingers"
SOURCE_DIR = ROOT / "audio/music/source_m8str0"
PATCH_PATH = SOURCE_DIR / "coheronia_adaptive_suite.m8patch"


@dataclass(frozen=True)
class Event:
    beat: float
    dur: float
    note: str
    amp: float
    voice: str
    pan: float = 0.0
    drift: float = 0.0


NOTE_BASE = {
    "C": -9,
    "C#": -8,
    "D": -7,
    "D#": -6,
    "E": -5,
    "F": -4,
    "F#": -3,
    "G": -2,
    "G#": -1,
    "A": 0,
    "A#": 1,
    "B": 2,
}


def note_freq(name: str) -> float:
    pitch = name[:-1]
    octave = int(name[-1])
    semitone = NOTE_BASE[pitch] + (octave - 4) * 12
    return 440.0 * (2 ** (semitone / 12.0))


def voice_wave(freq: float, samples: int, voice: str, drift: float = 0.0) -> np.ndarray:
    t = np.arange(samples, dtype=np.float32) / SR
    if drift:
        phase = 2.0 * math.pi * (freq * t + drift * np.sin(2.0 * math.pi * 0.18 * t))
    else:
        phase = 2.0 * math.pi * freq * t
    sine = np.sin(phase)
    if voice in {"plucked", "wood", "stone", "skin", "metal"}:
        h2 = np.sin(phase * 2.01) * 0.25
        h3 = np.sin(phase * 3.03) * 0.12
        return (sine + h2 + h3).astype(np.float32)
    if voice in {"bowed", "reed", "strain"}:
        return (sine * 0.78 + np.sin(phase * 2.0) * 0.16 + np.sin(phase * 3.0) * 0.06).astype(np.float32)
    if voice == "breath":
        rng = np.random.default_rng(int(freq * 1000) % 65535)
        noise = rng.normal(0, 0.16, samples).astype(np.float32)
        return (sine * 0.55 + noise).astype(np.float32)
    return sine.astype(np.float32)


def envelope(samples: int, voice: str) -> np.ndarray:
    if samples <= 1:
        return np.ones(samples, dtype=np.float32)
    if voice in {"wood", "stone", "skin", "metal"}:
        attack = max(8, int(0.004 * SR))
        decay = np.exp(-np.linspace(0.0, 6.4, samples, dtype=np.float32))
        decay[:attack] *= np.linspace(0.0, 1.0, attack, dtype=np.float32)
        return decay
    if voice == "plucked":
        attack = max(8, int(0.01 * SR))
        decay = np.exp(-np.linspace(0.0, 3.2, samples, dtype=np.float32))
        decay[:attack] *= np.linspace(0.0, 1.0, attack, dtype=np.float32)
        return decay
    attack = max(16, int(0.04 * SR))
    release = max(16, int(0.08 * SR))
    env = np.ones(samples, dtype=np.float32)
    env[:attack] = np.linspace(0.0, 1.0, attack, dtype=np.float32)
    env[-release:] *= np.linspace(1.0, 0.0, release, dtype=np.float32)
    return env


def add_event(buf: np.ndarray, event: Event, loop: bool = True) -> None:
    start = int(round(event.beat * BEAT_SAMPLES))
    samples = max(1, int(round(event.dur * BEAT_SAMPLES)))
    wave_data = voice_wave(note_freq(event.note), samples, event.voice, event.drift)
    wave_data *= envelope(samples, event.voice) * event.amp
    left = wave_data * math.sqrt((1.0 - event.pan) * 0.5)
    right = wave_data * math.sqrt((1.0 + event.pan) * 0.5)
    stereo = np.stack([left, right], axis=1)
    if not loop:
        end = min(buf.shape[0], start + samples)
        buf[start:end] += stereo[:end - start]
        return
    for i in range(samples):
        buf[(start + i) % buf.shape[0]] += stereo[i]


def add_noise_hit(buf: np.ndarray, beat: float, dur: float, amp: float, pan: float, seed: int,
                  color: str = "wood") -> None:
    start = int(round(beat * BEAT_SAMPLES))
    samples = max(1, int(round(dur * BEAT_SAMPLES)))
    rng = np.random.default_rng(seed)
    noise = rng.normal(0.0, 1.0, samples).astype(np.float32)
    if color == "skin":
        carrier = np.sin(np.linspace(0, math.pi * 2 * 74 * dur * 60 / BPM, samples, dtype=np.float32))
        noise = noise * 0.45 + carrier * 0.55
    elif color == "stone":
        noise *= np.sin(np.linspace(0, math.pi * 2 * 9, samples, dtype=np.float32)) * 0.35 + 0.65
    env = np.exp(-np.linspace(0.0, 7.0, samples, dtype=np.float32))
    attack = min(samples, max(8, int(0.003 * SR)))
    env[:attack] *= np.linspace(0.0, 1.0, attack, dtype=np.float32)
    hit = noise * env * amp
    left = hit * math.sqrt((1.0 - pan) * 0.5)
    right = hit * math.sqrt((1.0 + pan) * 0.5)
    for i in range(samples):
        buf[(start + i) % buf.shape[0], 0] += left[i]
        buf[(start + i) % buf.shape[0], 1] += right[i]


def new_loop() -> np.ndarray:
    return np.zeros((LOOP_SAMPLES, 2), dtype=np.float32)


def safe_scale(buf: np.ndarray) -> np.ndarray:
    peak = float(np.max(np.abs(buf)))
    if peak > HEADROOM:
        buf = buf * (HEADROOM / peak)
    return buf


def foundation_events(variant: str = "base") -> list[Event]:
    notes = [
        (0, "D2", "A2", "E3"),
        (16, "D2", "A2", "C3"),
        (32, "D2", "G2", "A2"),
        (48, "D2", "A2", "E3"),
    ]
    amp = 0.105 if variant != "night" else 0.14
    out: list[Event] = []
    for beat, a, b, c in notes:
        out.append(Event(beat, 16, a, amp, "bowed", -0.18))
        out.append(Event(beat + 0.02, 16, b, amp * 0.62, "bowed", 0.18))
        out.append(Event(beat + 4, 11.5, c, amp * 0.38, "breath", 0.04))
    return out


HEARTH_MOTIF = [
    (0.5, 1.0, "D4"),
    (1.5, 0.5, "E4"),
    (2.0, 1.5, "D4"),
    (3.5, 0.75, "G4"),
    (4.5, 1.0, "E4"),
]


def hearth_events(mode: str = "day") -> list[Event]:
    out: list[Event] = []
    shift = -12 if mode in {"night", "underground"} else 0
    amp = 0.14 if mode == "day" else 0.09
    windows = [0, 16, 32, 48]
    lengths = [5, 3, 4, 5]
    for window, length in zip(windows, lengths):
        for i, (beat, dur, note) in enumerate(HEARTH_MOTIF[:length]):
            if mode == "crisis" and window == 32 and i in {1, 4}:
                continue
            n = transpose(note, shift)
            start = window + beat + (0.5 if mode == "underground" and i % 2 else 0.0)
            v = "plucked" if mode in {"day", "crisis"} else "bowed"
            out.append(Event(start, dur, n, amp * (0.9 if window == 32 else 1.0), v, -0.26 + i * 0.13))
    return out


def transpose(note: str, semis: int) -> str:
    names = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
    pitch = note[:-1]
    octave = int(note[-1])
    idx = names.index(pitch) + octave * 12 + semis
    return names[idx % 12] + str(idx // 12)


def motion_pattern(buf: np.ndarray, mode: str = "day") -> None:
    for bar in range(BARS):
        phrase = bar // 4
        if mode == "night" and bar % 2 == 1:
            continue
        if mode == "underground":
            beats = [bar * 4 + 0.0, bar * 4 + 1.5, bar * 4 + 2.5]
            if bar in {0, 4, 8, 12}:
                beats = [bar * 4]
            for j, b in enumerate(beats):
                add_noise_hit(buf, b, 0.18, 0.085, (-0.35, 0.22, -0.1)[j % 3], 1000 + bar * 9 + j, "stone")
            continue
        if mode == "crisis":
            beats = [bar * 4 + 0.5, bar * 4 + 1.0, bar * 4 + 2.5, bar * 4 + 3.0]
            if bar in {0, 4, 8, 12}:
                beats = [bar * 4 + 1.0]
            for j, b in enumerate(beats):
                if phrase == 2 and j == 1:
                    continue
                add_noise_hit(buf, b, 0.16, 0.115, 0.18 if j % 2 else -0.18, 2000 + bar * 11 + j, "skin")
            continue
        beats = [bar * 4 + 1.0, bar * 4 + 2.0, bar * 4 + 3.0]
        if bar in {0, 4, 8, 12}:
            beats = [bar * 4 + 2.0]
        for j, b in enumerate(beats):
            add_noise_hit(buf, b, 0.12, 0.065, -0.22 + 0.22 * (j % 3), 3000 + bar * 7 + j, "wood")


def pressure_events() -> list[Event]:
    out: list[Event] = []
    for bar in range(BARS):
        if bar in {0, 4, 8, 12}:
            out.append(Event(bar * 4 + 1.0, 0.5, "A2", 0.08, "reed", -0.08))
            continue
        out.append(Event(bar * 4 + 0.5, 0.5, "D3", 0.08, "reed", -0.1))
        out.append(Event(bar * 4 + 2.0, 0.5, "E3", 0.07, "reed", 0.1))
        if 8 <= bar <= 10:
            out.append(Event(bar * 4 + 2.5, 0.75, "F3", 0.058, "strain", -0.16, 0.005))
            out.append(Event(bar * 4 + 3.0, 0.5, "B3", 0.045, "strain", 0.16, -0.004))
    return out


def attunement_events() -> list[Event]:
    return [
        Event(14.5, 1.0, "A5", 0.072, "metal", 0.25),
        Event(30.5, 1.1, "G5", 0.066, "metal", -0.2),
        Event(46.5, 0.8, "B5", 0.074, "metal", 0.18),
        Event(53.5, 1.0, "A5", 0.066, "metal", -0.08),
        Event(58.5, 1.1, "E5", 0.062, "metal", 0.12),
    ]


def fracture_events() -> list[Event]:
    return [
        Event(6.0, 0.45, "E3", 0.04, "strain", -0.25, 0.009),
        Event(22.0, 0.5, "C4", 0.047, "strain", 0.2, -0.006),
        Event(36.5, 0.35, "F3", 0.05, "strain", -0.12, 0.012),
        Event(42.5, 0.4, "B3", 0.042, "strain", 0.18, -0.008),
        Event(55.0, 0.35, "G3", 0.036, "strain", -0.05, 0.006),
    ]


def render_stem(name: str) -> np.ndarray:
    buf = new_loop()
    if name == "foundation":
        for ev in foundation_events():
            add_event(buf, ev)
    elif name == "hearth":
        for ev in hearth_events("day"):
            add_event(buf, ev)
    elif name == "motion":
        motion_pattern(buf, "day")
    elif name == "pressure":
        for ev in pressure_events():
            add_event(buf, ev)
        motion_pattern(buf, "crisis")
    elif name == "attunement":
        for ev in attunement_events():
            add_event(buf, ev)
    elif name == "fracture":
        for ev in fracture_events():
            add_event(buf, ev)
        for b in [7.5, 23.5, 37.5, 43.5, 56.0]:
            add_noise_hit(buf, b, 0.18, 0.035, 0.0, int(b * 100), "stone")
    else:
        raise ValueError(name)
    return safe_scale(buf)


def render_context(name: str) -> np.ndarray:
    buf = new_loop()
    mode = name
    for ev in foundation_events("night" if mode == "surface_night" else "base"):
        add_event(buf, ev)
    if mode == "surface_day":
        for ev in hearth_events("day"):
            add_event(buf, ev)
        motion_pattern(buf, "day")
        for ev in attunement_events()[0:2]:
            add_event(buf, Event(ev.beat, ev.dur, ev.note, ev.amp * 0.45, ev.voice, ev.pan))
    elif mode == "surface_night":
        for ev in hearth_events("night")[::2]:
            add_event(buf, ev)
        motion_pattern(buf, "night")
        for ev in attunement_events():
            add_event(buf, Event(ev.beat, ev.dur * 1.2, ev.note, ev.amp * 0.58, "metal", ev.pan))
    elif mode == "underground":
        for ev in foundation_events("base"):
            add_event(buf, Event(ev.beat, ev.dur, transpose(ev.note, -12), ev.amp * 0.72, ev.voice, ev.pan))
        for ev in hearth_events("underground")[1::2]:
            add_event(buf, Event(ev.beat + 1.0, ev.dur * 0.8, ev.note, ev.amp * 0.75, "stone", ev.pan))
        motion_pattern(buf, "underground")
    elif mode == "crisis":
        for ev in hearth_events("crisis"):
            add_event(buf, Event(ev.beat, ev.dur * 0.72, ev.note, ev.amp * 0.65, ev.voice, ev.pan))
        for ev in pressure_events():
            add_event(buf, ev)
        motion_pattern(buf, "crisis")
        for ev in fracture_events():
            add_event(buf, Event(ev.beat, ev.dur, ev.note, ev.amp * 0.75, ev.voice, ev.pan, ev.drift))
    else:
        raise ValueError(name)
    return safe_scale(buf)


def render_stinger(name: str) -> np.ndarray:
    durations = {
        "dawn": 5.6,
        "nightfall": 5.1,
        "raid_warning": 3.8,
        "attunement": 6.4,
        "base_advance": 6.0,
    }
    samples = int(round(durations[name] * SR))
    buf = np.zeros((samples, 2), dtype=np.float32)
    if name == "dawn":
        events = [Event(0.1, 0.6, "D4", 0.18, "plucked"), Event(0.75, 0.7, "E4", 0.14, "plucked"),
                  Event(1.4, 2.0, "A3", 0.12, "bowed"), Event(3.2, 1.0, "A5", 0.08, "metal", 0.18)]
    elif name == "nightfall":
        events = [Event(0.1, 1.5, "D3", 0.14, "bowed"), Event(1.9, 1.2, "A2", 0.13, "breath"),
                  Event(3.1, 0.7, "E3", 0.08, "plucked", -0.16)]
    elif name == "raid_warning":
        events = [Event(0.0, 0.25, "D3", 0.12, "skin"), Event(1.0, 0.2, "A2", 0.11, "skin"),
                  Event(1.5, 0.2, "A2", 0.10, "skin"), Event(2.0, 0.45, "F3", 0.08, "strain")]
    elif name == "attunement":
        events = [Event(0.4, 0.8, "D5", 0.075, "metal", -0.2), Event(1.9, 0.9, "E5", 0.07, "metal", 0.15),
                  Event(3.4, 0.9, "G5", 0.074, "metal", -0.05), Event(4.9, 1.1, "A5", 0.07, "metal", 0.22)]
    else:
        events = [Event(0.1, 0.55, "D4", 0.16, "plucked"), Event(0.7, 0.45, "E4", 0.12, "plucked"),
                  Event(1.15, 0.95, "D4", 0.13, "plucked"), Event(2.2, 0.6, "G4", 0.12, "plucked"),
                  Event(3.1, 1.1, "A3", 0.13, "bowed"), Event(4.6, 0.28, "D3", 0.11, "skin")]
    for ev in events:
        add_event(buf, ev, loop=False)
    if name in {"raid_warning", "base_advance"}:
        add_noise_hit(buf, 0.0, 0.14, 0.08, -0.15, 8801, "skin")
        add_noise_hit(buf, 1.5, 0.14, 0.075, 0.18, 8802, "wood")
    return safe_scale(buf)


def write_wav(path: Path, data: np.ndarray) -> None:
    pcm = np.clip(data, -1.0, 1.0)
    pcm16 = (pcm * 32767.0).astype("<i2")
    with wave.open(str(path), "wb") as wf:
        wf.setnchannels(2)
        wf.setsampwidth(2)
        wf.setframerate(SR)
        wf.writeframes(pcm16.tobytes())


def encode_ogg(wav_path: Path, ogg_path: Path, ffmpeg: str) -> None:
    ogg_path.parent.mkdir(parents=True, exist_ok=True)
    cmd = [
        ffmpeg,
        "-y",
        "-hide_banner",
        "-loglevel",
        "error",
        "-i",
        str(wav_path),
        "-map_metadata",
        "-1",
        "-c:a",
        "libvorbis",
        "-q:a",
        "5",
        str(ogg_path),
    ]
    subprocess.run(cmd, check=True)


def write_patch() -> None:
    SOURCE_DIR.mkdir(parents=True, exist_ok=True)
    patch = {
        "schema": "m8str0-placeholder-v1",
        "title": "Coheronia Adaptive Suite",
        "status": "deterministic Codex placeholder render; replace with M8str0-authored performance after operator listening approval",
        "bpm": BPM,
        "meter": "4/4",
        "bars": BARS,
        "sample_rate_hz": SR,
        "loop_samples": LOOP_SAMPLES,
        "key_family": "D Dorian / D-centered pentatonic",
        "motif_contour": ["grounded D", "small lift", "held support", "controlled fourth-like span", "open return"],
        "checkpoints": {"bar_1": 0, "bar_5": 640000, "bar_9": 1280000, "bar_13": 1920000, "return": 2560000},
        "contexts": ["surface_day", "surface_night", "underground", "crisis"],
        "stems": ["foundation", "hearth", "motion", "pressure", "attunement", "fracture"],
        "stingers": ["dawn", "nightfall", "raid_warning", "attunement", "base_advance"],
        "operator_approval": "pending by-ear review; mechanical validation is not final approval",
    }
    PATCH_PATH.write_text(json.dumps(patch, indent=2) + "\n", encoding="utf-8")


def main() -> int:
    parser = argparse.ArgumentParser(description="Render Coheronia adaptive-score placeholder assets.")
    parser.add_argument("--keep-wav", action="store_true", help="Keep temporary WAV masters under .tmp_music_render.")
    args = parser.parse_args()

    ffmpeg = imageio_ffmpeg.get_ffmpeg_exe()
    context_names = ["surface_day", "surface_night", "underground", "crisis"]
    stem_names = ["foundation", "hearth", "motion", "pressure", "attunement", "fracture"]
    stinger_names = ["dawn", "nightfall", "raid_warning", "attunement", "base_advance"]

    tmp_root = ROOT / ".tmp_music_render" if args.keep_wav else Path(tempfile.mkdtemp(prefix="coheronia_music_"))
    tmp_root.mkdir(parents=True, exist_ok=True)
    try:
        for name in context_names:
            wav = tmp_root / f"coheronia_{name}.wav"
            write_wav(wav, render_context(name))
            encode_ogg(wav, CONTEXT_DIR / f"coheronia_{name}.ogg", ffmpeg)
            print(f"rendered context {name}")
        for name in stem_names:
            wav = tmp_root / f"stem_{name}.wav"
            write_wav(wav, render_stem(name))
            encode_ogg(wav, STEM_DIR / f"stem_{name}.ogg", ffmpeg)
            print(f"rendered stem {name}")
        for name in stinger_names:
            wav = tmp_root / f"stinger_{name}.wav"
            write_wav(wav, render_stinger(name))
            encode_ogg(wav, STINGER_DIR / f"stinger_{name}.ogg", ffmpeg)
            print(f"rendered stinger {name}")
        write_patch()
        print(f"wrote {PATCH_PATH.relative_to(ROOT)}")
    finally:
        if not args.keep_wav:
            shutil.rmtree(tmp_root, ignore_errors=True)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
