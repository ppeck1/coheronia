#!/usr/bin/env python3
"""Genesis-style FM/PSG music renderer for Coheronia's adaptive score.

Emulates the *character* of the Sega Genesis sound chips in numpy:
  * YM2612-style FM voices  - a carrier sine phase-modulated by operator(s),
    with a per-note modulation-index envelope (bright attack decaying to a
    purer tone) and an ADSR amplitude envelope. Gives the round basses, glassy
    bells, warm e-piano/pads and plucks the Genesis is known for.
  * SN76489-style PSG voices - hard square waves (with duty) for chiptune arps
    and sparkle, plus a noise channel for soft hats/shakers.

Everything renders to the exact grid the adaptive director + verifier require
(48 kHz stereo, 72 BPM, 4/4, 16 bars = 53.333 s seamless loops). Note release
tails wrap around the loop point so the seam stays continuous.

This is content tooling: it writes the OGG loops the manifest already points at;
it changes nothing about the director, manifest, or verify contract. Prototype
usage renders a single track to a scratch path for audition:

    python scripts/audio/gen_music.py --only surface_day --out build/proto.ogg
"""
from __future__ import annotations

import argparse
import subprocess
from pathlib import Path

import imageio_ffmpeg
import numpy as np

ROOT = Path(__file__).resolve().parents[2]

SR = 48_000
BPM = 72
BEATS_PER_BAR = 4
BARS = 16
BEAT = SR * 60 // BPM          # 40_000 samples per beat
BAR = BEAT * BEATS_PER_BAR     # 160_000
LOOP = BAR * BARS              # 2_560_000 samples (53.333 s)

_NOTE = {"C": 0, "C#": 1, "D": 2, "D#": 3, "E": 4, "F": 5,
         "F#": 6, "G": 7, "G#": 8, "A": 9, "A#": 10, "B": 11}


def midi(name: str) -> int:
    """'A3' -> MIDI number (A4 = 69)."""
    octave = int(name[-1])
    return 12 * (octave + 1) + _NOTE[name[:-1]]


def hz(m: float) -> float:
    return 440.0 * 2.0 ** ((m - 69) / 12.0)


def triad(root: str, quality: str) -> list[int]:
    r = midi(root)
    thirds = {"maj": 4, "min": 3, "sus4": 5, "sus2": 2}
    return [r, r + thirds[quality], r + 7]


# ----------------------------------------------------------------------------
# envelopes
# ----------------------------------------------------------------------------

def adsr(dur: int, a: float, d: float, s: float, r: float) -> np.ndarray:
    """ADSR amplitude envelope. `dur` = note-on samples; total length adds the
    release tail. Times in seconds."""
    a_n, d_n, r_n = max(1, int(a * SR)), max(1, int(d * SR)), max(1, int(r * SR))
    sus_n = max(0, dur - a_n - d_n)
    seg = np.concatenate([
        np.linspace(0.0, 1.0, a_n, endpoint=False),
        np.linspace(1.0, s, d_n, endpoint=False),
        np.full(sus_n, s),
        np.linspace(s, 0.0, r_n),
    ])
    target = dur + r_n
    if seg.size < target:
        seg = np.concatenate([seg, np.zeros(target - seg.size)])
    return seg[:target]


def _idx_env(n: int, peak: float, end: float, decay: float) -> np.ndarray:
    t = np.arange(n) / SR
    return end + (peak - end) * np.exp(-t * decay)


# ----------------------------------------------------------------------------
# voices  (each returns a mono float array: dur note-on + release tail)
# ----------------------------------------------------------------------------

def fm_bell(freq: float, dur: int, *, ratio=2.0, peak=3.2, end=0.4, decay=6.0,
            amp=1.0, a=0.005, d=0.9, s=0.35, r=0.5) -> np.ndarray:
    env = adsr(dur, a, d, s, r)
    t = np.arange(env.size) / SR
    idx = _idx_env(env.size, peak, end, decay)
    mod = idx * np.sin(2 * np.pi * freq * ratio * t)
    return np.sin(2 * np.pi * freq * t + mod) * env * amp


