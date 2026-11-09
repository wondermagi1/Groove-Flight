# V32：统一初始配装

2026-11-09，`0.32.0-fixed-starters`。所有行星、难度、舰体与起步预设的新一局统一使用以下两件武器。

| 武器 | 占用格 | 发声起始格 | 每轮发声时刻 | 音色 |
| --- | --- | --- | --- | --- |
| 流萤织雨 `firefly_rain` | A3、A4、A5 | A3 | 0.375秒 | 晶润中音竖琴 |
| 七彩折光匣 `scatter_prism` | B7、B8 | B7 | 1.125秒 | 珠光钢琴 |

音序仍为1.5秒一轮，两件武器均为2轮充能；原弹数、伤害、特效、音源与音量保留。先摆放指定武器，再将舰体/预设附带的非武器道具放到合法空位。正常购入、波次切换和玩家调整不会重新套用初始布局；重新出击时恢复上述配装。

入口为`arsenal_loadout.gd`的`LIVE_STARTER_LAYOUT`与受生产音源规则保护的`set_starters`。显式测试/作曲试射所用的非生产自定义配装分支保留。

[验证汇总](data-v32/SUMMARY.json)覆盖实际开局的8行星×2难度×4预设共64组合，轮换覆盖5舰体；另核对全部舰体、非武器道具保留、完整占格与仅首格发声。[原生界面截图](screenshots/v32-starter-layout.png)用于确认A3–A5及B7–B8。未进行完整战役平衡复测。

修改前备份`codex/backup-20261109-before-fixed-starters`已上传并核验，SHA `dcadfecdbfb4fa16f50d99c27becd103abbfc9dd`。当前开发分支为`codex/v32-fixed-starters`。武器索引继续维护于[特效与音频对应表](WEAPON_VFX_AUDIO_REFERENCE.md)。
