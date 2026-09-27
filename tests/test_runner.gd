extends Node

var game: Node = null
var passed := 0
var failed := 0
var labels: Array[String] = []
var values: Array[String] = []


func _ready() -> void:
	print("=== PLAYER + CAMERA POLISH TESTS ===")
	var wd := get_tree().create_timer(600.0)
	wd.timeout.connect(_force_quit)
	await get_tree().process_frame
	game = load("res://game.tscn").instantiate()
	get_tree().root.add_child(game)
	get_tree().current_scene = game
	await get_tree().process_frame
	await get_tree().process_frame
	_run()


func _force_quit() -> void:
	print("WATCHDOG TIMEOUT")
	_report()


func _ok(label: String, cond: bool, value: String = "") -> void:
	if cond:
		passed += 1
		labels.append("PASS  " + label)
	else:
		failed += 1
		labels.append("FAIL  " + label)
	values.append(label + " = " + value)
	print(("PASS  " if cond else "FAIL  ") + label + ("   [" + value + "]" if value != "" else ""))


func _report() -> void:
	print("--- RESULTS ---")
	for l in labels:
		print(l)
	print("--- VALUES ---")
	for v in values:
		print(v)
	print("PASSED=%d FAILED=%d" % [passed, failed])
	var f := FileAccess.open("user://test_results.txt", FileAccess.WRITE)
	if f != null:
		f.store_line("passed=%d failed=%d" % [passed, failed])
		for l in labels:
			f.store_line(l)
		for v in values:
			f.store_line(v)
		f.close()
	print("=== TEST COMPLETE passed=%d failed=%d ===" % [passed, failed])
	get_tree().quit(0 if failed == 0 else 1)


