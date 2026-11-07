# Groove Flight V12–V15 修改记录与 GPT 交接表

记录日期：2026-11-02，持续更新至2026-11-04。当前版本：`0.15.0-recorded-first`。修改基线：`ca52f54`（`codex/v11-harmonic-expedition`）。本表记录当前工作区实际完成的代码、验证、证据和未完成项。当前改动尚未提交 Git。

## 需求来源

本轮同时参考用户提供的两份原项目升级文档（原始文件名仍含旧名称）、《音序核心》试玩视频与现有实机分析。优先级从“继续增加内容”调整为：先让配装改变节拍、声音和空间玩法，并让敌群与击杀反馈提供可读节奏。

用户补充的直接体验要求是：音乐要更带感、更有节奏；击败敌人要有爽快的鼓点；部分重武器应表现为四拍一重音、其余三拍轻音；保留并强化音轨和武器触发机制。

## 修改记录表

| ID | 状态 | 修改 | 主要文件 | 行为结果 | 验证 |
| --- | --- | --- | --- | --- | --- |
| V12-01 | 已完成 | 编队共享指挥状态，首个成员成为领航机 | `scripts/formation_motion.gd`、`scripts/main.gd` | 领航机带金色标记；击破后幸存敌机依次进入“失序”与“重整”，运动连续，不会瞬移 | `v12_tactical_review`、`v11_upgrade_review` |
| V12-02 | 已完成 | 领航损失写入战斗回执 | `scripts/main.gd`、`scripts/combat_receipt.gd` 现有统计 | `formation_command_breaks` 可追踪，不伪造击杀 | `v12_tactical_review` |
| V12-03 | 已完成 | 商店试射加入三轨射程覆盖层 | `scripts/arsenal_lab.gd`、`scripts/main.gd`、`scripts/arsenal_screen.gd` | A/B/C 轨分别以青、金、紫显示真实射程/扇面/环形覆盖；仅沙盒显示 | `v12_tactical_review`、`v12_visual_review` |
| V12-04 | 已完成并扩展 | 重武器四拍节奏 | `scripts/arsenal_loadout.gd`、`scripts/main.gd` | V12最初只给导弹、轨炮、雷荚增加三拍轻音；V12-28已扩展为所有武器的五类节奏分工 | `v12_tactical_review`、`arsenal_loadout_review` |
| V12-05 | 已完成并扩展 | 武器详情显示节奏语义 | `scripts/arsenal_screen.gd` | 详情现在显示实际节奏名称、四拍百分比强度、充能档位与“未完成充能只发声”说明 | `arsenal_ui_review` |
| V12-06 | 已完成 | 普通模式程序鼓组与底鼓侧链 | `scripts/music.gd`、`scripts/main.gd`、`scripts/ui.gd` | 120 BPM 四拍底鼓、二四拍军鼓、十六分踩镲、低音脉冲、第四小节填充；可独立调“节拍鼓组” | `arsenal_audio_review`、`v12_audio_review` |
| V12-07 | 已完成 | 连杀鼓填充 | `scripts/event_mixer.gd` | 普通连杀按45ms聚合并排成底鼓/军鼓/踩镲；装甲机使用双层重击；低刺激模式减少填充层数 | `v12_tactical_review`、`v12_audio_review` |
| V12-08 | 已完成 | 版本与可试听证据 | `project.godot`、`docs/audio-v12/`、`docs/screenshots/v12-*.png` | 工程版本更新为 `0.14.0-sonic-codex` | 文件存在、峰值/RMS与非静音检查 |
| V12-09 | 已完成 | 扩大真实弹道与击杀反馈 | `scripts/weapon_render.gd`、`shaders/weapon_trail.gdshader`、`scripts/fx.gd`、`scripts/main.gd` | 每条真实子弹增加更长的彩色 GPU 光带和更大光芯；普通击杀增加方向性短闪、环形亮圈和更多碎片；连杀最多10级局部增强 | `weapon_vfx_review`、`v12_visual_review` |
| V12-10 | 已完成 | 建立授权音频逐步整理库 | `tools/audio_library.py`、`AudioLibrary_Add.cmd`、`AudioLibrary_ImportFolder.cmd`、`audio/library/groove_core/` | 支持单文件或整文件夹入库，记录哈希、格式、采样率、声道、位深、时长、峰值、RMS、BPM 和加工版本；重复内容拒绝入库 | 临时库实测2条批量导入、重复拦截、加工版本关联和哈希校验全部通过 |
| V12-11 | 已完成 | 接入授权菜单主题 | `audio/authorized/menu_theme.ogg`、`scripts/main.gd` | 标题、都市、机库和星球航图播放经响度归一化的菜单主题；进入战斗、商店和作曲自动停止 | `v12_audio_review` |
| V12-12 | 已完成 | 对照首批视频重做护盾反馈 | `shaders/weapon_effect.gdshader`、`scripts/fx.gd`、`scripts/main.gd` | 护盾出现和受击时产生橙黄色外环、青蓝球壳与短脉冲；静态护盾也增加双环结构 | `v12_visual_review`、`weapon_vfx_review` |
| V12-13 | 已完成首批 | 录入并分析授权参考素材 | `audio/library/groove_core/` | 7条素材完成母带、WAV、验证哈希、BPM/响度/频段/瞬态分析和视频接触表 | `validate`、`ANALYSIS.md` |
| V12-14 | 已完成首轮 | 低频击杀鼓触发结构核对 | `docs/GROOVE_CORE_KILL_FEEDBACK.md`、`scripts/event_mixer.gd` | 参考片段的低频事件在约0.13秒间隔内成簇；实现改为随击杀立即起始、后续按125ms十六分音符展开 | `v12_tactical_review`、`v12_audio_review` |
| V12-15 | 已完成 | 提升舰体与敌机的金属质感 | `scripts/fleet_art.gd`、`scripts/fleet_batch.gd`、`scripts/item_art.gd`、`shaders/weapon_body.gdshader` | 玩家舰体、普通敌机与飞刃增加暗面、边缘高光、镜面点和面板线；飞刃从纯能量轮廓改为金属实体切面 | `v12_visual_review`、`weapon_vfx_review` |
| V12-16 | 已完成 | 真实飞行流线 | `scripts/main.gd` | 玩家记录最近约0.42秒轨迹并绘制双侧弯曲发动机光带；敌机按每帧真实位移产生短尾迹 | `v12_visual_review`、`v11_upgrade_review` |
| V12-17 | 已完成 | 每次清波提供基础属性成长 | `scripts/arsenal_loadout.gd`、`scripts/main.gd`、`scripts/arsenal_screen.gd` | 清波后固定生成三项免费基础强化；覆盖生命、装甲、移速、单发伤害、暴击、再生、拾取、幸运和四项主属性；未选择前不能继续 | `v12_tactical_review`、`arsenal_ui_review`、`arsenal_loadout_review` |
| V12-18 | 已完成 | 新增飞剑舰体、曜驾驶员并强化角色肖像 | `scripts/fleet_catalog.gd`、`scripts/fleet_art.gd`、`scripts/main.gd`、`tests/title_hub_review.gd` | 新增狭长刃形舰体“飞剑”和重拍聚焦驾驶员“曜”；四舰四员均可进入实战，全部肖像增加轮廓光与金属高光 | `title_hub_review`、`v12_visual_review` |
| V12-19 | 已完成 | 二次重做舰体与驾驶员造型 | `scripts/fleet_catalog.gd`、`scripts/fleet_art.gd`、`scripts/fleet_picker.gd`、`scripts/neon_hub.gd`、`tools/build_city_pilot.py` | 五型舰体加入蓝晶座舱、装甲明暗面、炮口挂点、发动机热辉、面板缝与铆钉；五名驾驶员拥有独立发型、护目/通讯装备、领口、肩章与阵营徽记；城市3D驾驶员追加背部动力核、胸前束带、头盔脊线、天线与肩灯；新增宽翼蜂群母舰“鲲影”和八小节护盾驾驶员“凛” | `fleet_density_review`、`v12_tactical_review`、`v12_visual_review`、`title_hub_review`、`neon_hub_review` |
| V12-20 | 已完成 | 强化真实路径飞行尾流 | `scripts/main.gd` | 尾流由单层双线改为宽离子焰、错层羽状带、白色热芯和按路径生成的火花，颜色随舰体与星球色调混合 | `v12_visual_review`、`v11_upgrade_review` |
| V12-21 | 已完成 | 超载重做为全向彩虹棱镜风暴 | `scripts/fx.gd`、`scripts/main.gd`、`tests/v12_visual_review.gd` | 六色技能调色板；中心白色冲击波与旋转彩环同步展开，42 道长短不一的长射线向四周溅射，210 枚彩粒形成风暴；低特效模式保留22道射线和80枚彩粒；视觉与实际伤害半径统一为650像素 | `v12_visual_review`：27项0失败；`weapon_vfx_review`、`arsenal_combat_review`、`v11_upgrade_review` |
| V12-22 | 已完成 | 八星标准数值重新标定 | `scripts/planet_catalog.gd`、`scripts/main.gd`、`tests/v11_balance_sim.gd` | 后期生命倍率收敛至2.9倍、伤害2.75倍，海王星预算下调，Boss生命改为3000/5200/6800/8700/10200/11600/13000/14000；单体武器优先锁定 Boss，避免小怪吞掉输出 | `v11_balance_sim`：13个代表性样本全部胜利 |
| V12-23 | 已完成 | 新增“棱镜灾变·高压”协议 | `scripts/planet_catalog.gd`、`scripts/main.gd`、`scripts/solar_map.gd` | 星图可选择标准或高压；高压提高耐久、Boss、伤害、弹速、预算并增加精英，拥有独立高压通关记录 | `solar_map_review`、`fleet_density_review`、`planet_catalog_review` |
| V12-24 | 已完成 | 增加穿棱机与镜像机 | `scripts/main.gd`、`scripts/fleet_art.gd`、`scripts/fleet_batch.gd`、`scripts/planet_catalog.gd` | 新增远距高速弹的穿棱机与蛇形包夹/双芯射击的镜像机，包含独立轮廓、明暗、武器舱和批量实例网格 | `fleet_density_review`、`v12_visual_review`、`planet_catalog_review` |
| V12-25 | 已完成 | 参考视频重做敌机入场 | `scripts/formation_motion.gd`、`scripts/wave_plan.gd`、`scripts/fx.gd`、`scripts/main.gd` | 0—0.42秒错峰跃迁、青蓝/洋红双环、四向光刺、真实1秒碰撞保护、弯曲切入，以及八边环形和双螺旋编队 | `v12_visual_review`、`fleet_density_review` |
| V12-26 | 已完成 | 首批录制音频实装 | `audio/authorized/`、`scripts/main.gd`、`audio/CREDITS.md` | 9个运行时音频文件：菜单主题、实弹轻/中/重音、粗制火弹、碰撞、护盾、敌机生成、推进器；5类来源记录现由游戏调用 | `v12_audio_review`、`audio_library validate` |
| V12-27 | 已完成并修正 | 录音派生新武器 | `scripts/arsenal_catalog.gd`、`audio/arsenal/notes/rec_*`、`scripts/music.gd`、`scripts/composer_player.gd` | 新增裂响火弹、轻压连铳、衡压破阵炮、终压攻城铳；装备总数244，武器36；V14-04将32个录制样本改为不变调事件切片 | `arsenal_loadout_review`、`arsenal_audio_review`、`composer_audio_review` |
| V12-28 | 已完成 | 全武器四拍层次 | `scripts/arsenal_loadout.gd`、`scripts/music.gd`、`scripts/arsenal_screen.gd` | 五类节奏：匀速四连、重-轻-轻-轻、渐强、轻重交替、强弱交替；四拍伤害比例总和为1，充能不足时只发声 | `v12_tactical_review`、`arsenal_loadout_review`、`v11_balance_sim` |
| V12-29 | 已完成 | 武器音色图鉴 | `scripts/weapon_codex.gd`、`scripts/arsenal_screen.gd`、`scripts/interactive_title.gd`、`audio/weapon_codex.json` | 标题页和编辑器均可打开；逐件显示36件武器的8音样本、SHA256、节奏强度、附加录音层，并可试听真实WAV | `weapon_codex_review`、`composer_ui_review` |
| V14-01 | 已完成 | 正式更名为 Groove Flight | `project.godot`、`scripts/ui.gd`、`README.md`、`docs/BRAND_RENAME.md`、桌面快捷方式 | Godot 项目名、主页、文档和快捷方式统一使用新名称；旧存档、乐谱格式和识别器内部标识保留兼容 | 项目启动、标题页截图、快捷方式属性检查 |
| V14-02 | 已完成 | 天王星背景音乐实装与来源映射 | `audio/authorized/uranus_amber_loop.ogg`、`scripts/main.gd`、`docs/AUDIO_SOURCE_MAP.md`、`audio/library/groove_core/runtime_mapping.json` | 20秒、10小节、120BPM循环进入天王星战斗与商店；7条原始录音逐项对应到Groove Flight运行文件和武器样本 | `v12_audio_review`、音频库校验、OGG时长与循环检查 |
| V14-03 | 已完成 | 修复武器音色图鉴进入与试听 | `scripts/main.gd`、`scripts/interactive_title.gd`、`scripts/arsenal_screen.gd`、`scripts/weapon_codex.gd` | 图鉴改为独立模态状态，冻结标题页弹丸交互；关闭后恢复原界面；打开时暂停背景音乐并提高试听音量；卡片区分录音主音色与录音重音层 | `title_hub_review`14/0、`weapon_codex_review`25/0、`arsenal_ui_review`49/0 |
| V14-04 | 已完成 | 全段周期分析与粗制火弹修复 | `tools/audio_library.py`、`docs/AUDIO_PIPELINE.md`、`audio/library/groove_core/`、`scripts/arsenal_catalog.gd`、`scripts/arsenal_loadout.gd` | 7条录音统一记录发声区间、响度与主导周期；粗制火弹0-7秒原声组直接用于图鉴和战斗，四拍只控制伤害时机且不再切分或升降调；原3.00秒静音文件和错误变调样本全部替换 | `v12_audio_review`、`v12_tactical_review`、`weapon_codex_review`、`audio_library validate` |
| V14-05 | 已完成 | 四件录音武器直接接入连续PCM16原声组 | `scripts/main.gd`、`scripts/weapon_codex.gd`、`audio/authorized/`、`tools/build_recorded_weapon_audio.py`、`audio/weapon_codex.json` | 火弹、轻、中、重四段分别直接截取`0-7.00 / 0.58-8.06 / 20.08-27.56 / 33.08-40.94`秒；不做淡化、增益、归一化、重采样、内部分段或升降调；四件武器使用独立播放器，图鉴与战斗读取同一文件；清理误生成的两条静音组记录 | `v12_audio_review`41/0、`v12_tactical_review`42/0、`weapon_codex_review`25/0、`arsenal_audio_review`430/0、`composer_audio_review`83/0、`audio_library validate`0失败 |
| V15-01 | 已完成 | 录音优先、双层1秒音序、独立4秒四拍与三档品质 | `scripts/arsenal_catalog.gd`、`scripts/arsenal_loadout.gd`、`scripts/music.gd`、`scripts/arsenal_screen.gd`、`scripts/weapon_codex.gd`、`scripts/composer_*.gd`、`scripts/midi_codec.gd`、`docs/V15_RECORDED_WEAPON_POLICY.md` | 实战音序改为2层×8格，白点每0.125秒一格、1秒回卷；白点每次经过武器格，该武器本地四拍推进一拍，四轮共4秒后重置；原轻/中/重三种实弹合并为1件“实弹连奏炮”，当前2个录音原型×3品质共6个可获取武器；卡面采用灰/绿/紫红品质色并显示“基础弹数+属性×系数”；32个电子占位武器移出初始配装、商店、试装、作曲选择与战斗调度 | `v12_tactical_review`、`weapon_codex_review`、`arsenal_loadout_review`、`arsenal_audio_review`、`composer_audio_review`、`composer_ui_review`、`recorded_quality_review`、`fleet_density_review`、`arsenal_full_run` |
| V15-02 | 已完成 | 关闭程序底层伴奏与节拍鼓床，加入敌机受击重音和3秒无敌护盾 | `scripts/music.gd`、`scripts/main.gd`、`scripts/ui.gd`、`docs/V15_RECORDED_WEAPON_POLICY.md` | 原生128秒混音不再生成底层伴奏和程序鼓组，设置中移除对应滑杆；敌机每次实际受伤触发低频“咚”，并把我方战斗机护盾刷新到3秒无敌；护盾包含双层球壳、六边形边界、旋转能量环和剩余时间提示 | `v12_tactical_review`、`v12_audio_review`、`v12_visual_review`、`audio_library validate` |
| V15-03 | 已完成 | 水星双武器起手与全关卡共用BGM | `scripts/arsenal_catalog.gd`、`scripts/arsenal_loadout.gd`、`scripts/main.gd` | 水星默认直接装备裂响火弹和实弹连奏炮；所有星球的战斗、暂停恢复、编辑器和波间商店共用同一份20秒关卡循环音乐，切换星球时保持播放 | 规则静态检查、音频库校验 |
| V15-04 | 已完成 | 同一录音武器的半秒重奏 | `scripts/main.gd` | 录音播放器改为每个装备UID独立持有，不再按武器类型共享；同一武器放在第1格和第5格时，第二实例精确延后0.5秒起音，长原声不会被前一实例阻断 | 静态调度检查 |
| V16-01 | 已完成 | 外部试玩回滚到旧电子武器与1秒音序 | `scripts/arsenal_catalog.gd`、`scripts/arsenal_loadout.gd`、`scripts/arsenal_screen.gd`、`scripts/music.gd`、`scripts/main.gd`、`scripts/composer_*.gd` | 裂响火弹和实弹连奏炮隐藏；32把旧电子武器恢复商店、初始配装、试装、图鉴与作曲；战斗改为3层×8格、每格0.125秒、1秒一轮；每把电子武器到格只触发一次，不使用四拍强弱派生 | 静态检查 |
| V16-02 | 已完成 | 两把彩色大范围武器开局与静默商店试听 | `scripts/arsenal_loadout.gd`、`scripts/arsenal_screen.gd`、`scripts/arsenal_lab.gd` | 第一回合全局三层音序合计只装入“七彩折光匣”和“螺旋星冕”，第三轨默认留空；商店默认不启动试射沙盒和任何自动声音，只有点击“试听此卡”“播放”或“重播”才激活 | 静态检查 |

