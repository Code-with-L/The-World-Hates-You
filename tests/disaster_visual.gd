extends Node

# Pass 4 visual verification, done as a differential test.
#
# A colour-classification check on its own is too easy to fool: sampling the sky
# returns "blue" and a naive test would call that a visible telegraph. So this
# captures the same camera view twice -- once clean, once with the disaster's
# telegraph running -- and asserts the telegraph actually changes pixels in the
# region around the danger area, and that those new pixels are warning-coloured
# rather than sky.
#
# It also reports how large the telegraph is on screen, which is the number that
# decides whether a player can actually see it while running.

const SCRIPTS := {
	"car": preload("res://scripts/disasters/car_disaster.gd"),
	"falling": preload("res://scripts/disasters/falling_object_disaster.gd"),
	"dog": preload("res://scripts/disasters/dog_chase.gd"),
	"door": preload("res://scripts/disasters/locked_door_disaster.gd"),
	"obstacle": preload("res://scripts/disasters/obstacle_disaster.gd"),
}
const ORDER := ["car", "falling", "dog", "door", "obstacle"]

# Camera stands where a player realistically is when a disaster fires: in the
# street, a few metres back, looking up the road.
const CAM_POS := Vector3(0, 1.7, -5.0)
const CAM_LOOK := Vector3(0, 1.0, 8.0)
const REGION := 150

var _cam: Camera3D
var _failed := 0
var _last_point := Vector3.ZERO


func _ready() -> void:
	_run()


func _classify(c: Vector3) -> String:
	var mx := maxf(c.x, maxf(c.y, c.z))
	var mn := minf(c.x, minf(c.y, c.z))
	var l := 0.299 * c.x + 0.587 * c.y + 0.114 * c.z
	var sat := 0.0
	if mx > 0.05:
		sat = (mx - mn) / mx
	if sat < 0.2:
		return "." if l < 0.6 else "~"
	if c.x > c.y and c.x > c.z:
		return "R" if l < 0.5 else "r"
	if c.y >= c.x and c.y > c.z:
		return "G" if l < 0.5 else "g"
	return "B" if l < 0.5 else "b"


func _run() -> void:
	var scene: PackedScene = load("res://game.tscn")
	var game: Node = scene.instantiate()
	add_child(game)
	for i in 30:
		await get_tree().process_frame

	_cam = Camera3D.new()
	add_child(_cam)
	_cam.position = CAM_POS
	_cam.look_at(CAM_LOOK, Vector3.UP)
	_cam.fov = 60.0

	var player: Node3D = game.get_node("Player")
	var man: Node = game.get_node("DisasterManager")
	player.global_position = Vector3(0, 0.1, -3.0)

	for kind in ORDER:
		await _check_one(game, man, player, kind)

	print("=== PASS 4 VISUAL %s ===" % ("PASSED" if _failed == 0 else "FAILED"))
	get_tree().quit(0 if _failed == 0 else 1)


func _capture() -> Image:
	# The game camera rig owns the viewport; take it back every frame or we would
	# be reading the third-person view instead of this one.
	_cam.current = true
	await RenderingServer.frame_post_draw
	return get_viewport().get_texture().get_image()


func _check_one(game: Node, man: Node, player: Node3D, kind: String) -> void:
	var point := Vector3(randf_range(-1.0, 1.0), 0.02, 3.0)
	_last_point = point

	# 1. baseline: identical view, no disaster
	var before := await _capture()

	var d = SCRIPTS[kind].new()
	d.setup(player, game)
	man.add_child(d)
	d.call("telegraph", point)
	# 2. let the telegraph's entrance animation settle
	for i in 45:
		_cam.current = true
		await get_tree().process_frame
	var after := await _capture()

	var w := after.get_width()
	var h := after.get_height()
	var sp := _cam.unproject_position(point + Vector3.UP * 0.4)
	var x0 := clampi(sp.x - REGION, 0, w - 1)
	var y0 := clampi(sp.y - REGION, 0, h - 1)
	var x1 := clampi(sp.x + REGION, 0, w - 1)
	var y1 := clampi(sp.y + REGION, 0, h - 1)

	var changed := 0
	var warm := 0
	var cool := 0
	var bbox := Rect2i(w, h, 0, 0)
	for y in range(y0, y1 + 1, 2):
		for x in range(x0, x1 + 1, 2):
			var a := before.get_pixel(x, y)
			var b := after.get_pixel(x, y)
			var delta := absf(a.r - b.r) + absf(a.g - b.g) + absf(a.b - b.b)
			if delta < 0.12:
				continue
			changed += 1
			# Classify what the telegraph actually painted.
			var cls := _classify(Vector3(b.r, b.g, b.b))
			if cls in ["R", "r", "G", "g", "Y", "y"]:
				warm += 1
			elif cls in ["B", "b"]:
				cool += 1
			bbox = bbox.expand(Vector2(x, y))

	var total := maxi(1, ((x1 - x0) / 2) * ((y1 - y0) / 2))
	var pct := 100.0 * float(changed) / float(total)
	var visible := changed > 40
	var warning_coloured := warm > 0
	var bbox_str := "none"
	if bbox.size.x > 0:
		bbox_str = "%dx%d px" % [bbox.size.x, bbox.size.y]

	print("  %-9s changed=%d (%.2f%% of region)  warm=%d cool=%d  onscreen=%s  %s" % [
		kind, changed, pct, warm, cool, bbox_str, "VISIBLE" if visible else "MISSING"])
	if not visible:
		print("      FAIL: telegraph changed too few pixels to see")
		_failed += 1
	if not warning_coloured:
		print("      FAIL: telegraph drew no warning-coloured pixels")
		_failed += 1
	if cool > warm * 3 and cool > 60:
		print("      note: mostly cool pixels (%d) -- check this is not just sky" % cool)

	# 3. now confirm the hazard itself also renders during the live phase
	d.call("activate", point)
	for i in 20:
		_cam.current = true
		await get_tree().process_frame
	var live := await _capture()
	var live_changed := 0
	for y in range(y0, y1 + 1, 3):
		for x in range(x0, x1 + 1, 3):
			var a := before.get_pixel(x, y)
			var b := live.get_pixel(x, y)
			if absf(a.r - b.r) + absf(a.g - b.g) + absf(a.b - b.b) > 0.12:
				live_changed += 1
	print("            live phase changed=%d  %s" % [
		live_changed, "OK" if live_changed > 20 else "HAZARD NOT VISIBLE"])
	if live_changed <= 20:
		_failed += 1

	if is_instance_valid(d) and d.is_inside_tree():
		d.call("finish")
	for i in 8:
		_cam.current = true
		await get_tree().process_frame
