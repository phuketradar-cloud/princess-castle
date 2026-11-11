extends SceneTree
## SUPERSEDED by tools/build_princess_art_v2.gd (green-screen v2 art). Running this would
## overwrite items_hd/ with the old v1 sword + tiara. Kept for reference only.
## Builds the Sword Princess art from the AI parts sheet (assets/art/source/sword_princess_sheet.webp):
##   body.png        the dressed character, blade removed from her hand (equipment draws weapons)
##   eyes_<v>.png    face overlays (eyes + mouth) cut from the 6 bald expression heads, scaled /
##                   rotated onto her face and masked so they never cover her hair
##   items_hd/       rose rapier + tiara for the Rose Rapier / Silver Tiara items
## Everything is in SHEET pixels; the game draws it at ART_SCALE (princess_definition.art_scale).
##   Godot_console.exe --headless --path . --script res://tools/build_princess_art.gd [-- --preview=<dir>]

const SHEET := "res://assets/art/source/sword_princess_sheet.webp"
const OUT := "res://assets/art/princesses/sword_princess_ai"
const ITEMS := "res://assets/art/items_hd"

## Character on the sheet and its feet (bottom-centre) = origin of the body texture.
const CHAR_RECT := Rect2i(7, 505, 407, 511)
const FEET := Vector2i(232, 1016)
## Blade to erase: segment tip -> hilt, radius in px (only this thin band is cleared).
const BLADE := [Vector2(4, 834), Vector2(86, 780), 8.0]
## Her eyes (iris centres) on the sheet, read off a coordinate grid (head tilted ~14 deg).
const EYE_L := Vector2(173, 635)
const EYE_R := Vector2(230, 649)

## Expression heads: bbox, iris centres, mouth centre (measured; head 2/5 eyes from head 3 layout).
const HEADS := {
	"h0": [Rect2i(16, 7, 217, 160), Vector2(105.4, 133.4), Vector2(188.3, 134.9), Vector2(147, 188)],
	"h1": [Rect2i(279, 4, 178, 156), Vector2(338.8, 106.3), Vector2(415.8, 106.1), Vector2(377, 150)],
	"h2": [Rect2i(473, 6, 166, 152), Vector2(527.3, 105.4), Vector2(598.7, 105.4), Vector2(565, 144)],
	"h3": [Rect2i(661, 7, 165, 150), Vector2(715.3, 107.2), Vector2(786.6, 105.5), Vector2(749, 150)],
	"h4": [Rect2i(855, 7, 161, 149), Vector2(909.0, 106.0), Vector2(976.1, 110.3), Vector2(945, 145)],
	"h5": [Rect2i(1033, 6, 166, 150), Vector2(1088.6, 105.2), Vector2(1159.9, 105.2), Vector2(1126, 150)],
}
## Game eye variants (CastleTypes.EXPRESSION_PARTS) -> head.
const VARIANTS := {
	"normal": "h1", "happy": "h0", "surprised": "h0", "curious": "h3", "fear": "h5",
	"crying": "h5", "angry": "h4", "sly": "h2", "closed": "h2",
}
## Her mouth centre on the sheet.
const MOUTH := Vector2(200, 671)
## Her original features (from the grid): eye half-size and the mouth box.
const FEATURE_EYE := Vector2(21, 16)
const MOUTH_BOX := Rect2i(188, 661, 25, 20)
## Patch ellipses in units of eye distance: eyes (+ brows) and mouth are placed separately
## because her face is proportioned differently from the bald heads.
const EYE_RADII := Vector2(0.98, 0.4)
const MOUTH_RADII := Vector2(0.34, 0.26)

## HD equipment: id -> [sheet rect]
const HD_ITEMS := {"rose_rapier": Rect2i(1110, 349, 415, 246), "silver_tiara": Rect2i(1360, 168, 153, 84)}


