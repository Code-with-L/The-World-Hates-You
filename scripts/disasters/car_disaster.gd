extends "res://scripts/disasters/disaster_base.gd"

const Fx := preload("res://scripts/fx.gd")

const SPEED := 16.0
# Matches the box body the pre-pass car used, so the collision footprint, the
# hurt volume and the player's reaction time are all unchanged. Only the way it
# looks is different now.
const BODY_SIZE := Vector3(1.9, 1.05, 3.9)
const START_OFFSET := 20.0
const LANE_HALF := 2.4
const REASONS := ["CRUSHED BY A CAR!", "A CAR HIT YOU!", "ROADKILL!"]

# One shell per event, picked at random so repeat car attacks do not look
# identical. [scale, body_length, y_offset, tris] mirrors car_kit() in
# tools/build_city.gd so the disaster car and the parked cars agree on size.
const KITS := {
	"car_taxi": [3.8, 3.6, -0.32, 548],
	"car_police": [3.8, 3.6, -0.32, 580],
	"car_stationwagon": [3.8, 3.6, -0.32, 523],
	"car_hatchback": [4.4, 3.4, -0.28, 498],
	"car_sedan": [3.8, 3.6, -0.32, 515],
}

var _car: AnimatableBody3D
var _light: MeshInstance3D
var _beam: MeshInstance3D
var _dust: CPUParticles3D
var _blink: Tween = null
var _dir := 1.0
var _lane_x := 0.0
var _hit := false
var _telegraph_nodes: Array = []


func _unit_cube() -> BoxMesh:
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.18, 0.18, 0.18)
	return mesh


func telegraph(point: Vector3) -> void:
	var ppos := player_pos()
	_lane_x = clampf(ppos.x, -4.6, 4.6)
	_dir = 1.0 if ppos.z <= 0.0 else -1.0
	_build()
	_car.global_position = Vector3(_lane_x, 0.62, ppos.z - _dir * START_OFFSET)

	# The telegraph: the player is about to be run over exactly here, and the car
	# is coming from this side. Band + arrow say where and which way, the callout
	# shouts, and the car's own lights blink at the player from 20m out.
	var ground := Vector3(_lane_x, ppos.y, ppos.z)
	var travel := Vector3(0.0, 0.0, _dir)
	_telegraph_nodes.append_array(make_hazard_band(ground, LANE_HALF * 2.0, travel, 7))
	_telegraph_nodes.append(make_danger_ring(1.9, WARN_RED, ground, 3))
	_telegraph_nodes.append(make_arrow(ground + travel * 1.7, travel, WARN_YELLOW, 0.9))
	_telegraph_nodes.append(make_callout("CAR!", ground + Vector3.UP * 1.9, WARN_CREAM, 0.009))

	# Blink the headlights at the player for the whole telegraph window. A finite
	# tween rather than set_loops(): an endless one logs "Infinite loop detected"
	# when activate() kills it, and 1.25s of telegraph is all that is needed.
	_blink = track(create_tween())
	for i in 6:
		_blink.tween_property(_light, "visible", false, 0.1)
		_blink.tween_property(_light, "visible", true, 0.1)
	sfx("car_warning", -4.0, 1.0)


