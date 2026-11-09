class_name PixelCanvas
extends RefCounted
## Tiny anti-aliased rasterizer for placeholder art (editor/tool use only).
## Coordinates are y-UP. `origin` shifts every drawing call, so equipment can be drawn
## in the princess's coordinate space and cropped around its slot anchor.

var width: int
var height: int
var origin := Vector2.ZERO
var _px: PackedColorArray


func _init(w: int, h: int) -> void:
	width = w
	height = h
	_px = PackedColorArray()
	_px.resize(w * h)
	_px.fill(Color(0, 0, 0, 0))


func blend(x: int, y: int, c: Color, coverage := 1.0) -> void:
	if x < 0 or y < 0 or x >= width or y >= height:
		return
	var a := clampf(c.a * coverage, 0.0, 1.0)
	if a <= 0.0:
		return
	var i := y * width + x
	var d := _px[i]
	var out_a := a + d.a * (1.0 - a)
	if out_a <= 0.0:
		return
	var r := (c.r * a + d.r * d.a * (1.0 - a)) / out_a
	var g := (c.g * a + d.g * d.a * (1.0 - a)) / out_a
	var b := (c.b * a + d.b * d.a * (1.0 - a)) / out_a
	_px[i] = Color(r, g, b, out_a)


func ellipse(cx: float, cy: float, rx: float, ry: float, c: Color) -> void:
	cx += origin.x
	cy += origin.y
	if rx <= 0 or ry <= 0:
		return
	var min_r := minf(rx, ry)
	for y in range(floori(cy - ry - 1), ceili(cy + ry + 1) + 1):
		for x in range(floori(cx - rx - 1), ceili(cx + rx + 1) + 1):
			var dx := (x + 0.5 - cx) / rx
			var dy := (y + 0.5 - cy) / ry
			var edge := (1.0 - sqrt(dx * dx + dy * dy)) * min_r
			blend(x, y, c, clampf(edge + 0.5, 0.0, 1.0))


func circle(cx: float, cy: float, r: float, c: Color) -> void:
	ellipse(cx, cy, r, r, c)


func rect(x0: float, y0: float, x1: float, y1: float, c: Color) -> void:
	x0 += origin.x; x1 += origin.x; y0 += origin.y; y1 += origin.y
	for y in range(floori(y0), ceili(y1)):
		for x in range(floori(x0), ceili(x1)):
			var cov := _overlap(x, x + 1, x0, x1) * _overlap(y, y + 1, y0, y1)
			blend(x, y, c, cov)


func round_rect(x0: float, y0: float, x1: float, y1: float, radius: float, c: Color) -> void:
	x0 += origin.x; x1 += origin.x; y0 += origin.y; y1 += origin.y
	radius = minf(radius, minf((x1 - x0) * 0.5, (y1 - y0) * 0.5))
	var mx := (x0 + x1) * 0.5
	var my := (y0 + y1) * 0.5
	for y in range(floori(y0), ceili(y1)):
		for x in range(floori(x0), ceili(x1)):
			var qx := maxf(absf(x + 0.5 - mx) - ((x1 - x0) * 0.5 - radius), 0.0)
			var qy := maxf(absf(y + 0.5 - my) - ((y1 - y0) * 0.5 - radius), 0.0)
			var dist := sqrt(qx * qx + qy * qy) - radius
			blend(x, y, c, clampf(0.5 - dist, 0.0, 1.0))


func tri(a: Vector2, b: Vector2, d: Vector2, c: Color) -> void:
	a += origin; b += origin; d += origin
	var x0 := floori(minf(a.x, minf(b.x, d.x))) - 1
	var x1 := ceili(maxf(a.x, maxf(b.x, d.x))) + 1
	var y0 := floori(minf(a.y, minf(b.y, d.y))) - 1
	var y1 := ceili(maxf(a.y, maxf(b.y, d.y))) + 1
	var poly := PackedVector2Array([a, b, d])
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			var inside := 0
			for s in 4:
				var p := Vector2(x + 0.25 + 0.5 * (s % 2), y + 0.25 + 0.5 * (s / 2))
				if Geometry2D.is_point_in_polygon(p, poly):
					inside += 1
			if inside > 0:
				blend(x, y, c, inside / 4.0)


func quad(a: Vector2, b: Vector2, d: Vector2, e: Vector2, c: Color) -> void:
	tri(a, b, d, c)
	tri(a, d, e, c)


func line(from: Vector2, to: Vector2, thickness: float, c: Color) -> void:
	var dir := to - from
	if dir.length_squared() < 0.0001:
		return
	var n := Vector2(-dir.y, dir.x).normalized() * thickness * 0.5
	quad(from + n, to + n, to - n, from - n, c)


func to_image() -> Image:
	var img := Image.create(width, height, false, Image.FORMAT_RGBA8)
	for y in height:
		for x in width:
			img.set_pixel(x, height - 1 - y, _px[y * width + x]) # y-up -> y-down
	return img


func save_png(path: String) -> Error:
	return to_image().save_png(path)


static func _overlap(a0: float, a1: float, b0: float, b1: float) -> float:
	return clampf(minf(a1, b1) - maxf(a0, b0), 0.0, 1.0)
