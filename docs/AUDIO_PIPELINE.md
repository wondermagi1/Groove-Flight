# Groove Flight 录制音频处理操作手册

本手册规定从玩家录制视频到游戏运行音频的完整流程。任何录音都必须先入库、提取完整音轨、分析全段，再按完整周期或有效瞬态截取；不得用未查看波形的时间点直接作为运行文件。

## 1 原始文件入库

将每次录屏按用途命名。原始视频或音频统一通过脚本入库，不直接把录像放进`audio/authorized`。

单文件：

```powershell
python tools/audio_library.py add "D:\recordings\weapon_crude.mp4" `
  --id weapon_crude_fire `
  --title "武器粗制火弹音效" `
  --category weapon `
  --role "crude_fire_projectile" `
  --tags "weapon,crude,fire" `
  --notes "玩家录制；包含完整强弱周期"
```

批量：

```powershell
python tools/audio_library.py batch "D:\recordings" --category auto --recursive
```

入库会复制原文件到`raw/<catalog_id>/`，并记录文件名、大小、格式、声道、采样率、时长和SHA256。授权证明放在`authorization/`。

## 2 提取完整音轨

视频入库后先提取完整PCM，不直接开始切片：

```powershell
python tools/audio_library.py extract weapon_crude_fire --label extracted_audio
```

结果位于`working/<catalog_id>/extracted_audio.wav`，统一为PCM16、48kHz、双声道。原始视频仍保留在`raw/`。

## 3 全段分析

分析单条：

```powershell
python tools/audio_library.py analyze weapon_crude_fire
```

分析全部资源：

```powershell
python tools/audio_library.py analyze-all
```

每条记录会写入`catalog.json`，并生成：

- `analysis/<catalog_id>/waveform-spectrum.png`：完整波形、起音和频谱。
- `analysis/<catalog_id>/contact-sheet.jpg`：六个时间点的视频画面对照。
- `active_intervals`：全段有效发声区间、峰值和RMS。
- `onset_times_seconds`：瞬态起音位置。
- `estimated_bpm`与`tempo_confidence`：节拍估计和置信度。
- `dominant_period_seconds`与`period_confidence`：响度包络的主导周期。

必须同时检查数值、完整波形和画面接触表。自动BPM只作为候选，不能代替人工确认。

## 4 截取规则

### 连续音乐

1. 先确认`dominant_period_seconds`、BPM和乐句长度。
2. 选择包含完整强弱的周期或整句，而不是任意取几秒。
3. 循环点放在相同节拍位置，首尾加短淡化防止爆音。
4. 以固定增益或统一响度归一化处理，不能分别把强弱片段拉到同一音量。
5. 用目标帧率无关的`AudioStreamPlayer`循环播放，并在暂停、编辑器和设置状态暂停。

天王星音乐的实际处理：

- 源片约119.68 BPM，自动主导周期接近节拍级。
- 取`0.32-20.32秒`，整理成10小节、120 BPM、20.000秒循环。
- 首尾8ms淡化，实测边界采样差为0。
- 生成`uranus_amber_loop.ogg`，作为所有星球共用的战斗/商店循环音乐。

### 武器、命中和事件

1. 在`active_intervals`中选择完整瞬态区间。
2. 起音前保留5-15ms，衰减结束后保留20-80ms；不得截在瞬态中间。
3. 检查切出文件的峰值不是静音；当前流程以峰值高于约-35 dBFS为最低有效标准。
4. 若源素材存在强弱变化，保留相对音量；需要进入游戏的武器原声直接截取连续组，不在游戏内按拍拆成8段。
5. 每个加工版本通过`variant`登记，不覆盖原始提取音轨；新增武器原声同时在`audio/library/groove_core/analysis/recorded-weapon-groups.json`记录源起止、哈希、波形和PCM规格。

粗制火弹的错误示例：原片`3.00秒`处于两段声音之间，后处理把静音归一化，得到约-91 dBFS。全段分析显示主导周期为2.000秒，强击在`3.08-3.66秒`，弱击在`2.08-2.24秒`。修正后：

- 检查图：`audio/library/groove_core/analysis/weapon_crude_fire/group-0-7s.png`。
- 微周期：`1.00-3.00秒`，保留一强一弱。
- 完整素材组：`0.00-4.00秒`，包含四个连续事件；0-7秒中可看到该组再次开始，因此不能把单一声响当成整件武器。
- 运行强击：`3.05-3.72秒`，替换原静音文件。
- 裂响火弹：直接播放`0.00-6.00秒`连续原声组，恰好包含3组2秒强-弱周期，不内部分段、不做升降调。

第一组的四个事件为：

| 组内次序 | 源起止 |
| --- | --- |
| 1 | `0.08-0.24秒` |
| 2 | `1.08-1.66秒` |
| 3 | `2.08-2.24秒` |
| 4 | `3.08-3.66秒` |

约`4.08秒`开始下一组，因此`0.00-4.00秒`可以作为重复边界清晰的完整组。

### 事件组合录音