def fm_pad(freq: float, dur: int, *, amp=1.0, detune=7.0, ratio=2.0, index=0.6,
           a=0.18, d=0.4, s=0.85, r=0.6) -> np.ndarray:
    env = adsr(dur, a, d, s, r)
    t = np.arange(env.size) / SR
    out = np.zeros(env.size)
    for cents in (-detune, 0.0, detune):
        f = freq * 2.0 ** (cents / 1200.0)
        mod = index * np.sin(2 * np.pi * f * ratio * t)
        out += np.sin(2 * np.pi * f * t + mod)
    return out / 3.0 * env * amp


def fm_bass(freq: float, dur: int, *, amp=1.0, ratio=1.0, peak=1.4, end=0.25,
            decay=9.0, a=0.004, d=0.25, s=0.7, r=0.16) -> np.ndarray:
    env = adsr(dur, a, d, s, r)
    t = np.arange(env.size) / SR
    idx = _idx_env(env.size, peak, end, decay)
    mod = idx * np.sin(2 * np.pi * freq * ratio * t)
    # a touch of sub sine for weight
    sig = np.sin(2 * np.pi * freq * t + mod) + 0.4 * np.sin(2 * np.pi * freq * t)
    return sig / 1.4 * env * amp


def psg_square(freq: float, dur: int, *, amp=1.0, duty=0.5, a=0.003, d=0.05,
               s=0.8, r=0.05) -> np.ndarray:
    env = adsr(dur, a, d, s, r)
    t = np.arange(env.size) / SR
    phase = (freq * t) % 1.0
    sq = np.where(phase < duty, 1.0, -1.0)
    return sq * env * amp


def psg_noise(dur: int, *, amp=1.0, a=0.001, d=0.04, s=0.0, r=0.03,
              tone=0.0) -> np.ndarray:
    env = adsr(dur, a, d, s, r)
    rng = np.random.default_rng(1234)
    n = rng.uniform(-1.0, 1.0, env.size)
    if tone > 0.0:  # crude low-pass toward a softer shaker
        b = np.exp(-tone)
        for i in range(1, n.size):
            n[i] = b * n[i - 1] + (1 - b) * n[i]
    return n * env * amp


def kick(freq0=110.0, freq1=45.0, dur=0.16, amp=1.0) -> np.ndarray:
    n = int(dur * SR)
    t = np.arange(n) / SR
    f = freq1 + (freq0 - freq1) * np.exp(-t * 28.0)
    ph = 2 * np.pi * np.cumsum(f) / SR
    env = np.exp(-t * 9.0)
    return np.sin(ph) * env * amp


# ----------------------------------------------------------------------------
# arrangement helpers
# ----------------------------------------------------------------------------

def add_wrap(buf: np.ndarray, start: int, sig: np.ndarray) -> None:
    """Add `sig` into the loop buffer at `start`, wrapping any tail past the end
    back to the beginning so the loop point stays seamless."""
    length = buf.size
    start %= length
    end = start + sig.size
    if end <= length:
        buf[start:end] += sig
        return
    first = length - start
    buf[start:] += sig[:first]
    rem = sig[first:]
    if rem.size <= length:
        buf[:rem.size] += rem
    else:
        buf += rem[:length]


def beats(n: float) -> int:
    return int(round(n * BEAT))


class Track:
    """A mono layer plus a stereo pan, rendered into the loop buffer."""

    def __init__(self, pan: float = 0.0) -> None:
        self.buf = np.zeros(LOOP, dtype=np.float64)
        self.pan = pan  # -1 left .. +1 right

    def note(self, at_beat: float, sig: np.ndarray) -> None:
        add_wrap(self.buf, beats(at_beat), sig)

    def stereo(self) -> np.ndarray:
        ang = (self.pan * 0.5 + 0.5) * (np.pi / 2)
        return np.stack([self.buf * np.cos(ang), self.buf * np.sin(ang)], axis=1)


# ----------------------------------------------------------------------------
# surface_day  (warm RPG / pastoral - Shining Force / Phantasy Star settlement)
# ----------------------------------------------------------------------------

