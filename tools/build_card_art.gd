extends SceneTree
## Card / skill icons from AI sheets in assets/art/source/cards/: a grid of painted icons
## separated by thin black lines -> assets/art/cards/<id>.png (full cell, its own background).
## The black gutters are found automatically (dark rows / columns); if that fails the sheet is
## cut into an even grid.
##   Godot_console.exe --headless --path . --script res://tools/build_card_art.gd

const SRC := "res://assets/art/source/cards/"
const OUT := "res://assets/art/cards"
## sheet -> [columns, rows, ids in reading order ("" = skip that cell)]
const SHEETS := {
	"cards_1.jpg": [4, 3, ["fireball", "fire_blast", "meteor", "dragon_breath",
		"dragons_wrath", "heal", "holy_shield", "lucky_day",
		"ice_prison", "sleep", "silence", "banish"]],
	"cards_2.jpg": [3, 3, ["shadow_prison", "shadow_execution", "dimensional_prison",
		"time_stop", "arcane_surge", "dragon_soul",
		"night_veil", "rose_oath", "saints_grace"]],
	# the AI drew a 4th row (repeats of row 3): skipped
	"skills.jpg": [4, 4, ["skill_crescent_slash", "skill_pommel_bash", "skill_chain_lightning", "skill_frost_lance",
		"skill_twin_fangs", "skill_assassinate", "skill_prayer", "skill_sanctuary",
		"skill_dragon_roar", "skill_dragon_fang", "skill_defend", "",
		"", "", "", ""]],
}
const DARK := 0.09   ## gutter pixels are darker than this
const INSET := 3     ## px trimmed inside each cell (soft gutter edge)


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var ok := true
	var done := 0
	for sheet in SHEETS:
		var path := ProjectSettings.globalize_path(SRC + sheet)
		if not FileAccess.file_exists(path):
			continue # sheet not made yet
		var img := Image.load_from_file(path)
		img.convert(Image.FORMAT_RGB8)
		var cfg: Array = SHEETS[sheet]
		var xs := _cuts(img, true, cfg[0])
		var ys := _cuts(img, false, cfg[1])
		var ids: Array = cfg[2]
		for r in cfg[1]:
			for c in cfg[0]:
				var id: String = ids[r * cfg[0] + c]
				if id == "":
					continue
				var rect := Rect2i(xs[c].x + INSET, ys[r].x + INSET, xs[c].y - xs[c].x - INSET * 2, ys[r].y - ys[r].x - INSET * 2)
				var cell := img.get_region(rect)
				cell.save_png(ProjectSettings.globalize_path("%s/%s.png" % [OUT, id]))
				done += 1
		print("%-12s cols %s rows %s" % [sheet, xs, ys])
	print("build_card_art: %d icons %s" % [done, "OK" if ok else "FAILED"])
	quit(0 if ok else 1)


## Cell spans along one axis: [start, end) pairs between dark gutter lines.
func _cuts(img: Image, vertical: bool, count: int) -> Array:
	var n := img.get_width() if vertical else img.get_height()
	var m := img.get_height() if vertical else img.get_width()
	var dark := []
	for i in n:
		# a gutter is near-black almost all the way across (dark art is not that uniform)
		var black := 0
		var total := 0
		for j in range(0, m, 2):
			var col := img.get_pixel(i, j) if vertical else img.get_pixel(j, i)
			total += 1
			if col.get_luminance() < DARK:
				black += 1
		dark.append(float(black) / total > 0.9)
	# runs of non-dark lines = cells
	var spans := []
	var start := -1
	for i in n + 1:
		var is_cell: bool = i < n and not dark[i]
		if is_cell and start < 0:
			start = i
		elif not is_cell and start >= 0:
			if i - start > n / (count * 3):
				spans.append(Vector2i(start, i))
			start = -1
	if spans.size() == count:
		return spans
	# fallback: even grid
	spans.clear()
	for k in count:
		spans.append(Vector2i(n * k / count, n * (k + 1) / count))
	return spans
