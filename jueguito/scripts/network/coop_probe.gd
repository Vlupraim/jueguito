extends Node

var failures: Array[String] = []
var saw_two := false
var saw_movement := false
var saw_jump := false
var saw_equipment := false
var saw_depleted := false
var role := ""
var world: Node3D
var player: CharacterBody3D
var previous_remote := Vector3(INF,INF,INF)

func check(ok: bool, message: String) -> void:
	if not ok: failures.append(message); push_error("PROBE: "+message)

func _ready() -> void:
	role = CoopSession.option("network-test")
	_run()

func _run() -> void:
	var start := Time.get_ticks_msec()
	while not CoopSession.active and Time.get_ticks_msec()-start < 14000:
		await get_tree().process_frame
	if role == "reject":
		check(not CoopSession.active and CoopSession.status.contains("clave"),"Wrong key rejected")
		finish()
		return
	check(CoopSession.active,"Connected")
	if not CoopSession.active: finish(); return
	if role == "rejoin":
		check(int(GameManager.player_inventory.get("Madera",0)) == 4,"Inventory survives server restart")
		check(CoopSession.get_respawn_at("sector_27_30/coast_tree_01") > Time.get_unix_time_from_system(),"Tree depletion survives server restart")
		finish()
		return
	world = load(GameManager.WORLD_SCENE).instantiate()
	add_child(world)
	await get_tree().create_timer(2.0).timeout
	player = world.get("player")
	check(player != null,"Native player/world loaded")
	check(int(world.get("ocean_water").get("water_cell_count")) > 0,"Ocean mask survives export")
	check(world.get("terrain").assets.get_texture_count() == 25,"Terrain texture library survives export")
	player.set_physics_process(false)
	set_process(true)
	check(GameManager.equip_tool(ItemCatalog.LUMBERJACK_AXE),"Equip native axe")
	print("PROBE_EQUIPMENT ",GameManager.equipped_primary_item," inventory=",GameManager.player_inventory)
	var home := player.global_position
	# Small genuine network movement and an airborne pose; the server sees only RPCs.
	for step in range(90):
		player.global_position.x = home.x+sin(step/90.0*TAU)*1.0
		player.global_position.y = home.y+sin(step/90.0*PI)*1.0
		player.get("character_animation_player").play("shared/jump")
		await get_tree().create_timer(0.033).timeout
	player.global_position = home
	player.global_position.x += 60
	await get_tree().create_timer(0.5).timeout
	check(player.global_position.distance_to(home) < 1.0,"Server rejects teleport")
	player.get("character_animation_player").play("shared/walk")
	var tree: Node3D = world.get_tree().get_nodes_in_group("harvestable_trees")[0]
	var target := tree.global_position+Vector3(2,0,0)
	while Vector2(player.global_position.x-target.x,player.global_position.z-target.z).length() > 0.1:
		var next := player.global_position.move_toward(target,0.15)
		next.y = world.get("terrain").data.get_height(next)+0.78
		player.global_position = next
		await get_tree().create_timer(0.03).timeout
	await get_tree().create_timer(0.5).timeout
	if role == "alice":
		check(tree.begin_interaction(player),"Begin native harvest")
		player.get("character_animation_player").play("shared/chop")
		await get_tree().create_timer(7.2).timeout
		check(tree.complete_interaction(player),"Finish native harvest")
		await get_tree().create_timer(1.0).timeout
		check(int(GameManager.player_inventory.get("Madera",0)) == 4,"Server grants four wood")
	else:
		await get_tree().create_timer(0.7).timeout
		# Competing/immediate finish must never grant duplicate wood.
		check(tree.begin_interaction(player),"Competing local harvest begins")
		check(tree.complete_interaction(player),"Local prediction awaits server")
		await get_tree().create_timer(1.0).timeout
		check(bool(tree.get("available")) and tree.get_node("VisualPivot").visible,"Rejected harvest restores tree and cancels fall")
		await get_tree().create_timer(7.0).timeout
		check(int(GameManager.player_inventory.get("Madera",0)) == 0,"Competing harvest grants no wood")
	check(not bool(tree.get("available")),"Shared native tree stump")
	check(saw_two,"Other player avatar visible")
	check(saw_movement,"Remote movement replicated")
	check(saw_jump,"Remote jump replicated")
	check(saw_equipment,"Remote equipped axe replicated")
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(CoopSession.option("capture","user://coop_probe.png"))
	if role == "bob":
		await get_tree().create_timer(3.0).timeout
		check(CoopSession.avatars.is_empty(),"Disconnected player removed")
	finish()

func _process(_delta: float) -> void:
	if not CoopSession.active: return
	if CoopSession.players.size() == 2: saw_two = true
	for id in CoopSession.players:
		if id == CoopSession.local_peer_id: continue
		var state: Dictionary = CoopSession.players[id]
		var position: Vector3 = state["position"]
		if previous_remote.is_finite() and previous_remote.distance_to(position) > 0.02: saw_movement = true
		previous_remote = position
		if state["animation"] == "jump": saw_jump = true
		if state["primary"] == "Hacha de leñador": saw_equipment = true

func finish() -> void:
	print("COOP_PROBE ",role," ","PASS" if failures.is_empty() else "FAIL", " ",failures)
	CoopSession.leave()
	if is_instance_valid(world): world.queue_free()
	await get_tree().process_frame
	get_tree().quit(0 if failures.is_empty() else 1)
