# 武器特效与音频对应表（持续维护）

最后更新：2026-11-11。核对版本：`0.54.0-three-track-score`。J/K/L三列直接对应A/B/C武器轨，每6秒该轨得分÷理论满分决定下一段弹量，开局6秒全轨100%。当前失误不再取消本发攻击，武器按原充能和音乐点自动齐射；0弹不产生新起音。24武器/288WAV、原单弹伤害/运动/音色、八星歌曲任务保留。修改前备份`4325c6a`已上传核验。[V54说明](V54_THREE_TRACK_SCORE.md)与[当前核对](data-v54/SUMMARY.json)。琴块面板紧靠音序器右侧并底部对齐，窄屏空间不足时移至右上方。

V53以来的背景与音乐点：水星Filaments、金星Helios、地球Reverie、火星Legionnaire (Original)、木星Titan、土星Cassini、天王星Luminance、海王星Omega，均为Scott Buckley CC BY4.0完整原曲转Vorbis。来源/哈希/署名/试听文件在[现行歌曲目录](../audio/PLANET_MUSIC.json)、[授权说明](../audio/authorized/scott_buckley/planets/LICENSE.md)及[V53逐曲试听表](V53_PLANET_SCORES_MISSIONS.md)。`rhythm_chart.gd`按当前星球读取`audio/charts/planets/*.json`；局部节拍路径、可闻起音、当前schema3保留原音乐点/长按，不再指定四键列，不宣称精确扒谱。背景各自按完整时长循环，原生PCM仍12+144秒且不预混武器声。设置校准默认0，每5ms一步，正值使琴块/发射稍晚，负值稍早；不改音高/音源长度、充能相位、判定宽度、BGM进度或混音总线。

历史V51声音与输入约定（V54已替换单块发射门控）：普通战役24武器使用H/J/K/L四列音乐琴块，包含短按、长按、双键同时按。有效窗口±75毫秒、完美±35毫秒，双键间隔≤60毫秒且重叠；长按0.30–0.65秒，到尾端才发射。错键/漏按/中断不产生新齐射或起音，不推进力度乐句。原1.5秒音序充能资格、伤害/弹数/材质、288WAV与敌人机制保留。修改前备份`bcf7955`已上传核验。[本轮说明](V51_MUSIC_CHART_PIANO.md)与[当前核对](data-v51/SUMMARY.json)。

当前发射/声音路径（V54）：保留原1.5秒/8格与各武器充能资格，映射该星球歌曲的下一音乐点，长按类按其尾端自动齐射。三列仅对应自己的装备轨，同轨同点可共用琴块，不同轨分别计分；当前段输入不会再直接取消齐射。完美100、普通成功70、漏按/中断0分，得分/满分决定下一个6秒的最终弹量，空段沿用。数量先算属性/品质/精炼/驾驶员/超载，再乘比例，各UID/来源轨累计小数；0%仍继续出评分琴块以便恢复。单弹伤害、射速、射程、折射/传导不再额外缩放。只有实际非零弹量齐射播放一次原动态WAV并推进力度，0弹没有炮口、声音或额外伤害，既有弹体/尾音保留。背景与战斗时钟在购物/暂停/设置/编排/图鉴共同保持，156秒PCM仍排除全部武器声，实时混音/声像/总线及独立同类叠奏保留。自由作曲、图鉴、商店试听仍走原显式/自动路径。

V49敌方表现：Boss射线延长到2500，预警带与实际判定共用带宽；Boss独立大弹体、光晕、白热内芯及直线残迹使用批量绘制。普通机仍不射击，精英弹体保留原样；玩家武器的VFX/audio规则不因Boss难度升级改变。

2026-11-10 Demo交付核对：V49 Windows x64导出保留24件武器/288份现役WAV与原声音时序、力度、弹道。暂存导入统一禁用WAV压缩，避免作曲器将QOA当PCM；没有重采样、重渲染或修改源WAV。全新解压包通过361项资源/API检查，默认/兼容模式正式EXE启动和原生DLL加载通过。见[Demo说明](WINDOWS_DEMO.md)与[验证快照](data-demo-v49/VERIFICATION.json)。

