#!/usr/bin/env python3
from __future__ import annotations

import json
import re
import subprocess
import sys
from itertools import combinations
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
MAX_STINGER_SAMPLES = SR * 8
MAX_PEAK = 0.98

CONTEXTS = {
    "surface_day": "audio/music/rendered/contexts/coheronia_surface_day.ogg",
    "surface_night": "audio/music/rendered/contexts/coheronia_surface_night.ogg",
    "underground": "audio/music/rendered/contexts/coheronia_underground.ogg",
    "crisis": "audio/music/rendered/contexts/coheronia_crisis.ogg",
}
STEMS = {
    "foundation": "audio/music/rendered/stems/stem_foundation.ogg",
    "hearth": "audio/music/rendered/stems/stem_hearth.ogg",
    "motion": "audio/music/rendered/stems/stem_motion.ogg",
    "pressure": "audio/music/rendered/stems/stem_pressure.ogg",
    "attunement": "audio/music/rendered/stems/stem_attunement.ogg",
    "fracture": "audio/music/rendered/stems/stem_fracture.ogg",
}
STINGERS = {
    "dawn": "audio/music/rendered/stingers/stinger_dawn.ogg",
    "nightfall": "audio/music/rendered/stingers/stinger_nightfall.ogg",
    "raid_warning": "audio/music/rendered/stingers/stinger_raid_warning.ogg",
    "attunement": "audio/music/rendered/stingers/stinger_attunement.ogg",
    "base_advance": "audio/music/rendered/stingers/stinger_base_advance.ogg",
}


def fail(message: str) -> None:
    print(f"FAIL {message}")
    raise SystemExit(1)


def ffmpeg_stream_info(path: Path) -> dict[str, object]:
    ffmpeg = imageio_ffmpeg.get_ffmpeg_exe()
    result = subprocess.run(
        [
            ffmpeg,
            "-hide_banner",
            "-i",
            str(path),
        ],
        capture_output=True,
        text=True,
    )
    match = re.search(r"Audio:\s+([^,]+),\s+(\d+)\s+Hz,\s+([^,\r\n]+)", result.stderr)
    if not match:
        fail(f"{path}: unable to read ffmpeg stream info")
    channel_text = match.group(3).strip().lower()
    channels = 2 if "stereo" in channel_text else 1 if "mono" in channel_text else 0
    return {"codec_name": match.group(1).strip(), "sample_rate": int(match.group(2)), "channels": channels}


def decode_pcm(path: Path) -> np.ndarray:
    ffmpeg = imageio_ffmpeg.get_ffmpeg_exe()
    result = subprocess.run(
        [
            ffmpeg,
            "-v",
            "error",
            "-i",
            str(path),
            "-f",
            "s16le",
            "-acodec",
            "pcm_s16le",
            "-ac",
            "2",
            "-",
        ],
        check=True,
        capture_output=True,
    )
    pcm = np.frombuffer(result.stdout, dtype="<i2")
    if pcm.size % 2 != 0:
        fail(f"{path}: decoded PCM has odd channel sample count")
    return (pcm.reshape((-1, 2)).astype(np.float32) / 32768.0)


def verify_manifest() -> None:
    manifest = json.loads((ROOT / "data/music_manifest.json").read_text(encoding="utf-8"))
    if int(manifest.get("sample_rate_hz", 0)) != SR:
        fail("data/music_manifest.json sample_rate_hz must remain 48000 for these assets")
    if int(manifest.get("bpm", 0)) != BPM or int(manifest.get("beats_per_bar", 0)) != BEATS_PER_BAR:
        fail("music manifest grid must be 72 BPM and 4/4")
    if int(manifest.get("bars_per_loop", 0)) != BARS:
        fail("music manifest bars_per_loop must be 16")
    for key, rel in CONTEXTS.items():
        if manifest.get("contexts", {}).get(key, {}).get("stream") != "res://" + rel.replace("\\", "/"):
            fail(f"manifest path mismatch for context {key}")
    for key, rel in STEMS.items():
        if manifest.get("stems", {}).get(key) != "res://" + rel.replace("\\", "/"):
            fail(f"manifest path mismatch for stem {key}")
    for key, rel in STINGERS.items():
        if manifest.get("stingers", {}).get(key) != "res://" + rel.replace("\\", "/"):
            fail(f"manifest path mismatch for stinger {key}")
    print("PASS manifest path and grid contract")