def surface_day() -> np.ndarray:
    # one chord per bar (16 bars); ends on V (E) so the loop resolves back to A.
    prog = [
        ("A3", "maj"), ("E3", "maj"), ("F#3", "min"), ("D3", "maj"),
        ("A3", "maj"), ("E3", "maj"), ("D3", "maj"), ("E3", "maj"),
        ("F#3", "min"), ("D3", "maj"), ("A3", "maj"), ("E3", "maj"),
        ("F#3", "min"), ("D3", "maj"), ("E3", "sus4"), ("E3", "maj"),
    ]

    bass = Track(pan=0.0)
    pad = Track(pan=0.0)
    bell = Track(pan=0.18)
    arp = Track(pan=-0.32)
    perc = Track(pan=0.0)
    shaker = Track(pan=-0.15)

    for bar, (root, qual) in enumerate(prog):
        b0 = bar * BEATS_PER_BAR
        chord = triad(root, qual)
        root_m = midi(root)

        # --- warm sustained pad: the triad, held the whole bar ---
        for m in chord:
            pad.note(b0, fm_pad(hz(m + 12), beats(4.0), amp=0.30))

        # --- round bass: root on 1, fifth walk on 3 ---
        bass.note(b0, fm_bass(hz(root_m - 12), beats(2.0), amp=0.55))
        bass.note(b0 + 2, fm_bass(hz(root_m - 12 + 7), beats(2.0), amp=0.50))

        # --- gentle 8th-note arpeggio through the chord tones ---
        arp_tones = [chord[0] + 12, chord[1] + 12, chord[2] + 12, chord[1] + 12]
        for i in range(8):
            m = arp_tones[i % len(arp_tones)] + (12 if i >= 4 else 0)
            arp.note(b0 + i * 0.5,
                     psg_square(hz(m), beats(0.42), amp=0.10, duty=0.35))

        # --- light percussion: soft kick on 1 & 3, shaker on off-8ths ---
        perc.note(b0, kick(amp=0.5))
        perc.note(b0 + 2, kick(amp=0.42))
        for i in range(8):
            if i % 2 == 1:
                shaker.note(b0 + i * 0.5,
                            psg_noise(beats(0.2), amp=0.06, tone=0.35))

    # --- bell melody: a warm, singable A-major line over the 16 bars ---
    # (start_beat, duration_beats, 'note' or None for rest)
    mel = [
        (0, 1.5, "E4"), (1.5, 0.5, "F#4"), (2, 2, "A4"),
        (4, 1, "E4"), (5, 1, "G#4"), (6, 2, "B4"),
        (8, 2, "A4"), (10, 1, "F#4"), (11, 1, "E4"),
        (12, 2, "F#4"), (14, 1, "D4"), (15, 1, "E4"),
        (16, 1.5, "C#5"), (17.5, 0.5, "B4"), (18, 2, "A4"),
        (20, 2, "B4"), (22, 1, "G#4"), (23, 1, "E4"),
        (24, 1, "F#4"), (25, 1, "A4"), (26, 2, "D5"),
        (28, 1, "C#5"), (29, 1, "B4"), (30, 2, "G#4"),
        # phrase B - lifts a little, then a turnaround that lands on V (E)
        (32, 2, "A4"), (34, 1, "C#5"), (35, 1, "D5"),
        (36, 2, "C#5"), (38, 1, "A4"), (39, 1, "B4"),
        (40, 3, "A4"), (43, 1, "F#4"),
        (44, 2, "E4"), (46, 2, "F#4"),
        (48, 1, "A4"), (49, 1, "C#5"), (50, 2, "B4"),
        (52, 2, "A4"), (54, 1, "F#4"), (55, 1, "E4"),
        (56, 2, "F#4"), (58, 1, "A4"), (59, 1, "G#4"),
        (60, 1, "F#4"), (61, 1, "G#4"), (62, 2, "B4"),
    ]
    for at, dur, note in mel:
        if note is None:
            continue
        bell.note(at, fm_bell(hz(midi(note)), beats(dur * 0.95), amp=0.42))

    mix = (bass.stereo() + pad.stereo() + bell.stereo()
           + arp.stereo() + perc.stereo() + shaker.stereo())
    return mix


# ----------------------------------------------------------------------------
# surface_night  (F# minor - calm, reflective, pad-forward)
# ----------------------------------------------------------------------------

