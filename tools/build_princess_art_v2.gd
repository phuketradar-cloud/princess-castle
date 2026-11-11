extends SceneTree
## Sword Princess art v2 from green-screen images in assets/art/source/sword_v2/:
##   body_original.jpg            full body, calm smile (= "normal" face)
##   face_<expr>.jpg              the SAME image with only the face edited (pixel-aligned)
##   rapier.jpg, tiara.jpg        equipment on green
## Output: assets/art/princesses/sword_princess_v2/{body,eyes_<v>}.png and items_hd/*.png
## Faces need no scaling or rotation (aligned images). Each face patch is colour-matched to the
## body (AI edits drift in colour) and purple-drifted irises are pulled back to rose pink.
##   Godot_console.exe --headless --path . --script res://tools/build_princess_art_v2.gd [-- --preview=<dir>]

const SRC := "res://assets/art/source/sword_v2/"
const OUT := "res://assets/art/princesses/sword_princess_v2"
const ITEMS := "res://assets/art/items_hd"

## Feet (bottom-centre between the boots) = origin of the body texture, in image pixels.
const FEET := Vector2i(712, 730)
## Face patch ellipse (covers brows, eyes, mouth, chin) and her iris centres.
const FACE_CENTER := Vector2(737, 262)
const FACE_RADII := Vector2(68, 52)
const EYES := [Vector2(703, 250), Vector2(772, 250)]
const IRIS_RADIUS := 17.0
## Game eye variants -> source file ("" = the body image itself).
const VARIANTS := {
	"normal": "", "happy": "face_happy", "surprised": "face_surprised", "curious": "face_curious",
	"fear": "face_fear", "crying": "face_crying", "angry": "face_angry", "sly": "face_sly",
	"closed": "face_closed",
}
## Item art: file -> output id. Hold point for the rapier (grip) in its image.
const RAPIER_GRIP := Vector2(1000, 165)


func _init() -> void:
	var preview := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--preview="):
			preview = a.substr(10)
	for d in [OUT, ITEMS]:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(d))

	var base := _load(SRC + "body_original.jpg")
	var keyed := key_green(base)

	# ---- body: symmetric around the feet so the texture's bottom-centre is FEET
	var fig := _opaque_rect(keyed)
	var half := maxi(FEET.x - fig.position.x, fig.end.x - FEET.x) + 4
	var body_rect := Rect2i(FEET.x - half, fig.position.y - 4, half * 2, FEET.y - fig.position.y + 8)
	var body := _region(keyed, body_rect)
	SheetCutter.remove_small(body, 300)
	body.save_png(ProjectSettings.globalize_path(OUT + "/body.png"))

	# ---- faces
	var box := Rect2i(Vector2i(FACE_CENTER - FACE_RADII) - Vector2i(2, 2), Vector2i(FACE_RADII * 2) + Vector2i(4, 4))
	var base_iris := _iris_hue(base, base)
	for v in VARIANTS:
		var src: Image = base if VARIANTS[v] == "" else _load(SRC + VARIANTS[v] + ".jpg")
		var patch := _face_patch(base, src, box, base_iris)
		patch.save_png(ProjectSettings.globalize_path("%s/eyes_%s.png" % [OUT, v]))
	var anchor := Vector2(box.position) + Vector2(box.size) * 0.5 - Vector2(FEET.x, body_rect.end.y)

	# ---- items
	var rapier := key_green(_load(SRC + "rapier.jpg"))
	var r_rect := _opaque_rect(rapier)
	var r := _region(rapier, r_rect)
	SheetCutter.remove_small(r, 400)
	r.save_png(ProjectSettings.globalize_path(ITEMS + "/rose_rapier.png"))
	var tiara := key_green(_load(SRC + "tiara.jpg"))
	var t := _region(tiara, _opaque_rect(tiara))
	SheetCutter.remove_small(t, 400)
	t.save_png(ProjectSettings.globalize_path(ITEMS + "/silver_tiara.png"))

	print("body %s (feet at bottom-centre)  face_anchor px %s  rapier grip from centre %s  rapier size %s  tiara size %s" % [
		body.get_size(), anchor, RAPIER_GRIP - Vector2(r_rect.get_center()), r.get_size(), t.get_size()])
	if preview != "":
		_preview(preview, body, box, body_rect)
	print("build_princess_art_v2: OK")
	quit()


static func _load(path: String) -> Image:
	var img := Image.load_from_file(ProjectSettings.globalize_path(path))
	img.convert(Image.FORMAT_RGBA8)
	return img


## Chroma key: alpha from how much greener a pixel is than its red/blue; despills edges.
static func key_green(src: Image) -> Image:
	var img := src.duplicate() as Image
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			var g := c.g - maxf(c.r, c.b)
			var a := clampf(1.0 - (g - 0.12) / 0.25, 0.0, 1.0)
			if a < 1.0:
				c.g = minf(c.g, maxf(c.r, c.b))
			c.a = a
			img.set_pixel(x, y, c if a > 0.02 else Color(0, 0, 0, 0))
	return img


