extends SceneTree
## Verifies the three recorded-weapon quality tiers and their live card layout.
const C=preload("res://scripts/arsenal_catalog.gd")
var game
var checks=0
var failures: Array[String]=[]

func _initialize() -> void:
	run.call_deferred()
	watchdog.call_deferred()

func watchdog() -> void:
	await create_timer(60.,true).timeout
	push_error("Recorded quality review timeout")
	quit(2)

func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok: failures.append(message); push_error(message)

func frames(count: int=5) -> void:
	for index in range(count): await process_frame

func run() -> void:
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS,true)
	root.size=Vector2i(1920,1080)
	game=load("res://scenes/Main.tscn").instantiate()
	root.add_child(game); current_scene=game
	await frames(6)
	game.start_run(7419,"mercury")
	game.music.hold(true); game.music.stop(); game.music._running=false
	game.set_process(false); game.set_physics_process(false); game.set_process_unhandled_input(false)
	game.state="reward"; game.rewards=[]; game.reward_taken=true; game.dust=999
	game.shop_offers=[
		{"id":"recorded_crude","price":31,"sold":false,"locked":false},
		{"id":"recorded_crude_rare","price":54,"sold":false,"locked":false},
		{"id":"recorded_crude_legend","price":87,"sold":false,"locked":false}
	]
	game.ui.refresh(); await frames(8)
	var tiers=[C.item("recorded_crude"),C.item("recorded_crude_rare"),C.item("recorded_crude_legend")]
	check(tiers.map(func(row): return int(row.count))==[2,5,10],"quality tiers expose the expected 2/5/10 base projectile counts")
	check(tiers.map(func(row): return C.quality_name(row))==["普通","稀有","珍贵"],"quality names match the reference card labels")
	check(C.color("recorded_crude")==Color("a7a7a7") and C.color("recorded_crude_rare")==Color("59d96f") and C.color("recorded_crude_legend")==Color("ef4ddd"),"quality cards use grey, green and magenta accents")
	for index in range(3):
		check(game.ui.arsenal.content.find_child("ShopOffer_%d"%index,true,false)!=null,"quality offer card is present / "+str(index))
	game.ui.arsenal.inspect_module(-1,"recorded_crude_legend"); await frames(3)
	var detail=""
	for node in game.ui.arsenal.detail_content.get_children():
		if node is Label: detail+=node.text+"\n"
	check(detail.contains("//珍贵") and detail.contains("发射") and detail.contains("实弹") and detail.contains("× 1.5"),"detail card shows the live attribute-based projectile formula")
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/screenshots/v15-recorded-quality-tiers-720p.png")
	var result={"checks":checks,"failures":failures,"scope":"Three live quality cards for the recorded crude-fire prototype, quality colors, 2/5/10 base counts and attribute-scaled count formula. Controlled shop fixture."}
	var file=FileAccess.open("res://tests/results-recorded-quality.json",FileAccess.WRITE)
	if file: file.store_string(JSON.stringify(result,"\t"))
	print("RECORDED_QUALITY_REVIEW ",JSON.stringify(result))
	game.music.stop(); current_scene=null; game.queue_free(); await frames(4)
	quit(0 if failures.is_empty() else 1)