## 机制约定

现行实战音序为2层、每层8格，每格0.125秒，8格一轮1秒。每件武器只在自己的格触发一次，白点在同一秒内扫完全部8格。历史电子武器仍保留旧四拍调度代码和数据，但只在关闭音频守卫的隔离测试中使用。

武器满足充能时，四拍按各自强度产生实际弹体；未满足充能时，四拍仍会发声，但主战斗调度会跳过伤害和弹体生成。这样长充能武器不会在休止期完全失去声音，也不会通过轻拍暗中增加DPS。

程序鼓组在后台合成，不依赖联网或新版权素材。底鼓后对旧伴奏做约20%的短促侧链，使低频重音更清楚。128秒成品仍在后台准备和缓存；逐采样三角函数已移到一次性预生成，避免重复编译时逐帧计算振荡器。

击杀鼓仅作反馈，不延迟伤害、拾取或受击结算。普通敌人贡献轻量连杀填充，装甲、精英和Boss仍保留不同重量与保留播放器优先级。

## 验证结果

| 测试 | 结果 | 关键证据 |
| --- | --- | --- |
| `v12_tactical_review` | 75项，0失败 | 双层8格/1秒白点、武器独立4秒四拍、连续进度条、4原型×3品质、录音独立播放器、编队、击杀鼓、射程层、清波强化与驾驶员被动全部通过 |
| `v12_audio_review` | 41项，0失败 | 14个授权运行时片段真实加载；四段连续PCM16原声组和天王星20秒循环进入独立播放器，7条来源与46个对应运行文件逐一校验 |
| `v12_visual_review` | 27项，0失败 | 13张GPU截图，新增敌机图鉴与环形入场，并覆盖彩虹超载、商店、飞行和机库 |
| `fleet_density_review` | 229项，0失败 | 25种舰体/驾驶员组合、10类敌机、高压协议/独立记录、Boss与480敌机压力夹具通过 |
| `planet_catalog_review` | 3088项，0失败 | 八星标准与高压倍率、预算、敌种、11种阵型及确定性约束 |
| `planet_flow_review` | 141项，0失败 | 星图、八星伤害/Boss、城市入口、原生短流程与存档记录 |
| `solar_map_review` | 40项，0失败 | 高压协议真实切换、独立倍率、发射入口与720p布局 |
| `v11_balance_sim` | 13/13胜利，0失败 | 六种水星构筑及金星至海王星代表性构筑，未开启无敌、免费货币或削血 |
| `arsenal_full_run` | 88项，0失败 | 天王星十波、9次商店、18次实际购买、8323击破、8444分、Boss二阶段与胜利；音乐时间325.59秒，全局最大音序误差41ms |
| `planet_native_run` | 69项，0失败 | 水星六波、5次商店、10次实际购买、700击破、3000生命Boss二阶段与胜利记录；最大音序误差11.08ms |
| `neon_hub_review` | 10项，0失败 | Forward+下真实GLB、骨骼动画、城市移动、星球航图与机库F交互、3D驾驶员附加装备 |
| `title_hub_review` | 14项，0失败 | 标题弹丸射击、七入口、图鉴模态状态与关闭恢复、五舰五员选择与720p布局 |
| `weapon_vfx_review` | 62项，0失败 | 44个武器品质条目图集、1200实例、真实开火/命中/爆炸和低特效边界 |
| `v11_upgrade_review` | 1290项，0失败 | 既有V11主流程完整回归 |
| `arsenal_loadout_review` | 1564项，0失败 | 252条目、44个武器品质条目、兼容周期、所有权与随机移动压力夹具 |
| `arsenal_audio_review` | 452项，0失败 | 288个基础voice WAV、四段连续原声组、录音优先调度与原生输出 |
| `weapon_codex_review` | 29项，0失败 | 左侧36个原型、右侧12个录音品质档切换、32个电子占位档停用、状态恢复与只读隔离 |
| `arsenal_combat_review` | 124项，0失败 | 44个武器品质条目实际命中与事件结算 |
| `composer_audio_review` | 52项，0失败 | 录音品质声部、停用占位音源、自由作曲与WAV输出 |
| `composer_ui_review` | 28项，0失败 | 12个录音品质声部可选择 |
| `fleet_density_review` | 229项，0失败 | 16种舰体/驾驶员组合均进入临时录音优先配装，密度与战斗夹具通过 |
| `recorded_quality_review` | 7项，0失败 | 灰/绿/紫红三档卡面、2/5/10基础弹数与属性实时换算公式 |
| `v11_balance_sim` | 13/13胜利，0失败 | 四拍拆分后八星代表性构筑仍全部胜利 |
| `orchestration_review` | 33项，0失败 | 自由编曲试飞最大起始误差3.45ms |
| `arsenal_ui_review` | 49项，0失败 | 商店/编辑/720p布局回归 |

