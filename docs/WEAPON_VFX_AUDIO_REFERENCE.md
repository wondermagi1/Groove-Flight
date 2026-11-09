# 武器特效与音频对应表（持续维护）

最后更新：2026-11-09。核对版本：`0.37.0-sustained-salvo-voices`；当前目录与配装快照见V37。三四轮武器重制20份强/很强长音，56份其他力度与152份作曲音高保留；修改前备份`31ed97e`。

这是当前现役武器的统一查阅入口。后续在同一份文档持续更新；历史版本说明和旧武器档案保留在原处。表中均为已经接入的内容，待开发设想另列。

现役共**19种武器**：**14种共享羽状质感、17种实体弹、2种激光/电弧**。每件武器保留独立的乐器身份与固定音高，战斗按真实发射演奏力度乐句；共228份样本。**当前武器声音仅使用11种钢琴变化、4种弓弦和4种竖琴**；V36新增76份不同力度／起音／持音／明暗的演奏，V35的152份音高样本保留。V37再强化十件三四轮武器的强/很强档，约+3dB起音与2.2–3.2秒长音，部分融入同根音弓弦主体。见[V37说明与试听](V37_SUSTAINED_SALVO_VOICES.md)。

## 1. 武器、画面与声音对照

下表乐器链接指向现役“强”档演奏WAV；每件四档的完整链接见第2节。“弹体充能”表示每几轮音序器发射一次；V34起声音只跟随实际发射，等待轮不新增起音。

当前所有关卡初始为**脉冲机炮 A3、苍穹轨炮 B4–B5、流萤织雨 C6–C8**，分别是一件1格、2格、3格武器。首次实际发声为0.375／2.0625／3.9375秒，此后间隔1.5／3／4.5秒；占用尾格不重复响。非武器道具保留，后续波次不重置玩家编排。见[V37初始配装与长音](V37_SUSTAINED_SALVO_VOICES.md)。