V47实弹成长：实弹流波末三选一固定两项实弹强化、一项通用强化。实弹池包含+3/+5/+7/+10（各权重3）与×1.5/×2/×3（权重2/1/1），同次不重复。倍率在选取时读取当前实弹，差额记为本局永久加点；后续新属性正常相加，不产生永久乘区。实弹流波末不再出现支援/能量/动力+5，通用生存、机动、经济与单发伤害选项保留。开局+10与已结算差额均进入现行属性弹数/伤害公式，并在属性来源中显示；已有1000属性与256实体弹上限保留，单次齐射仍只发一声。

这是当前现役武器的统一查阅入口。后续在同一份文档持续更新；历史版本说明和旧武器档案保留在原处。表中均为已经接入的内容，待开发设想另列。

现役共**24种武器**：15种共享羽状质感、18种实体弹、3种真激光、3种电链。共288WAV：192作曲音高、96力度；12钢琴变化、4弓弦、4竖琴、2单簧管、2长笛。V42新增48份木管样本，旧240份保留。万花筒4轮/6秒间隔，基础96弹、基础史诗品质实际100发；声音仍0.5秒。见[V42实现与验证](V42_CONDUCTIVE_LIGHT.md)。

开发遵循[统一武器开发规范](WEAPON_DEVELOPMENT_STANDARD.md)，汇总独立受力、曲线残迹、射程后退场、同类材质和后续13乐器组/充能覆盖。新增武器必须参照它；[V40数值与图鉴说明](V40_BALANCE_CODEX_FOUNDATION.md)。

## 1. 武器、画面与声音对照

下表乐器链接指向现役“强”档演奏WAV；每件四档完整链接见第2节。“弹体充能”表示每几轮获得一次资格，V54继续映射音乐点自动齐射。表中数量/形式为100%弹量基准，实际数量额外受该轨上一段6秒成绩影响；单弹伤害与音源本身不改。实际非零齐射一声，0弹无新起音。

所有星球/难度/舰体在战前明确选择本局流派，初始均为**两件**。实弹流：**脉冲机炮 A3、苍穹轨炮 B4–B5**；激光流：棱镜光束 A3–A4、曦光束阵 B4–B5；闪电链流：跃迁电弧 A3–A4、鸣雷枝杈 B4–B5。**所有关卡去掉初始流萤织雨**，仍可在实弹商店购买；不保留旧C6–C8武器占格。有效舰体非武器道具保留，后续波次不重置编排。占用尾格不重复响。

| 战斗流派 | 对应现役池 | 原扫描充能资格时刻与间隔（非最终起音） | 当前12秒音色试听（不要求击键） |
| --- | --- | --- | --- |
| 实弹 | 18件实际弹体，含导弹及能量属性羽弹；排除真激光/电链 | 脉冲0.375秒/每1.5秒；轨炮2.0625秒/每3秒 | [钢琴＋大提琴](audio-v43/starter-ballistic.wav) |
| 激光 | 棱镜光束、曦光束阵、穹光轮舞 | 棱镜0.375秒/每1.5秒；曦光0.5625秒/每1.5秒 | [小提琴＋长笛](audio-v43/starter-laser.wav) |
| 闪电链 | 跃迁电弧、鸣雷枝杈、风暴回路 | 跃迁1.875秒/每3秒；鸣雷0.5625秒/每1.5秒 | [竖琴＋单簧管](audio-v43/starter-lightning.wav) |

上表秒数表示充能资格。实际齐射还要等音乐点/长按类尾端，但V54不再要求当前琴块通过；发射数量受上一段成绩影响。同种不同格可在同轨同点合奏，各UID声音独立，试听不代表现行实战起音间隔。

流派按 `visual_class` 和实际运动分，独立于四种主属性/乐器轴。彗星导弹、七彩折光匣、双生棱镜留在实弹池。通用生存和适用增益可共用，专属道具、获取入口与祝福按流派过滤；西风只在实弹流第三/四波未拥有时保证。完整武器/道具名单见[当前分流快照](data-v43/doctrine-pools.json)与[V43说明](V43_DOCTRINE_CAMPAIGNS.md)。

