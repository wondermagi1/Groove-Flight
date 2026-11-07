# Groove Flight 品牌更名记录

记录日期：2026-11-04。

项目对外名称由“律航 · BEATDRIFT”统一更改为“Groove Flight”。Godot 项目名、窗口标题、互动主页、作曲文件筛选说明、当前说明文档、课程开发文档和桌面快捷方式均使用新名称。

## 已更名范围

- `project.godot` 的 `application/config/name`。
- 互动主页主标题与副标题。
- `Scenes/Main.tscn` 的根节点名称。
- 作曲保存/打开对话框中的“Groove Flight 乐谱”。
- README、版本说明、测试报告和交接文档中的当前项目名称。
- 桌面与“桌面/游戏开发”目录中的快捷方式名称和说明。
- 第 6 周课程开发文档的文件名、标题和页脚。

## 兼容标识

以下标识继续保留旧名称，用于读取已有数据和第三方工具，不属于玩家界面品牌：

- 当前开发检出目录 `outputs/BeatDrift/`：避免破坏 Codex 工作区、现有脚本和快捷方式目标；游戏与快捷方式对外显示名称均为 Groove Flight。
- `%APPDATA%/BeatDriftPrototype/`：旧设置、曲谱草稿和星球进度目录。
- `beatdrift-score`：已有 JSON 乐谱格式标识。
- `BEATDRIFT1:`：已有 MIDI 私有元事件前缀。
- `BeatDriftTranscribe`：本地音频识别器的现有可执行文件与目录名称。
- `--beatdrift-test`：旧测试启动参数；新参数为 `--grooveflight-test`，两者均可用。

改动名称不会迁移或删除现有存档。后续如果再次更换内部格式，需要单独提供版本迁移和回退测试。
