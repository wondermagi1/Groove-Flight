# 霓光港：Blender 原创主世界

本次将新项目《律航》的驾驶员休整区制作成可步行的 3D 科幻都市广场。中央折跃漩涡连接 2D 音序射击，右侧停机坪终端连接飞船与驾驶员配置。

## 已交付资源

| 文件 | 内容 |
| --- | --- |
| `assets/city/neon_city.glb` | 约 9.9 MB；10 个按材质合并的运行时网格；147,941 三角形 |
| `source_art/city/neon_city.blend` | 1,133 个命名的可编辑建筑部件；保存独立 Blender 场景、材质、灯光及检查相机 |
| `assets/city/pilot.glb` | 37 个实体身体/服装部件、11 根命名骨骼、Walk 与 Idle 动画 |
| `source_art/city/pilot.blend` | 可编辑的原创飞行员模型、骨骼与动作 |
| `tools/build_neon_city.py` | 可复现的建筑生成工具；种子 4219；新建场景，保留已有场景 |
| `tools/build_city_pilot.py` | 可复现的飞行员生成工具及骨骼动画制作 |

模型由本地 **Blender 4.5.9 LTS** 实际生成并导出；没有下载、提取或重新使用商业 Demo 模型。Blender MCP 此次未连接，建模使用独立后台 Blender 会话完成。`.blend` 放在带 `.gdignore` 的源文件目录内，运行时只加载 GLB，用户机器无需安装 Blender 即可游玩。

## 场景设计

- 16 座具有不同轮廓的建筑：切角主塔、双翼支架、阶梯通讯塔、八角数据塔，最高约 83 米。
- 可步行的分层圆形广场，放射状地面拼板、嵌入式导引灯、长椅、基站与街灯。
- 多层空中连桥、升降机外壳、金属支撑与栏杆，远景建筑通过大气雾分层。
- 中央漩涡含独立金属外环、24 组电容、支撑柱、青蓝高光环与紫蓝旋转螺旋。
- 右侧停机坪含实体飞船、机翼、驾驶舱、推进器、着陆支架和机库触摸终端。
- 飞行员具有人类面部、头盔、飞行服、围巾、护甲、手套与靴子；移动使用独立肢体骨骼动作，身体不整体左右扭动。

Godot 场景使用独立 3D SubViewport：Forward+、2×MSAA、柔和方向阴影、环境光遮蔽、屏幕空间反射、霓虹辉光及距离雾。切换到战斗时同时停止此视口的绘制与子节点处理，保留主世界位置供返回。

## 操作及接入

- WASD：移动；Shift：奔跑。
- 按住鼠标右键：旋转视角；滚轮：拉近或拉远。
- 靠近中央漩涡，按 F：调用 `game.start_run()`。
- 靠近右侧机库终端，按 F：调用 `game.open_hangar()`。
- `scripts/neon_hub.gd` 为 CanvasLayer，设置 `game` 后加入树；`activate()` / `deactivate()` 可重复调用，返回时不重置位置。
- 只有 `game.state == "hub"` 时接收行走与交互。机库和设置界面保留可见都市，但不允许角色继续移动。

## 验证与范围

`tests/neon_hub_review.gd` 在真实 Vulkan Forward+ 渲染下完成 10 项检查，结果保存在 `tests/results-neon-hub.json`；含 GLB 加载、Idle/Walk、真实输入移动、界面冻结、位置保留、两处 F 交互，以及离开后的视口停用。

实际渲染截图：`docs/screenshots/12-neon-harbor-forward.png`、`13-neon-harbor-pilot.png`。已人工查看截图中的模型、光影、漩涡、飞行员与文字对比度。

当前可探索范围是约 45 米直径的都市广场；远处高楼、空中连桥和展示飞船用于建立城市纵深，尚未开放楼内、连桥登乘或自由驾驶。10 项检查验证原型流程，未宣称长时间稳定帧率或完整开放世界。

## 重新生成

在独立 Blender 会话执行：

```text
blender --background --factory-startup --python tools/build_neon_city.py
blender --background --factory-startup --python tools/build_city_pilot.py
```

生成器新建自己的场景并将 `.blend` 保存为副本。修改源模型后重新导出同名 GLB，Godot 自动重新导入。
