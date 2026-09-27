extends SceneTree

# Regenerates scenes/city_block.tscn.
#
# Invariants kept on purpose:
#   * gameplay layout is unchanged: road, sidewalks, the six buildings at their
#     original centres/sizes/heights, pizza shop, prop anchors, hazard zones
#     (position + collision shape), spawn/goal markers, camera anchor
#   * decoration uses MeshInstance3D primitives only (no CSG bake, no collision)
#   * solid props stay CSG with an explicit use_collision flag, and cylinders /
#     spheres use low segment counts to keep the mobile triangle budget small

const OUT := "res://scenes/city_block.tscn"

var _nodes: Array[String] = []
var _subs: Array[String] = []
var _exts: Array[String] = []
var _extid := {}
var _mid := {}
var _mesh := {}
var n_res := 0
var n_ext := 0
var n_node := 0
var n_csg := 0
var n_mi := 0
var n_solid := 0
var n_light := 0
var n_label := 0
var n_tri := 0
var n_inst := 0

const KK_CITY := "res://assets/kaykit/city/Assets/gltf/"
const KK_REST := "res://assets/kaykit/restaurant/Assets/gltf/"
const KK_PROTO := "res://assets/kaykit/prototype/Assets/gltf/"

var MATS := [
	["road", {"c": Color(0.26, 0.26, 0.28), "r": 0.95}],
	["road_dark", {"c": Color(0.2, 0.2, 0.22), "r": 0.95}],
	["road_line", {"c": Color(0.88, 0.79, 0.38), "r": 0.8}],
	["road_pale", {"c": Color(0.92, 0.92, 0.9), "r": 0.8}],
	["curb", {"c": Color(0.74, 0.72, 0.68), "r": 0.9}],
	["sidewalk", {"c": Color(0.64, 0.63, 0.61), "r": 0.9}],
	["walk_tile", {"c": Color(0.55, 0.54, 0.53), "r": 0.9}],
	["wall_tan", {"c": Color(0.66, 0.56, 0.42), "r": 0.85}],
	["wall_tan2", {"c": Color(0.58, 0.48, 0.36), "r": 0.85}],
	["wall_blue", {"c": Color(0.4, 0.48, 0.58), "r": 0.85}],
	["wall_blue2", {"c": Color(0.34, 0.42, 0.52), "r": 0.85}],
	["wall_brick", {"c": Color(0.48, 0.32, 0.27), "r": 0.9}],
	["roof", {"c": Color(0.3, 0.29, 0.29), "r": 0.9}],
	["trim", {"c": Color(0.86, 0.84, 0.78), "r": 0.7}],
	["trim_dark", {"c": Color(0.33, 0.31, 0.29), "r": 0.8}],
	["glass", {"c": Color(0.48, 0.66, 0.78), "r": 0.1, "m": 0.4, "e": Color(0.3, 0.42, 0.5), "ei": 0.3}],
	["glass_lit", {"c": Color(0.95, 0.85, 0.6), "r": 0.2, "e": Color(1, 0.85, 0.55), "ei": 0.5}],
	["door", {"c": Color(0.33, 0.2, 0.14), "r": 0.7}],
	["awning_red", {"c": Color(0.78, 0.18, 0.16), "r": 0.75}],
	["awning_cream", {"c": Color(0.9, 0.87, 0.8), "r": 0.75}],
	["shop_dark", {"c": Color(0.16, 0.16, 0.18), "r": 0.8}],
	["pizza_red", {"c": Color(0.76, 0.11, 0.09), "r": 0.5}],
	["pizza_cream", {"c": Color(0.93, 0.86, 0.68), "r": 0.7}],
	["pizza_cheese", {"c": Color(0.95, 0.78, 0.2), "r": 0.6}],
	["pizza_glow", {"c": Color(0.86, 0.14, 0.1), "r": 0.5, "e": Color(0.98, 0.26, 0.15), "ei": 0.7}],
	["yellow", {"c": Color(0.94, 0.76, 0.14), "r": 0.5, "e": Color(1, 0.8, 0.2), "ei": 0.35}],
	["leaf", {"c": Color(0.24, 0.48, 0.24), "r": 0.95}],
	["leaf2", {"c": Color(0.31, 0.55, 0.27), "r": 0.95}],
	["trunk", {"c": Color(0.3, 0.21, 0.14), "r": 0.95}],
	["soil", {"c": Color(0.26, 0.19, 0.14), "r": 1.0}],
	["metal", {"c": Color(0.3, 0.31, 0.33), "r": 0.45, "m": 0.7}],
	["metal_light", {"c": Color(0.58, 0.59, 0.61), "r": 0.4, "m": 0.7}],
	["pole", {"c": Color(0.22, 0.23, 0.25), "r": 0.5, "m": 0.5}],
	["car_a", {"c": Color(0.68, 0.2, 0.18), "r": 0.35, "m": 0.3}],
	["car_b", {"c": Color(0.18, 0.28, 0.52), "r": 0.35, "m": 0.3}],
	["tire", {"c": Color(0.11, 0.11, 0.12), "r": 0.95}],
	["wood", {"c": Color(0.44, 0.31, 0.19), "r": 0.9}],
	["bench", {"c": Color(0.48, 0.34, 0.2), "r": 0.9}],
	["lamp_glow", {"c": Color(1, 0.93, 0.75), "r": 0.3, "e": Color(1, 0.92, 0.72), "ei": 2.0}],
	["neon", {"c": Color(1, 0.3, 0.3), "r": 0.3, "e": Color(1, 0.22, 0.22), "ei": 1.6}],
	["hazard", {"c": Color(0.44, 0.37, 0.17), "r": 0.9}],
	["hatch", {"c": Color(0.82, 0.7, 0.2), "r": 0.8}],
	["marker_spawn", {"c": Color(0.2, 0.6, 0.85), "r": 0.4, "e": Color(0.3, 0.75, 1.0), "ei": 0.9}],
	["marker_goal", {"c": Color(0.2, 0.7, 0.35), "r": 0.4, "e": Color(0.3, 0.95, 0.45), "ei": 0.9}],
	["grate", {"c": Color(0.18, 0.18, 0.19), "r": 0.9}],
	# --- KayKit palette (sampled from the pack atlases) ---------------------
	["kk_roof", {"c": Color(0.29, 0.29, 0.27), "r": 0.9}],
	["kk_wall", {"c": Color(0.42, 0.42, 0.33), "r": 0.9}],
	["kk_wall2", {"c": Color(0.49, 0.45, 0.34), "r": 0.9}],
	["kk_trim", {"c": Color(0.55, 0.52, 0.47), "r": 0.85}],
	["kk_base", {"c": Color(0.73, 0.54, 0.25), "r": 0.95}],
	["kk_asphalt", {"c": Color(0.38, 0.38, 0.25), "r": 0.95}],
]

# --------------------------------------------------------------- formatting
func f(v: float) -> String:
	if absf(v) < 0.0005:
		return "0"
	var s := String.num(v, 4)
	if s.contains("."):
		s = s.rstrip("0").rstrip(".")
	return s

func v3(v: Vector3) -> String:
	return "Vector3(%s, %s, %s)" % [f(v.x), f(v.y), f(v.z)]

func cl(c: Color) -> String:
	return "Color(%s, %s, %s, %s)" % [f(c.r), f(c.g), f(c.b), f(c.a)]

func xf(t: Transform3D) -> String:
	return "Transform3D(" + xf12(t) + ")"

# The same 12 numbers without the Transform3D wrapper, for a MultiMesh buffer.
func xf12(t: Transform3D) -> String:
	var b := t.basis
	return "%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s" % [
		f(b.x.x), f(b.y.x), f(b.z.x),
		f(b.x.y), f(b.y.y), f(b.z.y),
		f(b.x.z), f(b.y.z), f(b.z.z),
		f(t.origin.x), f(t.origin.y), f(t.origin.z)]

func T(x: float, y: float, z: float) -> Transform3D:
	return Transform3D(Basis(), Vector3(x, y, z))

func RY(x: float, y: float, z: float, deg: float) -> Transform3D:
	return Transform3D(Basis(Vector3.UP, deg_to_rad(deg)), Vector3(x, y, z))

func RX(x: float, y: float, z: float, deg: float) -> Transform3D:
	return Transform3D(Basis(Vector3.RIGHT, deg_to_rad(deg)), Vector3(x, y, z))

func RZ(x: float, y: float, z: float, deg: float) -> Transform3D:
	return Transform3D(Basis(Vector3.BACK, deg_to_rad(deg)), Vector3(x, y, z))

# Uniformly scaled transforms, used for the KayKit props: the packs are modelled
# at a smaller scale than this world, so every instance carries its own factor.
func TS(x: float, y: float, z: float, s: float) -> Transform3D:
	return Transform3D(Basis().scaled(Vector3(s, s, s)), Vector3(x, y, z))

func TRS(x: float, y: float, z: float, deg: float, s: float) -> Transform3D:
	var b := Basis(Vector3.UP, deg_to_rad(deg)).scaled(Vector3(s, s, s))
	return Transform3D(b, Vector3(x, y, z))

# --------------------------------------------------------------- emitters
func sub_res(type: String, id: String, body: Array) -> void:
	n_res += 1
	_subs.append('[sub_resource type="%s" id="%s"]' % [type, id])
	for l in body:
		_subs.append(str(l))
	_subs.append("")
	_subs.append("")

func node(t: String, name: String, parent: String, x: Transform3D = Transform3D.IDENTITY, props: Array = []) -> void:
	_nodes.append('[node name="%s" type="%s" parent="%s"]' % [name, t, parent])
	if x != Transform3D.IDENTITY:
		_nodes.append("transform = " + xf(x))
	for p in props:
		_nodes.append(str(p))
	_nodes.append("")
	_nodes.append("")
	n_node += 1

# Registers a KayKit PackedScene once and returns its ext_resource id.
func ext_res(path: String, type := "PackedScene") -> String:
	if _extid.has(path):
		return str(_extid[path])
	n_ext += 1
	var id := "%d_kk%d" % [10 + n_ext, n_ext]
	_extid[path] = id
	_exts.append('[ext_resource type="%s" path="%s" id="%s"]' % [type, path, id])
	return id

