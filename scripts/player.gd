extends CharacterBody3D

signal health_changed(hp: int, max_hp: int)
signal hit_taken(world_pos: Vector3, reason: String)
signal died(reason: String)

const WALK_SPEED := 5.4
const SPRINT_SPEED := 8.6
const ACCEL := 15.0
const AIR_ACCEL := 6.0
const FRICTION := 18.0
const GRAVITY := 24.0
const JUMP_VELOCITY := 7.4
const MAX_HP := 3
const COYOTE_TIME := 0.12
const JUMP_BUFFER := 0.14
const HIT_IFRAMES := 1.25
const TURN_SPEED := 12.0

var camera_rig: Node3D = null
var alive := true
var hp := MAX_HP
var input_enabled := true

var _touch_move := Vector2.ZERO
var _touch_sprint := false
var _coyote := 0.0
var _jump_buffer := 0.0
var _iframes := 0.0
var _control_lock := 0.0
var _facing := 0.0
var _blink := 0.0
var _was_on_floor := true
var _limb_phase := 0.0
var _limb_amp := 0.0

@onready var model: Node3D = $Model
@onready var shadow: MeshInstance3D = $Shadow
@onready var _arm_l: Node3D = $Model/ArmL
@onready var _arm_r: Node3D = $Model/ArmR
@onready var _leg_l: Node3D = $Model/LegL
@onready var _leg_r: Node3D = $Model/LegR

var _shadow_mat: StandardMaterial3D = null
var _body_mat: StandardMaterial3D = null


func _ready() -> void:
	collision_layer = 2
	collision_mask = 1
	floor_snap_length = 0.4
	_facing = rotation.y
	_shadow_mat = StandardMaterial3D.new()
	_shadow_mat.albedo_color = Color(0, 0, 0, 0.35)
	_shadow_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_shadow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_shadow_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	shadow.material_override = _shadow_mat
	var body := $Model/Body as MeshInstance3D
	if body != null and body.mesh != null:
		_body_mat = body.mesh.surface_get_material(0) as StandardMaterial3D
	health_changed.emit(hp, MAX_HP)


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
		_coyote = maxf(0.0, _coyote - delta)
	else:
		_coyote = COYOTE_TIME
		_jump_buffer = maxf(0.0, _jump_buffer - delta)
	_iframes = maxf(0.0, _iframes - delta)
	_control_lock = maxf(0.0, _control_lock - delta)

	var wish := _gather_input()
	var on_floor := is_on_floor()

	if alive and input_enabled and _control_lock <= 0.0 and wish.length() > 0.05:
		var basis := _move_basis()
		var dir := (basis.x * wish.x - basis.z * wish.y)
		dir.y = 0.0
		if dir.length() > 0.001:
			dir = dir.normalized()
			var speed := SPRINT_SPEED if _is_sprinting() else WALK_SPEED
			var rate := ACCEL if on_floor else AIR_ACCEL
			var target := dir * speed * wish.length()
			velocity.x = move_toward(velocity.x, target.x, rate * delta)
			velocity.z = move_toward(velocity.z, target.z, rate * delta)
			_facing = lerp_angle(_facing, atan2(-dir.x, -dir.z), clampf(TURN_SPEED * delta, 0.0, 1.0))
	elif on_floor:
		var friction := FRICTION * delta
		velocity.x = move_toward(velocity.x, 0.0, friction)
		velocity.z = move_toward(velocity.z, 0.0, friction)

	if alive and input_enabled and _jump_buffer > 0.0 and _coyote > 0.0:
		velocity.y = JUMP_VELOCITY
		_jump_buffer = 0.0
		_coyote = 0.0
		_squash(Vector2(0.8, 1.25), 0.18)

	rotation.y = _facing
	move_and_slide()

	if not alive:
		return

	if is_on_floor() and not _was_on_floor:
		_squash(Vector2(1.3, 0.72), 0.16)
	_was_on_floor = is_on_floor()

	if global_position.y < -12.0:
		global_position = Vector3(0.0, 2.0, -16.0)
		velocity = Vector3.ZERO

	_update_blink(delta)
	_update_limbs(delta)


func _process(_delta: float) -> void:
	if shadow == null:
		return
	var ground := 0.16 if absf(global_position.x) > 4.0 else 0.0
	var height := maxf(global_position.y - ground, 0.0)
	shadow.visible = height < 6.0
	shadow.position.y = ground + 0.03 - global_position.y
	var s := clampf(1.0 - height * 0.12, 0.45, 1.0)
	shadow.scale = Vector3(s, 1.0, s)
	_shadow_mat.albedo_color.a = clampf(0.4 - height * 0.06, 0.08, 0.4)


