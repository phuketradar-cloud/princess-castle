class_name EquipmentScreen
extends CanvasLayer
## Equipment + Inventory + Character Status in one screen.
##   left  : live paper-doll preview and total stats (base + equipment)
##   middle: the 5 equipment slots (tap = filter the bag by that slot)
##   right : bag grid, item details with comparison, Equip / Unequip
## Changes are applied to the Collection immediately and `equipment_changed` is emitted.

signal closed
signal equipment_changed

var princess: PrincessDefinition
var collection: Collection

var _root: Control
var _doll: PaperDoll
var _stats_label: Label
var _slot_buttons := {}       # slot -> Button
var _bag_grid: GridContainer
var _detail_title: Label
var _detail_body: Label
var _action_button: Button
var _speech: Label
var dialogue: DialogueDB
var bond_level := 0
var furniture_bonus: StatBlock
## Phase 5: her level (base stats grow with it).
var level := 1
## Last reaction line (tests).
var last_speech := ""
var _filter_slot := -1
var _selected_id := ""


func _init() -> void:
	layer = 30
	visible = false


func open(p_princess: PrincessDefinition, p_collection: Collection, p_dialogue: DialogueDB = null, p_bond := 0, p_furniture: StatBlock = null, p_level := 1) -> void:
	level = maxi(1, p_level)
	dialogue = p_dialogue
	bond_level = p_bond
	furniture_bonus = p_furniture
	princess = p_princess
	collection = p_collection
	if _root == null:
		_build()
	_filter_slot = -1
	_selected_id = ""
	_refresh()
	visible = true


func close() -> void:
	visible = false
	closed.emit()


# ------------------------------------------------------------ actions

func select_item(item_id: String) -> void:
	_selected_id = item_id
	_refresh_details()


## Equips (or unequips if already worn) the selected item.
func toggle_selected() -> void:
	var it := collection.get_item(_selected_id)
	if it == null:
		return
	if collection.is_equipped(princess.id, it.id):
		collection.unequip(princess.id, it.slot)
	else:
		var previous := collection.equip(princess.id, it.id)
		_react("ITEM_CHANGED" if previous != null else "ITEM_EQUIPPED", it)
	equipment_changed.emit()
	_refresh()


func filter_slot(slot: int) -> void:
	_filter_slot = -1 if _filter_slot == slot else slot
	_refresh_bag()


# ------------------------------------------------------------ build

