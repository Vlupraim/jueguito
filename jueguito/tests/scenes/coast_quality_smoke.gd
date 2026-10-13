extends Node3D

const WORLD := preload("res://scenes/terrain3d_walk_preview.tscn")
const RULES := preload("res://scripts/network/coast_combat_rules.gd")
var failures: Array[String] = []

func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	GameManager.should_play_tutorial_intro = false
	GameManager.current_character = {"current_sector":Vector2i(27,30),"tutorial_intro_completed":true}
	var world := WORLD.instantiate()
	add_child(world)
	for _frame in range(180):
		await get_tree().process_frame
		if world.get("player") != null and world.get("player").position.x > 250: break
	var player: CharacterBody3D = world.get("player")
	player.set_physics_process(false)
	player.set_process(false)
	var mist: MeshInstance3D = world.get("sector_mist")
	var material := mist.material_override as ShaderMaterial
	check(mist.get_parent() == player.get("camera"),"Border fog follows the active viewport")
	check(material.get_shader_parameter("sector_rect") == Vector4(0,0,512,512),"Fog uses real sector coordinates")
	var environment := world.get_node("Ambiente").environment as Environment
	check(environment.fog_depth_end == 360.0,"Distant coast loses visibility before culling")
	for quality in range(3):
		SettingsManager.set_setting("video","world_detail",quality)
		check(int(material.get_shader_parameter("samples")) == [6,10,16][quality],"Fog quality updates live")
		if DisplayServer.get_name() != "headless":
			var bias: Variant = world.get("terrain").material.get_shader_param("mipmap_bias")
			check(bias != null and is_equal_approx(float(bias),[1.3,0.85,0.35][quality]),"Terrain texture detail updates live")
		var content: Node3D = world.get("sector_content")
		var meshes := content.find_children("*","MeshInstance3D",true,false)
		check(not meshes.is_empty() and meshes[0].visibility_range_end == [380.0,440.0,550.0][quality],"Distant decor culling updates live")
	SettingsManager.set_setting("video","world_detail",1)
	check(is_equal_approx(float(player.get("walk_speed")),2.6),"Native scene uses the new walk speed")
	check(is_equal_approx(float(player.get("sprint_speed"))/float(player.get("walk_speed")),2.36),"Sprint remains proportional to walking")
	player.set("velocity",Vector3(1.4,0,0))
	player.call("_update_locomotion",Vector3.RIGHT,float(player.get("walk_speed")),1.4)
	check(is_equal_approx(player.get("character_animation_player").speed_scale,1.0),"Walking playback follows actual travel")
	player.call("_update_locomotion",Vector3.RIGHT,float(player.get("sprint_speed")),4.2)
	check(is_equal_approx(player.get("character_animation_player").speed_scale,1.0),"Running playback follows actual travel")
	player.call("_update_locomotion",Vector3.RIGHT,float(player.get("walk_speed")),0.0)
	check(player.get("locomotion_state") == "idle","Blocked movement does not walk in place")
	player.call("play_character_action",&"attack")
	check(player.get("character_animation_player").speed_scale == 1.0,"Locomotion does not accelerate attack animations")
	player.call("stop_character_action")
	player.set("stamina",100.0)
	player.call("_update_stamina",100.0/28.0,true)
	check(is_equal_approx(float(player.get("stamina")),75.0),"Sprint lasts four times as long")
	player.call("_update_stamina",100.0/7.0-100.0/28.0,true)
	check(float(player.get("stamina")) < 0.001,"Sprint is still exhaustible")
	var hud: Node = world.get("gameplay_hud")
	hud.call("open_pause_menu")
	check(get_tree().paused,"Offline pause still pauses")
	hud.call("close_pause_menu")
	check(not get_tree().paused,"Offline menu restores processing")
	await _combat_rules()
	_snapshot_assembly()
	if DisplayServer.get_name() != "headless":
		get_viewport().size = Vector2i(1280,720)
		hud.visible = false
		var camera := Camera3D.new()
		camera.fov = 58.0
		camera.far = 900.0
		world.add_child(camera)
		camera.make_current()
		world.get("terrain").set_camera(camera)
		await _capture(camera,Vector3(280,48,360),Vector3(278,2,180),"fog-coast")
		var inland_height: float = world.get("terrain").data.get_height(Vector3(280,0,350))
		await _capture(camera,Vector3(280,inland_height+8,350),Vector3(280,inland_height+4,650),"fog-inland")
		await _capture(camera,Vector3(283,12,212),Vector3(278,4,175),"fog-near-ship")
		await _capture(camera,Vector3(58,17,300),Vector3(-80,17,300),"fog-border")
	print("COAST_QUALITY_SMOKE ","PASS" if failures.is_empty() else "FAIL",failures)
	world.queue_free()
	await get_tree().process_frame
	get_tree().quit(0 if failures.is_empty() else 1)

