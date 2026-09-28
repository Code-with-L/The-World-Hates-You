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
var _legs: Array[Node3D] = []
var _tail: Node3D
var _callout: Label3D
var _spawn_ring: MeshInstance3D
var _dust_t := 0.0
var _hit := false


func telegraph(point: Vector3) -> void:
	_build()
	_dog.global_position = point + Vector3.UP * 0.1
	_face_player()
	# Squash-and-stretch pop so the dog "arrives" rather than blinking in.
	_model.scale = Vector3(1.0, 0.4, 1.0)
	var t := track(create_tween())
	t.tween_property(_model, "scale", Vector3.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	# Where it appeared. The dog is a small fast target, so without a ground mark
	# it can be missed entirely at a sprint; the ring is what makes the spawn
	# readable at a glance.
	_spawn_ring = make_danger_ring(1.4, WARN_YELLOW, _dog.global_position, 2)
	# A growl label right on the dog reads as "the dog is the threat" instantly.
	_add_callout()
	sfx("dog_bark", -4.0, 1.0)


func activate(_point: Vector3) -> void:
	active = true
	# The ring has done its job once the dog is moving; the WOOF label stays,
	# because it rides above the dog and keeps the threat readable while it closes.
	if _spawn_ring != null and is_instance_valid(_spawn_ring):
		var mat := _spawn_ring.material_override as StandardMaterial3D
		if mat != null:
			_spawn_ring.visible = false
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
	_animate_run()
	_dust(delta)

	if dist <= CATCH_DISTANCE and not _hit:
		_hit = true
		var reason: String = REASONS[randi() % REASONS.size()]
		hurt(1, _dog.global_position, reason, 5.0)
		shake(0.5)
		Fx.burst(self, _dog.global_position, Color(0.9, 0.5, 0.3), 12, 3.5)
		sfx("dog_bark", 0.0, 0.8)
		finish()
		return
	if lifetime > MAX_LIFETIME:
		finish()


func _process(delta: float) -> void:
	if active:
		lifetime += delta
		if _model != null and is_instance_valid(_model):
			# Side-to-side sway kept from the original, so the gait still reads.
			_model.rotation.z = sin(lifetime * 16.0) * 0.12
		# The bark label rides above the dog so it stays attached to the threat
		# rather than hanging where the dog spawned.
		if _callout != null and is_instance_valid(_callout) and is_instance_valid(_dog):
			_callout.global_position = _callout.global_position.lerp(
				_dog.global_position + Vector3.UP * 1.35, delta * 6.0)


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


# Diagonal leg swing and a tail wag. Four legs + tail is the cheapest way to make
# a box animal read as "running" instead of "sliding".
func _animate_run() -> void:
	var phase := lifetime * 18.0
	for i in _legs.size():
		var leg := _legs[i]
		if not is_instance_valid(leg):
			continue
		# Legs were appended front-then-back per side, so an even index is a front
		# leg. Front and back swing in antiphase, and the two sides are offset by
		# a further half cycle, which is what makes a trot read as a trot.
		var is_front := i % 2 == 0
		var side_half := PI if (i / 2) % 2 == 0 else 0.0
		leg.rotation.x = sin(phase + (0.0 if is_front else PI) + side_half) * 0.7
	if _tail != null and is_instance_valid(_tail):
		_tail.rotation.y = sin(phase * 0.5) * 0.5
		_tail.rotation.x = -0.5 + sin(phase * 0.5) * 0.2


# Small puffs kicked up behind the dog while it sprints, throttled so it stays
# cheap on mobile.
func _dust(delta: float) -> void:
	_dust_t -= delta
	if _dust_t > 0.0:
		return
	_dust_t = 0.16
	var p := _dog.global_position
	Fx.burst(self, Vector3(p.x, 0.15, p.z), Color(0.7, 0.62, 0.5), 2, 1.2)


func _add_callout() -> void:
	if not is_instance_valid(_dog):
		return
	_callout = make_label("WOOF", Color(1.0, 0.9, 0.3), 0.006)
	add_child(_callout)
	_callout.global_position = _dog.global_position + Vector3.UP * 1.35
	var t := track(create_tween())
	t.tween_property(_callout, "position:y", _callout.position.y + 0.2, 0.4)


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

	# A flat contact shadow so the dog is anchored to the ground rather than
	# floating; combined with the spawn ring it is findable at any distance.
	# Parented to the dog so it travels with it instead of being left behind.
	var contact := make_disc(0.55, Color(0.0, 0.0, 0.0), Vector3.ZERO, 0.32)
	contact.name = "Contact"
	_dog.add_child(contact)
	contact.position = Vector3(0.0, 0.02, 0.0)

	var fur := Color(0.55, 0.35, 0.18)
	var body := make_box(Vector3(0.36, 0.34, 0.72), fur, 0.85)
	body.position = Vector3(0, 0.5, 0)
	_model.add_child(body)

	var head := make_box(Vector3(0.32, 0.32, 0.36), fur, 0.85)
	head.position = Vector3(0, 0.64, -0.52)
	_model.add_child(head)

	var snout := make_box(Vector3(0.16, 0.14, 0.2), Color(0.25, 0.16, 0.1), 0.8)
	snout.position = Vector3(0, 0.56, -0.74)
	_model.add_child(snout)

	# Googly eyes: bigger white + dark pupil, so the dog has a face at a distance.
	var eyes := make_box(Vector3(0.3, 0.14, 0.06), Color(1, 1, 1), 0.4, 0.0, 0.6)
	eyes.position = Vector3(0, 0.72, -0.68)
	_model.add_child(eyes)
	var pupils := make_box(Vector3(0.16, 0.09, 0.05), Color(0.05, 0.05, 0.05), 0.3)
	pupils.position = Vector3(0, 0.72, -0.72)
	_model.add_child(pupils)

	# A red collar so the dog reads as a pet gone wrong, not a wild animal.
	var collar := make_box(Vector3(0.34, 0.07, 0.34), Color(0.8, 0.12, 0.12), 0.7)
	collar.position = Vector3(0, 0.52, -0.36)
	_model.add_child(collar)

	for side in [-0.13, 0.13]:
		var ear := make_box(Vector3(0.08, 0.18, 0.06), Color(0.3, 0.2, 0.12), 0.85)
		ear.position = Vector3(side, 0.82, -0.5)
		_model.add_child(ear)
		# Front and back legs pivot from the top so the swing reads as a stride.
		for front in [true, false]:
			var pivot := Node3D.new()
			pivot.position = Vector3(side * 1.5, 0.38, -0.26 if front else 0.26)
			_model.add_child(pivot)
			var leg := make_box(Vector3(0.11, 0.34, 0.11), fur, 0.85)
			leg.position = Vector3(0, -0.18, 0)
			pivot.add_child(leg)
			_legs.append(pivot)

	_tail = Node3D.new()
	_tail.position = Vector3(0, 0.58, 0.5)
	_model.add_child(_tail)
	var tail := make_box(Vector3(0.08, 0.08, 0.3), fur, 0.85)
	tail.position = Vector3(0, 0, 0.15)
	tail.rotation.x = -0.5
	_tail.add_child(tail)
