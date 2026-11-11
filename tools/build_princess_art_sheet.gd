extends SceneTree
## Princess art from 3 green-screen AI images (no pixel-aligned face edits needed):
##   body.jpg          full body                      -> <out>/body.png
##   faces_sheet.jpg   9 heads in a 3x3 grid          -> <out>/eyes_<variant>.png (face overlays)
##   <weapon>.jpg      her starter weapon             -> items_hd/<weapon_id>.png
## Each head's eyes are found by iris colour; the face (eyes + mouth) is scaled / rotated so
## its eyes land on the body's eyes, colour-matched to the body's skin, and masked so it never
## covers her hair. If the art faces LEFT, everything is mirrored so she faces the monsters.
##   Godot_console.exe --headless --path . --script res://tools/build_princess_art_sheet.gd -- --princess=magic_princess [--preview=<dir>]

const CONFIG := {
	"magic_princess": {
		"src": "res://assets/art/source/magic/",
		"out": "res://assets/art/princesses/magic_princess_hd",
		"mirror": true,               # AI drew her facing left
		"iris_hue": Vector2(0.55, 0.70), # ice blue (pale: low saturation)
		"iris_min_sat": 0.18,
		"iris_min_v": 0.5,   # pale bright iris vs the dark-blue collar / trim
		# where to look for eyes: rows of the upper body / of each head box (fractions)
		"body_eye_rows": Vector2(0.15, 0.4),
		"head_eye_rows": Vector2(0.3, 0.75),
		"weapon": ["wand.jpg", "apprentice_wand"],
		"mirror_weapon": false,      # keep the wand pointing up-right (away from her face)
		# face patch around the eye midpoint, in eye-distance units
		"face_center": 0.26,
		"face_radii": Vector2(0.95, 0.6), # stops just above her chin (chin ~0.94 eye-distances down)
		# variants that only take the eyes (head drawn at a different size): keep her own mouth
		"eyes_only": ["closed"],
	},
}
## 3x3 grid order (row by row) -> game eye variants. Cell 0 = calm smile = "normal".
const GRID := ["normal", "happy", "surprised", "curious", "fear", "crying", "angry", "sly", "closed"]
const ITEMS := "res://assets/art/items_hd"
## Eye spacing as a fraction of the searched area's width (head box / upper body).
const EYE_DX := Vector2(0.15, 0.5)

var cfg: Dictionary


