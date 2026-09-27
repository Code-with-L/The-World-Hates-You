extends "res://scripts/disasters/disaster_base.gd"

const Fx := preload("res://scripts/fx.gd")

const SPEED := 7.4
const ACCEL := 26.0
const GRAVITY := 24.0
const CATCH_DISTANCE := 1.2
const MAX_LIFETIME := 7.5
const REASONS := ["BITTEN BY A DOG!", "DOG ATTACK!", "RUFF JUSTICE!"]

var _dog: CharacterBody3D
var _model: Node3D
var _hit := false


func telegraph(point: Vector3) -> void:
	_build()
	_dog.global_position = point + Vector3.UP * 0.1
	_face_player()
	_model.scale = Vector3(1.0, 0.4, 1.0)
	var t := track(create_tween())
	t.tween_property(_model, "scale", Vector3.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func activate(_point: Vector3) -> void:
	active = true
	shake(0.12)


func _physics_process(delta: float) -> void:
	if _dog == null or not is_instance_valid(_dog):
		return
	if not _dog.is_on_floor():
		_dog.velocity.y -= GRAVITY * delta
	else:
		_dog.velocity.y = maxf(_dog.velocity.y, 0.0)
	if not active:
		_dog.velocity.x = move_toward(_dog.velocity.x, 0.0, 20.0 * delta)
		_dog.velocity.z = move_toward(_dog.velocity.z, 0.0, 20.0 * delta)
		_dog.move_and_slide()
		return

	var to_player := player_pos() - _dog.global_position
	to_player.y = 0.0
	var dist := to_player.length()
	if dist > 0.05:
		var dir := to_player / dist
		_dog.velocity.x = move_toward(_dog.velocity.x, dir.x * SPEED, ACCEL * delta)
		_dog.velocity.z = move_toward(_dog.velocity.z, dir.z * SPEED, ACCEL * delta)
		_face_player()
	_dog.move_and_slide()
	_bob()

	if dist <= CATCH_DISTANCE and not _hit:
		_hit = true
		var reason: String = REASONS[randi() % REASONS.size()]
		hurt(1, _dog.global_position, reason, 5.0)
		shake(0.5)
		Fx.burst(self, _dog.global_position, Color(0.9, 0.5, 0.3), 12, 3.5)
		finish()
		return
	if lifetime > MAX_LIFETIME:
		finish()


func _process(delta: float) -> void:
	if active:
		lifetime += delta
		if _model != null and is_instance_valid(_model):
			_model.rotation.z = sin(lifetime * 16.0) * 0.12


func _face_player() -> void:
	var target := player_pos()
	target.y = _dog.global_position.y
	if _dog.global_position.distance_squared_to(target) < 0.04:
		return
	_dog.look_at(target, Vector3.UP)


func _bob() -> void:
	if _model == null:
		return
	_model.position.y = 0.42 + absf(sin(lifetime * 14.0)) * 0.08


func _build() -> void:
	_dog = CharacterBody3D.new()
	_dog.collision_layer = 4
	_dog.collision_mask = 1
	_dog.floor_snap_length = 0.4
	add_child(_dog)

	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.34
	capsule.height = 0.9
	shape.shape = capsule
	shape.position = Vector3(0, 0.45, 0)
	_dog.add_child(shape)

	_model = Node3D.new()
	_dog.add_child(_model)

	var fur := Color(0.55, 0.35, 0.18)
	var body := make_box(Vector3(0.36, 0.34, 0.72), fur, 0.85)
	body.position = Vector3(0, 0.5, 0)
	_model.add_child(body)

	var head := make_box(Vector3(0.3, 0.3, 0.34), fur, 0.85)
	head.position = Vector3(0, 0.62, -0.5)
	_model.add_child(head)

	var snout := make_box(Vector3(0.16, 0.14, 0.2), Color(0.25, 0.16, 0.1), 0.8)
	snout.position = Vector3(0, 0.55, -0.72)
	_model.add_child(snout)

	var eyes := make_box(Vector3(0.26, 0.08, 0.05), Color(1, 1, 1), 0.4, 0.0, 0.6)
	eyes.position = Vector3(0, 0.7, -0.66)
	_model.add_child(eyes)

	for side in [-0.13, 0.13]:
		var ear := make_box(Vector3(0.08, 0.16, 0.06), Color(0.3, 0.2, 0.12), 0.85)
		ear.position = Vector3(side, 0.8, -0.48)
		_model.add_child(ear)
		var leg := make_box(Vector3(0.11, 0.34, 0.11), fur, 0.85)
		leg.position = Vector3(side * 1.5, 0.2, 0.26)
		_model.add_child(leg)
		var back_leg := make_box(Vector3(0.11, 0.34, 0.11), fur, 0.85)
		back_leg.position = Vector3(side * 1.5, 0.2, -0.26)
		_model.add_child(back_leg)

	var tail := make_box(Vector3(0.08, 0.08, 0.3), fur, 0.85)
	tail.position = Vector3(0, 0.58, 0.5)
	tail.rotation.x = -0.5
	_model.add_child(tail)