def surface_night() -> np.ndarray:
    prog = [
        ("F#3", "min"), ("F#3", "min"), ("D3", "maj"), ("D3", "maj"),
        ("A3", "maj"), ("A3", "maj"), ("E3", "maj"), ("E3", "maj"),
        ("F#3", "min"), ("F#3", "min"), ("D3", "maj"), ("E3", "sus4"),
        ("A3", "maj"), ("A3", "maj"), ("E3", "maj"), ("E3", "maj"),
    ]
    pad, bass, bell = Track(0.0), Track(0.0), Track(0.22)
    shaker, perc = Track(-0.2), Track(0.0)
    for bar, (root, qual) in enumerate(prog):
        b0 = bar * BEATS_PER_BAR
        for m in triad(root, qual):
            pad.note(b0, fm_pad(hz(m + 12), beats(4.0), amp=0.34, a=0.4, s=0.9))
        bass.note(b0, fm_bass(hz(midi(root) - 12), beats(4.0), amp=0.42,
                              a=0.02, d=0.5, s=0.8, r=0.5))
        perc.note(b0, kick(freq0=90, freq1=42, dur=0.18, amp=0.26))
        shaker.note(b0 + 1, psg_noise(beats(0.25), amp=0.04, tone=0.4))
        shaker.note(b0 + 3, psg_noise(beats(0.25), amp=0.04, tone=0.4))
    mel = [
        (0, 3, "F#4"), (3, 1, "E4"), (4, 4, "D4"), (8, 3, "A4"), (11, 1, "F#4"),
        (12, 4, "E4"), (16, 3, "F#4"), (19, 1, "G#4"), (20, 4, "A4"),
        (24, 4, "C#5"), (28, 2, "B4"), (30, 2, "A4"), (32, 4, "F#4"),
        (36, 4, "D4"), (40, 3, "E4"), (43, 1, "F#4"), (44, 4, "E4"),
        (48, 3, "A4"), (51, 1, "G#4"), (52, 4, "F#4"), (56, 4, "E4"), (60, 4, "F#4"),
    ]
    for at, dur, note in mel:
        bell.note(at, fm_bell(hz(midi(note)), beats(dur * 0.9), amp=0.30,
                              peak=2.2, d=1.2, s=0.4, r=0.8))
    return pad.stereo() + bass.stereo() + bell.stereo() + shaker.stereo() + perc.stereo()


# ----------------------------------------------------------------------------
# underground  (F# minor - dark, sparse, mysterious drones + distant bells)
# ----------------------------------------------------------------------------

def underground() -> np.ndarray:
    prog = [
        ("F#2", "min"), ("F#2", "min"), ("F#2", "min"), ("D2", "maj"),
        ("F#2", "min"), ("F#2", "min"), ("E2", "min"), ("E2", "min"),
        ("F#2", "min"), ("F#2", "min"), ("D2", "maj"), ("D2", "maj"),
        ("F#2", "min"), ("F#2", "min"), ("E2", "min"), ("E2", "min"),
    ]
    drone, pad, bell = Track(0.0), Track(0.0), Track(0.25)
    for bar, (root, qual) in enumerate(prog):
        b0 = bar * BEATS_PER_BAR
        rm = midi(root)
        drone.note(b0, fm_bass(hz(rm), beats(4.0), amp=0.40, a=0.6, d=0.8, s=0.85,
                               r=0.8, peak=0.8, end=0.15))
        drone.note(b0, fm_bass(hz(rm + 7), beats(4.0), amp=0.22, a=0.7, s=0.8,
                               r=0.8, peak=0.6, end=0.1))
        if bar % 2 == 0:
            for m in triad(root, qual):
                pad.note(b0, fm_pad(hz(m + 24), beats(4.0), amp=0.09, a=0.9,
                                    s=0.7, r=1.0, index=0.3))
    mel = [(2, 2, "F#4"), (6, 2, "A4"), (10, 2, "C#5"), (14, 3, "B4"),
           (20, 2, "F#4"), (26, 3, "E4"), (34, 2, "A4"), (40, 2, "F#4"),
           (50, 3, "C#5"), (58, 4, "F#4")]
    for at, dur, note in mel:
        bell.note(at, fm_bell(hz(midi(note)), beats(dur), amp=0.20, peak=1.8,
                              d=1.6, s=0.3, r=1.6, ratio=3.0))
    return drone.stereo() + pad.stereo() + bell.stereo()