| 武器 / ID | 发射形式与运动 | 弹体、光色与尾迹 | 乐器代表音色（强奏试听） | 对应主属性 | 弹体充能 |
| --- | --- | --- | --- | --- | ---: |
| 脉冲机炮<br>`pulse` | 朝瞄准方向错时喷射；各弹独立初速、偏角和摆动 | 青绿色羽状弹、柔光、细曲线尾迹 | [延音中音钢琴](../audio/arsenal/dynamics/dyn_pulse_2.wav) | 实弹 | 1轮 |
| 星砂霰弹<br>`scatter` | 前向扇面散射；各颗在扇面内独立推进、错位 | 暖金色羽状弹；共享鎏金基底 | [明亮延音钢琴](../audio/arsenal/dynamics/dyn_scatter_2.wav) | 实弹 | 1轮 |
| 棱镜光束<br>`beam` | 朝瞄准方向发射多条直束；各束微小方向、宽度和闪光差异 | 淡紫束芯与能量鞘，保留激光形态 | [清晰弓头小提琴](../audio/arsenal/dynamics/dyn_beam_2.wav) | 能量 | 1轮 |
| 彗星导弹<br>`missile` | 向前发射后独立追踪；各弹转向响应不同，命中爆破 | 粉红导弹实体、推进尾焰与弯曲残迹 | [温暖低音钢琴](../audio/arsenal/dynamics/dyn_missile_2.wav) | 动力 | 2轮 |
| 新星环炮<br>`nova` | 三层错时全周星环，层间交错角度并有反向弯转；实际行程2400 | 浅绿能量珠、局部柔光、细弧形尾迹 | [圆润重奏钢琴](../audio/arsenal/dynamics/dyn_nova_2.wav) | 能量 | 4轮 |
| 跃迁电弧<br>`chain` | 先连向目标，再向附近敌人跳跃；各段有稳定的独立相位 | 蓝色分支电流与局部辉光 | [柔和高音竖琴](../audio/arsenal/dynamics/dyn_chain_2.wav) | 能量 | 2轮 |
| 苍穹轨炮<br>`rail` | 朝瞄准方向高速贯穿；各弹独立受力、保留主方向 | 冰白羽状弹；实际路径尾迹 | [厚弓大提琴](../audio/arsenal/dynamics/dyn_rail_2.wav) | 实弹 | 2轮 |
| 星针狙击器<br>`pulse_needle` | 朝瞄准方向集中喷射；个体速度与细微弯转不同 | 青白羽状弹；共享羽状质感 | [清亮高音钢琴](../audio/arsenal/dynamics/dyn_pulse_needle_2.wav) | 实弹 | 1轮 |
| 七彩折光匣<br>`scatter_prism` | 四个斜向羽冠分排绽放，扩大开口与摆幅，实际抵达后命中；行程2050 | 七彩羽状实体弹；与尾羽共享柔光和真实弯曲尾迹 | [珠光重奏钢琴](../audio/arsenal/dynamics/dyn_scatter_prism_2.wav) | 实弹 | 4轮 |
| 双生棱镜<br>`beam_split` | 机头两侧向前喷出青粉双股羽流，各股反相摇摆，每颗独立飞行，抵达后才命中 | 与尾羽共享羽状实体、柔光、弯曲残迹；不再瞬时直束 | [绵奏中提琴](../audio/arsenal/dynamics/dyn_beam_split_2.wav) | 能量 | 2轮 |
| 地平线终奏<br>`rail_horizon` | 沿实际机身左右两翼喷射；低初速出膛，再各自加速和摆动 | 绿色羽状弹流；柔光与逐渐变细的实际尾迹 | [深色低音钢琴](../audio/arsenal/dynamics/dyn_rail_horizon_2.wav) | 实弹 | 8轮 |
| 终压攻城铳<br>`recorded_heavy` | 中轴和两侧三列交叉贯穿齐射，独立出膛/受力；行程上限2400 | 暖橙羽状实体弹；当前使用统一羽状基底 | [厚实中低音钢琴](../audio/arsenal/dynamics/dyn_recorded_heavy_2.wav) | 实弹 | 4轮 |
| 鎏金螺旋阵<br>`gilded_helix` | 三层不同半径、交错角度和反向弯转的金色螺旋；实际行程2400 | 金色发光叶状弹头；同类羽弹的质感基准 | [明亮三角钢琴](../audio/arsenal/dynamics/dyn_gilded_helix_2.wav) | 能量 | 4轮 |
| 虹织十字炮<br>`weave_cross` | 四向各分双股，形成八翼交织阵列，扩大实际侧向摆动；行程2050 | 彩色羽状弹流、错位交织尾迹 | [断奏钢琴＋高音小提琴](../audio/arsenal/dynamics/dyn_weave_cross_2.wav) | 实弹 | 3轮 |
| 星冕回旋阵<br>`crown_orbit` | 3–8层星冠从近舰位置渐次展开，交替转向、各自惯性呼吸；半径230起每层+52 | 彩色环绕实体与柔光；细曲线残迹 | [竖琴＋高音小提琴](../audio/arsenal/dynamics/dyn_crown_orbit_2.wav) | 支援 | 3轮 |
| 尾羽回响<br>`stern_fan` | 机尾U形羽幕分层错时展开，开口更宽、独立弯转；实际行程2400 | 左翼绿黄、中央橙黄、右翼粉紫的羽状弹流 | [中音竖琴＋中提琴](../audio/arsenal/dynamics/dyn_stern_fan_2.wav) | 实弹 | 3轮 |
| 晨羽前奏<br>`dawn_fan` | 机头前方左/中/右三瓣羽扇分排展开，各颗独立飞行；实际行程2400 | 绿、金、橙、粉连续过渡的羽弹与曲线尾迹 | [柔亮高音钢琴](../audio/arsenal/dynamics/dyn_dawn_fan_2.wav) | 实弹 | 3轮 |
| 潮汐弦歌<br>`tidal_weave` | 前方四股反相潮汐编织，扩大横向摆幅；实际行程2400 | 青粉羽弹、局部柔光与真实弯曲残迹 | [高音小提琴](../audio/arsenal/dynamics/dyn_tidal_weave_2.wav) | 能量 | 4轮 |
| 流萤织雨<br>`firefly_rain` | 宽幅彩虹扫射幕，多列错峰、向前加速与独立摆动；实际行程2400 | 与尾羽同系绿黄橙粉紫彩虹羽弹，光晕与真实曲线尾迹同步着色 | [高音竖琴＋高音小提琴](../audio/arsenal/dynamics/dyn_firefly_rain_2.wav) | 动力 | 3轮 |
| 万花筒<br>`kaleidoscope` | 96基础弹六瓣旋转甩射，切向速度渐转径向，实际行程2300；装备期间同轨自由实体弹继承该形式，各自充能/弹数/伤害保留 | 珠光紫/粉/淡白羽弹，52×15轮廓、柔光与真实曲线残迹；其他武器继承形式时保留原颜色材质 | [珠光高音三角钢琴](../audio/arsenal/dynamics/dyn_kaleidoscope_2.wav) · G5 | 实弹 | 4轮 |
| 鸣雷枝杈<br>`arc_bough` | 分叉跳链，锁定1100/基础跳跃360；击杀后三向分流 | 薰蓝电弧、稳定分支相位、柔光节点 | [高音单簧管G4](../audio/arsenal/dynamics/dyn_arc_bough_2.wav) | 能量 | 1轮 |
| 风暴回路<br>`chain_loop` | 多目标传导后回流闭环，锁定1450/基础跳跃480；回流不重复伤害 | 粉紫电网与闭环余辉 | [低音单簧管G3](../audio/arsenal/dynamics/dyn_chain_loop_2.wav) | 能量 | 4轮 |
| 曦光束阵<br>`laser_fan` | 机头扇形脉冲，基础1折射，总行程1500；真实折线/穿透顺序 | 薄荷青直束、白热芯与能量鞘 | [高音长笛C5](../audio/arsenal/dynamics/dyn_laser_fan_2.wav) | 能量 | 1轮 |
| 穹光轮舞<br>`laser_crown` | 四周分段扫射，0–0.42秒展开，基础2折射，总行程2200 | 暖金激光轮冠，后续束出现时才伤害 | [中音长笛C4](../audio/arsenal/dynamics/dyn_laser_crown_2.wav) | 能量 | 6轮 |

