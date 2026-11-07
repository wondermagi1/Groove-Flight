#!/usr/bin/env python3
"""Incremental catalog for authorized Groove Core reference recordings."""

from __future__ import annotations

import argparse
import array
import csv
import hashlib
import io
import json
import math
import os
import re
import shutil
import subprocess
import sys
import wave
from datetime import datetime, timezone
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[1]
LIBRARY = Path(
    os.environ.get(
        "GROOVE_FLIGHT_AUDIO_LIBRARY",
        os.environ.get("BEATDRIFT_AUDIO_LIBRARY", ROOT / "audio" / "library" / "groove_core"),
    )
).resolve()
CATALOG = LIBRARY / "catalog.json"
CSV_INDEX = LIBRARY / "catalog.csv"
MARKDOWN_INDEX = LIBRARY / "CATALOG.md"
ANALYSIS_INDEX = LIBRARY / "ANALYSIS.md"
RUNTIME_MAPPING = LIBRARY / "runtime_mapping.json"
CATEGORIES = {
    "music",
    "weapon",
    "hit",
    "kill",
    "pickup",
    "warning",
    "boss",
    "ui",
    "ambience",
    "voice",
    "video",
    "other",
}
CSV_FIELDS = [
    "id",
    "title",
    "category",
    "role",
    "status",
    "authorization",
    "bpm",
    "bars",
    "duration_seconds",
    "sample_rate_hz",
    "channels",
    "bit_depth",
    "loop",
    "source_file",
    "sha256",
    "tags",
    "notes",
    "imported_at",
]
MEDIA_EXTENSIONS = {".wav", ".ogg", ".mp3", ".flac", ".m4a", ".aac", ".mp4", ".mov", ".mkv", ".webm"}
AUDIO_EXTENSIONS = {".wav", ".ogg", ".mp3", ".flac", ".m4a", ".aac"}
VIDEO_EXTENSIONS = {".mp4", ".mov", ".mkv", ".webm"}


def now_iso() -> str:
    return datetime.now(timezone.utc).isoformat(timespec="seconds")


def slug(value: str, fallback: str) -> str:
    cleaned = re.sub(r"[^a-z0-9]+", "_", value.lower()).strip("_")
    return cleaned[:64] or fallback


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def find_tool(name: str) -> str | None:
    executable = shutil.which(name)
    if executable:
        return executable
    app_roots = []
    if os.environ.get("LOCALAPPDATA"):
        app_roots.append(Path(os.environ["LOCALAPPDATA"]))
    if os.environ.get("USERPROFILE"):
        app_roots.append(Path(os.environ["USERPROFILE"]) / "AppData" / "Local")
    for app_root in app_roots:
        package_root = app_root / "Microsoft" / "WinGet" / "Packages"
        try:
            candidates = sorted(package_root.glob(f"Gyan.FFmpeg*/**/bin/{name}.exe"))
        except OSError:
            candidates = []
        if candidates:
            return str(candidates[-1])
    return None


def empty_catalog() -> dict[str, Any]:
    return {
        "schema_version": 1,
        "source_game": "Groove Core Demo",
        "authorization": {
            "status": "user-confirmed",
            "recorded_at": "2026-11-02",
            "statement": "用户说明已获得原作者授权，可以直接使用录制或提取的音频。",
            "evidence_dir": "authorization/",
        },
        "created_at": now_iso(),
        "updated_at": now_iso(),
        "items": [],
    }


def load_catalog() -> dict[str, Any]:
    if not CATALOG.exists():
        return empty_catalog()
    data = json.loads(CATALOG.read_text(encoding="utf-8"))
    if not isinstance(data, dict) or not isinstance(data.get("items"), list):
        raise ValueError(f"Invalid catalog: {CATALOG}")
    return data


