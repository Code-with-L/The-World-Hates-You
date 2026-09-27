extends RefCounted

static func burst(parent: Node, pos: Vector3, color: Color, amount := 14, speed := 4.5) -> void:
	if parent == null or not is_instance_valid(parent) or not parent.is_inside_tree():
		return
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.16, 0.16, 0.16)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var p := CPUParticles3D.new()
	p.mesh = mesh
	p.material_override = mat
	p.emitting = false
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = amount
	p.lifetime = 0.55
	p.direction = Vector3.UP
	p.spread = 70.0
	p.initial_velocity_min = speed * 0.5
	p.initial_velocity_max = speed
	p.gravity = Vector3(0.0, -14.0, 0.0)
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.5
	p.position = pos
	parent.add_child(p)
	p.emitting = true
	_autofree(parent, p, 1.4)


static func shockwave(parent: Node, pos: Vector3, color: Color, to_scale := 3.0, time := 0.45) -> void:
	if parent == null or not is_instance_valid(parent) or not parent.is_inside_tree():
		return
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.5
	mesh.bottom_radius = 0.5
	mesh.height = 0.03
	mesh.radial_segments = 12
	mesh.rings = 1
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = pos + Vector3.UP * 0.06
	mi.scale = Vector3(0.2, 1.0, 0.2)
	parent.add_child(mi)
	var t := parent.create_tween()
	t.set_parallel(true)
	t.tween_property(mi, "scale", Vector3(to_scale, 1.0, to_scale), time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_property(mat, "albedo_color:a", 0.0, time)
	t.chain().tween_interval(0.01)
	t.chain().tween_callback(Callable(mi, "queue_free"))


static func _autofree(parent: Node, node: Node, delay: float) -> void:
	var tree := parent.get_tree()
	if tree == null or not is_instance_valid(node):
		return
	tree.create_timer(delay, true, false, true).timeout.connect(Callable(node, "queue_free"))
