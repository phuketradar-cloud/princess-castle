class_name SheetCutter
## Turns an AI "character parts sheet" into usable sprites:
##  - remove_checkerboard(): many AI tools PAINT a fake transparency checkerboard. Pixels that
##    are light + grey and connected to the image border (or that form enclosed regions with
##    both checker tones) become transparent; light grey fringe next to them is cleaned too.
##  - components(): bounding boxes of every separate part (8-connected opaque pixels).
## Used by tools/build_princess_art.gd. Offline only.


static func _is_checker(c: Color) -> bool:
	var v := maxf(c.r, maxf(c.g, c.b))
	var s := v - minf(c.r, minf(c.g, c.b))
	return s < 0.045 and v > 0.84


## Returns a copy (RGBA8) with the painted checkerboard made transparent.
static func remove_checkerboard(src: Image) -> Image:
	var img := src.duplicate() as Image
	img.convert(Image.FORMAT_RGBA8)
	var w := img.get_width()
	var h := img.get_height()
	var cand := PackedByteArray()
	cand.resize(w * h)
	for y in h:
		for x in w:
			cand[y * w + x] = 1 if _is_checker(img.get_pixel(x, y)) else 0
	var bg := PackedByteArray()
	bg.resize(w * h)
	bg.fill(0)
	# 1) flood from the border
	var stack := PackedInt32Array()
	for x in w:
		stack.append(x)
		stack.append((h - 1) * w + x)
	for y in h:
		stack.append(y * w)
		stack.append(y * w + w - 1)
	_flood(stack, cand, bg, w, h, 1)
	# 2) enclosed checker pockets (e.g. between hair strands): need both checker tones
	var seen := PackedByteArray()
	seen.resize(w * h)
	seen.fill(0)
	for i in w * h:
		if cand[i] == 0 or bg[i] == 1 or seen[i] == 1:
			continue
		var region := _collect(i, cand, bg, seen, w, h)
		if region.size() < 120:
			continue
		var dark := 0
		for p in region:
			var c := img.get_pixel(p % w, p / w)
			if maxf(c.r, maxf(c.g, c.b)) < 0.95:
				dark += 1
		var f := float(dark) / region.size()
		if f > 0.15 and f < 0.85:
			for p in region:
				bg[p] = 1
	# 3) defringe: light grey anti-aliasing pixels touching the background
	for _pass in 2:
		var add := PackedInt32Array()
		for y in range(1, h - 1):
			for x in range(1, w - 1):
				var i := y * w + x
				if bg[i] == 1:
					continue
				if bg[i - 1] + bg[i + 1] + bg[i - w] + bg[i + w] == 0:
					continue
				var c := img.get_pixel(x, y)
				var v := maxf(c.r, maxf(c.g, c.b))
				if v > 0.72 and v - minf(c.r, minf(c.g, c.b)) < 0.09:
					add.append(i)
		for i in add:
			bg[i] = 1
	for i in w * h:
		if bg[i] == 1:
			img.set_pixel(i % w, i / w, Color(0, 0, 0, 0))
	return img


static func _flood(stack: PackedInt32Array, cand: PackedByteArray, mark: PackedByteArray, w: int, h: int, value: int) -> void:
	while not stack.is_empty():
		var i := stack[stack.size() - 1]
		stack.resize(stack.size() - 1)
		if mark[i] == value or cand[i] == 0:
			continue
		mark[i] = value
		var x := i % w
		var y := i / w
		if x > 0: stack.append(i - 1)
		if x < w - 1: stack.append(i + 1)
		if y > 0: stack.append(i - w)
		if y < h - 1: stack.append(i + w)


static func _collect(start: int, cand: PackedByteArray, bg: PackedByteArray, seen: PackedByteArray, w: int, h: int) -> PackedInt32Array:
	var out := PackedInt32Array()
	var stack := PackedInt32Array([start])
	while not stack.is_empty():
		var i := stack[stack.size() - 1]
		stack.resize(stack.size() - 1)
		if seen[i] == 1 or cand[i] == 0 or bg[i] == 1:
			continue
		seen[i] = 1
		out.append(i)
		var x := i % w
		var y := i / w
		if x > 0: stack.append(i - 1)
		if x < w - 1: stack.append(i + 1)
		if y > 0: stack.append(i - w)
		if y < h - 1: stack.append(i + w)
	return out


