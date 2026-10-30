# 律航 V9 · 多声部音乐与武器验证

2026-10-30，Windows、Godot4.7.2、RTX4060 Laptop。测试使用`--beatdrift-test`和独立APPDATA；未写入真实玩家乐谱、设置或战绩。音频素材为测试程序原创合成的旋律、和弦与瞬态。

| 检查 | 结果 | 范围 |
| --- | ---: | --- |
| composer_score_review.gd |112/112|音符事务、8192容量、JSON、真实SMF0/1、踏板、量化、GM映射、保留鼓组、超过8轨合并及损坏输入 |
| composer_audio_review.gd |78/78|32种不同PCM、绝对音高、力度/时值/声像、静音独奏、原生循环/暂停/寻位、异步重建取消、WAV |
| composer_ui_review.gd |28/28|实际卷帘点击/删除/拖动、修改参数、武器选择、混音、720p/1080p布局 |
| composer_flow_review.gd |29/29|真实主页→工坊→后台音频→乐谱试飞→暂停返回→普通肉鸽回归 |
| audio_transcription_review.py |21/21|真实MP3解码与ONNX推理、旋律/多音/完整编配、原音高保留、源瞬态检测、稳定音无虚构鼓循环、无效文件 |
| audio_import_flow_review.gd |19/19|实际重建的独立EXE、默认完整编配、1080p/720p参数、候选试听确认、MIDI导出、取消及损坏文件保留 |
| orchestration_review.gd |33/33|原音符指纹、明确新增伴奏、8类职责、鼓组MIDI往返、旧草稿迁移、真实UI、不同鼓PCM、静音职责、真实试飞及光束关闭、SFX混音 |

合计320项通过。音频、UI与集成检查使用真实OpenGL音频/渲染路径；数据检查使用headless。最终编辑器导入另行检查资源和脚本。受限环境仍有系统证书库读取错误；最终运行没有GDScript运行异常。测试不等于真人听感验收或整条星球航线平衡测试。

## 直接相关证据

- 真实草稿只读审查：原来两个声部同为pulse，共1109音符；重新配器为5类职责，原音符ID、音高、起音、长度、力度逐个一致。未把该歌曲音符、标题或录音写入仓库。生产备份由玩家下次在游戏中执行编配时生成，本次未触碰真实草稿。
- 原创6秒和弦MP3：完整编配输出64音符，包含lead/bass/harmony/accent/kick/snare六类职责。实际EXE识别另一段原创旋律输出29音符、4轨，完成Godot试听→确认→导出。
- 新集成短试飞记录lead/bass/harmony/kick/snare/hat实际攻击；最大原生时钟起音误差约4.65ms。该数值仅是本机短样本，不是任意设备延迟保证。
- 长光束在持续音期间真实发射，并在note-off后停止；退出试飞清空持续攻击。实际AudioStreamPlayer音量对比确认试飞击杀声比普通模式低16dB。
- 查看过1080p工坊与试飞截图，声部列表可滚动，智能编配入口位于列表顶端。识谱与原稿仍隔离，补写伴奏选项默认关闭。
- 离线目录组件已由本地固定依赖重建，测试实际执行`tools/audio_recognizer/BeatDriftTranscribe/BeatDriftTranscribe.exe`，没有依赖系统Python或网络。

截图：`docs/screenshots/v9-orchestration-editor.png`、`v9-orchestration-trial.png`。原创8秒立体声示例可由测试重建至`work/v9-original-arrangement.wav`，不包含玩家歌曲。

## 验证边界

MP3的职责与鼓组是估计，未实现原曲音源分离，也没有人工听完用户歌曲。复杂人声、多乐器混音、转调或鼓组分类质量仍需玩家试听改谱。恒定速度与十六分量化限制保留。已验证短时真实试飞、取消/返回和数据上限，未重跑八星完整航线或进行数百音符同时发射的长期压力测试。新声音只进入自由作曲播放器，普通肉鸽预生成音色没有替换。
