extends Node3D

signal reached

@export var goal_radius := 2.7

var goal_position := Vector3.ZERO
var completed := false

var _player: Node3D = null


func _ready() -> void:
	var root := get_parent()
	_player = root.get_node_or_null("Player")
	var goal := root.get_node_or_null("CityBlock/PizzaShopGoal") as Node3D
	if goal != null:
		goal_position = goal.global_position


func _process(_delta: float) -> void:
	if completed or _player == null or not is_instance_valid(_player):
		return
	if _player.global_position.distance_to(goal_position) <= goal_radius:
		completed = true
		reached.emit()


func distance_to_goal() -> float:
	if _player == null or not is_instance_valid(_player):
		return 0.0
	return _player.global_position.distance_to(goal_position)
