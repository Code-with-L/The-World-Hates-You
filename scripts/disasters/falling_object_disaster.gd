extends "res://scripts/disasters/disaster_base.gd"

const Fx := preload("res://scripts/fx.gd")

const DROP_HEIGHT := 11.0
const REASONS := ["CRUSHED BY A PIANO!", "BONK!", "THE SKY HATED YOU!"]
# The impact footprint the marker and the hurt box both describe, so the circle
# the player is told to avoid is exactly the circle that can hit them.
const IMPACT_RADIUS := 1.5

var _target := Vector3.ZERO
var _marker: MeshInstance3D = null
var _shadow: MeshInstance3D = null
var _marker_tween: Tween = null
var _body: RigidBody3D = null
var _hit := false
var _telegraph_nodes: Array = []


func telegraph(point: Vector3) -> void:
	_target = point

	# The tell, in three layers: a red footprint on the ground saying "here", an
	# expanding ring saying "now", and a shouted LOOK OUT. A shrinking marker is
	# not enough on its own at running speed.
	_shadow = make_disc(IMPACT_RADIUS, WARN_RED, _target, 0.55)
	_telegraph_nodes.append(make_danger_ring(IMPACT_RADIUS, WARN_YELLOW, _target, 2))
	_telegraph_nodes.append(make_callout("LOOK OUT", _target + Vector3.UP * 2.2, WARN_CREAM, 0.008))

	# Keep the old spinning flat marker too: it survives at a glance even when the
	# player is looking at the sky, not the ground.
	_marker = make_marker(_target, 1.9, Color(1.0, 0.2, 0.15))
	_telegraph_nodes.append(_marker)
	_marker_tween = track(create_tween())
	_marker_tween.tween_property(_marker, "rotation:y", PI * 2.0, 1.25)
	sfx("fall_warning", -3.0, 1.0)


func activate(_point: Vector3) -> void:
	active = true
	if _marker_tween != null and _marker_tween.is_valid():
		_marker_tween.kill()
	# The callout and the old marker go; the shadow stays and becomes a live
	# tracker of the object as it falls, which is the honest way to telegraph it.
	if _marker != null and is_instance_valid(_marker):
		_marker.queue_free()
		_marker = null
	fade_out(_telegraph_nodes, 0.18)
	_spawn_object()
	shake(0.18)


func _process(delta: float) -> void:
	if not active:
		return
	lifetime += delta
	if _body == null or not is_instance_valid(_body):
		finish()
		return
	_track_shadow()
	if _body.global_position.y < -6.0 or lifetime > 5.0:
		finish()


# Shadow grows and darkens as the object approaches, so the player can judge the
# drop by watching the ground rather than by looking up and losing the target.
func _track_shadow() -> void:
	if _shadow == null or not is_instance_valid(_shadow):
		return
	var h := maxf(_body.global_position.y - _target.y, 0.35)
	var k := clampf(1.0 - (h / DROP_HEIGHT), 0.0, 1.0)
	var scale_factor := 0.45 + k * 0.9
	_shadow.scale = Vector3(scale_factor, 1.0, scale_factor)
	var mat := _shadow.material_override as StandardMaterial3D
	if mat != null:
		mat.albedo_color.a = 0.2 + k * 0.55


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
	# Impact lands on the ground, not mid-air, and the ground crack reads as the
	# spot the object hit even after the body has gone.
	Fx.burst(self, _target + Vector3.UP * 0.4, Color(0.9, 0.85, 0.8), 20, 5.5)
	Fx.shockwave(self, _target, Color(1.0, 0.85, 0.4), 3.4)
	Fx.burst(self, _target + Vector3.UP * 0.2, Color(0.6, 0.55, 0.5), 14, 3.4)
	if game != null and game.has_method("hit_stop"):
		game.hit_stop(0.08)
	sfx("fall_impact", -1.0, 1.0)
	# Land a brief scorch decal at the impact point, then clean up after it.
	var scorch := make_disc(1.1, Color(0.2, 0.18, 0.16), _target, 0.6)
	var st := track(create_tween())
	st.tween_interval(1.6)
	st.tween_property(scorch.material_override, "albedo_color:a", 0.0, 0.5)
	st.tween_callback(Callable(scorch, "queue_free"))
	finish_after(2.2)