func _build() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root)
	_root.add_child(UIKit.dimmer(0.85))

	var main := UIKit.panel()
	main.set_anchors_preset(Control.PRESET_FULL_RECT)
	main.offset_left = 36
	main.offset_top = 30
	main.offset_right = -36
	main.offset_bottom = -30
	_root.add_child(main)

	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 14)
	main.add_child(outer)

	var header := HBoxContainer.new()
	outer.add_child(header)
	var title := UIKit.label("อุปกรณ์ & สถานะ", 44, UIKit.GOLD)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	var close_btn := UIKit.button("ปิด", UIKit.BUTTON_ALT, 30, Vector2(180, 70))
	close_btn.name = "CloseButton"
	close_btn.pressed.connect(close)
	header.add_child(close_btn)

	var cols := HBoxContainer.new()
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cols.add_theme_constant_override("separation", 22)
	outer.add_child(cols)

	# --- left: preview + stats
	var left := VBoxContainer.new()
	left.custom_minimum_size.x = 470
	left.add_theme_constant_override("separation", 10)
	cols.add_child(left)
	var vp_box := SubViewportContainer.new()
	vp_box.custom_minimum_size = Vector2(470, 560)
	vp_box.stretch = true
	left.add_child(vp_box)
	var vp := SubViewport.new()
	vp.transparent_bg = true
	vp.size = Vector2i(470, 560)
	vp_box.add_child(vp)
	var floor_glow := EllipseShape.new()
	floor_glow.radius = Vector2(150, 30)
	floor_glow.color = Color(0.75, 0.55, 1, 0.25)
	floor_glow.position = Vector2(235, 520)
	vp.add_child(floor_glow)
	_doll = PaperDoll.new()
	_doll.position = Vector2(235, 520)
	_doll.scale = Vector2(2.0, 2.0)
	vp.add_child(_doll)
	_speech = UIKit.label("", 24, Color(1, 0.9, 1))
	left.add_child(_speech)
	_stats_label = UIKit.label("", 28, UIKit.LAVENDER)
	left.add_child(_stats_label)

	# --- middle: slots
	var mid := VBoxContainer.new()
	mid.custom_minimum_size.x = 400
	mid.add_theme_constant_override("separation", 12)
	cols.add_child(mid)
	mid.add_child(UIKit.label("ช่องสวมใส่ (แตะเพื่อกรองกระเป๋า)", 24, UIKit.LAVENDER))
	for slot in ItemTypes.Slot.values():
		var b := UIKit.button("", Color(0.16, 0.09, 0.24), 24, Vector2(400, 108))
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.expand_icon = true
		b.add_theme_constant_override("icon_max_width", 84)
		b.pressed.connect(func(): filter_slot(slot))
		mid.add_child(b)
		_slot_buttons[slot] = b

	# --- right: bag + details
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 12)
	cols.add_child(right)
	right.add_child(UIKit.label("กระเป๋า", 30, UIKit.GOLD))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right.add_child(scroll)
	_bag_grid = GridContainer.new()
	_bag_grid.columns = 5
	_bag_grid.add_theme_constant_override("h_separation", 12)
	_bag_grid.add_theme_constant_override("v_separation", 12)
	scroll.add_child(_bag_grid)

	var detail := UIKit.panel(Color(0.06, 0.03, 0.09, 1), UIKit.EDGE, 18, 3)
	detail.custom_minimum_size.y = 300
	right.add_child(detail)
	var dv := VBoxContainer.new()
	dv.add_theme_constant_override("separation", 8)
	detail.add_child(dv)
	_detail_title = UIKit.label("เลือกไอเท็มในกระเป๋า", 32, Color.WHITE)
	dv.add_child(_detail_title)
	_detail_body = UIKit.label("", 24, UIKit.LAVENDER)
	_detail_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	dv.add_child(_detail_body)
	_action_button = UIKit.button("สวมใส่", UIKit.BUTTON, 30, Vector2(260, 74))
	_action_button.name = "EquipButton"
	_action_button.size_flags_horizontal = Control.SIZE_SHRINK_END
	_action_button.pressed.connect(toggle_selected)
	dv.add_child(_action_button)


# ------------------------------------------------------------ refresh

func _refresh() -> void:
	var gear := collection.equipped_items(princess.id)
	_doll.setup(princess.battle_texture, Color.WHITE, false, princess.slot_anchors, princess.art_scale)
	_doll.setup_face(princess.face_dir, princess.face_anchor)
	_doll.set_equipment(gear)

	# Character status: total with the equipment part in brackets.
	var b := princess.level_stats(level)
	var total := ItemStats.total(b, gear)
	if furniture_bonus != null:
		total = total.plus(furniture_bonus)
	_stats_label.text = "\n".join([
		"%s  Lv%d" % [princess.display_name, level],
		"HP   %d  (+%d)" % [total.max_hp, total.max_hp - b.max_hp],
		"ATK  %d  (+%d)" % [total.attack, total.attack - b.attack],
		"DEF  %d  (+%d)" % [total.defense, total.defense - b.defense],
		"CRI  %d%%  (+%d%%)" % [roundi(total.critical * 100), roundi((total.critical - b.critical) * 100)],
		"EVA  %d%%  (+%d%%)" % [roundi(total.evasion * 100), roundi((total.evasion - b.evasion) * 100)],
		"LUK  %d  (+%d)" % [roundi(total.luck), roundi(total.luck - b.luck)],
	])
	var specials: Array[String] = []
	for it in gear:
		if it.special != ItemTypes.Special.NONE:
			specials.append("★ " + ItemTypes.special_text(it.special, it.special_value))
	if not specials.is_empty():
		_stats_label.text += "\n" + "\n".join(specials)
	if furniture_bonus != null:
		var fl := ItemStats.describe(furniture_bonus)
		if not fl.is_empty():
			_stats_label.text += "\nเฟอร์นิเจอร์ห้อง: " + ", ".join(fl)

	for slot in _slot_buttons:
		var btn: Button = _slot_buttons[slot]
		var it := collection.equipped_in(princess.id, slot)
		btn.text = "%s\n%s" % [ItemTypes.slot_name(slot), it.display_name if it else "— ว่าง —"]
		btn.icon = UIKit.icon_texture(it) if it else null
		btn.add_theme_color_override("font_color", ItemTypes.rarity_color(it.rarity) if it else Color(1, 1, 1, 0.45))
	_refresh_bag()
	_refresh_details()


