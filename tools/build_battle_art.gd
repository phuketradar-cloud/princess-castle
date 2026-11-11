extends SceneTree
## Battle art from AI images in assets/art/source/battle/:
##   bg_<stage>.jpg          16:9 battle backgrounds        -> assets/art/battle_bg/<stage>.png
##   monsters_<stage>.jpg    monsters in one row on green   -> assets/art/monsters_hd/<id>.png
## Monsters are the big green-keyed islands, named left to right; small loose bits (sparks,
## staff orbs, breath fire) join the nearest monster.
##   Godot_console.exe --headless --path . --script res://tools/build_battle_art.gd

const SRC := "res://assets/art/source/battle/"
const BG_OUT := "res://assets/art/battle_bg"
const MON_OUT := "res://assets/art/monsters_hd"
const STAGES := ["stage_01", "stage_02", "stage_03", "stage_04"]
## Left-to-right monster ids per sheet.
const SHEETS := {
	"stage_01": ["slime", "bat", "goblin", "skeleton_knight", "dark_shaman"],
	"stage_02": ["ice_wisp", "frost_golem", "lich_queen"],
	"stage_03": ["imp", "werewolf", "night_witch"],
	"stage_04": ["wyvern", "drake", "elder_wyrm"],
}
const BIG_AREA := 5000   ## islands at least this big are monsters
const MIN_BIT := 100     ## smaller islands are compression noise


func _init() -> void:
	for d in [BG_OUT, MON_OUT]:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(d))
	var ok := true
	for stage in STAGES:
		var bg := Image.load_from_file(ProjectSettings.globalize_path(SRC + "bg_%s.jpg" % stage))
		bg.convert(Image.FORMAT_RGB8)
		bg.save_png(ProjectSettings.globalize_path("%s/%s.png" % [BG_OUT, stage]))
		ok = _cut_sheet(stage) and ok
	print("build_battle_art: ", "OK" if ok else "FAILED")
	quit(0 if ok else 1)


func _cut_sheet(stage: String) -> bool:
	var img := Image.load_from_file(ProjectSettings.globalize_path(SRC + "monsters_%s.jpg" % stage))
	img.convert(Image.FORMAT_RGBA8)
	var keyed: Image = load("res://tools/build_room_art.gd").key_green(img)
	var lab := _label(keyed)
	var islands: Array = lab.islands
	var big := islands.filter(func(i): return i.area >= BIG_AREA)
	big.sort_custom(func(a, b): return a.rect.position.x < b.rect.position.x)
	var ids: Array = SHEETS[stage]
	if big.size() != ids.size():
		push_error("%s: expected %d monsters, found %d" % [stage, ids.size(), big.size()])
		return false
	# group: big island index -> labels
	var groups := []
	for b in big:
		groups.append({"labels": [b.label], "rect": b.rect})
	for i in islands:
		if i.area >= BIG_AREA or i.area < MIN_BIT:
			continue
		var best := 0
		var best_d := INF
		for g in groups.size():
			# Ties (touching several monsters) go to the monster whose centre is nearer.
			var d := _rect_distance(i.rect, big[g].rect) + 0.001 * Vector2(i.rect.get_center()).distance_to(Vector2(big[g].rect.get_center()))
			if d < best_d:
				best_d = d
				best = g
		groups[best].labels.append(i.label)
		groups[best].rect = groups[best].rect.merge(i.rect)
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
		out.save_png(ProjectSettings.globalize_path("%s/%s.png" % [MON_OUT, ids[g]]))
		print("%-16s %s" % [ids[g], r.size])
	return true


static func _rect_distance(a: Rect2i, b: Rect2i) -> float:
	var dx := maxi(0, maxi(a.position.x - b.end.x, b.position.x - a.end.x))
	var dy := maxi(0, maxi(a.position.y - b.end.y, b.position.y - a.end.y))
	return sqrt(dx * dx + dy * dy)


## 8-connected labelling of opaque pixels: {map: PackedInt32Array, islands: [{label, rect, area}]}
static func _label(img: Image) -> Dictionary:
	var w := img.get_width()
	var h := img.get_height()
	var map := PackedInt32Array()
	map.resize(w * h)
	map.fill(-1)
	var islands := []
	for i in w * h:
		if map[i] != -1 or img.get_pixel(i % w, i / w).a <= 0.1:
			continue
		var label := islands.size()
		var minp := Vector2i(w, h)
		var maxp := Vector2i.ZERO
		var area := 0
		var stack := PackedInt32Array([i])
		while not stack.is_empty():
			var j := stack[stack.size() - 1]
			stack.resize(stack.size() - 1)
			if map[j] != -1:
				continue
			var x := j % w
			var y := j / w
			if img.get_pixel(x, y).a <= 0.1:
				continue
			map[j] = label
			area += 1
			minp = Vector2i(mini(minp.x, x), mini(minp.y, y))
			maxp = Vector2i(maxi(maxp.x, x), maxi(maxp.y, y))
			for dy: int in [-1, 0, 1]:
				for dx: int in [-1, 0, 1]:
					var nx := x + dx
					var ny := y + dy
					if nx >= 0 and ny >= 0 and nx < w and ny < h:
						stack.append(ny * w + nx)
		islands.append({"label": label, "rect": Rect2i(minp, maxp - minp + Vector2i.ONE), "area": area})
	return {"map": map, "islands": islands}
