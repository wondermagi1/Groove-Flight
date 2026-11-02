extends Node
## Persistent sandbox owns a separate Main, viewport, RNG, receipt and timeline.
## Only immutable PCM cache entries are shared. Campaign state is never copied back.
var source_game
var arena
var viewport: SubViewport
var active: bool=false
var paused: bool=false
var loop_bar: bool=false
var target_layout: int=0
var sample_path: int=-1
var trial_kind: String=""
var comparison: String=""
var signature: String=""
var sync_elapsed: float=1.
var status: String="准备试射"
func ensure_ready() -> void:
	if is_instance_valid(arena): return
	viewport=SubViewport.new(); viewport.size=Vector2i(900,540)
	viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED
	viewport.handle_input_locally=false; add_child(viewport)
	arena=load("res://scenes/Main.tscn").instantiate(); arena.is_preview=true; viewport.add_child(arena)
	arena.set_physics_process(false); arena.set_process_unhandled_input(false); arena.set_process(false)
	arena.ui.root_control.hide(); arena.camera.enabled=true; arena.camera.position_smoothing_enabled=false
	arena.camera.zoom=Vector2.ONE*.72; arena.player=Vector2.ZERO; arena.camera.position=Vector2(0,-180)
	arena.music._cache=source_game.standard_music._cache
	source_game.standard_music.prepared.connect(_prepared)
func activate() -> void:
	ensure_ready(); arena.mixer.set_process(true); arena.fx.set_process(true); active=true; viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	sync()
func sync() -> void:
	if not active: return
	var candidate=source_game.loadout.clone()
	comparison=""
	if sample_path>=0:
		candidate.set_starters([])
		for placement in source_game.PATHS.PATHS[sample_path].layout: candidate.add_module(str(placement[0]),int(placement[1]))
		comparison="蓝图演示 不授予装备"
	elif not trial_kind.is_empty():
		var uid=candidate.add_module(trial_kind)
		if uid<0 or candidate.equipped_head(uid)<0: comparison="没有合法空位 请先整理音序"
		else:
			comparison="试装 "+str(source_game.C.item(trial_kind).name)+" 不扣款"
			for head in source_game.loadout.heads():
				var owner=source_game.loadout.slots[head]; var old=source_game.loadout.item_stats(owner,head%8); var changed=candidate.item_stats(owner,head%8)
				if old.has("damage") and (not is_equal_approx(float(old.damage),float(changed.damage)) or int(old.get("count",0))!=int(changed.get("count",0))):
					comparison+="\n%s %.1f→%.1f伤害 %d→%d发"%[str(old.name),old.damage,changed.damage,int(old.get("count",0)),int(changed.get("count",0))]
	var key=source_game.standard_music.key_for(candidate)
	if key==signature: return
	signature=key; arena.music.hold(true); arena.set_process(false)
	arena.loadout=candidate; arena.selected_ship=source_game.selected_ship; arena.selected_pilot=source_game.selected_pilot
	arena.refresh_loadout_stats(); arena.receipt.reset(); arena.rng.seed=421119
	arena.music.track_mutes=source_game.standard_music.track_mutes.duplicate()
	arena.music.backing_gain=source_game.standard_music.backing_gain; arena.music.weapon_gain=source_game.standard_music.weapon_gain
	arena.music.volume_db=source_game.standard_music.volume_db-7.
	set_targets(target_layout); status="准备当前配装音频…"
	if source_game.standard_music.has_prepared(arena.loadout): _prepared(key)
	else: source_game.standard_music.prepare(arena.loadout)
func _prepared(key: String) -> void:
	if not active or key!=signature: return
	arena.music.begin(arena.loadout); replay(); status="实战同源 · 无收益试射"
func replay() -> void:
	if not is_instance_valid(arena) or arena.music.stream==null: return
	arena.bullets.clear(); arena.pending_triggers.clear(); arena.pending_projectiles.clear(); arena.root_budgets.clear()
	arena.music.play(14.); arena.music.timeline=14.; arena.music._previous_raw=14.; arena.music.loop_count=0; arena.music.last_step=55
	arena.music._running=true; arena.state="combat"; arena.music.hold(paused); arena.set_process(not paused)
func set_targets(layout: int) -> void:
	target_layout=layout
	if not is_instance_valid(arena): return
	arena.enemies.clear(); arena.by_id.clear(); arena.spatial.clear()
	var positions: Array=[]
	if layout==0:
		for i in range(5): positions.append(Vector2(0,-170-i*70))
	elif layout==1:
		for y in range(3):
			for x in range(5): positions.append(Vector2((x-2)*100,-220-y*100))
	else: positions.append(Vector2(0,-330))
	for at in positions:
		var target=arena.spawn_enemy("armor",at); target.speed=0.; target.hp=10000000.; target.max_hp=target.hp
		target.radius=125. if layout==2 else 23.
	arena.rebuild_spatial()
func toggle_pause() -> void:
	paused=not paused; arena.music.hold(paused); arena.set_process(not paused)
func toggle_track(track: int,solo: bool=false) -> void:
	for i in range(3):
		if solo: source_game.standard_music.track_mutes[i]=i!=track
		elif i==track: source_game.standard_music.track_mutes[i]=not bool(source_game.standard_music.track_mutes[i])
	signature=""; sync()
func deactivate() -> void:
	active=false; status="试射已暂停"
	if not is_instance_valid(arena): return
	arena.music.hold(true); arena.set_process(false); arena.fx.set_process(false)
	arena.mixer.pending.clear(); arena.mixer.set_process(false)
	for group in arena.mixer.groups.values():
		for voice in group: voice.stop()
	viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED
func _process(delta: float) -> void:
	if not active: return
	if not source_game.can_edit(): deactivate(); return
	sync_elapsed+=delta
	if sync_elapsed>=.15: sync_elapsed=0.; sync()
	if is_instance_valid(arena):
		if loop_bar and arena.music.timeline>=16.: replay()
		for target in arena.enemies: target.hp=target.max_hp

func select_sample(index: int) -> void:
	sample_path=index-1; trial_kind=""; signature=""; sync()
func try_item(kind: String) -> void:
	trial_kind=kind; sample_path=-1; signature=""; sync()