V41射程复核：表内“实际行程”以最终速度×寿命及2400封顶核算，不把`salvo_patterns.gd`的标称范围直接当成结算距离；原九件非环绕大范围武器基础实际行程均为2400，万花筒基础2300，射程改装仍受共同上限限制。这里只纠正文档表述，原19件参数未改。

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

V39十件三四轮武器的四档均为0.5秒（每份11,025帧），强奏/很强保持声学弓弦层及已有起音力度。旧V37长音文件已由当前链接替换；历史试听保留于旧版文件夹。

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

万花筒四档（均0.50秒）：[很弱](../audio/arsenal/dynamics/dyn_kaleidoscope_0.wav) · [弱](../audio/arsenal/dynamics/dyn_kaleidoscope_1.wav) · [强](../audio/arsenal/dynamics/dyn_kaleidoscope_2.wav) · [很强](../audio/arsenal/dynamics/dyn_kaleidoscope_3.wav)。实际发射每4轮/6秒一次，很强→强交替。

V42新声部四档均0.50秒：

鸣雷枝杈：[很弱](../audio/arsenal/dynamics/dyn_arc_bough_0.wav) · [弱](../audio/arsenal/dynamics/dyn_arc_bough_1.wav) · [强](../audio/arsenal/dynamics/dyn_arc_bough_2.wav) · [很强](../audio/arsenal/dynamics/dyn_arc_bough_3.wav)

