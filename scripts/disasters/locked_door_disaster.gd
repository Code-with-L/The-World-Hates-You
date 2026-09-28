extends "res://scripts/disasters/disaster_base.gd"

const Fx := preload("res://scripts/fx.gd")

const DURATION := 6.5
const WIDTH := 3.4
const HEIGHT := 2.4
const THICK := 0.3

var _barrier: StaticBody3D
var _opened := false
var _label: Label3D
var _glow: MeshInstance3D
var _flash := 0.0
var _nagged := false


func telegraph(point: Vector3) -> void:
	_build(point)


func activate(_point: Vector3) -> void:
	active = true
	shake(0.2)
	sfx("door_locked", -3.0, 1.0)


func _process(delta: float) -> void:
	if not active:
		return
	lifetime += delta
	# Flash the barrier so it reads as "blocked right now" rather than as scenery
	# the player has already learned to walk around.
	_flash += delta * 6.0
	if _glow != null and is_instance_valid(_glow):
		var mat := _glow.material_override as StandardMaterial3D
		if mat != null:
			mat.emission_energy_multiplier = 0.5 + 0.5 * (0.5 + 0.5 * sin(_flash))
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
	sfx("door_open", -6.0, 1.0)
	var t := track(create_tween())
	t.set_parallel(true)
	# The barrier drops away and tips over, which reads as "the world relented"
	# rather than the block silently blinking out of existence.
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

	# Panel, with an emissive core so the flashing reads from across the street.
	_glow = make_box(Vector3(WIDTH, HEIGHT, THICK), WARN_RED, 0.7, 0.0, 0.5)
	_barrier.add_child(_glow)

	for i in 4:
		var stripe := make_box(Vector3(0.34, HEIGHT * 1.02, THICK + 0.06), Color(0.95, 0.95, 0.9), 0.6)
		stripe.position = Vector3(-WIDTH * 0.5 + 0.42 + i * 0.85, 0, 0)
		stripe.rotation.z = 0.5
		_barrier.add_child(stripe)

	# A real padlock on the front face: the single clearest "this is shut" shape
	# there is, and it needs four boxes.
	var body_y := 0.62
	var lock := make_box(Vector3(0.78, 0.62, 0.2), Color(0.16, 0.16, 0.2), 0.35, 0.75)
	lock.position = Vector3(0.0, body_y, -THICK * 0.5 - 0.12)
	_barrier.add_child(lock)
	var shackle_l := make_box(Vector3(0.12, 0.46, 0.14), Color(0.22, 0.22, 0.26), 0.3, 0.75)
	shackle_l.position = Vector3(-0.19, body_y + 0.5, -THICK * 0.5 - 0.1)
	_barrier.add_child(shackle_l)
	var shackle_r := make_box(Vector3(0.12, 0.46, 0.14), Color(0.22, 0.22, 0.26), 0.3, 0.75)
	shackle_r.position = Vector3(0.19, body_y + 0.5, -THICK * 0.5 - 0.1)
	_barrier.add_child(shackle_r)
	var shackle_top := make_box(Vector3(0.5, 0.12, 0.14), Color(0.22, 0.22, 0.26), 0.3, 0.75)
	shackle_top.position = Vector3(0.0, body_y + 0.72, -THICK * 0.5 - 0.1)
	_barrier.add_child(shackle_top)
	var keyhole := make_box(Vector3(0.12, 0.2, 0.06), Color(0.02, 0.02, 0.03), 0.4)
	keyhole.position = Vector3(0.0, body_y - 0.04, -THICK * 0.5 - 0.24)
	_barrier.add_child(keyhole)

	_label = make_label("LOCKED!", WARN_CREAM, 0.008)
	_label.position = Vector3(0, -0.28, -THICK * 0.5 - 0.05)
	_barrier.add_child(_label)

	var hint := make_label("GO AROUND", Color(1, 1, 1), 0.005)
	hint.position = Vector3(0, -0.75, -THICK * 0.5 - 0.05)
	_barrier.add_child(hint)

	# Drop it in with a bounce, then leave it wobbling slightly: the arrival is
	# the warning, so it happens during the telegraph window, before activate().
	# The wobble stops once the block is live, otherwise it fights the drop-in
	# tween for position:y and the barrier jitters where it stands.
	var t := track(create_tween())
	t.tween_property(_barrier, "position:y", point.y + HEIGHT * 0.5, 0.32).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)

	var shake_tween := track(create_tween())
	shake_tween.tween_property(_barrier, "rotation:z", 0.05, 0.08)
	shake_tween.tween_property(_barrier, "rotation:z", -0.05, 0.08)
	shake_tween.tween_property(_barrier, "rotation:z", 0.0, 0.08)

	# Bumping into the shut door is the feedback that matters: the player learns
	# the route is closed from the world, not from a tutorial. Fires once, and
	# never damages anything.
	var bump := Area3D.new()
	bump.collision_layer = 0
	bump.collision_mask = 2
	bump.monitoring = true
	var bump_shape := CollisionShape3D.new()
	var bump_form := BoxShape3D.new()
	bump_form.size = Vector3(WIDTH * 1.3, HEIGHT * 1.3, THICK + 1.0)
	bump_shape.shape = bump_form
	bump.add_child(bump_shape)
	bump.body_entered.connect(_on_bumped)
	_barrier.add_child(bump)


# One-shot nudge when the player runs into the barrier. No damage, no knockback:
# the block still works exactly as it did, it just explains itself.
func _on_bumped(body: Node3D) -> void:
	if _nagged or body != player or _opened:
		return
	_nagged = true
	shake(0.18)
	if game != null:
		game.emit_event("NOT THIS WAY!", 1)
	sfx("door_locked", -6.0, 0.75)
