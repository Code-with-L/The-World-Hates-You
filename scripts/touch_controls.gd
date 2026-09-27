extends Control

const STICK_RADIUS := 62.0
const BASE_SIZE := 150.0

var player: CharacterBody3D = null
var camera_rig: Node3D = null
var enabled := false
var move := Vector2.ZERO

var _stick_id := -1
var _look_id := -1
var _base_pos := Vector2.ZERO
var _sprint := false

@onready var joy_base: Panel = $JoyBase
@onready var joy_knob: Panel = $JoyKnob
@onready var jump_button: Button = $JumpButton
@onready var sprint_button: Button = $SprintButton
@onready var touch_toggle: Button = $TouchToggle


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	jump_button.button_down.connect(_on_jump_down)
	jump_button.button_up.connect(_on_jump_up)
	sprint_button.button_down.connect(_on_sprint_down)
	sprint_button.button_up.connect(_on_sprint_up)
	touch_toggle.pressed.connect(_on_toggle_pressed)
	_set_enabled(DisplayServer.is_touchscreen_available() or OS.has_feature("mobile"))


func setup(p: CharacterBody3D, rig: Node3D) -> void:
	player = p
	camera_rig = rig


func _set_enabled(value: bool) -> void:
	enabled = value
	touch_toggle.text = "TOUCH: ON" if value else "TOUCH: OFF"
	_stick_id = -1
	_look_id = -1
	move = Vector2.ZERO
	joy_knob.visible = false
	joy_base.visible = value
	jump_button.visible = value
	sprint_button.visible = value
	_place_base(Vector2(BASE_SIZE * 0.9, get_viewport_rect().size.y * 0.72))
	if player != null:
		player.set_touch_input(Vector2.ZERO, _sprint)


func _unhandled_input(event: InputEvent) -> void:
	if not enabled:
		return
	var rect := get_viewport_rect().size
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			_press(touch.index, touch.position, rect)
		else:
			_release(touch.index)
	elif event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		if drag.index == _stick_id:
			_update_stick(drag.position)
		elif drag.index == _look_id and camera_rig != null and is_instance_valid(camera_rig):
			camera_rig.add_look(drag.relative * 0.0045)


func _press(index: int, pos: Vector2, rect: Vector2) -> void:
	var in_stick_zone := pos.x < rect.x * 0.48 and pos.y > rect.y * 0.2
	var in_look_zone := pos.x > rect.x * 0.52 and pos.y > rect.y * 0.1
	if in_stick_zone and _stick_id == -1:
		_stick_id = index
		_place_base(pos)
		joy_base.visible = true
		_update_stick(pos)
	elif in_look_zone and _look_id == -1:
		_look_id = index


func _release(index: int) -> void:
	if index == _stick_id:
		_stick_id = -1
		move = Vector2.ZERO
		joy_knob.visible = false
		joy_base.visible = enabled
		_place_base(Vector2(BASE_SIZE * 0.9, get_viewport_rect().size.y * 0.72))
		if player != null:
			player.set_touch_input(Vector2.ZERO, _sprint)
	if index == _look_id:
		_look_id = -1


func _place_base(pos: Vector2) -> void:
	_base_pos = pos
	joy_base.position = pos - Vector2(BASE_SIZE, BASE_SIZE) * 0.5
	if joy_knob.visible:
		joy_knob.position = pos - joy_knob.size * 0.5


func _update_stick(pos: Vector2) -> void:
	move = ((pos - _base_pos) / STICK_RADIUS).limit_length(1.0)
	joy_knob.visible = move.length() > 0.08
	joy_knob.position = _base_pos + move * STICK_RADIUS - joy_knob.size * 0.5
	if player != null:
		player.set_touch_input(move, _sprint)


func _on_jump_down() -> void:
	if player != null:
		player.request_jump()


func _on_jump_up() -> void:
	pass


func _on_sprint_down() -> void:
	_sprint = true
	if player != null:
		player.set_touch_input(move, true)


func _on_sprint_up() -> void:
	_sprint = false
	if player != null:
		player.set_touch_input(move, false)


func _on_toggle_pressed() -> void:
	_set_enabled(not enabled)