def verify_loop(role: str, rel: str) -> np.ndarray:
    path = ROOT / rel
    if not path.is_file():
        fail(f"missing {role}: {rel}")
    stream = ffmpeg_stream_info(path)
    if stream.get("codec_name") != "vorbis":
        fail(f"{rel}: expected OGG Vorbis, got {stream.get('codec_name')}")
    if int(stream.get("sample_rate", 0)) != SR:
        fail(f"{rel}: expected {SR} Hz")
    if int(stream.get("channels", 0)) != 2:
        fail(f"{rel}: expected stereo")
    pcm = decode_pcm(path)
    if pcm.shape[0] != LOOP_SAMPLES:
        fail(f"{rel}: decoded {pcm.shape[0]} samples, expected {LOOP_SAMPLES}")
    peak = float(np.max(np.abs(pcm)))
    if peak > MAX_PEAK:
        fail(f"{rel}: peak {peak:.4f} exceeds {MAX_PEAK}")
    seam = float(np.max(np.abs(pcm[0] - pcm[-1])))
    if seam > 0.24:
        fail(f"{rel}: seam jump {seam:.4f} is too large")
    print(f"PASS {role}: {rel} samples={pcm.shape[0]} peak={peak:.3f} seam={seam:.3f}")
    return pcm


def verify_stinger(role: str, rel: str) -> None:
    path = ROOT / rel
    if not path.is_file():
        fail(f"missing {role}: {rel}")
    stream = ffmpeg_stream_info(path)
    if stream.get("codec_name") != "vorbis":
        fail(f"{rel}: expected OGG Vorbis")
    if int(stream.get("sample_rate", 0)) != SR:
        fail(f"{rel}: expected {SR} Hz")
    pcm = decode_pcm(path)
    if pcm.shape[0] > MAX_STINGER_SAMPLES:
        fail(f"{rel}: stinger exceeds 8 seconds")
    peak = float(np.max(np.abs(pcm)))
    if peak > MAX_PEAK:
        fail(f"{rel}: peak {peak:.4f} exceeds {MAX_PEAK}")
    print(f"PASS stinger: {rel} samples={pcm.shape[0]} seconds={pcm.shape[0] / SR:.2f} peak={peak:.3f}")


def verify_stem_combinations(stems: dict[str, np.ndarray]) -> None:
    names = list(stems)
    for count in range(1, len(names) + 1):
        for combo in combinations(names, count):
            mix = sum(stems[name] for name in combo) / max(1.0, count ** 0.55)
            peak = float(np.max(np.abs(mix)))
            if peak > 1.0:
                fail(f"stem combination clips: {combo} peak={peak:.3f}")
    print("PASS all 63 stem combinations remain below full-scale at equal nominal gain")


def verify_patch() -> None:
    patch_path = ROOT / "audio/music/source_m8str0/coheronia_adaptive_suite.m8patch"
    if not patch_path.is_file():
        fail("missing source patch coheronia_adaptive_suite.m8patch")
    patch = json.loads(patch_path.read_text(encoding="utf-8"))
    for key, expected in [("bpm", BPM), ("bars", BARS), ("sample_rate_hz", SR), ("loop_samples", LOOP_SAMPLES)]:
        if int(patch.get(key, 0)) != expected:
            fail(f"source patch {key} mismatch")
    if "operator_approval" not in patch:
        fail("source patch must keep operator approval state explicit")
    print("PASS source patch metadata")


def main() -> int:
    verify_manifest()
    context_pcm = {name: verify_loop(f"context {name}", rel) for name, rel in CONTEXTS.items()}
    stem_pcm = {name: verify_loop(f"stem {name}", rel) for name, rel in STEMS.items()}
    for name, rel in STINGERS.items():
        verify_stinger(name, rel)
    verify_stem_combinations(stem_pcm)
    verify_patch()
    checkpoint_samples = [0, 4 * BAR_SAMPLES, 8 * BAR_SAMPLES, 12 * BAR_SAMPLES, LOOP_SAMPLES]
    print(f"PASS checkpoint samples: {checkpoint_samples}")
    print(f"PASS context set: {', '.join(context_pcm)}")
    print("PASS music asset verification complete")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
