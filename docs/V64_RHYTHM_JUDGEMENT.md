# V64 音游曲目与判定反馈

2026-11-18 · `0.64.0-rhythm-judgement` · 修改前远程备份 `8b81f21`

## 八颗星球的现用曲目

八首均是 Scott Buckley 以 CC BY 4.0 发布的完整配乐。项目采用音频起音、追踪拍点和延音分析生成谱面，游戏内按固定指法模板分配 J/K/L。当前曲库的选曲方向是电影配乐，曲目来源与 Phigros 曲库无关。下表是运行资源里的谱面统计，速度是分析估计值，每 20 秒的数量是从曲首计数。[曲目及许可清单](../audio/PLANET_MUSIC.json) · [分析结果](data-v64/SUMMARY.json)

| 星球 | 曲目 | 估算 BPM | 全曲琴块（长按） | 开场 20 秒 |
| --- | --- | ---: | ---: | ---: |
| 水星 | Filaments | 95.7 | 582（108） | 43 |
| 金星 | Helios | 73.8 | 437（102） | 25 |
| 地球 | Reverie | 123.0 | 453（54） | 40 |
| 火星 | Legionnaire (Original) | 86.1 | 343（42） | 46 |
| 木星 | Titan | 80.8 | 239（50） | 27 |
| 土星 | Cassini | 152.0 | 617（118） | 43 |
| 天王星 | Luminance | 107.7 | 521（65） | 36 |
| 海王星 | Omega | 71.8 | 295（73） | 24 |

同一套生成规则已经产生不同的开场密度。谱面里 77–600 个琴块（随曲目变化）以追踪拍点为依据。点位能否对上听感中最明确的重音，仍需逐曲实机核听。

## 判定表现

Phigros 的发行页将动态判定线与多类音符作为特色，官方 PV 介绍了随乐句变化的判定线、变速与多押。V64 借鉴判定与音乐的视觉联系，把短促变化放在 Groove Flight 的固定三键与赛博界面里。[Phigros 发行页](https://apps.apple.com/us/app/phigros/id1454809109) · [Pigeon Games 官方 PV](https://www.bilibili.com/video/BV1G4411h7VN/)

- 三段判定线随谱面已有的重音标记短亮，重音琴块加菱形切面。亮度变化使用校准后的歌曲时间。
- 路过有效判定窗口的提前按键即时给本轨一闪，判定、记分与提示音由原结算时刻产生。Perfect 命中用金色切角光框与短火花，长按键下的金线显示持续进度。同拍轨道可独立反馈。
- 八个原创合成打击音缩为 24–112 毫秒。普通音是短物理敲击感，Perfect 起音更亮，长按收尾和里程碑各有独立音型。实际里程碑替换当次判定音，继续走独立的「音游反馈」滑块。

[1080p 双轨 Perfect](screenshots/v64-perfect-1920.png) · [720p 长按](screenshots/v64-hold-1280.png)

[运行时音色试听](audio-v64/rhythm-feedback-audition.wav) 的顺序是 Perfect、Excellent、Good、Miss、长按头、长按尾、普通连击和 Perfect 奖励。

Forward+ 和 OpenGL Compatibility 各通过 62 项检查，另通过 459 项计分与平衡回归。[核验数据](data-v64/SUMMARY.json)
