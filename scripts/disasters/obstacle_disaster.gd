extends "res://scripts/disasters/disaster_base.gd"

const Fx := preload("res://scripts/fx.gd")

const DURATION := 11.0
const TYPES := ["cone", "crate", "bin", "tyres"]

var _props: Array[Node3D] = []
var _gone := false


func telegraph(point: Vector3) -> void:
	var count := randi_range(2, 4)
	var spread := 1.1
	var start := point - Vector3(spread * float(count - 1) * 0.5, 0, 0)
	for i in count:
		var type: String = TYPES[randi() % TYPES.size()]
		var offset := Vector3(spread * float(i), 0, randf_range(-0.35, 0.35))
		var prop := _make_prop(type, start + offset)
		add_child(prop)
		_props.append(prop)
		var visual := prop.get_node("Visual") as Node3D
		visual.scale = Vector3(1.0, 0.05, 1.0)
		var t := track(create_tween())
		t.tween_property(visual, "scale", Vector3.ONE, 0.22).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	Fx.burst(self, point + Vector3.UP * 0.2, Color(1.0, 0.8, 0.2), 10, 3.0)


func activate(_point: Vector3) -> void:
	active = true
	shake(0.1)


func _process(delta: float) -> void:
	if not active:
		return
	lifetime += delta
	if lifetime > DURATION and not _gone:
		_gone = true
		_clear_props()


func _clear_props() -> void:
	var t := track(create_tween())
	t.set_parallel(true)
	for prop in _props:
		if is_instance_valid(prop):
			var visual := prop.get_node_or_null("Visual") as Node3D
			if visual != null:
				t.tween_property(visual, "scale", Vector3(0.01, 0.01, 0.01), 0.3)
	finish_after(0.35)


func _make_prop(type: String, pos: Vector3) -> Node3D:
	var root := StaticBody3D.new()
	root.collision_layer = 1
	root.collision_mask = 1
	root.position = pos

	var visual := Node3D.new()
	visual.name = "Visual"
	root.add_child(visual)

	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	var cylinder := CylinderShape3D.new()

	match type:
		"cone":
			cylinder.radius = 0.28
			cylinder.height = 0.62
			shape.shape = cylinder
			var cone_mesh := CylinderMesh.new()
			cone_mesh.top_radius = 0.03
			cone_mesh.bottom_radius = 0.28
			cone_mesh.height = 0.62
			cone_mesh.radial_segments = 8
			cone_mesh.rings = 1
			var cone := MeshInstance3D.new()
			cone.mesh = cone_mesh
			cone.material_override = make_material(Color(1.0, 0.45, 0.05), 0.6)
			cone.position = Vector3(0, 0.31, 0)
			visual.add_child(cone)
			var band := make_box(Vector3(0.44, 0.12, 0.44), Color(0.95, 0.95, 0.95), 0.5)
			band.position = Vector3(0, 0.36, 0)
			visual.add_child(band)
			var base := make_box(Vector3(0.62, 0.06, 0.62), Color(0.95, 0.3, 0.05), 0.6)
			base.position = Vector3(0, 0.03, 0)
			visual.add_child(base)
		"crate":
			box.size = Vector3(0.72, 0.72, 0.72)
			shape.shape = box
			var crate := make_box(Vector3(0.72, 0.72, 0.72), Color(0.62, 0.44, 0.24), 0.85)
			crate.position = Vector3(0, 0.36, 0)
			visual.add_child(crate)
			var plank := make_box(Vector3(0.76, 0.08, 0.76), Color(0.42, 0.29, 0.15), 0.9)
			plank.position = Vector3(0, 0.36, 0)
			visual.add_child(plank)
		"bin":
			cylinder.radius = 0.32
			cylinder.height = 0.9
			shape.shape = cylinder
			var can := CylinderMesh.new()
			can.top_radius = 0.34
			can.bottom_radius = 0.28
			can.height = 0.9
			can.radial_segments = 10
			can.rings = 1
			var bin := MeshInstance3D.new()
			bin.mesh = can
			bin.material_override = make_material(Color(0.28, 0.3, 0.32), 0.7, 0.2)
			bin.position = Vector3(0, 0.45, 0)
			visual.add_child(bin)
			var lid := CylinderMesh.new()
			lid.top_radius = 0.36
			lid.bottom_radius = 0.36
			lid.height = 0.08
			lid.radial_segments = 10
			lid.rings = 1
			var cap := MeshInstance3D.new()
			cap.mesh = lid
			cap.material_override = make_material(Color(0.16, 0.18, 0.2), 0.6, 0.3)
			cap.position = Vector3(0, 0.92, 0)
			visual.add_child(cap)
		_:
			cylinder.radius = 0.36
			cylinder.height = 0.42
			shape.shape = cylinder
			for i in 3:
				var tyre_mesh := CylinderMesh.new()
				tyre_mesh.top_radius = 0.36
				tyre_mesh.bottom_radius = 0.36
				tyre_mesh.height = 0.13
				tyre_mesh.radial_segments = 10
				tyre_mesh.rings = 1
				var tyre := MeshInstance3D.new()
				tyre.mesh = tyre_mesh
				tyre.material_override = make_material(Color(0.1, 0.1, 0.11), 0.95)
				tyre.position = Vector3(0, 0.07 + i * 0.14, 0)
				visual.add_child(tyre)

	shape.position = Vector3(0, 0.45 if type != "cone" else 0.3, 0)
	root.add_child(shape)
	root.rotation.y = randf_range(-0.6, 0.6)
	return root
