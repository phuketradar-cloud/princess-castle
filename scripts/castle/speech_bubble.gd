class_name SpeechBubble
extends PanelContainer
## A comic speech bubble that follows a world position and fades out by itself.
## SpeechBubble.say(parent, world_pos, text) -> bubble


var _life := 0.0
var _label: Label


static func say(parent: Node, world_pos: Vector2, text: String, seconds := 3.0, font_size := 30) -> SpeechBubble:
	var b := SpeechBubble.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(1, 0.98, 1, 0.97)
	sb.border_color = Color(0.3, 0.15, 0.4)
	sb.set_border_width_all(4)
	sb.set_corner_radius_all(22)
	sb.content_margin_left = 22
	sb.content_margin_right = 22
	sb.content_margin_top = 12
	sb.content_margin_bottom = 12
	sb.shadow_color = Color(0, 0, 0, 0.3)
	sb.shadow_size = 6
	b.add_theme_stylebox_override("panel", sb)
	b._label = Label.new()
	b._label.text = text
	b._label.add_theme_font_size_override("font_size", font_size)
	b._label.add_theme_color_override("font_color", Color(0.18, 0.08, 0.25))
	b._label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b._label.custom_minimum_size.x = clampf(text.length() * font_size * 0.45, 160, 520)
	b._label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.add_child(b._label)
	b.z_index = 300
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b._label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b._life = seconds
	parent.add_child(b)
	b.reset_size()
	b.position = world_pos - Vector2(b.size.x * 0.5, b.size.y)
	b.pivot_offset = Vector2(b.size.x * 0.5, b.size.y)
	b.scale = Vector2(0.6, 0.6)
	b.create_tween().tween_property(b, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	return b


func text() -> String:
	return _label.text if _label else ""


func _process(delta: float) -> void:
	_life -= delta
	if _life < 0.4:
		modulate.a = clampf(_life / 0.4, 0.0, 1.0)
	if _life <= 0.0:
		queue_free()
