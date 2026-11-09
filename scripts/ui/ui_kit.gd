class_name UIKit
## Small helpers so code-built screens share one gothic look.

const PANEL := Color(0.1, 0.055, 0.15, 1.0)

static var _icon_cache := {}


## Icon = the item's layer art cropped to its visible pixels (layer art has lots of padding
## because it is positioned on the body).
static func icon_texture(item: EquipmentDefinition) -> Texture2D:
	if item == null or item.texture == null:
		return null
	if _icon_cache.has(item.id):
		return _icon_cache[item.id]
	var img := item.texture.get_image()
	var tex: Texture2D = item.texture
	if img != null:
		var used := img.get_used_rect().grow(4).intersection(Rect2i(Vector2i.ZERO, img.get_size()))
		if used.size.x > 0 and used.size.y > 0:
			var atlas := AtlasTexture.new()
			atlas.atlas = item.texture
			atlas.region = Rect2(used)
			tex = atlas
	_icon_cache[item.id] = tex
	return tex
const EDGE := Color(0.47, 0.27, 0.59)
const GOLD := Color(1, 0.84, 0.47)
const LAVENDER := Color(0.84, 0.77, 0.94)
const BUTTON := Color8(170, 50, 90)
const BUTTON_ALT := Color8(95, 60, 160)


static func panel_style(bg := PANEL, border := EDGE, radius := 24, border_w := 4) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(border_w)
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = 20
	sb.content_margin_right = 20
	sb.content_margin_top = 16
	sb.content_margin_bottom = 16
	return sb


static func panel(bg := PANEL, border := EDGE, radius := 24, border_w := 4) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", panel_style(bg, border, radius, border_w))
	return p


static func label(text: String, size := 28, color := LAVENDER, align := HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = align
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


static func button(text: String, color := BUTTON, size := 30, min_size := Vector2(220, 80)) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = min_size
	b.add_theme_font_size_override("font_size", size)
	style_button(b, color)
	return b


static func style_button(b: Button, color: Color, radius := 18) -> void:
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		var sb := StyleBoxFlat.new()
		sb.set_corner_radius_all(radius)
		sb.set_border_width_all(3)
		sb.border_color = Color(1, 1, 1, 0.25)
		match state:
			"normal": sb.bg_color = color
			"hover": sb.bg_color = color.lightened(0.15)
			"pressed": sb.bg_color = color.darkened(0.25)
			"disabled":
				sb.bg_color = color.darkened(0.55)
				sb.border_color = Color(1, 1, 1, 0.08)
			"focus":
				sb.draw_center = false
				sb.border_color = Color(1, 0.85, 0.5, 0.8)
		b.add_theme_stylebox_override(state, sb)
	b.add_theme_color_override("font_disabled_color", Color(1, 1, 1, 0.35))


## Full-screen dimmer that blocks clicks to whatever is behind it.
static func dimmer(alpha := 0.75) -> ColorRect:
	var c := ColorRect.new()
	c.color = Color(0, 0, 0, alpha)
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_STOP
	return c


## Item icon: the layer art centered and scaled to fit a square.
static func item_icon(item: EquipmentDefinition, size := 120.0) -> Control:
	var frame := PanelContainer.new()
	var color := ItemTypes.rarity_color(item.rarity) if item != null else EDGE
	frame.add_theme_stylebox_override("panel", panel_style(Color(0.05, 0.02, 0.08, 1), color, 16, 4))
	frame.custom_minimum_size = Vector2(size, size)
	var tex := TextureRect.new()
	tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tex.texture = icon_texture(item)
	tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(tex)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return frame


## Card art in a frame coloured by rarity (category colour inside).
static func card_icon(card: CardDefinition, size := 120.0) -> Control:
	var frame := PanelContainer.new()
	var sb := panel_style(CardTypes.category_color(card.category).darkened(0.7), ItemTypes.rarity_color(card.rarity), 18, 4)
	frame.add_theme_stylebox_override("panel", sb)
	frame.custom_minimum_size = Vector2(size, size)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tex := TextureRect.new()
	tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tex.texture = card.icon
	tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(tex)
	return frame


## A tappable card tile: art, name, cost, optional count badge.
static func card_tile(card: CardDefinition, count := -1, width := 190.0, selected := false, dimmed := false) -> Button:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(width, width * 1.32)
	b.tooltip_text = card.description
	for state in ["normal", "hover", "pressed", "disabled"]:
		var sb := panel_style(Color(0.07, 0.04, 0.11, 1), ItemTypes.rarity_color(card.rarity), 18, 7 if selected else 4)
		if state == "hover": sb.bg_color = Color(0.15, 0.08, 0.22, 1)
		b.add_theme_stylebox_override(state, sb)
	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.offset_left = 10
	v.offset_right = -10
	v.offset_top = 10
	v.offset_bottom = -8
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_theme_constant_override("separation", 4)
	b.add_child(v)
	var icon := card_icon(card, width - 40)
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(icon)
	var name_l := label(card.display_name, 21, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	name_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(name_l)
	var info := label("◆%d  %s" % [card.mana_cost, CardTypes.category_name(card.category)], 18,
		CardTypes.category_color(card.category).lightened(0.4), HORIZONTAL_ALIGNMENT_CENTER)
	info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(info)
	if count >= 0:
		var badge := label("x%d" % count, 24, GOLD)
		badge.autowrap_mode = TextServer.AUTOWRAP_OFF
		badge.position = Vector2(12, 4)
		badge.add_theme_color_override("font_outline_color", Color(0.05, 0.02, 0.08))
		badge.add_theme_constant_override("outline_size", 8)
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(badge)
	if dimmed:
		# "dimmed" = already in the deck: tag it instead of hiding it.
		b.modulate = Color(1, 1, 1, 0.75)
		var tag := label("ในเด็ค", 20, Color(0.55, 1, 0.7))
		tag.autowrap_mode = TextServer.AUTOWRAP_OFF
		tag.add_theme_color_override("font_outline_color", Color(0.05, 0.02, 0.08))
		tag.add_theme_constant_override("outline_size", 8)
		tag.position = Vector2(width - 74, 4)
		tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(tag)
	return b


## "ATK +6 (+3)" style lines comparing an item with what is equipped in that slot.
static func compare_text(item: EquipmentDefinition, current: EquipmentDefinition) -> String:
	var lines: Array[String] = []
	var d := ItemStats.diff(item.bonus(), current.bonus() if current != null else StatBlock.make(0, 0, 0))
	var diff_lines := ItemStats.describe(d)
	for line in item.stat_lines():
		lines.append(line)
	if current != null and current.id != item.id and not diff_lines.is_empty():
		lines.append("เทียบของเดิม: " + ", ".join(diff_lines))
	if item.special != ItemTypes.Special.NONE:
		lines.append("★ " + ItemTypes.special_text(item.special, item.special_value))
	return "\n".join(lines)