## Bounding boxes (Rect2i) of opaque parts with at least min_area pixels, top-to-bottom.
static func components(img: Image, min_area := 40) -> Array:
	var w := img.get_width()
	var h := img.get_height()
	var solid := PackedByteArray()
	solid.resize(w * h)
	for y in h:
		for x in w:
			solid[y * w + x] = 1 if img.get_pixel(x, y).a > 0.1 else 0
	var seen := PackedByteArray()
	seen.resize(w * h)
	seen.fill(0)
	var out := []
	for i in w * h:
		if solid[i] == 0 or seen[i] == 1:
			continue
		var minx := w
		var miny := h
		var maxx := 0
		var maxy := 0
		var area := 0
		var stack := PackedInt32Array([i])
		while not stack.is_empty():
			var j := stack[stack.size() - 1]
			stack.resize(stack.size() - 1)
			if seen[j] == 1 or solid[j] == 0:
				continue
			seen[j] = 1
			area += 1
			var x := j % w
			var y := j / w
			minx = mini(minx, x); maxx = maxi(maxx, x); miny = mini(miny, y); maxy = maxi(maxy, y)
			for dy: int in [-1, 0, 1]:
				for dx: int in [-1, 0, 1]:
					var nx := x + dx
					var ny := y + dy
					if nx >= 0 and ny >= 0 and nx < w and ny < h:
						stack.append(ny * w + nx)
		if area >= min_area:
			out.append({"rect": Rect2i(minx, miny, maxx - minx + 1, maxy - miny + 1), "area": area})
	out.sort_custom(func(a, b): return a.rect.position.y * 10000 + a.rect.position.x < b.rect.position.y * 10000 + b.rect.position.x)
	return out


## Keeps only opaque islands whose bounding box lies inside `keep` (sheet coords), i.e. the
## parts that belong to one figure, and clears everything else (neighbouring parts' tips).
static func isolate(img: Image, keep: Rect2i) -> void:
	var w := img.get_width()
	var h := img.get_height()
	var label := PackedInt32Array()
	label.resize(w * h)
	label.fill(-1)
	var inside := []
	var next := 0
	for i in w * h:
		if label[i] != -1 or img.get_pixel(i % w, i / w).a <= 0.1:
			continue
		var minp := Vector2i(w, h)
		var maxp := Vector2i(0, 0)
		var stack := PackedInt32Array([i])
		while not stack.is_empty():
			var j := stack[stack.size() - 1]
			stack.resize(stack.size() - 1)
			if label[j] != -1:
				continue
			var x := j % w
			var y := j / w
			if img.get_pixel(x, y).a <= 0.1:
				continue
			label[j] = next
			minp = Vector2i(mini(minp.x, x), mini(minp.y, y))
			maxp = Vector2i(maxi(maxp.x, x), maxi(maxp.y, y))
			for dy: int in [-1, 0, 1]:
				for dx: int in [-1, 0, 1]:
					var nx := x + dx
					var ny := y + dy
					if nx >= 0 and ny >= 0 and nx < w and ny < h:
						stack.append(ny * w + nx)
		inside.append(keep.grow(2).encloses(Rect2i(minp, maxp - minp + Vector2i.ONE)))
		next += 1
	for i in w * h:
		if label[i] >= 0 and not inside[label[i]]:
			img.set_pixel(i % w, i / w, Color(0, 0, 0, 0))


## Clears tiny opaque islands (compression noise) pixel-exactly, keeping everything else.
static func remove_small(img: Image, min_area: int) -> void:
	var w := img.get_width()
	var h := img.get_height()
	var seen := PackedByteArray()
	seen.resize(w * h)
	seen.fill(0)
	for i in w * h:
		if seen[i] == 1 or img.get_pixel(i % w, i / w).a <= 0.1:
			continue
		var island := PackedInt32Array()
		var stack := PackedInt32Array([i])
		while not stack.is_empty():
			var j := stack[stack.size() - 1]
			stack.resize(stack.size() - 1)
			if seen[j] == 1:
				continue
			var x := j % w
			var y := j / w
			if img.get_pixel(x, y).a <= 0.1:
				continue
			seen[j] = 1
			island.append(j)
			for dy: int in [-1, 0, 1]:
				for dx: int in [-1, 0, 1]:
					var nx := x + dx
					var ny := y + dy
					if nx >= 0 and ny >= 0 and nx < w and ny < h:
						stack.append(ny * w + nx)
		if island.size() < min_area:
			for j in island:
				img.set_pixel(j % w, j / w, Color(0, 0, 0, 0))