func _gather_input() -> Vector2:
	if not input_enabled or _control_lock > 0.0:
		return Vector2.ZERO
	if _touch_move.length() > 0.05:
		return _touch_move.limit_length(1.0)
	if not InputMap.has_action("move_left"):
		return Vector2.ZERO
	return Input.get_vector("move_left", "move_right", "move_forward", "move_back").limit_length(1.0)


func _is_sprinting() -> bool:
	if _touch_sprint:
		return true
	return InputMap.has_action("sprint") and Input.is_action_pressed("sprint")


func _move_basis() -> Basis:
	if camera_rig != null and is_instance_valid(camera_rig):
		var b := camera_rig.global_transform.basis
		var forward := -b.z
		forward.y = 0.0
		if forward.length() < 0.001:
			forward = Vector3.FORWARD
		forward = forward.normalized()
		return Basis(forward.cross(Vector3.UP), Vector3.UP, forward)
	return Basis(Vector3.RIGHT, Vector3.UP, Vector3.FORWARD)


func request_jump() -> void:
	_jump_buffer = JUMP_BUFFER


func set_touch_input(move: Vector2, sprint: bool) -> void:
	_touch_move = move
	_touch_sprint = sprint


func take_damage(amount: int, from: Vector3, reason: String, power := 6.0) -> void:
	if not alive or _iframes > 0.0 or not input_enabled:
		return
	hp -= amount
	_iframes = HIT_IFRAMES
	_control_lock = 0.22
	var away := global_position - from
	away.y = 0.0
	if away.length() < 0.01:
		away = Vector3.FORWARD
	away = away.normalized()
	velocity.x = away.x * power
	velocity.z = away.z * power
	velocity.y = maxf(velocity.y, 4.0)
	health_changed.emit(hp, MAX_HP)
	hit_taken.emit(global_position, reason)
	if hp <= 0:
		_die(reason)


func force_death(reason: String) -> void:
	_die(reason)


func celebrate() -> void:
	input_enabled = false
	velocity = Vector3.ZERO
	var t := create_tween().set_parallel(true)
	t.tween_property(model, "position:y", 0.35, 0.18).set_trans(Tween.TRANS_BACK)
	t.chain().tween_property(model, "position:y", 0.0, 0.22)


func _die(reason: String) -> void:
	if not alive:
		return
	alive = false
	input_enabled = false
	velocity = Vector3.ZERO
	var t := create_tween()
	t.tween_property(self, "rotation:z", PI * 0.5, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if _body_mat != null:
		t.parallel().tween_property(_body_mat, "albedo_color", Color(1.0, 0.4, 0.4), 0.3)
	died.emit(reason)


func _squash(to: Vector2, time: float) -> void:
	if model == null:
		return
	model.scale = Vector3(to.x, to.y, 1.0)
	var t := create_tween()
	t.tween_property(model, "scale", Vector3.ONE, time).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _update_blink(delta: float) -> void:
	if model == null:
		return
	if _iframes > 0.0:
		_blink += delta * 22.0
		model.visible = fmod(_blink, 1.0) > 0.45
	else:
		_blink = 0.0
		model.visible = true


func _update_limbs(delta: float) -> void:
	if _arm_l == null or _arm_r == null or _leg_l == null or _leg_r == null:
		return
	var planar := Vector2(velocity.x, velocity.z).length()
	if alive and is_on_floor():
		var want := clampf(planar / SPRINT_SPEED, 0.0, 1.0)
		_limb_amp = lerpf(_limb_amp, want, clampf(delta * 12.0, 0.0, 1.0))
		_limb_phase += delta * lerpf(7.0, 15.0, _limb_amp)
	else:
		_limb_amp = lerpf(_limb_amp, 0.0, clampf(delta * 9.0, 0.0, 1.0))
		_limb_phase += delta * 2.0
	var swing := sin(_limb_phase) * _limb_amp
	var air := 0.0 if is_on_floor() else 0.35
	_arm_l.rotation.x = lerpf(_arm_l.rotation.x, swing * 0.95 - air, clampf(delta * 18.0, 0.0, 1.0))
	_arm_r.rotation.x = lerpf(_arm_r.rotation.x, -swing * 0.95 - air, clampf(delta * 18.0, 0.0, 1.0))
	_leg_l.rotation.x = lerpf(_leg_l.rotation.x, -swing * 0.85, clampf(delta * 18.0, 0.0, 1.0))
	_leg_r.rotation.x = lerpf(_leg_r.rotation.x, swing * 0.85, clampf(delta * 18.0, 0.0, 1.0))
	model.rotation.z = swing * 0.05