风暴回路：[很弱](../audio/arsenal/dynamics/dyn_chain_loop_0.wav) · [弱](../audio/arsenal/dynamics/dyn_chain_loop_1.wav) · [强](../audio/arsenal/dynamics/dyn_chain_loop_2.wav) · [很强](../audio/arsenal/dynamics/dyn_chain_loop_3.wav)

曦光束阵：[很弱](../audio/arsenal/dynamics/dyn_laser_fan_0.wav) · [弱](../audio/arsenal/dynamics/dyn_laser_fan_1.wav) · [强](../audio/arsenal/dynamics/dyn_laser_fan_2.wav) · [很强](../audio/arsenal/dynamics/dyn_laser_fan_3.wav)

穹光轮舞：[很弱](../audio/arsenal/dynamics/dyn_laser_crown_0.wav) · [弱](../audio/arsenal/dynamics/dyn_laser_crown_1.wav) · [强](../audio/arsenal/dynamics/dyn_laser_crown_2.wav) · [很强](../audio/arsenal/dynamics/dyn_laser_crown_3.wav)

## 3. 声音与弹道怎样对应

当前为1.5秒一轮，按实际发射发声；V36按有效充能加入纯音频力度乐句，1轮四档渐强、2轮弱强、3–4轮疏重音。详见[V36说明与同响度试听](V36_EXPRESSIVE_WEAPON_VOICES.md)。当前试听见本表上方三个流派的12秒链接；[V40旧三件配装试听](audio-v40/starter-synchronized.wav)仅作历史。V31每轮发声及V27的2秒试听保留作历史对比。

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

### V42组合与能量规则

- 西风：唯一、固定完整效果，不升级/不叠加；V43起仅实弹流未持有时第3/4波初始商店保证出现。约72%里程触发近水平右转，2.8倍速度、0.32秒短助推；此后惯性滑行，原有效射程与退场边界保留。
- 万花筒：4轮、96基础弹；同轨自由实体弹只同步甩射形式，原充能/声音/伤害/弹数/颜色保留。
- 真激光：每1能量+1折射（上限64），每次折射保留86%伤害，共用总行程；棱镜光束伤害12、曦光5.5、穹光13。
- 全部电链：每5能量+1传导（上限32），击杀向最近3个可用敌人分流；同次电流不重复命中，分流受深度/距离限制。后续段按实际期限命中。
- 传导、折射、分流不新增声音。光束/电链仍独立于西风和万花筒的实体弹逻辑。

