extends Node3D

signal finished

const Sfx := preload("res://scripts/sfx.gd")

# Telegraph read: the danger area is always told in the same three layers, so a
# player who has seen one disaster can read the next without being told.
const WARN_RED := Color(1.0, 0.22, 0.16)
const WARN_YELLOW := Color(1.0, 0.82, 0.2)
const WARN_CREAM := Color(1.0, 0.96, 0.88)

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


# --- pass 4 presentation helpers -------------------------------------------
# Everything below is presentation only. No helper here touches collision,
# damage, cooldowns or spawn points; they exist so each disaster can telegraph
# itself in the same visual language without duplicating the setup.

# Unshaded and alpha blended: telegraph decals must stay legible in shadow and
# must not pick up the scene's lighting, or they vanish at dusk.
func unshaded(color: Color, alpha := 1.0) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(color.r, color.g, color.b, alpha)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	return mat


# Flat ground disc in world space, so it does not depend on the disaster node
# sitting at the origin.
func make_disc(radius: float, color: Color, at: Vector3, alpha := 0.85) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = 0.02
	mesh.radial_segments = 12
	mesh.rings = 1
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = unshaded(color, alpha)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	mi.global_position = at + Vector3.UP * 0.03
	return mi


# The shared danger-area tell: a ring that expands out of the impact point. Reads
# as "this exact spot", which is the one thing the old flat marker failed to say.
func make_danger_ring(radius: float, color: Color, at: Vector3, cycles := 3) -> MeshInstance3D:
	var mi := make_disc(radius, color, at, 0.8)
	mi.scale = Vector3(0.1, 1.0, 0.1)
	var t := track(create_tween())
	t.set_loops(cycles)
	t.tween_property(mi, "scale", Vector3(1.0, 1.0, 1.0), 0.42).from(Vector3(0.1, 1.0, 0.1)) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	return mi


# Diagonal hazard band, used for the car lane and the obstacle patches. Alternating
# bars read as hazard from any angle and cost one node per bar.
func make_hazard_band(at: Vector3, width: float, along: Vector3, bars := 7) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	var yaw := atan2(-along.x, -along.z)
	for i in bars:
		var mi := make_box(Vector3(0.22, 0.02, width), WARN_YELLOW, 0.6, 0.0, 0.35)
		mi.material_override = unshaded(WARN_YELLOW, 0.9)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)
		var offset := (float(i) - float(bars - 1) * 0.5) * 0.34
		mi.global_position = at + along * offset + Vector3.UP * 0.035
		mi.rotation = Vector3(0.0, yaw + 0.6, 0.0)
		out.append(mi)
	return out


# Arrow that points the way a hazard travels, so the direction is readable
# before the hazard itself is visible.
func make_arrow(at: Vector3, dir: Vector3, color: Color, scale := 1.0) -> Node3D:
	var root := Node3D.new()
	add_child(root)
	root.global_position = at + Vector3.UP * 0.04
	var flat := Vector3(dir.x, 0.0, dir.z)
	if flat.length() < 0.01:
		flat = Vector3.FORWARD
	root.rotation.y = atan2(flat.x, flat.z)
	for i in 3:
		for s in [1.0, -1.0]:
			var head := make_box(Vector3(0.9, 0.02, 0.22) * scale, color, 0.6, 0.0, 0.4)
			head.material_override = unshaded(color, 0.9)
			head.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			head.position = Vector3(0.0, 0.0, (float(i) - 1.0) * 0.5 * scale)
			head.rotation = Vector3(0.0, 0.62 * s, 0.0)
			root.add_child(head)
	return root


# World-space callout that always faces the player. Used for the short shout
# that sits over a telegraph ("LOOK OUT", "LOCKED").
func make_callout(text: String, at: Vector3, color: Color, pixel := 0.007) -> Label3D:
	var label := make_label(text, color, pixel)
	add_child(label)
	label.global_position = at
	# A single up-and-back pop rather than a set_loops() tween. An endless tween
	# logs "Infinite loop detected" when the disaster frees its tweens at
	# cleanup, and a callout only lives for the telegraph anyway.
	var t := track(create_tween())
	t.tween_property(label, "position:y", label.position.y + 0.18, 0.18) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(label, "position:y", label.position.y, 0.3).set_trans(Tween.TRANS_SINE)
	return label


# Fades and frees a list of telegraph nodes once the disaster goes live, so the
# warning does not sit on top of the thing it was warning about. Tints the
# unshaded material's alpha down; telegraphs are always unshaded, so this is
# safe. Nodes without an override (rare) are simply freed.
func fade_out(nodes: Array, delay := 0.0) -> void:
	if nodes.is_empty() or not is_inside_tree():
		return
	var t := track(create_tween())
	if delay > 0.0:
		t.tween_interval(delay)
	t.set_parallel(true)
	for n in nodes:
		if not is_instance_valid(n):
			continue
		var mat: Material = n.material_override if n is GeometryInstance3D else null
		if mat is StandardMaterial3D:
			t.tween_property(mat, "albedo_color:a", 0.0, 0.18)
	t.chain().tween_callback(func() -> void:
		for n in nodes:
			if is_instance_valid(n):
				n.queue_free())


# Loads a KayKit prop for use as decoration. Returns null if the pack is missing
# so a disaster can fall back to its box geometry instead of failing to spawn.
func load_prop(path: String) -> PackedScene:
	if not ResourceLoader.exists(path):
		return null
	var res := ResourceLoader.load(path)
	return res as PackedScene


func sfx(cue: String, volume_db := 0.0, pitch := 1.0) -> void:
	Sfx.play(cue, volume_db, pitch)
