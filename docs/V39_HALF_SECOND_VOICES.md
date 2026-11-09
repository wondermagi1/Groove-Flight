# V39：图鉴与实战统一半秒演奏

2026-11-09，`0.39.0-half-second-voices`。按用户最新反馈，十件三四轮武器的四档音源由1秒改为**0.5秒**，共40份。其余36份力度与152份显式作曲音高保留，总计228份。

每份为11,025帧／22,050Hz单声道PCM16。重新渲染0.28秒持音＋0.22秒释放，末35毫秒平滑淡出；声学弦层更早渐入，并按短持音段校准，保留清晰起音、四档音色差异和原根音。没有加快播放、移调、静音补长或仅在图鉴中截断；图鉴按钮和实战都读取同一组短WAV。

图鉴在单档与乐句试听状态中显示实际播放资源时长，例如“很强 · 0.50秒”，重音名称同步去掉旧长音描述。乐句各次发声的间隔仍由充能决定：三轮4.5秒、四轮6秒；缩短的是单声演奏，不是充能或音序周期。

新星环炮、七彩折光匣、终压攻城铳、鎏金螺旋阵、虹织十字炮、星冕回旋阵、尾羽回响、晨羽前奏、潮汐弦歌、流萤织雨均覆盖很弱／弱／强／很强四档。策略与SHA见[统一策略](../audio/instruments/WEAPON_DYNAMICS.json)、[当前演奏清单](../audio/instruments/DYNAMICS_MANIFEST.json)；上一版元数据见[修改前清单](../audio/instruments/archives/DYNAMICS_MANIFEST-before-v39.json)。

[流萤半秒强奏](../audio/arsenal/dynamics/dyn_firefly_rain_2.wav) · [流萤半秒很强](../audio/arsenal/dynamics/dyn_firefly_rain_3.wav)。重建命令：`python tools/build_weapon_dynamics.py --ids nova,scatter_prism,recorded_heavy,gilded_helix,weave_cross,crown_orbit,stern_fan,dawn_fan,tidal_weave,firefly_rain`，随后进行Godot导入与生产索引导出。

[当前验证](data-v39/SUMMARY.json)记录40份精确半秒WAV、导入资源、图鉴40个实际按钮、四档句法、原生声画同步与144秒回卷。当前环境不能直接听音，音色舒适度仍需用户试听。

本轮仅改声音资源、图鉴说明与音频缓存版本；V38齐射、射程、彩虹、材质、弹数、伤害、充能、初始配装、1.5秒音序和0.5秒敌机动作保留。13种未来乐器框架也保留，新增乐器尚未接入。

修改前备份：`codex/backup-20261109-before-half-second-voices`，SHA `5e32ac7cd195a63b1f6c9638f3b5b54830425660`，已上传并核验。开发：`codex/v39-half-second-voices`。长期维护：[武器特效与音频对应表](WEAPON_VFX_AUDIO_REFERENCE.md)。
