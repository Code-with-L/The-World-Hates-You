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

# Rig animation names available on the KayKit character.
const ANIM_IDLE := "Idle"
const ANIM_WALK := "Walking_A"
const ANIM_RUN := "Running_A"
const ANIM_AIR := "Jump_Idle"
const ANIM_LAND := "Jump_Land"
const ANIM_CHEER := "Cheer"
const ANIM_DEATH := "Death_A"
const ANIM_LAND_LEN := 0.25
# Weapon meshes parented to the hand bone slots; the courier delivers, it does not fight.
const RIG_WEAPONS := ["1H_Crossbow", "2H_Crossbow", "Knife", "Knife_Offhand", "Throwable"]
# Locomotion clips ship with loop disabled, so they are switched on at load.
const ANIM_LOOPS := [ANIM_IDLE, ANIM_WALK, "Walking_B", "Walking_C", ANIM_RUN, "Running_B",
	"Jump_Idle", ANIM_AIR]

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
var _anim_name := ""
var _land_t := 0.0
var _one_shot := ""

@onready var model: Node3D = $Model
@onready var shadow: MeshInstance3D = $Shadow
@onready var _anim: AnimationPlayer = _find_anim()
@onready var _death_mat: StandardMaterial3D = _make_death_mat()

var _shadow_mat: StandardMaterial3D = null


func _find_anim() -> AnimationPlayer:
	for c in model.find_children("*", "AnimationPlayer", true, false):
		return c as AnimationPlayer
	return null


func _make_death_mat() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(1.0, 0.35, 0.32)
	return m


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
	for n in model.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if mi != null and RIG_WEAPONS.has(String(mi.name)):
			mi.visible = false
	for n in ANIM_LOOPS:
		var a: Animation = _anim.get_animation(n) if _anim != null else null
		if a != null:
			a.loop_mode = Animation.LOOP_LINEAR
	_play(ANIM_IDLE)
	health_changed.emit(hp, MAX_HP)


func _play(name: String) -> void:
	if _anim == null or name == _anim_name:
		return
	if not _anim.has_animation(name):
		return
	_anim_name = name
	_anim.play(name)
	_anim.advance(0.0)


func _play_once(name: String) -> void:
	_play(name)
	_one_shot = name



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
		_land_t = ANIM_LAND_LEN
	_was_on_floor = is_on_floor()

	if global_position.y < -12.0:
		global_position = Vector3(0.0, 2.0, -16.0)
		velocity = Vector3.ZERO

	_update_blink(delta)
	_update_anim(delta)


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
	_play_once(ANIM_CHEER)
	var t := create_tween().set_parallel(true)
	t.tween_property(model, "position:y", 0.35, 0.18).set_trans(Tween.TRANS_BACK)
	t.chain().tween_property(model, "position:y", 0.0, 0.22)


func _die(reason: String) -> void:
	if not alive:
		return
	alive = false
	input_enabled = false
	velocity = Vector3.ZERO
	_play(ANIM_DEATH)
	_set_death_flash(true)
	var t := create_tween()
	t.tween_property(self, "rotation:z", PI * 0.5, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	died.emit(reason)


func _set_death_flash(on: bool) -> void:
	if _death_mat == null:
		return
	for n in model.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if mi != null and mi.skin != null:
			mi.material_overlay = _death_mat if on else null


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


func _update_anim(delta: float) -> void:
	if _anim == null or not alive:
		return
	if _land_t > 0.0:
		_land_t = maxf(0.0, _land_t - delta)
	var planar := Vector2(velocity.x, velocity.z).length()
	if _one_shot != "":
		if _anim.current_animation != _one_shot or not _anim.is_playing():
			_one_shot = ""
		else:
			return
	var want := ANIM_IDLE
	if not is_on_floor():
		want = ANIM_AIR
	elif _land_t > 0.0:
		want = ANIM_LAND
	elif planar > WALK_SPEED * 1.05:
		want = ANIM_RUN
	elif planar > 0.35:
		want = ANIM_WALK
	if not input_enabled:
		want = ANIM_IDLE
	_play(want)
	if _anim_name == ANIM_WALK or _anim_name == ANIM_RUN:
		var base := WALK_SPEED if _anim_name == ANIM_WALK else SPRINT_SPEED
		_anim.speed_scale = clampf(planar / base, 0.65, 1.7)
	elif _anim_name == ANIM_IDLE or _anim_name == ANIM_AIR:
		_anim.speed_scale = 1.0

