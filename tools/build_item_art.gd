extends SceneTree
## Equipment art from AI sheets in assets/art/source/items/ (green screen) -> assets/art/items_hd/<id>.png
## Each sheet lists its items with a cell (sheet px): a big island belongs to the cell holding its
## centre; small bits (sparkles, glow specks, the second half of a wing pair) join the nearest item.
##   Godot_console.exe --headless --path . --script res://tools/build_item_art.gd
## Placement on the princess (scale / offset) lives in tools/generate_data.gd HD_ITEMS.

const SRC := "res://assets/art/source/items/"
const OUT := "res://assets/art/items_hd"
const BIG_AREA := 2500   ## islands at least this big are item parts
const MIN_BIT := 25      ## smaller islands are compression noise

const SHEETS := {
	"weapons.jpg": [
		["rusty_sword", Rect2i(0, 0, 330, 768)], ["moonlight_blade", Rect2i(330, 0, 270, 768)],
		["dragon_sword", Rect2i(600, 0, 300, 768)], ["abyss_scythe", Rect2i(900, 0, 476, 768)],
	],
	"headgear.jpg": [
		["ribbon_bow", Rect2i(0, 0, 340, 768)], ["witch_hat", Rect2i(340, 0, 380, 768)],
		["queen_crown", Rect2i(720, 0, 310, 768)], ["starfall_halo", Rect2i(1030, 0, 346, 768)],
	],
	# bat / dragon wings are two halves each: both halves' centres sit in the cell
	"wings.jpg": [
		["moth_wings", Rect2i(0, 0, 300, 768)], ["bat_wings", Rect2i(300, 0, 265, 768)],
		["fairy_wings", Rect2i(565, 0, 240, 768)], ["dragon_wings", Rect2i(805, 0, 275, 768)],
		["seraph_wings", Rect2i(1080, 0, 296, 768)],
	],
	# 4 columns: armor / dress / plate ... ; the last column holds 3 small pendants
	"icons.jpg": [
		["leather_corset", Rect2i(0, 0, 340, 280)], ["rose_knight_armor", Rect2i(0, 280, 340, 488)],
		["lace_guard_dress", Rect2i(340, 0, 360, 360)], ["clover_charm", Rect2i(340, 360, 360, 408)],
		["thorn_plate", Rect2i(700, 0, 370, 360)], ["mirror_of_thorns", Rect2i(700, 360, 370, 408)],
		["ruby_pendant", Rect2i(1070, 0, 306, 275)], ["vampire_locket", Rect2i(1070, 275, 306, 245)],
		["moon_tear", Rect2i(1070, 520, 306, 248)],
	],
}


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var ok := true
	for sheet in SHEETS:
		ok = _cut(sheet, SHEETS[sheet]) and ok
	print("build_item_art: ", "OK" if ok else "FAILED")
	quit(0 if ok else 1)


func _cut(file: String, items: Array) -> bool:
	var img := Image.load_from_file(ProjectSettings.globalize_path(SRC + file))
	img.convert(Image.FORMAT_RGBA8)
	var keyed: Image = load("res://tools/build_room_art.gd").key_green(img)
	var battle = load("res://tools/build_battle_art.gd")
	var lab: Dictionary = battle._label(keyed)
	var groups := []
	for it in items:
		groups.append({"labels": [], "rect": Rect2i()})
	var small := []
	for isl in lab.islands:
		if isl.area < MIN_BIT:
			continue
		if isl.area < BIG_AREA:
			small.append(isl)
			continue
		var c: Vector2i = isl.rect.get_center()
		var found := false
		for g in items.size():
			if (items[g][1] as Rect2i).has_point(c):
				_add(groups[g], isl)
				found = true
				break
		if not found:
			push_error("%s: island at %s is in no cell" % [file, c])
			return false
	for g in groups.size():
		if groups[g].labels.is_empty():
			push_error("%s: nothing found for %s" % [file, items[g][0]])
			return false
	for isl in small:
		var best := 0
		var best_d := INF
		for g in groups.size():
			var d: float = battle._rect_distance(isl.rect, groups[g].rect)
			if d < best_d:
				best_d = d
				best = g
		if best_d < 40.0: # far-off specks are noise
			_add(groups[best], isl)
	var w := keyed.get_width()
	for g in groups.size():
		var r: Rect2i = groups[g].rect.grow(2).intersection(Rect2i(Vector2i.ZERO, keyed.get_size()))
		var out := Image.create(r.size.x, r.size.y, false, Image.FORMAT_RGBA8)
		out.fill(Color(0, 0, 0, 0))
		var keep := {}
		for l in groups[g].labels:
			keep[l] = true
		for y in r.size.y:
			for x in r.size.x:
				var p := r.position + Vector2i(x, y)
				if keep.has(lab.map[p.y * w + p.x]):
					out.set_pixel(x, y, keyed.get_pixelv(p))
		out.save_png(ProjectSettings.globalize_path("%s/%s.png" % [OUT, items[g][0]]))
		print("%-18s %s parts %d" % [items[g][0], r.size, groups[g].labels.size()])
	return true


static func _add(group: Dictionary, isl: Dictionary) -> void:
	group.rect = isl.rect if group.labels.is_empty() else group.rect.merge(isl.rect)
	group.labels.append(isl.label)
