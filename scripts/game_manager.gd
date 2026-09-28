extends Node3D

const Fx := preload("res://scripts/fx.gd")
const Sfx := preload("res://scripts/sfx.gd")

enum State { INTRO, RUNNING, WON, LOST }

const RUN_TIME := 60.0
const INTRO_TIME := 1.5

var state: int = State.INTRO
var time_left := RUN_TIME
var intro_left := INTRO_TIME
var run_coins := 0
var fail_reason := ""

var _mouse_captured := false
var _hitstop := 0.0

@onready var player: CharacterBody3D = $Player
@onready var camera_rig: Node3D = $CameraRig
@onready var mission: Node3D = $Mission
@onready var disasters: Node3D = $DisasterManager
@onready var ui: CanvasLayer = $HUD
@onready var touch: Control = $HUD/TouchControls


func _ready() -> void:
	# Sound hooks are inert until audio files exist; attaching the pool is what
	# makes adding them later a drop-in change.
	Sfx.attach(self)
	player.camera_rig = camera_rig
	camera_rig.target = player
	camera_rig.snap_to_target()
	disasters.setup(player, self)
	touch.setup(player, camera_rig)
	player.died.connect(_on_player_died)
	player.hit_taken.connect(_on_player_hit)
	player.health_changed.connect(_on_health_changed)
	_on_health_changed(player.hp, 3)
	mission.reached.connect(_on_goal_reached)
	ui.restart_requested.connect(restart)
	ui.set_objective("GET TO THE PIZZA SHOP")
	ui.set_timer(time_left)
	ui.set_coins(SaveSystem.coins)
	_capture_mouse(DisplayServer.is_touchscreen_available() == false)
	disasters.set_active(false)
	ui.show_event("GO! THE WORLD HATES YOU!", 0)


func _process(delta: float) -> void:
	if _hitstop > 0.0:
		_hitstop -= delta
		if _hitstop <= 0.0:
			Engine.time_scale = 1.0
		return
	match state:
		State.INTRO:
			intro_left -= delta
			ui.set_distance(mission.distance_to_goal())
			if intro_left <= 0.0:
				_start_run()
		State.RUNNING:
			time_left = maxf(0.0, time_left - delta)
			ui.set_timer(time_left)
			ui.set_distance(mission.distance_to_goal())
			if time_left <= 0.0:
				lose("OUT OF TIME. THE PIZZA WENT COLD.")


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("restart"):
		restart()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		_capture_mouse(false)
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton and event.pressed and state == State.RUNNING and not _mouse_captured:
		if DisplayServer.is_touchscreen_available():
			_capture_mouse(false)
		else:
			_capture_mouse(true)


func _start_run() -> void:
	state = State.RUNNING
	disasters.set_active(true)


func add_shake(amount: float) -> void:
	if camera_rig != null:
		camera_rig.add_trauma(amount)


func emit_event(text: String, tone := 0) -> void:
	ui.show_event(text, tone)


func hit_stop(duration := 0.1) -> void:
	if _hitstop > 0.0:
		return
	_hitstop = duration
	Engine.time_scale = 0.35
	var timer := get_tree().create_timer(duration, true, false, true)
	timer.timeout.connect(_end_hit_stop)


func _end_hit_stop() -> void:
	_hitstop = 0.0
	Engine.time_scale = 1.0


func restart() -> void:
	Engine.time_scale = 1.0
	_hitstop = 0.0
	get_tree().reload_current_scene()


func _on_goal_reached() -> void:
	if state == State.WON or state == State.LOST:
		return
	run_coins = SaveSystem.finish_run(true, time_left)
	player.celebrate()
	ui.show_victory(run_coins, time_left, SaveSystem.coins, SaveSystem.best_time_left)
	Fx.burst(self, mission.goal_position + Vector3.UP, Color(1.0, 0.8, 0.2), 24, 6.0)
	add_shake(0.25)
	state = State.WON
	disasters.set_active(false)
	ui.show_event("YOU MADE IT!", 2)
	Sfx.play("victory")
	_capture_mouse(true)


func _on_health_changed(hp: int, max_hp: int) -> void:
	ui.set_health(hp, max_hp)


func _on_player_hit(_world_pos: Vector3, reason: String) -> void:
	ui.flash(0.32)
	ui.set_coins(SaveSystem.coins)
	add_shake(0.45)
	hit_stop(0.09)
	emit_event(reason, 1)
	# Single funnel point for every hit in the game, so the "I got hit" cue only
	# has to be wired once.
	Sfx.play("player_hurt")


func _on_player_died(reason: String) -> void:
	if state == State.WON or state == State.LOST:
		return
	lose(reason)


func lose(reason: String) -> void:
	if state == State.LOST or state == State.WON:
		return
	fail_reason = reason
	run_coins = SaveSystem.finish_run(false, 0.0)
	ui.show_failure(fail_reason, run_coins, SaveSystem.coins, SaveSystem.runs)
	state = State.LOST
	disasters.set_active(false)
	add_shake(0.6)
	emit_event("THE WORLD HATES YOU!", 1)
	_capture_mouse(true)
	if player.alive:
		player.force_death(fail_reason)


func _capture_mouse(should_capture: bool) -> void:
	_mouse_captured = should_capture
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if should_capture else Input.MOUSE_MODE_VISIBLE
