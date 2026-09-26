"""Prepare a small external audition set; never change production audio.

Requires numpy and soundfile. Pass --sources and --output (outside the game).
The first-shot windows below were checked against these particular recordings;
this is deliberately not a general-purpose burst splitter.
"""

import argparse
import hashlib
import json
from pathlib import Path

import numpy as np
import soundfile as sf


PACKS = {
    "free_firearm": {
        "source": "https://opengameart.org/content/the-free-firearm-sound-library",
        "license": "CC0",
        "creator": "Ben Jaszczak, Brian Nelson, Kevin Heras, Matthew Nanney",
    },
    "snake_1": {
        "source": "https://f8studios.itch.io/snakes-authentic-gun-sounds",
        "license": "Author permits commercial use and editing; credit appreciated, optional.",
        "creator": "SnakeF8 / F8 Studios",
    },
    "snake_2": {
        "source": "https://f8studios.itch.io/snakes-second-authentic-gun-sounds-pack",
        "license": "Author permits commercial use and editing; credit appreciated, optional.",
        "creator": "SnakeF8 / F8 Studios",
    },
    "mixkit": {
        "source": "https://mixkit.co/free-sound-effects/gun/",
        "license": "Mixkit license; retain specific source/license evidence before production promotion.",
    },
    "loose": {
        "source": None,
        "license": "Exact download-page provenance not supplied; audition candidate only.",
    },
}


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def candidates(root):
    for weapon in ("1911", "Bersa", "Ruger Mark III", "Ruger Single Six",
                   "Smith & Wesson 642", "Walther PPQ"):
        for path in sorted((root / "Gunshots" / weapon).glob("*.wav")):
            yield path, f"Handgun_shots/FF - {weapon} - {path.stem} - first shot.wav", "free_firearm", True
    for folder, pack in (("Snake's Authentic Gun Sounds", "snake_1"),
                         ("Snake's SECOND Authentic Gun Sounds", "snake_2")):
        for path in sorted((root / folder / "Isolated").rglob("*.wav")):
            if "Single" not in path.name:
                continue
            category = "Handgun_shots" if "9mm" in path.parts else "Other_single_shots"
            yield path, f"{category}/Snake - {path.stem}.wav", pack, False
    path = root / "Snake's SECOND Authentic Gun Sounds" / "& More/Pistol/WAV/9mm Pistol Dry Fire.wav"
    yield path, "Empty_clicks/Snake - 9mm Pistol Dry Fire.wav", "snake_2", False
    for filename, label, pack in (
        ("mixkit-handgun-click-1660.mp3", "Mixkit - handgun click", "mixkit"),
        ("spinopel-dry-fire-gun-364844.mp3", "Spinopel - dry fire gun 364844", "loose"),
        ("spinopel-dry-fire-364846.mp3", "Spinopel - dry fire 364846", "loose"),
        ("freesound_community-empty-gun-shot-6209.mp3", "Empty gun shot 6209", "loose"),
    ):
        yield root / filename, f"Empty_clicks/{label}.wav", pack, False


