# 本地音频识谱实现

入口为自由作曲工坊的“识别 MP3”。Godot负责选择文件、参数、进度、取消、草稿试听与确认导入；独立进程负责解码、模型计算和音符整理。成功结果先保存在候选数据中，原曲谱直到确认导入才改变。

## 模型与组件

- [Spotify Basic Pitch](https://github.com/spotify/basic-pitch)：使用官方Apache-2.0 ONNX模型。固定提交`fa5997af0a8210982619003269994a1be25eddf3`；模型SHA256为`2c3c1d144bfa61ad236e92e169c13535c880469a12a047d4e73451f2c059a0ec`。
- [miniaudio](https://github.com/irmen/pyminiaudio)：本地流式解码与单声道重采样，限制文件、起点和读取长度。
- [ONNX Runtime](https://github.com/microsoft/onnxruntime)：CPU推理，限制为2个内部线程，不要求CUDA/GPU。
- NumPy：谱通量速度建议、音符选择、时值整理和网格量化。
- Python3.13与PyInstaller：打包为Windows x64目录组件。运行时无需安装Python或联网。

模型仅输出音高/起音概率。BeatDrift的音符分组、旋律优先选择、恒速估计、JSON协议与编辑器量化在`tools/transcribe_audio.py`。按照官方输入窗口、补零和重叠协议推理，未引入整套Basic Pitch Python依赖。

主要文件：

| 文件 | 用途 |
| --- | --- |
| scripts/audio_transcriber.gd | 非阻塞进程启动、进度轮询、超时、取消与返回值校验 |
| tools/transcribe_audio.py | 音频到候选乐谱的源代码 |
| tools/build_audio_recognizer.py | 在work隔离环境下载并校验wheel，固定版本，打包组件及收集许可 |
| tools/models/basic_pitch.onnx | 原模型，约230KB |
| tools/audio_recognizer/BeatDriftTranscribe/ | 约98MB独立组件、Python运行时、推理/解码库及内嵌模型 |
| third_party/ | 模型、运行时与依赖许可及构建版本 |

目录打包避免每次启动都往系统临时目录解压DLL；每个识别请求只有一个工作进程，取消时只终止该进程。Godot通过独立任务目录中的请求、原子写入进度与结果文件通信。默认使用`user://transcription`，测试使用项目`work/transcription-jobs`。

## 构建与分发

本机组件已经构建。需要重建时，在Windows x64、Python3.13下运行：

```powershell
python tools/build_audio_recognizer.py
```

构建阶段需要网络，仅从PyPI下载匹配当前Python的wheel并校验SHA256，模型取自固定GitHub提交。依赖安装在`work/audio-build/venv`，不改系统Python包。版本记录在`third_party/audio-recognizer/build-versions.json`。`--test-tools --dependencies-only`会额外准备仅供原创MP3测试用的lameenc编码器。

Godot导出时，需将整个`tools/audio_recognizer`目录及`third_party`许可目录复制到游戏可执行文件旁，保持相对路径。该目录有`.gdignore`，不会被当作Godot资源自动塞入PCK；缺失时工坊会明确提示组件缺失。当前已验证本地工程运行，未声称验证所有平台导出包。

## 能力边界

输入单文件≤128MB，片段≤600秒；输出仍须通过乐谱模型的256小节、8192音符、音域与十六分网格验证。速度为谱通量自相关的近似建议，可手动覆盖。旋律优先选择主要音高，不能把混音中的歌手声音可靠分离出来；多音模式按音域分轨，也不识别乐器身份。V9默认完整编配：按音域、时值与同拍和弦分配最多5类定音声部；1024采样窗/256步长的低、中、高频瞬态检测产生最多3类鼓组估计，FFT分批计算限制内存。它不是原曲分轨或乐器识别，可能把拨弦误判成鼓点。

识谱结果是机器草稿，不保证与原曲逐音一致。尚未测量商业歌曲、人声/复杂混音转谱质量，未实现歌词、歌名识别或音源分离。