| 武器 / ID | 发射形式与运动 | 弹体、光色与尾迹 | 乐器代表音色（强奏试听） | 对应主属性 | 弹体充能 |
| --- | --- | --- | --- | --- | ---: |
| 脉冲机炮<br>`pulse` | 朝瞄准方向错时喷射；各弹独立初速、偏角和摆动 | 青绿色羽状弹、柔光、细曲线尾迹 | [延音中音钢琴](../audio/arsenal/dynamics/dyn_pulse_2.wav) | 实弹 | 1轮 |
| 星砂霰弹<br>`scatter` | 前向扇面散射；各颗在扇面内独立推进、错位 | 暖金色羽状弹；共享鎏金基底 | [明亮延音钢琴](../audio/arsenal/dynamics/dyn_scatter_2.wav) | 实弹 | 1轮 |
| 棱镜光束<br>`beam` | 朝瞄准方向发射多条直束；各束微小方向、宽度和闪光差异 | 淡紫束芯与能量鞘，保留激光形态 | [清晰弓头小提琴](../audio/arsenal/dynamics/dyn_beam_2.wav) | 能量 | 1轮 |
| 彗星导弹<br>`missile` | 向前发射后独立追踪；各弹转向响应不同，命中爆破 | 粉红导弹实体、推进尾焰与弯曲残迹 | [温暖低音钢琴](../audio/arsenal/dynamics/dyn_missile_2.wav) | 动力 | 2轮 |
| 新星环炮<br>`nova` | 360°圆周展开；各颗独立弯转，保持完整圆周覆盖 | 浅绿能量珠、局部柔光、细弧形尾迹 | [延音圆润钢琴](../audio/arsenal/dynamics/dyn_nova_2.wav) | 能量 | 4轮 |
| 跃迁电弧<br>`chain` | 先连向目标，再向附近敌人跳跃；各段有稳定的独立相位 | 蓝色分支电流与局部辉光 | [柔和高音竖琴](../audio/arsenal/dynamics/dyn_chain_2.wav) | 能量 | 2轮 |
| 苍穹轨炮<br>`rail` | 朝瞄准方向高速贯穿；各弹独立受力、保留主方向 | 冰白羽状弹；实际路径尾迹 | [厚弓大提琴](../audio/arsenal/dynamics/dyn_rail_2.wav) | 实弹 | 2轮 |
| 星针狙击器<br>`pulse_needle` | 朝瞄准方向集中喷射；个体速度与细微弯转不同 | 青白羽状弹；共享羽状质感 | [清亮高音钢琴](../audio/arsenal/dynamics/dyn_pulse_needle_2.wav) | 实弹 | 1轮 |
| 七彩折光匣<br>`scatter_prism` | 机头前方的四个斜向，展开多排U形羽流；每组轻摆、每颗独立飞行 | 七彩羽状实体弹；与尾羽共享柔光和真实弯曲尾迹 | [延音珠光钢琴](../audio/arsenal/dynamics/dyn_scatter_prism_2.wav) | 实弹 | 4轮 |
| 双生棱镜<br>`beam_split` | 机头两侧向前喷出青粉双股羽流，各股反相摇摆，每颗独立飞行，抵达后才命中 | 与尾羽共享羽状实体、柔光、弯曲残迹；不再瞬时直束 | [绵奏中提琴](../audio/arsenal/dynamics/dyn_beam_split_2.wav) | 能量 | 2轮 |
| 地平线终奏<br>`rail_horizon` | 沿实际机身左右两翼喷射；低初速出膛，再各自加速和摆动 | 绿色羽状弹流；柔光与逐渐变细的实际尾迹 | [深色低音钢琴](../audio/arsenal/dynamics/dyn_rail_horizon_2.wav) | 实弹 | 8轮 |
| 终压攻城铳<br>`recorded_heavy` | 朝瞄准方向发射重型贯穿弹；独立出膛时差与惯性，命中爆破 | 暖橙羽状实体弹；当前使用统一羽状基底 | [延音厚实中低音钢琴](../audio/arsenal/dynamics/dyn_recorded_heavy_2.wav) | 实弹 | 4轮 |
| 鎏金螺旋阵<br>`gilded_helix` | 向四周展开，叠加不同弯转速率，形成螺旋包络 | 金色发光叶状弹头；同类羽弹的质感基准 | [延音三角钢琴](../audio/arsenal/dynamics/dyn_gilded_helix_2.wav) | 能量 | 4轮 |
| 虹织十字炮<br>`weave_cross` | 上、下、左、右四向编织；实际横向摆动叠加个体受力 | 彩色羽状弹流、错位交织尾迹 | [断奏钢琴＋高音小提琴长音](../audio/arsenal/dynamics/dyn_weave_cross_2.wav) | 实弹 | 3轮 |
| 星冕回旋阵<br>`crown_orbit` | 三至八层环绕；每颗独立呼吸、角速度和惯性中心，跟随玩家 | 彩色环绕实体与柔光；细曲线残迹 | [竖琴＋高音小提琴长音](../audio/arsenal/dynamics/dyn_crown_orbit_2.wav) | 支援 | 3轮 |
| 尾羽回响<br>`stern_fan` | 沿机尾向后展开多排U形扇面；两翼先打开，再以不同惯性收向后方 | 左翼绿黄、中央橙黄、右翼粉紫的羽状弹流 | [中音竖琴＋中提琴长音](../audio/arsenal/dynamics/dyn_stern_fan_2.wav) | 实弹 | 3轮 |
| 晨羽前奏<br>`dawn_fan` | 机头前方宽U形羽扇，分排出膛，中心较快、两翼略慢，每颗沿自身扇面方向轻摆 | 绿、金、橙、粉连续过渡的羽弹与曲线尾迹 | [延音高音钢琴](../audio/arsenal/dynamics/dyn_dawn_fan_2.wav) | 实弹 | 3轮 |
| 潮汐弦歌<br>`tidal_weave` | 前方两股反相摆动，分排错开形成较强的S形波浪编织 | 青粉羽弹、局部柔光与真实弯曲残迹 | [长弓高音小提琴](../audio/arsenal/dynamics/dyn_tidal_weave_2.wav) | 能量 | 4轮 |
| 流萤织雨<br>`firefly_rain` | 前方多列错峰喷射，出膛较慢后渐加速；喷口按列扫动，每颗独立受力 | 绿青紫萤彩羽弹、收敛光晕与曲线残迹 | [高音竖琴＋高音小提琴长音](../audio/arsenal/dynamics/dyn_firefly_rain_2.wav) | 动力 | 3轮 |

## 2. 四档演奏与原音高索引

当前战斗使用`audio/arsenal/dynamics/dyn_<ID>_0…3.wav`，索引表示很弱／弱／强／很强，**不是四个音高**。四份均独立渲染，力度、起音、持音、释放和频谱一起变化。每件固定音高；1轮武器按四档渐强，2轮按弱→强，3轮强→很强，4轮很强→强，8轮强→很强，按实际齐射推进。音源与样本SHA见[力度清单](../audio/instruments/DYNAMICS_MANIFEST.json)。