# Instances a KayKit glTF. These are pure visuals: no collision, so they can
# never change the walkable heights or block a lane the city tests protect.
# They also do not cast shadows: the CSG body behind each one already casts the
# shadow that reads, and the extra casters cost about 10ms a frame.
func inst(parent: String, name: String, path: String, x: Transform3D, tris: int) -> void:
	_nodes.append('[node name="%s" parent="%s" instance=ExtResource("%s")]' % [name, parent, ext_res(path)])
	if x != Transform3D.IDENTITY:
		_nodes.append("transform = " + xf(x))
	_nodes.append("cast_shadow = 0")
	_nodes.append("")
	_nodes.append("")
	n_node += 1
	n_inst += 1
	n_tri += tris

func grp(parent: String, name: String, x: Transform3D = Transform3D.IDENTITY) -> void:
	node("Node3D", name, parent, x)

# Small decorative boxes stay as individual MeshInstance3D nodes. Batching them
# into per-material MultiMeshes was measurably slower (11.3ms vs 6.5ms): one
# MultiMesh spanning the whole city cannot be frustum culled, so every instance
# is transformed and rasterised every frame.
func mi(parent: String, name: String, size: Vector3, mat: String, x: Transform3D = Transform3D.IDENTITY) -> void:
	var key := "b|" + str(size)
	if not _mesh.has(key):
		var id := "mb%d" % _mesh.size()
		_mesh[key] = id
		sub_res("BoxMesh", id, ["size = " + v3(size)])
		n_tri += 12
	node("MeshInstance3D", name, parent, x, [
		"mesh = SubResource(\"%s\")" % _mesh[key],
		"surface_material_override/0 = SubResource(\"%s\")" % _mid[mat],
		"cast_shadow = 0"])
	n_mi += 1

# Decorative shapes are emitted as plain mesh instances rather than CSG. CSG
# re-solves its geometry whenever anything above it moves, and none of these
# carry collision, so they cost CPU for nothing. Only solid shapes stay CSG.
func _cyl_mesh(radius: float, height: float, seg: int) -> String:
	var key := "c|%s|%s|%d" % [f(radius), f(height), seg]
	if not _mesh.has(key):
		var id := "mc%d" % _mesh.size()
		_mesh[key] = id
		sub_res("CylinderMesh", id, [
			"top_radius = " + f(radius),
			"bottom_radius = " + f(radius),
			"height = " + f(height),
			"radial_segments = " + str(seg),
			"rings = 1"])
		n_tri += seg * 4
	return _mesh[key]

func _sph_mesh(radius: float) -> String:
	var key := "s|" + f(radius)
	if not _mesh.has(key):
		var id := "ms%d" % _mesh.size()
		_mesh[key] = id
		sub_res("SphereMesh", id, [
			"radius = " + f(radius),
			"height = " + f(radius * 2.0),
			"radial_segments = 8",
			"rings = 4"])
		n_tri += 8 * 4
	return _mesh[key]

func sb(parent: String, name: String, size: Vector3, mat: String, x: Transform3D = Transform3D.IDENTITY, solid := true, hide := false) -> void:
	if not solid:
		mi(parent, name, size, mat, x)
		return
	var props := [
		"size = " + v3(size),
		"material = SubResource(\"%s\")" % _mid[mat],
		"use_collision = true"]
	if hide:
		props.append("visible = false")
	node("CSGBox3D", name, parent, x, props)
	n_csg += 1
	n_tri += 12
	n_solid += 1

func scyl(parent: String, name: String, radius: float, height: float, mat: String, x: Transform3D = Transform3D.IDENTITY, seg := 10, solid := true, hide := false) -> void:
	if not solid:
		node("MeshInstance3D", name, parent, x, [
			"mesh = SubResource(\"%s\")" % _cyl_mesh(radius, height, seg),
			"surface_material_override/0 = SubResource(\"%s\")" % _mid[mat],
			"cast_shadow = 0"])
		n_mi += 1
		return
	var props := [
		"material = SubResource(\"%s\")" % _mid[mat],
		"radius = " + f(radius),
		"height = " + f(height),
		"radial_segments = " + str(seg),
		"use_collision = true"]
	if hide:
		props.append("visible = false")
	node("CSGCylinder3D", name, parent, x, props)
	n_csg += 1
	n_tri += seg * 4
	n_solid += 1

func ssph(parent: String, name: String, radius: float, mat: String, x: Transform3D = Transform3D.IDENTITY, solid := true) -> void:
	if not solid:
		node("MeshInstance3D", name, parent, x, [
			"mesh = SubResource(\"%s\")" % _sph_mesh(radius),
			"surface_material_override/0 = SubResource(\"%s\")" % _mid[mat],
			"cast_shadow = 0"])
		n_mi += 1
		return
	node("CSGSphere3D", name, parent, x, [
		"material = SubResource(\"%s\")" % _mid[mat],
		"radius = " + f(radius),
		"radial_segments = 8",
		"rings = 4",
		"use_collision = true"])
	n_csg += 1
	n_tri += 64
	if solid:
		n_solid += 1

func storus(parent: String, name: String, inner: float, outer: float, mat: String, x: Transform3D = Transform3D.IDENTITY) -> void:
	node("CSGTorus3D", name, parent, x, [
		"material = SubResource(\"%s\")" % _mid[mat],
		"inner_radius = " + f(inner),
		"outer_radius = " + f(outer),
		"rings = 3",
		"ring_segments = 16",
		"use_collision = false"])
	n_csg += 1
	n_tri += 96

func scol_node(parent: String, shape_id: String) -> void:
	node("CollisionShape3D", "CollisionShape3D", parent, Transform3D.IDENTITY, ["shape = SubResource(\"%s\")" % shape_id])

func light(parent: String, name: String, pos: Vector3, color: Color, energy: float, rng: float) -> void:
	node("OmniLight3D", name, parent, T(pos.x, pos.y, pos.z), [
		"light_color = " + cl(color),
		"light_energy = " + f(energy),
		"omni_range = " + f(rng),
		"shadow_enabled = false"])
	n_light += 1

func label3d(parent: String, name: String, text: String, pos: Vector3, rot: float, psize: float, col: Color, outline: Color) -> void:
	node("Label3D", name, parent, RY(pos.x, pos.y, pos.z, rot), [
		"text = \"%s\"" % text,
		"font_size = 48",
		"outline_size = 10",
		"pixel_size = " + f(psize),
		"modulate = " + cl(col),
		"outline_modulate = " + cl(outline),
		"billboard = 0",
		"no_depth_test = false"])
	n_label += 1

# facade: 1 -> looks toward +x, -1 -> toward -x, 0 -> toward -z (local space)
func fl(face: int, dx: float, dz: float, s: float, y: float, d: float) -> Vector3:
	if face == 0:
		return Vector3(s, y, -dz * 0.5 - d)
	if face > 0:
		return Vector3(dx * 0.5 + d, y, s)
	return Vector3(-dx * 0.5 - d, y, s)

func fs(face: int, w: float, h: float, t: float) -> Vector3:
	if face == 0:
		return Vector3(w, h, t)
	return Vector3(t, h, w)

func fo(face: int, lateral: float, up: float, out: float) -> Transform3D:
	if face == 0:
		return T(lateral, up, -out)
	if face > 0:
		return T(out, up, lateral)
	return T(-out, up, lateral)

func ft(v: Vector3) -> Transform3D:
	return Transform3D(Basis(), v)

