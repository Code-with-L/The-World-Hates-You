extends Node


func _ready() -> void:
	_run()


func _run() -> void:
	var scene: PackedScene = load("res://scenes/city_block.tscn")
	var node: Node3D = scene.instantiate()
	add_child(node)
	for i in 20:
		await get_tree().physics_frame
	var space := get_viewport().world_3d.direct_space_state
	var probes: Array[Vector3] = [Vector3(-5.5, 3, 0), Vector3(0, 3, 0), Vector3(-8, 8, 10), Vector3(9, 8, 13), Vector3(7.5, 3, 17)]
	for probe in probes:
		var q := PhysicsRayQueryParameters3D.create(probe, probe + Vector3.DOWN * 6.0)
		q.collision_mask = 1
		var hit: Dictionary = space.intersect_ray(q)
		if hit.is_empty():
			print("ray ", str(probe), " -> MISS")
		else:
			print("ray ", str(probe), " -> HIT y=%.2f obj=%s" % [hit["position"].y, hit["collider"].get_class()])
	var road: Node3D = node.get_node("Road")
	var sw: Node3D = node.get_node("SidewalkLeft")
	print("road_children=", road.get_child_count(), " sidewalk_children=", sw.get_child_count())
	print("road_has_collision_shape=", road.get_node_or_null("CollisionShape3D") != null, " sw_has_collision_shape=", sw.get_node_or_null("CollisionShape3D") != null)
	print("DONE")
	get_tree().quit()
