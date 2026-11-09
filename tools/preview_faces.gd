extends SceneTree
## Dev helper: every princess x every expression (paper doll + face layers).
##   Godot_console.exe --path . --resolution 1920x1080 --script res://tools/preview_faces.gd -- --out=C:/tmp/faces.png
var frames := 0
var out := ""
func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="): out = a.substr(6)
	var bg := ColorRect.new()
	bg.color = Color8(60, 30, 85)
	bg.size = Vector2(1920, 1080)
	bg.z_index = -50
	root.add_child(bg)
	var ids := ["sword_princess", "magic_princess", "shadow_princess", "light_princess", "dragon_princess"]
	for r in ids.size():
		for e in 8:
			var d := PaperDoll.new()
			root.add_child(d)
			d.position = Vector2(110 + e * 235, 215 + r * 210)
			d.scale = Vector2(0.95, 0.95)
			d.setup(load("res://assets/art/princesses/%s/body.png" % ids[r]), Color.WHITE, false, {})
			d.setup_face("res://assets/art/princesses/" + ids[r], Vector2(-4, -168))
			d.set_expression(e)
			d._blink_left = 999
func _process(_d: float) -> bool:
	frames += 1
	if frames == 5:
		root.get_texture().get_image().save_png(out)
		return true
	return false