| 武器 | 四档实际演奏试听 | 平衡增益 |
| --- | --- | ---: |
| 脉冲机炮 | [很弱](../audio/arsenal/dynamics/dyn_pulse_0.wav) · [弱](../audio/arsenal/dynamics/dyn_pulse_1.wav) · [强](../audio/arsenal/dynamics/dyn_pulse_2.wav) · [很强](../audio/arsenal/dynamics/dyn_pulse_3.wav) | +0.0dB |
| 星砂霰弹 | [很弱](../audio/arsenal/dynamics/dyn_scatter_0.wav) · [弱](../audio/arsenal/dynamics/dyn_scatter_1.wav) · [强](../audio/arsenal/dynamics/dyn_scatter_2.wav) · [很强](../audio/arsenal/dynamics/dyn_scatter_3.wav) | -0.8dB |
| 棱镜光束 | [很弱](../audio/arsenal/dynamics/dyn_beam_0.wav) · [弱](../audio/arsenal/dynamics/dyn_beam_1.wav) · [强](../audio/arsenal/dynamics/dyn_beam_2.wav) · [很强](../audio/arsenal/dynamics/dyn_beam_3.wav) | -2.5dB |
| 彗星导弹 | [很弱](../audio/arsenal/dynamics/dyn_missile_0.wav) · [弱](../audio/arsenal/dynamics/dyn_missile_1.wav) · [强](../audio/arsenal/dynamics/dyn_missile_2.wav) · [很强](../audio/arsenal/dynamics/dyn_missile_3.wav) | -0.5dB |
| 新星环炮 | [很弱](../audio/arsenal/dynamics/dyn_nova_0.wav) · [弱](../audio/arsenal/dynamics/dyn_nova_1.wav) · [强](../audio/arsenal/dynamics/dyn_nova_2.wav) · [很强](../audio/arsenal/dynamics/dyn_nova_3.wav) | +0.4dB |
| 跃迁电弧 | [很弱](../audio/arsenal/dynamics/dyn_chain_0.wav) · [弱](../audio/arsenal/dynamics/dyn_chain_1.wav) · [强](../audio/arsenal/dynamics/dyn_chain_2.wav) · [很强](../audio/arsenal/dynamics/dyn_chain_3.wav) | -2.0dB |
| 苍穹轨炮 | [很弱](../audio/arsenal/dynamics/dyn_rail_0.wav) · [弱](../audio/arsenal/dynamics/dyn_rail_1.wav) · [强](../audio/arsenal/dynamics/dyn_rail_2.wav) · [很强](../audio/arsenal/dynamics/dyn_rail_3.wav) | -0.5dB |
| 星针狙击器 | [很弱](../audio/arsenal/dynamics/dyn_pulse_needle_0.wav) · [弱](../audio/arsenal/dynamics/dyn_pulse_needle_1.wav) · [强](../audio/arsenal/dynamics/dyn_pulse_needle_2.wav) · [很强](../audio/arsenal/dynamics/dyn_pulse_needle_3.wav) | -1.8dB |
| 七彩折光匣 | [很弱](../audio/arsenal/dynamics/dyn_scatter_prism_0.wav) · [弱](../audio/arsenal/dynamics/dyn_scatter_prism_1.wav) · [强](../audio/arsenal/dynamics/dyn_scatter_prism_2.wav) · [很强](../audio/arsenal/dynamics/dyn_scatter_prism_3.wav) | +0.0dB |
| 双生棱镜 | [很弱](../audio/arsenal/dynamics/dyn_beam_split_0.wav) · [弱](../audio/arsenal/dynamics/dyn_beam_split_1.wav) · [强](../audio/arsenal/dynamics/dyn_beam_split_2.wav) · [很强](../audio/arsenal/dynamics/dyn_beam_split_3.wav) | -2.0dB |
| 地平线终奏 | [很弱](../audio/arsenal/dynamics/dyn_rail_horizon_0.wav) · [弱](../audio/arsenal/dynamics/dyn_rail_horizon_1.wav) · [强](../audio/arsenal/dynamics/dyn_rail_horizon_2.wav) · [很强](../audio/arsenal/dynamics/dyn_rail_horizon_3.wav) | +0.0dB |
| 终压攻城铳 | [很弱](../audio/arsenal/dynamics/dyn_recorded_heavy_0.wav) · [弱](../audio/arsenal/dynamics/dyn_recorded_heavy_1.wav) · [强](../audio/arsenal/dynamics/dyn_recorded_heavy_2.wav) · [很强](../audio/arsenal/dynamics/dyn_recorded_heavy_3.wav) | +1.0dB |
| 鎏金螺旋阵 | [很弱](../audio/arsenal/dynamics/dyn_gilded_helix_0.wav) · [弱](../audio/arsenal/dynamics/dyn_gilded_helix_1.wav) · [强](../audio/arsenal/dynamics/dyn_gilded_helix_2.wav) · [很强](../audio/arsenal/dynamics/dyn_gilded_helix_3.wav) | -0.5dB |
| 虹织十字炮 | [很弱](../audio/arsenal/dynamics/dyn_weave_cross_0.wav) · [弱](../audio/arsenal/dynamics/dyn_weave_cross_1.wav) · [强](../audio/arsenal/dynamics/dyn_weave_cross_2.wav) · [很强](../audio/arsenal/dynamics/dyn_weave_cross_3.wav) | -1.0dB |
| 星冕回旋阵 | [很弱](../audio/arsenal/dynamics/dyn_crown_orbit_0.wav) · [弱](../audio/arsenal/dynamics/dyn_crown_orbit_1.wav) · [强](../audio/arsenal/dynamics/dyn_crown_orbit_2.wav) · [很强](../audio/arsenal/dynamics/dyn_crown_orbit_3.wav) | -1.5dB |
| 尾羽回响 | [很弱](../audio/arsenal/dynamics/dyn_stern_fan_0.wav) · [弱](../audio/arsenal/dynamics/dyn_stern_fan_1.wav) · [强](../audio/arsenal/dynamics/dyn_stern_fan_2.wav) · [很强](../audio/arsenal/dynamics/dyn_stern_fan_3.wav) | -0.2dB |
| 晨羽前奏 | [很弱](../audio/arsenal/dynamics/dyn_dawn_fan_0.wav) · [弱](../audio/arsenal/dynamics/dyn_dawn_fan_1.wav) · [强](../audio/arsenal/dynamics/dyn_dawn_fan_2.wav) · [很强](../audio/arsenal/dynamics/dyn_dawn_fan_3.wav) | -0.2dB |
| 潮汐弦歌 | [很弱](../audio/arsenal/dynamics/dyn_tidal_weave_0.wav) · [弱](../audio/arsenal/dynamics/dyn_tidal_weave_1.wav) · [强](../audio/arsenal/dynamics/dyn_tidal_weave_2.wav) · [很强](../audio/arsenal/dynamics/dyn_tidal_weave_3.wav) | -1.0dB |
| 流萤织雨 | [很弱](../audio/arsenal/dynamics/dyn_firefly_rain_0.wav) · [弱](../audio/arsenal/dynamics/dyn_firefly_rain_1.wav) · [强](../audio/arsenal/dynamics/dyn_firefly_rain_2.wav) · [很强](../audio/arsenal/dynamics/dyn_firefly_rain_3.wav) | -0.5dB |