func activate(_point: Vector3) -> void:
	active = true
	if _blink != null and _blink.is_valid():
		_blink.kill()
	_light.visible = true
	_beam.visible = true
	_dust.emitting = true
	fade_out(_telegraph_nodes)
	_telegraph_nodes.clear()
	# Horn + a short puff as it pulls away, so the car has a "launch" beat
	# instead of simply appearing at speed.
	Fx.burst(self, _car.global_position + Vector3(0.0, -0.2, 0.0),
		Color(0.85, 0.8, 0.7), 8, 2.6)
	sfx("car_horn", -6.0, 1.0)


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
	# Impact: debris + shockwave + a short hit stop, so the hit is unmistakable
	# without a heavy screen effect.
	shake(0.85)
	Fx.burst(self, _car.global_position, Color(1.0, 0.75, 0.2), 22, 6.5)
	Fx.shockwave(self, Vector3(_car.global_position.x, 0.0, _car.global_position.z),
		Color(1.0, 0.6, 0.1), 4.0)
	if game != null and game.has_method("hit_stop"):
		game.hit_stop(0.12)
	sfx("car_impact", 0.0, 1.0)


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

	# KayKit shell as the visible car, sized and lifted to match car_kit().
	var kinds: Array = KITS.keys()
	var kind: String = kinds[randi() % kinds.size()]
	var kit: Array = KITS[kind]
	var shell_scene := load_prop("res://assets/kaykit/city/Assets/gltf/%s.gltf" % kind)
	if shell_scene != null:
		var shell: Node3D = shell_scene.instantiate()
		shell.scale = Vector3.ONE * float(kit[0])
		shell.position = Vector3(0.0, float(kit[2]) - 0.30, 0.0)
		_disable_shadows(shell)
		_car.add_child(shell)
	else:
		_box_car()

	# A low warm wash on the tarmac in front of the car. Reads as "headlights"
	# from any angle and costs one unshaded disc, not a real light.
	_beam = make_box(Vector3(2.6, 0.02, 5.0), Color(1.0, 0.95, 0.7), 0.3, 0.0, 0.9)
	_beam.material_override = unshaded(Color(1.0, 0.95, 0.7), 0.0)
	_beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_beam.position = Vector3(0.0, -0.55, -BODY_SIZE.z * 0.5 - 2.2)
	_car.add_child(_beam)
	var bt := track(create_tween())
	bt.tween_property(_beam.material_override, "albedo_color:a", 0.28, 0.4)

	# Blinkers, the thing that actually tells the player a car is about to move.
	_light = make_box(Vector3(1.5, 0.28, 0.12), Color(1.0, 0.95, 0.5), 0.3, 0.0, 2.5)
	_light.material_override = unshaded(Color(1.0, 0.95, 0.5), 1.0)
	_light.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_light.position = Vector3(0, 0.1, -BODY_SIZE.z * 0.5)
	_car.add_child(_light)

	var tail := make_box(Vector3(1.5, 0.2, 0.1), Color(1.0, 0.15, 0.1), 0.3, 0.0, 2.0)
	tail.material_override = unshaded(Color(1.0, 0.15, 0.1), 1.0)
	tail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	tail.position = Vector3(0, 0.2, BODY_SIZE.z * 0.5)
	_car.add_child(tail)

	# Tyre dust: one persistent emitter riding the tail of the car rather than a
	# burst spawned per frame, so the running car costs a single extra node.
	_dust = CPUParticles3D.new()
	_dust.mesh = _unit_cube()
	_dust.material_override = unshaded(Color(0.72, 0.7, 0.67), 0.5)
	_dust.amount = 10
	_dust.lifetime = 0.6
	_dust.explosiveness = 0.0
	_dust.spread = 25.0
	_dust.initial_velocity_min = 0.4
	_dust.initial_velocity_max = 1.6
	_dust.gravity = Vector3(0.0, 0.6, 0.0)
	_dust.scale_amount_min = 0.5
	_dust.scale_amount_max = 1.3
	_dust.emitting = false
	_dust.position = Vector3(0.0, -0.5, BODY_SIZE.z * 0.5)
	_car.add_child(_dust)

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


# Fallback body used only if the KayKit pack is missing: same silhouette as the
# old box car so the disaster still works.
func _box_car() -> void:
	_car.add_child(make_box(BODY_SIZE, Color(0.75, 0.1, 0.12), 0.45, 0.25))
	var cabin := make_box(Vector3(1.6, 0.75, 1.9), Color(0.85, 0.2, 0.2), 0.4, 0.3)
	cabin.position = Vector3(0, 0.85, -0.1)
	_car.add_child(cabin)
	var glass := make_box(Vector3(1.5, 0.45, 1.7), Color(0.35, 0.55, 0.7), 0.15, 0.6)
	glass.position = Vector3(0, 0.95, -0.15)
	_car.add_child(glass)
	for side in [-1.0, 1.0]:
		for end in [-1.0, 1.0]:
			var wheel := make_box(Vector3(0.22, 0.62, 0.62), Color(0.09, 0.09, 0.1), 0.9)
			wheel.position = Vector3(side * 0.95, -0.35, end * 1.25)
			_car.add_child(wheel)


func _disable_shadows(node: Node) -> void:
	if node is GeometryInstance3D:
		(node as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for child in node.get_children():
		_disable_shadows(child)
