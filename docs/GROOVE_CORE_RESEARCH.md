# 《音序核心》公开玩法研究与《律航》v2参考

研究日期：2026-10-28。参考来源包括Steam官方商店、官方开发公告、开发者日志，以及用户提供的本地Demo清单。研究未启动、解包或提取参考游戏资源，也没有读取到其游戏逻辑源码。本报告的建议参数属于《律航》，不代表参考游戏的内部数值。

## 1. 已证实的核心玩法

《音序核心》是太空俯视角节奏弹幕肉鸽：玩家在音序器上编排道具，武器随拍自动触发，敌人也随节奏行动；弹幕强调几何秩序。商店页所列“200余道具、8种飞船”属于尚未发行完整版本的介绍，不能据此认定当前Demo全部具备。[Steam官方商店](https://store.steampowered.com/app/4668140/Groove_Core/?l=schinese)

开发者说明：武器道具生成旋律，非武器道具加入鼓点或改变音色；弯曲弹道甚至对应音高变化。这说明它追求的是“构筑改变音乐”，而不只是让预录歌曲伴随射击。团队还刻意约束道具设计，以便强化后仍保留数学美感。开发者称从Godot迁移到Unreal后，借助Mass系统支持同屏数千敌人；这是开发者的技术陈述，未在本次研究中实测。[开发者日志](https://cx10.itch.io/dischead/devlog/1664671/announcing-groove-core-originating-from-dischead)

### 飞船与驾驶员

| 已确认内容 | 对设计的含义 | 证据边界 |
| --- | --- | --- |
| Demo公告明确列出Shuka、Midori、Aoi三位驾驶员 | 角色选择已经进入实际Demo | 本次未核实Shuka与Midori的完整被动与属性 |
| Aoi为Power型，冲刺结束恢复生命 | 驾驶员的能力会改变操作收益 | 公告没有写恢复量、冷却或触发限制 |
| Aoi的Swordfish随当前移动方向转向，三个挂点全部朝前 | 飞船差异包含射向与挂点布局 | 不能据此推断其他飞船的完整挂点规则 |

以上均见[Demo v0.6.26官方公告](https://steamstore-a.akamaihd.net/news/externalpost/steam_community_announcements/1846651706691339)。最新补丁还说明驾驶员具有Ballistic、Energy、Power、Support四类主属性，对应道具随之增强。[Demo v0.6.29.1官方公告](https://steamstore-a.akamaihd.net/news/externalpost/steam_community_announcements/1847920302230675)

### 音序器、商店和组合

官方补丁可确认，道具存在不同占格长度、充能要求、同轨效果与相邻效果。例如有道具占3格或5格，有道具影响相邻非武器的充能，也有道具把同轨已经射出的弹丸转化为导弹。因此其策略不仅是把武器放进单格，还涉及空间、时间与前后顺序。[v0.6.25](https://steamstore-a.akamaihd.net/news/externalpost/steam_community_announcements/1846651706677201)、[v0.6.18.1](https://steamstore-a.akamaihd.net/news/externalpost/steam_community_announcements/1844115010489210)

Demo具备购买、刷新、合并升级、回收和库存；新补丁支持在商店或库存预览道具实际效果。生成权重会照顾玩家主属性，也降低买不起的道具出现概率。这些是减少无效选择的设计，而不仅是随机给奖励。[v0.6.21.1合并提示](https://steamstore-a.akamaihd.net/news/externalpost/steam_community_announcements/1844751498220804)、[v0.6.25商品权重](https://steamstore-a.akamaihd.net/news/externalpost/steam_community_announcements/1846651706677201)、[v0.6.29.1预览与回收](https://steamstore-a.akamaihd.net/news/externalpost/steam_community_announcements/1847920302230675)

### 波次、精英和高密度

- v0.6.25明确提到“木星第7波精英”，并调整为先进入中央再左右移动。因此不能把用户截图中的“第3/6波”理解成全游戏固定只有6波。[官方补丁](https://steamstore-a.akamaihd.net/news/externalpost/steam_community_announcements/1846651706677201)
- 同一补丁降低拥挤敌群朝玩家集体冲锋的最高速度，并减弱挤出力朝玩家的分量，说明大量敌人需要处理拥挤与公平性，不能只提高数量。[官方补丁](https://steamstore-a.akamaihd.net/news/externalpost/steam_community_announcements/1846651706677201)
- 危机模式会提高敌群压力；v0.6.26把危机等级带来的敌人数量增幅封顶200%，并对有效收益等级设上限。[官方补丁](https://steamstore-a.akamaihd.net/news/externalpost/steam_community_announcements/1846651706691339)
- 最新Demo让敌人更倾向于从飞船朝向的方向生成；波次结束后仍留短暂收集星尘的窗口；商店会提前提醒下一场为Boss战。[v0.6.29.1](https://steamstore-a.akamaihd.net/news/externalpost/steam_community_announcements/1847920302230675)、[v0.6.26](https://steamstore-a.akamaihd.net/news/externalpost/steam_community_announcements/1846651706691339)

**未查到的具体数值：**各星球实际完整波数、每波精确刷怪总数、同屏上限、生成间隔、最终Boss生命、星尘掉率、各飞船全部参数。没有通过截图中的可见数量或资源名反推这些数据。本地程序也不能视为可编辑源工程。

### 视觉与声音的节制

v0.6.27缩短精英/Boss死亡闪光、修改范围攻击预警、增加飞船位置高亮；v0.6.29.1增加降低Bloom选项，并降低某爆炸道具的亮度提升。这些改动说明强烈反馈仍需服务可读性。对应《律航》应保持白色主机、敌弹和场景之间的对比，避免用长时间闪白、大片烟雾制造假繁华。[v0.6.27](https://steamstore-a.akamaihd.net/news/externalpost/steam_community_announcements/1847286114027555)、[v0.6.29.1](https://steamstore-a.akamaihd.net/news/externalpost/steam_community_announcements/1847920302230675)

## 2. 本地安装目录只读核对

位置：`E:/SteamLibrary/steamapps/common/Groove Core Demo`。对应Steam清单`E:/SteamLibrary/steamapps/appmanifest_4703050.acf`记录AppID 4703050、BuildID 26268744、安装体积487230395字节。它是打包后的Unreal Shipping发行目录。Steam公告称最近版本为v0.6.29.1；**未从可执行文件内部确认其语义版本，BuildID与公告版本不作强制等同。**

| 清单中可见内容 | 可以说明 | 不能说明 |
| --- | --- | --- |
| `Player/BP_PlayerShip_StandardShip`、`CircleShip`、`Boomerang` | 存在不同船型资产分类 | 不能把名称直接对应到角色、外形或参数 |
| `Sequencer/BP_SequencerComponent`、`BP_SequencerInputComponent` | 存在音序器相关资源 | 不能还原其执行顺序或充能公式 |
| `MetaSound/MS_SequencerRhythemPlayer` | 存在MetaSound节奏播放资产 | 不能获知合成器实现或音阶规则 |
| `Battle/RandomEncounter/...GenerateBatchEnemy`、`...GenerateBatchHunterEnemy`、`...CargoShip` | 资源分类涉及批量敌群和遭遇 | 不能直接证明某遭遇当前可触发及其概率 |
| `LevelSequencer/LS_EnterArena`、`LS_WinAndLeaveArena` | 存在进入与离开竞技场演出资产 | 不能证明完整关卡流程 |

依据为安装目录已有的`Manifest_UFSFiles_Win64.txt`和`Manifest_NonUFSFiles_Win64.txt`，只读文本清单。没有解包`.pak/.utoc/.ucas`、提取模型/音效、反编译或改写安装文件。Engine目录的插件名不作为实际玩法证据。

## 3. 对《律航》v2的具体落地建议

以下均是我们的设计，不是参考游戏复刻数据。

1. **三种原创船型，保留白色六边核心。**均衡型使用紧凑翼组；高速型使用后掠双翼；重装型使用宽体装甲与炮台。差异体现为移动、耐久、挂点位置及攻击朝向，不能只换色。驾驶员通过小幅明确被动改变冲刺、拾取或超载收益，说明中展示实际数值。
2. **六种可辨认敌机。**基础群机负责密度，装甲机迫使集中火力，射手机制造可读弹幕，突进机提前锁定方向，分裂机提供连锁清群，哨戒机形成局部威胁。每种应有不同轮廓、速度、耐久和出手节拍。
3. **从零散刷怪升级为随拍编队。**让批量生成出现在音乐拍点，并使用V形、楔形、弧形、双列、小群等不同队形；大部分从主机前方进入，少量侧翼形成包围。不能在玩家身旁突然生成。碰撞挤压和分裂产生的新个体同样受上限控制。
4. **十波原创密度曲线。**`scripts/wave_plan.gd`提供9个生存波和最终Boss；普通波时长26—42秒，总生成预算110—620，累计3130架计划敌机，第4/8波精英。160/300/500同屏上限是分阶段目标，实际需要压测；预算是整波计划数量，不等同于瞬间同屏数量，也不承诺未经实测的帧率。
5. **音乐是火力时序的唯一依据。**继续使用实际音频播放时钟触发武器和编队，避免另开计时器导致漂移。保持既有音序器编辑后相位恢复规则。后续非武器模块可以对应节奏层或音色，但必须实际实现再对外宣称。
6. **强化后的美感来自结构。**通过相位偏移、放射角度、连续轨迹、有限色组和短促命中碎片，保持弹幕有秩序。敌弹颜色应与友弹分离，主机与危险预警始终可见。分裂、链击和爆破必须有预算。
7. **先交付可测的闭环。**船型/驾驶员选择→编排→高密度随拍生存→三选一调整→精英/Boss→结算。暂不加入庞大主线、农场或长期技能树。商店、多格道具、独立充能可以后续逐项制作，不能因为参考作品具备就写成当前已经完成。

### 验证重点

- 自动跑局记录实际峰值敌机、敌弹、友弹、刷怪预算兑现率及完整一局结果。
- 至少实际测试三种船型，确认炮口跟随船体且射击方向正确，切换不会复制模块或清空编排。
- 同一配置重复运行，拍点与战斗事件一致；暂停、编辑和恢复不产生补发洪峰。
- 分裂敌机、退场、精英和Boss均有清晰的生成/销毁统计；未击杀撤退不能算击杀奖励。
- 验证胜利与失败、重复重开、全屏布局及旧本地设置兼容。自动无敌跑局只证明流程，不能替代真人手感与难度验收。

本报告只核实公开资料和安装清单；未游玩参考Demo，也未声称掌握其源码或精确数值。