原152份音高样本继续保留供显式作曲，下面记录的是这组原样本，**不是当前战斗力度层**。
统一目录：`audio/arsenal/notes/`。每种武器有`_0.wav`至`_7.wav`共8份样本；普通战斗固定根音但使用上表新演奏层；这8个音高由显式作曲选择，不自动轮换旋律。

下列时长是原声文件长度，不是武器发射间隔、弹体寿命或充能时长。

| 武器 | 音色键 / 文件前缀 | 当前固定原声 | 原声长度 |
| --- | --- | --- | ---: |
| 脉冲机炮 | `inst_pulse` | `inst_pulse_0.wav` | 1.350秒 |
| 星砂霰弹 | `inst_scatter` | `inst_scatter_0.wav` | 1.220秒 |
| 棱镜光束 | `inst_beam` | `inst_beam_0.wav` | 1.158秒 |
| 彗星导弹 | `inst_missile` | `inst_missile_0.wav` | 0.880秒 |
| 新星环炮 | `inst_nova` | `inst_nova_0.wav` | 0.820秒 |
| 跃迁电弧 | `inst_chain` | `inst_chain_0.wav` | 0.750秒 |
| 苍穹轨炮 | `inst_rail` | `inst_rail_0.wav` | 1.257秒 |
| 星针狙击器 | `inst_pulse_needle` | `inst_pulse_needle_0.wav` | 0.640秒 |
| 七彩折光匣 | `inst_scatter_prism` | `inst_scatter_prism_0.wav` | 0.770秒 |
| 双生棱镜 | `inst_beam_split` | `inst_beam_split_0.wav` | 1.158秒 |
| 地平线终奏 | `inst_rail_horizon` | `inst_rail_horizon_0.wav` | 1.190秒 |
| 终压攻城铳 | `inst_recorded_heavy` | `inst_recorded_heavy_0.wav` | 1.000秒 |
| 鎏金螺旋阵 | `inst_gilded_helix` | `inst_gilded_helix_0.wav` | 0.870秒 |
| 虹织十字炮 | `inst_weave_cross` | `inst_weave_cross_0.wav` | 0.490秒 |
| 星冕回旋阵 | `inst_crown_orbit` | `inst_crown_orbit_0.wav` | 0.820秒 |
| 尾羽回响 | `inst_stern_fan` | `inst_stern_fan_0.wav` | 0.860秒 |
| 晨羽前奏 | `inst_dawn_fan` | `inst_dawn_fan_0.wav` | 0.860秒 |
| 潮汐弦歌 | `inst_tidal_weave` | `inst_tidal_weave_0.wav` | 1.178秒 |
| 流萤织雨 | `inst_firefly_rain` | `inst_firefly_rain_0.wav` | 1.470秒 |

