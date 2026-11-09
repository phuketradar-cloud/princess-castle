class_name RewardScreen
extends CanvasLayer
## "CHOOSE A REWARD": 3 cards after a won battle, the player picks exactly one.
## Emits `chosen(index)`; BattleController applies it. Built in code (see UIKit).

signal chosen(index: int)

var cards: Array[Button] = []
var _root: Control


func _init() -> void:
	layer = 20
	visible = false


func show_options(options: Array, collection: Collection, princess_id: String, title := "CHOOSE A REWARD") -> void:
	if _root != null:
		_root.queue_free()
	cards.clear()
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root)
	_root.add_child(UIKit.dimmer(0.78))

	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 30)
	_root.add_child(v)
	var t := UIKit.label(title, 64, UIKit.GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	t.add_theme_color_override("font_outline_color", Color(0.08, 0.03, 0.12))
	t.add_theme_constant_override("outline_size", 12)
	v.add_child(t)
	v.add_child(UIKit.label("เลือกได้ 1 อย่าง — อุปกรณ์จะสวมใส่ทันที • การ์ดเข้าคอลเลกชันถาวร", 26, UIKit.LAVENDER, HORIZONTAL_ALIGNMENT_CENTER))

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 34)
	v.add_child(row)
	for i in options.size():
		var card := _make_card(options[i], collection, princess_id)
		card.pressed.connect(func(): _pick(i))
		row.add_child(card)
		cards.append(card)

	visible = true
	_root.modulate.a = 0.0
	create_tween().tween_property(_root, "modulate:a", 1.0, 0.25)


func _pick(index: int) -> void:
	for c in cards:
		c.disabled = true
	visible = false
	chosen.emit(index)


func _make_card(option, collection: Collection, princess_id: String) -> Button:
	var card := Button.new()
	card.custom_minimum_size = Vector2(440, 600)
	card.focus_mode = Control.FOCUS_NONE
	var color := UIKit.EDGE
	if option.kind == LootTable.RewardOption.Kind.EQUIPMENT:
		color = ItemTypes.rarity_color(option.item.rarity)
	elif option.kind == LootTable.RewardOption.Kind.CARD:
		color = ItemTypes.rarity_color(option.card.rarity)
	for state in ["normal", "hover", "pressed", "disabled"]:
		var sb := UIKit.panel_style(Color(0.09, 0.05, 0.14, 0.98), color, 26, 5)
		if state == "hover":
			sb.bg_color = Color(0.16, 0.09, 0.24, 1)
			sb.set_border_width_all(8)
		elif state == "pressed":
			sb.bg_color = Color(0.22, 0.12, 0.3, 1)
		card.add_theme_stylebox_override(state, sb)

	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.offset_left = 24
	box.offset_right = -24
	box.offset_top = 24
	box.offset_bottom = -24
	box.add_theme_constant_override("separation", 12)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(box)

	if option.kind == LootTable.RewardOption.Kind.EQUIPMENT:
		var it: EquipmentDefinition = option.item
		var icon := UIKit.item_icon(it, 210)
		icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		box.add_child(icon)
		box.add_child(_l("%s  •  %s" % [ItemTypes.rarity_name(it.rarity), ItemTypes.slot_name(it.slot)], 24, color))
		box.add_child(_l(it.display_name, 36, Color.WHITE))
		var current := collection.equipped_in(princess_id, it.slot)
		box.add_child(_l(UIKit.compare_text(it, current), 24, UIKit.LAVENDER))
		box.add_child(_l("\"%s\"" % it.description, 22, Color(1, 1, 1, 0.55)))
	elif option.kind == LootTable.RewardOption.Kind.CARD:
		var c: CardDefinition = option.card
		var icon := UIKit.card_icon(c, 210)
		icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		box.add_child(icon)
		box.add_child(_l("%s  •  การ์ด %s  •  ◆%d มานา" % [ItemTypes.rarity_name(c.rarity), CardTypes.category_name(c.category), c.mana_cost], 22, color))
		box.add_child(_l(c.display_name, 36, Color.WHITE))
		box.add_child(_l(c.description, 24, UIKit.LAVENDER))
		var have := collection.card_count(c.id)
		box.add_child(_l("มีอยู่แล้ว %d ใบ (ใช้รวมการ์ดได้)" % have if have > 0 else "★ การ์ดใหม่! เข้าเด็คอัตโนมัติถ้ามีที่ว่าง", 22, Color(1, 1, 1, 0.6)))
	else:
		var heart := UIKit.label("♥", 150, Color(0.45, 1, 0.6), HORIZONTAL_ALIGNMENT_CENTER)
		box.add_child(heart)
		box.add_child(_l("Restore", 24, UIKit.LAVENDER))
		box.add_child(_l("พักฟื้นทันที", 36, Color.WHITE))
		box.add_child(_l("ฟื้น HP %d%% ของ HP สูงสุด" % roundi(option.heal_fraction * 100), 24, UIKit.LAVENDER))
	for c in box.get_children():
		if c is Control:
			c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return card


func _l(text: String, size: int, color: Color) -> Label:
	var l := UIKit.label(text, size, color, HORIZONTAL_ALIGNMENT_CENTER)
	l.custom_minimum_size.x = 380
	return l
