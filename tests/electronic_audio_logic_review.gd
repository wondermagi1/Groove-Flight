extends SceneTree
const L=preload("res://scripts/arsenal_loadout.gd")
const C=preload("res://scripts/arsenal_catalog.gd")
var checks=0
var failures: Array=[]
var facts: Dictionary={}
var game
func _initialize() -> void:
	run.call_deferred(); watchdog.call_deferred()
func watchdog() -> void:
	await create_timer(120.).timeout; push_error("Electronic audio review timeout"); quit(2)
func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok: failures.append(message); push_error(message)
func frames(n: int=3) -> void:
	for i in range(n): await process_frame
func zero_pcm(wav: AudioStreamWAV) -> bool:
	var silent=PackedByteArray(); silent.resize(wav.data.size())
	return hash(wav.data)==hash(silent)
func excerpt(wav: AudioStreamWAV,path: String) -> void:
	var clip=AudioStreamWAV.new(); clip.mix_rate=wav.mix_rate; clip.format=wav.format; clip.stereo=wav.stereo
	clip.data=wav.data.slice(0,4*wav.mix_rate*4); clip.save_to_wav(path)
func run() -> void:
	game=load("res://scenes/Main.tscn").instantiate(); root.add_child(game); current_scene=game
	await frames()
	game.set_process(false); game.set_physics_process(false); game.music.stop(); game.music._running=false
	game.state="combat"; game.ui.refresh(); await frames()
	check(game.ui.arsenal.step_lights.size()==24,"three tracks keep all24 scan dots")
	check(game.ui.arsenal.step_cards.all(func(card): return not card.get_property_list().any(func(p): return p.name=="charge_progress")),"weapon cards no longer contain a phrase progress bar")
	var codex=load("res://scripts/weapon_codex.gd").new(); codex.game=game; root.add_child(codex); await frames()
	codex.select_weapon("beam"); codex.play_log.clear(); codex.play_cadence(); await create_timer(.65).timeout
	check(codex.play_log.size()==1 and codex.play_log[0].pitch==0 and not codex.rhythm_view.visible,"codex previews one fixed voice without an automatic phrase or rhythm meter")
	codex.queue_free(); await frames()
	# Every active instrument keeps the identical sample on successive passes.
	for row in C.playable_weapons():
		var model=L.new(); model.set_starters([str(row.id)])
		var events: Array=[]
		for serial in range(64): events.append_array(model.schedule(serial))
		check(events.size()==8 and events.all(func(e): return e.pitch==0 and e.cadence_beats==1 and e.cadence_scale==1.),"fixed voice across eight scans / "+str(row.id))
		game.sound_times.clear(); var before=int(game.mixer.counters.played)
		game._play_weapon_reference(events[0],str(row.family))
		check(int(game.mixer.counters.played)==before,"electronic shot cannot overlay an old recorded reference / "+str(row.id))
	var model=L.new(); model.set_starters([])
	var a=model.add_module("beam",0); var b=model.add_module("beam",2)
	check(a>0 and b>0 and a!=b and model.slots[1]==a and model.slots[3]==b,"two same-type instruments occupy12 and34 as distinct instances")
	var synth=game.standard_music; synth.weapon_gain=.34; synth.track_mutes=[false,false,false]
	var snapshot=synth._snapshot(model)
	var first=snapshot.events.filter(func(e): return float(e.deadline)<1.)
	check(first.size()==2 and first[0].uid==a and first[1].uid==b and is_equal_approx(first[1].deadline-first[0].deadline,.25),"same-type12/34 emits at both heads,250ms apart")
	check(first.size()==2 and first[0].sample_key==first[1].sample_key and first[0].gain==first[1].gain,"both copies play the same timbre and level")
	var wav=synth.compose(model); var pcm=wav.data
	var instrument_pcm=snapshot.instruments[first[0].sample_key]
	check(instrument_pcm.size()>int(.25*synth.RATE),"the test voice has an audible tail overlapping the second copy")
	# Compare the actual PCM against the sum of every overlapping source,
	# including soft limiting; replacing the first voice would fail this.
	var max_error=0.; var frame_count=int(synth.LENGTH*synth.RATE)
	for n in range(60):
		var frame=int((4.27+n*.001)*synth.RATE); var left=0.
		for event in snapshot.events:
			var sample=snapshot.instruments[event.sample_key]
			var source_index=posmod(frame-roundi(event.deadline*synth.RATE),frame_count)
			if source_index<sample.size(): left+=sample[source_index]*sqrt(.73)*event.gain
		max_error=maxf(max_error,absf(pcm.decode_s16(frame*4)-int(tanh(left)*30000)))
	check(max_error<=2.,"actual native PCM sums both overlapping copies rather than cutting the first one")
	facts.overlap_pcm_max_lsb_error=max_error
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://docs/audio-v18"))
	excerpt(wav,"res://docs/audio-v18/same-weapon-12-34.wav")
	var solo=model.clone(); solo.unequip_uid(b)
	excerpt(synth.compose(solo),"res://docs/audio-v18/single-weapon-12.wav")
	for module in model.modules: module.level=4
	model.add_module("r_coda",8)
	synth.weapon_gain=0.
	check(synth._snapshot(model).events.all(func(e): return e.gain==0.),"zero weapon volume also silences upgraded and support voices")
	check(zero_pcm(synth.compose(model)),"zero weapon volume produces digital-silent native PCM")
	synth.weapon_gain=.34; synth.track_mutes=[true,true,true]
	check(zero_pcm(synth.compose(model)),"all tracks muted produce digital-silent PCM")
	synth.track_mutes=[false,false,false]
	var charged=L.new(); charged.set_starters(["rail"])
	var charged_events=synth._snapshot(charged).events.slice(0,8)
	check(charged_events.size()==8 and charged_events.all(func(e): return e.sample_key==charged_events[0].sample_key and e.gain==charged_events[0].gain),"charging affects projectile eligibility without changing the fixed sound")
	# Native transport and live settings: no manual clock stepping.
	game.simulation_only=false; game.set_process(true); game.set_physics_process(true)
	game.selected_pilot="mender"; game.start_run(1805,"mercury"); game.invulnerable=1000.
	game.loadout.audio_guard_enabled=false; game.loadout.set_starters([])
	a=game.loadout.add_module("beam",0); b=game.loadout.add_module("beam",2)
	game.loadout.audio_guard_enabled=true; game.refresh_loadout_stats(); game.music.begin(game.loadout)
	var waited=0.
	while game.music.timeline<2.6 and waited<25.:
		await create_timer(.1).timeout; waited+=.1
	var shots=game.fire_log.filter(func(e): return int(e.uid) in [a,b])
	check(shots.size()>=6,"both copies fire repeatedly under the real native transport")
	check(shots.all(func(e): return e.pitch==0 and e.cadence_step==0),"live fire never advances an automatic phrase or transposes by slot")
	facts.native_shots=shots
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/screenshots/v18-fixed-voice-no-meter.png")
	var before_time=game.music.timeline
	game.settings.weapons=0.; game.apply_audio(); waited=0.
	while not synth.is_current(game.loadout) and waited<15.:
		await create_timer(.1).timeout; waited+=.1
	check(synth.is_current(game.loadout) and zero_pcm(synth.stream),"live volume change replaces the playing PCM, not only future previews")
	check(game.music.timeline>=before_time,"live mix refresh does not restart the scan clock")
	game.music.hold(true); var held=game.music.timeline
	game.settings.weapons=.3; game.apply_audio(); waited=0.
	while not synth.is_current(game.loadout) and waited<15.:
		await create_timer(.1).timeout; waited+=.1
	check(synth.is_current(game.loadout) and synth.stream_paused and game.music.timeline==held and not zero_pcm(synth.stream),"volume refresh during pause preserves the exact paused scan position")
	game.state="editor"; game.editor_return="combat"; game.editing_changed=false; game.ensure_lab()
	var wanted=synth._wanted; var campaign=JSON.stringify([game.loadout.modules,game.loadout.slots,game.dust])
	game.lab.begin_preview("beam"); waited=0.
	while game.lab.arena.music.timeline<1.15 and waited<20.:
		await create_timer(.1).timeout; waited+=.1
	check(game.lab.arena.music.timeline>=1. and synth._wanted==wanted,"preview uses its own compiler without replacing the campaign's pending audio")
	check(JSON.stringify([game.loadout.modules,game.loadout.slots,game.dust])==campaign,"same-type preview does not change equipment or currency")
	game.lab.toggle_track(0); game.close_editor(); waited=0.
	while (game.state!="combat" or not synth.is_current(game.loadout)) and waited<20.:
		await create_timer(.1).timeout; waited+=.1
	check(game.state=="combat" and synth.is_current(game.loadout) and zero_pcm(synth.stream),"leaving the editor adopts track mute changes even without moving equipment")
	var count=game.fire_log.size(); await create_timer(1.1).timeout
	check(game.fire_log.size()>count,"muting audio never disables the actual projectiles")
	var result={"checks":checks,"failures":failures,"facts":facts,"scope":"Fixed voices for the active weapon roster, same-type12/34 native PCM overlap and live fire, zero-volume/track mute, live/paused PCM refresh and isolated preview compilation. Native fixture uses invulnerability; no human listening or balance claim."}
	FileAccess.open("res://tests/results-electronic-audio-logic.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	print("ELECTRONIC_AUDIO_LOGIC ",JSON.stringify({"checks":checks,"failures":failures}))
	game.return_title(); current_scene=null; game.queue_free(); await frames(5)
	quit(0 if failures.is_empty() else 1)
