extends SceneTree
## UI transaction fixture using the production catalog/loadout. It intentionally
## does not claim a complete flight, native audio or human balance acceptance.
const DATA=preload("res://scripts/arsenal_catalog.gd")
const LOADOUT=preload("res://scripts/arsenal_loadout.gd")
const SCREEN=preload("res://scripts/arsenal_screen.gd")
var checks: int=0
var failures: Array[String]=[]
var fixture
var screen
var view: SubViewport

class Clock:
	extends RefCounted
	var timeline: float=0.0
class Fixture:
	extends Node
	var settings={"panel_attributes":true,"panel_status":true,"panel_buffs":true,"panel_inventory":true,"panel_sequencer":true}
	var loadout=LOADOUT.new()
	var music=Clock.new()
	var selected_uid: int=-1
	var dust: int=999
	var wave: int=4
	var weapon_damage={"pulse":12345.0}
	var shop_offers: Array=[]
	var shop_reroll_cost: int=8
	var state: String="reward"
	var resumes: int=0
	var saves: int=0
	var rng=RandomNumberGenerator.new()
	func can_edit() -> bool: return state in ["editor","reward"]
	func toggle_panel(key: String) -> void:
		settings[key]=not settings.get(key,true); saves+=1
	func toggle_all_panels() -> void:
		var all_visible: bool=true
		for key in settings: all_visible=all_visible and settings[key]
		for key in settings: settings[key]=not all_visible
		saves+=1
	func select_module(uid: int) -> void: selected_uid=uid
	func move_module(uid: int,at: int) -> void: loadout.move_module(uid,at)
	func unequip_module(uid: int) -> void: loadout.unequip_uid(uid)
	func buy_offer(index: int) -> void:
		var offer: Dictionary=shop_offers[index]
		if offer.sold: return
		var result: Dictionary=loadout.buy(offer,dust)
		if result.ok: dust-=int(result.cost); offer.sold=true
	func toggle_offer_lock(index: int) -> void: shop_offers[index].locked=not bool(shop_offers[index].get("locked",false))
	func shop_reroll() -> void:
		if dust<shop_reroll_cost: return
		dust-=shop_reroll_cost; shop_offers=loadout.make_shop(rng,wave)
	func salvage_module(uid: int) -> void: dust+=loadout.salvage(uid)
	func merge_module(uid: int) -> void: loadout.merge(uid)
	func continue_wave() -> void: resumes+=1; state="combat"
	func close_editor() -> void: resumes+=1; state="combat"

func _initialize() -> void: run.call_deferred()
func check(ok: bool,message_value: String) -> void:
	checks+=1
	if not ok: failures.append(message_value); push_error(message_value)
func frames(count: int=5) -> void:
	for index in range(count): await process_frame
func button(name_value: String) -> Button:
	return screen.content.find_child(name_value,true,false) as Button
func make_screen(mode_value: String) -> void:
	if is_instance_valid(screen): screen.hide(); screen.queue_free()
	screen=SCREEN.new(); screen.game=fixture; screen.mode=mode_value; view.add_child(screen)
func snapshot(name_value: String) -> void:
	if DisplayServer.get_name()=="headless": return
	await RenderingServer.frame_post_draw
	view.get_texture().get_image().save_png("res://docs/screenshots/"+name_value+".png")