## 5. 后续迭代必须同步更新

2026-11-09用户最新确认[统一13种乐器组开发总体框架](ORCHESTRAL_AUDIO_DIRECTION.md)：钢琴；小提琴、中提琴、大提琴、低音提琴；竖琴；长笛、单簧管、双簧管（独奏句）、巴松；三角铁、钟琴、定音鼓。该统一清单覆盖此前A/B组织方式。**这是完整开发框架；当前7种主乐器已接入，低音提琴、双簧管、巴松、三角铁、钟琴、定音鼓6种尚待制作。**先建立音源库与演奏力度，再按武器定位分配声部；当前生产样本仍以本表实际文件为准。

本文件固定为`docs/WEAPON_VFX_AUDIO_REFERENCE.md`。每次改动以下任一项，必须在**同一个修改提交**内同步维护本表，并更新日期、核对版本和下面的迭代记录：

- 新增、停用、删除或更名武器，以及稳定ID、对应主属性或充能规则。
- 发射方向、发射形式、弹体类别、颜色、光晕、尾迹、摆动、追踪、射程退场。
- 乐器音色、voice键、实际样本路径、索引规则、固定声/分排/重奏行为。

更新时从当前生产武器目录和发射代码核对画面，从实际播放路径和WAV核对声音；逐项检查现役名单一致、试听链接可用、样本格式正确。替换音频时同步更新`audio/weapon_codex.json`及相关授权来源。历史验证数据保留，当前版本引用指向本轮结果；未实现的内容单列为计划。

维护要求已写入根目录[AGENTS.md](../AGENTS.md)。游戏代码、素材、平衡或视觉的每轮修改，仍先执行既定的远程Git备份与SHA核验。

## 6. 迭代记录