func _init() -> void:
	var id := ""
	var preview := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--princess="):
			id = a.substr(11)
		elif a.begins_with("--preview="):
			preview = a.substr(10)
	if not CONFIG.has(id):
		push_error("unknown --princess=%s" % id)
		quit(1)
		return
	cfg = CONFIG[id]
	for d in [cfg.out, ITEMS]:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(d))

	# ---- body
	var body_full := _keyed(cfg.src + "body.jpg")
	var fig := _opaque_rect(body_full)
	var feet_x := _feet_x(body_full, fig)
	var half := maxi(feet_x - fig.position.x, fig.end.x - feet_x) + 4
	var body_rect := Rect2i(feet_x - half, fig.position.y - 4, half * 2, fig.size.y + 8)
	var body := _region(body_full, body_rect)
	SheetCutter.remove_small(body, 300)
	body.save_png(ProjectSettings.globalize_path(cfg.out + "/body.png"))
	var ber: Vector2 = cfg.get("body_eye_rows", Vector2(0.0, 0.5))
	var eyes := _find_eyes(body, Rect2i(0, int(body.get_height() * ber.x), body.get_width(), int(body.get_height() * (ber.y - ber.x))))
	if eyes.is_empty():
		push_error("could not find the body's eyes")
		quit(1)
		return
	var bl: Vector2 = eyes[0]
	var br: Vector2 = eyes[1]
	var d := bl.distance_to(br)
	var tilt := (br - bl).angle()
	var mid := (bl + br) * 0.5
	var center: Vector2 = mid + Vector2(0, cfg.face_center * d).rotated(tilt)
	var radii: Vector2 = cfg.face_radii * d
	var box := Rect2i(Vector2i(center - Vector2(radii.x, radii.y) - Vector2(2, 2)), Vector2i(radii * 2 + Vector2(4, 4)))
	print("body %s  eyes %s %s (d=%.1f, tilt %.1f deg)" % [body.get_size(), bl.round(), br.round(), d, rad_to_deg(tilt)])

	# ---- heads
	var sheet := _keyed(cfg.src + "faces_sheet.jpg")
	var heads := SheetCutter.components(sheet, 8000)
	if heads.size() != 9:
		push_error("expected 9 heads, found %d" % heads.size())
		quit(1)
		return
	heads.sort_custom(func(a, b): return a.rect.get_center().y < b.rect.get_center().y)
	var ordered := []
	for row in 3:
		var r := heads.slice(row * 3, row * 3 + 3)
		# mirrored art: the sheet was flipped too, so its columns now run right to left
		if cfg.mirror:
			r.sort_custom(func(a, b): return a.rect.get_center().x > b.rect.get_center().x)
		else:
			r.sort_custom(func(a, b): return a.rect.get_center().x < b.rect.get_center().x)
		ordered.append_array(r)
	var ref_eyes := []
	for i in 9:
		var hr: Rect2i = ordered[i].rect
		var her: Vector2 = cfg.get("head_eye_rows", Vector2(0.0, 1.0))
		var he := _find_eyes(sheet, Rect2i(hr.position.x, hr.position.y + int(hr.size.y * her.x), hr.size.x, int(hr.size.y * (her.y - her.x))))
		if he.is_empty() and ref_eyes.is_empty():
			push_error("no eyes found on the first (calm) head")
			quit(1)
			return
		if he.is_empty() or GRID[i] == "closed":
			# closed eyes: no iris -> reuse the layout of the calm head (same size/angle)
			var c0: Rect2i = ordered[0].rect
			var off := _match_offset(sheet, c0, hr)
			he = [ref_eyes[0][0] + off, ref_eyes[0][1] + off]
		ref_eyes.append(he)
		var pc := center
		var pr := radii
		if GRID[i] in cfg.get("eyes_only", []):
			pc = mid # eye band only
			pr = Vector2(radii.x, 0.36 * d)
		var patch := _face_patch(body, sheet, hr, he[0], he[1], bl, br, box, pc, pr)
		patch.save_png(ProjectSettings.globalize_path("%s/eyes_%s.png" % [cfg.out, GRID[i]]))
		print("%-10s head %s eyes %s %s" % [GRID[i], hr, he[0].round(), he[1].round()])
	var anchor := Vector2(box.position) + Vector2(box.size) * 0.5 - Vector2(body.get_width() / 2.0, body.get_height())
	print("face_anchor px from feet %s" % anchor)

	# ---- weapon
	var w := _keyed(cfg.src + cfg.weapon[0], cfg.get("mirror_weapon", true))
	var wr := _opaque_rect(w)
	var wi := _region(w, wr)
	SheetCutter.remove_small(wi, 400)
	wi.save_png(ProjectSettings.globalize_path("%s/%s.png" % [ITEMS, cfg.weapon[1]]))
	print("weapon %s size %s" % [cfg.weapon[1], wi.get_size()])
	if preview != "":
		_preview(preview, body, box)
	print("build_princess_art_sheet: OK")
	quit()


func _keyed(path: String, mirror := true) -> Image:
	var img := Image.load_from_file(ProjectSettings.globalize_path(path))
	img.convert(Image.FORMAT_RGBA8)
	if cfg.mirror and mirror:
		img.flip_x()
	return load("res://tools/build_room_art.gd").key_green(img)


