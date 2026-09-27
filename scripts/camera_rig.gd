extends Node3D

const TRAUMA_DECAY := 2.0
const SHAKE_OFFSET := 0.26
const SHAKE_ROLL := 0.035
const SHAKE_SMOOTH := 16.0
const SHAKE_STEP := 0.05
const LOOK_SPEED := 0.0032
const MIN_ZOOM := 4.2
const MAX_ZOOM := 10.5

@export var follow_distance := 7.0
@export var follow_height := 1.62
@export var follow_speed := 9.5
@export var shoulder_offset := 0.45
@export var min_pitch := -0.62
@export var max_pitch := 0.34
@export var max_follow_gap := 11.0
@export var min_camera_height := 0.55
@export var look_enabled := true

var target: Node3D = null
var yaw := PI
var pitch := -0.34
var trauma := 0.0

var _shake_seed := Vector2.ZERO
var _shake_next := Vector2.ZERO
var _shake_next_roll := 0.0
var _shake_step := 0.0

@onready var spring: SpringArm3D = $SpringArm3D
@onready var camera: Camera3D = $SpringArm3D/Camera3D


func _ready() -> void:
	camera.current = true
	var probe := SphereShape3D.new()
	probe.radius = 0.28
	spring.shape = probe
	spring.spring_length = follow_distance
	spring.collision_mask = 1
	spring.margin = 0.5
	camera.fov = 64.0
	camera.near = 0.08
	camera.far = 75.0
	_pick_shake_targets()


func _process(delta: float) -> void:
	rotation = Vector3(pitch, yaw, 0.0)
	_update_shake(delta)
	_follow(delta)
	_clamp_camera()


func _follow(delta: float) -> void:
	if not is_instance_valid(target):
		return
	var desired := target.global_position + Vector3.UP * follow_height
	desired += global_transform.basis.x * shoulder_offset
	var offset := global_position - target.global_position
	offset.y = 0.0
	if offset.length() > max_follow_gap:
		global_position = desired
		return
	global_position = global_position.lerp(desired, clampf(follow_speed * delta, 0.0, 1.0))


func _clamp_camera() -> void:
	if camera.global_position.y < min_camera_height:
		camera.global_position.y = min_camera_height


func _unhandled_input(event: InputEvent) -> void:
	if not look_enabled:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		add_look((event as InputEventMouseMotion).relative * LOOK_SPEED)
	elif event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		if (event as InputEventMouseButton).button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom(-0.5)
		elif (event as InputEventMouseButton).button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom(0.5)


func _zoom(amount: float) -> void:
	follow_distance = clampf(follow_distance + amount, MIN_ZOOM, MAX_ZOOM)
	spring.spring_length = follow_distance


func add_look(relative: Vector2) -> void:
	yaw -= relative.x
	pitch = clampf(pitch - relative.y, min_pitch, max_pitch)


func add_trauma(amount: float) -> void:
	trauma = clampf(trauma + amount, 0.0, 1.0)


func snap_to_target() -> void:
	if is_instance_valid(target):
		rotation = Vector3(pitch, yaw, 0.0)
		global_position = target.global_position + Vector3.UP * follow_height
		global_position += global_transform.basis.x * shoulder_offset


func _update_shake(delta: float) -> void:
	if trauma <= 0.0:
		trauma = 0.0
		var calm := clampf(delta * 8.0, 0.0, 1.0)
		_shake_seed = _shake_seed.lerp(Vector2.ZERO, calm)
		camera.h_offset = _shake_seed.x * SHAKE_OFFSET
		camera.v_offset = _shake_seed.y * SHAKE_OFFSET
		camera.rotation.z = lerpf(camera.rotation.z, 0.0, calm)
		return
	trauma = maxf(0.0, trauma - delta * TRAUMA_DECAY)
	var s := trauma * trauma
	_shake_step += delta
	if _shake_step >= SHAKE_STEP:
		_shake_step = 0.0
		_pick_shake_targets()
	var weight := clampf(delta * SHAKE_SMOOTH, 0.0, 1.0)
	_shake_seed = _shake_seed.lerp(_shake_next * s, weight)
	camera.h_offset = _shake_seed.x * SHAKE_OFFSET
	camera.v_offset = _shake_seed.y * SHAKE_OFFSET
	camera.rotation.z = lerpf(camera.rotation.z, _shake_next_roll * s * SHAKE_ROLL, weight)


func _pick_shake_targets() -> void:
	_shake_next = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0))
	_shake_next_roll = randf_range(-1.0, 1.0)