文件规格统一为22,050Hz、单声道、PCM16。完整8索引、文件长度和SHA256见[音频机器索引](../audio/weapon_codex.json)。V25重制了128份样本，均以较轻触键、离线低通、柔和起音与尾端淡化制作，保留个体音色差异。渲染来源、力度、滤波参数和SHA256见[当前音源清单](../audio/instruments/MANIFEST.json)，统一配置见[音色策略](../audio/instruments/CHAMBER_PALETTE.json)。旧声音可从调整前Git备份恢复，旧元数据见[原音色档案](../audio/instruments/archives/MANIFEST-before-v25.json)。

## 3. 声音与弹道怎样对应

当前为1.5秒一轮，按实际发射发声；V36按有效充能加入纯音频力度乐句，1轮四档渐强、2轮弱强、3–4轮疏重音。详见[V36说明与同响度试听](V36_EXPRESSIVE_WEAPON_VOICES.md)。[18秒当前初始配装试听](audio-v37/starter-voices-18s.wav)。V31每轮发声及V27的2秒试听保留作历史对比。

V26在“设置 → 声音”中独立控制背景、武器、击杀鼓点、拾取、受击护盾、命中爆炸和界面警报，总音量统一控制全部声音。武器滑块同时覆盖战斗、图鉴、商店与作曲试听；0%静音、调节自动保存。改音量直接作用于播放通道，保留当前PCM与音序位置，背景静音不再压低武器。详见[分类音量说明](V26_AUDIO_CONTROLS.md)。

V33修复暂停背景被当成未播放而从头启动的问题：进入设置、拖动任意音量、静音后恢复、恢复默认与返回游戏均保留背景位置。返回游戏后从原位置继续；离开战斗时正确停止暂停中的旧背景。见[修复与原生验证](V33_MUSIC_CONTINUITY.md)。