# ----------------------------------------------------------------------------
# crisis  (F# minor - driving, urgent: busy arp, 8th bass, harder percussion)
# ----------------------------------------------------------------------------

def crisis() -> np.ndarray:
    prog = [
        ("F#3", "min"), ("E3", "maj"), ("D3", "maj"), ("C#3", "maj"),
        ("F#3", "min"), ("E3", "maj"), ("D3", "maj"), ("C#3", "maj"),
        ("F#3", "min"), ("D3", "maj"), ("E3", "maj"), ("F#3", "min"),
        ("D3", "maj"), ("E3", "maj"), ("C#3", "maj"), ("C#3", "maj"),
    ]
    bass, arp, stab = Track(0.0), Track(-0.3), Track(0.15)
    perc, hat = Track(0.0), Track(0.2)
    for bar, (root, qual) in enumerate(prog):
        b0 = bar * BEATS_PER_BAR
        rm = midi(root)
        chord = triad(root, qual)
        for i in range(8):
            bass.note(b0 + i * 0.5, fm_bass(hz(rm - 12), beats(0.45), amp=0.48,
                                            d=0.15, s=0.5, r=0.06, peak=1.8))
        tones = [chord[0] + 12, chord[1] + 12, chord[2] + 12, chord[1] + 12]
        for i in range(16):
            m = tones[i % 4] + (12 if (i // 4) % 2 else 0)
            arp.note(b0 + i * 0.25, psg_square(hz(m), beats(0.22), amp=0.11, duty=0.5))
        for m in chord:
            stab.note(b0, fm_bell(hz(m + 12), beats(0.5), amp=0.15, peak=3.5,
                                  d=0.3, s=0.2, r=0.2))
        perc.note(b0, kick(amp=0.6))
        perc.note(b0 + 2, kick(amp=0.55))
        perc.note(b0 + 1, psg_noise(beats(0.25), amp=0.20, tone=0.05, r=0.12))
        perc.note(b0 + 3, psg_noise(beats(0.25), amp=0.20, tone=0.05, r=0.12))
        for i in range(8):
            hat.note(b0 + i * 0.5, psg_noise(beats(0.12), amp=0.055, tone=0.0, r=0.04))
    return (bass.stereo() + arp.stereo() + stab.stereo()
            + perc.stereo() + hat.stereo())


# ----------------------------------------------------------------------------
# stems  (single-purpose quiet layers; same key family; equal length; the
# director volume-automates each. Kept low so all 63 combinations stay clean.)
# ----------------------------------------------------------------------------

def stem_foundation() -> np.ndarray:
    t = Track(0.0)
    prog = [midi("A2"), midi("A2"), midi("E2"), midi("E2")] * 4
    for bar, rm in enumerate(prog):
        b0 = bar * BEATS_PER_BAR
        t.note(b0, fm_bass(hz(rm), beats(4.0), amp=0.5, a=0.5, s=0.9, r=0.6,
                           peak=0.9, end=0.2))
        t.note(b0, fm_pad(hz(rm + 12), beats(4.0), amp=0.18, a=0.6, s=0.85, index=0.3))
        t.note(b0, fm_pad(hz(rm + 19), beats(4.0), amp=0.12, a=0.7, s=0.8, index=0.2))
    return t.stereo()


def stem_hearth() -> np.ndarray:
    t = Track(0.0)
    prog = [("A3", "maj"), ("D3", "maj"), ("A3", "maj"), ("E3", "maj")] * 4
    for bar, (r, q) in enumerate(prog):
        b0 = bar * BEATS_PER_BAR
        for m in triad(r, q):
            t.note(b0, fm_pad(hz(m + 12), beats(4.0), amp=0.22, a=0.35, s=0.88,
                              detune=8, index=0.5))
    return t.stereo()


def stem_motion() -> np.ndarray:
    arp, perc = Track(-0.2), Track(0.1)
    prog = [("A3", "maj"), ("E3", "maj"), ("F#3", "min"), ("D3", "maj")] * 4
    for bar, (r, q) in enumerate(prog):
        b0 = bar * BEATS_PER_BAR
        chord = triad(r, q)
        tones = [chord[0] + 12, chord[1] + 12, chord[2] + 12, chord[1] + 12]
        for i in range(16):
            m = tones[i % 4] + (12 if (i // 4) % 2 else 0)
            arp.note(b0 + i * 0.25, psg_square(hz(m), beats(0.2), amp=0.13, duty=0.4))
        perc.note(b0, kick(amp=0.38))
        perc.note(b0 + 2, kick(amp=0.34))
        for i in range(8):
            if i % 2 == 1:
                perc.note(b0 + i * 0.5, psg_noise(beats(0.15), amp=0.05, tone=0.3))
    return arp.stereo() + perc.stereo()


def stem_pressure() -> np.ndarray:
    t = Track(0.0)
    for bar in range(16):
        b0 = bar * BEATS_PER_BAR
        for i in range(16):
            amp = 0.15 if i % 2 == 0 else 0.09
            t.note(b0 + i * 0.25, fm_bass(hz(midi("F#2")), beats(0.22), amp=amp,
                                          peak=1.2, d=0.1, s=0.4, r=0.05))
        t.note(b0, fm_pad(hz(midi("G3")), beats(2.0), amp=0.09, a=0.2, s=0.6, index=0.4))
        t.note(b0 + 2, fm_pad(hz(midi("F#3")), beats(2.0), amp=0.09, a=0.2, s=0.6, index=0.4))
    return t.stereo()


def stem_attunement() -> np.ndarray:
    t = Track(0.25)
    penta = [midi(n) for n in ("A5", "B5", "C#6", "E6", "F#6")]
    for bar in range(16):
        b0 = bar * BEATS_PER_BAR
        for i in range(8):
            m = penta[(bar * 2 + i) % len(penta)]
            t.note(b0 + i * 0.5, fm_bell(hz(m), beats(0.6), amp=0.10, peak=2.5,
                                         d=0.5, s=0.2, r=0.6, ratio=3.5))
    return t.stereo()


def stem_fracture() -> np.ndarray:
    drone, swell = Track(0.0), Track(0.0)
    for bar in range(16):
        b0 = bar * BEATS_PER_BAR
        drone.note(b0, fm_bass(hz(midi("F#2")), beats(4.0), amp=0.16, a=0.8,
                               s=0.85, r=0.8, peak=0.7, ratio=1.01))
        if bar % 4 == 2:
            drone.note(b0, fm_bass(hz(midi("C3")), beats(4.0), amp=0.10, a=1.0,
                                   s=0.7, r=1.0, peak=0.6))
        if bar % 4 == 0:
            swell.note(b0, psg_noise(beats(6.0), amp=0.11, a=1.5, d=2.0, s=0.3,
                                     r=2.0, tone=0.6))
    return drone.stereo() + swell.stereo()


# ----------------------------------------------------------------------------
# stingers  (short one-shots, placed in seconds, NOT looped)
# ----------------------------------------------------------------------------

def _stinger(events: list, length_s: float, pan: float = 0.0) -> np.ndarray:
    n = int(length_s * SR)
    buf = np.zeros(n)
    for at, sig in events:
        s = int(at * SR)
        e = min(n, s + sig.size)
        if e > s:
            buf[s:e] += sig[:e - s]
    ang = (pan * 0.5 + 0.5) * (np.pi / 2)
    return np.stack([buf * np.cos(ang), buf * np.sin(ang)], axis=1)


def sting_dawn() -> np.ndarray:
    ev = [(i * 0.13, fm_bell(hz(midi(n)), int(1.2 * SR), amp=0.5, peak=2.6,
                             d=0.8, s=0.3, r=0.9))
          for i, n in enumerate(["A4", "C#5", "E5", "A5"])]
    return _stinger(ev, 2.0, pan=0.1)


def sting_nightfall() -> np.ndarray:
    ev = [(i * 0.15, fm_bell(hz(midi(n)), int(1.3 * SR), amp=0.42, peak=2.0,
                             d=1.0, s=0.3, r=1.0))
          for i, n in enumerate(["F#5", "C#5", "A4", "F#4"])]
    return _stinger(ev, 2.0, pan=-0.1)


def sting_raid_warning() -> np.ndarray:
    ev = [(0.0, kick(freq0=150, freq1=52, dur=0.4, amp=0.7))]
    for k in range(3):
        at = k * 0.22
        ev.append((at, fm_bell(hz(midi("F#4")), int(0.35 * SR), amp=0.5, peak=4.0,
                               d=0.2, s=0.3, r=0.12, ratio=1.414)))
        ev.append((at, fm_bell(hz(midi("C5")), int(0.35 * SR), amp=0.32, peak=4.0,
                               d=0.2, s=0.3, r=0.12, ratio=1.414)))
    return _stinger(ev, 1.6, pan=0.0)


def sting_attunement() -> np.ndarray:
    ev = [(i * 0.05, fm_bell(hz(midi(n)), int(0.9 * SR), amp=0.34, peak=3.0,
                             d=0.6, s=0.2, r=0.7, ratio=3.5))
          for i, n in enumerate(["A5", "C#6", "E6", "F#6", "A6"])]
    return _stinger(ev, 1.5, pan=0.15)


def sting_base_advance() -> np.ndarray:
    ev = []
    for i, n in enumerate(["D4", "A4", "E5", "A5"]):
        ev.append((i * 0.14, fm_bell(hz(midi(n)), int(1.1 * SR), amp=0.5, peak=2.8,
                                     d=0.7, s=0.4, r=0.8)))
        ev.append((i * 0.14, psg_square(hz(midi(n)), int(0.5 * SR), amp=0.13, duty=0.5)))
    for m in triad("A4", "maj"):
        ev.append((0.56, fm_pad(hz(m), int(1.2 * SR), amp=0.18, a=0.02, s=0.7, r=0.9)))
    return _stinger(ev, 2.2, pan=0.0)


CONTEXTS = {
    "surface_day": surface_day,
    "surface_night": surface_night,
    "underground": underground,
    "crisis": crisis,
}
STEMS = {
    "foundation": stem_foundation,
    "hearth": stem_hearth,
    "motion": stem_motion,
    "pressure": stem_pressure,
    "attunement": stem_attunement,
    "fracture": stem_fracture,
}
STINGERS = {
    "dawn": sting_dawn,
    "nightfall": sting_nightfall,
    "raid_warning": sting_raid_warning,
    "attunement": sting_attunement,
    "base_advance": sting_base_advance,
}

CONTEXT_PATH = "audio/music/rendered/contexts/coheronia_{}.ogg"
STEM_PATH = "audio/music/rendered/stems/stem_{}.ogg"
STINGER_PATH = "audio/music/rendered/stingers/stinger_{}.ogg"


# ----------------------------------------------------------------------------
# render / encode
# ----------------------------------------------------------------------------

def finalize(mix: np.ndarray, headroom=0.9) -> np.ndarray:
    """Trim to exactly LOOP frames, soft-limit, and normalize under headroom.

    The loop is seamless by construction: note release tails wrap around the
    boundary (add_wrap) and every downbeat voice attacks from silence, so the
    first and last frames already match. tanh soft-clip + normalize are
    per-sample monotonic, so they preserve that continuity (no seam crossfade -
    an earlier one copied the loud downbeat onto the tail and BROKE the seam)."""
    if mix.shape[0] < LOOP:
        mix = np.pad(mix, ((0, LOOP - mix.shape[0]), (0, 0)))
    mix = mix[:LOOP].copy()
    mix = np.tanh(mix * 0.8) / np.tanh(0.8)
    peak = float(np.max(np.abs(mix))) or 1.0
    mix *= headroom / peak
    return mix


def encode_ogg(mix: np.ndarray, out_path: Path, quality=6) -> None:
    out_path.parent.mkdir(parents=True, exist_ok=True)
    pcm = np.clip(mix, -1.0, 1.0)
    pcm = (pcm * 32767.0).astype("<i2").tobytes()
    ff = imageio_ffmpeg.get_ffmpeg_exe()
    subprocess.run(
        [ff, "-v", "error", "-f", "s16le", "-ar", str(SR), "-ac", "2", "-i", "-",
         "-c:a", "libvorbis", "-q:a", str(quality), "-f", "ogg", "-y", str(out_path)],
        input=pcm, check=True,
    )


def finalize_stem(mix: np.ndarray, peak_to=0.34) -> np.ndarray:
    """Stems mix additively under the director's volume automation. Normalizing
    each to a low peak (<=0.34) guarantees every one of the 63 subset sums stays
    below full scale at the verifier's nominal gain (sum / count**0.55)."""
    if mix.shape[0] < LOOP:
        mix = np.pad(mix, ((0, LOOP - mix.shape[0]), (0, 0)))
    mix = mix[:LOOP].copy()
    mix = np.tanh(mix * 0.9) / np.tanh(0.9)
    peak = float(np.max(np.abs(mix))) or 1.0
    return mix * (peak_to / peak)


def finalize_stinger(mix: np.ndarray, peak_to=0.85) -> np.ndarray:
    mix = np.tanh(mix * 0.9) / np.tanh(0.9)
    peak = float(np.max(np.abs(mix))) or 1.0
    return mix * (peak_to / peak)


def report(mix: np.ndarray, loop=True) -> None:
    peak = float(np.max(np.abs(mix)))
    seam = float(np.max(np.abs(mix[0] - mix[-1])))
    tag = f"seam={seam:.4f} (limit 0.24)  " if loop else ""
    print(f"  frames={mix.shape[0]}  peak={peak:.3f}  {tag}seconds={mix.shape[0]/SR:.3f}")


def update_patch() -> None:
    """Refresh the source-patch provenance the verifier checks: the audio is now
    rendered by this generator (the FM/PSG suite), operator-approved by ear."""
    import json
    path = ROOT / "audio/music/source_m8str0/coheronia_adaptive_suite.m8patch"
    patch = json.loads(path.read_text(encoding="utf-8"))
    patch["schema"] = "coheronia-fm-synth-v1"
    patch["status"] = ("rendered by scripts/audio/gen_music.py - a numpy YM2612-style "
                       "FM + SN76489-style PSG synth suite (warm RPG/pastoral voice)")
    patch["source_generator"] = "scripts/audio/gen_music.py"
    patch["key_family"] = "A major / F# minor (contexts + stems share the family so "
    patch["key_family"] += "the layer bed is consonant over every context)"
    patch["operator_approval"] = ("surface_day prototype approved by ear 2026-08-19; "
                                  "full suite rendered in the same voice")
    path.write_text(json.dumps(patch, indent=2) + "\n", encoding="utf-8")
    print(f"updated {path.relative_to(ROOT)}")


def build_all() -> int:
    for name, fn in CONTEXTS.items():
        print(f"context {name} ...")
        mix = finalize(fn())
        report(mix)
        encode_ogg(mix, ROOT / CONTEXT_PATH.format(name))
    for name, fn in STEMS.items():
        print(f"stem {name} ...")
        mix = finalize_stem(fn())
        report(mix)
        encode_ogg(mix, ROOT / STEM_PATH.format(name))
    for name, fn in STINGERS.items():
        print(f"stinger {name} ...")
        mix = finalize_stinger(fn())
        report(mix, loop=False)
        encode_ogg(mix, ROOT / STINGER_PATH.format(name))
    update_patch()
    print("all assets rendered.")
    return 0


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--all", action="store_true",
                    help="render every asset to its manifest path + update the patch")
    ap.add_argument("--only", default="surface_day", help="one context to a scratch file")
    ap.add_argument("--out", default="build/proto_surface_day.ogg")
    args = ap.parse_args()

    if args.all:
        return build_all()
    if args.only not in CONTEXTS:
        print(f"unknown context '{args.only}'; have {list(CONTEXTS)}")
        return 1
    print(f"rendering {args.only} ...")
    mix = finalize(CONTEXTS[args.only]())
    report(mix)
    out = (ROOT / args.out) if not Path(args.out).is_absolute() else Path(args.out)
    encode_ogg(mix, out)
    print(f"wrote {out}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