## Offset that best overlays head box `b` onto reference head box `a` (same hairstyle):
## compares the upper half (hair + forehead) over a +-40 px search.
static func _match_offset(img: Image, a: Rect2i, b: Rect2i) -> Vector2:
	var base := Vector2(b.position - a.position)
	var best := base
	var best_err := INF
	for dy in range(-40, 41, 2):
		for dx in range(-40, 41, 2):
			var err := 0.0
			var n := 0
			for y in range(a.position.y, a.position.y + a.size.y / 2, 3):
				for x in range(a.position.x, a.end.x, 3):
					var p := Vector2i(x, y) + Vector2i(base) + Vector2i(dx, dy)
					if p.x < 0 or p.y < 0 or p.x >= img.get_width() or p.y >= img.get_height():
						continue
					var c1 := img.get_pixel(x, y)
					var c2 := img.get_pixelv(p)
					err += absf(c1.v - c2.v) + absf(c1.a - c2.a)
					n += 1
			err /= maxf(n, 1)
			if err < best_err:
				best_err = err
				best = base + Vector2(dx, dy)
	return best


static func _opaque_rect(img: Image) -> Rect2i:
	var minp := Vector2i(img.get_width(), img.get_height())
	var maxp := Vector2i.ZERO
	for y in img.get_height():
		for x in img.get_width():
			if img.get_pixel(x, y).a > 0.5:
				minp = Vector2i(mini(minp.x, x), mini(minp.y, y))
				maxp = Vector2i(maxi(maxp.x, x), maxi(maxp.y, y))
	return Rect2i(minp, maxp - minp + Vector2i.ONE)


## Centre of the opaque pixels in the bottom rows (between the feet).
static func _feet_x(img: Image, fig: Rect2i) -> int:
	var sx := 0.0
	var n := 0
	for y in range(fig.end.y - maxi(6, fig.size.y / 30), fig.end.y):
		for x in range(fig.position.x, fig.end.x):
			if img.get_pixel(x, y).a > 0.5:
				sx += x
				n += 1
	return int(sx / maxf(n, 1))


static func _region(img: Image, r: Rect2i) -> Image:
	var out := Image.create(r.size.x, r.size.y, false, Image.FORMAT_RGBA8)
	out.fill(Color(0, 0, 0, 0))
	var src := r.intersection(Rect2i(Vector2i.ZERO, img.get_size()))
	out.blit_rect(img, src, src.position - r.position)
	return out


func _is_iris(c: Color) -> bool:
	var h: Vector2 = cfg.iris_hue
	return c.a > 0.5 and c.s > float(cfg.get("iris_min_sat", 0.3)) and c.v > float(cfg.get("iris_min_v", 0.3)) and c.v < 0.98 and c.h >= h.x and c.h <= h.y


## Two iris blobs at about the same height (largest pair), left to right. [] if not found.
func _find_eyes(img: Image, area: Rect2i) -> Array:
	var mask := Image.create(img.get_width(), img.get_height(), false, Image.FORMAT_RGBA8)
	mask.fill(Color(0, 0, 0, 0))
	for y in range(area.position.y, area.end.y):
		for x in range(area.position.x, area.end.x):
			if _is_iris(img.get_pixel(x, y)):
				mask.set_pixel(x, y, Color.WHITE)
	var blobs := SheetCutter.components(mask, 40)
	# Best pair = two similar-sized, level blobs a plausible eye distance apart
	# (rejects hair clips, dress trim, sparkles). Score = the smaller blob's area.
	var best := []
	var best_score := 0
	var w := float(area.size.x)
	for i in blobs.size():
		for j in range(i + 1, blobs.size()):
			var a: Dictionary = blobs[i]
			var b: Dictionary = blobs[j]
			var dy := absf(a.rect.get_center().y - b.rect.get_center().y)
			var dx := absf(a.rect.get_center().x - b.rect.get_center().x)
			var ratio := float(maxi(a.area, b.area)) / maxi(1, mini(a.area, b.area))
			if dy > dx * 0.3 or dx < w * EYE_DX.x or dx > w * EYE_DX.y or ratio > 2.5:
				continue
			if mini(a.area, b.area) > best_score:
				best_score = mini(a.area, b.area)
				var pa := _centroid(mask, a.rect)
				var pb := _centroid(mask, b.rect)
				best = [pa, pb] if pa.x < pb.x else [pb, pa]
	return best


