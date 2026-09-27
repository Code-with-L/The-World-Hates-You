extends Node


func _ready() -> void:
	_measure()


func _measure() -> void:
	var scene: PackedScene = load("res://scenes/city_block.tscn")
	var node: Node = scene.instantiate()
	add_child(node)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	var nodes := 0
	var meshes := 0
	var tris := 0
	var bodies := 0
	var areas := 0
	var lights := 0
	var labels := 0
	var mats := {}
	var stack: Array[Node] = [node]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		nodes += 1
		if n is StaticBody3D:
			bodies += 1
		if n is Area3D:
			areas += 1
		if n is Light3D:
			lights += 1
		if n is Label3D:
			labels += 1
		if n is MeshInstance3D:
			var mi := n as MeshInstance3D
			meshes += 1
			if mi.mesh != null:
				for s in mi.mesh.get_surface_count():
					tris += int(mi.mesh.surface_get_array_len(s) / 3)
			var m := mi.get_active_material(0)
			if m != null:
				mats[m.resource_name] = true
		for c in n.get_children():
			stack.append(c)
	print("RESULT nodes=%d mesh_instances=%d triangles=%d static_bodies=%d areas=%d lights=%d labels=%d unique_materials=%d" % [nodes, meshes, tris, bodies, areas, lights, labels, mats.size()])
	get_tree().quit()
