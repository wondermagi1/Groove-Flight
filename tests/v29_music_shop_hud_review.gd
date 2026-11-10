extends "res://tests/v21_spectacle_review.gd"
const AUDIO=preload("res://scripts/audio_controls.gd")
func shop_checks() -> void:
	var model=game.LOADOUT.new(); var random=RandomNumberGenerator.new()
	var samples=0
	for wave in [1,4,7,10]:
		for seed_value in range(64):
			random.seed=wave*1000+seed_value
			var offers=model.make_shop(random,wave); var weapons=0; var ids: Dictionary={}; var rarity_ok=true
			for offer in offers:
				var row=C.item(offer.id); weapons+=1 if str(row.category)=="weapon" else 0; ids[offer.id]=true
				var ceiling=clampi(wave,1,3) if str(row.category)=="weapon" else clampi(1+floori(float(wave-1)/3.),1,3)
				rarity_ok=rarity_ok and int(row.rarity)<=ceiling
			check(offers.size()==6 and weapons==3 and ids.size()==6 and rarity_ok,"seeded shop keeps3weapons3items,unique IDs and rarity unlock / %d:%d"%[wave,seed_value]); samples+=1
	game.simulation_only=true; game.state="reward"
	for mask in range(64):
		game.rng.seed=29000+mask; game.shop_offers=game.loadout.make_shop(game.rng,7); game.wave=7; game.dust=1000; game.shop_reroll_cost=8
		var retained: Dictionary={}
		for i in range(6):
			if (mask & (1<<i))!=0: game.shop_offers[i].locked=true; retained[i]=game.shop_offers[i].duplicate(true)
		var changed=game.shop_reroll(); var kept=true; var weapon_count=0; var ids: Dictionary={}
		for i in range(6):
			if retained.has(i): kept=kept and game.shop_offers[i]==retained[i]
			weapon_count+=1 if C.item(game.shop_offers[i].id).category=="weapon" else 0; ids[game.shop_offers[i].id]=true
		check(kept and weapon_count==3 and ids.size()==6 and changed==(mask!=63) and game.dust==(992 if changed else 1000),"all lock patterns preserve quotations,3+3quota and exact reroll payment / "+str(mask))
	game.simulation_only=false
	for key in ["ballistic","energy","power","support"]:
		var boon=game.LOADOUT.WAVE_BOONS.filter(func(b): return str(b.key)==key)[0]
		var before=float(model.stats()[key]); model.add_boon(str(boon.id))
		check(is_equal_approx(float(model.stats()[key])-before,5.) and str(boon.detail).contains("+5"),"primary wave boon applies and describes+5 / "+key)
	check(model.wave_boon_choices(random).size()==3,"wave rewards retain three choices")
	facts.shop_samples=samples; facts.lock_patterns=64

func ui_checks() -> void:
	game.loadout.set_starters(["pulse","scatter"]); game.settings.combat_panel_inventory=false
	for size_value in [Vector2i(1920,1080),Vector2i(1280,720)]:
		root.size=size_value; game.state="combat"; game.settings.combat_panel_sequencer=false; game.ui.refresh(); await frames(5)
		var restore=game.ui.root_control.find_child("RestoreCombatSequencer",true,false)
		check(restore!=null and restore.is_visible_in_tree(),"hidden combat sequencer has a visible recovery control / "+str(size_value))
		restore.pressed.emit(); await frames(5)
		var panel=game.ui.root_control.find_child("FlightSequencer",true,false)
		var rect: Rect2=panel.get_global_rect()
		var view: Vector2=game.get_viewport_rect().size
		check(panel.is_visible_in_tree() and rect.position.x<30. and rect.position.y>view.y*.7 and rect.end.x<=view.x and rect.end.y<=view.y,"restored sequencer stays bottom-left and on-screen / "+str(size_value))
		check(game.ui.arsenal.step_lights.size()==24,"all three tracks retain eight scan lights")
		check(game.ui.arsenal.step_lights.all(func(n): return n.z_index>0),"scan lights draw above equipped weapon cards")
		for sample in [[0.,0],[game.LOADOUT.SEQUENCE_STEP_SECONDS,1],[game.LOADOUT.SEQUENCE_STEP_SECONDS*7.,7],[game.LOADOUT.SEQUENCE_LOOP_SECONDS,0]]:
			game.music.timeline=sample[0]; game.ui.arsenal._update_sequence_cursor()
			check(game.ui.arsenal.step_lights[int(sample[1])].active and game.ui.arsenal.step_lights.filter(func(n): return n.active).size()==3,"scan dots follow current production cell/loop timing / "+str(sample[0]))
		if DisplayServer.get_name()!="headless":
			await RenderingServer.frame_post_draw; root.get_texture().get_image().save_png("res://docs/screenshots/v29-hud-"+str(size_value.x)+".png")
		game.state="reward"; game.wave=4; game.shop_offers=game.loadout.make_shop(game.rng,4); game.rewards=[]; game.reward_taken=true
		game.settings.text_scale=1.2; game.ui.refresh(); await frames(6)
		var separate=true
		for i in range(6):
			var lock=game.ui.root_control.find_child("ShopLock_"+str(i),true,false)
			var card=game.ui.root_control.find_child("ShopOffer_"+str(i),true,false)
			separate=separate and lock.get_global_rect().end.y+5.<=card.get_global_rect().position.y
		check(separate,"all six lock controls have dedicated space above card art at120percent text / "+str(size_value))
		if DisplayServer.get_name()!="headless":
			await RenderingServer.frame_post_draw; root.get_texture().get_image().save_png("res://docs/screenshots/v29-shop-"+str(size_value.x)+".png")
	game.state="settings"; game.previous_state="title"; game.ui.refresh(); await frames(3)
	var credit=game.ui.root_control.find_child("MusicAttribution",true,false)
	check(credit!=null and credit.text.contains("Scott Buckley") and credit.text.contains("CC BY 4.0") and credit.text.contains("scottbuckley.com.au"),"settings includes title,artist,license and clickable original source")