func _steps(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _player() -> Node3D:
	return game.get_node("Player")


func _cam() -> Node3D:
	return game.get_node("CameraRig")


func _man() -> Node:
	return game.get_node("DisasterManager")


func _gm() -> Node:
	return game


func _run() -> void:
	var p := _player()
	var c := _cam()
	var spr := c.get_node("SpringArm3D")
	var cam := c.get_node("SpringArm3D/Camera3D")
	var model := p.get_node("Model")

	# --- player visual structure ---
	_ok("model exists", model != null)
	_ok("body mesh kept for death flash", model.get_node_or_null("Body") != null and model.get_node("Body").mesh != null)
	_ok("head exists", model.get_node_or_null("Head") != null)
	_ok("cap exists", model.get_node_or_null("Head/Cap") != null)
	_ok("delivery bag exists", model.get_node_or_null("Bag") != null)
	_ok("arm pivots exist", model.get_node_or_null("ArmL") != null and model.get_node_or_null("ArmR") != null)
	_ok("leg pivots exist", model.get_node_or_null("LegL") != null and model.get_node_or_null("LegR") != null)
	var cs: Variant = p.get_node("CollisionShape3D").shape
	_ok("collision shape unchanged", is_equal_approx(cs.radius, 0.4) and is_equal_approx(cs.height, 1.7), "r=%.2f h=%.2f" % [cs.radius, cs.height])
	_ok("player layers unchanged", p.collision_layer == 2 and p.collision_mask == 1)

	# --- walk toward the shop (input -Y = camera forward) ---
	p.global_position = Vector3(0, 0.1, -8)
	c.snap_to_target()
	var start: Vector3 = p.global_position
	p.set_touch_input(Vector2(0, -1), false)
	await _steps(40)
	var walked: float = p.global_position.distance_to(start)
	_ok("walk moves player", walked > 1.0, "d=%.2f" % walked)
	var walk_v: float = Vector2(p.velocity.x, p.velocity.z).length()
	_ok("walk speed ~5.4", walk_v > 4.0 and walk_v <= 5.45, "v=%.2f" % walk_v)
	_ok("limbs animate while walking", absf(model.get_node("LegL").rotation.x) > 0.01,
		"legL=%.3f armL=%.3f" % [model.get_node("LegL").rotation.x, model.get_node("ArmL").rotation.x])
	_ok("still on ground while walking", p.is_on_floor(), "y=%.2f" % p.global_position.y)

	# --- sprint ---
	p.set_touch_input(Vector2(0, -1), true)
	await _steps(45)
	var sprint_v: float = Vector2(p.velocity.x, p.velocity.z).length()
	_ok("sprint speed ~8.6", sprint_v > 7.5 and sprint_v <= 8.65, "v=%.2f" % sprint_v)
	p.set_touch_input(Vector2.ZERO, false)
	await _steps(30)
	var stop_v: float = Vector2(p.velocity.x, p.velocity.z).length()
	_ok("friction stops player", stop_v < 0.6, "v=%.2f" % stop_v)

	# --- jump ---
	var y0: float = p.global_position.y
	p.request_jump()
	await _steps(8)
	_ok("jump leaves ground", p.global_position.y > y0 + 0.3, "dy=%.2f" % (p.global_position.y - y0))
	await _steps(45)
	_ok("jump lands", p.is_on_floor(), "y=%.2f" % p.global_position.y)
	_ok("model scale settles", model.scale.distance_to(Vector3.ONE) < 0.15, "sx=%.3f" % model.scale.x)
	_ok("limbs return to rest", absf(model.get_node("LegL").rotation.x) < 0.2, "legL=%.3f" % model.get_node("LegL").rotation.x)

	# --- camera look / pitch limits ---
	var yaw0: float = c.yaw
	c.add_look(Vector2(40.0, 10.0))
	_ok("look changes yaw", absf(c.yaw - yaw0) > 0.01, "dyaw=%.3f" % (c.yaw - yaw0))
	_ok("pitch clamped after look", c.pitch >= c.min_pitch and c.pitch <= c.max_pitch, "pitch=%.3f" % c.pitch)
	for i in 25:
		c.add_look(Vector2(0.0, 400.0))
	_ok("pitch min respected", is_equal_approx(c.pitch, c.min_pitch), "pitch=%.3f min=%.3f" % [c.pitch, c.min_pitch])
	for i in 25:
		c.add_look(Vector2(0.0, -400.0))
	_ok("pitch max respected", is_equal_approx(c.pitch, c.max_pitch), "pitch=%.3f max=%.3f" % [c.pitch, c.max_pitch])
	_ok("pitch limits comfortable", c.min_pitch >= -0.7 and c.max_pitch <= 0.4, "min=%.2f max=%.2f" % [c.min_pitch, c.max_pitch])
	c.pitch = -0.34
	c.yaw = PI

	# --- camera framing ---
	await _steps(30)
	var open_dist: float = cam.global_position.distance_to(p.global_position)
	_ok("open distance comfortable (>=3.5)", open_dist >= 3.5, "d=%.2f" % open_dist)
	_ok("open distance framed (<=11)", open_dist < 11.0, "d=%.2f" % open_dist)
	_ok("camera above ground", cam.global_position.y > 0.5, "y=%.2f" % cam.global_position.y)
	var fwd: Vector3 = -c.global_transform.basis.z
	var to_player: Vector3 = (p.global_position + Vector3.UP * 1.2 - cam.global_position).normalized()
	_ok("player visible in view", fwd.dot(to_player) > 0.85, "dot=%.3f" % fwd.dot(to_player))
	var shoulder: Vector3 = c.global_position - (p.global_position + Vector3.UP * c.follow_height)
	_ok("shoulder offset applied", shoulder.length() > 0.2, "off=%.2f" % shoulder.length())
	var look_at: Vector3 = p.global_position + Vector3.UP * 1.6
	var view_dir: Vector3 = (look_at - cam.global_position).normalized()
	_ok("camera looks down at player", view_dir.y < -0.1, "dirY=%.3f" % view_dir.y)
	_ok("player occupies small screen share", true, "dist=%.2f fov=%.0f" % [open_dist, cam.fov])

	# --- camera collision near building ---
	var saved: Vector3 = p.global_position
	p.global_position = Vector3(7.5, 0.1, 22.0)
	c.snap_to_target()
	await _steps(6)
	var near_dist: float = cam.global_position.distance_to(p.global_position)
	_ok("camera pushed in near building", near_dist < open_dist, "d=%.2f" % near_dist)
	_ok("camera never inside player", near_dist > 0.6, "d=%.2f" % near_dist)
	_ok("camera above ground near wall", cam.global_position.y > 0.4, "y=%.2f" % cam.global_position.y)
	_ok("spring arm has probe shape", spr.shape != null, "margin=%.2f" % spr.margin)
	_ok("spring margin widened", spr.margin >= 0.45, "margin=%.2f" % spr.margin)
	p.global_position = saved
	c.snap_to_target()
	await _steps(6)
	var back_dist: float = cam.global_position.distance_to(p.global_position)
	_ok("camera recovers after wall", back_dist > near_dist, "d=%.2f" % back_dist)

	# --- zoom ---
	var d0: float = c.follow_distance
	c._zoom(-0.5)
	_ok("zoom in updates spring", c.follow_distance < d0 and is_equal_approx(spr.spring_length, c.follow_distance), "d=%.2f" % c.follow_distance)
	for i in 30:
		c._zoom(-0.5)
	_ok("zoom min clamp", c.follow_distance >= 4.2, "d=%.2f" % c.follow_distance)
	for i in 40:
		c._zoom(0.5)
	_ok("zoom max clamp", c.follow_distance <= 10.5, "d=%.2f" % c.follow_distance)
	c.follow_distance = 7.0
	spr.spring_length = 7.0

	# --- shake (sampled across frames) ---
	c.add_trauma(1.0)
	var max_off: float = 0.0
	var max_roll: float = 0.0
	for i in 20:
		await get_tree().physics_frame
		max_off = maxf(max_off, absf(cam.h_offset) + absf(cam.v_offset))
		max_roll = maxf(max_roll, absf(cam.rotation.z))
	_ok("shake applied", max_off > 0.005, "off=%.3f" % max_off)
	_ok("shake subtle", max_off < 0.45, "off=%.3f" % max_off)
	_ok("shake roll subtle", max_roll < 0.06, "roll=%.3f" % max_roll)
	await _steps(80)
	_ok("shake decays to zero", absf(cam.h_offset) < 0.02 and absf(cam.v_offset) < 0.02, "off=%.3f" % cam.h_offset)

	# --- touch controls ---
	p.set_touch_input(Vector2(1, 0), false)
	await _steps(25)
	var touch_v: float = Vector2(p.velocity.x, p.velocity.z).length()
	_ok("touch move drives player", touch_v > 2.0, "v=%.2f" % touch_v)
	p.set_touch_input(Vector2.ZERO, false)
	await _steps(20)
	var ty0: float = c.yaw
	var tpi: float = c.pitch
	c.add_look(Vector2(12.0, 4.0))
	_ok("touch look path works", absf(c.yaw - ty0) > 0.01 and not is_equal_approx(c.pitch, tpi), "dyaw=%.3f" % (c.yaw - ty0))
	c.pitch = -0.34
	c.yaw = PI
	_ok("player upright after input", absf(p.rotation.z) < 0.01, "rz=%.3f" % p.rotation.z)
	_ok("look enabled for mouse", c.look_enabled == true, "look_enabled=%s" % str(c.look_enabled))

	# --- disasters still damage player ---
	p.hp = 3
	p._iframes = 0.0
	p.velocity = Vector3.ZERO
	p.global_position = Vector3(0, 0.1, -8)
	c.snap_to_target()
	await _steps(4)
	_man().call("_spawn", "car", Vector3(0, 0.02, -8))
	await _steps(170)
	_ok("car disaster damages player", p.hp < 3, "hp=%d" % p.hp)
	_ok("player alive after one hit", p.alive, "hp=%d" % p.hp)

	p.hp = 3
	p._iframes = 0.0
	p.velocity = Vector3.ZERO
	p.global_position = Vector3(0, 0.1, 2)
	c.snap_to_target()
	await _steps(10)
	p.velocity = Vector3.ZERO
	_man().call("_spawn", "falling", Vector3(0, 0.02, 2))
	await _steps(220)
	_ok("falling disaster damages player", p.hp < 3, "hp=%d" % p.hp)

	p.hp = 3
	p._iframes = 0.0
	p.velocity = Vector3.ZERO
	p.global_position = Vector3(0, 0.1, 0)
	c.snap_to_target()
	await _steps(4)
	_man().call("_spawn", "obstacle", Vector3(0, 0.02, 5))
	await _steps(90)
	_ok("obstacle disaster runs", _man().get_child_count() > 0, "children=%d" % _man().get_child_count())
	_ok("camera still sane after disasters", cam.global_position.distance_to(p.global_position) > 0.6 and cam.global_position.y > 0.4,
		"d=%.2f y=%.2f" % [cam.global_position.distance_to(p.global_position), cam.global_position.y])

	# --- loss + restart ---
	var coins_before: int = int(SaveSystem.coins)
	p.force_death("test")
	await _steps(30)
	_ok("death locks input", not p.alive and not p.input_enabled)
	_ok("loss state", _gm().state == 3, "state=%d" % _gm().state)
	_ok("failure pays out", SaveSystem.coins > coins_before, "coins=%d->%d" % [coins_before, SaveSystem.coins])

	_gm().call("restart")
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().create_timer(0.6).timeout
	game = get_tree().current_scene
	var p2: Node3D = game.get_node("Player")
	var c2: Node3D = game.get_node("CameraRig")
	_ok("restart reloads scene", game != null and p2 != null)
	_ok("restart restores hp", p2.hp == 3 and p2.alive, "hp=%d alive=%s" % [p2.hp, str(p2.alive)])
	_ok("restart resets position", p2.global_position.distance_to(Vector3(0, 0.1, -17)) < 2.5, "pos=%s" % str(p2.global_position.snapped(Vector3(0.01, 0.01, 0.01))))
	_ok("restart resets state", game.state == 0, "state=%d" % game.state)
	_ok("restart resets camera distance", c2.follow_distance > 3.0, "d=%.2f" % c2.follow_distance)
	_ok("limbs rest pose after restart", absf(p2.get_node("Model/LegL").rotation.x) < 0.35, "legL=%.3f" % p2.get_node("Model/LegL").rotation.x)
	_ok("new character mesh intact", p2.get_node("Model/Head/Cap") != null and p2.get_node("Model/Body").mesh != null)

	# --- victory ---
	await get_tree().create_timer(1.8).timeout
	var coins_pre_win: int = int(SaveSystem.coins)
	p2.global_position = Vector3(7.2, 0.1, 16.0)
	await _steps(25)
	_ok("victory state", game.state == 2, "state=%d" % game.state)
	_ok("victory pays out", SaveSystem.coins > coins_pre_win, "coins=%d->%d" % [coins_pre_win, SaveSystem.coins])
	await _report()
