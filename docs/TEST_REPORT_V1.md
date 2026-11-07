# First playable verification

2026-10-28, Windows, Godot4.7.2, OpenGL Compatibility, NVIDIA RTX4060 Laptop GPU. Test data uses isolated APPDATA with `--grooveflight-test`; formal player settings and older games are untouched.

## Native full run

`tests/full_run.gd`: 19 checks, no failures. One complete six-wave run took153.004 wall seconds /152.882 music seconds. Five real reward buttons were selected. Actual native weapon damage defeated181 enemies including the half-health, second-phaseBoss, for291 score. No wave/time jumps, soundtrack seeking, injected kills or direct enemy HP reduction.

Assistance: invulnerability, direct steering and automatic activation of the normal overload action. Movement input was separately exercised by the focused prototype test. This run proves the loop can complete; it does not prove human difficulty, unassisted survival or final listening quality.

Native wave starts were approximately0.005,18.027,40.018,64.022,90.028,118.033 music seconds. Module counts progressed5→6→7→7→8→9. Sampled peaks:21 enemies,60 friendly bullets,58 hostile bullets; production caps are110/600/350. Late-run weapon-event versus audio-clock maximum error was27.7ms in the sampled final160 firings, including render capture overhead. These are observations, not a general frame-rate or latency guarantee.

Actual weapon damage: pulse2142, scatter1665.75, beam1546.25, nova1979.75, chain323, overload268. Missile damage was checked separately in a controlled actual-impact fixture; it was not selected in this seeded full run.

## Focused review

`tests/prototype_review.gd` checks loadout ownership, swap and cross-track movement, level-four cap, actual duet/chord effects, changed native PCM after reordering, real looping audio and firing timestamps, real movement, camera,8192-square world, dash cooldown, player damage grace, paused editing and phase-preserving resume, all six actual weapon impacts, overload charge, reward refresh costs, reward idempotence and death/retry.

Final focused review:57 checks, no failures. Additional UI verification covers actual slot-button callbacks, zero-weapon resume protection, safe reward-screen replacement during button signals, and720p editor/settings. Native weapon/audio-clock maximum error was14.7ms in this short sample. Machine-readable totals are in`tests/results-prototype.json`.

Final settings-only review:7 checks, no failures, after replacing low-contrast checkboxes with readable state buttons. Actual start/back signals, both particle settings and audible master gain changes passed. In total,57 focused +19 full-run +7 settings assertions passed.

An initial test exposed default QOA audio compression and a signal-locked button being freed synchronously. Authored stem imports now explicitly usePCM16; UI replacement hides old controls and queues their release. Full native reward selection was repeated after the UI fix and passed.

## Visual records

- `01-title.png`: actual menu and program-generated starfield/planet.
- `02-sequencer.png`: actual two-track editor.
- `04-rewards.png`: controlled reward-layout fixture, not a claim of human progression.
- `run-wave-2/4/5.png`: actual ongoing complete-run combat.
- `run-boss.png`: actual half-healthBoss phase in complete run.
- `run-victory.png`: earned native results from the complete assisted run.
- `06-sequencer-720p.png`, `07-settings-720p.png`: final size checks.

No assets were extracted from`E:/SteamLibrary/steamapps/common/Groove Core Demo`. That folder is an Unreal shipping installation with executable and cooked archives, not an editable source project. Reference screenshots were inspected separately outside the new game directory. The prototype is independently implemented.

Current limits: a single six-wave route, one mainBoss, two short musical tracks, six weapons, six unique perks; no long-form composition, long-term talent tree, shop-economy campaign, controller mapping or multiple characters. The old《折界》remains a separate game.