| 日期 | 游戏版本 / 基线 | 本表变更 |
| --- | --- | --- |
| 2026-11-11 | V54 / 备份`4325c6a` | 三列J/K/L绑定A/B/C，每6秒成绩决定下一段最终弹量，首段100%；普通齐射自动按原充能/音乐点进行，非零齐射一声，小数独立累计。八曲3487候选点的时间/长按、24武器/288WAV/原伤害弹道保留；琴块移至音序器右侧。 |
| 2026-11-11 | V53 / 备份`6a91158` | 八首逐星完整背景曲、八份局部节拍/起音/乐句谱面；四键立体琴块/细长按轨/命中早晚提示，±150ms校准。八星实际任务与Boss共同通关；24武器/288WAV、充能/弹道/属性弹数及单次起音规则保留。 |
| 2026-11-11 | V52 / 备份`c22af8b` | 统一中性黑灰UI材质/字体/按钮/滑杆；四键深色轨道、白色琴块和淡金反馈，整理HUD与Boss间距。V51全部触发、音源及实际武器/弹道/数值不变；图鉴区分试听间隔与实战琴块。 |
| 2026-11-11 | V51 / 备份`bcf7955` | H/J/K/L四键；Filaments波形编排561个候选点，短按/长按/双键；资格转交下一音乐点，长按尾端授权；共同暂停与分别循环背景/PCM，保持24武器/288WAV、伤害弹数与实际弹道。 |
| 2026-11-10 | V50 / 备份`99f4618` | 历史三列J/K/L强制输入，失败不发射；实时成功声部替代战役预混武器，力度按成功次数推进。 |
| 2026-11-10 | V49 / 备份`d818e73` | 八星Boss提高出招、覆盖、弹速，扩展预警/射线/大弹体/尾迹/机体蓄能表现；冲锋蓄力与运动衔接修复。友方24武器与288WAV、属性/充能规则保留。 |
| 2026-11-10 | V48 / 备份`b9e7f95`、`b1d214c` | 普通机取消冲停，持续行进；武器品质第2波可刷史诗、第3波可刷传奇，3+3/锁定/价格保留。24武器/288WAV、1.5秒音序及V47实弹成长不变。 |
| 2026-11-10 | V47 / 备份`a948e86`、`53b3b90` | 敌机0.25秒步进；实弹流开局+10，波末两项实弹/一项通用；新增+3/+7/+10与一次性×1.5/×2/×3，保留+5，属性弹数和伤害同步。武器基础表、齐射形式与288WAV保留。 |
| 2026-11-10 | V46 / 备份`9e7c967` | 撤销V44 UI皮肤，战斗顶部白字/按钮默认透明、悬停轻反馈，倒计时加大加粗；原始背景、敌我舰体、24武器/288WAV与玩法保留。 |
| 2026-11-10 | V45 / 备份`3b6b84a` | 撤销V44青绿色战场，背景着色器/贴图绑定精确恢复059ceb2；UI/舰体细节保留。24武器/288WAV及玩法不变；V44截图保留为历史。 |
| 2026-11-09 | V44 / 备份`059ceb2` | 六组UI与敌我舰体细化、参考视频青绿背景；24武器参数/颜色/运动、288WAV及V43流派/初始不变。更新当前版本/目录/资产核对；新图是实际Forward+自动渲染，未做人工画面评审。 |
| 2026-11-09 | V43 / 备份`42187dc` | 战前明确选择实弹18/激光3/电链3；全获取路径及道具/祝福按流派过滤，导弹/实体棱镜留实弹。所有关卡取消初始流萤，改两件流派配装；288音源/24参数/VFX不变，更新三份实装试听和当前快照。 |
| 2026-11-09 | V42 / 备份`8516717` | 新增两链两激光、单簧管/长笛48WAV；万花筒4轮/96基础弹，西风完整唯一且第3/4波保证，详情点击固定。激光每能量+1折射，电链每5能量+1传导及击杀三分流，根齐射一声。 |
| 2026-11-09 | V41 / 备份`fa85541` | 新增西风真实后段加速、6轮万花筒和同轨旋转甩射，20种现役/240WAV；新增12份钢琴样本，旧228份及19件基础参数保留。实体碰撞、射程和计数守恒；图鉴缩放保留实例。 |
| 2026-11-09 | V40 / 备份`63385cb` | 图鉴增加主乐器及充能分组/交叉筛选，13类和1/2/3/4/6/8档覆盖表；支持6轮强/很强乐句、144秒相位连续，缓存版本13。19种现役基础充能/特效/样本保留。新增统一武器开发规范，未来乐器和武器尚未增加。 |
| 2026-11-09 | V39 / 备份`5e32ac7` | 十件三四轮武器四档共40份演奏缩至0.5秒；提琴重新缩短持音/释放，图鉴与实战同源，实际按钮显示0.50秒。其余36份力度与152音高保留；齐射、范围、彩虹、弹数、伤害和充能保留。 |
| 2026-11-09 | V38 / 备份`b1fcc51` | 最新统一十件三四轮武器的40份演奏为1秒；流萤使用尾羽同系彩虹；升级十种实际分层齐射和范围，1850–2400行程、星冠230起展开。共用原弹头/光晕/尾迹，不按分支加弹或加声音；单发伤害和充能保留。 |
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