def atomic_text(path: Path, content: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_name(path.name + ".tmp")
    temporary.write_text(content, encoding="utf-8", newline="\n")
    os.replace(temporary, path)


def markdown_cell(value: Any) -> str:
    return str(value if value is not None else "").replace("|", "\\|").replace("\n", " ")


def write_indexes(catalog: dict[str, Any]) -> None:
    items = catalog["items"]
    rows = []
    for item in items:
        row = {key: item.get(key, "") for key in CSV_FIELDS}
        row["tags"] = ",".join(item.get("tags", []))
        rows.append(row)
    rows.sort(key=lambda row: (str(row["category"]), str(row["id"])))
    output = io.StringIO()
    writer = csv.DictWriter(output, fieldnames=CSV_FIELDS)
    writer.writeheader()
    writer.writerows(rows)
    atomic_text(CSV_INDEX, output.getvalue())

    lines = [
        "# Groove Core 授权音频索引",
        "",
        f"条目数：{len(items)}。由 `tools/audio_library.py` 自动生成，请勿手工编辑。",
        "",
        "| ID | 分类 / 用途 | 标题 | 时长 | BPM | 状态 | 授权 |",
        "| --- | --- | --- | ---: | ---: | --- | --- |",
    ]
    for item in sorted(items, key=lambda value: (value["category"], value["id"])):
        duration = item.get("duration_seconds")
        duration_text = f"{duration:.2f}s" if isinstance(duration, (int, float)) else "待探测"
        lines.append(
            "| %s | %s / %s | %s | %s | %s | %s | %s |"
            % (
                markdown_cell(item["id"]),
                markdown_cell(item["category"]),
                markdown_cell(item.get("role", "")),
                markdown_cell(item.get("title", "")),
                markdown_cell(duration_text),
                markdown_cell(item.get("bpm", "")),
                markdown_cell(item.get("status", "")),
                markdown_cell(item.get("authorization", "")),
            )
        )
    if not items:
        lines.append("| — | — | 尚无音频入库 | — | — | — | — |")
    atomic_text(MARKDOWN_INDEX, "\n".join(lines) + "\n")

    analysis_lines = [
        "# Groove Core 音频分析索引",
        "",
        "估计值用于制作参考，不替代逐段人工试听。",
        "",
        "| ID | 标题 | 时长 | BPM | 置信度 | 有效事件 | 主导周期 | 周期置信度 | RMS dBFS | 峰值因数 | 频段 低/中低/中/高 | 瞬态/秒 | 分析图 |",
        "| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | --- | ---: | --- |",
    ]
    analyzed = [item for item in items if item.get("analysis")]
    for item in sorted(analyzed, key=lambda value: (value["category"], value["id"])):
        analysis = item["analysis"]
        bands = analysis.get("band_energy_ratio", {})
        band_text = "/".join(f"{float(bands.get(key, 0.0)):.2f}" for key in ["low", "low_mid", "mid", "high"])
        image = analysis.get("waveform_spectrum")
        sheet = analysis.get("contact_sheet")
        links = []
        if image:
            links.append(f"[波形]({image})")
        if sheet:
            links.append(f"[画面]({sheet})")
        analysis_lines.append(
            "| %s | %s | %.2fs | %s | %s | %s | %s | %s | %s | %s | %s | %s | %s |"
            % (
                markdown_cell(item["id"]),
                markdown_cell(item.get("title", "")),
                float(analysis.get("duration_seconds", 0.0)),
                markdown_cell(item.get("bpm", "")),
                markdown_cell(analysis.get("tempo_confidence", "")),
                markdown_cell(analysis.get("active_interval_count", "")),
                markdown_cell(analysis.get("dominant_period_seconds", "")),
                markdown_cell(analysis.get("period_confidence", "")),
                markdown_cell(analysis.get("rms_dbfs", "")),
                markdown_cell(analysis.get("crest_factor_db", "")),
                band_text,
                markdown_cell(analysis.get("onset_rate_per_second", "")),
                " ".join(links),
            )
        )
    if not analyzed:
        analysis_lines.append("| — | 尚无分析结果 | — | — | — | — | — | — | — | — | — | — | — |")
    atomic_text(ANALYSIS_INDEX, "\n".join(analysis_lines) + "\n")


def save_catalog(catalog: dict[str, Any]) -> None:
    catalog["updated_at"] = now_iso()
    atomic_text(CATALOG, json.dumps(catalog, ensure_ascii=False, indent=2) + "\n")
    write_indexes(catalog)


def ffprobe_metadata(path: Path) -> dict[str, Any]:
    executable = find_tool("ffprobe")
    if not executable:
        return {}
    command = [
        executable,
        "-v",
        "error",
        "-show_entries",
        "format=duration:stream=index,codec_type,codec_name,sample_rate,channels,bits_per_raw_sample,width,height,avg_frame_rate",
        "-of",
        "json",
        str(path),
    ]
    try:
        completed = subprocess.run(command, capture_output=True, text=True, check=True, timeout=30)
        payload = json.loads(completed.stdout)
        audio_streams = [row for row in payload.get("streams", []) if row.get("codec_type") == "audio"]
        video_streams = [row for row in payload.get("streams", []) if row.get("codec_type") == "video"]
        stream = audio_streams[0] if audio_streams else {}
        video = video_streams[0] if video_streams else {}
        bit_depth = stream.get("bits_per_raw_sample")
        rate = str(video.get("avg_frame_rate", ""))
        try:
            numerator, denominator = (int(value) for value in rate.split("/", 1))
            frame_rate = numerator / denominator if denominator else None
        except (ValueError, TypeError):
            frame_rate = None
        return {
            "media_type": "video" if video_streams else ("audio" if audio_streams else "unknown"),
            "codec": stream.get("codec_name"),
            "sample_rate_hz": int(stream["sample_rate"]) if stream.get("sample_rate") else None,
            "channels": int(stream["channels"]) if stream.get("channels") else None,
            "bit_depth": int(bit_depth) if str(bit_depth or "").isdigit() else None,
            "duration_seconds": float(payload.get("format", {}).get("duration", 0.0)) or None,
            "has_audio": bool(audio_streams),
            "has_video": bool(video_streams),
            "video_codec": video.get("codec_name"),
            "video_width": int(video["width"]) if video.get("width") else None,
            "video_height": int(video["height"]) if video.get("height") else None,
            "frame_rate": round(frame_rate, 3) if frame_rate else None,
        }
    except (OSError, subprocess.SubprocessError, json.JSONDecodeError, ValueError):
        return {}


def wav_metadata(path: Path) -> dict[str, Any]:
    try:
        with wave.open(str(path), "rb") as recording:
            channels = recording.getnchannels()
            sample_rate = recording.getframerate()
            sample_width = recording.getsampwidth()
            frame_count = recording.getnframes()
            peak = 0.0
            squared = 0.0
            sample_count = 0
            while True:
                chunk = recording.readframes(65536)
                if not chunk:
                    break
                if sample_width == 2:
                    values = array.array("h")
                    values.frombytes(chunk)
                    if sys.byteorder != "little":
                        values.byteswap()
                    for value in values:
                        normalized = float(value) / 32768.0
                        peak = max(peak, abs(normalized))
                        squared += normalized * normalized
                        sample_count += 1
            result = {
                "media_type": "audio",
                "codec": f"pcm_s{sample_width * 8}le",
                "sample_rate_hz": sample_rate,
                "channels": channels,
                "bit_depth": sample_width * 8,
                "duration_seconds": frame_count / sample_rate if sample_rate else None,
                "has_audio": True,
                "has_video": False,
            }
            if sample_count:
                result["peak_dbfs"] = round(20.0 * math.log10(max(peak, 1e-12)), 3)
                result["rms_dbfs"] = round(20.0 * math.log10(max(math.sqrt(squared / sample_count), 1e-12)), 3)
            return result
    except (wave.Error, EOFError, OSError):
        return {}


def probe(path: Path) -> dict[str, Any]:
    metadata = ffprobe_metadata(path)
    if path.suffix.lower() == ".wav":
        metadata.update(wav_metadata(path))
    if "media_type" not in metadata:
        extension = path.suffix.lower()
        if extension in AUDIO_EXTENSIONS:
            metadata["media_type"] = "audio"
            metadata["has_audio"] = True
        elif extension in VIDEO_EXTENSIONS:
            metadata["media_type"] = "video"
            metadata["has_audio"] = None
        else:
            metadata["media_type"] = "unknown"
            metadata["has_audio"] = None
    metadata.update(
        {
            "source_name": path.name,
            "file_size_bytes": path.stat().st_size,
            "sha256": sha256_file(path),
        }
    )
    return metadata


def next_id(catalog: dict[str, Any], category: str) -> str:
    used = {str(item["id"]) for item in catalog["items"]}
    index = 1
    while f"{category}_{index:03d}" in used:
        index += 1
    return f"{category}_{index:03d}"


def add_item(args: argparse.Namespace) -> int:
    source = Path(args.file).expanduser().resolve()
    if not source.is_file():
        raise FileNotFoundError(source)
    category = args.category.lower()
    catalog = load_catalog()
    item_id = args.id or next_id(catalog, category)
    item_id = slug(item_id, next_id(catalog, category))
    if any(item["id"] == item_id for item in catalog["items"]):
        raise ValueError(f"id already exists: {item_id}")
    metadata = probe(source)
    digest = str(metadata["sha256"])
    duplicate = next((item for item in catalog["items"] if item.get("sha256") == digest), None)
    if duplicate:
        raise ValueError(f"duplicate audio content already cataloged as {duplicate['id']}")
    destination = LIBRARY / "raw" / item_id / source.name
    entry = {
        "id": item_id,
        "title": args.title or source.stem,
        "source_game": args.source_game,
        "category": category,
        "role": args.role,
        "status": "raw",
        "authorization": "原作者授权 / 用户确认",
        "authorization_evidence": "authorization/",
        "bpm": args.bpm,
        "bars": args.bars,
        "loop": bool(args.loop),
        "clip_start_seconds": args.clip_start,
        "clip_end_seconds": args.clip_end,
        "tags": [tag.strip() for tag in args.tags.split(",") if tag.strip()],
        "notes": args.notes,
        "source_origin": str(source),
        "source_file": catalog_path(destination),
        "imported_at": now_iso(),
        **metadata,
        "variants": [],
    }
    if args.dry_run:
        print(json.dumps({"dry_run": True, "entry": entry}, ensure_ascii=False, indent=2))
        return 0
    destination.parent.mkdir(parents=True, exist_ok=False)
    shutil.copy2(source, destination)
    catalog["items"].append(entry)
    save_catalog(catalog)
    print(f"Added {item_id}: {destination}")
    if metadata.get("duration_seconds") is None:
        print("WARNING: duration is unknown; install/find ffprobe to inspect video or compressed media.", file=sys.stderr)
    return 0


def add_variant(args: argparse.Namespace) -> int:
    catalog = load_catalog()
    item = next((value for value in catalog["items"] if value["id"] == args.id), None)
    if item is None:
        raise ValueError(f"unknown id: {args.id}")
    source = Path(args.file).expanduser().resolve()
    if not source.is_file():
        raise FileNotFoundError(source)
    label = slug(args.label, "processed")
    if any(value.get("label") == label for value in item.get("variants", [])):
        raise ValueError(f"variant already exists for {args.id}: {label}")
    metadata = probe(source)
    destination = LIBRARY / "working" / args.id / (label + source.suffix.lower())
    variant = {
        "label": label,
        "role": args.role or item.get("role", ""),
        "file": catalog_path(destination),
        "created_at": now_iso(),
        "notes": args.notes,
        **metadata,
    }
    if args.dry_run:
        print(json.dumps({"dry_run": True, "entry_id": args.id, "variant": variant}, ensure_ascii=False, indent=2))
        return 0
    destination.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(source, destination)
    item.setdefault("variants", []).append(variant)
    if args.mark_ready:
        item["status"] = "processed"
    save_catalog(catalog)
    print(f"Added variant {args.id}/{label}: {destination}")
    return 0


def infer_category(path: Path, root: Path) -> str:
    parts = [part.lower() for part in path.relative_to(root).parts[:-1]]
    for part in reversed(parts):
        if part in CATEGORIES:
            return part
    return "other"


def batch_add(args: argparse.Namespace) -> int:
    root = Path(args.directory).expanduser().resolve()
    if not root.is_dir():
        raise FileNotFoundError(root)
    extensions = {value.strip().lower() for value in args.extensions.split(",") if value.strip()}
    if not extensions:
        raise ValueError("at least one extension is required")
    files = []
    iterator = root.rglob("*") if args.recursive else root.glob("*")
    for path in sorted(iterator):
        if not path.is_file() or path.suffix.lower() not in extensions:
            continue
        relative_parts = {part.lower() for part in path.relative_to(root).parts}
        if "raw" in relative_parts or "working" in relative_parts or path.name.startswith("."):
            continue
        files.append(path)
    added = 0
    skipped = 0
    failed = 0
    failures = []
    for path in files:
        category = args.category
        if category == "auto":
            category = infer_category(path, root)
        role = args.role or slug(path.stem, "unclassified")
        item_args = argparse.Namespace(
            file=str(path),
            id=None,
            title=path.stem,
            category=category,
            role=role,
            source_game=args.source_game,
            bpm=args.bpm,
            bars=args.bars,
            loop=args.loop,
            clip_start=None,
            clip_end=None,
            tags=args.tags,
            notes=args.notes or f"Batch import from {root}",
            dry_run=args.dry_run,
        )
        try:
            add_item(item_args)
            added += 1
        except ValueError as error:
            if "duplicate" in str(error).lower():
                skipped += 1
            else:
                failed += 1
                failures.append({"file": str(path), "error": str(error)})
        except OSError as error:
            failed += 1
            failures.append({"file": str(path), "error": str(error)})
    summary = {
        "directory": str(root),
        "discovered": len(files),
        "added": added,
        "duplicates": skipped,
        "failed": failed,
        "failures": failures,
        "dry_run": bool(args.dry_run),
    }
    print(json.dumps(summary, ensure_ascii=False, indent=2))
    return 1 if failed else 0


def extract_audio(args: argparse.Namespace) -> int:
    catalog = load_catalog()
    item = next((value for value in catalog["items"] if value["id"] == args.id), None)
    if item is None:
        raise ValueError(f"unknown id: {args.id}")
    executable = find_tool("ffmpeg")
    if not executable:
        raise ValueError("ffmpeg is not available; install ffmpeg or export a WAV recording first")
    label = slug(args.label, "extracted_audio")
    if any(value.get("label") == label for value in item.get("variants", [])):
        raise ValueError(f"variant already exists for {args.id}: {label}")
    source = path_from_catalog(item.get("source_file"))
    destination = LIBRARY / "working" / args.id / (label + ".wav")
    if destination.exists():
        raise ValueError(f"destination already exists: {destination}")
    destination.parent.mkdir(parents=True, exist_ok=True)
    command = [
        executable,
        "-hide_banner",
        "-loglevel",
        "error",
        "-y",
        "-i",
        str(source),
        "-vn",
        "-ac",
        "2",
        "-ar",
        "48000",
        "-c:a",
        "pcm_s16le",
        str(destination),
    ]
    subprocess.run(command, check=True, timeout=600)
    metadata = probe(destination)
    item.setdefault("variants", []).append(
        {
            "label": label,
            "role": item.get("role", ""),
            "file": catalog_path(destination),
            "created_at": now_iso(),
            "notes": args.notes,
            **metadata,
        }
    )
    item["status"] = "audio_extracted"
    save_catalog(catalog)
    print(f"Extracted {args.id}/{label}: {destination}")
    return 0


def refresh_item(args: argparse.Namespace) -> int:
    catalog = load_catalog()
    item = next((value for value in catalog["items"] if value["id"] == args.id), None)
    if item is None:
        raise ValueError(f"unknown id: {args.id}")
    source = path_from_catalog(item.get("source_file"))
    if not source.is_file():
        raise FileNotFoundError(source)
    metadata = probe(source)
    if item.get("sha256") and metadata.get("sha256") != item["sha256"]:
        raise ValueError(f"source hash changed; refusing to refresh {args.id}")
    item.update(metadata)
    save_catalog(catalog)
    print(json.dumps({"id": args.id, "metadata": metadata}, ensure_ascii=False, indent=2))
    return 0


def edit_item(args: argparse.Namespace) -> int:
    catalog = load_catalog()
    item = next((value for value in catalog["items"] if value["id"] == args.id), None)
    if item is None:
        raise ValueError(f"unknown id: {args.id}")
    if args.title is not None:
        item["title"] = args.title
    if args.role is not None:
        item["role"] = args.role
    if args.category is not None:
        item["category"] = args.category
    if args.clear_bpm:
        item["bpm"] = None
    if args.bpm is not None:
        item["bpm"] = args.bpm
    if args.bars is not None:
        item["bars"] = args.bars
    if args.clip_start is not None:
        item["clip_start_seconds"] = args.clip_start
    if args.clip_end is not None:
        item["clip_end_seconds"] = args.clip_end
    if args.tags is not None:
        item["tags"] = [tag.strip() for tag in args.tags.split(",") if tag.strip()]
    if args.notes is not None:
        item["notes"] = args.notes
    if args.loop:
        item["loop"] = True
    if args.no_loop:
        item["loop"] = False
    save_catalog(catalog)
    print(json.dumps({"id": args.id, "updated": True}, ensure_ascii=False))
    return 0


def path_from_catalog(relative: Any) -> Path:
    path = Path(str(relative))
    return path if path.is_absolute() else ROOT / path


def catalog_path(path: Path) -> str:
    try:
        return path.relative_to(ROOT).as_posix()
    except ValueError:
        return str(path)


def doctor() -> int:
    print(
        json.dumps(
            {
                "library": str(LIBRARY),
                "library_exists": LIBRARY.is_dir(),
                "ffmpeg": find_tool("ffmpeg"),
                "ffprobe": find_tool("ffprobe"),
                "python": sys.version.split()[0],
            },
            ensure_ascii=False,
            indent=2,
        )
    )
    return 0


def analyze_audio_file(path: Path) -> dict[str, Any]:
    import numpy as np
    from scipy import signal

    with wave.open(str(path), "rb") as recording:
        channels = recording.getnchannels()
        sample_rate = recording.getframerate()
        sample_width = recording.getsampwidth()
        if sample_width != 2:
            raise ValueError("analysis currently requires PCM16 WAV")
        raw = recording.readframes(recording.getnframes())
    samples = np.frombuffer(raw, dtype="<i2").astype(np.float32) / 32768.0
    if channels > 1:
        samples = samples.reshape(-1, channels)
        mono = samples.mean(axis=1)
    else:
        mono = samples
    if mono.size == 0:
        raise ValueError(f"empty audio: {path}")
    peak = float(np.max(np.abs(samples)))
    rms = float(np.sqrt(np.mean(np.square(samples))))
    stft_frequency, stft_time, spectrum = signal.stft(
        mono,
        fs=sample_rate,
        nperseg=2048,
        noverlap=1536,
        boundary=None,
        padded=False,
    )
    magnitude = np.abs(spectrum)
    power = np.square(magnitude)
    frame_energy = power.sum(axis=0)
    flux = np.maximum(0.0, np.diff(magnitude, axis=1)).sum(axis=0)
    if flux.size:
        flux = np.convolve(flux, np.ones(5) / 5.0, mode="same")
    threshold = float(np.mean(flux) + np.std(flux) * 0.65) if flux.size else 0.0
    peaks, _ = signal.find_peaks(flux, height=threshold, distance=2)
    onset_times = stft_time[1:][peaks] if peaks.size else np.array([], dtype=float)

    envelope_seconds = 0.02
    envelope_size = max(1, int(round(sample_rate * envelope_seconds)))
    usable = (mono.size // envelope_size) * envelope_size
    active_intervals: list[dict[str, Any]] = []
    dominant_period_seconds = None
    period_confidence = None
    if usable >= envelope_size * 8:
        envelopes = np.square(mono[:usable]).reshape(-1, envelope_size).mean(axis=1)
        envelope_db = 20.0 * np.log10(np.maximum(np.sqrt(envelopes), 1e-9))
        noise_floor = float(np.percentile(envelope_db, 20))
        loud_level = float(np.percentile(envelope_db, 95))
        active_threshold = max(-55.0, noise_floor + max(3.5, (loud_level - noise_floor) * 0.12))
        active = envelope_db >= active_threshold
        merge_gap = max(1, int(round(0.12 / envelope_seconds)))
        active_indices = np.flatnonzero(active)
        if active_indices.size:
            split_points = np.flatnonzero(np.diff(active_indices) > merge_gap) + 1
            for indices in np.split(active_indices, split_points):
                start_frame = int(indices[0])
                end_frame = int(indices[-1]) + 1
                duration = (end_frame - start_frame) * envelope_seconds
                if duration < 0.035:
                    continue
                level = envelope_db[start_frame:end_frame]
                active_intervals.append(
                    {
                        "start_seconds": round(start_frame * envelope_seconds, 3),
                        "end_seconds": round(end_frame * envelope_seconds, 3),
                        "duration_seconds": round(duration, 3),
                        "peak_dbfs": round(float(np.max(level)), 3),
                        "rms_dbfs": round(
                            20.0
                            * math.log10(
                                max(float(np.sqrt(np.mean(np.square(10.0 ** (level / 20.0))))), 1e-9)
                            ),
                            3,
                        ),
                    }
                )
        centered_envelope = envelopes - envelopes.mean()
        autocorrelation_envelope = np.fft.irfft(
            np.abs(np.fft.rfft(centered_envelope, n=2 * centered_envelope.size)) ** 2
        )[: centered_envelope.size]
        min_period_lag = max(1, int(round(0.2 / envelope_seconds)))
        max_period_lag = min(
            autocorrelation_envelope.size // 2,
            int(round(min(8.0, mono.size / sample_rate / 2.0) / envelope_seconds)),
        )
        if max_period_lag > min_period_lag:
            period_window = autocorrelation_envelope[min_period_lag : max_period_lag + 1]
            period_peaks, _period_properties = signal.find_peaks(period_window)
            if period_peaks.size:
                best_period = int(period_peaks[np.argmax(period_window[period_peaks])])
                period_lag = min_period_lag + best_period
                dominant_period_seconds = round(period_lag * envelope_seconds, 3)
                period_confidence = round(
                    float(autocorrelation_envelope[period_lag] / max(1e-9, autocorrelation_envelope[0])),
                    3,
                )

    tempo_bpm = None
    tempo_confidence = None
    if flux.size > 16:
        centered = flux - flux.mean()
        autocorrelation = np.fft.irfft(np.abs(np.fft.rfft(centered, n=2 * flux.size)) ** 2)[: flux.size]
        frame_seconds = float(stft_time[1] - stft_time[0])
        min_lag = max(1, int(round((60.0 / 200.0) / frame_seconds)))
        max_lag = min(autocorrelation.size - 1, int(round((60.0 / 55.0) / frame_seconds)))
        if max_lag > min_lag:
            window = autocorrelation[min_lag : max_lag + 1]
            local_peaks, _properties = signal.find_peaks(window)
            if local_peaks.size:
                best = int(local_peaks[np.argmax(window[local_peaks])])
                lag = min_lag + best
                beat_seconds = lag * frame_seconds
                tempo_bpm = round(60.0 / beat_seconds, 2)
                baseline = max(1e-9, float(autocorrelation[0]))
                tempo_confidence = round(float(autocorrelation[lag]) / baseline, 3)

    total_power = max(1e-12, float(power.sum()))
    bands = {}
    for name, lower, upper in [
        ("low", 20.0, 180.0),
        ("low_mid", 180.0, 600.0),
        ("mid", 600.0, 3000.0),
        ("high", 3000.0, 16000.0),
    ]:
        mask = (stft_frequency >= lower) & (stft_frequency < upper)
        bands[name] = round(float(power[mask].sum()) / total_power, 4)
    stereo_correlation = None
    if channels == 2:
        left = samples[:, 0].astype(np.float64)
        right = samples[:, 1].astype(np.float64)
        denominator = float(np.sqrt(np.dot(left, left) * np.dot(right, right)))
        stereo_correlation = round(float(np.dot(left, right) / max(denominator, 1e-12)), 3)
    return {
        "duration_seconds": round(mono.size / sample_rate, 4),
        "peak_dbfs": round(20.0 * math.log10(max(peak, 1e-12)), 3),
        "rms_dbfs": round(20.0 * math.log10(max(rms, 1e-12)), 3),
        "crest_factor_db": round(20.0 * math.log10(max(peak, 1e-12) / max(rms, 1e-12)), 3),
        "estimated_bpm": tempo_bpm,
        "tempo_confidence": tempo_confidence,
        "onset_count": int(peaks.size),
        "onset_rate_per_second": round(float(peaks.size) / max(0.001, mono.size / sample_rate), 3),
        "onset_times_seconds": [round(float(value), 3) for value in onset_times[:256]],
        "active_interval_count": len(active_intervals),
        "active_intervals": active_intervals[:256],
        "dominant_period_seconds": dominant_period_seconds,
        "period_confidence": period_confidence,
        "band_energy_ratio": bands,
        "stereo_correlation": stereo_correlation,
        "_plot_data": {
            "sample_rate": sample_rate,
            "mono": mono,
            "stft_frequency": stft_frequency,
            "stft_time": stft_time,
            "magnitude": magnitude,
            "frame_energy": frame_energy,
            "flux": flux,
            "onset_times": onset_times,
        },
    }


def write_audio_plot(analysis: dict[str, Any], destination: Path) -> None:
    import matplotlib

    matplotlib.use("Agg")
    import matplotlib.pyplot as plt
    import numpy as np

    data = analysis.pop("_plot_data")
    mono = data["mono"]
    sample_rate = data["sample_rate"]
    times = np.arange(mono.size, dtype=np.float64) / sample_rate
    figure, (wave_axis, spectrum_axis) = plt.subplots(
        2,
        1,
        figsize=(14, 7.5),
        gridspec_kw={"height_ratios": [1.0, 1.35]},
        constrained_layout=True,
    )
    stride = max(1, mono.size // 120000)
    wave_axis.plot(times[::stride], mono[::stride], color="#55d9cf", linewidth=0.65)
    wave_axis.scatter(
        data["onset_times"],
        np.interp(data["onset_times"], times, mono),
        color="#ffc267",
        s=8,
        alpha=0.8,
        label="onsets",
    )
    wave_axis.set_ylim(-1.0, 1.0)
    wave_axis.set_ylabel("amplitude")
    wave_axis.legend(loc="upper right")
    magnitude = data["magnitude"]
    db = 20.0 * np.log10(np.maximum(magnitude, 1e-7))
    spectrum_axis.imshow(
        db,
        origin="lower",
        aspect="auto",
        extent=[data["stft_time"][0], data["stft_time"][-1], data["stft_frequency"][0], 12000],
        cmap="magma",
        vmin=-75,
        vmax=-15,
    )
    spectrum_axis.set_ylim(0, 12000)
    spectrum_axis.set_xlabel("seconds")
    spectrum_axis.set_ylabel("Hz")
    figure.suptitle(destination.parent.name)
    destination.parent.mkdir(parents=True, exist_ok=True)
    figure.savefig(destination, dpi=150)
    plt.close(figure)


def write_contact_sheet(item: dict[str, Any], destination: Path) -> bool:
    ffmpeg = find_tool("ffmpeg")
    duration = item.get("duration_seconds")
    if not ffmpeg or not item.get("has_video") or not isinstance(duration, (int, float)):
        return False
    source = path_from_catalog(item.get("source_file"))
    fps = 6.0 / max(0.1, float(duration))
    destination.parent.mkdir(parents=True, exist_ok=True)
    command = [
        ffmpeg,
        "-hide_banner",
        "-loglevel",
        "error",
        "-i",
        str(source),
        "-vf",
        f"fps={fps:.6f},scale=480:-1,tile=2x3:padding=4:margin=4",
        "-y",
        "-frames:v",
        "1",
        str(destination),
    ]
    subprocess.run(command, check=True, timeout=120)
    return destination.is_file()


def analyze_item(args: argparse.Namespace) -> int:
    catalog = load_catalog()
    item = next((value for value in catalog["items"] if value["id"] == args.id), None)
    if item is None:
        raise ValueError(f"unknown id: {args.id}")
    variant = next((value for value in item.get("variants", []) if value.get("label") == "extracted_audio"), None)
    audio_path = path_from_catalog(variant["file"] if variant else item.get("source_file"))
    if audio_path.suffix.lower() != ".wav":
        raise ValueError("run the extract command before analysis")
    output_root = LIBRARY / "analysis" / args.id
    output_root.mkdir(parents=True, exist_ok=True)
    result = analyze_audio_file(audio_path)
    plot_path = output_root / "waveform-spectrum.png"
    write_audio_plot(result, plot_path)
    contact_path = output_root / "contact-sheet.jpg"
    has_sheet = write_contact_sheet(item, contact_path)
    summary = {
        "analyzed_audio": catalog_path(audio_path),
        "waveform_spectrum": catalog_path(plot_path),
        "contact_sheet": catalog_path(contact_path) if has_sheet else None,
        **result,
    }
    item["analysis"] = summary
    item["status"] = "analyzed"
    if (
        item.get("bpm") is None
        and result.get("estimated_bpm") is not None
        and float(result.get("tempo_confidence") or 0.0) >= 0.35
    ):
        item["bpm"] = result["estimated_bpm"]
    save_catalog(catalog)
    print(json.dumps({"id": args.id, "analysis": summary}, ensure_ascii=False, indent=2))
    return 0


def analyze_all(args: argparse.Namespace) -> int:
    catalog = load_catalog()
    ids = [
        str(item["id"])
        for item in catalog["items"]
        if args.category == "all" or str(item.get("category", "")) == args.category
    ]
    failures = []
    for item_id in ids:
        try:
            result = analyze_item(argparse.Namespace(id=item_id))
            if result:
                failures.append({"id": item_id, "status": result})
        except (OSError, ValueError, KeyError) as error:
            failures.append({"id": item_id, "error": str(error)})
    print(json.dumps({"analyzed": len(ids) - len(failures), "total": len(ids), "failures": failures}, ensure_ascii=False, indent=2))
    return 1 if failures else 0


def validate_library() -> int:
    catalog = load_catalog()
    failures: list[str] = []
    seen_ids: set[str] = set()
    seen_hashes: dict[str, str] = {}
    for item in catalog["items"]:
        item_id = str(item.get("id", ""))
        if not item_id:
            failures.append("catalog item without id")
            continue
        if item_id in seen_ids:
            failures.append(f"duplicate id: {item_id}")
        seen_ids.add(item_id)
        digest = str(item.get("sha256", ""))
        if digest in seen_hashes:
            failures.append(f"duplicate content: {item_id} and {seen_hashes[digest]}")
        elif digest:
            seen_hashes[digest] = item_id
        files = [item.get("source_file")] + [variant.get("file") for variant in item.get("variants", [])]
        for relative in files:
            if not relative:
                continue
            path = ROOT / str(relative)
            if not path.is_file():
                failures.append(f"missing file: {path}")
                continue
            if path == ROOT / str(item.get("source_file", "")) and digest and sha256_file(path) != digest:
                failures.append(f"hash mismatch: {path}")
    mapped_runtime_files = 0
    mapping_items = 0
    if RUNTIME_MAPPING.is_file():
        mapping = json.loads(RUNTIME_MAPPING.read_text(encoding="utf-8"))
        mapping_rows = mapping.get("items", [])
        mapping_items = len(mapping_rows)
        catalog_ids = {str(item.get("id", "")) for item in catalog["items"]}
        for mapped in mapping_rows:
            catalog_id = str(mapped.get("catalog_id", ""))
            if catalog_id not in catalog_ids:
                failures.append(f"runtime mapping references unknown catalog id: {catalog_id}")
            catalog_item = next(
                (value for value in catalog["items"] if str(value.get("id", "")) == catalog_id),
                {},
            )
            analysis = catalog_item.get("analysis", {})
            waveform = analysis.get("waveform_spectrum")
            if not waveform:
                failures.append(f"full-track waveform missing from analysis: {catalog_id}")
            elif not (ROOT / str(waveform)).is_file():
                failures.append(f"full-track waveform file missing: {waveform}")
            silent_reference = (
                mapped.get("status") == "silent_reference"
                and not mapped.get("runtime_files")
                and float(analysis.get("peak_dbfs", 0)) < -120
                and int(analysis.get("onset_count", -1)) == 0
            )
            if analysis.get("dominant_period_seconds") is None and not silent_reference:
                failures.append(f"period analysis missing: {catalog_id}")
            source_windows = mapped.get("source_windows", [])
            if mapped.get("status") == "runtime" and not source_windows:
                failures.append(f"runtime mapping has no source cut ranges: {catalog_id}")
            source = ROOT / str(mapped.get("source_file", ""))
            if not source.is_file():
                failures.append(f"runtime mapping source missing: {source}")
            else:
                expected = str(mapped.get("source_sha256", ""))
                if expected and sha256_file(source) != expected:
                    failures.append(f"runtime mapping source hash mismatch: {source}")
            for relative in mapped.get("runtime_files", []):
                mapped_runtime_files += 1
                if not (ROOT / str(relative)).is_file():
                    failures.append(f"runtime mapping target missing: {relative}")
        if mapping_items != len(catalog["items"]):
            failures.append(
                f"runtime mapping covers {mapping_items} items; catalog contains {len(catalog['items'])}"
            )
    print(
        json.dumps(
            {
                "items": len(catalog["items"]),
                "mapping_items": mapping_items,
                "mapped_runtime_files": mapped_runtime_files,
                "failures": failures,
            },
            ensure_ascii=False,
            indent=2,
        )
    )
    return 1 if failures else 0


def list_items() -> int:
    catalog = load_catalog()
    for item in sorted(catalog["items"], key=lambda value: (value["category"], value["id"])):
        duration = item.get("duration_seconds")
        duration_text = f"{duration:.2f}s" if isinstance(duration, (int, float)) else "unknown"
        print(f"{item['id']:<20} {item['category']:<10} {item['status']:<10} {duration_text:<10} {item['title']}")
    print(f"\n{len(catalog['items'])} item(s)")
    return 0


def parser() -> argparse.ArgumentParser:
    command = argparse.ArgumentParser(description="Incremental Groove Core authorized audio library")
    subcommands = command.add_subparsers(dest="command", required=True)

    add = subcommands.add_parser("add", help="copy and catalog one recording")
    add.add_argument("file")
    add.add_argument("--id")
    add.add_argument("--title")
    add.add_argument("--category", default="music", choices=sorted(CATEGORIES))
    add.add_argument("--role", default="unclassified")
    add.add_argument("--source-game", default="Groove Core Demo")
    add.add_argument("--bpm", type=float)
    add.add_argument("--bars", type=int)
    add.add_argument("--loop", action="store_true")
    add.add_argument("--clip-start", type=float)
    add.add_argument("--clip-end", type=float)
    add.add_argument("--tags", default="")
    add.add_argument("--notes", default="")
    add.add_argument("--dry-run", action="store_true")
    add.set_defaults(func=add_item)

    variant = subcommands.add_parser("variant", help="attach a processed derivative to an existing item")
    variant.add_argument("id")
    variant.add_argument("file")
    variant.add_argument("--label", default="processed")
    variant.add_argument("--role")
    variant.add_argument("--notes", default="")
    variant.add_argument("--mark-ready", action="store_true")
    variant.add_argument("--dry-run", action="store_true")
    variant.set_defaults(func=add_variant)

    batch = subcommands.add_parser("batch", help="incrementally catalog every media file in a folder")
    batch.add_argument("directory")
    batch.add_argument("--category", default="auto", choices=sorted(CATEGORIES | {"auto"}))
    batch.add_argument("--role", default="")
    batch.add_argument("--source-game", default="Groove Core Demo")
    batch.add_argument("--bpm", type=float)
    batch.add_argument("--bars", type=int)
    batch.add_argument("--loop", action="store_true")
    batch.add_argument("--tags", default="batch")
    batch.add_argument("--notes", default="")
    batch.add_argument("--recursive", action="store_true")
    batch.add_argument("--extensions", default=",".join(sorted(MEDIA_EXTENSIONS)))
    batch.add_argument("--dry-run", action="store_true")
    batch.set_defaults(func=batch_add)

    extract = subcommands.add_parser("extract", help="extract a 48kHz stereo WAV from an existing video/audio item")
    extract.add_argument("id")
    extract.add_argument("--label", default="extracted_audio")
    extract.add_argument("--notes", default="ffmpeg PCM16 48kHz stereo")
    extract.set_defaults(func=extract_audio)

    refresh = subcommands.add_parser("refresh", help="re-probe source metadata without copying or changing hashes")
    refresh.add_argument("id")
    refresh.set_defaults(func=refresh_item)

    analyze = subcommands.add_parser("analyze", help="measure one extracted WAV and render review images")
    analyze.add_argument("id")
    analyze.set_defaults(func=analyze_item)

    analyze_all_parser = subcommands.add_parser("analyze-all", help="analyze every catalog item or one category")
    analyze_all_parser.add_argument("--category", default="all", choices=sorted(CATEGORIES | {"all"}))
    analyze_all_parser.set_defaults(func=analyze_all)

    edit = subcommands.add_parser("edit", help="correct metadata for an existing item")
    edit.add_argument("id")
    edit.add_argument("--title")
    edit.add_argument("--category", choices=sorted(CATEGORIES))
    edit.add_argument("--role")
    bpm_group = edit.add_mutually_exclusive_group()
    bpm_group.add_argument("--bpm", type=float)
    bpm_group.add_argument("--clear-bpm", action="store_true")
    edit.add_argument("--bars", type=int)
    edit.add_argument("--clip-start", type=float)
    edit.add_argument("--clip-end", type=float)
    edit.add_argument("--tags")
    edit.add_argument("--notes")
    loop_group = edit.add_mutually_exclusive_group()
    loop_group.add_argument("--loop", action="store_true")
    loop_group.add_argument("--no-loop", action="store_true")
    edit.set_defaults(func=edit_item)

    subcommands.add_parser("validate", help="verify IDs, files and source hashes").set_defaults(func=lambda _args: validate_library())
    subcommands.add_parser("list", help="print the current compact catalog").set_defaults(func=lambda _args: list_items())
    subcommands.add_parser("doctor", help="show library and media-tool availability").set_defaults(func=lambda _args: doctor())
    return command


def main() -> int:
    for stream in (sys.stdout, sys.stderr):
        if hasattr(stream, "reconfigure"):
            stream.reconfigure(encoding="utf-8", errors="replace")
    args = parser().parse_args()
    try:
        return int(args.func(args))
    except (OSError, ValueError, KeyError) as error:
        print(f"ERROR: {error}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