static func _opaque_rect(img: Image) -> Rect2i:
	var minp := Vector2i(img.get_width(), img.get_height())
	var maxp := Vector2i.ZERO
	for y in img.get_height():
		for x in img.get_width():
			if img.get_pixel(x, y).a > 0.5:
				minp = Vector2i(mini(minp.x, x), mini(minp.y, y))
				maxp = Vector2i(maxi(maxp.x, x), maxi(maxp.y, y))
	return Rect2i(minp, maxp - minp + Vector2i.ONE)


static func _region(img: Image, r: Rect2i) -> Image:
	var out := Image.create(r.size.x, r.size.y, false, Image.FORMAT_RGBA8)
	out.fill(Color(0, 0, 0, 0))
	var src := r.intersection(Rect2i(Vector2i.ZERO, img.get_size()))
	out.blit_rect(img, src, src.position - r.position)
	return out


static func _is_hair(c: Color) -> bool:
	return c.s > 0.18 and c.h > 0.66 and c.h < 0.86 and c.v < 0.8


static func _is_skin(c: Color) -> bool:
	return c.v > 0.6 and c.s < 0.35 and (c.h < 0.12 or c.h > 0.9)


static func _in_iris(p: Vector2) -> bool:
	for e in EYES:
		if p.distance_to(e) <= IRIS_RADIUS:
			return true
	return false


## Mean hue of saturated iris pixels; also counts them (closed eyes have almost none).
static var iris_count := 0

static func _iris_hue(img: Image, _ref: Image) -> float:
	var sx := 0.0
	var sy := 0.0
	iris_count = 0
	for e in EYES:
		for y in range(int(e.y - IRIS_RADIUS), int(e.y + IRIS_RADIUS)):
			for x in range(int(e.x - IRIS_RADIUS), int(e.x + IRIS_RADIUS)):
				var c := img.get_pixel(x, y)
				if c.s > 0.25 and c.v > 0.3 and _in_iris(Vector2(x, y)) and not _is_skin(c):
					sx += cos(c.h * TAU)
					sy += sin(c.h * TAU)
					iris_count += 1
	return fposmod(atan2(sy, sx) / TAU, 1.0)


func _face_patch(base: Image, src: Image, box: Rect2i, base_iris: float) -> Image:
	# Colour gain per channel from skin pixels that are skin in both images (robust to drift).
	var gain := Vector3.ONE
	var acc_b := Vector3.ZERO
	var acc_s := Vector3.ZERO
	for y in range(box.position.y, box.end.y):
		for x in range(box.position.x, box.end.x):
			var b := base.get_pixel(x, y)
			var s := src.get_pixel(x, y)
			if _is_skin(b) and _is_skin(s):
				acc_b += Vector3(b.r, b.g, b.b)
				acc_s += Vector3(s.r, s.g, s.b)
	if acc_s.x > 0.0:
		gain = acc_b / acc_s
	var iris_shift := 0.0
	var src_iris := 0.0
	if src != base:
		src_iris = _iris_hue(src, base)
		# Only open eyes with a clearly drifted iris colour get corrected.
		if iris_count > 150 and absf(wrapf(base_iris - src_iris, -0.5, 0.5)) > 0.02:
			iris_shift = wrapf(base_iris - src_iris, -0.5, 0.5)
	var out := Image.create(box.size.x, box.size.y, false, Image.FORMAT_RGBA8)
	out.fill(Color(0, 0, 0, 0))
	for y in box.size.y:
		for x in box.size.x:
			var p := Vector2(box.position) + Vector2(x, y)
			var q := (p - FACE_CENTER) / FACE_RADII
			var e := q.length_squared()
			if e > 1.0:
				continue
			var under := base.get_pixel(int(p.x), int(p.y))
			if _is_hair(under) and not _in_iris(p):
				continue # her hair (bangs / side locks) always comes from the body
			var c := src.get_pixel(int(p.x), int(p.y))
			c = Color(clampf(c.r * gain.x, 0, 1), clampf(c.g * gain.y, 0, 1), clampf(c.b * gain.z, 0, 1))
			if iris_shift != 0.0 and _in_iris(p) and c.s > 0.2 and absf(wrapf(c.h - src_iris, -0.5, 0.5)) < 0.08:
				c.h = fposmod(c.h + iris_shift, 1.0)
			c.a = clampf((1.0 - e) / 0.25, 0.0, 1.0) # feathered rim
			out.set_pixel(x, y, c)
	return out


func _preview(dir: String, body: Image, box: Rect2i, body_rect: Rect2i) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	var cell := Vector2i(220, 200)
	var sheet := Image.create(cell.x * 3, cell.y * 3, false, Image.FORMAT_RGBA8)
	sheet.fill(Color(0.2, 0.12, 0.3))
	var i := 0
	for v in VARIANTS:
		var b := body.duplicate() as Image
		var f := Image.load_from_file(ProjectSettings.globalize_path("%s/eyes_%s.png" % [OUT, v]))
		b.blend_rect(f, Rect2i(Vector2i.ZERO, f.get_size()), box.position - body_rect.position)
		var c := Vector2i(FACE_CENTER) - body_rect.position
		sheet.blend_rect(b, Rect2i(c - cell / 2 + Vector2i(0, 10), cell), Vector2i(i % 3, i / 3) * cell)
		i += 1
	sheet.resize(sheet.get_width() * 2, sheet.get_height() * 2, Image.INTERPOLATE_LANCZOS)
	sheet.save_png(dir + "/v2_faces.png")
