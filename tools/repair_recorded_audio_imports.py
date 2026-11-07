"""Force recorded weapon WAVs to remain raw mono PCM16 at 22050 Hz in Godot."""

from pathlib import Path
import hashlib
import wave


ROOT = Path(__file__).resolve().parents[1]
NOTES = ROOT / "audio" / "arsenal" / "notes"


def import_sidecar(path: Path) -> str:
    source = "res://" + path.relative_to(ROOT).as_posix()
    digest = hashlib.md5(source.encode()).hexdigest()
    imported = f"res://.godot/imported/{path.name}-{digest}.sample"
    return (
        '[remap]\n'
        'importer="wav"\n'
        'type="AudioStreamWAV"\n'
        f'path="{imported}"\n\n'
        '[deps]\n'
        f'source_file="{source}"\n'
        f'dest_files=["{imported}"]\n\n'
        '[params]\n'
        'force/8_bit=false\n'
        'force/mono=false\n'
        'force/max_rate=false\n'
        'force/max_rate_hz=44100\n'
        'edit/trim=false\n'
        'edit/normalize=false\n'
        'edit/loop_mode=0\n'
        'edit/loop_begin=0\n'
        'edit/loop_end=-1\n'
        'compress/mode=0\n'
    )


def main() -> None:
    files = sorted(NOTES.glob("rec_*.wav"))
    if len(files) != 32:
        raise ValueError(f"expected 32 recorded weapon WAVs, found {len(files)}")
    for path in files:
        with wave.open(str(path), "rb") as recording:
            if (
                recording.getnchannels() != 1
                or recording.getsampwidth() != 2
                or recording.getframerate() != 22050
            ):
                raise ValueError(f"recorded weapon WAV must be mono PCM16/22050: {path}")
        path.with_suffix(".wav.import").write_text(import_sidecar(path), encoding="utf-8", newline="\n")
    print(f"REPAIRED_RECORDED_AUDIO_IMPORTS={len(files)}")


if __name__ == "__main__":
    main()
