"""Prepare mipmapped VRAM texture imports before Godot's first scan."""
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
for path in (ROOT/'assets/planets').iterdir():
    if path.suffix not in ('.png','.jpg'):
        continue
    config=path.with_name(path.name+'.import')
    if config.exists():
        continue
    source='res://'+path.relative_to(ROOT).as_posix()
    config.write_text('[remap]\nimporter="texture"\ntype="CompressedTexture2D"\n\n[deps]\nsource_file="'+source+'"\n\n[params]\ncompress/mode=2\ncompress/high_quality=true\nmipmaps/generate=true\nprocess/size_limit=0\ndetect_3d/compress_to=0\n',encoding='utf-8')
    print(path.name)
