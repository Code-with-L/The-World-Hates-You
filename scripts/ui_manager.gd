extends CanvasLayer

signal restart_requested

const TONE_COLORS := [
	Color(1, 1, 1),
	Color(1, 0.36, 0.3),
	Color(0.55, 1, 0.55),
]
const TONE_SCALES := [1.0, 1.18, 1.3]

@onready var objective_label: Label = $ObjectivePanel/Box/ObjectiveLabel
@onready var distance_label: Label = $ObjectivePanel/Box/DistanceLabel
@onready var timer_label: Label = $TimerLabel
@onready var coins_label: Label = $CoinsLabel
@onready var event_label: Label = $EventLabel
@onready var damage_flash: ColorRect = $DamageFlash
@onready var victory_panel: Control = $VictoryPanel
@onready var failure_panel: Control = $FailurePanel
@onready var victory_coin_line: Label = $VictoryPanel/Card/Box/CoinLine
@onready var victory_time_line: Label = $VictoryPanel/Card/Box/TimeLine
@onready var failure_reason_label: Label = $FailurePanel/Card/Box/ReasonLine
@onready var failure_coin_line: Label = $FailurePanel/Card/Box/CoinLine
@onready var touch: Control = $TouchControls
@onready var restart_hint: Label = $RestartHint

var _event_tween: Tween = null
var _flash_tween: Tween = null
var _last_seconds := -1
var _health_row: HBoxContainer = null
var _pips: Array[Panel] = []


func _ready() -> void:
	victory_panel.visible = false
	failure_panel.visible = false
	damage_flash.color = Color(0.9, 0.1, 0.1, 0.0)
	event_label.modulate.a = 0.0
	_center_pivots()
	get_viewport().size_changed.connect(_center_pivots)
	$VictoryPanel/Card/Box/VictoryButton.pressed.connect(_on_play_again)
	$FailurePanel/Card/Box/FailureButton.pressed.connect(_on_play_again)
	_build_health()


func _build_health() -> void:
	_health_row = HBoxContainer.new()
	_health_row.name = "HealthRow"
	_health_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_health_row.add_theme_constant_override("separation", 10)
	_health_row.anchor_left = 0.5
	_health_row.anchor_right = 0.5
	_health_row.offset_left = -80.0
	_health_row.offset_right = 80.0
	_health_row.offset_top = 14.0
	_health_row.offset_bottom = 42.0
	_health_row.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(_health_row)
	for i in 3:
		var pip := Panel.new()
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.93, 0.24, 0.3)
		style.border_color = Color(0.12, 0.03, 0.05)
		style.set_border_width_all(2)
		style.set_corner_radius_all(8)
		pip.add_theme_stylebox_override("panel", style)
		pip.custom_minimum_size = Vector2(38, 18)
		_health_row.add_child(pip)
		_pips.append(pip)
	set_health(3, 3)


func set_health(hp: int, _max_hp: int) -> void:
	for i in _pips.size():
		var pip := _pips[i]
		if i < hp:
			pip.modulate = Color(1, 1, 1, 1)
		else:
			pip.modulate = Color(0.3, 0.28, 0.3, 0.5)


func _center_pivots() -> void:
	event_label.pivot_offset = event_label.size * 0.5


func get_touch() -> Control:
	return touch


func set_objective(text: String) -> void:
	objective_label.text = text


func set_timer(time_left: float) -> void:
	var seconds := ceili(maxf(time_left, 0.0))
	if seconds == _last_seconds:
		return
	_last_seconds = seconds
	timer_label.text = str(seconds)
	var urgent := seconds <= 10
	timer_label.add_theme_color_override("font_color", Color(1, 0.35, 0.3) if urgent else Color(1, 1, 1))
	if urgent:
		timer_label.scale = Vector2(1.12, 1.12)


func set_coins(total: int) -> void:
	coins_label.text = "COINS  %d" % total


func set_distance(meters: float) -> void:
	distance_label.text = "%dm TO PIZZA" % roundi(meters)


func show_event(text: String, tone := 0) -> void:
	var idx := clampi(tone, 0, TONE_COLORS.size() - 1)
	event_label.text = text
	event_label.add_theme_color_override("font_color", TONE_COLORS[idx])
	event_label.modulate.a = 1.0
	event_label.scale = Vector2.ONE * TONE_SCALES[idx]
	_center_pivots()
	if _event_tween != null and _event_tween.is_valid():
		_event_tween.kill()
	_event_tween = create_tween()
	_event_tween.tween_property(event_label, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_event_tween.tween_interval(1.0)
	_event_tween.tween_property(event_label, "modulate:a", 0.0, 0.4)


func flash(strength := 0.32) -> void:
	damage_flash.color.a = strength
	if _flash_tween != null and _flash_tween.is_valid():
		_flash_tween.kill()
	_flash_tween = create_tween()
	_flash_tween.tween_property(damage_flash, "color:a", 0.0, 0.5)


func show_victory(gained: int, time_left: float, total: int, best: float) -> void:
	victory_coin_line.text = "+%d COINS      TOTAL %d" % [gained, total]
	if best > 0.0:
		victory_time_line.text = "TIME LEFT %.1fs      BEST %.1fs" % [time_left, best]
	else:
		victory_time_line.text = "TIME LEFT %.1fs" % time_left
	victory_panel.visible = true
	victory_panel.modulate.a = 0.0
	_pop_in(victory_panel)
	restart_hint.visible = false
	touch.visible = false


func show_failure(reason: String, gained: int, total: int, runs: int) -> void:
	failure_reason_label.text = reason
	failure_coin_line.text = "+%d COINS      TOTAL %d      RUNS %d" % [gained, total, runs]
	failure_panel.visible = true
	failure_panel.modulate.a = 0.0
	_pop_in(failure_panel)
	restart_hint.visible = false
	touch.visible = false


func _pop_in(panel: Control) -> void:
	panel.modulate.a = 1.0
	var card := panel.get_node_or_null("Card") as Control
	if card == null:
		return
	card.pivot_offset = card.size * 0.5
	card.scale = Vector2(0.72, 0.72)
	var t := create_tween()
	t.tween_property(card, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _on_play_again() -> void:
	restart_requested.emit()