func _capture(camera: Camera3D, position: Vector3, target: Vector3, name: String) -> void:
	camera.global_position = position
	camera.look_at(target)
	for _frame in range(35): await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var path := "res://.godot/network_validation/"+name+".png"
	get_viewport().get_texture().get_image().save_png(path)
	print("CAPTURE ",path)

func _combat_rules() -> void:
	var a := {"id":2,"position":Vector3.ZERO,"yaw":0.0,"health":100,"pvp":true,"primary":ItemCatalog.VIKING_SWORD,"next_attack":0}
	var b := {"id":3,"position":Vector3(0,0,-2),"health":100,"pvp":true}
	check(RULES.rejection(a,b,1000).is_empty(),"Facing nearby opt-in player is valid")
	b["pvp"] = false
	check(not RULES.rejection(a,b,1000).is_empty(),"Safe players cannot be hit")
	b["pvp"] = true
	b["position"] = Vector3(0,0,-4)
	check(not RULES.rejection(a,b,1000).is_empty(),"Distant players cannot be hit")
	b["position"] = Vector3(0,0,2)
	check(not RULES.rejection(a,b,1000).is_empty(),"Players behind attacker cannot be hit")
	b["position"] = Vector3(0,0,-2)
	a["next_attack"] = 1200
	check(not RULES.rejection(a,b,1000).is_empty(),"Cooldown cannot be bypassed")
	a["next_attack"] = 0
	b["protected_until"] = 1200
	check(not RULES.rejection(a,b,1000).is_empty(),"Respawn protection prevents hits")
	var server_world := preload("res://scripts/network/coast_server_world.gd").new()
	check(server_world.load_world(),"Server loads collision catalog")
	server_world.install_combat_colliders(self)
	var blocker := StaticBody3D.new()
	blocker.collision_layer = 8
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1,4,1)
	shape.shape = box
	blocker.add_child(shape)
	blocker.position = Vector3(284,8,211)
	add_child(blocker)
	await get_tree().physics_frame
	await get_tree().physics_frame
	check(not server_world.combat_line_clear(Vector3(283,8,211),Vector3(285,8,211)),"Server physics blocks attacks through walls")
	blocker.queue_free()
	server_world.collider_root.queue_free()

func _snapshot_assembly() -> void:
	var session := CoopSession
	var previous: Dictionary = session.players.duplicate(true)
	var sequence := session._received_sequence+10
	# Parts may arrive out of order; none may replace the visible world alone.
	session._snapshot(sequence,1,2,[{"id":3,"health":100,"pvp":false}])
	check(session.players == previous,"Incomplete snapshot does not remove players")
	session._snapshot(sequence,0,2,[{"id":2,"health":82,"pvp":true}])
	check(session.players.size() == 2 and session.players.has(2) and session.players.has(3),"Snapshot combines out-of-order parts")
	session._snapshot(sequence-1,0,1,[{"id":4}])
	check(not session.players.has(4),"Older snapshot cannot replace newer state")
	session.players = previous
	session._received_sequence = -1
	session._assembling_sequence = -1
	session._snapshot_parts.clear()
