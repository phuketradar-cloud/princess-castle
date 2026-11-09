extends SceneTree
## Dev helper: renders the princess wearing every item tier side by side to check alignment.
##   Godot_console.exe --path . --resolution 1500x420 --script res://tools/preview_doll.gd -- --out=C:/tmp/doll.png
var frames := 0
var out := ""

func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="): out = a.substr(6)
	var anchors := PrincessDefinition.new().slot_anchors
	var sets := [
		[],
		["rusty_sword", "ribbon_bow", "moth_wings", "leather_corset", "clover_charm"],
		["rose_rapier", "silver_tiara", "bat_wings", "lace_guard_dress", "ruby_pendant"],
		["moonlight_blade", "witch_hat", "fairy_wings", "thorn_plate", "vampire_locket"],
		["dragon_sword", "queen_crown", "dragon_wings", "rose_knight_armor", "mirror_of_thorns"],
		["abyss_scythe", "starfall_halo", "seraph_wings", "rose_knight_armor", "moon_tear"],
	]
	var slots := {"rusty_sword": 0, "rose_rapier": 0, "moonlight_blade": 0, "dragon_sword": 0, "abyss_scythe": 0,
		"ribbon_bow": 1, "silver_tiara": 1, "witch_hat": 1, "queen_crown": 1, "starfall_halo": 1,
		"moth_wings": 2, "bat_wings": 2, "fairy_wings": 2, "dragon_wings": 2, "seraph_wings": 2,
		"leather_corset": 3, "lace_guard_dress": 3, "thorn_plate": 3, "rose_knight_armor": 3,
		"clover_charm": 4, "ruby_pendant": 4, "vampire_locket": 4, "mirror_of_thorns": 4, "moon_tear": 4}
	var bg := ColorRect.new()
	bg.color = Color8(60, 30, 85)
	bg.size = Vector2(3000, 3000)
	bg.z_index = -50
	root.add_child(bg)
	for i in sets.size():
		var doll := PaperDoll.new()
		root.add_child(doll)
		doll.position = Vector2(170 + i * 315, 900)
		doll.scale = Vector2(2.4, 2.4)
		doll.setup(load("res://assets/art/princess_base.png"), Color.WHITE, false, anchors)
		var items := []
		for id in sets[i]:
			var e := EquipmentDefinition.new()
			e.slot = slots[id]
			e.texture = load("res://assets/art/items/%s.png" % id)
			items.append(e)
		doll.set_equipment(items)

func _process(_d: float) -> bool:
	frames += 1
	if frames == 5:
		root.get_texture().get_image().save_png(out)
		return true
	return false