def prepare(source, destination, first_shot):
    source_hash = digest(source)
    data, rate = sf.read(source, always_2d=True, dtype="float64")
    amplitude = np.max(np.abs(data), axis=1)
    peak = float(amplitude.max())
    if not np.isfinite(data).all() or peak <= 0:
        raise ValueError(f"Invalid or silent source: {source}")
    # Start just before the attack, retaining a little lead-in for quiet mechanics.
    attack = int(np.flatnonzero(amplitude >= peak * 0.4)[0])
    search_start = max(0, attack - round(rate * 0.03))
    onset = search_start + int(np.flatnonzero(amplitude[search_start:attack + 1] >= peak * 0.01)[0])
    start = max(0, onset - round(rate * 0.004))
    # These handgun sources have their second report >3.4 s after the first.
    # Keep only the inspected first-shot window; never apply this to bursts.
    window_end = min(len(data), attack + round(rate * 3.2)) if first_shot else len(data)
    active = np.flatnonzero(amplitude[start:window_end] >= peak * 10 ** (-50 / 20))
    end = min(window_end, start + int(active[-1]) + 1 + round(rate * 0.06))
    clip = data[start:end].copy()
    # Attenuate only. MP3 decoding can exceed full scale; prevent added clipping.
    gain = min(1.0, 0.8 / float(np.abs(clip).max()))
    clip *= gain
    fade_in = min(round(rate * 0.001), onset - start, len(clip))
    fade_out = min(round(rate * 0.01), len(clip))
    if fade_in > 0:
        clip[:fade_in] *= np.linspace(0, 1, fade_in)[:, None]
    clip[-fade_out:] *= np.linspace(1, 0, fade_out)[:, None]
    destination.parent.mkdir(parents=True, exist_ok=True)
    sf.write(destination, clip, rate, subtype="PCM_16")
    check, check_rate = sf.read(destination, always_2d=True)
    assert check_rate == rate and check.shape == clip.shape
    assert np.isfinite(check).all() and 0 < np.abs(check).max() < 0.801
    assert digest(source) == source_hash, f"Source changed: {source}"
    return {
        "source_file": str(source), "source_sha256": source_hash,
        "source_duration_seconds": len(data) / rate,
        "source_peak": peak,
        "source_samples_at_or_above_full_scale": int(np.sum(amplitude >= 1.0)),
        "start_frame": start, "end_frame_exclusive": end,
        "sample_rate": rate, "channels": data.shape[1],
        "duration_seconds": len(clip) / rate,
        "gain_db": float(20 * np.log10(gain)),
        "fade_in_frames": fade_in, "fade_out_frames": fade_out,
        "window_limit_reached": end == window_end and first_shot,
        "output_sha256": digest(destination),
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--sources", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    root, output = args.sources.resolve(), args.output.resolve()
    if root == output or output.is_relative_to(root) or root.is_relative_to(output):
        parser.error("Use a separate output folder beside, not inside, the original sources.")
    if output.exists():
        parser.error("Output already exists; choose a new folder to preserve previous auditions.")
    jobs = list(candidates(root))
    if len(jobs) != 24 or any(not source.is_file() for source, *_ in jobs):
        parser.error("Expected the inspected 24-source set; check the source-pack layout.")
    output.mkdir(parents=True)
    manifest = {"format": "PCM16 WAV, original sample rate and channels",
                "processing": "Trim lead/tail, first shot only from Free Firearm sequences, attenuation only to at most 0.8 peak, up to 1ms lead and 10ms tail fades. No denoise, pitch change, compression or added reverb.",
                "approval": "Prepared for listening; not an accepted game mix.",
                "packs": PACKS, "clips": []}
    for source, relative, pack, first_shot in jobs:
        entry = prepare(source, output / relative, first_shot)
        entry.update({"file": relative, "pack": pack})
        manifest["clips"].append(entry)
        print(f"{entry['duration_seconds']:.3f}s  {relative}", flush=True)
    (output / "source_manifest.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    (output / "README.txt").write_text(
        "FIREARM AUDITIONS\n\n"
        "24 prepared candidates: 13 handgun shots, 5 empty clicks, 6 other isolated shots.\n"
        "In game: F1 > Audio tuning > Combat > choose an event > Add recordings.\n"
        "Choose files from the matching folder. Audition rows individually before saving.\n"
        "Out of ammo plays on an empty trigger press in game. Save defaults changes the saved mix.\n\n"
        "The originals and existing reload/mix are unchanged. These are listening candidates,\n"
        "not approved replacements. No denoising or added reverb; original room reflections remain.\n"
        "The manifest records exact cuts, gain, fades, source hashes and source permissions.\n"
        "Start with Snake 9mm, FF Walther PPQ X_39P and FF 1911 A_42P for handgun shots;\n"
        "Snake 9mm Pistol Dry Fire and Mixkit handgun click for empty clicks.\n"
        "Those starting points are based on labels and waveform duration, not listening approval.\n\n"
        "Other pack recordings, reloads, bursts and loose multi-click sequences remain available\n"
        "in the original Sounds folder. This is a compact shortlist, not a full library conversion.\n",
        encoding="utf-8")
    print(f"Verified {len(jobs)} clips; originals preserved. Output: {output}")


if __name__ == "__main__":
    main()
