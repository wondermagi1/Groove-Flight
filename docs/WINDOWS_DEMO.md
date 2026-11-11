# Windows Demo 0.49.0

本文主体记录历史V49交付，不代表当前V53工程。V53新增琴块、八首星球歌曲/谱面和任务，本轮没有重打包ZIP或覆盖展示PPT。当前`build_windows_demo.py`从`project.godot`读取版本，生成新的版本目录/暂存树，并携带逐星歌曲许可证；不会以V49名称打包新源码。下方V49两条重建/验证命令仅适用于切回对应历史基线时；`verify_windows_demo.py`仍专门验证历史V49包，后续新Demo需增加相应版本的全新解压/资源/EXE验证，不能复用旧报告冒充。

构建日期：2026-11-10。游戏代码基线：`34019f389dffb32757ec817995d9fa20e9b1d7c5`（V49）。打包前上传备份：`codex/backup-20261110-before-windows-demo` / `070745a89bcc98582d0bee1f840a118cac9ab3a4`，已核验远端SHA。

本机交付：`dist/GrooveFlight_Demo_v0.49.0_Windows_x64.zip`，282,269,543字节，约269.2MiB。SHA256：`107a26b6d0fe45e78622ff2123582119bb3981515b0664c849cb28767dfd75d9`。ZIP不进入源码Git；导出配置、构建/验证脚本、资源清单与校验结果进入版本库。

## 运行

完整解压，双击`GrooveFlightDemo.exe`。保留同目录的`.pck`、DLL、audio、native、tools及Credits文件夹，无需安装Godot或Python。默认Forward+；有图形兼容问题时使用`LaunchCompatibility.bat`。

主菜单→星球航图→选择星球→选择流派→确认出击。WASD/方向键移动，空格冲刺，E超载，Tab编排音序，Esc暂停，F11全屏/窗口。武器自动跟随音序器开火，商店不限时。

Demo独立使用`%APPDATA%/GrooveFlightDemo/`存档与音量配置，保留正常星球解锁流程。当前24种武器、三种流派、8颗星球、图鉴和自由作曲均保留；实弹开局+10、波末加点/一次性倍率、持续推进、第2波史诗/第3波传奇品质池、加强版Boss均来自V49，没有另改数值。

## 包装规则

`tools/build_windows_demo.py`从白名单复制运行资源到`work/demo-stage-v49`，再使用官方Godot4.7.2 Windows x86_64 release模板导出。包中不含编辑器、源码仓库、测试、PPT、原始参考录像、音频资料库和音色构建用SoundFont。现役、支援及历史作曲音源按运行时需求保留。

所有WAV仅在暂存树中指定`compress/mode=0`，保持PCM16/22050单声道输入契约；未修改源WAV、采样时长、音高、动态、音量或开火节奏。特别是晨羽、潮汐和流萤的24份作曲音源，原默认QOA导入会破坏直接PCM解码，导出已纠正。

Godot导出器生成的原生DLL与`native/crowd/crowd.gdextension`/DLL原路径一起保留。直接用OS文件读取的击杀反馈WAV放在外部audio目录；离线识谱EXE、Python/ONNX依赖和模型完整随包。Filaments及其他音乐、纹理、Godot与识谱依赖的许可证在Credits中。

## 验证

验证使用ZIP的**全新解压目录**，没有引用开发目录的音源或脚本。结果见[完整报告](data-demo-v49/VERIFICATION.json)、[包清单](data-demo-v49/BUILD.json)、[模板来源](data-demo-v49/TEMPLATE_SOURCE.json)。

- 361项PCK资源/API检查：24武器、192作曲音高+96动态音源、支援音源、339.88秒Filaments、全部5份战斗反馈、全部行星贴图/3D场景、原生内核、三种流派初始装备、156秒PCM编译和实际开火分派。
- 正式release EXE分别在Forward+与OpenGL兼容模式冷启动，退出码均0；进程映射确认加载了包内原生避让DLL。本机GPU为RTX4060Laptop，不能代表全部显卡。
- 包内离线识谱组件完成3秒自制音符音频解码和ONNX推理，返回6个估计音符；验证组件可用性，不等同于人工确认识谱准确率。

官方release模板不允许`--script`/`--main-pack`覆盖，因此资源/API检查使用同版本Godot宿主读取**实际交付PCK**；正式EXE启动另测，未把宿主检查冒称正式EXE脚本测试。自动`--quit-after`退出出现4个ObjectDB/2个资源清理提示，保留于报告；无启动/脚本错误。这些短检查不构成全程性能或人工音画验收。

## 重建

先按AGENTS要求完成上传备份。准备官方4.7.2的`windows_release_x86_64.exe`（来源与SHA见模板记录），然后：

```text
E:\Py\python.exe tools\build_windows_demo.py --template work\export-templates\windows_release_x86_64.exe
E:\Py\python.exe tools\verify_windows_demo.py
```

两脚本的`--engine`可指定同版本Godot宿主路径。验证工具另需宿主Python安装`psutil`，玩家无需。日志、暂存、解压测试和ZIP均在Git忽略的work/tests/dist目录；保存到版本库的报告位于`docs/data-demo-v49`。
