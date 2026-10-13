extends Node

var failures: Array[String] = []
var saw_two := false
var saw_movement := false
var saw_jump := false
var saw_equipment := false
var saw_attack := false
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
	if role.begins_with("combat_"):
		await _combat_probe()
		return
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
		if state["animation"] == "attack": saw_attack = true
		if state["primary"] == "Hacha de leñador": saw_equipment = true

func finish() -> void:
	print("COOP_PROBE ",role," ","PASS" if failures.is_empty() else "FAIL", " ",failures)
	CoopSession.leave()
	if is_instance_valid(world): world.queue_free()
	await get_tree().process_frame
	get_tree().quit(0 if failures.is_empty() else 1)

func _combat_probe() -> void:
	var start := Time.get_ticks_msec()
	while CoopSession.players.size() < 2 and Time.get_ticks_msec()-start < 10000:
		await get_tree().process_frame
	check(CoopSession.players.size() == 2,"Combat peers connected")
	if CoopSession.players.size() != 2: finish(); return
	var other := 0
	for id in CoopSession.players:
		if id != CoopSession.local_peer_id: other = int(id)
	if role == "combat_alice":
		check(GameManager.toggle_item_equipped(ItemCatalog.VIKING_SWORD),"Equip sword")
		CoopSession.request_attack(other)
		await get_tree().create_timer(0.65).timeout
		check(int(CoopSession.players[other]["health"]) == 100,"PvP off prevents damage")
		CoopSession.set_pvp(true)
		start = Time.get_ticks_msec()
		while not bool(CoopSession.players[other].get("pvp",false)) and Time.get_ticks_msec()-start < 5000:
			await get_tree().process_frame
		await get_tree().create_timer(1.0).timeout
		player.call("face_world_position",CoopSession.players[other]["position"])
		CoopSession.request_attack(other)
		# Bypass client throttling: the server must reject every extra request.
		for _request in range(12): CoopSession._attack.rpc_id(1,other,float(player.get("visual").rotation.y))
		await get_tree().create_timer(0.65).timeout
		check(int(CoopSession.players[other]["health"]) == 82,"One sword hit; server rejects spam")
		await get_tree().create_timer(2.3).timeout
		player.call("face_world_position",CoopSession.players[other]["position"])
		CoopSession.request_attack(other)
		await get_tree().create_timer(0.65).timeout
		check(int(CoopSession.players[other]["health"]) == 82,"Server rejects distant hit")
		start = Time.get_ticks_msec()
		while player.global_position.distance_to(CoopSession.players[other]["position"]) > 2.8 and Time.get_ticks_msec()-start < 10000:
			await get_tree().process_frame
		await get_tree().create_timer(0.35).timeout
		for _hit in range(5):
			player.call("face_world_position",CoopSession.players[other]["position"])
			CoopSession.request_attack(other)
			await get_tree().create_timer(1.1).timeout
		check(int(CoopSession.players[other]["health"]) == 100 and not bool(CoopSession.players[other]["pvp"]),"Defeat respawns target and disables PvP")
		await get_tree().create_timer(0.4).timeout
	else:
		CoopSession.set_pvp(true)
		var hud: Node = world.get("gameplay_hud")
		hud.call("open_pause_menu")
		check(not get_tree().paused,"Online menu never pauses the tree")
		check(not bool(player.get("gameplay_input_enabled")),"Menu consumes movement input")
		var ground_y := player.position.y
		player.position.y += 0.5
		player.set("_grounded",false)
		player.velocity.y = 1.0
		for _tick in range(50):
			player.call("_physics_process",1.0/60.0)
			await get_tree().create_timer(1.0/60.0).timeout
		check(absf(player.position.y-ground_y) < 0.05,"Gravity continues through online menu")
		start = Time.get_ticks_msec()
		while int(CoopSession.players[CoopSession.local_peer_id]["health"]) == 100 and Time.get_ticks_msec()-start < 5000:
			await get_tree().process_frame
		check(int(CoopSession.players[CoopSession.local_peer_id]["health"]) == 82,"Menu gives no PvP immunity")
		check(saw_attack,"Remote attack animation is replicated")
		CoopSession.set_pvp(false)
		await get_tree().create_timer(0.2).timeout
		check(bool(CoopSession.players[CoopSession.local_peer_id]["pvp"]),"Combat lock rejects disabling PvP")
		var home := player.global_position
		await _combat_walk_to(home+Vector3(8,0,0))
		await get_tree().create_timer(2.0).timeout
		check(int(CoopSession.players[CoopSession.local_peer_id]["health"]) == 82,"Distant attacks cause no damage")
		await _combat_walk_to(home)
		start = Time.get_ticks_msec()
		while bool(CoopSession.players[CoopSession.local_peer_id]["pvp"]) and Time.get_ticks_msec()-start < 10000:
			await get_tree().process_frame
		check(int(CoopSession.players[CoopSession.local_peer_id]["health"]) == 100,"Local respawn restores health")
		check(int(GameManager.player_inventory.get(ItemCatalog.VIKING_SWORD,0)) == 1,"Respawn preserves inventory")
		var bar := hud.find_child("CombatHealthBar",true,false) as ProgressBar
		check(bar != null and bar.value == 100.0,"HUD shows server health")
		hud.call("close_pause_menu")
		await get_tree().create_timer(1.0).timeout
	finish()

func _combat_walk_to(target: Vector3) -> void:
	while Vector2(player.global_position.x-target.x,player.global_position.z-target.z).length() > 0.05:
		var next := player.global_position.move_toward(target,0.14)
		next.y = world.get("terrain").data.get_height(next)+float(player.get("ground_clearance"))
		player.global_position = next
		await get_tree().create_timer(0.03).timeout
