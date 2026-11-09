class_name FloatingText
extends Label
## Damage numbers / MISS / +HP popups. Created from code, float up, fade, free themselves.


static func spawn(parent: Node, world_pos: Vector2, message: String, color: Color, font_size := 46) -> FloatingText:
	var ft := FloatingText.new()
	ft.text = message
	ft.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ft.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	ft.size = Vector2(320, 70)
	ft.pivot_offset = ft.size * 0.5
	ft.position = world_pos - ft.size * 0.5 + Vector2(randf_range(-14, 14), 0)
	ft.z_index = 100
	ft.add_theme_font_size_override("font_size", font_size)
	ft.add_theme_color_override("font_color", color)
	ft.add_theme_color_override("font_outline_color", Color(0.08, 0.03, 0.12))
	ft.add_theme_constant_override("outline_size", 10)
	ft.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(ft)
	ft._animate()
	return ft


func _animate() -> void:
	scale = Vector2(0.6, 0.6)
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector2(1.2, 1.2), 0.12)
	tw.tween_property(self, "scale", Vector2.ONE, 0.12)
	var move := create_tween().set_parallel()
	move.tween_property(self, "position:y", position.y - 90.0, 0.9).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	move.tween_property(self, "modulate:a", 0.0, 0.35).set_delay(0.55)
	move.chain().tween_callback(queue_free)
