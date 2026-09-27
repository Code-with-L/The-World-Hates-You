extends "res://scripts/disasters/disaster_base.gd"

const Fx := preload("res://scripts/fx.gd")

const DROP_HEIGHT := 11.0
const REASONS := ["CRUSHED BY A PIANO!", "BONK!", "THE SKY HATED YOU!"]

var _target := Vector3.ZERO
var _marker: MeshInstance3D = null
var _marker_tween: Tween = null
var _body: RigidBody3D = null
var _hit := false


func telegraph(point: Vector3) -> void:
	_target = point
	_marker = make_marker(_target, 1.9, Color(1.0, 0.2, 0.15))
	_marker_tween = track(create_tween())
	_marker_tween.tween_property(_marker, "rotation:y", PI * 2.0, 1.25)


func activate(_point: Vector3) -> void:
	active = true
	if _marker_tween != null and _marker_tween.is_valid():
		_marker_tween.kill()
	if _marker != null and is_instance_valid(_marker):
		_marker.queue_free()
		_marker = null
	_spawn_object()
	shake(0.18)


func _process(delta: float) -> void:
	if not active:
		return
	lifetime += delta
	if _body == null or not is_instance_valid(_body):
		finish()
		return
	if _body.global_position.y < -6.0 or lifetime > 5.0:
		finish()


func _spawn_object() -> void:
	_body = RigidBody3D.new()
	_body.mass = 40.0
	_body.gravity_scale = 1.4
	_body.continuous_cd = true
	_body.contact_monitor = true
	_body.max_contacts_reported = 4
	_body.collision_layer = 1
	_body.collision_mask = 1
	_body.body_entered.connect(_on_body_entered)
	add_child(_body)

	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.15, 1.15, 1.15)
	shape.shape = box
	_body.add_child(shape)

	var hurt_box := Area3D.new()
	hurt_box.collision_layer = 4
	hurt_box.collision_mask = 2
	hurt_box.monitoring = true
	var hurt_shape := CollisionShape3D.new()
	var hurt_form := BoxShape3D.new()
	hurt_form.size = Vector3(1.5, 1.5, 1.5)
	hurt_shape.shape = hurt_form
	hurt_box.add_child(hurt_shape)
	hurt_box.body_entered.connect(_on_hurt)
	_body.add_child(hurt_box)

	var body_mesh := make_box(Vector3(1.15, 1.15, 1.15), Color(0.15, 0.15, 0.18), 0.6, 0.1)
	_body.add_child(body_mesh)

	var trim := make_box(Vector3(1.22, 0.16, 1.22), Color(0.85, 0.2, 0.15), 0.5, 0.2)
	_body.add_child(trim)

	_body.global_position = _target + Vector3.UP * DROP_HEIGHT
	_body.rotation = Vector3(randf_range(-0.6, 0.6), randf_range(0.0, PI), randf_range(-0.6, 0.6))
	_body.angular_velocity = Vector3(randf_range(-2.0, 2.0), randf_range(-2.0, 2.0), randf_range(-2.0, 2.0))


func _on_body_entered(body: Node3D) -> void:
	if body != player:
		if _body != null and is_instance_valid(_body):
			_body.queue_free()
			_body = null
		finish()
		return
	if _hit:
		return
	_on_hurt(body)


func _on_hurt(body: Node3D) -> void:
	if _hit or body != player:
		return
	_hit = true
	var reason: String = REASONS[randi() % REASONS.size()]
	hurt(1, _target, reason, 7.0)
	shake(0.7)
	Fx.burst(self, _target + Vector3.UP * 0.4, Color(0.9, 0.85, 0.8), 20, 5.5)
	Fx.shockwave(self, _target, Color(1.0, 0.85, 0.4), 3.4)
	finish_after(2.2)
