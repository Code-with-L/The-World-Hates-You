extends Node3D

var _fails := 0
var _passes := 0
var _done := false
var _elapsed := 0.0

func _process(delta: float) -> void:
	if _done:
		return
	_elapsed += delta
	if _elapsed > 45.0:
		printerr("CITY VERIFY TIMEOUT - aborting")
		get_tree().quit(1)

func _ready() -> void:
	var scene: Node = load("res://scenes/city_block.tscn").instantiate()
	add_child(scene)
	await get_tree().process_frame
	await get_tree().process_frame

	# --- required gameplay anchors (must be identical to the original) ---
	var expect := {
		"DisasterZones/CarAttackZone": [Vector3(0, 0.5, -8), Vector3(8, 3, 6)],
		"DisasterZones/FallingObjectZone": [Vector3(-5.5, 0.5, 10), Vector3(2.4, 3, 3)],
		"DisasterZones/DogChaseZone": [Vector3(5.5, 0.5, 0), Vector3(2.6, 3, 9)],
		"DisasterZones/ObstacleZone1": [Vector3(-5.5, 0.5, -3), Vector3(2.4, 3, 3)],
		"DisasterZones/ObstacleZone2": [Vector3(5.5, 0.5, -15), Vector3(2.4, 3, 3)],
		"DisasterZones/ObstacleZone3": [Vector3(-5.5, 0.5, 13), Vector3(2.4, 3, 3)],
	}
	# LockedDoorArea is a plain Node3D in the original scene (it is decoration plus a
	# spawn anchor), so it only has a position requirement.
	for path in ["DisasterZones/LockedDoorArea"]:
		var dn: Node3D = scene.get_node_or_null(NodePath(path)) as Node3D
		if dn == null:
			_fail("MISSING " + path)
		elif dn is Area3D:
			_fail(path + " must stay a Node3D, not an Area3D")
		elif dn.position.distance_to(Vector3(-5.5, 1.35, 5)) > 0.001:
			_fail("MOVED " + path + " -> " + str(dn.position))
		else:
			_pass("ANCHOR " + path + " (Node3D)")
	for path in expect.keys():
		var want: Array = expect[path]
		var n: Node3D = scene.get_node_or_null(NodePath(path)) as Node3D
		if n == null:
			_fail("MISSING " + path)
			continue
		if n.position.distance_to(want[0]) > 0.001:
			_fail("MOVED " + path + " -> " + str(n.position))
			continue
		var a: Area3D = n as Area3D
		var sh: Object = _shape_of(a)
		var dims: Vector3 = _box_dims(sh)
		if dims == Vector3.ZERO:
			_fail("NO BOX SHAPE " + path)
			continue
		if dims.distance_to(want[1]) > 0.001:
			_fail("BAD SHAPE " + path + " -> " + str(sh))
			continue
		_pass("ANCHOR " + path)

	# mission.gd reads CityBlock/PizzaShopGoal as a Node3D, keeps its global
	# position and uses its own goal_radius of 2.7 for the victory check.
	var goal: Marker3D = scene.get_node_or_null("PizzaShopGoal") as Marker3D
	if goal == null:
		_fail("PizzaShopGoal must stay a Marker3D")
	elif goal.position.distance_to(Vector3(7.2, 1.0, 15.4)) > 0.001:
		_fail("GOAL MOVED -> " + str(goal.position))
	else:
		_pass("ANCHOR PizzaShopGoal Marker3D at (7.2,1,15.4)")
	var mission: Node = load("res://scripts/mission.gd").new()
	var m_radius: float = mission.goal_radius
	mission.free()
	if absf(m_radius - 2.7) > 0.001:
		_fail("mission goal_radius changed -> " + str(m_radius))
	else:
		_pass("mission goal_radius still 2.7")

	var icon: Node3D = scene.get_node_or_null("PizzaShop/PizzaIcon") as Node3D
	if icon == null:
		_fail("MISSING PizzaShop/PizzaIcon")
	elif icon.position.distance_to(Vector3(-1.5, 6.5, -2.2)) > 0.001:
		_fail("PizzaIcon moved -> " + str(icon.position))
	else:
		_pass("PizzaShop/PizzaIcon at original anchor")

	var cam: Node3D = scene.get_node_or_null("CameraRig") as Node3D
	if cam != null:
		_fail("city scene must not own the gameplay camera")
	else:
		_pass("gameplay camera left in game.tscn")

	# --- floors: same walkable heights as the original layout ---
	_walkable("sidewalk L", Vector3(-5.5, 4, 0), 0.15)
	_walkable("sidewalk R", Vector3(5.5, 4, 6), 0.15)
	_walkable("sidewalk shop front", Vector3(5.2, 4, 15.4), 0.15)
	_walkable("road mid", Vector3(1.8, 4, -2), 0.0)
	_walkable("road south", Vector3(-1.8, 4, 2), 0.0)
	_walkable("road north", Vector3(1.8, 4, 12), 0.0)
	_walkable("south apron", Vector3(0, 4, 23), -0.2)
	_walkable("north apron", Vector3(0, 4, -23), -0.2)

	# --- the right sidewalk must stay walkable from the spawn to the shop ---
	var blocked := []
	for z in range(-17, 16):
		var clear := 0
		var names := []
		for dx in [4.3, 4.8, 5.3, 5.8, 6.3]:
			var from := Vector3(float(dx), 1.0, float(z))
			if not _ray(from, Vector3(0, 0, 1), 0.95):
				clear += 1
			else:
				var w := _ray_name(from, Vector3(0, 0, 1), 0.95)
				names.append(w)
		if clear == 0:
			blocked.append("%d[%s]" % [z, ",".join(names)])
	if blocked.size() > 0:
		_fail("right sidewalk fully obstructed at " + str(blocked))
	else:
		_pass("right sidewalk always walkable (>=1.2m lane)")

	# --- goal decor must sit inside the goal trigger and on the sidewalk ---
	var pad: Node3D = scene.get_node_or_null("PizzaShopGoal/Pad") as Node3D
	if pad == null:
		_fail("MISSING goal pad")
	elif goal == null or pad.global_position.distance_to(goal.global_position) > float(m_radius):
		_fail("goal pad outside goal radius")
	else:
		_pass("goal pad inside goal radius")

	# --- left sidewalk must stay walkable too (locked door / hydrant side) ---
	var lblocked := []
	for z in range(-17, 16):
		var clear := 0
		for dx in [-6.7, -6.2, -5.7, -5.2, -4.7]:
			var from := Vector3(float(dx), 1.0, float(z))
			if not _ray(from, Vector3(0, 0, 1), 0.95):
				clear += 1
		if clear == 0:
			lblocked.append(z)
	if lblocked.size() > 0:
		_fail("left sidewalk fully obstructed at " + str(lblocked))
	else:
		_pass("left sidewalk always walkable")

	# --- the road must stay clear (the car attack drives down it) ---
	var rblocked := []
	for z in range(-19, 20):
		var clear := 0
		for dx in [-3.0, -1.5, 1.5, 3.0]:
			var from := Vector3(float(dx), 0.6, float(z))
			if not _ray(from, Vector3(0, 0, 1), 0.95):
				clear += 1
		if clear == 0:
			rblocked.append(z)
	if rblocked.size() > 0:
		_fail("road obstructed at " + str(rblocked))
	else:
		_pass("road driving lane clear")

	# --- no tall geometry inside the six disaster zone volumes ---
	for path in expect.keys():
		var zn: Node3D = scene.get_node_or_null(NodePath(path)) as Node3D
		if zn == null:
			continue
		var want: Array = expect[path]
		var half: Vector3 = (want[1] as Vector3) * 0.5
		for c in scene.find_children("*", "CollisionObject3D", true, false):
			var co: CollisionObject3D = c as CollisionObject3D
			if co == null or co.get_collision_layer() == 0 or co is Area3D:
				continue
			var gx: Vector3 = co.global_position - zn.global_position
			if absf(gx.x) < half.x + 0.3 and absf(gx.y) < half.y and absf(gx.z) < half.z + 0.3:
				_fail("solid inside zone " + path + ": " + co.name)
				break

	print("PASSED=%d FAILED=%d" % [_passes, _fails])
	print("=== CITY VERIFY %s ===" % ("OK" if _fails == 0 else "FAILED"))
	_done = true
	get_tree().quit(0 if _fails == 0 else 1)

