extends SceneTree
## Dev helper: contact sheet of all card + essence icons.
##   Godot_console.exe --path . --resolution 1920x1080 --script res://tools/preview_cards.gd -- --out=C:/tmp/cards.png
var frames := 0
var out := ""
func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="): out = a.substr(6)
	var bg := ColorRect.new()
	bg.color = Color8(40, 22, 60)
	bg.size = Vector2(1920, 1080)
	root.add_child(bg)
	var files := DirAccess.get_files_at("res://assets/art/cards")
	var i := 0
	for f in files:
		if not f.ends_with(".png"): continue
		var t := TextureRect.new()
		t.texture = load("res://assets/art/cards/" + f)
		t.position = Vector2(30 + (i % 9) * 210, 30 + (i / 9) * 330)
		root.add_child(t)
		var l := Label.new()
		l.text = f.get_basename()
		l.position = t.position + Vector2(0, 165)
		root.add_child(l)
		i += 1
func _process(_d: float) -> bool:
	frames += 1
	if frames == 5:
		root.get_texture().get_image().save_png(out)
		return true
	return false