# --------------------------------------------------------------- building
func building(tag: String, cx: float, cz: float, dx: float, dz: float, h: float,
		wall: String, upper: String, face: int, shop: bool, sign_text: String,
		accent: String, awning: bool, rows: int, cols: int, roof_kit: int) -> void:
	grp(".", tag, T(cx, 0, cz))
	var p := tag
	var upper_h := maxf(0.6, h - 2.6)
	# The masses keep their exact collision; only their palette changes so the
	# procedural block matches the KayKit facade panels that now clad the front.
	sb(p, "GroundFloor", Vector3(dx, 2.6, dz), "kk_wall2", T(0, 1.3, 0), true)
	sb(p, "Walls", Vector3(dx, upper_h, dz), "kk_wall", T(0, 2.6 + upper_h * 0.5, 0), true)
	sb(p, "Cladding", Vector3(dx + 0.06, maxf(0.3, upper_h - 0.5), dz + 0.06), upper, T(0, 2.6 + upper_h * 0.5, 0), false, true)
	sb(p, "Base", Vector3(dx + 0.24, 0.55, dz + 0.24), "kk_trim", T(0, 0.27, 0), false)
	sb(p, "Cornice", Vector3(dx + 0.34, 0.34, dz + 0.34), "kk_trim", T(0, h - 0.15, 0), false)
	sb(p, "Roof", Vector3(dx + 0.1, 0.4, dz + 0.1), "kk_roof", T(0, h + 0.2, 0), true)
	sb(p, "RoofLip", Vector3(dx + 0.5, 0.28, dz + 0.5), "kk_roof", T(0, h + 0.48, 0), false)
	var pz := dz * 0.5 + 0.2
	var px := dx * 0.5 + 0.2
	sb(p, "ParapetN", Vector3(dx + 0.5, 0.5, 0.25), "kk_trim", T(0, h + 0.75, pz), false)
	sb(p, "ParapetS", Vector3(dx + 0.5, 0.5, 0.25), "kk_trim", T(0, h + 0.75, -pz), false)
	sb(p, "ParapetE", Vector3(0.25, 0.5, dz + 0.5), "kk_trim", T(px, h + 0.75, 0), false)
	sb(p, "ParapetW", Vector3(0.25, 0.5, dz + 0.5), "kk_trim", T(-px, h + 0.75, 0), false)
	# KayKit 4x4 wall panels replace the painted window grid, so the procedural
	# band moldings and window frames are no longer emitted.
	var nbands := 0
	for i in nbands:
		var by := 2.6 + upper_h * (float(i + 1) / float(nbands + 1))
		grp(p, "Band%d" % i, T(0, by, 0))
		var bl := (dz - 0.2) if face != 0 else (dx - 0.2)
		mi(p + "/Band%d" % i, "Strip", fs(face, bl, 0.16, 0.16), "trim", T(0, 0, 0))
		mi(p + "/Band%d" % i, "Under", fs(face, bl, 0.08, 0.2), "trim_dark", T(0, -0.12, 0))
	# upper windows: replaced by the KayKit facade panels
	grp(p, "Windows")
	var wspan := (dz - 1.0) if face != 0 else (dx - 1.0)
	var sp := minf(1.75, wspan / float(maxi(1, cols)))
	for r in 0:
		for c in cols:
			var s := (float(c) - float(cols - 1) * 0.5) * sp
			var y := 2.6 + 2.6 * float(r) + 1.25
			if y + 0.8 > h - 0.35:
				continue
			var wn := "W%d_%d" % [r, c]
			var wp := p + "/Windows/" + wn
			grp(p + "/Windows", wn, ft(fl(face, dx, dz, s, y, 0.05)))
			mi(wp, "Frame", fs(face, 1.16, 1.56, 0.12), "trim", T(0, 0, 0))
			mi(wp, "Pane", fs(face, 0.92, 1.32, 0.18), "glass_lit" if (r + c) % 3 == 0 else "glass", T(0, 0, 0))
			mi(wp, "Bar", fs(face, 0.07, 1.32, 0.2), "trim_dark", T(0, 0, 0))
			mi(wp, "Sill", fs(face, 1.34, 0.11, 0.3), "trim", fo(face, 0, -0.86, 0.05))
			mi(wp, "Lintel", fs(face, 1.4, 0.12, 0.22), "trim", fo(face, 0, 0.86, 0.02))
	# roof kit
	if roof_kit > 0:
		grp(p, "RoofTop")
		var rp := p + "/RoofTop"
		if roof_kit > 1:
			grp(rp, "Hut", T(dx * 0.2, h + 1.45, dz * 0.18))
			mi(rp + "/Hut", "Body", Vector3(1.7, 2.0, 1.7), "trim_dark", T(0, 0, 0))
		if roof_kit > 2:
			grp(rp, "Tank", T(-dx * 0.22, h + 1.75, -dz * 0.2))
			scyl(rp + "/Tank", "Drum", 0.85, 1.5, "metal_light", T(0, 0, 0), 10, false)
			mi(rp + "/Tank", "Lid", Vector3(1.7, 0.12, 1.7), "metal", T(0, 0.8, 0))
			for lx in [-0.6, 0.6]:
				for lz in [-0.6, 0.6]:
					mi(rp + "/Tank", "Leg%d_%d" % [int(lx * 10.0), int(lz * 10.0)], Vector3(0.12, 0.95, 0.12), "metal", T(lx, -1.2, lz))
		# One box per unit: the grill and foot plates were 0.07 and 0.14 thick, so
		# they never read at street distance and cost a node each.
		for a in roof_kit:
			var an := "AC%d" % a
			grp(rp, an, T(-dx * 0.3 + float(a) * 1.5, h + 0.9, -dz * 0.28 + float(a % 2) * 1.0))
			mi(rp + "/" + an, "Body", Vector3(1.15, 0.8, 1.15), "metal_light", T(0, 0, 0))
	# ground floor frontage: the KayKit doorway/order window panels take over the
	# shopfront glazing, so only the sign and the awning are kept.
	grp(p, "Shop")
	var sp2 := p + "/Shop"
	var span: float = minf((dz - 1.0) if face != 0 else (dx - 1.0), 5.0)
	if sign_text != "":
		label3d(sp2, "Sign", sign_text, fl(face, dx, dz, 0, 2.92, 0.26), 90.0 if face != 0 else 180.0, 0.011, Color(1, 0.96, 0.88), Color(0.15, 0.06, 0.05))
	clad_building(p, dx, dz, h, face, shop)
	if awning:
		var ap := sp2 + "/Awning"
		var base := fl(face, dx, dz, 0, 3.35, 0.62)
		grp(sp2, "Awning", RZ(base.x, base.y, base.z, -20.0) if face > 0 else (RZ(base.x, base.y, base.z, 20.0) if face < 0 else RX(base.x, base.y, base.z, -20.0)))
		mi(ap, "Slab", fs(face, span + 0.9, 0.12, 1.5), "awning_red", T(0, 0, 0))
		for st in 4:
			mi(ap, "Stripe%d" % st, fs(face, 0.5, 0.14, 1.52), "awning_cream", fo(face, (float(st) - 1.5) * (span + 0.9) / 4.0, 0, 0))
		mi(ap, "Valance", fs(face, span + 0.9, 0.34, 0.1), "awning_red", fo(face, 0, -0.2, 0.72))

# --------------------------------------------------------------- props
func streetlight(x: float, z: float, dir: float, id: int) -> void:
	var n := "Lamp%d" % id
	grp("StreetProps", n, T(x, 0.15, z))
	var p := "StreetProps/" + n
	scyl(p, "Base", 0.17, 0.34, "metal", T(0, 0.17, 0), 8, true)
	scyl(p, "Pole", 0.075, 4.7, "pole", T(0, 2.6, 0), 8, true)
	mi(p, "Arm", Vector3(1.35, 0.09, 0.09), "pole", T(dir * 0.65, 4.9, 0))
	mi(p, "Head", Vector3(0.7, 0.16, 0.34), "metal", T(dir * 1.25, 4.8, 0))
	mi(p, "Lens", Vector3(0.56, 0.06, 0.26), "lamp_glow", T(dir * 1.25, 4.69, 0))
	light(p, "Glow", Vector3(dir * 1.25, 4.55, 0), Color(1, 0.93, 0.78), 1.15, 7.0)

func bench(x: float, z: float, rot: float, id: int) -> void:
	var n := "Bench%d" % id
	grp("StreetProps", n, RY(x, 0.45, z, rot))
	var p := "StreetProps/" + n
	# collision only; the KayKit slat bench is the visible part
	sb(p, "Block", Vector3(1.7, 0.42, 0.45), "bench", T(0, -0.2, 0), true, true)
	inst(p, "Slat", KK_CITY + "bench.gltf", TRS(0.0, -0.30, 0.0, 0.0, 4.5), 26)

func bin_at(x: float, z: float, id: int) -> void:
	var n := "Bin%d" % id
	grp("StreetProps", n, T(x, 0.65, z))
	var p := "StreetProps/" + n
	scyl(p, "Can", 0.28, 0.92, "metal", T(0, 0, 0), 10, true, true)
	inst(p, "Mesh", KK_PROTO + ("Can_B" if id % 2 == 0 else "Can_A") + ".gltf", TS(0.0, -0.50, 0.0, 2.0), 79)

func tree(x: float, z: float, s: float, id: int) -> void:
	var n := "Tree%d" % id
	grp("StreetProps", n, T(x, 0.15, z))
	var p := "StreetProps/" + n
	scyl(p, "Trunk", 0.17 * s, 1.9 * s, "trunk", T(0, 0.95 * s, 0), 8, true)
	# One canopy sphere is enough: the two extra blobs were hidden inside it and
	# the tree grate already hides the soil disc underneath.
	ssph(p, "Canopy", 0.95 * s, "leaf", T(0, 2.5 * s, 0), true)
	scyl(p, "Grate", 0.55, 0.06, "grate", T(0, 0.03, 0), 8, false)
	# KayKit shrubs fill the bare trunk base. The group already sits on the
	# sidewalk at 0.15, so the shrub origin must be at 0.0, not -0.15, or it
	# ends up buried in the pavement.
	inst(p, "Bush", KK_CITY + "bush.gltf", TS(
		cos(float(id) * 1.7) * 0.4, 0.0, sin(float(id) * 1.7) * 0.4, 2.6), 27)

# Extra KayKit set dressing: kerbside clutter that the procedural pass never
# had. All of it is decoration only, so the walkable lanes are untouched.
func kk_clutter() -> void:
	grp(".", "KayKitProps")
	# Traffic lights on two crossing corners. trafficlight_A is a slim 0.73 pole
	# and _C a boxy 0.97 head, so each gets its own scale to land at the same
	# ~3.2m reading height instead of one scale stretching both into the wrong
	# proportions. _B stays the fallback so a new corner still has a kit.
	for i in 2:
		var tx := -4.6 if i % 2 == 0 else 4.6
		var pole := 4.4 if i % 2 == 0 else 3.3
		var kit := "trafficlight_A" if i % 2 == 0 else "trafficlight_C"
		inst("KayKitProps", "Signal%d" % i, KK_CITY + kit + ".gltf", TS(tx, 0.15, 5.6 if i < 1 else 10.4, pole),
			287 if i % 2 == 0 else 223)
	# skips and pallet stacks in the back yards. Ground/Body is a 2m box whose
	# top is y=-0.2, so anything off the road/sidewalk slabs has to stand on
	# -0.2 rather than on the 0.15 pavement height it was previously using.
	for i in 3:
		var sx: float = [-7.4, 7.4, -7.4][i]
		var sz: float = [14.0, -10.5, -17.5][i]
		inst("KayKitProps", "Skip%d" % i, KK_CITY + "dumpster.gltf", TRS(sx, -0.2, sz, 90.0 * float(i % 2), 2.2), 77)
	# barrels straddle the pavement edge: even indices sit on the bare ground at
	# -0.2, odd ones on the sidewalk at 0.15.
	for i in 4:
		inst("KayKitProps", "Barrel%d" % i, KK_PROTO + ["Barrel_A", "Barrel_C", "Barrel_B", "Barrel_A"][i] + ".gltf",
			TS(-7.1 + float(i % 2) * 0.95, [0.3, 0.65, 0.3, 0.65][i], -16.0 + float(i / 2) * 0.95, 1.0), 128)
	inst("KayKitProps", "Pallet", KK_PROTO + "Pallet_Small.gltf", TS(-7.0, 0.15, -15.0, 1.0), 88)
	# rooftop water tower and a few crates on the back lots
	inst("KayKitProps", "Tower", KK_CITY + "watertower.gltf", TS(6.6, 6.7, 18.0, 1.0), 77)
	# South-east back lot, in the gap south of the Plot155 annex. The big pallet
	# gives that corner some mass it never had, and the three crate sizes in
	# front of it break up the silhouette. All of it sits off the slabs, so it
	# stands on the -0.2 ground rather than the 0.15 pavement height. The pallet
	# is pushed to x=9.2 so its 4m width clears Barrier2's 6.92 edge, and the
	# crates sit at z=-16.2 to clear that same barrier by more than a hair.
	inst("KayKitProps", "PalletLarge", KK_PROTO + "Pallet_Large.gltf", TS(9.2, -0.2, -19.0, 1.0), 88)
	for i in 3:
		inst("KayKitProps", "YardCrate%d" % i, KK_PROTO + ["Box_A", "Box_B", "Box_C"][i] + ".gltf",
			TRS(7.6 + float(i) * 0.85, -0.2, -16.2, 12.0 * float(i), 1.0), [38, 56, 68][i])
	# The packs ship no tree or plant assets beyond this one bush, so the extra
	# greenery is the same kit clustered at a smaller scale than the planters
	# use. Each clump sits in a measured gap between building masses (z=4.8
	# between Building2 and Building1, z=0.0 and z=8.8 in the two east gaps)
	# and is kept at |x|>7.5 so the whole clump clears the -0.2 bare ground
	# rather than straddling the 0.15 sidewalk edge, and both sampled sidewalk
	# lanes. They carry no collision.
	for i in 3:
		var sx: float = [8.2, -9.0, 8.6][i]
		var sz: float = [8.8, 4.8, 0.0][i]
		for j in 3:
			var a := float(j) * 2.399963
			inst("KayKitProps", "Shrub%d_%d" % [i, j], KK_CITY + "bush.gltf",
				TS(sx + cos(a) * 0.55, -0.2, sz + sin(a) * 0.55, 1.9 + 0.5 * float(j % 2)), 27)

