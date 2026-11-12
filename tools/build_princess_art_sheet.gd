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
		"flip_weapon": false,        # keep the wand pointing up-right (away from her face)
		# face patch around the eye midpoint, in eye-distance units
		"face_center": 0.26,
		"face_radii": Vector2(0.95, 0.6), # stops just above her chin (chin ~0.94 eye-distances down)
		# variants that only take the eyes (head drawn at a different size): keep her own mouth
		"eyes_only": ["closed"],
	},
	"light_princess": {
		"src": "res://assets/art/source/light/",
		"out": "res://assets/art/princesses/light_princess_hd",
		"key": "magenta",             # green eyes -> drawn on a magenta screen
		"mirror": true,               # drawn facing left
		"iris_hue": Vector2(0.33, 0.48), # emerald green
		"iris_min_sat": 0.35,
		"iris_min_v": 0.3,
		"body_eye_rows": Vector2(0.15, 0.4),
		"head_eye_rows": Vector2(0.3, 0.75),
		"weapon": ["staff.jpg", "prayer_staff"],
		"flip_weapon": false,        # sun ornament up-right, away from her face
		"face_center": 0.26,
		"face_radii": Vector2(0.95, 0.6),
		# reading order of her sheet (row 1 has an extra winking "happy")
		"sheet_order": ["normal", "skip", "happy", "surprised", "curious", "fear", "crying", "angry", "sly", "closed"],
		"match_by_hair": ["closed"],
		"eyes_only": ["closed"],
	},
	"shadow_princess": {
		"src": "res://assets/art/source/shadow/",
		"out": "res://assets/art/princesses/shadow_princess_hd",
		"mirror": false,              # drawn facing right
		"iris_hue": Vector2(0.94, 0.04), # crimson (wraps around red)
		"iris_min_sat": 0.35,
		"iris_min_v": 0.25,
		"iris_max_v": 0.9,
		"body_eye_rows": Vector2(0.15, 0.4),
		"head_eye_rows": Vector2(0.3, 0.75),
		"hair": "dark",
		"weapon": ["dagger.jpg", "twin_dagger"],
		"flip_weapon": true,         # blade points forward-down toward the enemies
		"face_center": 0.08,          # reaches up to her high brows, still above the chin
		"face_radii": Vector2(0.95, 0.78),
		"brow_band": Vector2(0.25, 0.78), # brows sit high: 0.25 .. 0.78 eye-distances above the eyes
		"match_by_hair": ["happy", "closed"], # eyes shut / winking: no iris to find
		"eyes_only": ["closed"],
	},
	"dragon_princess": {
		"src": "res://assets/art/source/dragon/",
		"out": "res://assets/art/princesses/dragon_princess_hd",
		"mirror": false,              # drawn facing right
		"iris_hue": Vector2(0.075, 0.16), # golden amber (hair highlights are redder)
		"iris_min_sat": 0.55,
		"iris_min_v": 0.45,
		"body_eye_rows": Vector2(0.15, 0.4),
		"head_eye_rows": Vector2(0.3, 0.75),
		"hair": "red",
		"weapon": ["club.jpg", "scale_club"],
		"flip_weapon": false,        # club head up-right
		"face_center": 0.12,          # her chin is close under the eyes
		"face_radii": Vector2(0.85, 0.6),
		"eyes_only_rx": 1.05,          # her outer eye corners reach ~1 eye distance out
		"mouth_r": 0.42,               # her red smirk reads as hair: cover all of it
		"mouth_pos": 0.5,              # smirk 0.47..0.55 below the eyes, x -0.31..0.18
		"chin_guard": true,
		"align_chin": true,
		"eyes_only_ry": 0.4,           # her closed eyes are wider: cover the whole open eye
		"sheet_order": ["normal", "skip", "happy", "surprised", "curious", "fear", "crying", "angry", "sly", "closed"],
		"match_by_hair": ["closed"],
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
	var body_full := _keyed(cfg.src + "body.jpg", cfg.mirror)
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
	# eyes-only band may be wider than the face patch (outer eye corners); the box holds both
	var band_rx: float = maxf(radii.x, float(cfg.get("eyes_only_rx", 0.0)) * d)
	var box_half := Vector2(band_rx, radii.y)
	var box := Rect2i(Vector2i(center - box_half - Vector2(2, 2)), Vector2i(box_half * 2 + Vector2(4, 4)))
	print("body %s  eyes %s %s (d=%.1f, tilt %.1f deg)" % [body.get_size(), bl.round(), br.round(), d, rad_to_deg(tilt)])

	# ---- heads
	var sheet := _keyed(cfg.src + "faces_sheet.jpg", cfg.mirror)
	var heads := _split_wide(sheet, _split_tall(sheet, SheetCutter.components(sheet, 8000)))
	# Rows by vertical position (any number of heads per row), then left to right in the
	# ORIGINAL drawing (a mirrored sheet is read right to left).
	heads.sort_custom(func(a, b): return a.rect.get_center().y < b.rect.get_center().y)
	var rows := []
	for h in heads:
		if rows.is_empty() or h.rect.get_center().y - rows[-1][0].rect.get_center().y > h.rect.size.y * 0.5:
			rows.append([h])
		else:
			rows[-1].append(h)
	var ordered := []
	for r in rows:
		if cfg.mirror:
			r.sort_custom(func(a, b): return a.rect.get_center().x > b.rect.get_center().x)
		else:
			r.sort_custom(func(a, b): return a.rect.get_center().x < b.rect.get_center().x)
		ordered.append_array(r)
	# Names in reading order; "skip" drops an extra head.
	var order: Array = cfg.get("sheet_order", GRID)
	if ordered.size() != order.size():
		push_error("expected %d heads, found %d" % [order.size(), ordered.size()])
		quit(1)
		return
	var named := {}
	for i in ordered.size():
		if order[i] != "skip":
			named[order[i]] = ordered[i]
	var ref_eyes := []
	var ref_rect: Rect2i = named["normal"].rect
	for v in GRID:
		var hr: Rect2i = named[v].rect
		var her: Vector2 = cfg.get("head_eye_rows", Vector2(0.0, 1.0))
		var he := _find_eyes(sheet, Rect2i(hr.position.x, hr.position.y + int(hr.size.y * her.x), hr.size.x, int(hr.size.y * (her.y - her.x))))
		if he.is_empty() and ref_eyes.is_empty():
			push_error("no eyes found on the calm (normal) head")
			quit(1)
			return
		if he.is_empty() or v in cfg.get("match_by_hair", ["closed"]):
			# no iris to find -> calm head's eye layout, shifted by matching the hair
			var off := _match_offset(sheet, ref_rect, hr)
			he = [ref_eyes[0][0] + off, ref_eyes[0][1] + off]
		ref_eyes.append(he)
		var pc := center
		var pr := radii
		if v in cfg.get("eyes_only", []):
			pc = mid # eye band only
			pr = Vector2(band_rx, float(cfg.get("eyes_only_ry", 0.36)) * d)
		var patch := _face_patch(body, sheet, hr, he[0], he[1], bl, br, box, pc, pr, v in cfg.get("eyes_only", []))
		patch.save_png(ProjectSettings.globalize_path("%s/eyes_%s.png" % [cfg.out, v]))
		print("%-10s head %s eyes %s %s" % [v, hr, he[0].round(), he[1].round()])
	var anchor := Vector2(box.position) + Vector2(box.size) * 0.5 - Vector2(body.get_width() / 2.0, body.get_height())
	print("face_anchor px from feet %s" % anchor)

	# ---- weapon
	# weapon: mirrored with her unless the config says otherwise (flip_weapon)
	var w := _keyed(cfg.src + cfg.weapon[0], cfg.get("flip_weapon", cfg.mirror))
	var wr := _opaque_rect(w)
	var wi := _region(w, wr)
	SheetCutter.remove_small(wi, 400)
	wi.save_png(ProjectSettings.globalize_path("%s/%s.png" % [ITEMS, cfg.weapon[1]]))
	print("weapon %s size %s" % [cfg.weapon[1], wi.get_size()])
	if preview != "":
		_preview(preview, body, box)
	print("build_princess_art_sheet: OK")
	quit()


func _keyed(path: String, flip: bool) -> Image:
	var img := Image.load_from_file(ProjectSettings.globalize_path(path))
	img.convert(Image.FORMAT_RGBA8)
	if flip:
		img.flip_x()
	var keyer: Script = load("res://tools/build_room_art.gd")
	return keyer.key_magenta(img) if cfg.get("key", "green") == "magenta" else keyer.key_green(img)


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


## Heads drawn touching each other come out as one wide island: split it at the emptiest
## columns into as many heads as its width suggests (median head width).
static func _split_wide(img: Image, comps: Array) -> Array:
	var widths := comps.map(func(c): return c.rect.size.x)
	widths.sort()
	var median: int = widths[widths.size() / 2]
	var out := []
	for c in comps:
		var r: Rect2i = c.rect
		var n := ceili(float(r.size.x) / median - 0.3) # crowded heads overlap, so each is narrower
		if n <= 1:
			out.append(c)
			continue
		var cuts := [r.position.x]
		for k in range(1, n):
			var guess := r.position.x + r.size.x * k / n
			var best := guess
			var best_count := 1 << 30
			for x in range(guess - median / 4, guess + median / 4):
				var count := 0
				for y in range(r.position.y, r.end.y):
					if img.get_pixel(x, y).a > 0.5:
						count += 1
				if count < best_count:
					best_count = count
					best = x
			cuts.append(best)
		cuts.append(r.end.x)
		for k in n:
			out.append({"rect": Rect2i(cuts[k], r.position.y, cuts[k + 1] - cuts[k], r.size.y), "area": c.area / n})
	return out


## Rows drawn touching each other (hair spikes on the shoulders above) come out as tall
## islands: split them at the emptiest rows, like _split_wide does for columns.
static func _split_tall(img: Image, comps: Array) -> Array:
	var heights := comps.map(func(c): return c.rect.size.y)
	heights.sort()
	var median: int = heights[heights.size() / 2]
	var out := []
	for c in comps:
		var r: Rect2i = c.rect
		var n := roundi(float(r.size.y) / median)
		if n <= 1:
			out.append(c)
			continue
		var cuts := [r.position.y]
		for k in range(1, n):
			var guess := r.position.y + r.size.y * k / n
			var best := guess
			var best_count := 1 << 30
			for y in range(guess - median / 4, guess + median / 4):
				var count := 0
				for x in range(r.position.x, r.end.x):
					if img.get_pixel(x, y).a > 0.5:
						count += 1
				if count < best_count:
					best_count = count
					best = y
			cuts.append(best)
		cuts.append(r.end.y)
		for k in n:
			out.append({"rect": Rect2i(r.position.x, cuts[k], r.size.x, cuts[k + 1] - cuts[k]), "area": c.area / n})
	return out


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
	# hue range may wrap around red (e.g. 0.95 .. 0.04)
	var in_hue := (c.h >= h.x and c.h <= h.y) if h.x <= h.y else (c.h >= h.x or c.h <= h.y)
	return c.a > 0.5 and c.s > float(cfg.get("iris_min_sat", 0.3)) and c.v > float(cfg.get("iris_min_v", 0.3)) and c.v < float(cfg.get("iris_max_v", 0.98)) and in_hue


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


func _is_hair(c: Color) -> bool:
	if cfg.get("hair", "light") == "red":
		return c.a > 0.5 and c.s > 0.55 and c.v > 0.3 and (c.h < 0.07 or c.h > 0.93) # crimson / ember hair
	if cfg.get("hair", "light") == "dark":
		return c.a > 0.5 and c.v < 0.32 # black hair (and dark outlines: kept from the body)
	return c.a > 0.5 and c.s < 0.12 and c.v > 0.55 # silver / white hair


## Depth of the chin line below the eyes (in eye distances), measured down a column
## 0.4 eye distances toward the left eye (clear of the mouth): the first dark outline pixel
## (not a blue tear) past 0.3. 0 = not found.
var _ref_chin := 0.0


static func _chin_depth(img: Image, l: Vector2, r: Vector2) -> float:
	var d := l.distance_to(r)
	var a := (r - l).angle()
	var mid := (l + r) * 0.5
	var steps := int(d * 1.3)
	for i in range(int(d * 0.3), steps):
		var p := mid + Vector2(-0.4 * d, i).rotated(a)
		if p.x < 0 or p.y < 0 or p.x >= img.get_width() or p.y >= img.get_height():
			return 0.0
		var c := img.get_pixel(int(p.x), int(p.y))
		if c.a > 0.5 and c.v < 0.45 and not (c.h > 0.45 and c.h < 0.7):
			return i / d
	return 0.0


static func _is_skin(c: Color) -> bool:
	return c.a > 0.5 and c.v > 0.65 and c.s > 0.08 and c.s < 0.4 and (c.h < 0.12 or c.h > 0.94)


func _face_patch(body: Image, sheet: Image, hrect: Rect2i, hl: Vector2, hr: Vector2, bl: Vector2, br: Vector2,
		box: Rect2i, center: Vector2, radii: Vector2, boxy := false) -> Image:
	var bmid := (bl + br) * 0.5
	var hmid := (hl + hr) * 0.5
	var s := hl.distance_to(hr) / bl.distance_to(br)
	var rot := (hr - hl).angle() - (br - bl).angle()
	var d := bl.distance_to(br)
	var eye_r := d * 0.36
	# her own mouth must be covered too (it is dark like hair / outlines)
	var mouth := bmid + Vector2(0, float(cfg.get("mouth_pos", 0.65)) * d).rotated((br - bl).angle())
	var mouth_r := d * float(cfg.get("mouth_r", 0.3))
	# align_chin: heads drawn with a shorter / longer chin are stretched below the eyes so
	# their chin line lands on hers (else it is drawn across her cheeks).
	var chin_k := 1.0
	if cfg.get("align_chin", false) and not boxy:
		# measured against the calm head (first one patched): it is drawn like her body
		var hc := _chin_depth(sheet, hl, hr)
		if _ref_chin <= 0.0:
			_ref_chin = hc
		if hc > 0.0 and _ref_chin > 0.0:
			chin_k = clampf(hc / _ref_chin, 0.6, 1.3)
		print("  chin %.2f / calm %.2f -> k %.2f" % [hc, _ref_chin, chin_k])
	var bang := (br - bl).angle()
	# colour gain: skin in both images
	var acc_b := Vector3.ZERO
	var acc_s := Vector3.ZERO
	var pts := []
	for y in box.size.y:
		for x in box.size.x:
			var p := Vector2(box.position) + Vector2(x, y)
			var q := (p - center) / radii
			# eye band: a rounded box (q^4) so the outer eye corners are fully covered
			var r2 := pow(q.x, 4) + pow(q.y, 4) if boxy else q.length_squared()
			if r2 > 1.0:
				continue
			var v := (p - bmid).rotated(-bang)
			if v.y > 0.0:
				v.y *= chin_k
			var hp := Vector2i(hmid + (v.rotated(bang) * s).rotated(rot))
			if not hrect.has_point(hp):
				continue
			pts.append([x, y, r2, hp])
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
		var near_eye := p.distance_to(bl) < eye_r or p.distance_to(br) < eye_r or p.distance_to(mouth) < mouth_r
		var c := sheet.get_pixelv(e[3])
		# Brow zone (band above each eye): the expression's brows replace hers. Where both images
		# are dark it is her bangs -> keep the body; where only one is dark it is a brow.
		var in_brow := false
		for eye: Vector2 in [bl, br]:
			var dy := eye.y - p.y
			var band: Vector2 = cfg.get("brow_band", Vector2(0.12, 0.55))
			if dy > d * band.x and dy < d * band.y and absf(p.x - eye.x) < d * 0.5:
				in_brow = true
		var brow_swap := in_brow and not boxy and _is_hair(under) != _is_hair(c) # eyes-only: keep her brows
		if under.a < 0.5 or (_is_hair(under) and not near_eye and not brow_swap):
			continue # outside her, or her hair: the body shows through
		if c.a < 0.5:
			continue
		# chin_guard: on the lower cheeks (beside the mouth) only skin / tears come from the
		# sheet: a head drawn with a shorter chin would draw its chin line across her cheeks.
		var guard := 0.0
		if cfg.get("chin_guard", false):
			var rel := (p - bmid).rotated(-(br - bl).angle()) / d
			var tear := c.h > 0.45 and c.h < 0.65 and c.s > 0.2
			# soft weight: 1 = her own cheeks / face edge win (skin-toned chin lines would show too)
			var ax := absf(rel.x)
			var lower := smoothstep(0.24, 0.36, rel.y) * maxf(smoothstep(0.26, 0.38, ax), smoothstep(0.56, 0.64, rel.y))
			var side := smoothstep(0.06, 0.18, rel.y) * smoothstep(0.64, 0.76, ax)
			# the expression's mouth (a flat ellipse around mouth_pos) always comes through
			var mq := Vector2((rel.x + 0.05) / 0.4, (rel.y - float(cfg.get("mouth_pos", 0.65))) / 0.17)
			guard = maxf(lower, side) * smoothstep(0.8, 1.15, mq.length())
			if tear:
				guard = 0.0
			if guard > 0.99:
				continue
		if boxy and not _is_skin(c) and minf(p.distance_to(bl), p.distance_to(br)) > d * 0.5:
			continue # eyes-only: past the eyes only skin comes from the sheet (no stray hair)
		c = Color(clampf(c.r * gain.x, 0, 1), clampf(c.g * gain.y, 0, 1), clampf(c.b * gain.z, 0, 1))
		c.a = clampf((1.0 - e[2]) / 0.25, 0.0, 1.0) * (1.0 - guard)
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