func music_checks() -> void:
	check(game.LEVEL_MUSIC_PATH.ends_with("scott_buckley/filaments.ogg"),"production background music selects Filaments")
	check(game.menu_music.stream!=null and game.menu_music.stream.get_length()>339. and game.menu_music.stream.get_length()<341. and game.menu_music.stream.loop,"full339second Filaments stream is loaded and looping")
	game.state="combat"; game.is_preview=false; game.free_music_run=false; game._sync_screen_music()
	check(game.planet_music.playing and game.planet_music.bus==AUDIO.MUSIC and game.planet_music.stream==game.menu_music.stream,"combat uses the same cached Filaments resource on the independent music bus")
	for state_value in ["paused","editor","reward"]:
		game.state=state_value; game._sync_screen_music()
		check(game.planet_music.stream_paused==(state_value!="reward"),"background pause/resume follows game state / "+state_value)
	game.state="title"; game._sync_screen_music()
	check(game.menu_music.playing and not game.planet_music.playing,"title switches to Filaments without overlapping combat player")
	if DisplayServer.get_name()=="headless": return
	var background_stream=game.menu_music.stream; stop_audio(game); game.menu_music.stream=background_stream; game.planet_music.stream=background_stream
	var old_master_mute=AudioServer.is_bus_mute(0); AudioServer.set_bus_mute(0,true)
	var capture=AudioEffectCapture.new(); capture.buffer_length=.5; var bus=AudioServer.get_bus_index(AUDIO.MASTER)
	AudioServer.add_bus_effect(bus,capture); game.settings.master=1.; game.settings.music=1.; game.apply_audio()
	game.menu_music.play(90.); await create_timer(.25,true).timeout; capture.clear_buffer(); await create_timer(.15,true).timeout
	var data=capture.get_buffer(capture.get_frames_available()); var energy=0.
	for sample in data: energy+=sample.length_squared()
	var rms=sqrt(energy/maxi(1,data.size()*2)); check(rms>.0001,"native audio capture confirms actual Filaments playback")
	var weapons_gain=AudioServer.get_bus_volume_db(AudioServer.get_bus_index(AUDIO.WEAPONS))
	game.set_audio_volume("music",0.); await create_timer(.2,true).timeout; capture.clear_buffer(); await create_timer(.15,true).timeout
	data=capture.get_buffer(capture.get_frames_available()); energy=0.
	for sample in data: energy+=sample.length_squared()
	check(energy<.0000001 and is_equal_approx(weapons_gain,AudioServer.get_bus_volume_db(AudioServer.get_bus_index(AUDIO.WEAPONS))),"music mute is digitally silent while weapon gain remains independent")
	facts.native_music_rms=rms
	AudioServer.remove_bus_effect(bus,AudioServer.get_bus_effect_count(bus)-1); AudioServer.set_bus_mute(0,old_master_mute)

func run() -> void:
	ProjectSettings.set_setting("gui/timers/tooltip_delay_sec",3600.)
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS,true); root.size=Vector2i(1920,1080)
	game=load("res://scenes/Main.tscn").instantiate(); root.add_child(game); current_scene=game; await frames(4)
	game.set_process(false); game.set_physics_process(false); game.set_process_unhandled_input(false); game.music.stop(); game.music._running=false; game.fx.set_process(false)
	game.settings.master=0.; game.apply_audio()
	shop_checks(); await ui_checks(); await music_checks()
	var result={"checks":checks,"failures":failures,"facts":facts,"scope":"Seeded3+3shops and all64lock masks,primary boons+5,bottom-left sequencer/recovery/cursor and separated lock layout at1080p/720p,120percent shop text,Filaments resource/state/category and optional actual native music capture. Isolated test profile,no human mix/balance claim."}
	FileAccess.open("res://tests/results-v29-music-shop-hud.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t")); print("V29_REVIEW ",JSON.stringify(result))
	stop_audio(game); current_scene=null; game.queue_free(); await frames(6); await create_timer(.2,true).timeout; quit(0 if failures.is_empty() else 1)
