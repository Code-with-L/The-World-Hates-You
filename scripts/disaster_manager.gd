extends Node3D

const CarDisaster := preload("res://scripts/disasters/car_disaster.gd")
const FallingObjectDisaster := preload("res://scripts/disasters/falling_object_disaster.gd")
const DogChaseDisaster := preload("res://scripts/disasters/dog_chase.gd")
const LockedDoorDisaster := preload("res://scripts/disasters/locked_door_disaster.gd")
const ObstacleDisaster := preload("res://scripts/disasters/obstacle_disaster.gd")

const FIRST_DELAY := 4.0
const MIN_INTERVAL := 4.5
const MAX_INTERVAL := 8.5
const MAX_ACTIVE := 2
const TELEGRAPH := 1.25
const STREET_MIN_X := -6.4
const STREET_MAX_X := 6.4
const STREET_MIN_Z := -18.0
const STREET_MAX_Z := 17.5
const ROAD_EDGE := 4.0

const SCRIPTS := {
	"car": CarDisaster,
	"falling": FallingObjectDisaster,
	"dog": DogChaseDisaster,
	"door": LockedDoorDisaster,
	"obstacle": ObstacleDisaster,
}
const WEIGHTS := {
	"car": 1.0,
	"falling": 1.0,
	"dog": 1.1,
	"door": 0.7,
	"obstacle": 1.3,
}
const MESSAGES := {
	"car": ["CAR INCOMING!", "BRUH! A CAR!", "MOVE! CAR!"],
	"falling": ["LOOK OUT! ABOVE!", "INCOMING FROM ABOVE!", "WATCH THE SKY!"],
	"dog": ["DOG! RUN!", "OH NO! DOG!", "HERE COME THE DOGS!"],
	"door": ["LOCKED! GO AROUND!", "NOT THIS WAY!", "THE DOOR SAYS NO!"],
	"obstacle": ["TRIP HAZARD!", "WATCH THE FLOOR!", "STUFF IN THE WAY!"],
}

var player: Node3D = null
var game: Node = null

var _active_disasters := {}
var _cooldowns := {}
var _last_kind := ""
var _timer := FIRST_DELAY
var _pending := false
var _running := false

@onready var zones: Node3D = get_node("../CityBlock/DisasterZones")


func setup(p: Node3D, g: Node) -> void:
	player = p
	game = g


func set_active(value: bool) -> void:
	_running = value
	if value:
		_timer = FIRST_DELAY
		_pending = false
		return
	for kind in _active_disasters.keys():
		var disaster: Node = _active_disasters[kind]
		if is_instance_valid(disaster):
			disaster.finish()
	_active_disasters.clear()
	_cooldowns.clear()
	_pending = false


func _process(delta: float) -> void:
	if not _running or player == null or not is_instance_valid(player):
		return
	_prune()
	for kind in _cooldowns.keys():
		_cooldowns[kind] = maxf(0.0, float(_cooldowns[kind]) - delta)
	if _pending:
		return
	_timer -= delta
	if _timer <= 0.0:
		_timer = randf_range(MIN_INTERVAL, MAX_INTERVAL)
		_try_spawn()


func _prune() -> void:
	for kind in _active_disasters.keys():
		if not is_instance_valid(_active_disasters[kind]):
			_active_disasters.erase(kind)


func _try_spawn() -> void:
	if _active_disasters.size() >= MAX_ACTIVE:
		return
	var options := _available_kinds()
	if options.is_empty():
		return
	var kind: String = _weighted_pick(options)
	var point: Variant = _pick_point(kind)
	if point == null:
		_timer = minf(_timer, 2.0)
		return
	_spawn(kind, point)


func _available_kinds() -> Array:
	var options: Array = []
	for kind in SCRIPTS.keys():
		if _active_disasters.has(kind):
			continue
		if kind == _last_kind:
			continue
		if float(_cooldowns.get(kind, 0.0)) > 0.0:
			continue
		options.append(kind)
	if options.is_empty():
		for kind in SCRIPTS.keys():
			if not _active_disasters.has(kind):
				options.append(kind)
	return options


func _weighted_pick(options: Array) -> String:
	var total := 0.0
	for kind in options:
		total += float(WEIGHTS.get(kind, 1.0))
	var roll := randf() * total
	for kind in options:
		roll -= float(WEIGHTS.get(kind, 1.0))
		if roll <= 0.0:
			return kind
	return options[options.size() - 1]