func _refresh_bag() -> void:
	for c in _bag_grid.get_children():
		c.queue_free()
	var items: Array = []
	for item_id in collection.owned:
		var it := collection.get_item(item_id)
		if it != null and (_filter_slot < 0 or it.slot == _filter_slot):
			items.append(it)
	# Best first: rarity, then power.
	items.sort_custom(func(a, b): return a.rarity > b.rarity or (a.rarity == b.rarity and ItemStats.power(a) > ItemStats.power(b)))
	for it in items:
		var btn := Button.new()
		btn.name = "Item_" + it.id
		btn.custom_minimum_size = Vector2(150, 150)
		btn.focus_mode = Control.FOCUS_NONE
		btn.icon = UIKit.icon_texture(it)
		btn.expand_icon = true
		btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		btn.tooltip_text = it.display_name
		var worn: bool = collection.is_equipped(princess.id, it.id)
		var sel: bool = it.id == _selected_id
		for state in ["normal", "hover", "pressed"]:
			var sb := UIKit.panel_style(Color(0.05, 0.02, 0.08, 1), ItemTypes.rarity_color(it.rarity), 16, 7 if sel else 4)
			sb.content_margin_left = 10
			sb.content_margin_right = 10
			sb.content_margin_top = 10
			sb.content_margin_bottom = 10
			if state == "hover": sb.bg_color = Color(0.14, 0.08, 0.2)
			btn.add_theme_stylebox_override(state, sb)
		if worn:
			var tag := UIKit.label("E", 26, UIKit.GOLD)
			tag.position = Vector2(10, 4)
			tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
			btn.add_child(tag)
		btn.pressed.connect(func(): select_item(it.id))
		_bag_grid.add_child(btn)


func _refresh_details() -> void:
	var it := collection.get_item(_selected_id)
	if it == null:
		_detail_title.text = "เลือกไอเท็มในกระเป๋า"
		_detail_title.add_theme_color_override("font_color", Color.WHITE)
		_detail_body.text = "ไอเท็มทั้งหมด %d ชิ้น — ของที่สวมใส่จะแสดงบนตัวเจ้าหญิงทันที" % collection.owned.size()
		_action_button.visible = false
		return
	_detail_title.text = "%s   [%s • %s]" % [it.display_name, ItemTypes.rarity_name(it.rarity), ItemTypes.slot_name(it.slot)]
	_detail_title.add_theme_color_override("font_color", ItemTypes.rarity_color(it.rarity))
	_detail_body.text = UIKit.compare_text(it, collection.equipped_in(princess.id, it.slot)) + "\n\"%s\"" % it.description
	_action_button.visible = true
	_action_button.text = "ถอดออก" if collection.is_equipped(princess.id, it.id) else "สวมใส่"
	_refresh_bag_selection()


func _refresh_bag_selection() -> void:
	# Re-draw borders so the selected item stands out.
	_refresh_bag()


## Princess reacts to what she was just given / swapped (dialogue DB + expression).
func _react(trigger: String, item: EquipmentDefinition) -> void:
	if dialogue == null:
		return
	var line := dialogue.pick(trigger, DialogueDB.context(princess, bond_level, item))
	if line == null:
		return
	last_speech = line.text
	_speech.text = "“%s”" % line.text
	_doll.set_expression(line.expression)
