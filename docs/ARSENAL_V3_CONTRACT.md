# V3 arsenal integration contract

Next work after the v2 city/fleet checkpoint. Original Foldbound remains separate.

## Data API

New scripts/arsenal_catalog.gd extends RefCounted. static rows()->Array[Dictionary], item(id:String)->Dictionary (empty unknown), weapons()->Array[Dictionary]. Exactly 240 unique item IDs, level/rarity copies do not count. Categories:32 weapon,72 mod,80 rhythm,40 defense,16 core. Explicit curated names/effects; templates may organize data but no quality/level-only duplicates.

All rows: id,name,category,detail,rarity (0..3),cost (int),width (1..3),color (Color),tags (Array[String]),voice (a weapon ID, empty nonweapon),attr (ballistic/energy/power/support).

Weapons add family (pulse/scatter/beam/missile/nova/chain/rail/boomerang/orbit/mine/flame/drone),damage,count,speed,life,spread,pierce,explosion,homing,bounces,charge (1/2/4/8 bars),melody (8 pitch indices0..7),timbre (dictionary wave/decay/fm/octave/detune),rules (array).

Nonweapon rules are a list of dictionaries: type=stat/weapon/beat/event; key; value float; scope=all/row/neighbor; target optional family/attribute; condition=always/even/odd/first/final. stat keys ballistic,energy,power,support,extra_projectiles,bullet_multiplier,crit_chance,crit_damage,max_health,regen,armor,move_percent,magnet,luck. weapon keys damage_percent,count,pierce,speed_percent,range_percent,explosion,spread_percent,chain_count,homing,bounces. beat keys charge_reduce,repeat,rotate,streak,chord. event keys heal_bar,shield_dash,heal_pickup,explode_kill,charge_kill,missiles_dash,heal_kill. All quantities stack, clamp in runtime. No unimplemented rule types/keys.

## Loadout API (new arsenal_loadout.gd)

Retain old core API reset/find/add_module/move_module/unequip/valid/active_count/trigger/reward_choices/take; 3 tracks x8 cells=24. Inventory modules array max64, slots Array[int]24 uses same UID for every occupied cell of a multi-cell item. Modules {uid,kind,level}; level1..4. Only head cell triggers; item cannot cross row edge. Move atomically and reject partial overlap; moving onto another item's head can swap if both widths fit; no duplicates. Explicit equip/unequip preserve inventory.

New stats()->Dictionary, stat_sources(key)->Array[Dictionary] with name/value; item_stats(uid,serial=0)->Dictionary; events()->Dictionary; advance_step(index,serial)->Array[Dictionary]; schedule(serial)->Array[Dictionary] PURE and shared by composer/combat. Results carry uid,kind,voice,pitch,family,damage,count,extra,pierce,speed,life,spread,explosion,homing,bounces,chain_count,chord,repeat,angle,slot. Support beat conditions and target scopes. Width cells count once for all stat calculations. Only equipped items contribute. echo_repeat pilot retained, final-step half-damage repeat only on the bar when the first weapon is eligible. charge values powers of two; the shared native score is128sec/64bars/512steps, enough for charge8 weapons to complete an eight-note motif. Pitch advances on each eligible weapon firing, not on silent bars. trigger(at) remains pure preview for compatibility, schedule is combat source.

Shop helpers: make_shop(rng,wave)->Array[Dictionary] six unique offers{id,price,sold}; buy(offer,dust)->Dictionary {ok,cost,uid}, no dust mutation in loadout; salvage(uid)->int refund removes entire item; merge(uid)->bool consumes another samekind/samelevel, preserves chosen UID/placement, cap4. Never upgrade/consume if transaction invalid. root game owns currency validation and offer sold flag. Starter six legacy IDs resolve. stats damage_scale retained; expose max_health/extra_bullets/perks for root compatibility. Static source attrs set via set_fleet(craft,pilot), root applies after reset.

## Game/UI API (root owns main/music/UI integration)

New full-screen arsenal_screen.gd extends Control var game; var mode='editor'/'shop'; UI calls game.buy_offer(i),shop_reroll(),salvage_module(uid),merge_module(uid),move_module(uid,at),select_module(uid),unequip_module(uid),continue_wave(),close_editor(). State reward uses shop mode (no forcedfree threecards). Root game has shop_offers:Array, selected_uid,dust,wave,loadout,music,weapon_damage,selected_ship/pilot. Inventory tooltip uses arsenal_catalog.item(id),loadout.item_stats(uid),stat_sources(key). Main4stats and all secondary attributes readable; damage breakdown real. Layout like reference: left attribute/status, bottom inventory+3tracks, rightbufftiles, center popup detail/shop6cards. Panels independently toggle plus globalhide; combat compact toggles as well. Settings persist visibility in game.settings panel_attributes/panel_status/panel_buffs/panel_inventory/panel_sequencer booleans. UI selection doesn't mutate stats. Helpers game.toggle_panel(key),game.toggle_all_panels().

Root adds32 weapon voices*8 pitches generated original synth audio; native composer loops128secs, uses loadout.schedule(serial) identical to actual combat for charge/conditional notes. No timers independent of audible clock. UI must not call schedule/trigger with mutation.

## Document and verification

catalog agent writes docs/ARSENAL_CATALOG.md (all240), docs/WEAPON_MUSIC_MATRIX.md(all32 voice/charging/pattern mapping). Engine agent writes isolated tests/arsenal_loadout_review.gd. Root verifies actual firing/audio/shop/UI, saves v2 checkpoint before integration. Catalog and loadout agents must coordinate known rule schema; no root file changes by them.