- [当前武器/初始配装/回合强化/商店参数快照](data-v42/weapon-selection.json)、[武器生产目录](../scripts/arsenal_catalog.gd)：名单、ID、属性、充能和音色键。
- [发射与命中](../scripts/main.gd)、[发射几何](../scripts/weapon_emission.gd)、[个体运动与视觉类别](../scripts/weapon_visuals.gd)：真实方向、曲线路径、实体弹与光学分工。
- [当前乐器索引](../audio/weapon_codex.json)、[音乐播放与混音](../scripts/music.gd)：样本、固定音色和实例重奏。
- [V31扫描与兼容验证](data-v31/SUMMARY.json)：19件声音/充能时序、可见白点、原生播放与96秒缓存回卷；敌机0.5秒推进、显式作曲和音量兼容。
- [V32初始配装验证](data-v32/SUMMARY.json)：实际开局覆盖全部行星、两种难度与四种预设，并核对舰体、占格和起始格发声。
- [V33背景连续播放验证](data-v33/SUMMARY.json)：真实Filaments在91秒处暂停、全部音量滑块、恢复默认、返回继续、商店/编辑器/菜单切换；保留修复前失败记录。
- [V34全武器声音/发射同步与三件初始配装验证](data-v34/SUMMARY.json)：19件实际发射与音符逐项对应，17件首弹与独立粒子，充能静音、同种叠奏、原生回卷及全关卡开局检查。
- [V26分类音量与反馈验证](data-v26/SUMMARY.json)；[V25音色验证汇总](data-v25/SUMMARY.json)：128份音源格式、固定扫描、原生重奏与弹道兼容回归；视觉专项基线见[V24汇总](data-v24/SUMMARY.json)。

击杀低鼓的机制背景见[反馈音频说明](GROOVE_CORE_KILL_FEEDBACK.md)，其余授权素材见[录音来源](AUDIO_SOURCE_MAP.md)；当前分类音量与28秒护盾以[V26说明](V26_AUDIO_CONTROLS.md)为准。

V36历史专项核对：[V36演奏层/原生时序/图鉴与作曲验证](data-v36/SUMMARY.json) · [同响度音色试听](audio-v36/timbre-equal-level-20s.wav) · [36秒前后对照](audio-v36/phrases-before-after-36s.wav)。V35样本主体与参考单音的历史核对仍见[V35记录](data-v35/SUMMARY.json)。

V37历史专项：[新配装与长音说明](V37_SUSTAINED_SALVO_VOICES.md) · [当前验证](data-v37/SUMMARY.json) · [20份长音能量测量](data-v37/sustain-review.json) · [新配装试听](audio-v37/starter-voices-18s.wav)。V36原同响度试听保持历史文件，不因本轮重建覆盖。

V38历史专项：[一秒音源与十种展开](V38_ONE_SECOND_GRAND_SALVOS.md) · [当前验证](data-v38/SUMMARY.json) · [十种原生齐射总览](screenshots/v38-grand-salvos.png)。

当前V49：[Boss攻势与特效](V49_BOSS_PRESSURE.md) · [当前目录](data-v49/weapon-selection.json) · [验证汇总](data-v49/SUMMARY.json)。[V48持续移动与商店](V48_CONTINUOUS_ENEMIES.md)及[V47实弹开局与波末强化](V47_QUARTER_STEP_ENEMIES.md)继续有效。V46 UI说明保留为历史：[UI回退与透明HUD](V46_CLEAR_COMBAT_UI.md)。

历史V45：[原始背景回退](V45_ORIGINAL_BACKDROP.md) · [当前目录](data-v45/weapon-selection.json) · [验证汇总](data-v45/SUMMARY.json)。

历史V44：[UI与舰体说明](V44_JADE_FLEET_UI.md) · [当前目录](data-v44/weapon-selection.json) · [分流目录](data-v44/doctrine-pools.json) · [验证汇总](data-v44/SUMMARY.json)。

历史V43：[战前流派说明](V43_DOCTRINE_CAMPAIGNS.md) · [分流目录](data-v43/doctrine-pools.json) · [验证汇总](data-v43/SUMMARY.json)。

历史V42：[光电与西风说明](V42_CONDUCTIVE_LIGHT.md) · [验证汇总](data-v42/SUMMARY.json)。

历史V41：[实现与参考分析](V41_WESTWIND_KALEIDOSCOPE.md) · [生产覆盖/航线快照](data-v41/run-foundation.json) · [验证汇总](data-v41/SUMMARY.json)。

历史V40：[数值与图鉴](V40_BALANCE_CODEX_FOUNDATION.md) · [乐器/充能和航线快照](data-v40/run-foundation.json) · [验证汇总](data-v40/SUMMARY.json)。

历史V39专项：[半秒图鉴/实战声音](V39_HALF_SECOND_VOICES.md) · [当前验证](data-v39/SUMMARY.json)。