func run() -> void:
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_NO_FOCUS,true)
	fixture=Fixture.new(); root.add_child(fixture)
	fixture.rng.seed=944; fixture.loadout.reset(); fixture.loadout.set_starters(["pulse"])
	fixture.shop_offers=fixture.loadout.make_shop(fixture.rng,4)
	var spare: int=fixture.loadout.add_module("pulse",-2)
	view=SubViewport.new(); view.size=Vector2i(1920,1080); view.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(view)
	make_screen("shop"); await frames(10)
	check(screen.step_cells.size()==24 and screen.step_cards.size()==1,"three eight-step tracks display occupied module heads once")
	check(screen.content.find_children("ShopOffer_*","Button",true,false).size()==6,"shop presents six real offers")
	var count_before: int=fixture.loadout.modules.size()
	var price: int=fixture.shop_offers[0].price
	var money_before: int=fixture.dust
	button("ShopOffer_0").pressed.emit(); await frames()
	check(fixture.loadout.modules.size()==count_before+1 and fixture.dust==money_before-price and fixture.shop_offers[0].sold,"actual buy button adds one module and pays its actual price")
	check(button("ShopOffer_0").disabled,"purchased offer becomes unavailable")
	money_before=fixture.dust
	button("ShopOffer_0").pressed.emit(); await frames()
	check(fixture.dust==money_before and fixture.loadout.modules.size()==count_before+1,"repeated sold-card activation cannot buy twice")
	button("ArsenalReroll").pressed.emit(); await frames()
	check(fixture.dust==money_before-8 and fixture.shop_offers.size()==6,"actual reroll button pays the configured fee")
	var first_uid: int=fixture.loadout.slots[0]
	screen.select_module(first_uid); await frames()
	check(button("ArsenalMerge")!=null and not button("ArsenalMerge").disabled,"selecting a module exposes legal same-kind same-level merge")
	button("ArsenalMerge").pressed.emit(); await frames()
	check(fixture.loadout.find(first_uid).level==2 and fixture.loadout.find(spare).is_empty() and fixture.loadout.slots[0]==first_uid,"merge button preserves selected placement and consumes the duplicate")
	screen.inspect_module(first_uid); await frames()
	check(button("ArsenalMerge").disabled,"merge is disabled without a same-level partner")
	screen.drop_module(first_uid,-1); await frames()
	check(not fixture.loadout.slots.has(first_uid) and fixture.loadout.find(first_uid).level==2,"inventory drop target unequips without losing the module")
	check(button("ArsenalContinue").disabled,"continue is disabled when no actual weapon is equipped")
	screen.drop_module(first_uid,16); await frames()
	check(fixture.loadout.slots[16]==first_uid and not button("ArsenalContinue").disabled,"moving from inventory to track C restores a playable sequence")
	var arrangement: Array=fixture.loadout.slots.duplicate()
	var old_dust: int=fixture.dust
	for key in SCREEN.PANEL_NAMES:
		var toggle: Button=button(str(key[0]))
		toggle.pressed.emit(); await frames()
		check(not fixture.settings[key[0]],"individual visibility toggle: "+str(key[0]))
	check(screen.step_cells.is_empty() and screen.stat_labels.is_empty() and fixture.loadout.slots==arrangement and fixture.dust==old_dust,"hiding panels removes UI without mutating loadout or money")
	check(button("ArsenalContinue")!=null and not button("ArsenalContinue").disabled,"global panel hiding leaves navigation accessible")
	button("ToggleAllPanels").pressed.emit(); await frames()
	check(screen.step_cells.size()==24 and screen.stat_labels.size()==14,"show-all restores all panels and current stats")
	screen.inspect_stat("armor"); await frames()
	check(screen.detail_panel.visible and screen.preview_stat=="armor","attribute button opens actual per-source inspector")
	screen.inspect_module(first_uid); await frames()
	check(screen.detail_panel.visible and screen.preview_kind=="pulse","module inspector restores actual weapon values and artwork")
	await snapshot("v3-arsenal-shop-1080p")
	view.size=Vector2i(1280,720); await frames(10)
	for key in ["attributes","status","inventory","sequencer","buffs"]:
		var rect: Rect2=screen.panel_rects[key]
		check(rect.position.x>=0 and rect.position.y>=0 and rect.end.x<=1280.1 and rect.end.y<=720.1,"720p panel bounds: "+key)
	check(not screen.panel_rects.status.intersects(screen.panel_rects.inventory),"short-window status and inventory panels do not overlap")
	check(screen.detail_panel.get_rect().end.y<screen.panel_rects.sequencer.position.y and screen.detail_panel.size.x<=screen.panel_rects.sequencer.size.x*.32+1.0,"short-window inspector respects its reserved column and does not cover sequence")
	check(button("ShopOffer_5").get_parent().get_parent() is ScrollContainer,"shop remains scrollable at short window heights")
	await snapshot("v3-arsenal-shop-720p")
	money_before=fixture.dust
	screen.inspect_module(first_uid); await frames()
	button("ArsenalSalvage").pressed.emit(); await frames()
	check(fixture.loadout.find(first_uid).is_empty() and not fixture.loadout.slots.has(first_uid) and fixture.dust>money_before,"salvage button removes all occupied cells and returns actual refund")
	fixture.loadout.set_starters(["beam"]); fixture.state="combat"
	make_screen("combat"); await frames()
	var combat_uid: int=fixture.loadout.slots[0]
	screen.select_module(combat_uid); await frames()
	check(not screen.editable() and not screen.can_drop(combat_uid,8) and button("ArsenalSalvage")==null,"combat overlay supports inspection while blocking inventory mutation")
	check(screen.panel_rects.sequencer.size.y<=720.0*.15 and screen.panel_rects.sequencer.size.x<=780.0,"720p combat sequencer stays within fifteen percent of viewport height")
	fixture.state="editor"; make_screen("editor"); await frames(); screen.inspect_module(combat_uid); await frames()
	check(button("ArsenalSalvage").disabled,"the final owned weapon has a visibly disabled salvage action")
	check(screen._format_stat("armor",.25)=="0.25" and screen._format_stat("regen",.008)=="0.008" and screen._format_stat("magnet",1.35)=="×1.35","small actual armor, regeneration and magnet gains remain visible")
	fixture.loadout.set_starters(["pulse"]); var parity_uid: int=fixture.loadout.slots[0]
	fixture.loadout.add_module("r_backbeat",2); fixture.loadout.move_module(parity_uid,1)
	make_screen("editor"); await frames(); screen.inspect_module(parity_uid); await frames()
	var detail_text: String=""
	for node in screen.detail_content.get_children():
		if node is Label: detail_text+=node.text+"\n"
	check(detail_text.contains("第 2 格") and detail_text.contains("单发伤害 11.0"),"weapon inspector applies the actual second-step conditional bonus instead of previewing step one")
	view.queue_free(); fixture.queue_free(); await frames()
	await actual_main_flow()
	var result={"checks":checks,"failures":failures,"scope":"Production ArsenalScreen/loadout transaction fixture: six-offer buy/reroll, merge/salvage, track-C drop/unequip, read-only combat, five toggles, source inspector and720p/1080p layout. Additional actual Main.tscn checks default clean combat, independent combat/editor visibility, pause/move/merge/recompile and shop-buy-continue callbacks. Shop entry is an explicit state fixture, not a complete wave/flight or human balance test."}
	FileAccess.open("res://tests/results-arsenal-ui.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t"))
	print("ARSENAL_UI_REVIEW ",JSON.stringify(result))
	quit(0 if failures.is_empty() else 1)