func _shape_of(n: Node) -> Object:
	if n == null or not (n is CollisionObject3D):
		return null
	var co: CollisionObject3D = n as CollisionObject3D
	var ids: Array = co.get_shape_owners()
	if not ids.is_empty():
		return co.shape_owner_get_shape(int(ids[0]), 0)
	# CSG areas generate their own collision, so there is no shape owner
	for c in n.get_children():
		if c is CSGShape3D:
			return c
	return null

func _box_dims(sh: Object) -> Vector3:
	if sh is BoxShape3D:
		return (sh as BoxShape3D).size
	if sh is CSGBox3D:
		return (sh as CSGBox3D).size
	return Vector3.ZERO

func _sphere_radius(sh: Object) -> float:
	if sh is SphereShape3D:
		return (sh as SphereShape3D).radius
	if sh is CSGSphere3D:
		return (sh as CSGSphere3D).radius
	return -1.0

func _pass(tag: String) -> void:
	_passes += 1
	print("PASS  " + tag)

func _fail(tag: String) -> void:
	_fails += 1
	print("FAIL  " + tag)

func _ray(from: Vector3, dir: Vector3, len: float) -> bool:
	var q := PhysicsRayQueryParameters3D.create(from, from + dir.normalized() * len)
	q.collision_mask = 0xFFFFFFFF
	return not get_world_3d().direct_space_state.intersect_ray(q).is_empty()

func _ray_name(from: Vector3, dir: Vector3, len: float) -> String:
	var q := PhysicsRayQueryParameters3D.create(from, from + dir.normalized() * len)
	q.collision_mask = 0xFFFFFFFF
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		return "-"
	var w: Object = hit.get("collider")
	return str(w) if w != null else "?"

func _walkable(tag: String, x: Vector3, expect_y: float) -> void:
	var from := Vector3(x.x, x.y, x.z)
	var q := PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * 14.0)
	q.collision_mask = 0xFFFFFFFF
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		_fail("NO FLOOR under " + tag)
		return
	var y: float = hit.position.y
	if absf(y - expect_y) > 0.05:
		var who: Node = hit.get("collider") as Node
		_fail("FLOOR %s at y=%.3f (hit %s) expected %.2f" % [tag, y, str(who), expect_y])
		return
	if _ray(from + Vector3(0, 0.85, 0), Vector3.DOWN, 0.65):
		_fail("CEILING too low over " + tag)
		return
	_pass("FLOOR " + tag + " y=%.2f" % y)