func planter(x: float, z: float, name: String) -> void:
	grp("StreetProps", name, T(x, 0.45, z))
	var p := "StreetProps/" + name
	sb(p, "Box", Vector3(0.72, 0.72, 0.72), "trim", T(0, 0, 0), true, true)
	mi(p, "Rim", Vector3(0.86, 0.14, 0.86), "kk_trim", T(0, 0.3, 0))
	inst(p, "Shrub", KK_CITY + "bush.gltf", TS(0.0, 0.36, 0.0, 3.4), 27)

func parked_car(x: float, z: float, rot: float, body: String, name: String, kind: String) -> void:
	grp("StreetProps", name, RY(x, 0.55, z, rot))
	var p := "StreetProps/" + name
	# The box stays the collision body and the KayKit shell is the visible car.
	# The shell carries its own wheels, so separate wheel cylinders only sat
	# inside it and cost sixteen nodes across the parked cars.
	var kit: Array = car_kit(kind)
	sb(p, "Body", Vector3(1.85, 0.6, float(kit[1])), body, T(0, -0.06, 0), true, true)
	inst(p, "Shell", KK_CITY + kind + ".gltf", TRS(0.0, float(kit[2]), 0.0, 0.0, float(kit[0])), int(kit[3]))

# Every KayKit car shell is 0.94 long except the hatchback at 0.81, and they all
# share a -0.072 base offset, so scale, collision length and the vertical nudge
# that keeps the wheels on the tarmac are per-kit rather than one size forced
# onto every model. Returns [scale, body_length, y_offset, tris].
func car_kit(kind: String) -> Array:
	match kind:
		"car_taxi":
			return [3.8, 3.6, -0.32, 548]
		"car_police":
			return [3.8, 3.6, -0.32, 580]
		"car_stationwagon":
			return [3.8, 3.6, -0.32, 523]
		"car_hatchback":
			# Shorter shell: 0.81 * 4.4 = 3.56 long, and the extra scale needs a
			# little more lift because the -0.072 base offset grows with it.
			return [4.4, 3.4, -0.28, 498]
		_:
			return [3.8, 3.6, -0.32, 515]

func hydrant() -> void:
	grp("StreetProps", "FireHydrant", T(-5.5, 0.55, 10))
	var p := "StreetProps/FireHydrant"
	scyl(p, "Body", 0.19, 0.78, "pizza_red", T(0, 0, 0), 8, true, true)
	inst(p, "Mesh", KK_CITY + "firehydrant.gltf", TS(0.0, -0.40, 0.0, 3.0), 72)
func mailbox() -> void:
	grp("StreetProps", "Mailbox", T(5.5, 0.75, 1))
	var p := "StreetProps/Mailbox"
	scyl(p, "Post", 0.08, 1.2, "pole", T(0, -0.35, 0), 8, true)
	mi(p, "Box", Vector3(0.42, 0.46, 0.52), "car_b", T(0, 0.3, 0))
	mi(p, "Cap", Vector3(0.44, 0.14, 0.54), "car_b", T(0, 0.55, 0))

func stop_sign() -> void:
	grp("StreetProps", "StopSign", T(-6.5, 1.5, 8))
	var p := "StreetProps/StopSign"
	scyl(p, "Pole", 0.055, 2.0, "metal_light", T(0, -0.5, 0), 8, true)
	grp(p, "Plate", RY(0, 0, 0, 90))
	var pp := p + "/Plate"
	node("CSGPolygon3D", "Octagon", pp, Transform3D.IDENTITY, [
		"polygon = PackedVector2Array(0.34, 0, 0.24, -0.17, 0, -0.34, -0.24, -0.17, -0.34, 0, -0.24, 0.17, 0, 0.34, 0.24, 0.17)",
		"depth = 0.05",
		"material = SubResource(\"%s\")" % _mid["pizza_red"],
		"use_collision = true"])
	n_csg += 1
	n_tri += 6
	n_solid += 1
	mi(pp, "Rim", Vector3(0.04, 0.74, 0.74), "pizza_cream", T(-0.03, 0, 0))
	mi(pp, "Bar", Vector3(0.06, 0.3, 0.5), "pizza_cream", T(0.04, 0, 0))

func barrier(x: float, z: float, flip: float, name: String) -> void:
	grp("StreetProps", name, T(x, 0.55, z))
	var p := "StreetProps/" + name
	sb(p, "Body", Vector3(0.24, 0.85, 2.1), "awning_cream", T(0, 0, 0), true)
	mi(p, "Stripe1", Vector3(0.3, 0.34, 1.2), "pizza_red", RX(0, 0, -0.55, 32.0 * flip))
	mi(p, "Stripe2", Vector3(0.3, 0.34, 1.2), "pizza_red", RX(0, 0, 0.55, -32.0 * flip))

func utility(x: float, z: float, name: String, w: float, h: float, d: float) -> void:
	grp("StreetProps", name, T(x, 0.15, z))
	var p := "StreetProps/" + name
	mi(p, "Body", Vector3(w, h, d), "metal_light", T(0, h * 0.5, 0))
	mi(p, "Door", Vector3(w * 0.7, h * 0.6, 0.06), "metal", T(0, h * 0.5, d * 0.5 + 0.02))

func manhole(x: float, z: float, id: int) -> void:
	var n := "Manhole%d" % id
	grp("RoadDetails", n, T(x, 0.0, z))
	scyl("RoadDetails/" + n, "Plate", 0.34, 0.05, "grate", T(0, 0.02, 0), 10, false)
	mi("RoadDetails/" + n, "Ring", Vector3(0.78, 0.03, 0.78), "road_dark", T(0, 0.012, 0))

# --------------------------------------------------------- KayKit dressing
# A KayKit road tile is 2x2x0.1 with its origin on the underside, so a tile
# dropped to y=-0.1 has its driving surface flush with the original road top
# (y=0.0). The CSG road underneath stays as the collision body.
# Repeated KayKit props are far cheaper as one MultiMesh than as one instanced
# scene per copy: 88 road tiles cost 88 draw calls as instances and one as a
# MultiMesh. The source mesh is saved next to the scene so the .tscn can point
# at it.
const GENDIR := "res://scenes/generated/"

var _mm_ids: Dictionary = {}

func _mm_mesh_id(path: String) -> String:
	if _mm_ids.has(path):
		return _mm_ids[path]
	var ps: PackedScene = load(path)
	if ps == null:
		return ""
	var inst: Node = ps.instantiate()
	var mesh: Mesh = null
	for ch in inst.find_children("*", "MeshInstance3D", true, false):
		mesh = (ch as MeshInstance3D).mesh
		break
	inst.free()
	if mesh == null:
		return ""
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(GENDIR))
	var out := GENDIR + path.get_file().get_basename() + ".res"
	ResourceSaver.save(mesh, out, ResourceSaver.FLAG_COMPRESS)
	var id := ext_res(out, "Mesh")
	_mm_ids[path] = id
	return id

# Emits one MultiMeshInstance3D holding every copy of `path` placed by `xs`/`zs`.
func _mm_tiles(name: String, path: String, xs: Array, zs: Array, y: float) -> void:
	if xs.is_empty():
		return
	var id := _mm_mesh_id(path)
	if id == "":
		return
	var sub := "mm_" + name
	var buf := ""
	for i in xs.size():
		if i > 0:
			buf += ", "
		buf += "1.0, 0.0, 0.0, " + f(float(xs[i]))
		buf += ", 0.0, 1.0, 0.0, " + f(y)
		buf += ", 0.0, 0.0, 1.0, " + f(float(zs[i]))
	sub_res("MultiMesh", sub, [
		"transform_format = 1",
		"instance_count = " + str(xs.size()),
		"visible_instance_count = " + str(xs.size()),
		"mesh = ExtResource(\"%s\")" % id,
		"buffer = PackedFloat32Array(" + buf + ")"])
	node("MultiMeshInstance3D", name, "Roads", Transform3D.IDENTITY, [
		"multimesh = SubResource(\"%s\")" % sub,
		"cast_shadow = 0"])
	n_inst += 1
	n_tri += xs.size() * 34

# Same idea for boxes, but only for dressing that is on screen no matter where
# the camera looks: the kerb strips and paving joints run the length of the
# block in two unbroken lines. A MultiMesh is one cullable AABB, so scattering
# one across a wide area throws away the per-object culling that made the first
# batching attempt slower. Placements are translation only, which keeps the
# transform buffer a plain basis-plus-origin list.
func mm_boxes(parent: String, name: String, size: Vector3, mat: String, pts: Array) -> void:
	if pts.is_empty():
		return
	var key := "b|" + str(size)
	if not _mesh.has(key):
		var id := "mb%d" % _mesh.size()
		_mesh[key] = id
		sub_res("BoxMesh", id, ["size = " + v3(size)])
		n_tri += 12
	var sub := "mmb_" + name
	var buf := ""
	for i in pts.size():
		if i > 0:
			buf += ", "
		var p: Vector3 = pts[i]
		buf += "1.0, 0.0, 0.0, " + f(p.x)
		buf += ", 0.0, 1.0, 0.0, " + f(p.y)
		buf += ", 0.0, 0.0, 1.0, " + f(p.z)
	sub_res("MultiMesh", sub, [
		"transform_format = 1",
		"instance_count = " + str(pts.size()),
		"visible_instance_count = " + str(pts.size()),
		"mesh = SubResource(\"%s\")" % _mesh[key],
		"buffer = PackedFloat32Array(" + buf + ")"])
	node("MultiMeshInstance3D", name, parent, Transform3D.IDENTITY, [
		"multimesh = SubResource(\"%s\")" % sub,
		"material_override = SubResource(\"%s\")" % _mid[mat],
		"cast_shadow = 0"])
	n_inst += 1
	n_tri += pts.size() * 12

