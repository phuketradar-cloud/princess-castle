extends SceneTree
## Room art from AI images in assets/art/source/rooms/:
##   <wing>_bg.jpg          empty room background (16:9)          -> assets/art/rooms_hd/<wing>.png
##   furniture_sheet.jpg    12 furniture pieces on green, 4x3 grid -> assets/art/furniture_hd/<id>.png
## Pieces are found automatically (green key + separate islands) and named by grid position.
##   Godot_console.exe --headless --path . --script res://tools/build_room_art.gd

const SRC := "res://assets/art/source/rooms/"
const ROOMS_OUT := "res://assets/art/rooms_hd"
const FURN_OUT := "res://assets/art/furniture_hd"
const BACKGROUNDS := ["sword_wing", "magic_wing", "shadow_wing", "light_wing", "dragon_wing"]
## Grid order of furniture_sheet.jpg (rows top to bottom, left to right).
const SHEET_ORDER := [
	"simple_bed", "old_desk", "wooden_dummy", "plain_chair",
	"rose_training_hall", "rose_vanity", "lucky_bed", "tea_set_table",
	"training_dummy", "velvet_wardrobe", "pink_canopy_bed", "starry_canopy_bed",
]


func _init() -> void:
	for d in [ROOMS_OUT, FURN_OUT]:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(d))
	for wing in BACKGROUNDS:
		var bg := Image.load_from_file(ProjectSettings.globalize_path(SRC + wing + "_bg.jpg"))
		bg.convert(Image.FORMAT_RGB8)
		bg.save_png(ProjectSettings.globalize_path("%s/%s.png" % [ROOMS_OUT, wing]))
		print("background %s %s" % [wing, bg.get_size()])

	var sheet := Image.load_from_file(ProjectSettings.globalize_path(SRC + "furniture_sheet.jpg"))
	sheet.convert(Image.FORMAT_RGBA8)
	var keyed := key_green(sheet)
	SheetCutter.remove_small(keyed, 1500)
	var parts := SheetCutter.components(keyed, 1500)
	if parts.size() != SHEET_ORDER.size():
		push_error("expected %d furniture pieces, found %d" % [SHEET_ORDER.size(), parts.size()])
		quit(1)
		return
	# Grid order: cluster into rows by vertical centre, then left to right.
	parts.sort_custom(func(a, b): return a.rect.get_center().y < b.rect.get_center().y)
	var ordered := []
	for row in 3:
		var r := parts.slice(row * 4, row * 4 + 4)
		r.sort_custom(func(a, b): return a.rect.get_center().x < b.rect.get_center().x)
		ordered.append_array(r)
	for i in ordered.size():
		var rect: Rect2i = ordered[i].rect
		var piece := Image.create(rect.size.x, rect.size.y, false, Image.FORMAT_RGBA8)
		piece.blit_rect(keyed, rect, Vector2i.ZERO)
		piece.save_png(ProjectSettings.globalize_path("%s/%s.png" % [FURN_OUT, SHEET_ORDER[i]]))
		print("%-20s %s" % [SHEET_ORDER[i], rect])
	print("build_room_art: OK")
	quit()


## Magenta screen (#FF00FF) for art with green in it (e.g. green eyes): alpha from how much
## more red+blue than green a pixel has; despill pulls blue back to green.
static func key_magenta(src: Image) -> Image:
	var img := src.duplicate() as Image
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			var m := minf(c.r, c.b) - c.g
			var a := clampf(1.0 - (m - 0.12) / 0.25, 0.0, 1.0)
			if a < 1.0:
				c.b = minf(c.b, c.g)
			c.a = a
			img.set_pixel(x, y, c if a > 0.02 else Color(0, 0, 0, 0))
	return img


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

