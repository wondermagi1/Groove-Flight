# Basic Pitch model

Copyright 2022 Spotify AB. Apache License 2.0; full license is in `LICENSE`.

Source: https://github.com/spotify/basic-pitch

Pinned revision: `fa5997af0a8210982619003269994a1be25eddf3`.

Model: `basic_pitch/saved_models/icassp_2022/nmp.onnx`, stored without model modification as `tools/models/basic_pitch.onnx` and embedded in the local recognizer executable.

`tools/transcribe_audio.py` uses the published waveform shape, padding and overlap protocol. It provides its own bounded audio decoding, note grouping, approximate melody selection, tempo suggestion, editor quantization and JSON process protocol. It does not bundle Spotify's full Python package or claim instrument/source separation.