可用命令：

```powershell
python tools/run_v11_tests.py v12_tactical_review
python tools/run_v11_tests.py v12_audio_review
python tools/run_v11_tests.py v12_visual_review --gpu --forward
python tools/run_v11_tests.py arsenal_audio_review
python tools/run_v11_tests.py orchestration_review --gpu --forward
python tools/run_v11_tests.py arsenal_ui_review --gpu --forward
python tools/run_v11_tests.py weapon_codex_review --gpu --forward
python tools/run_v11_tests.py composer_audio_review --gpu --forward
python tools/run_v11_tests.py v11_balance_sim
```

`orchestration_review` 包含 `await RenderingServer.frame_post_draw` 和截图，必须使用GPU模式；headless会在截图等待处超时，不代表游戏逻辑死锁。

## 试听与截图

| 文件 | 用途 |
| --- | --- |
| `docs/audio-v12/rhythm-before.wav` | 同一配装、鼓组增益0的8秒对照 |
| `docs/audio-v12/rhythm-v12.wav` | 同一配装的V12四拍鼓组8秒混音 |
| `docs/audio-v12/kill-drum-fill.wav` | 生产击杀瞬态拼成的2.4秒连杀鼓演示 |
| `docs/screenshots/v12-formation-command.png` | 领航机标记 |
| `docs/screenshots/v12-formation-broken.png` | 领航机被击破后的失序状态 |
| `docs/screenshots/v12-shop-ranges-1080p.png` | 商店三轨射程覆盖 |
| `docs/screenshots/v12-salvo-trails.png` | 实弹齐射的加长光带与更大光芯 |
| `docs/screenshots/v12-salvo-and-chain-kills.png` | 齐射叠加连杀短闪与方向碎片 |
| `docs/screenshots/v12-shield-impact.png` | 参照授权视频重做的橙环/青蓝护盾 |
| `docs/screenshots/v12-overload-burst.png` | 42道全向彩色射线、错相色环、650像素冲击与密集粒子的超载技能 |
| `docs/screenshots/v12-flight-streams.png` | 跟随真实移动轨迹的双侧飞行流线 |
| `docs/screenshots/v12-blade-flight.png` | 金属高光、暗面与光刃尾迹下的回旋飞刃 |
| `docs/screenshots/v12-enemy-entry.png` | 双编队错峰跃迁、青蓝/洋红入口环与弯曲切入 |
| `docs/screenshots/v12-enemy-roster.png` | 八类普通敌机的并排造型检查 |
| `docs/screenshots/v4-solar-hard-1080p.png` | 星球航图的高压协议倍率与出击入口 |
| `docs/screenshots/v12-shop-ranges-1080p.png` | 清波三选一基础强化、六件商店与射程试射 |
| `docs/screenshots/v12-shop-growth-720p.png` | 720p下三项基础强化和商店滚动布局 |
| `docs/screenshots/v12-fleet-manta-rime.png` | 五舰五员机库与新增“鲲影/凛” |
| `docs/V13_BALANCE_AND_ENEMY_ENTRY.md` | 八星数值、棱镜灾变、敌机属性与入场规则交接 |
| `docs/GROOVE_CORE_KILL_FEEDBACK.md` | 授权录像的三段低频/画面对照与触发机制推断 |
| `docs/V14_SONIC_CODEX.md` | 录制音频实装、4件新武器、36件武器节奏与音色图鉴交接 |
| `docs/screenshots/v14-weapon-sonic-codex-720p.png` | 武器实际音源、SHA256和四拍强度图鉴 |
| `docs/V15_RECORDED_WEAPON_POLICY.md` | 录音优先、双层1秒音序、白点、三档品质与电子武器恢复流程 |
| `docs/screenshots/v15-recorded-quality-tiers-720p.png` | 同一录音原型普通/稀有/珍贵三卡、品质色与实时弹数公式 |
| `docs/data-v15/` | V15来源映射、武器记录、三档品质和回归测试快照 |