func _init() -> void:
	var preview := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--preview="):
			preview = a.substr(10)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(ITEMS))
	var sheet := SheetCutter.remove_checkerboard(Image.load_from_file(ProjectSettings.globalize_path(SHEET)))

	# ---- body
	var half := maxi(FEET.x - CHAR_RECT.position.x, CHAR_RECT.end.x - FEET.x) + 4
	var body_rect := Rect2i(FEET.x - half, CHAR_RECT.position.y - 4, half * 2, FEET.y - CHAR_RECT.position.y + 4)
	var figure := sheet.duplicate() as Image
	SheetCutter.isolate(figure, CHAR_RECT) # only her own pixels, not the hair part next to her
	var body := _region(figure, body_rect)
	_erase_blade(body, body_rect.position)
	_drop_specks(body, 300)
	body.save_png(ProjectSettings.globalize_path(OUT + "/body.png"))

	# ---- faces: eyes patch + mouth patch per expression, in one overlay texture
	var mid := (EYE_L + EYE_R) * 0.5
	var d := EYE_L.distance_to(EYE_R)
	var tilt := (EYE_R - EYE_L).angle()
	var er := EYE_RADII * d
	var mr := MOUTH_RADII * d
	var top_left := Vector2(minf(mid.x - er.x, MOUTH.x - mr.x), mid.y - er.x) - Vector2(3, 3)
	var bottom_right := Vector2(maxf(mid.x + er.x, MOUTH.x + mr.x), MOUTH.y + mr.y + er.y * 0.5) + Vector2(3, 3)
	var box := Rect2i(Vector2i(top_left), Vector2i(bottom_right - top_left))
	var anchor := (Vector2(box.position) + Vector2(box.size) * 0.5 - Vector2(FEET))
	for v in VARIANTS:
		var h: Array = HEADS[VARIANTS[v]]
		var hl: Vector2 = h[1]
		var hr: Vector2 = h[2]
		var s := hl.distance_to(hr) / d
		var patch := Image.create(box.size.x, box.size.y, false, Image.FORMAT_RGBA8)
		patch.fill(Color(0, 0, 0, 0))
		_paste(patch, box, sheet, h[0], mid, (hl + hr) * 0.5, er, tilt, (hr - hl).angle(), s)
		_paste(patch, box, sheet, h[0], MOUTH, h[3], mr, tilt, (hr - hl).angle(), s)
		patch.save_png(ProjectSettings.globalize_path("%s/eyes_%s.png" % [OUT, v]))
	print("face_anchor (sheet px from feet) = ", anchor, "  body size ", body.get_size())

	# ---- HD items
	for id in HD_ITEMS:
		var it := _region(sheet, HD_ITEMS[id])
		_drop_specks(it, 200)
		# keep only the item itself (largest piece), not neighbouring parts inside its box
		var parts := SheetCutter.components(it, 1)
		var biggest := 0
		for c in parts:
			biggest = maxi(biggest, c.area)
		SheetCutter.remove_small(it, biggest)
		it.save_png(ProjectSettings.globalize_path("%s/%s.png" % [ITEMS, id]))

	if preview != "":
		_save_preview(preview, body, anchor)
	print("build_princess_art: OK")
	quit()


static func _region(img: Image, r: Rect2i) -> Image:
	var out := Image.create(r.size.x, r.size.y, false, Image.FORMAT_RGBA8)
	out.fill(Color(0, 0, 0, 0))
	var src := r.intersection(Rect2i(Vector2i.ZERO, img.get_size()))
	out.blit_rect(img, src, src.position - r.position)
	return out


static func _erase_blade(img: Image, origin: Vector2i) -> void:
	var a: Vector2 = BLADE[0] - Vector2(origin)
	var b: Vector2 = BLADE[1] - Vector2(origin)
	var rad: float = BLADE[2]
	for y in img.get_height():
		for x in img.get_width():
			var p := Vector2(x, y)
			if Geometry2D.get_closest_point_to_segment(p, a, b).distance_to(p) <= rad:
				img.set_pixel(x, y, Color(0, 0, 0, 0))