static func _centroid(mask: Image, r: Rect2i) -> Vector2:
	var s := Vector2.ZERO
	var n := 0
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			if mask.get_pixel(x, y).a > 0.5:
				s += Vector2(x, y)
				n += 1
	return s / maxf(n, 1)


static func _is_hair(c: Color) -> bool:
	return c.a > 0.5 and c.s < 0.12 and c.v > 0.55 # silver / white hair


static func _is_skin(c: Color) -> bool:
	return c.a > 0.5 and c.v > 0.65 and c.s > 0.08 and c.s < 0.4 and (c.h < 0.12 or c.h > 0.94)


func _face_patch(body: Image, sheet: Image, hrect: Rect2i, hl: Vector2, hr: Vector2, bl: Vector2, br: Vector2,
		box: Rect2i, center: Vector2, radii: Vector2) -> Image:
	var bmid := (bl + br) * 0.5
	var hmid := (hl + hr) * 0.5
	var s := hl.distance_to(hr) / bl.distance_to(br)
	var rot := (hr - hl).angle() - (br - bl).angle()
	var d := bl.distance_to(br)
	var eye_r := d * 0.36
	# colour gain: skin in both images
	var acc_b := Vector3.ZERO
	var acc_s := Vector3.ZERO
	var pts := []
	for y in box.size.y:
		for x in box.size.x:
			var p := Vector2(box.position) + Vector2(x, y)
			var q := (p - center) / radii
			if q.length_squared() > 1.0:
				continue
			var hp := Vector2i(hmid + ((p - bmid) * s).rotated(rot))
			if not hrect.has_point(hp):
				continue
			pts.append([x, y, q.length_squared(), hp])
			var b := body.get_pixel(int(p.x), int(p.y))
			var c := sheet.get_pixelv(hp)
			if _is_skin(b) and _is_skin(c):
				acc_b += Vector3(b.r, b.g, b.b)
				acc_s += Vector3(c.r, c.g, c.b)
	var gain := acc_b / acc_s if acc_s.x > 0.0 else Vector3.ONE
	var out := Image.create(box.size.x, box.size.y, false, Image.FORMAT_RGBA8)
	out.fill(Color(0, 0, 0, 0))
	for e in pts:
		var p := Vector2(box.position) + Vector2(e[0], e[1])
		var under := body.get_pixel(int(p.x), int(p.y))
		var near_eye := p.distance_to(bl) < eye_r or p.distance_to(br) < eye_r
		if under.a < 0.5 or (_is_hair(under) and not near_eye):
			continue # outside her, or her hair: the body shows through
		var c := sheet.get_pixelv(e[3])
		if c.a < 0.5:
			continue
		c = Color(clampf(c.r * gain.x, 0, 1), clampf(c.g * gain.y, 0, 1), clampf(c.b * gain.z, 0, 1))
		c.a = clampf((1.0 - e[2]) / 0.25, 0.0, 1.0)
		out.set_pixel(e[0], e[1], c)
	return out


func _preview(dir: String, body: Image, box: Rect2i) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	var cell := Vector2i(240, 220)
	var sheet := Image.create(cell.x * 3, cell.y * 3, false, Image.FORMAT_RGBA8)
	sheet.fill(Color(0.2, 0.12, 0.3))
	for i in GRID.size():
		var b := body.duplicate() as Image
		var f := Image.load_from_file(ProjectSettings.globalize_path("%s/eyes_%s.png" % [cfg.out, GRID[i]]))
		b.blend_rect(f, Rect2i(Vector2i.ZERO, f.get_size()), box.position)
		var c := box.get_center()
		sheet.blend_rect(b, Rect2i(c - cell / 2 + Vector2i(0, -10), cell), Vector2i(i % 3, i / 3) * cell)
	sheet.resize(sheet.get_width() * 2, sheet.get_height() * 2, Image.INTERPOLATE_LANCZOS)
	sheet.save_png(dir + "/sheet_faces.png")
