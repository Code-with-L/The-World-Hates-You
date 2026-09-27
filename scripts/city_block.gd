extends Node3D

var _t := 0.0


func _process(delta: float) -> void:
	_t += delta
	var icon := get_node_or_null("PizzaShop/PizzaIcon") as Node3D
	if icon == null:
		return
	var s := 0.1 * (1.0 + sin(_t * 3.2) * 0.12)
	icon.scale = Vector3(s, s, s)
	icon.rotate_y(delta * 1.2)