func main_snapshot(name_value: String) -> void:
	if DisplayServer.get_name()=="headless": return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/screenshots/"+name_value+".png")

func actual_main_flow() -> void:
	root.size=Vector2i(1920,1080)
	var game=load("res://scenes/Main.tscn").instantiate()
	root.add_child(game); current_scene=game
	await frames(6)
	game.start_run(3517); game.invulnerable=999.0
	for attempt in range(800):
		if game.music.playing: break
		await create_timer(.01).timeout
	await create_timer(.2).timeout
	var actual_screen=game.ui.arsenal
	check(game.state=="combat" and actual_screen.mode=="combat" and actual_screen.stat_labels.is_empty() and actual_screen.step_cells.size()==24,"actual Main starts with compact three-track combat and optional panels hidden")
	check(actual_screen.panel_rects.sequencer.size.y<=128.0 and actual_screen.panel_rects.sequencer.size.x<=780.0 and actual_screen.step_cards[0].flight_compact,"actual Main combat uses compact icon rows rather than the full workshop layout")
	await main_snapshot("v3-combat-default-1080p")
	var phase: float=game.music.timeline
	var compiles: int=game.music.compile_count
	actual_screen._toggle_all(); await frames()
	check(game.ui.arsenal.stat_labels.size()==14 and game.settings.combat_panel_attributes,"actual combat show-all updates its own visibility preferences")
	check(game.music.compile_count==compiles and game.music.timeline>=phase,"panel visibility never recompiles or resets the native soundtrack")
	game.ui.arsenal._toggle_all(); await frames()
	await main_snapshot("v3-combat-clean-1080p")
	game.open_editor(); await frames(6)
	check(game.state=="editor" and game.music.stream_paused and game.ui.arsenal.stat_labels.size()==14,"opening editor pauses native music and retains full editor panels independently of combat")
	var uid: int=game.loadout.slots[0]
	var level_before: int=game.loadout.find(uid).level
	game.loadout.add_module(str(game.loadout.find(uid).kind),-2)
	game.ui.refresh(); await frames()
	game.ui.arsenal.select_module(uid); await frames()
	var merge_button: Button=game.ui.arsenal.content.find_child("ArsenalMerge",true,false)
	merge_button.pressed.emit(); await frames()
	check(game.loadout.find(uid).level==level_before+1 and game.editing_changed,"actual Main merge callback updates equipment and marks the soundtrack dirty")
	game.ui.arsenal.drop_module(uid,-1); await frames()
	game.ui.arsenal.drop_module(uid,16); await frames()
	check(game.loadout.slots[16]==uid and game.loadout.valid(),"actual Main drag/drop routing unequips and equips on the third track atomically")
	game.ui.arsenal.inspect_module(uid); await frames()
	await main_snapshot("v3-actual-editor-1080p")
	game.close_editor(); await wait_resume(game)
	check(game.state=="combat" and not game.music.stream_paused and game.music.compile_count>=compiles+1,"closing changed editor resumes combat after cached or background soundtrack preparation")
	check(game.ui.arsenal.stat_labels.is_empty(),"editor visibility does not overwrite the hidden combat panels")
	# Explicit shop-state fixture tests real purchase and continue callbacks; the
	# comprehensive flight suite is responsible for earning this state in battle.
	game.state="reward"; game.music.hold(true); game.dust=100
	game.shop_offers=game.loadout.make_shop(game.rng,game.wave); game.ui.refresh(); await frames()
	actual_screen=game.ui.arsenal
	check(actual_screen.mode=="shop" and actual_screen.stat_labels.size()==14,"actual wave-shop uses the full panel composition")
	var money_before: int=game.dust
	var price: int=game.shop_offers[0].price
	var before_items: int=game.loadout.modules.size()
	actual_screen.content.find_child("ShopOffer_0",true,false).pressed.emit(); await frames()
	check(game.dust==money_before-price and game.shop_offers[0].sold and game.loadout.modules.size()==before_items+1,"actual Main shop button commits currency, module and sold state together")
	await main_snapshot("v3-actual-shop-1080p")
	var before_wave: int=game.wave
	game.ui.arsenal.content.find_child("ArsenalContinue",true,false).pressed.emit(); await wait_resume(game)
	check(game.state=="combat" and game.wave==before_wave+1 and not game.music.stream_paused,"actual shop continue button recompiles and starts the next wave")
	check(game.selected_uid==-1 and not game.ui.arsenal.detail_panel.visible,"continuing from a selected shop item leaves combat unobscured by its inspector")
	game.return_title(); await frames()
	game.music.stop(); game.music.stream=null
	for voice in game.voices: voice.stop(); voice.stream=null
	current_scene=null; game.queue_free(); await frames()
	await create_timer(.15).timeout

func wait_resume(game) -> void:
	for i in range(500):
		if game.state=="combat": break
		await create_timer(.01).timeout
	await frames()