音频已通过格式、非静音、峰值和RMS检查，但没有替代真人主观试听。听感是否“更带感”仍需用户实际对比 `rhythm-before.wav` 与 `rhythm-v12.wav`。

## 后续 GPT 接手须知

| 事项 | 说明 |
| --- | --- |
| 不要重复实现 | V12已包含领航机损失重整、试射射程覆盖、重武器1重+3轻、程序鼓组和连杀鼓填充 |
| 节拍单位 | 普通模式1小节8格；重音间隔4个四分音符，对应相对格偏移0、2、4、6 |
| 不得削弱伤害 | `cadence_light=true` 的事件必须继续在主战斗调度中跳过，不能给它补弹体；调整听感只改增益/波形 |
| 性能约束 | `music.gd` 的128秒渲染循环内不要再加入逐采样三角函数扫描；鼓和侧链应预生成缓存 |
| 预览隔离 | 射程层只能存在于 `arsenal_lab` 的独立Main/SubViewport，不能写回正式货币、RNG、装备或战绩 |
| GPU测试 | `v12_visual_review` 和 `orchestration_review` 使用 `--gpu --forward`；普通headless会卡在截图等待 |
| 生成文件 | 仓库现有若干 `.uid` 是Godot生成的未跟踪文件；除非确认归属，不要批量删除或覆盖 |
| 音频库 | 原始文件在 `audio/library/groove_core/raw/`，加工版本在 `working/`；`catalog.json` 为主索引，不要手工改 `catalog.csv` 或 `CATALOG.md` |
| 打包音频 | 工程暂无 `export_presets.cfg`。正式导出前必须包含 `audio/arsenal/notes/*.wav` 与 `audio/authorized/*`；开发版会回退到原文件，但这不能保证未配置的导出包携带录音 |
| 视频提取 | 已安装 FFmpeg 9.0.2；音频库会自动定位 WinGet 安装目录。重装或迁移环境后运行 `python tools/audio_library.py doctor` |
| 首批素材 | 7条已位于资料库；`music_menu` 是完整菜单主题，`music_title` 是其中约118.84秒处的同源片段；其余武器与事件素材等待逐事件切分 |

