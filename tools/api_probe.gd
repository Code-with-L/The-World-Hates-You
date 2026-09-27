extends SceneTree
func _init() -> void:
	for p in ClassDB.class_get_property_list("CollisionObject3D", true):
		var n: String = p["name"]
		if n.findn("shape") >= 0 or n.findn("owner") >= 0:
			print("PROP ", n)
	for m in ClassDB.class_get_method_list("CollisionObject3D", true):
		var mn: String = m["name"]
		if mn.findn("shape") >= 0:
			print("METH ", mn)
	quit()
