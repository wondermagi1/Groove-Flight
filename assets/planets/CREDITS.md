# Planet textures

Creator / attribution: **Solar System Scope / INOVE**.

Source collection: https://www.solarsystemscope.com/textures/

License: **Creative Commons Attribution 4.0 International (CC BY 4.0)**.
https://creativecommons.org/licenses/by/4.0/

Original maps and source URLs, original file hashes and verified dimensions are recorded in `sources.json`. All maps are distributed with attribution under the license linked by the source collection. Some maps contain reconstructed/fictional unmapped regions as described by their publisher; these assets are game scenery, not authoritative scientific datasets.

BeatDrift changes: Earth normal/specular TIFFs were losslessly re-encoded to PNG without changing pixel dimensions or values. Original TIFFs are preserved under `source_art/planets`. Runtime imports generate mipmaps and BC7/BPTC VRAM compression. The game adds sphere projection, lighting, atmosphere, cloud displacement/shadows, specular response, night illumination, ring occlusion, color/exposure adjustment and parallax. Sources are not upscaled.

The `8k_jupiter.jpg` and `8k_saturn.jpg` downloads are actually4096×2048; the manifest records those dimensions rather than inferring resolution from filenames. Uranus/Neptune sources are2048×1024. Other maps include true8192-pixel-wide sources. The renderer supports native4K output across all eight worlds, independently of the maps' individual resolutions.