func _pick_point(kind: String) -> Variant:
	var ppos: Vector3 = player.global_position
	match kind:
		"car":
			return Vector3(clampf(ppos.x, -4.6, 4.6), 0.0, ppos.z)
		"falling":
			var drop_zone: Variant = _point_in_zone("FallingObjectZone", ppos, 7.0, 2.5)
			if drop_zone != null:
				return drop_zone
			return _clamp_to_street(ppos + _forward() * randf_range(3.6, 5.4))
		"dog":
			var in_zone: Variant = _point_in_zone("DogChaseZone", ppos, 9.0, 6.0)
			if in_zone != null:
				return in_zone
			return _point_ahead(ppos, 7.5, 10.5)
		"door":
			var door: Node3D = zones.get_node_or_null("LockedDoorArea") as Node3D
			if door != null and door.global_position.distance_to(ppos) <= 16.0:
				return Vector3(door.global_position.x, _ground_y(door.global_position.x), door.global_position.z)
			return _point_ahead(ppos, 7.0, 9.5)
		"obstacle":
			var spot: Variant = _point_in_random_obstacle_zone(ppos)
			if spot != null:
				return spot
			return _point_ahead(ppos, 6.0, 9.0)
	return null


func _point_ahead(ppos: Vector3, min_dist: float, max_dist: float) -> Variant:
	for attempt in 8:
		var angle := randf_range(-1.1, 1.1)
		var dist := randf_range(min_dist, max_dist)
		var offset := Vector3(sin(angle) * dist, 0.0, cos(angle) * dist)
		if _forward_is_positive():
			offset.z = absf(offset.z)
		else:
			offset.z = -absf(offset.z)
		var point := _clamp_to_street(ppos + offset)
		if ppos.distance_to(point) >= min_dist * 0.8:
			return point
	return null


func _point_in_zone(zone_name: String, ppos: Vector3, max_dist: float, min_dist: float) -> Variant:
	var zone := zones.get_node_or_null(zone_name) as Area3D
	if zone == null:
		return null
	if zone.global_position.distance_to(ppos) > max_dist:
		return null
	for attempt in 6:
		var point := _random_point_in_area(zone, 1.0)
		if ppos.distance_to(point) >= min_dist:
			return point
	return null


func _point_in_random_obstacle_zone(ppos: Vector3) -> Variant:
	var names := ["ObstacleZone1", "ObstacleZone2", "ObstacleZone3"]
	names.shuffle()
	for name in names:
		var point: Variant = _point_in_zone(name, ppos, 26.0, 5.5)
		if point != null:
			return point
	return null


func _random_point_in_area(area: Area3D, inset: float) -> Vector3:
	var local := Vector3.ZERO
	var shape_node := area.get_node_or_null("CollisionShape3D") as CollisionShape3D
	if shape_node != null and shape_node.shape is BoxShape3D:
		var half: Vector3 = (shape_node.shape as BoxShape3D).size * 0.5
		var lo_x := -half.x + inset
		var hi_x := maxf(lo_x, half.x - inset)
		var lo_z := -half.z + inset
		var hi_z := maxf(lo_z, half.z - inset)
		local = Vector3(randf_range(lo_x, hi_x), 0.0, randf_range(lo_z, hi_z))
	var point := area.to_global(local)
	point.y = _ground_y(point.x)
	return point


func _clamp_to_street(point: Vector3) -> Vector3:
	var x := clampf(point.x, STREET_MIN_X, STREET_MAX_X)
	var z := clampf(point.z, STREET_MIN_Z, STREET_MAX_Z)
	return Vector3(x, _ground_y(x), z)


func _ground_y(x: float) -> float:
	return 0.16 if absf(x) > ROAD_EDGE else 0.02


func _forward() -> Vector3:
	if game != null and is_instance_valid(game):
		var rig = game.get("camera_rig")
		if rig is Node3D and is_instance_valid(rig):
			var yaw: float = rig.get("yaw")
			return Vector3(-sin(yaw), 0.0, -cos(yaw)).normalized()
	if is_instance_valid(player):
		var f := -player.global_transform.basis.z
		f.y = 0.0
		if f.length() > 0.01:
			return f.normalized()
	return Vector3.FORWARD


func _forward_is_positive() -> bool:
	return _forward().z >= 0.0


func _spawn(kind: String, point: Vector3) -> void:
	var script: Script = SCRIPTS[kind]
	var disaster = script.new()
	disaster.setup(player, game)
	add_child(disaster)
	disaster.connect("finished", _on_disaster_finished.bind(kind))
	_active_disasters[kind] = disaster
	_last_kind = kind
	_cooldowns[kind] = randf_range(9.0, 14.0)
	_pending = true
	var messages: Array = MESSAGES[kind]
	if game != null:
		game.emit_event(messages[randi() % messages.size()], 1)
		game.add_shake(0.12)
	disaster.call("telegraph", point)
	await get_tree().create_timer(TELEGRAPH).timeout
	_pending = false
	if is_instance_valid(disaster) and is_instance_valid(player):
		disaster.call("activate", point)


func _on_disaster_finished(kind: String) -> void:
	_active_disasters.erase(kind)
