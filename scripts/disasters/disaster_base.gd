extends Node3D

signal finished

var player: Node3D = null
var game: Node = null
var active := false
var lifetime := 0.0

var _tweens: Array[Tween] = []


func setup(p: Node3D, g: Node) -> void:
	player = p
	game = g


func track(t: Tween) -> Tween:
	if t != null:
		_tweens.append(t)
	return t


func _kill_tweens() -> void:
	for t in _tweens:
		if t != null and t.is_valid():
			t.kill()
	_tweens.clear()


func _exit_tree() -> void:
	_kill_tweens()


func telegraph(_point: Vector3) -> void:
	pass


func activate(_point: Vector3) -> void:
	active = true


func finish() -> void:
	active = false
	finished.emit()
	_kill_tweens()
	queue_free()


func finish_after(delay: float) -> void:
	if not is_inside_tree():
		return
	get_tree().create_timer(delay, true, false, true).timeout.connect(_on_finish_timer)


func _on_finish_timer() -> void:
	if is_inside_tree():
		finish()


func player_pos() -> Vector3:
	if is_instance_valid(player):
		return player.global_position
	return Vector3.ZERO


func hurt(amount: int, from: Vector3, reason: String, power := 6.0) -> void:
	if is_instance_valid(player):
		player.take_damage(amount, from, reason, power)


func shake(amount: float) -> void:
	if game != null:
		game.add_shake(amount)


func make_material(color: Color, rough := 0.75, metal := 0.0, emission := 0.0) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = rough
	mat.metallic = metal
	if emission > 0.0:
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = emission
	return mat


func make_box(size: Vector3, color: Color, rough := 0.75, metal := 0.0, emission := 0.0) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = make_material(color, rough, metal, emission)
	return mi


func make_marker(point: Vector3, size: float, color: Color) -> MeshInstance3D:
	var mi := make_box(Vector3(size, 0.05, size), color, 0.9, 0.0, 0.5)
	mi.position = point + Vector3.UP * 0.05
	add_child(mi)
	var t := track(create_tween())
	t.set_loops(3)
	t.tween_property(mi, "scale", Vector3(0.72, 1.0, 0.72), 0.16)
	t.tween_property(mi, "scale", Vector3(1.15, 1.0, 1.15), 0.16)
	return mi


func make_label(text: String, color: Color, pixel := 0.006) -> Label3D:
	var label := Label3D.new()
	label.text = text
	label.font_size = 64
	label.outline_size = 14
	label.pixel_size = pixel
	label.modulate = color
	label.outline_modulate = Color(0.1, 0.05, 0.05)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = false
	label.double_sided = true
	return label