## Removes leftover noise: faint pixels and opaque islands smaller than min_area.
static func _drop_specks(img: Image, min_area: int) -> void:
	for y in img.get_height():
		for x in img.get_width():
			if img.get_pixel(x, y).a < 0.25:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
	SheetCutter.remove_small(img, min_area)


## Inside her original eyes or mouth (the only dark pixels a face overlay may cover).
static func _in_feature(p: Vector2) -> bool:
	for c in [EYE_L, EYE_R]:
		var q: Vector2 = (p - c) / FEATURE_EYE
		if q.length_squared() <= 1.0:
			return true
	return MOUTH_BOX.grow(1).has_point(Vector2i(p))


static func _near_hair(img: Image, p: Vector2i, r: int) -> bool:
	for dy in range(-r, r + 1):
		for dx in range(-r, r + 1):
			if _is_hair(img.get_pixel(p.x + dx, p.y + dy)):
				return true
	return false


static func _is_hair(c: Color) -> bool:
	# Purple hair (hue ~250-305 deg) vs magenta eyes / pink skin.
	return c.a > 0.3 and c.s > 0.18 and c.h > 0.69 and c.h < 0.85


## Copies an ellipse of a head (around head_point) onto the overlay, centred on char_point,
## scaled + rotated to her face. Never covers her hair; keeps her dark outlines near the rim.
func _paste(out: Image, box: Rect2i, sheet: Image, hrect: Rect2i, char_point: Vector2,
		head_point: Vector2, radii: Vector2, tilt: float, htilt: float, s: float) -> void:
	for y in box.size.y:
		for x in box.size.x:
			var p := Vector2(box.position) + Vector2(x, y)
			var q := (p - char_point).rotated(-tilt)
			var e := (q.x * q.x) / (radii.x * radii.x) + (q.y * q.y) / (radii.y * radii.y)
			if e > 1.0:
				continue
			var under := sheet.get_pixel(int(p.x), int(p.y))
			if under.a < 0.5 or _is_hair(under):
				continue
			if under.v < 0.45 and not _in_feature(p):
				continue # her own outlines (chin, face, hair) stay; only old eyes / mouth are covered
			var hp := Vector2i(head_point + (q * s).rotated(htilt))
			if not hrect.has_point(hp):
				continue
			var c := sheet.get_pixel(hp.x, hp.y)
			c.a *= clampf((1.0 - e) / 0.2, 0.0, 1.0) # feather the edge
			var prev := out.get_pixel(x, y)
			out.set_pixel(x, y, c if c.a >= prev.a else prev)


func _save_preview(dir: String, body: Image, anchor: Vector2) -> void:
	DirAccess.make_dir_recursive_absolute(dir)
	var feet := Vector2(body.get_width() / 2, body.get_height())
	var cell := Vector2i(170, 150)
	var row := Image.create(cell.x * 3, cell.y * 3, false, Image.FORMAT_RGBA8)
	row.fill(Color(0.12, 0.22, 0.16))
	var i := 0
	for v in VARIANTS:
		var b := body.duplicate() as Image
		var f := Image.load_from_file(ProjectSettings.globalize_path("%s/eyes_%s.png" % [OUT, v]))
		var pos := Vector2i(feet + anchor - Vector2(f.get_size()) * 0.5)
		b.blend_rect(f, Rect2i(Vector2i.ZERO, f.get_size()), pos)
		var fc := Vector2i(feet + anchor)
		row.blend_rect(b, Rect2i(fc - cell / 2, cell), Vector2i(i % 3, i / 3) * cell)
		i += 1
	row.resize(row.get_width() * 2, row.get_height() * 2, Image.INTERPOLATE_LANCZOS)
	row.save_png(dir + "/faces_preview.png")
	var full := Image.create(body.get_width(), body.get_height(), false, Image.FORMAT_RGBA8)
	full.fill(Color(0.12, 0.22, 0.16))
	full.blend_rect(body, Rect2i(Vector2i.ZERO, body.get_size()), Vector2i.ZERO)
	full.save_png(dir + "/body_preview.png")