敌机撞击、护盾和敌机生成来自同一段23秒录音。先按瞬态分组，再分别截取：

| 事件 | 源区间 | 运行文件 |
| --- | --- | --- |
| 碰撞 | 约4.95秒 | `event_collision.ogg` |
| 护盾 | 约9.90秒 | `event_shield.ogg` |
| 生成 | 约19.05-21.14秒 | `event_spawn.ogg` |

### 强弱递进录音

`weapon_ballistic_volume_ramp`全段检出52个有效事件，主导周期1.000秒。运行轻、中、重音分别来自：

| 强度 | 有效源区间 | 运行文件 |
| --- | --- | --- |
| 轻 | `0.60-0.98秒` | `weapon_ballistic_light.ogg` |
| 中 | `22.10-22.48秒` | `weapon_ballistic_medium.ogg` |
| 重 | `47.10-47.86秒` | `weapon_ballistic_heavy.ogg` |

当前把原本拆成轻、中、重的三段合并为一件“实弹连奏炮”，只播放一个完整十六秒周期：

| 武器 | 连续源区间 | 运行文件 |
| --- | --- | --- |
| 实弹连奏炮·普通/稀有/珍贵 | `0.58-16.58秒` | `weapon_ballistic_cycle_16s.wav` |

当前两个原声组（裂响火弹、实弹连奏炮）只经过`ffmpeg -c:a pcm_s16le`截取，不做淡化、增益、归一化、重采样、内部分段或变调。普通、稀有、珍贵三档共用原声文件，只改变战斗数值。

## 5 登记加工版本

```powershell
python tools/audio_library.py variant weapon_crude_fire `
  "D:\processed\crude_strong.wav" `
  --label runtime_crude_strong_v2 `
  --role crude_fire_runtime_strong `
  --notes "全段分析后从3.05-3.72秒强击截取" `
  --mark-ready
```

`catalog.json`是主记录；`catalog.csv`和`CATALOG.md`由脚本更新，不手工改。

## 6 接入Groove Flight

根据用途选择入口：

| 用途 | 运行时位置 | 接入方式 |
| --- | --- | --- |
| 菜单与关卡循环音乐 | `audio/authorized/` | `main.gd`中的`menu_music`或`planet_music` |
| 一次性事件 | `audio/authorized/` | `main.gd`的`sound()`与`event_mixer.gd` |
| 武器录音重音 | `audio/authorized/` | `main.gd._play_weapon_reference()` |
| 录音武器连续原声组 | `audio/authorized/*_group.wav` | `main.gd`的`RECORDED_WEAPON_GROUPS`，按武器独立播放器读取；图鉴读取同一路径 |

每增加一个运行文件，都要同步更新：

- `audio/authorized/AUTHORIZED_SFX.json`：运行文件、来源ID、截取点和用途。
- `audio/library/groove_core/runtime_mapping.json`：原始游戏用途、源文件、处理链和全部运行文件。
- `docs/AUDIO_SOURCE_MAP.md`：人工可读的一一对应表。
- `audio/CREDITS.md`：授权和使用说明。
- `audio/weapon_codex.json`：如果声音属于新武器，记录8个样本的路径、字节数和SHA256。
- `audio/library/groove_core/analysis/recorded-weapon-groups.json`：记录连续原声组、源起止、PCM规格、峰值/RMS和波形图。

## 7 验证

```powershell
python tools/audio_library.py validate
python tools/run_v11_tests.py v12_audio_review
python tools/run_v11_tests.py composer_audio_review
python tools/run_v11_tests.py weapon_codex_review --gpu --forward
```

交付前必须确认：

- 源文件哈希和运行文件均存在。
- 截取音段不落在静音区。
- 循环时长与游戏节拍一致。
- 图鉴试听不播放静音样本。
- 录音原声组和录音重音层在武器图鉴中可区分。
- 正式导出包含`audio/authorized/*`和`audio/arsenal/notes/*.wav`。

## 8 当前七条来源的分析结论

| 来源 | 全段时长 | 主导周期 | 分析结论 |
| --- | ---: | ---: | --- |
| `music_menu` | 224.70秒 | 4.00秒 | 长菜单音乐；运行时保留整段循环主题 |
| `events_enemy_collision` | 23.13秒 | 6.20秒 | 三个主要事件簇，分别切为碰撞、护盾和生成 |
| `weapon_power_thruster` | 11.56秒 | 1.00秒 | 周期推进瞬态，选择起音段作为冲刺声 |
| `music_uranus_amber` | 21.23秒 | 节拍级 | 取20秒完整10小节循环，用于天王星战斗 |
| `weapon_crude_fire` | 23.06秒 | 2.00秒 | 一强一弱重复；重建重音和8个派生武器样本 |
| `weapon_ballistic_volume_ramp` | 49.37秒 | 1.00秒 | 连续轻中重递进；用于实弹重音和3件派生武器 |
| `music_title` | 38.25秒 | 0.58秒 | 前9.34秒静音，之后音乐与菜单主题同源；不重复加载 |
