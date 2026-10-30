# 验证报告入口

当前V6本地MP3识谱版本请查看[最新测试报告](TEST_REPORT_V6.md)。[V5自由作曲](TEST_REPORT_V5.md)、[V4太阳系航线](TEST_REPORT_V4.md)、[V3装备与旋律记录](TEST_REPORT_V3.md)及以下V2城市舰队记录保留为历史验证，V2独立副本为`TEST_REPORT_V2.md`。

## v2 neon harbor / fleet verification

2026-10-29, Windows, Godot4.7.2, NVIDIA RTX4060 Laptop GPU. Automated runs use an isolated profile and `--beatdrift-test`, without writing player settings or older-game saves. V1 history is in `TEST_REPORT_V1.md`.

## Focused and integrated checks

| Suite | Checks | Result / scope |
| --- | --- | --- |
| prototype_review.gd |58|Passed: native audio, six actual weapon impacts, ownership, real input,12288-square world, editing, pause, rewards, death/retry |
| ui_review.gd |9|Passed: title projectile opens settings, volume/particle controls and safe return |
| title_hub_review.gd |10|Passed: title flight, selection/result-layout fixtures and resize |
| neon_hub_review.gd |10|Passed: Blender GLB, skeleton animation, motion, portal/terminal callbacks with a mock game |
| harbor_flow_review.gd |15|Passed: actual title impact→city→fleet/settings→F departure→native combat; results return is an explicit fixture |
| fleet_density_review.gd |110|Passed:9 configurations, actual movement/damage/cooldowns, pilot passives, seeded spawns/edge safety, collision seams/tunneling, split births, boss win, drop merges/caps |

The main-city integration uses the actual scene and Vulkan Forward+. It verifies the city render target/child animations stop in2D combat, and reopening preserves avatar position. It does not claim the45m plaza is a fully explorable metropolis; towers/bridges currently provide scenery.

## Native ten-wave run

The runner uses production durations/native soundtrack and actual reward buttons, defeating enemies/Boss through normal damage. Assistance: invulnerability, steering and automatic overload. No seeking, wave skips, injected kills or enemy HP reductions.

Final rerun passed27/27 checks:3938kills,3948spawns,124peak enemies,68peak friendly/123hostile bullets,356.55music seconds (356.78wall seconds),9real reward selections. Maximum late native-audio timing error was5.93ms. All ten waves and the final Boss completed through production damage. The prior screenshot fixture stalled frames while synchronously compressing PNGs; compression now runs on a worker while gameplay continues. This is an assisted automated completion, not human balance or listening acceptance.

## Dense controlled sample

The fixture holds480 stationary high-HP aircraft,800 friendly/450 hostile bullets with positive1damage. It injects positions and pauses audio to retain a stable workload. Ninety samples are a short measurement, not a stable-FPS certification or human difficulty test.

After96px occupied-grid/swept collision, six shared MultiMesh hulls and batched bullet trails:

| Renderer | Update median / P95 | Frame interval median / P95 | Draw calls |
| --- | --- | --- | --- |
| OpenGL Compatibility |7.27 /8.64ms|14.46 /16.17ms|85|
| Vulkan Forward+ |9.05 /9.74ms|16.10 /17.10ms|85|

RTX4060 Laptop, approximately1600×900 window. Full details: `tests/results-fleet-density-opengl3.json` and `results-fleet-density-vulkan.json`. Before batching the same controlled fixture took approximately82ms per frame; this does not promise performance on other PCs.

## Visual records / limits

`docs/screenshots`:08/09 title;10 selection fixture;11 results-layout fixture;12/13 standalone city;14 actual integrated city;v2-fleet-enemies role gallery;v2-dense-fixture instanced aircraft/bullets. `run-wave-*`, `run-boss`, `run-victory` are actual full assisted-run captures. Images were visually inspected; glare, invisible vortex shading and duplicated help text were corrected.

No commercial Demo assets were extracted. Editable `.blend` files and authored GLBs are included. Blender MCP was unavailable; modeling used independent background Blender. Runtime requires Godot, not Blender. Ten waves form one route; music remains a short procedural prototype score. No long campaign, commercial soundtrack, human balance acceptance, controller mapping or sustained low-end benchmark is claimed.