### 模型与角色交接

- 战斗舰体是 `scripts/fleet_art.gd` 的矢量程序绘制，不依赖位图。统一坐标以 `+X` 为机头，白六边飞行核心位于原点；新增舰体必须同时实现轮廓分支、`_ship_finish()` 座舱/炮口细节，并把 ID 加入 `scripts/fleet_catalog.gd`。
- 机库选择器直接读取 `FLEET.SHIPS` 与 `FLEET.PILOTS`，卡牌数量会随数据自动生成。新增驾驶员还需在 `draw_pilot()` 中加入专属头型/装备，并在 `main.gd` 的对应拍点或战斗事件中实现真实被动。
- 当前新增 ID：舰体 `manta`（鲲影，蜂群母舰），驾驶员 `rime`（凛，八小节护盾）。不要只增加外观数据而不验证 `fleet_density_review`，该测试会遍历全部舰体/驾驶员组合。
- 城市角色加载 `assets/city/pilot.glb`。运行时的附加装备位于 `scripts/neon_hub.gd::_decorate_pilot_visual()`，可编辑源部件同步写在 `tools/build_city_pilot.py`；重新导出 GLB 后运行时检测到同名部件会自动跳过重复叠加。
- 飞行尾流使用真实移动采样，不按固定屏幕曲线伪造；调整长度应修改 `record_flight_trail()` 的生命期和采样上限，调整质感应修改 `_draw_flight_trail()` 的图层，不要破坏路径时间数据。

## 性能备注

GPU实例化光带修正后，Forward+极端场景640敌机/4096逻辑弹的总帧中位约39.03ms、P95约45.88ms，尚未达到持续60帧；相比上一版没有拖尾的31.03ms有可见开销。低特效仍使用相同逻辑弹体，只关闭光晕和光带，不改变命中与伤害。

## 尚未完成

水星样板之外的逐星球最终平衡、真人完整试玩、主观混音验收、完整邻接/合成/充能互动教学、所有Boss的真人视频验收仍待完成。V14把装备从240扩展到244，保留原存档键、旧装备ID与自由编曲原稿格式。V15进一步增加8个录音品质条目并关闭程序底层伴奏/鼓床，旧存档键和旧谱标识继续兼容。

## 回退方式

本次没有提交或创建新标签。需要整体回退时，先审阅 `git diff`，再针对以下V12文件使用明确的 Git 反向补丁：`scripts/arsenal_lab.gd`、`scripts/arsenal_loadout.gd`、`scripts/arsenal_screen.gd`、`scripts/event_mixer.gd`、`scripts/formation_motion.gd`、`scripts/main.gd`、`scripts/music.gd`、`scripts/ui.gd`。不要使用会丢弃用户未提交修改的硬重置。