func kk_roads() -> void:
	grp(".", "Roads")
	var sx: Array = []
	var sz: Array = []
	var cx: Array = []
	var cz: Array = []
	for i in 20:
		var z := -19.0 + float(i) * 2.0
		# two rows of crossing tiles carry the zebra crossing that the old
		# procedural Cross boxes used to paint on
		var cross := absf(z - 7.0) < 0.01 or absf(z - 9.0) < 0.01
		for j in 4:
			var x := -3.0 + float(j) * 2.0
			if cross:
				cx.append(x)
				cz.append(z)
			else:
				sx.append(x)
				sz.append(z)
	_mm_tiles("RStraight", KK_CITY + "road_straight.gltf", sx, sz, -0.1)
	_mm_tiles("RCrossing", KK_CITY + "road_straight_crossing.gltf", cx, cz, -0.1)
	# the two aprons past the road ends get plain base plates, dropped to the
	# apron floor height so they sit flush with the ground behind the road
	var ax: Array = []
	var az: Array = []
	for i in 4:
		for s in 2:
			ax.append(-3.0 + float(i) * 2.0)
			az.append(21.0 * float(s))
	_mm_tiles("RApron", KK_CITY + "base.gltf", ax, az, -0.3)

# Transform for one facade panel, in the building's local space. The panel is a
# 4x4x0.5 slab whose origin sits on its base; `out` pushes it onto the face
# plane, and `sy` squashes the top filler row so the stack reaches the parapet.
func _panel_xf(lx: float, y: float, out: float, rot: float, sy := 1.0) -> Transform3D:
	var rb := Basis(Vector3.UP, deg_to_rad(rot))
	return Transform3D(rb.scaled(Vector3(1.0, sy, 1.0)), rb * Vector3(lx, y, out))

# Clads the street-facing side of a building with 4x4 KayKit wall panels, from
# just above the plinth up to the parapet. Windows are scattered over the upper
# rows; the ground row gets a doorway (shops) or an order window.
func clad_building(p: String, dx: float, dz: float, h: float, face: int, shop: bool) -> void:
	var rot := 0.0
	var out := 0.0
	var span := dx
	if face > 0:
		rot = 90.0
		out = dx * 0.5
		span = dz
	elif face < 0:
		rot = -90.0
		out = dx * 0.5
		span = dz
	else:
		out = dz * 0.5
	var cols := maxi(1, int(ceil(span / 4.0)))
	var top := h - 0.9
	var bottom := 0.62
	var rows := int(floor((top - bottom) / 4.0))
	if rows <= 0:
		return
	grp(p, "Facade")
	var fp := p + "/Facade"
	for c in cols:
		var lx := (float(c) - float(cols - 1) * 0.5) * 4.0
		for r in rows:
			var kind := "wall"
			var tris := 50
			var roll := (r * 5 + c * 3 + 11) % 5
			if r == 0 and shop:
				kind = "wall_orderwindow" if c % 2 == 0 else "wall_doorway"
				tris = 113 if c % 2 == 0 else 97
			elif r > 0 and roll < 2:
				kind = "wall_window_open" if roll == 0 else "wall_window_closed"
				tris = 106
			inst(fp, "P%d_%d" % [c, r], KK_REST + kind + ".gltf", _panel_xf(lx, bottom + float(r) * 4.0, out, rot), tris)
		# door leaf for the shopfront doorways
		if shop and c % 2 == 1:
			inst(fp, "L%d" % c, KK_REST + "door_A.gltf",
				_panel_xf(lx + 0.85, bottom, out + 0.35, rot + 26.0), 110)
		# squash one plain panel to close the gap under the parapet
		var rem := top - (bottom + float(rows) * 4.0)
		if rem > 1.1:
			inst(fp, "F%d" % c, KK_REST + "wall.gltf",
				_panel_xf(lx, bottom + float(rows) * 4.0, out, rot, rem / 4.0), 50)

# --- pizza shop polish ----------------------------------------------------
# The shop is the mission destination but it is the shortest building on the
# block (6.5m) and Building4 rises 12m directly in front of it, so from the road
# only its west corner reads and the objective is easy to walk past. This pass
# fixes that without moving the building, the goal or any collision:
#   * a grounded apron and forecourt that close the sidewalk/bare-ground seam
#   * a tall roof blade sign on the north-west corner, which clears Building4
#     and is the only thing visible from the far end of the street
#   * a lit entrance, menu board and pavement seating that make the doorway
#     read as "the place" from the goal pad
# All of it is decoration: no new collision, no anchor moves, no new lights
# beyond two shadowless omnis.
func pizza_polish() -> void:
	# The 6x4 footprint straddles the x=7 sidewalk edge. The base sat in mid-air
	# over the bare -0.2 ground and the two window boxes over x=7 floated above
	# it. One apron slab, top at 0.14, puts every ground-floor prop back on a
	# surface without touching GroundFloor's transform or its collision.
	mi("PizzaShop", "Apron", Vector3(6.5, 0.42, 4.5), "curb", T(0, -0.06, 0))

	# Forecourt in the only gap between Building4 and the apron edge. Building4's
	# base trim reaches z=15.62, so the slab starts at 15.675; it stops at x=7.0
	# to stay clear of the goal pad disc, whose 1.75 radius at (5.2, 15.4)
	# reaches x=6.95.
	mi("PizzaShop", "Forecourt", Vector3(3.6, 0.36, 1.15), "sidewalk", T(1.1, -0.04, -2.775))
	# Set 3 sits in the strip between Building4's base (z<=15.62) and the shop's
	# glazing plane (z>=16.86), which leaves 1.24m. The 0.62-scaled table is
	# 0.93 deep, so it is centred at 16.35 and the stools tuck either side of it.
	inst("PizzaShop", "CafeTable", KK_REST + "table_round_A_small_decorated.gltf",
		TS(1.15, 0.14, -2.65, 0.62), 275)
	for i in 2:
		inst("PizzaShop", "CafeStool%d" % i, KK_REST + "chair_stool.gltf",
			TS(1.15, 0.14, -3.05 + float(i) * 0.6, 0.68), 87)
	# top of the 0.62-scaled table sits at 0.14 + 1.116
	inst("PizzaShop", "CafeKetchup", KK_REST + "ketchup.gltf", TS(0.97, 1.26, -2.48, 0.26), 56)
	inst("PizzaShop", "CafeMustard", KK_REST + "mustard.gltf", TS(1.31, 1.26, -2.62, 0.26), 56)
	inst("PizzaShop", "CafeBowl", KK_REST + "bowl.gltf", TS(1.14, 1.26, -2.3, 0.3), 70)

	# Menu board at the east end of the seating area. The door frame fills
	# x 4.97..6.23 and Building4's west cladding stands proud to x=6.25, so
	# there is no room for it beside the door; out here it still faces the road.
	inst("PizzaShop", "MenuBoard", KK_REST + "menu.gltf", TS(2.2, 0.14, -2.95, 1.0), 50)

	# Entrance lamps on the door bay (frame spans x 4.97..6.23), lifted to
	# y=2.55 so they clear the door leaf's 2.375 top. Building4's west cladding
	# overshoots its own mass and stands proud at x 6.25..6.75 from z 13 to 17,
	# so the lamps stay inside the bay rather than flanking it further out, and
	# sit 6cm proud of the glazing. Emissive geometry only; the actual falloff
	# is DoorGlow below.
	for i in 2:
		var lx := -2.42 + float(i) * 1.04
		mi("PizzaShop/Shop/Front", "EntryLamp%d" % i, Vector3(0.16, 0.3, 0.16), "lamp_glow", T(lx, 2.55, -2.28))
		mi("PizzaShop/Shop/Front", "EntryArm%d" % i, Vector3(0.08, 0.08, 0.26), "metal", T(lx, 2.55, -2.07))
	# Warm bar under the awning, over the door bay only. It hangs in front of the
	# sign band (z 16.67 vs the band's 16.78) and stops short of x=6.2, because
	# Building4's cladding fills everything east of that up to roof height.
	mi("PizzaShop/Shop/AwningS", "Strip", Vector3(1.2, 0.07, 0.07), "lamp_glow", T(-1.9, -0.12, 0.28))
	light("PizzaShop", "DoorGlow", Vector3(-1.9, 2.2, -2.7), Color(1, 0.84, 0.6), 0.8, 3.6)

	# No counter dressing behind the west glazing: GroundFloor and Walls are
	# solid CSG boxes, so anything placed inside them would be invisible. The
	# emissive glass_lit pane is what sells the window.

	# --- roof blade sign ---------------------------------------------------
	# Sits on the north-west roof corner at world (4.9, 0, 17.5). The panel plus
	# its rims reach 2.52m either side of the mast, which puts the east edge at
	# x=6.16 -- short of Building4's proud west cladding at 6.25 -- while the
	# 11.6m panel top stays under that building's 13m parapet. Because the whole
	# sign is west of Building4, the sight line from the road passes beside the
	# block rather than having to clear it.
	grp("PizzaShop", "Blade", T(-2.6, 0, -1.5))
	var bp := "PizzaShop/Blade"
	mi(bp, "Mast", Vector3(0.24, 6.0, 0.24), "pole", T(0, 9.4, 0))
	mi(bp, "Collar", Vector3(0.46, 0.24, 0.46), "metal", T(0, 6.62, 0))
	# cross of two panels, north and west, so it reads from the road and the
	# pavement. Back-to-back at +-0.06 they share the mast.
	mi(bp, "PanelN", Vector3(2.2, 4.3, 0.2), "pizza_glow", T(0, 9.3, -0.06))
	mi(bp, "PanelW", Vector3(0.2, 4.3, 2.2), "pizza_glow", T(-0.06, 9.3, 0))
	mi(bp, "RimTop", Vector3(2.36, 0.16, 0.3), "pizza_cream", T(0, 11.53, -0.02))
	mi(bp, "RimBot", Vector3(2.36, 0.16, 0.3), "pizza_cream", T(0, 7.07, -0.02))
	mi(bp, "RimW", Vector3(0.16, 4.62, 0.3), "pizza_cream", T(-1.18, 9.3, -0.02))
	mi(bp, "RimE", Vector3(0.16, 4.62, 0.3), "pizza_cream", T(1.18, 9.3, -0.02))
	# chunky stylised pie on the north face; boxes read as a pizza at distance
	# in a way a 0.1-scaled icon never can
	mi(bp, "PieCrust", Vector3(1.3, 1.3, 0.12), "pizza_cream", T(0, 10.55, -0.19))
	mi(bp, "PieSauce", Vector3(0.98, 0.98, 0.14), "pizza_red", T(0, 10.55, -0.22))
	mi(bp, "PieCheeseA", Vector3(0.24, 0.24, 0.16), "pizza_cheese", T(-0.24, 10.67, -0.25))
	mi(bp, "PieCheeseB", Vector3(0.24, 0.24, 0.16), "pizza_cheese", T(0.26, 10.45, -0.25))
	mi(bp, "PiePepA", Vector3(0.2, 0.2, 0.17), "pizza_red", T(0.18, 10.71, -0.26))
	mi(bp, "PiePepB", Vector3(0.2, 0.2, 0.17), "pizza_red", T(-0.2, 10.41, -0.26))
	label3d(bp, "TextN", "PIZZA", Vector3(0, 8.8, -0.24), 180.0, 0.016,
		Color(1, 0.96, 0.88), Color(0.42, 0.06, 0.04))
	label3d(bp, "TextW", "PIZZA", Vector3(-0.24, 8.8, 0), 270.0, 0.016,
		Color(1, 0.96, 0.88), Color(0.42, 0.06, 0.04))
	light(bp, "BladeGlow", Vector3(0, 9.3, -0.9), Color(1, 0.72, 0.48), 0.7, 5.5)

