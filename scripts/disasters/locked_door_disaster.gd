extends "res://scripts/disasters/disaster_base.gd"

const Fx := preload("res://scripts/fx.gd")

const DURATION := 6.5
const WIDTH := 3.4
const HEIGHT := 2.4
const THICK := 0.3

var _barrier: StaticBody3D
var _opened := false
var _label: Label3D


func telegraph(point: Vector3) -> void:
	_build(point)


func activate(_point: Vector3) -> void:
	active = true
	shake(0.2)


func _process(delta: float) -> void:
	if not active:
		return
	lifetime += delta
	if lifetime > DURATION and not _opened:
		_opened = true
		_open()


func _open() -> void:
	if _barrier == null or not is_instance_valid(_barrier):
		finish()
		return
	_barrier.collision_layer = 0
	_barrier.collision_mask = 0
	shake(0.15)
	Fx.burst(self, _barrier.global_position + Vector3.UP * 0.4, Color(0.7, 0.75, 0.8), 10, 3.0)
	var t := track(create_tween())
	t.set_parallel(true)
	t.tween_property(_barrier, "position:y", _barrier.position.y - 3.0, 0.5).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_IN)
	t.tween_property(_barrier, "rotation:x", 0.5, 0.5)
	finish_after(0.55)


func _build(point: Vector3) -> void:
	_barrier = StaticBody3D.new()
	_barrier.collision_layer = 1
	_barrier.collision_mask = 1
	add_child(_barrier)
	_barrier.global_position = Vector3(point.x, point.y + HEIGHT * 0.5 + 0.6, point.z)

	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(WIDTH, HEIGHT, THICK)
	shape.shape = box
	_barrier.add_child(shape)

	_barrier.add_child(make_box(Vector3(WIDTH, HEIGHT, THICK), Color(0.8, 0.12, 0.12), 0.7))
	for i in 4:
		var stripe := make_box(Vector3(0.34, HEIGHT * 1.02, THICK + 0.06), Color(0.95, 0.95, 0.9), 0.6)
		stripe.position = Vector3(-WIDTH * 0.5 + 0.42 + i * 0.85, 0, 0)
		stripe.rotation.z = 0.5
		_barrier.add_child(stripe)

	_label = make_label("LOCKED!", Color(1.0, 0.95, 0.6), 0.008)
	_label.position = Vector3(0, 0.35, -THICK * 0.5 - 0.05)
	_barrier.add_child(_label)

	var hint := make_label("GO AROUND", Color(1, 1, 1), 0.005)
	hint.position = Vector3(0, -0.75, -THICK * 0.5 - 0.05)
	_barrier.add_child(hint)

	var t := track(create_tween())
	t.tween_property(_barrier, "position:y", point.y + HEIGHT * 0.5, 0.32).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)

	var shake_tween := track(create_tween())
	shake_tween.tween_property(_barrier, "rotation:z", 0.05, 0.08)
	shake_tween.tween_property(_barrier, "rotation:z", -0.05, 0.08)
	shake_tween.tween_property(_barrier, "rotation:z", 0.0, 0.08)
