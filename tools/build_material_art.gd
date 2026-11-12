extends SceneTree
## Crafting-material icons from assets/art/source/items/materials.webp: a 3x3 sheet of framed
## tiles on green. Each tile's inside (dark backdrop + item, without the ornate frame) is kept,
## with rounded corners -> assets/art/materials_hd/<key>.png (used by CastleTypes.material_icon).
##   Godot_console.exe --headless --path . --script res://tools/build_material_art.gd

const SRC := "res://assets/art/source/items/materials.webp"
const OUT := "res://assets/art/materials_hd"
const ORDER := ["fire", "ice", "shadow", "light", "dragon", "bone_fragment", "ice_crystal", "holy_fragment", "dragon_scale"]
const INSET := 0.13    ## fraction of the tile cut from each side (the frame)
const RADIUS := 0.2    ## corner radius, fraction of the icon size
const SIZE := 160      ## output px


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var img := Image.load_from_file(ProjectSettings.globalize_path(SRC))
	img.convert(Image.FORMAT_RGBA8)
	var keyed: Image = load("res://tools/build_room_art.gd").key_green(img)
	var lab: Dictionary = load("res://tools/build_battle_art.gd")._label(keyed)
	var cell := Vector2(img.get_width() / 3.0, img.get_height() / 3.0)
	var ok := true
	for i in ORDER.size():
		var area := Rect2(Vector2(i % 3, i / 3) * cell, cell)
		# the tile = the biggest island whose centre is in this cell
		var best: Dictionary = {}
		for isl in lab.islands:
			if area.has_point(Vector2(isl.rect.get_center())) and (best.is_empty() or isl.area > best.area):
				best = isl
		if best.is_empty():
			push_error("no tile for %s" % ORDER[i])
			ok = false
			continue
		var r: Rect2i = best.rect
		# a stray frame strip above can join the tile: keep the bottom square
		var side := mini(r.size.x, r.size.y)
		var tile := Rect2i(r.position.x, r.end.y - side, side, side)
		var inset := int(side * INSET)
		var inner := img.get_region(tile.grow(-inset))
		inner.resize(SIZE, SIZE, Image.INTERPOLATE_LANCZOS)
		_round_corners(inner, SIZE * RADIUS)
		inner.save_png(ProjectSettings.globalize_path("%s/%s.png" % [OUT, ORDER[i]]))
		print("%-14s tile %s" % [ORDER[i], tile])
	print("build_material_art: ", "OK" if ok else "FAILED")
	quit(0 if ok else 1)


static func _round_corners(img: Image, radius: float) -> void:
	var w := img.get_width()
	var h := img.get_height()
	for y in h:
		for x in w:
			var cx := clampf(x + 0.5, radius, w - radius)
			var cy := clampf(y + 0.5, radius, h - radius)
			var d := Vector2(x + 0.5 - cx, y + 0.5 - cy).length()
			if d > radius - 1.0:
				var c := img.get_pixel(x, y)
				c.a *= clampf(radius - d, 0.0, 1.0)
				img.set_pixel(x, y, c)
