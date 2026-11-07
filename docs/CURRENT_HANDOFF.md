# Groove Flight 当前接手说明

2026-11-07，工程版本 `0.21.0-fleet-spectacle`，开发分支 `codex/v21-fleet-spectacle`。远程仓库：https://github.com/wondermagi1/Groove-Flight 。后续每轮游戏修改前必须先上传Git备份并核验SHA，规则见根目录 `AGENTS.md`。

优先阅读 [方阵与圆阵的分布、追击、包围与建模](ENEMY_FORMATIONS_AND_ENCIRCLEMENT.md) 和 [V21版本说明](V21_FLEET_SPECTACLE.md)。这两份说明覆盖用户最新补充，较早的“只使用方阵”现已扩展为方阵与圆阵两类；未引入菱阵。

## 当前规则

- 音序器3轨×8格，每格0.125秒、一轮1秒。扫到武器起始格播放一次固定音色，同种武器不同实例允许尾音重叠。四拍强弱与自动旋律继续搁置，拍序状态条已移除。
- 原有12种武器全部保留，新增鎏金螺旋阵、虹织十字炮、星冕回旋阵，共15种。商店、试装、图鉴与显式作曲走同一可用名单。
- 普通敌机不射击，每0.5秒推进一次，以接触造成伤害。精英与Boss保留专属攻击。
- 每批同型号。红色预告后整批显形；方阵只决定出生排列，圆阵显形后先径向展开。约32%近端单位先攻，其他单位分向两翼并沿地图坐标绕行。
- 近端形成扇形、弧形压力，远端在视野外继续行动；每架有自己的路线进度、朝向与局部避让。舰体保留净空，分裂出生也寻找空区。
- 战场镜头缩放0.65；玩家绘制核心半径16，普通机16—18游戏单位，完整外形与核心半径不同。敌机采用带侧壁、顶面与固定世界受光的实例网格，营造2.5D俯视感。
- 后期大矩阵验证600架、25×24，普通敌机存活上限1024。扩大密度仍要结合性能和真人难度检查。
- 受击后蓝白色核心亮光与保护场衰减；实际保护时间仍为3秒。现有击杀低鼓、受击/拾取反馈继续保留。

## 主要实现入口

| 内容 | 文件 |
| --- | --- |
| 敌机密度与波次 | `scripts/planet_catalog.gd` |
| 方阵/圆阵出生、空区与预告 | `scripts/enemy_arrival.gd` |
| 个体近端进攻、径向展开、视野外绕行 | `scripts/enemy_maneuver.gd` |
| 半秒运动、局部净空与避让 | `scripts/contact_swarm.gd` |
| 实例舰体、侧壁与受光 | `scripts/fleet_batch.gd`、`shaders/fleet_depth.gdshader` |
| 战斗调度、生成与实际命中 | `scripts/main.gd` |
| 武器名单、参数与美术配置 | `scripts/arsenal_catalog.gd`、`scripts/weapon_visuals.gd` |
| 护盾效果 | `scripts/player_guard_render.gd`、`shaders/player_guard.gdshader` |

## 验证与后续

专项结果以 `docs/data-v21/SUMMARY.json` 为准，历史旧结果不能当成现版通过记录。参考预览位于 `docs/video-v21/`，为受控时间、无敌条件和指定配装下的视觉样本。还需要真人调整进攻比例、包围距离、批次间隔、混音和八星难度；没有宣称所有星球已完成真人验收或持续60FPS。

原接手页完整保存为 [V21前历史接手说明](archives/CURRENT_HANDOFF_BEFORE_V21.md)。旧四拍强弱约定、旧武器数量、录音原型和旧入场规则属于对应历史版本。
