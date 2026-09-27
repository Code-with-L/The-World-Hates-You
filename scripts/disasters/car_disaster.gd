extends "res://scripts/disasters/disaster_base.gd"

const Fx := preload("res://scripts/fx.gd")

const SPEED := 16.0
const BODY_SIZE := Vector3(1.9, 1.05, 3.9)
const REASONS := ["CRUSHED BY A CAR!", "A CAR HIT YOU!", "ROADKILL!"]

var _car: AnimatableBody3D
var _light: MeshInstance3D
var _blink: Tween = null
var _dir := 1.0
var _lane_x := 0.0
var _hit := false


func telegraph(point: Vector3) -> void:
	var ppos := player_pos()
	_lane_x = clampf(ppos.x, -4.6, 4.6)
	_dir = 1.0 if ppos.z <= 0.0 else -1.0
	_build()
	_car.global_position = Vector3(_lane_x, 0.62, ppos.z - _dir * 20.0)
	_blink = track(create_tween().set_loops())
	_blink.tween_property(_light, "visible", false, 0.12)
	_blink.tween_property(_light, "visible", true, 0.12)


func activate(_point: Vector3) -> void:
	active = true
	if _blink != null and _blink.is_valid():
		_blink.kill()
	_light.visible = true


func _physics_process(delta: float) -> void:
	if not active:
		return
	lifetime += delta
	_car.global_position.z += _dir * SPEED * delta
	if lifetime > 3.2 or absf(_car.global_position.z - player_pos().z) > 24.0:
		finish()


func _on_hurt(body: Node3D) -> void:
	if _hit or body != player:
		return
	_hit = true
	var reason: String = REASONS[randi() % REASONS.size()]
	hurt(2, _car.global_position, reason, 9.0)
	shake(0.85)
	Fx.burst(self, _car.global_position, Color(1.0, 0.75, 0.2), 22, 6.5)
	Fx.shockwave(self, Vector3(_car.global_position.x, 0.0, _car.global_position.z), Color(1.0, 0.6, 0.1), 4.0)


func _build() -> void:
	_car = AnimatableBody3D.new()
	_car.sync_to_physics = false
	_car.collision_layer = 8
	_car.collision_mask = 0
	add_child(_car)

	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = BODY_SIZE
	shape.shape = box
	_car.add_child(shape)

	_car.add_child(make_box(BODY_SIZE, Color(0.75, 0.1, 0.12), 0.45, 0.25))

	var cabin := make_box(Vector3(1.6, 0.75, 1.9), Color(0.85, 0.2, 0.2), 0.4, 0.3)
	cabin.position = Vector3(0, 0.85, -0.1)
	_car.add_child(cabin)

	var glass := make_box(Vector3(1.5, 0.45, 1.7), Color(0.35, 0.55, 0.7), 0.15, 0.6)
	glass.position = Vector3(0, 0.95, -0.15)
	_car.add_child(glass)

	_light = make_box(Vector3(1.5, 0.28, 0.12), Color(1.0, 0.95, 0.5), 0.3, 0.0, 2.5)
	_light.position = Vector3(0, 0.1, -BODY_SIZE.z * 0.5)
	_car.add_child(_light)

	var tail := make_box(Vector3(1.5, 0.2, 0.1), Color(1.0, 0.15, 0.1), 0.3, 0.0, 2.0)
	tail.position = Vector3(0, 0.2, BODY_SIZE.z * 0.5)
	_car.add_child(tail)

	for side in [-1.0, 1.0]:
		for end in [-1.0, 1.0]:
			var wheel := make_box(Vector3(0.22, 0.62, 0.62), Color(0.09, 0.09, 0.1), 0.9)
			wheel.position = Vector3(side * 0.95, -0.35, end * 1.25)
			_car.add_child(wheel)

	var hurt_box := Area3D.new()
	hurt_box.collision_layer = 4
	hurt_box.collision_mask = 2
	hurt_box.monitoring = true
	var hurt_shape := CollisionShape3D.new()
	var hurt_form := BoxShape3D.new()
	hurt_form.size = Vector3(2.4, 2.0, 4.4)
	hurt_shape.shape = hurt_form
	hurt_box.add_child(hurt_shape)
	hurt_box.body_entered.connect(_on_hurt)
	_car.add_child(hurt_box)
