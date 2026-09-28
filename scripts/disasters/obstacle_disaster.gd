extends "res://scripts/disasters/disaster_base.gd"

const Fx := preload("res://scripts/fx.gd")

const DURATION := 11.0

# Real KayKit props instead of boxes, because a pile of literal boxes reads as a
# bug while a dumpster and a stack of barrels reads as a blocked street. Each
# entry is [path, uniform_scale, collider_size, sit_offset_y, tris]. The collider
# is a simple box sized to the prop's footprint so the walkable surface and the
# visual agree; sit_offset_y lifts a prop whose glTF is not authored on y=0.
const TYPES := {
	"dumpster": ["res://assets/kaykit/city/Assets/gltf/dumpster.gltf", 2.4, Vector3(1.15, 0.78, 0.72), 0.0, 77],
	"barrel": ["res://assets/kaykit/prototype/Assets/gltf/Barrel_A.gltf", 0.62, Vector3(0.62, 0.62, 0.62), 0.31, 40],
	"boxes": ["res://assets/kaykit/prototype/Assets/gltf/Box_A.gltf", 0.95, Vector3(0.72, 0.72, 0.72), 0.0, 40],
	"trash": ["res://assets/kaykit/city/Assets/gltf/trash_A.gltf", 2.0, Vector3(0.5, 0.5, 0.5), 0.0, 40],
}
const TYPE_KEYS := ["dumpster", "barrel", "boxes", "trash"]

var _props: Array[Node3D] = []
var _gone := false
var _telegraph_nodes: Array = []


func telegraph(point: Vector3) -> void:
	var count := randi_range(2, 4)
	var spread := 1.1
	var start := point - Vector3(spread * float(count - 1) * 0.5, 0, 0)
	# The tell: a hazard patch and a shouted TRIP HAZARD where the junk will be,
	# dropped a beat before the props rise, so the placement is readable.
	_telegraph_nodes.append(make_hazard_band(point, 2.2, Vector3(0.0, 0.0, 1.0), 6))
	_telegraph_nodes.append(make_callout("TRIP HAZARD", point + Vector3.UP * 1.6, WARN_CREAM, 0.006))
	for i in count:
		var key: String = TYPE_KEYS[randi() % TYPE_KEYS.size()]
		var offset := Vector3(spread * float(i), 0, randf_range(-0.35, 0.35))
		var prop := _make_prop(key, start + offset)
		if prop == null:
			continue
		add_child(prop)
		_props.append(prop)
		var visual := prop.get_node_or_null("Visual") as Node3D
		if visual != null:
			visual.scale = Vector3(1.0, 0.05, 1.0)
			var t := track(create_tween())
			t.tween_property(visual, "scale", Vector3.ONE, 0.22).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	Fx.burst(self, point + Vector3.UP * 0.2, WARN_YELLOW, 10, 3.0)
	sfx("obstacle_land", -8.0, 1.3)


func activate(_point: Vector3) -> void:
	active = true
	shake(0.1)
	# The patch has done its job once the junk is standing on it.
	fade_out(_telegraph_nodes)
	_telegraph_nodes.clear()


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


# Builds one obstacle: a StaticBody3D whose Visual child holds either the KayKit
# prop or, if the pack is missing, a coloured box stand-in.
func _make_prop(key: String, pos: Vector3) -> Node3D:
	var spec: Array = TYPES[key]
	var size: Vector3 = spec[2]
	var root := StaticBody3D.new()
	root.collision_layer = 1
	root.collision_mask = 1
	root.position = pos
	root.rotation.y = randf_range(-0.6, 0.6)

	var visual := Node3D.new()
	visual.name = "Visual"
	root.add_child(visual)

	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	shape.position = Vector3(0, size.y * 0.5, 0)
	root.add_child(shape)

	var scene := load_prop(spec[0])
	if scene != null:
		var mesh: Node3D = scene.instantiate()
		mesh.scale = Vector3.ONE * float(spec[1])
		_disable_shadows(mesh)
		visual.add_child(mesh)
		# sit_offset_y lifts a prop whose glTF is not authored on y=0; the collider
		# height already carries the rest off the ground.
		if float(spec[3]) != 0.0:
			mesh.position.y = float(spec[3])
	else:
		# Fallback stand-in so the obstacle still blocks even without the pack.
		var fallback := make_box(size, _fallback_color(key), 0.8)
		fallback.position = Vector3(0, size.y * 0.5, 0)
		visual.add_child(fallback)
	return root


func _fallback_color(key: String) -> Color:
	match key:
		"dumpster":
			return Color(0.24, 0.42, 0.28)
		"barrel":
			return Color(0.75, 0.55, 0.2)
		"boxes":
			return Color(0.62, 0.44, 0.24)
		_:
			return Color(0.35, 0.37, 0.4)


func _disable_shadows(node: Node) -> void:
	if node is GeometryInstance3D:
		(node as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for child in node.get_children():
		_disable_shadows(child)