# --------------------------------------------------------------- main
func _initialize() -> void:
	_build()
	quit()

func _build() -> void:
	_nodes.clear()
	_subs.clear()
	_mid.clear()
	_mesh.clear()
	n_res = 0
	n_node = 0
	n_csg = 0
	n_mi = 0
	n_solid = 0
	n_light = 0
	n_label = 0
	n_tri = 0
	n_inst = 0
	_exts.clear()
	_extid.clear()

	for d in MATS:
		var name: String = d[0]
		var o: Dictionary = d[1]
		var id := "m_" + name
		_mid[name] = id
		var body: Array = ["albedo_color = " + cl(o["c"]), "roughness = " + f(o.get("r", 0.9))]
		if o.has("m"):
			body.append("metallic = " + f(o["m"]))
		if o.has("e"):
			body.append("emission_enabled = true")
			body.append("emission = " + cl(o["e"]))
			body.append("emission_energy_multiplier = " + f(o["ei"]))
		sub_res("StandardMaterial3D", id, body)

	var zone_shapes := [["ZoneShapeCar", Vector3(8, 3, 6)], ["ZoneShapeDog", Vector3(2.6, 3, 9)], ["ZoneShapeSmall", Vector3(2.4, 3, 3)]]
	for z in zone_shapes:
		sub_res("BoxShape3D", str(z[0]), ["size = " + v3(z[1])])
	sub_res("BoxShape3D", "GroundBox", ["size = Vector3(60, 2, 56)"])
	sub_res("ProceduralSkyMaterial", "sky_mat", [
		"sky_top_color = Color(0.29, 0.5, 0.79, 1)",
		"sky_horizon_color = Color(0.75, 0.82, 0.9, 1)",
		"ground_bottom_color = Color(0.2, 0.2, 0.22, 1)",
		"ground_horizon_color = Color(0.62, 0.68, 0.74, 1)",
		"sun_angle_max = 24.0"])
	sub_res("Sky", "sky", ["sky_material = SubResource(\"sky_mat\")"])
	sub_res("Environment", "env_main", [
		"background_mode = 2",
		"sky = SubResource(\"sky\")",
		"ambient_light_source = 3",
		"ambient_light_color = Color(0.72, 0.78, 0.88, 1)",
		"ambient_light_sky_contribution = 0.65",
		"ambient_light_energy = 1.0",
		"fog_enabled = true",
		"fog_light_color = Color(0.72, 0.79, 0.88, 1)",
		"fog_density = 0.0016",
		"fog_sky_affect = 0.0"])

	# --- environment -------------------------------------------------------
	node("WorldEnvironment", "WorldEnvironment", ".", Transform3D.IDENTITY, ["environment = SubResource(\"env_main\")"])
	node("DirectionalLight3D", "DirectionalLight3D", ".", Transform3D(Basis.looking_at(Vector3(-0.33, -0.86, -0.39), Vector3.UP), Vector3(0, 15, 0)), [
		"light_color = Color(1, 0.96, 0.89, 1)",
		"light_energy = 1.2",
		"shadow_enabled = true",
		"shadow_bias = 0.04",
		"shadow_normal_bias = 1.2",
		"directional_shadow_max_distance = 60.0"])

	# --- ground / street ---------------------------------------------------
	grp(".", "Ground")
	node("StaticBody3D", "Body", "Ground", T(0, -1.2, 0), ["collision_layer = 1", "collision_mask = 1"])
	scol_node("Ground/Body", "GroundBox")
	# The original street was: road slab (8,0.2,40) at y=-0.1 and two sidewalk
	# slabs (3,0.3,40) at x=+-5.5, all of them solid. Keep those exact numbers so
	# the walkable heights stay road=0.0 / sidewalk=0.15. The road slab is now
	# invisible: it is the collision body under the KayKit road tiles.
	sb(".", "Road", Vector3(8, 0.2, 40), "kk_asphalt", T(0, -0.1, 0), true, true)
	sb(".", "SidewalkLeft", Vector3(3, 0.3, 40), "sidewalk", T(-5.5, 0, 0), true)
	sb(".", "SidewalkRight", Vector3(3, 0.3, 40), "sidewalk", T(5.5, 0, 0), true)
	kk_roads()
	grp(".", "RoadDetails")
	grp(".", "Paving")
	grp(".", "Curbs")
	# The kerbs and paving joints are unbroken lines down both sides of the
	# block, so each run is one MultiMesh instead of sixteen little boxes.
	var kerbs: Array = []
	var joints: Array = []
	for i in 8:
		var cz := -17.5 + float(i) * 5.0
		kerbs.append(Vector3(-4.05, 0.02, cz))
		kerbs.append(Vector3(4.05, 0.02, cz))
		joints.append(Vector3(-5.5, 0.15, cz))
		joints.append(Vector3(5.5, 0.15, cz))
	mm_boxes("Curbs", "KerbStrip", Vector3(0.3, 0.36, 4.4), "kk_trim", kerbs)
	mm_boxes("Paving", "JointStrip", Vector3(2.9, 0.04, 0.14), "walk_tile", joints)
	# Lane markings now come from the road tile texture, so the old painted
	# dashes/crosswalk boxes are gone; the manholes stay as extra detail.
	manhole(-2.0, -6.0, 1)
	manhole(2.4, 12.0, 2)
	# building plots
	grp(".", "Plots")
	for e in [[-8, 15.5, 4, 5, 1], [-8, -16.5, 4, 5, -1], [9, 18.5, 5, 3, -1], [9, -13.0, 5, 4, -1]]:
		var en := "Plot%d" % int(absf(e[1]) * 10.0)
		var ep := "Plots/" + en
		grp("Plots", en, T(e[0], 0, e[1]))
		sb(ep, "Body", Vector3(e[2], 6.5, e[3]), "kk_wall2", T(0, 3.25, 0), true)
		sb(ep, "Cap", Vector3(e[2] + 0.3, 0.3, e[3] + 0.3), "kk_roof", T(0, 6.6, 0), false)
		sb(ep, "Band", Vector3(e[2] + 0.2, 0.16, e[3] + 0.2), "kk_trim", T(0, 2.6, 0), false)
		# KayKit panels on the street side plus a real 2x2 unit against the back.
		# All eight building kits are the same 2x2 footprint with their base at
		# y=0, so they drop straight onto the ground; spreading four plots across
		# eight of them stops the back lot repeating the same three silhouettes.
		clad_building(ep, e[2], e[3], 6.5, int(e[4]), false)
		var annex := Vector3(-float(e[4]) * (e[2] * 0.5 - 1.0), 0.0, 0.0)
		var kits := [["building_A", 464], ["building_B", 614], ["building_C", 577], ["building_D", 657],
			["building_E", 799], ["building_F", 791], ["building_G", 973], ["building_H", 1112]]
		var k: Array = kits[int(absf(e[1])) % kits.size()]
		inst(ep, "Unit", KK_CITY + String(k[0]) + ".gltf", T(annex.x, 0.0, annex.z), int(k[1]))

	# --- buildings ---------------------------------------------------------
	building("Building1", -8, 10, 4, 6, 10, "wall_tan", "wall_tan2", 1, true, "CAFE", "awning_red", true, 2, 3, 2)
	building("Building2", -8, 0, 4, 5, 7, "wall_blue", "wall_blue2", 1, false, "", "trim", false, 1, 2, 1)
	building("Building3", -8, -10, 4, 7, 4, "wall_tan", "wall_tan2", 1, true, "LAUNDRY", "awning_red", false, 0, 3, 0)
	building("Building4", 9, 13, 5, 5, 12, "wall_blue", "wall_blue2", -1, false, "", "trim", false, 3, 2, 2)
	building("Building5", 9, 4, 5, 6, 6, "wall_tan", "wall_tan2", -1, true, "MARKET", "awning_red", true, 1, 3, 1)
	building("Building6", 9, -7, 5, 8, 5, "wall_blue", "wall_blue2", -1, false, "", "trim", false, 1, 4, 1)

	# --- pizza shop --------------------------------------------------------
	grp(".", "PizzaShop", T(7.5, 0, 19))
	# Restaurant kit dressing: awning pillars at the door, a rooftop extraction
	# hood, and an outdoor seating nook north of the shop. Everything sits off
	# the delivery lane and clear of PizzaShopGoal at (7.2, 1, 15.4).
	inst("PizzaShop", "PillarW", KK_REST + "pillar_A.gltf", TS(-3.0, 0.15, -1.5, 0.8), 29)
	inst("PizzaShop", "PillarW2", KK_REST + "pillar_A.gltf", TS(-3.0, -0.2, 1.5, 0.8), 29)
	inst("PizzaShop", "Hood", KK_REST + "extractorhood.gltf", TS(1.4, 6.4, 0.4, 1.0), 210)
	inst("PizzaShop", "HoodDuct", KK_REST + "wall.gltf", TS(1.4, 8.0, 0.4, 1.0), 50)
	# The nook sits at z=22.2, past the end of the 40m road/sidewalk slabs, so
	# it stands on the bare Ground/Body surface at -0.2. Its barrel model has
	# its origin half a metre above its own base, hence the 0.5 local lift.
	grp("PizzaShop", "Nook", T(0.0, -0.2, 3.2))
	inst("PizzaShop/Nook", "TableA", KK_REST + "table_round_A.gltf", TS(-1.2, 0.0, 0.0, 1.0), 120)
	inst("PizzaShop/Nook", "TableB", KK_REST + "table_round_A_small.gltf", TS(1.4, 0.0, 0.4, 1.0), 96)
	for i in 4:
		inst("PizzaShop/Nook", "Chair%d" % i, KK_REST + ("chair_A" if i % 2 == 0 else "chair_B") + ".gltf",
			TRS(-1.2 + [-1.1, 1.1, -1.1, 1.1][i], 0.0, [0.0, 0.0, 1.5, -1.1][i] * 1.0, [0, 180, 90, 270][i], 1.0), 70)
	inst("PizzaShop/Nook", "CrateCheese", KK_REST + "crate_cheese.gltf", TRS(2.6, 0.0, -0.8, 20.0, 1.0), 130)
	inst("PizzaShop/Nook", "CrateTomato", KK_REST + "crate_tomatoes.gltf", TRS(2.6, 0.55, -0.8, 0.0, 1.0), 130)
	inst("PizzaShop/Nook", "Barrel", KK_PROTO + "Barrel_A.gltf", TS(-2.4, 0.5, -1.0, 1.0), 128)
	sb("PizzaShop", "GroundFloor", Vector3(6, 3.2, 4), "pizza_red", T(0, 1.6, 0), true)
	sb("PizzaShop", "Walls", Vector3(6, 2.8, 4), "wall_brick", T(0, 4.6, 0), true)
	sb("PizzaShop", "Base", Vector3(6.24, 0.5, 4.24), "trim_dark", T(0, 0.25, 0), false)
	sb("PizzaShop", "Cornice", Vector3(6.3, 0.3, 4.3), "pizza_cream", T(0, 5.85, 0), false)
	sb("PizzaShop", "Roof", Vector3(6.1, 0.4, 4.1), "roof", T(0, 6.2, 0), true)
	sb("PizzaShop", "RoofLip", Vector3(6.5, 0.26, 4.5), "trim_dark", T(0, 6.45, 0), false)
	sb("PizzaShop", "ParapetS", Vector3(6.5, 0.45, 0.24), "pizza_cream", T(0, 6.75, -2.2), false)
	sb("PizzaShop", "ParapetN", Vector3(6.5, 0.45, 0.24), "pizza_cream", T(0, 6.75, 2.2), false)
	sb("PizzaShop", "ParapetW", Vector3(0.24, 0.45, 4.5), "pizza_cream", T(-3.1, 6.75, 0), false)
	grp("PizzaShop", "Shop")
	grp("PizzaShop/Shop", "Front")
	var fpz := "PizzaShop/Shop/Front"
	mi(fpz, "GlassS", Vector3(4.7, 2.2, 0.18), "glass_lit", T(0, 1.6, -2.05))
	mi(fpz, "BarS", Vector3(0.12, 2.2, 0.2), "trim_dark", T(0, 1.6, -2.07))
	mi(fpz, "DoorFrameS", Vector3(1.26, 2.5, 0.2), "pizza_cream", T(-1.9, 1.3, -2.07))
	mi(fpz, "DoorS", Vector3(1.02, 2.25, 0.24), "door", T(-1.9, 1.25, -2.09))
	mi(fpz, "BandS", Vector3(5.5, 0.72, 0.28), "pizza_red", T(0, 3.12, -2.08))
	mi(fpz, "GlassW", Vector3(0.18, 2.2, 2.9), "glass_lit", T(-3.05, 1.6, 0))
	mi(fpz, "BarW", Vector3(0.2, 2.2, 0.12), "trim_dark", T(-3.07, 1.6, 0))
	mi(fpz, "BandW", Vector3(0.28, 0.72, 3.5), "pizza_red", T(-3.09, 3.12, 0))
	mi(fpz, "Open", Vector3(0.1, 0.36, 0.7), "neon", T(-3.12, 2.35, 0.9))
	label3d(fpz, "Sign", "PIZZA", Vector3(-0.9, 3.14, -2.26), 180.0, 0.014, Color(1, 0.95, 0.85), Color(0.35, 0.05, 0.04))
	# a Label3D draws on its local XY plane facing +z, so RY(180) looks north
	# down the road and RY(90) would look east, straight into the shopfront.
	# 270 turns this one out to the street on the west elevation.
	label3d(fpz, "SignW", "HOT SLICE", Vector3(-3.26, 3.14, 0), 270.0, 0.009, Color(1, 0.95, 0.85), Color(0.35, 0.05, 0.04))
	grp("PizzaShop/Shop", "AwningS", T(0, 3.52, -2.58))
	mi("PizzaShop/Shop/AwningS", "Slab", Vector3(5.6, 0.12, 1.5), "pizza_red", T(0, 0, 0))
	for s in 5:
		mi("PizzaShop/Shop/AwningS", "Stripe%d" % s, Vector3(0.5, 0.14, 1.52), "pizza_cream", T(-2.2 + float(s) * 1.1, 0, 0))
	mi("PizzaShop/Shop/AwningS", "Valance", Vector3(5.6, 0.4, 0.1), "pizza_cream", T(0, -0.2, 0.72))
	grp("PizzaShop/Shop", "AwningW", T(-3.58, 3.52, 0))
	mi("PizzaShop/Shop/AwningW", "Slab", Vector3(1.5, 0.12, 3.6), "pizza_red", T(0, 0, 0))
	for s in 3:
		mi("PizzaShop/Shop/AwningW", "Stripe%d" % s, Vector3(1.52, 0.14, 0.5), "pizza_cream", T(0, 0, -1.2 + float(s) * 1.2))
	mi("PizzaShop/Shop/AwningW", "Valance", Vector3(0.1, 0.4, 3.6), "pizza_cream", T(-0.72, -0.2, 0))
	grp("PizzaShop", "Windows")
	for i in 3:
		grp("PizzaShop/Windows", "U%d" % i, T(-1.7 + float(i) * 1.7, 4.75, -2.03))
		mi("PizzaShop/Windows/U%d" % i, "Frame", Vector3(1.2, 1.36, 0.12), "pizza_cream", T(0, 0, 0))
		mi("PizzaShop/Windows/U%d" % i, "Pane", Vector3(0.96, 1.12, 0.18), "glass_lit" if i == 1 else "glass", T(0, 0, 0))
	grp("PizzaShop", "RoofTop")
	scyl("PizzaShop/RoofTop", "Vent", 0.28, 0.9, "metal", T(-1.6, 6.85, 1.0), 8, false)
	mi("PizzaShop/RoofTop", "Hut", Vector3(1.6, 1.8, 1.6), "trim_dark", T(1.4, 7.3, 0.9))
	grp("PizzaShop", "Hanging", T(1.7, 3.05, -2.5))
	mi("PizzaShop/Hanging", "Arm", Vector3(0.09, 0.09, 0.9), "metal", T(0, 0, 0))
	mi("PizzaShop/Hanging", "Board", Vector3(0.12, 0.7, 1.0), "pizza_red", T(0, -0.85, 0))
	mi("PizzaShop/Hanging", "Slice", Vector3(0.16, 0.46, 0.6), "pizza_cheese", T(0, -0.85, 0))
	light("PizzaShop", "Warm", Vector3(0, 2.7, -2.7), Color(1, 0.8, 0.55), 0.9, 5.0)
	for i in 3:
		var pn := "WindowBox%d" % i
		grp("PizzaShop", pn, T(-2.2 + float(i) * 2.2, 0.15, -2.45))
		mi("PizzaShop/" + pn, "Box", Vector3(0.8, 0.4, 0.36), "wood", T(0, 0.2, 0))
		ssph("PizzaShop/" + pn, "Bush", 0.22, "leaf", T(0, 0.5, 0), false)
	# scripts/city_block.gd drives this node: it overwrites scale with
	# 0.1 * (1 + sin) and spins it. The original was a CSGCylinder3D of radius 3
	# and height 0.5 parked at (-1.5, 6.5, -2.2), so the art is modelled in those
	# same pre-scale units (effective size 0.3 radius) and keeps that anchor.
	grp("PizzaShop", "PizzaIcon", T(-1.5, 6.5, -2.2))
	node("CSGPolygon3D", "Slice", "PizzaShop/PizzaIcon", Transform3D.IDENTITY, [
		"polygon = PackedVector2Array(0, 0, 3.3, 0.72, 2.5, 2.88, 0.78, 2.88)",
		"depth = 0.5",
		"material = SubResource(\"%s\")" % _mid["pizza_cheese"],
		"use_collision = false"])
	n_csg += 1
	n_tri += 2
	mi("PizzaShop/PizzaIcon", "Crust", Vector3(0.85, 0.55, 3.5), "pizza_cream", T(0.1, 0, 1.6))
	mi("PizzaShop/PizzaIcon", "CrustTip", Vector3(0.7, 0.5, 0.7), "pizza_cream", T(3.2, 0, 0.55))
	mi("PizzaShop/PizzaIcon", "PepA", Vector3(0.6, 0.2, 0.6), "pizza_red", T(1.5, 0.3, 1.5))
	mi("PizzaShop/PizzaIcon", "PepB", Vector3(0.55, 0.2, 0.55), "pizza_red", T(2.5, 0.3, 0.9))
	mi("PizzaShop/PizzaIcon", "Leaf", Vector3(0.8, 0.16, 0.5), "leaf", T(1.2, 0.3, 0.6))
	mi("PizzaShop/PizzaIcon", "Cheese", Vector3(1.4, 0.18, 0.4), "yellow", T(2.1, 0.3, 2.0))
	# static bracket so the spinning sign reads as mounted, not floating
	mi("PizzaShop", "SignMast", Vector3(0.16, 1.9, 0.16), "metal", T(-1.5, 5.3, -2.2))
	mi("PizzaShop", "SignArm", Vector3(0.14, 0.14, 1.1), "metal", T(-1.5, 6.4, -1.8))
	# static decoration on the front sign band (not driven by any script)
	mi("PizzaShop", "SignDisc", Vector3(1.5, 0.12, 1.5), "pizza_cream", T(1.7, 3.16, -2.34))
	mi("PizzaShop", "SignDiscIn", Vector3(1.16, 0.1, 1.16), "pizza_red", T(1.7, 3.2, -2.34))
	pizza_polish()

	# --- street props ------------------------------------------------------
	grp(".", "StreetProps")
	streetlight(-6.5, -12.0, 1.0, 1)
	streetlight(-6.5, 0.0, 1.0, 2)
	streetlight(-6.5, 12.0, 1.0, 3)
	streetlight(6.5, -2.0, -1.0, 4)
	streetlight(6.5, 9.0, -1.0, 5)
	bench(-5.8, -8.0, 90.0, 1)
	bench(-5.8, 3.0, 90.0, 2)
	bin_at(-5.5, -15.0, 1)
	bin_at(5.5, -3.0, 2)
	bin_at(5.5, 14.0, 3)
	bin_at(-5.5, 6.9, 4)
	bin_at(5.5, -6.0, 5)
	tree(-5.0, -5.0, 1.0, 1)
	tree(5.0, -12.0, 0.9, 2)
	tree(-5.0, 16.0, 1.0, 3)
	tree(5.0, 7.0, 0.85, 4)
	tree(-5.0, 1.2, 0.8, 5)
	planter(5.5, 10.0, "Planter1")
	planter(-5.5, 1.5, "Planter2")
	planter(5.5, 5.5, "Planter3")
	# Four kerbside cars instead of two, so the block reads as a street people
	# park on. Each one stays on the same side as the car it follows, which
	# leaves the opposite two lanes clear of the box at every z the road test
	# samples. car_police was already named in the old code but never actually
	# placed, so this also finally puts it in the scene.
	parked_car(-2.6, -10.0, 0.0, "car_a", "ParkedCar1", "car_taxi")
	parked_car(2.6, 4.0, 180.0, "car_b", "ParkedCar2", "car_sedan")
	parked_car(-2.7, 12.0, 0.0, "car_a", "ParkedCar3", "car_police")
	parked_car(2.7, -14.0, 180.0, "car_b", "ParkedCar4", "car_hatchback")
	hydrant()
	mailbox()
	stop_sign()
	barrier(-6.8, -18.0, 1.0, "Barrier1")
	barrier(6.8, -18.0, -1.0, "Barrier2")
	utility(-5.4, -2.2, "Utility1", 0.7, 1.0, 0.5)
	utility(5.4, 8.0, "Utility2", 0.6, 0.9, 0.45)
	utility(-5.4, 12.5, "Utility3", 0.55, 0.85, 0.4)
	kk_clutter()
	# facade clutter
	grp(".", "FacadeBits")
	var units := [["B1", -5.96, 7.6, 3.5], ["B2", -5.96, -1.6, 2.2], ["B3", -5.96, -12.0, 1.7],
		["B4", 6.46, 11.0, 3.2], ["B5", 6.46, 6.4, 2.1], ["B6", 6.46, -9.0, 2.1]]
	for i in units.size():
		var un := "AC%d" % i
		grp("FacadeBits", un, T(units[i][1], 0, units[i][2]))
		# The unit box carries the read; the fan slat and the drain pipe behind
		# it were sub-decimetre details that cost a node apiece.
		mi("FacadeBits/" + un, "Unit", Vector3(0.44, 0.62, 0.72), "metal_light", T(0, units[i][3], 0))
	for i2 in 3:
		var pn2 := "Downpipe%d" % i2
		grp("FacadeBits", pn2, T(-5.94 if i2 % 2 == 0 else 6.44, 0, [8.6, -2.2, 14.6][i2]))
		scyl("FacadeBits/" + pn2, "Pipe", 0.1, 5.0, "metal", T(0, 2.5, 0), 8, false)

	# --- markers -----------------------------------------------------------
	# The goal centre sits inside the Building4 footprint, so its ground decal is
	# offset onto the open sidewalk tile in front of the shop door.
	node("Marker3D", "PlayerSpawn", ".", T(0, 0.2, -17))
	grp("PlayerSpawn", "Ring")
	storus("PlayerSpawn/Ring", "Ring", 0.85, 1.05, "marker_spawn", T(0, -0.18, 0))
	mi("PlayerSpawn/Ring", "Arrow", Vector3(0.5, 0.04, 0.9), "marker_spawn", T(0, -0.17, 0.55))
	mi("PlayerSpawn/Ring", "Arrow2", Vector3(1.0, 0.04, 0.4), "marker_spawn", T(0, -0.17, 1.0))
	node("Marker3D", "PizzaShopGoal", ".", T(7.2, 1.0, 15.4))
	grp("PizzaShopGoal", "Pad")
	scyl("PizzaShopGoal/Pad", "Disc", 1.75, 0.03, "marker_goal", T(-2.0, -0.83, 0.0), 16, false)
	storus("PizzaShopGoal/Pad", "Ring", 1.5, 1.75, "marker_goal", T(-2.0, -0.8, 0.0))
	mi("PizzaShopGoal/Pad", "Arrow", Vector3(0.5, 0.04, 1.4), "marker_goal", T(-2.0, -0.78, 0.3))
	mi("PizzaShopGoal/Pad", "Head", Vector3(1.2, 0.04, 0.8), "marker_goal", T(-2.0, -0.78, 1.3))
	grp("PizzaShopGoal", "Beam")
	mi("PizzaShopGoal/Beam", "Post", Vector3(0.1, 1.4, 0.1), "metal", T(-2.0, 0.9, -1.6))
	mi("PizzaShopGoal/Beam", "Flag", Vector3(0.06, 0.4, 0.6), "marker_goal", T(-2.0, 1.5, -1.6))
	mi("PizzaShopGoal/Beam", "Arrow3", Vector3(0.4, 0.04, 1.2), "marker_goal", T(-2.0, 0.2, -0.9))

	# --- disaster zones (positions and shapes unchanged) -------------------
	grp(".", "DisasterZones")
	var zones := [
		["CarAttackZone", T(0, 0.5, -8), "ZoneShapeCar", Vector3(6, 0.04, 5), Vector3(6, 0.06, 5)],
		["FallingObjectZone", T(-5.5, 0.5, 10), "ZoneShapeSmall", Vector3(3.2, 0.04, 3.2), Vector3(2.5, 0.06, 2.5)],
		["DogChaseZone", T(5.5, 0.5, 0), "ZoneShapeDog", Vector3(2.4, 0.04, 8.6), Vector3(2.5, 0.06, 8.6)],
		["ObstacleZone1", T(-5.5, 0.5, -3), "ZoneShapeSmall", Vector3(2.2, 0.04, 2.6), Vector3(2.2, 0.06, 2.6)],
		["ObstacleZone2", T(5.5, 0.5, -15), "ZoneShapeSmall", Vector3(2.2, 0.04, 2.6), Vector3(2.2, 0.06, 2.6)],
		["ObstacleZone3", T(-5.5, 0.5, 13), "ZoneShapeSmall", Vector3(2.2, 0.04, 2.6), Vector3(2.2, 0.06, 2.6)],
	]
	for z in zones:
		var zn: String = z[0]
		node("Area3D", zn, "DisasterZones", z[1], ["monitoring = false", "monitorable = false"])
		scol_node("DisasterZones/" + zn, str(z[2]))
		sb("DisasterZones/" + zn, "VisualMarker", z[3], "hazard", T(0, -0.33, 0), true)
		var hv: Vector3 = z[4]
		for e in 4:
			var ex := (hv.x * 0.5 - 0.8) if e % 2 == 0 else (-hv.x * 0.5 + 0.8)
			var ez := (hv.z * 0.5 - 0.45) if e < 2 else (-hv.z * 0.5 + 0.45)
			mi("DisasterZones/" + zn, "Hatch%d" % e, Vector3(1.1, 0.03, 0.2), "hatch", T(ex, -0.3, ez))
	grp("DisasterZones", "LockedDoorArea", Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(-5.5, 1.35, 5)))
	var lp := "DisasterZones/LockedDoorArea"
	sb(lp, "Wall", Vector3(3.8, 2.9, 0.4), "wall_brick", T(0, 0, -0.62), true)
	sb(lp, "Door", Vector3(2.8, 2.4, 0.25), "wall_tan2", T(0, 0, 0), true)
	mi(lp, "Frame", Vector3(3.0, 2.6, 0.1), "trim", T(0, 0, -0.16))
	mi(lp, "Panel", Vector3(1.0, 0.9, 0.06), "door", T(-0.7, 0.4, -0.2))
	mi(lp, "PanelB", Vector3(1.0, 0.9, 0.06), "door", T(0.7, 0.4, -0.2))
	mi(lp, "Step", Vector3(3.2, 0.18, 0.7), "curb", T(0, -1.3, -0.32))
	mi(lp, "LockPlate", Vector3(0.36, 0.42, 0.05), "trim_dark", T(0.45, 0, -0.2))
	mi(lp, "Lock", Vector3(0.18, 0.24, 0.07), "yellow", T(0.45, 0, -0.24))
	mi(lp, "Doormat", Vector3(1.2, 0.05, 0.6), "grate", T(0, -1.2, -0.5))
	mi(lp, "Canopy", Vector3(3.4, 0.12, 0.8), "metal", T(0, 1.5, -0.5))

	grp(".", "CameraAnchor", Transform3D(Basis(Vector3.RIGHT, deg_to_rad(-30.0)), Vector3(0, 5, -8)))

	# --- write -------------------------------------------------------------
	var head := "[gd_scene load_steps=%d format=3]\n\n" % (n_res + n_ext + 2)
	head += "[ext_resource type=\"Script\" path=\"res://scripts/city_block.gd\" id=\"1_city\"]\n\n"
	if n_ext > 0:
		head += "\n".join(_exts) + "\n\n"
	head += "\n".join(_subs)
	head += "\n[node name=\"CityBlock\" type=\"Node3D\"]\nscript = ExtResource(\"1_city\")\n\n"
	head += "\n".join(_nodes)
	var fh := FileAccess.open(OUT, FileAccess.WRITE)
	fh.store_string(head)
	fh.close()
	print("WROTE %s res=%d ext=%d inst=%d nodes=%d csg=%d mi=%d solid=%d lights=%d labels=%d est_tris=%d" % [
		OUT, n_res, n_ext, n_inst, n_node, n_csg, n_mi, n_solid, n_light, n_label, n_tri])
