# Groove Core 授权音频资料库

本目录用于逐个整理用户录制或从 Demo 导出的《音序核心》参考资料。原始素材、加工版本和授权证明分开保存，避免同名覆盖，也避免 Godot 自动导入整批录像。

## 目录

| 目录 | 内容 |
| --- | --- |
| `raw/<id>/` | 原始录音或视频，保留原文件格式和名称 |
| `working/<id>/` | 归一化、裁剪、循环、分轨等加工版本 |
| `authorization/` | 原作者授权截图、邮件、许可文本或来源说明 |
| `incoming/` | 临时投递区；正式入库后会复制到 `raw/<id>/` |
| `catalog.json` | 唯一结构化主索引 |
| `catalog.csv` | 自动生成的表格，便于 Excel 查看 |
| `CATALOG.md` | 自动生成的可读索引 |

## 单条入库

每次只处理一个文件：

最简单的方式是把录音或 MP4 直接拖到项目根目录的 `AudioLibrary_Add.cmd`，按提示填写分类、用途和备注。

```powershell
python tools/audio_library.py add "D:\recordings\battle_kill_chain.wav" `
  --category kill `
  --role "normal_enemy_chain" `
  --title "普通连杀与落点" `
  --bpm 120 `
  --bars 4 `
  --tags "kill,drum,normal" `
  --notes "无解说，固定音量，第3-7波"
```

`--id` 可省略，脚本会生成如 `kill_001`。如果内容哈希已经存在，脚本会拒绝重复入库。

## 整批导入

录屏很多段时，可以按用途建立子目录，再把整个目录拖到项目根目录的 `AudioLibrary_ImportFolder.cmd`：

```text
recordings/
  music/
  weapon/
  kill/
  boss/
  ui/
```

选择分类 `auto` 时，子目录名会成为分类；每个文件仍得到独立 ID、原始副本和哈希记录。重复内容会跳过，坏文件会单独列在汇总里，不会中断其他文件。

等价命令：

```powershell
python tools/audio_library.py batch "D:\recordings" --category auto --recursive
python tools/audio_library.py doctor
```

视频也可以先登记：

```powershell
python tools/audio_library.py add "D:\recordings\boss.mp4" --category video --role "boss_phase_1_and_2" --bpm 120
```

没有 `ffprobe` 时，WAV 仍可读取采样率、声道、位深、时长、峰值和 RMS；MP4/MOV 只会保存文件与哈希，并标记待探测。需要实际提取时先导出 WAV 再入库。

## 加工版本

例如母带归一化和循环裁剪后：

```powershell
python tools/audio_library.py variant kill_001 "D:\work\kill_chain_loop.wav" `
  --label loop_clean `
  --notes "去静音头，0.00-3.84秒无缝循环，-14 LUFS近似归一化" `
  --mark-ready
```

如果本机已有 ffmpeg，可以从已登记的 MP4/MKV 中直接提取 48kHz 双声道 PCM：

```powershell
python tools/audio_library.py extract video_001 --label extracted_audio
```

## 校验与查看

```powershell
python tools/audio_library.py list
python tools/audio_library.py validate
python tools/audio_library.py analyze kill_001
python tools/audio_library.py analyze-all
```

`validate` 会检查重复 ID、重复内容、缺失文件及原始文件哈希。`analyze` 会生成 BPM、瞬态、频段、RMS/峰值因数和波形/频谱图，并为有画面的素材生成六帧接触表。`catalog.json` 是主记录；`catalog.csv`、`CATALOG.md` 和 `ANALYSIS.md` 每次入库或分析后自动重建。

`analyze`和`analyze-all`还会记录全段有效发声区间、每个区间的峰值/RMS、响度包络的主导周期和周期置信度。截取前应先核对完整波形与观测周期，再选择包含完整强弱的周期或有效瞬态。完整流程见`docs/AUDIO_PIPELINE.md`。

## 授权记录

当前状态是“用户确认原作者已授权”，见 `AUTHORIZATION.md`。授权证明文件应放入 `authorization/`，并在正式发行前再次核对授权范围。

## Godot 使用规则

`audio/library/.gdignore` 阻止原始资料被 Godot 自动导入。确认某个加工版本要进入游戏后，应复制到正式运行目录，例如 `audio/authorized/`，再在 `audio/CREDITS.md` 中登记具体用途；不要直接让游戏读取整个资料库。

大批 WAV/视频不建议直接提交普通 Git。若后续体积明显增大，应先确定 Git LFS 或外部资料库方案，再提交原始母带。

## V14 部分实装

截至 `0.14.0-sonic-codex`，7条来源记录中有6条已进入运行时：

- `music_menu`：菜单主题。
- `weapon_ballistic_volume_ramp`：轻/中/重实弹重音，以及3段直接截取的PCM16连续原声组。
- `weapon_crude_fire`：粗制火弹重音与“裂响火弹”0-7秒PCM16连续原声组。
- `events_enemy_collision`：碰撞、护盾、敌机生成三段独立事件。
- `weapon_power_thruster`：冲刺推进器。
- `music_uranus_amber`：10小节、20秒的天王星战斗与商店循环音乐。

`music_title` 是菜单主题的同源短摘段，不再单独加载。逐项来源与运行时对应关系见 `docs/AUDIO_SOURCE_MAP.md` 和 `audio/library/groove_core/runtime_mapping.json`。运行时清单见 `audio/authorized/AUTHORIZED_SFX.json`。当前4个录音原型的12个品质条目共用4段连续原声组，基础36个voice的实际PCM样本及哈希见 `audio/weapon_codex.json`。