V29用户选定背景曲[Filaments — Scott Buckley](https://www.scottbuckley.com.au/library/filaments/)，以完整339.88秒OGG用于菜单和战斗/商店背景，走独立背景音乐音量；来源、哈希和CC BY4.0见[素材记录](../audio/authorized/scott_buckley/SOURCE.json)与[署名](../CREDITS.md)。武器128份钢琴/提琴/竖琴样本及固定声音逻辑不变。音序面板恢复到左下，可从隐藏后的入口找回，白点层级在装备卡片上方。回合主属性强化由+3提高到+5，经原共享属性公式影响实际弹数/伤害；商店固定3武器＋3道具，锁定刷新维持比例。见[V29说明](V29_FILAMENTS_SHOP_HUD.md)。

V25使用同一组音区与质感协调的钢琴、弓弦和竖琴，撤下武器中的萨克斯、鼓、长笛、吉他、钢片琴及电子叠层。钢琴通过三角钢琴/明亮三角钢琴音源、触键、音区、明暗、断奏和尾音区分。击杀、护盾与拾取反馈声音保持各自用途。

[8秒原生叠奏试听](audio-v25/native-ensemble.wav) · [16种音色逐件试听](audio-v25/sixteen-chamber-voices.wav) · [逐件试听时间表](audio-v25/sixteen-chamber-voices.json)。两份试听隔离了背景和反馈声，原生叠奏使用生产混音，包含两件钢琴实例。

1. 音序器3轨×8格，每格0.1875秒，一轮1.5秒。白点到武器起始格且充能满足，实际发射与当前档演奏同时开始；等待轮不新增起音，占用的后续格不重复播放。
2. 同种武器的不同装备实例各自发声，尾音允许重叠。例如分别放在第1–2格与第3–4格，就在第1格和第3格分别发声，相隔0.375秒。
3. 充能轮数保留。例如七彩折光匣每4轮（6秒）发射并发声，流萤每3轮（4.5秒），地平线仍每8轮（12秒）。PCM有12秒自然开场，再循环144秒完整区域，开局不带尚未发生的尾音，回卷保留真实尾音及扫描/充能相位。
4. 同一次发射增加弹数、方向或弹排，只产生这一次扫描对应的声音，不按每颗弹或每排弹重复发声。
5. 出膛时差、摆动、加速和弯转属于实际运动。V36力度乐句只选择当前演奏样本，不能缩放伤害或弹数，不恢复旧拍序条；音高始终固定。
6. 原声的尾音、弹体的飞行和光束的闪光可以有不同长度。实体弹按自身速度与射程运动，不能用音频结束时间直接裁掉弹体。
7. 静音、独奏、武器音量覆盖实际播放路径。未来重做音色时，同步核对试听、普通战斗、同种重奏和显式作曲入口。

详细时序约定见[声音与演奏时序约定](RHYTHM_CONTRACT.md)。

V35提供9项独立音量，新增独立危险警报；推荐混音可一键恢复旧值。自动背景让位最多3dB，不改变播放进度。击杀首下即时、尾鼓最短187.5毫秒且最多两下；受伤只保留一次195毫秒护盾。长音样本、发射周期、源单音拆解和试听见[V35说明](V35_SUSTAINED_AUDIO_UPGRADE.md)。

### 三类独立反馈

最新护盾只保留干净的一击，已按用户反馈裁掉主声后的额外小声音；[单次护盾试听](../audio/authorized/feedback/shield_impact.wav)。当前裁剪和播放核对见[V26.1记录](data-v26.1/SUMMARY.json)。

按用户再次给出的《音频资源.mp4》核对。这三类与武器乐器层分开，各有独立音量。

| 反馈 | 当前素材与试听 | 视频来源 | 音量控制 |
| --- | --- | --- | --- |
| 击杀低鼓 | [重](../audio/authorized/feedback/kill_low_strong.wav)、[轻](../audio/authorized/feedback/kill_low_soft.wav)、[圆润低鼓](../audio/authorized/feedback/kill_low_round.wav)，死亡立即反馈并组成短鼓列 | 11.45—11.82秒、17.27—17.62秒、16.41—16.70秒 | 击杀鼓点 |
| 清脆拾取 | [金币拾取](../audio/authorized/feedback/pickup_coin.wav) | 6.685—6.845秒 | 道具与拾取 |
| 受击护盾 | [新版护盾](../audio/authorized/feedback/shield_impact.wav)，保留起音、主体与收尾 | V26.1保留28秒附近的护盾主声，取28.745—28.940秒 | 受击与护盾 |

[三类反馈组合试听](audio-v26/feedback-source-audition.wav)与[来源及处理记录](../audio/library/groove_core/analysis/combat-feedback.json)同时保留。参考片是混合录屏，滤波截段不代表独立原始音轨。

## 4. 所有武器共用的视觉约定

- 按类别统一质感：14种羽状武器共享鎏金基底；导弹、能量珠、环绕、激光、电弧保留各自形式。颜色是识别线索，发射结构和运动才是各武器的主要区别。
- 17种实体弹各颗独立拥有位置、初速、质量、出膛时差和受力；尾迹采样实际路径。保留柔光、颗粒轮廓与自然错位。
- V34每次实体弹发射的首颗不额外等待，与声音起始和炮口闪光同刻出现；其余颗粒的出膛时差与独立运动保留。激光、电弧仍在实际发射事件立即创建。
- 七彩折光匣以用户最新反馈为准：四斜向摇摆的羽状实体弹流，持续飞行，命中等待实际抵达。
- 实体弹在有效射程内保持完整；达到射程后才进入1.5秒的缩小、减光和尾迹收敛，退场期间不继续造成伤害。环绕弹按驻留时长退出后退场。
- 弹数沿统一公式随对应主属性、品质、强化及原有改件增加。总弹数分配到各方向和弹排，不能暗中按方向翻倍；增加弹数不增加扫描发声次数。

[全部16种特效总览](screenshots/v24-all-weapons.png) · [8秒原生静音预览](video-v24/all-weapon-motion-preview.mp4) · [V24运动与实现说明](V24_ALL_WEAPON_MOTION.md)

预览为受控试射：Lv.4、对应主属性40，前4秒为七彩折光匣，随后为新星环炮和星冕回旋阵；受控重复触发方便比较效果，正常充能规则未改。

## 5. 后续迭代必须同步更新

本文件固定为`docs/WEAPON_VFX_AUDIO_REFERENCE.md`。每次改动以下任一项，必须在**同一个修改提交**内同步维护本表，并更新日期、核对版本和下面的迭代记录：

- 新增、停用、删除或更名武器，以及稳定ID、对应主属性或充能规则。
- 发射方向、发射形式、弹体类别、颜色、光晕、尾迹、摆动、追踪、射程退场。
- 乐器音色、voice键、实际样本路径、索引规则、固定声/分排/重奏行为。

更新时从当前生产武器目录和发射代码核对画面，从实际播放路径和WAV核对声音；逐项检查现役名单一致、试听链接可用、样本格式正确。替换音频时同步更新`audio/weapon_codex.json`及相关授权来源。历史验证数据保留，当前版本引用指向本轮结果；未实现的内容单列为计划。

维护要求已写入根目录[AGENTS.md](../AGENTS.md)。游戏代码、素材、平衡或视觉的每轮修改，仍先执行既定的远程Git备份与SHA核验。

## 6. 迭代记录

| 日期 | 游戏版本 / 基线 | 本表变更 |
| --- | --- | --- |
| 2026-11-09 | V37 / 备份`31ed97e` | 初始改为脉冲A3、苍穹B4–B5、流萤C6–C8。十件3/4轮武器重制20份强/很强档，起音约+3dB、总长2.2–3.2秒；四件加入同根音声学弓弦持音，保留原起音、一次齐射一声。56份其他力度与152音高保留。 |
| 2026-11-09 | V36 / 备份`5f7a65d` | 全19件新增76份独立力度／演奏样本；1轮很弱→弱→强→很强、2轮弱→强、3/4/8轮疏重音；音高固定、声音跟随真实发射，不改变伤害与弹数。图鉴新增四档和真实间隔乐句试听；152份原作曲样本保留，144秒回卷相位连续。 |
| 2026-11-09 | V35 / 备份`699f22f` | 延长7种乐器的真实主体与尾音（56份），大范围武器3–4轮，新增3轮与144秒重复相位。击杀滚奏降密度、受伤单次、背景平滑让位、独立警报和可恢复推荐混音；保持1.5秒扫描与固定齐射声音。 |
| 2026-11-09 | V34 / 备份`f69d352` | 全19件仅实际发射发声，充能等待轮静音；实体弹首颗立即出膛，其余保持独立错峰。PCM自然开场12秒＋96秒重复，避免虚假开场尾音。初始改为脉冲 A3、霰弹 B4、流萤 C6–C8；样本、弹数、伤害与充能轮数保留。 |
| 2026-11-09 | V33 / 备份`2056a0a` | 背景状态同步区分暂停与未启动，设置/音量/静音恢复不再重播Filaments；退出战斗停止暂停中的旧背景。武器、音源、初始占格与1.5秒扫描保留。 |
| 2026-11-09 | V32 / 备份`dcadfec` | 所有关卡初始改为流萤织雨 A3–A5、七彩折光匣 B7–B8，优先保留完整占格；舰体和预设道具在空位保留。1.5秒扫描、充能、音源及特效参数不变。 |
| 2026-11-09 | V31 / 备份`aef8d32` | 普通音序2秒→1.5秒，每格187.5毫秒；声音、白点、充能和试射同速，同种第1/3格间隔375毫秒。音频缓存64整轮/96秒。敌机仍0.5秒推进，19件武器、152样本及其他规则保留。 |
| 2026-11-08 | V30 / 备份`5e52ee0` | 双生棱镜由瞬时多束变为青粉前向双股羽流；新增晨羽前奏、潮汐弦歌、流萤织雨及24份钢琴/小提琴/竖琴音源。当前19件、152样本；实际羽弹上限256，真实激光/电弧保留类别。原128样本、2秒扫描、3＋3商店与+5强化保留。 |
| 2026-11-08 | V29 / 备份`2ea3f58` | 接入Filaments背景及署名，恢复左下音序与白点，商店3武器＋3道具、锁定独立行；回合主属性强化+3→+5，继续使用统一属性弹数公式。武器乐器样本和2秒扫描保持不变。 |
| 2026-11-08 | V28 / 备份`ce780a6` | 密集敌机避让数值原生化；武器种类、弹数、轨迹、光晕、尾迹、音源和2秒扫描规则保持V27。新增[高密度性能验证](V28_CROWD_PERFORMANCE.md)，不得把旧8秒/旧时钟基准视为本版帧率承诺。 |
| 2026-11-08 | V27 / 备份`6321236` | 按用户要求改为2秒一轮、每格0.25秒；白点、音频、发射和商店试听同步，同种第1/3格声音间隔0.5秒；原音源、音量与护盾不变。 |
| 2026-11-08 | V26.1 / 备份`cad0b22` | 按用户反馈把护盾收为195毫秒单次主声，裁去后面的两次小瞬态；前183毫秒保持原样、末12毫秒淡出，音量与其他反馈不变。 |
| 2026-11-08 | V26 / 备份`0698dcf`、`ba8cc0b` | 增加8项独立音量控制、0%静音与自动保存；背景与武器分离，调整音量不重编PCM；按视频28秒附近更新护盾反馈，保留击杀低鼓、拾取声及V25武器音色。 |
| 2026-11-08 | V25 / 备份`8418597` | 根据试玩反馈统一为钢琴、柔奏提琴、竖琴；10种钢琴变化，重制128样本、柔化起音并控制响度，保留固定扫描和同种重奏。 |
| 2026-11-08 | V24 / `5c925ce` | 建立16种现役武器的特效、乐器与原声索引；明确折光四斜向羽流、13种实体弹、固定声音与充能分离；确立以后同提交更新规则。 |

## 7. 核对来源

- [当前武器/初始配装/回合强化/商店参数快照](data-v37/weapon-selection.json)、[武器生产目录](../scripts/arsenal_catalog.gd)：名单、ID、属性、充能和音色键。
- [发射与命中](../scripts/main.gd)、[发射几何](../scripts/weapon_emission.gd)、[个体运动与视觉类别](../scripts/weapon_visuals.gd)：真实方向、曲线路径、实体弹与光学分工。
- [当前乐器索引](../audio/weapon_codex.json)、[音乐播放与混音](../scripts/music.gd)：样本、固定音色和实例重奏。
- [V31扫描与兼容验证](data-v31/SUMMARY.json)：19件声音/充能时序、可见白点、原生播放与96秒缓存回卷；敌机0.5秒推进、显式作曲和音量兼容。
- [V32初始配装验证](data-v32/SUMMARY.json)：实际开局覆盖全部行星、两种难度与四种预设，并核对舰体、占格和起始格发声。
- [V33背景连续播放验证](data-v33/SUMMARY.json)：真实Filaments在91秒处暂停、全部音量滑块、恢复默认、返回继续、商店/编辑器/菜单切换；保留修复前失败记录。
- [V34全武器声音/发射同步与三件初始配装验证](data-v34/SUMMARY.json)：19件实际发射与音符逐项对应，17件首弹与独立粒子，充能静音、同种叠奏、原生回卷及全关卡开局检查。
- [V26分类音量与反馈验证](data-v26/SUMMARY.json)；[V25音色验证汇总](data-v25/SUMMARY.json)：128份音源格式、固定扫描、原生重奏与弹道兼容回归；视觉专项基线见[V24汇总](data-v24/SUMMARY.json)。

击杀低鼓的机制背景见[反馈音频说明](GROOVE_CORE_KILL_FEEDBACK.md)，其余授权素材见[录音来源](AUDIO_SOURCE_MAP.md)；当前分类音量与28秒护盾以[V26说明](V26_AUDIO_CONTROLS.md)为准。

V36历史专项核对：[V36演奏层/原生时序/图鉴与作曲验证](data-v36/SUMMARY.json) · [同响度音色试听](audio-v36/timbre-equal-level-20s.wav) · [36秒前后对照](audio-v36/phrases-before-after-36s.wav)。V35样本主体与参考单音的历史核对仍见[V35记录](data-v35/SUMMARY.json)。

当前V37专项：[新配装与长音说明](V37_SUSTAINED_SALVO_VOICES.md) · [当前验证](data-v37/SUMMARY.json) · [20份长音能量测量](data-v37/sustain-review.json) · [新配装试听](audio-v37/starter-voices-18s.wav)。V36原同响度试听保持历史文件，不因本轮重建覆盖。
