extends Node

const SHOTS := [
	{"name": "overview", "pos": Vector3(0, 13, -27), "look": Vector3(0, 2, 6), "fov": 60.0},
	{"name": "building1", "pos": Vector3(-1.5, 3.5, 4.0), "look": Vector3(-8.0, 4.0, 11.0), "fov": 65.0},
	{"name": "pizzashop", "pos": Vector3(2.0, 2.2, 12.5), "look": Vector3(7.5, 2.2, 19.0), "fov": 65.0},
	{"name": "street", "pos": Vector3(0.0, 1.7, -14.0), "look": Vector3(1.0, 1.2, 6.0), "fov": 70.0},
]

const RAMP := " .:-=+*#%@"

var _cam: Camera3D
var _out := ""


func _ready() -> void:
	_run()


func _classify(r: float, g: float, b: float, l: float) -> String:
	var mx := maxf(r, maxf(g, b))
	var mn := minf(r, minf(g, b))
	var sat := 0.0
	if mx > 0.05:
		sat = (mx - mn) / mx
	if l > 0.72 and sat < 0.22:
		return "~"
	if sat < 0.18:
		return "."
	if b > r and b > g:
		return "B" if l < 0.5 else "b"
	if g >= r and g > b:
		return "G" if l < 0.5 else "g"
	if r > g and r > b:
		return "R" if l < 0.5 else "r"
	return "y"


func _stats(img: Image) -> void:
	if img.is_compressed():
		img.decompress()
	var w := img.get_width()
	var h := img.get_height()
	var lum := PackedFloat32Array()
	lum.resize(w * h)
	var uniq := {}
	var dom := {}
	var sat_count := 0
	var lsum := 0.0
	var l2sum := 0.0
	for y in h:
		for x in w:
			var c := img.get_pixel(x, y)
			var i := y * w + x
			var l := 0.299 * c.r + 0.587 * c.g + 0.114 * c.b
			lum[i] = l
			lsum += l
			l2sum += l * l
			uniq[(int(c.r * 23.0) << 10) | (int(c.g * 23.0) << 5) | int(c.b * 23.0)] = true
			dom[(int(c.r * 7.0) << 6) | (int(c.g * 7.0) << 3) | int(c.b * 7.0)] = int(dom.get((int(c.r * 7.0) << 6) | (int(c.g * 7.0) << 3) | int(c.b * 7.0), 0)) + 1
			var mx := maxf(c.r, maxf(c.g, c.b))
			var mn := minf(c.r, minf(c.g, c.b))
			if mx > 0.1 and (mx - mn) / mx > 0.4:
				sat_count += 1
	var edge := 0
	var total := 0
	for y in range(1, h - 1):
		for x in range(1, w - 1):
			var gx := lum[y * w + x + 1] - lum[y * w + x - 1]
			var gy := lum[(y + 1) * w + x] - lum[(y - 1) * w + x]
			total += 1
			if absf(gx) + absf(gy) > 0.10:
				edge += 1
	var mean := lsum / float(w * h)
	var sd := sqrt(maxf(0.0, l2sum / float(w * h) - mean * mean))
	var top := []
	for k in dom.keys():
		top.append([dom[k], k])
	top.sort_custom(func(a, b): return a[0] > b[0])
	var top_s := []
	for i in mini(6, top.size()):
		var k: int = top[i][1]
		top_s.append("rgb(%.2f,%.2f,%.2f):%.1f%%" % [float((k >> 6) & 7) / 7.0, float((k >> 3) & 7) / 7.0, float(k & 7) / 7.0, 100.0 * top[i][0] / float(w * h)])
	_out += "  lum_mean=%.3f lum_sd=%.3f unique_colors=%d edge_density=%.4f saturated=%.3f\n" % [mean, sd, uniq.size(), float(edge) / float(total), float(sat_count) / float(w * h)]
	_out += "  dominant: %s\n" % ", ".join(top_s)
	var cols := 96
	var rows := 30
	var art := "\n"
	var cls := "\n"
	var by := float(h) / float(rows)
	var bx := float(w) / float(cols)
	for ry in rows:
		var line := ""
		var cline := ""
		for rx in cols:
			var sl := 0.0
			var sr := 0.0
			var sg := 0.0
			var sb := 0.0
			var n := 0
			var y0 := int(ry * by)
			var y1 := mini(h, int((ry + 1) * by))
			var x0 := int(rx * bx)
			var x1 := mini(w, int((rx + 1) * bx))
			for y in range(y0, y1, 2):
				for x in range(x0, x1, 2):
					sl += lum[y * w + x]
					var c := img.get_pixel(x, y)
					sr += c.r
					sg += c.g
					sb += c.b
					n += 1
			if n == 0:
				n = 1
			var al := sl / float(n)
			line += RAMP[clampi(int(al * (RAMP.length() - 1)), 0, RAMP.length() - 1)]
			cline += _classify(sr / float(n), sg / float(n), sb / float(n), al)
		art += "  |" + line + "|\n"
		cls += "  |" + cline + "|\n"
	_out += art + cls


func _shot(shot: Dictionary) -> void:
	_cam.position = shot["pos"]
	_cam.look_at(shot["look"], Vector3.UP)
	_cam.fov = shot["fov"]
	_cam.current = true
	for i in 3:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png("user://vis_%s.png" % shot["name"])
	_out += "== %s ==\n" % shot["name"]
	var probes := {"center": Vector2(0.5, 0.5), "upper": Vector2(0.5, 0.3), "lower": Vector2(0.5, 0.8), "left": Vector2(0.18, 0.5), "right": Vector2(0.82, 0.5)}
	var ps := []
	for k in probes.keys():
		var px: Vector2 = probes[k]
		var acc := Vector3.ZERO
		var cnt := 0
		for dy in range(-6, 7, 3):
			for dx in range(-6, 7, 3):
				var c := img.get_pixel(clampi(int(img.get_width() * px.x) + dx, 0, img.get_width() - 1), clampi(int(img.get_height() * px.y) + dy, 0, img.get_height() - 1))
				acc += Vector3(c.r, c.g, c.b)
				cnt += 1
		acc /= float(cnt)
		ps.append("%s=%.2f/%.2f/%.2f" % [k, acc.x, acc.y, acc.z])
	_out += "  probe: " + ", ".join(ps) + "\n"
	_stats(img)


func _run() -> void:
	var scene: PackedScene = load("res://game.tscn")
	var game: Node = scene.instantiate()
	add_child(game)
	for i in 30:
		await get_tree().process_frame
	_cam = Camera3D.new()
	add_child(_cam)
	for shot in SHOTS:
		await _shot(shot)
	_cam.queue_free()
	var f := FileAccess.open("user://frame_stats.txt", FileAccess.WRITE)
	f.store_string(_out)
	f.close()
	print("STATS_WRITTEN user://frame_stats.txt")
	print(_out)
	get_tree().quit()
