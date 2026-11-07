"""Build traced feedback clips from the user's second, audible recording.

The first demo is digital silence and is never used as an audio source.
Windows follow full-track waveform analysis and video event review; extraction
uses filtering and short boundary fades, not source-separation claims.
"""
from pathlib import Path
import hashlib
import json
import numpy as np
from scipy import signal
from scipy.io import wavfile

ROOT = Path(__file__).resolve().parents[1]
SOURCE_ID = "gameplay_feedback_audio"
SOURCE = ROOT / "audio/library/groove_core/working" / SOURCE_ID / "extracted_audio.wav"
DEST = ROOT / "audio/authorized/feedback"
REPORT = ROOT / "audio/library/groove_core/analysis/combat-feedback.json"
WINDOWS = [
    ("kill_low_strong", 11.450, 11.820, 22, 700),
    ("kill_low_soft", 17.270, 17.620, 22, 700),
    ("kill_low_round", 16.410, 16.700, 22, 700),
    ("shield_impact", 23.480, 23.730, 380, 4500),
    ("pickup_coin", 6.685, 6.845, 3000, 9500),
]


def main():
    rate, pcm = wavfile.read(SOURCE)
    assert rate == 48000 and pcm.dtype == np.int16
    source = pcm.astype(np.float64) / 32768.
    assert abs(source).max() > .1, "Refuse silent input"
    DEST.mkdir(parents=True, exist_ok=True)
    catalog = json.loads((ROOT / "audio/library/groove_core/catalog.json").read_text(encoding="utf-8"))
    item = next(i for i in catalog["items"] if i["id"] == SOURCE_ID)
    clips = []
    for name, start, end, low, high in WINDOWS:
        raw = source[round(start * rate):round(end * rate)].copy()
        sos = signal.butter(3, [low, high], fs=rate, btype="bandpass", output="sos")
        data = signal.sosfiltfilt(sos, raw, axis=0)
        attack, release = round(.002 * rate), round(.014 * rate)
        data[:attack] *= np.linspace(0., 1., attack)[:, None]
        data[-release:] *= np.linspace(1., 0., release)[:, None]
        clips.append((name, start, end, low, high, data))
    # One gain for the entire drum family preserves the recorded accents.
    drum_gain = .68 / max(abs(c[5]).max() for c in clips[:3])
    records = []
    for name, start, end, low, high, data in clips:
        gain = drum_gain if name.startswith("kill_") else .60 / abs(data).max()
        data *= gain
        path = DEST / (name + ".wav")
        wavfile.write(path, rate, np.rint(np.clip(data, -.94, .94) * 32767).astype(np.int16))
        mono = data.mean(axis=1)
        f, power = signal.welch(mono, rate, nperseg=min(8192, len(mono)))
        records.append({
            "id": name, "file": path.relative_to(ROOT).as_posix(),
            "source_catalog_id": SOURCE_ID, "source_start_seconds": start,
            "source_end_seconds": end, "seconds": len(data)/rate,
            "processing": f"Butterworth3 bandpass {low}-{high}Hz; 2ms attack/14ms release boundary fades; fixed gain {gain:.6f}; no pitch/time change",
            "peak_dbfs": float(20*np.log10(max(1e-9, abs(data).max()))),
            "rms_dbfs": float(20*np.log10(max(1e-9, np.sqrt(np.mean(data**2))))),
            "low_35_250_ratio": float(power[(f>=35)&(f<=250)].sum()/max(1e-12,power.sum())),
            "sha256": hashlib.sha256(path.read_bytes()).hexdigest(),
        })
    report = {
        "source_catalog_id": SOURCE_ID, "source_sha256": item["sha256"],
        "source_pcm_sha256": hashlib.sha256(SOURCE.read_bytes()).hexdigest(),
        "silent_reference": {"id": "gameplay_feedback_demo", "status": "digital_silence_not_used"},
        "review": "Full-track waveform/spectrum and video frames inspected; shield ring begins at23.34s; distinct shield audio transient at23.50s, trimmed to23.48s; isolated high pickup at6.7s; low kill events begin at11.46s. Mixed-gameplay excerpts are filtered, not claimed as isolated original stems.",
        "sample_rate": rate, "channels": pcm.shape[1], "clips": records,
    }
    REPORT.write_text(json.dumps(report, ensure_ascii=False, indent=2)+"\n", encoding="utf-8")
    import matplotlib
    matplotlib.use("Agg")
    import matplotlib.pyplot as plt
    fig, axes = plt.subplots(len(clips), 1, figsize=(12, 10))
    for ax, (name, start, end, _, _, data) in zip(axes, clips):
        ax.plot(np.arange(len(data))/rate, data.mean(axis=1), linewidth=.6)
        ax.set_title(f"{name} | source {start:.3f}-{end:.3f}s"); ax.set_ylim(-1,1)
    fig.tight_layout(); fig.savefig(REPORT.with_suffix(".png")); plt.close(fig)
    register(records)
    print(json.dumps(records, ensure_ascii=False, indent=2))


def register(records):
    """Use the library writer; keep previous processed variants immutable."""
    from types import SimpleNamespace
    import audio_library as library
    catalog = library.load_catalog()
    item = next(i for i in catalog["items"] if i["id"] == SOURCE_ID)
    for clip in records:
        label = "runtime_" + clip["id"]
        old = next((v for v in item.get("variants", []) if v["label"] == label), None)
        if old and old.get("sha256") == clip["sha256"]:
            continue
        if old:
            label += "_" + clip["sha256"][:8]
        if any(v["label"] == label for v in item.get("variants", [])):
            continue
        library.add_variant(SimpleNamespace(id=SOURCE_ID, file=str(ROOT / clip["file"]),
            label=label, role=clip["id"], notes=clip["processing"], mark_ready=True, dry_run=False))
    auth = ROOT / "audio/authorized/AUTHORIZED_SFX.json"
    data = json.loads(auth.read_text(encoding="utf-8"))
    data["clips"] = [c for c in data["clips"] if not c["id"].startswith("feedback_")]
    for clip in records:
        data["clips"].append({"id": "feedback_"+clip["id"], "file": "res://"+clip["file"],
            "source_catalog_id": SOURCE_ID, "source_seconds": clip["source_start_seconds"],
            "source_end_seconds": clip["source_end_seconds"], "role": clip["id"],
            "processing": clip["processing"], "sha256": clip["sha256"]})
    auth.write_text(json.dumps(data, ensure_ascii=False, indent=2)+"\n", encoding="utf-8")
    mapping = ROOT / "audio/library/groove_core/runtime_mapping.json"
    data = json.loads(mapping.read_text(encoding="utf-8"))
    row = next(i for i in data["items"] if i["catalog_id"] == SOURCE_ID)
    row["processing"] = "; ".join(dict.fromkeys(c["processing"] for c in records))
    row["source_windows"] = [{"start_seconds": c["source_start_seconds"],
        "end_seconds": c["source_end_seconds"], "use": c["id"]} for c in records]
    mapping.write_text(json.dumps(data, ensure_ascii=False, indent=2)+"\n", encoding="utf-8")


if __name__ == "__main__":
    main()
