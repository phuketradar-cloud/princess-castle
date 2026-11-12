class_name CardsScreen
extends CanvasLayer
## Card hub with 3 tabs:
##   0  Collection & Deck : owned cards (x copies), deck of up to N cards, add / remove
##   1  Craft             : essence inventory + recipes (Essence -> card)
##   2  Fusion            : combine cards into stronger ones (inputs are consumed)
## Every change is applied to the Collection immediately and `collection_changed` is emitted.

signal closed
signal collection_changed

const TAB_NAMES := ["การ์ด & เด็ค", "สร้างการ์ด (Craft)", "รวมการ์ด (Fusion)"]

var collection: Collection
var library: CardLibrary
var current_tab := 0
var selected_card_id := ""
## For tests / autoplay.
var craft_buttons := {}   # result card id -> Button
var fuse_buttons := {}    # result card id -> Button
var deck_buttons: Array[Button] = []
var last_result := ""

var _root: Control
var _tab_buttons: Array[Button] = []
var _content: Control
var _toast: Label


func _init() -> void:
	layer = 30
	visible = false


func open(p_collection: Collection, p_library: CardLibrary, tab := 0) -> void:
	collection = p_collection
	library = p_library
	if _root == null:
		_build()
	selected_card_id = ""
	last_result = ""
	_toast.text = ""
	select_tab(tab)
	visible = true


func close() -> void:
	visible = false
	closed.emit()


func select_tab(tab: int) -> void:
	current_tab = tab
	for i in _tab_buttons.size():
		UIKit.style_button(_tab_buttons[i], UIKit.BUTTON if i == tab else Color(0.2, 0.12, 0.3), 14)
	_refresh()


# ------------------------------------------------------------ actions

func toggle_deck(card_id: String) -> void:
	if collection.deck.has(card_id):
		collection.remove_from_deck(card_id)
		_say("นำ %s ออกจากเด็ค" % _name(card_id))
	else:
		var err := collection.add_to_deck(card_id)
		_say(err if err != "" else "เพิ่ม %s เข้าเด็ค" % _name(card_id))
	collection_changed.emit()
	_refresh()


func craft(recipe: CraftRecipe) -> void:
	var made := collection.craft(recipe)
	if made == null:
		_say("Essence ไม่พอ")
		return
	last_result = made.id
	_say("✦ สร้างสำเร็จ! ได้รับ %s%s" % [made.display_name, " (เข้าเด็คแล้ว)" if collection.deck.has(made.id) else ""])
	collection_changed.emit()
	_refresh()


func fuse(recipe: FusionRecipe) -> void:
	var made := collection.fuse(recipe)
	if made == null:
		_say("การ์ดไม่ครบ")
		return
	last_result = made.id
	_say("✦ รวมสำเร็จ! ได้รับ %s" % made.display_name)
	collection_changed.emit()
	_refresh()


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
	outer.add_theme_constant_override("separation", 12)
	main.add_child(outer)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 14)
	outer.add_child(header)
	header.add_child(_nl("การ์ด", 44, UIKit.GOLD))
	for i in TAB_NAMES.size():
		var b := UIKit.button(TAB_NAMES[i], UIKit.BUTTON_ALT, 26, Vector2(260, 66))
		b.pressed.connect(func(): select_tab(i))
		header.add_child(b)
		_tab_buttons.append(b)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)
	var close_btn := UIKit.button("ปิด", UIKit.BUTTON_ALT, 30, Vector2(160, 66))
	close_btn.pressed.connect(close)
	header.add_child(close_btn)

	_content = Control.new()
	_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer.add_child(_content)
	_toast = UIKit.label("", 28, Color(0.55, 1, 0.7))
	outer.add_child(_toast)


func _refresh() -> void:
	for c in _content.get_children():
		c.queue_free()
	craft_buttons.clear()
	fuse_buttons.clear()
	deck_buttons.clear()
	match current_tab:
		0: _build_deck_tab()
		1: _build_craft_tab()
		2: _build_fusion_tab()


# ------------------------------------------------------------ tab 0: collection & deck

func _build_deck_tab() -> void:
	var cols := HBoxContainer.new()
	cols.set_anchors_preset(Control.PRESET_FULL_RECT)
	cols.add_theme_constant_override("separation", 20)
	_content.add_child(cols)

	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", 10)
	cols.add_child(left)
	left.add_child(UIKit.label("เด็คสำหรับต่อสู้ (%d/%d) — แตะเพื่อเลือก" % [collection.deck.size(), collection.deck_size], 26, UIKit.GOLD))
	var deck_row := HBoxContainer.new()
	deck_row.add_theme_constant_override("separation", 12)
	left.add_child(deck_row)
	for i in collection.deck_size:
		if i < collection.deck.size():
			var c := collection.get_card(collection.deck[i])
			var tile := UIKit.card_tile(c, -1, 160, c.id == selected_card_id)
			var card_id := c.id
			tile.pressed.connect(func(): _select(card_id))
			deck_row.add_child(tile)
			deck_buttons.append(tile)
		else:
			var empty := UIKit.panel(Color(0.05, 0.03, 0.08, 1), Color(1, 1, 1, 0.15), 18, 3)
			empty.custom_minimum_size = Vector2(160, 211)
			var l := UIKit.label("ว่าง", 26, Color(1, 1, 1, 0.3), HORIZONTAL_ALIGNMENT_CENTER)
			l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			empty.add_child(l)
			deck_row.add_child(empty)

	left.add_child(UIKit.label("คอลเลกชัน (การ์ดที่มีถาวร)", 26, UIKit.GOLD))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	left.add_child(scroll)
	var grid := GridContainer.new()
	grid.columns = 7
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	scroll.add_child(grid)
	var owned := []
	for card_id in collection.cards:
		var c := collection.get_card(card_id)
		if c != null:
			owned.append(c)
	owned.sort_custom(func(a, b): return a.rarity > b.rarity or (a.rarity == b.rarity and a.display_name < b.display_name))
	for c in owned:
		var tile := UIKit.card_tile(c, collection.card_count(c.id), 150, c.id == selected_card_id, collection.deck.has(c.id))
		var card_id: String = c.id
		tile.pressed.connect(func(): _select(card_id))
		grid.add_child(tile)
	if owned.is_empty():
		grid.add_child(UIKit.label("ยังไม่มีการ์ด — ชนะการต่อสู้หรือสร้างจาก Essence", 24))

	# detail panel
	var detail := UIKit.panel(Color(0.06, 0.03, 0.09, 1), UIKit.EDGE, 18, 3)
	detail.custom_minimum_size.x = 520
	cols.add_child(detail)
	var dv := VBoxContainer.new()
	dv.add_theme_constant_override("separation", 10)
	detail.add_child(dv)
	var c := collection.get_card(selected_card_id)
	if c == null:
		dv.add_child(UIKit.label("เลือกการ์ดเพื่อดูรายละเอียด", 28, Color.WHITE))
		dv.add_child(UIKit.label("• ระหว่างต่อสู้: ใช้การ์ดได้หลายใบต่อเทิร์นตามมานา (ไม่เสียเทิร์น)\n• การ์ดแต่ละใบในเด็คใช้ได้ 1 ครั้งต่อการต่อสู้\n• มานาเริ่ม 1 และเพิ่มเทิร์นละ 1 (สูงสุด 6)", 22))
		return
	var icon := UIKit.card_icon(c, 220)
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	dv.add_child(icon)
	dv.add_child(UIKit.label(c.display_name, 34, ItemTypes.rarity_color(c.rarity)))
	dv.add_child(UIKit.label("%s • %s • ◆%d มานา • มี %d ใบ" % [ItemTypes.rarity_name(c.rarity), CardTypes.category_name(c.category),
		c.mana_cost, collection.card_count(c.id)], 22))
	dv.add_child(UIKit.label(c.description, 24, Color.WHITE))
	if c.exclusive_to != "":
		dv.add_child(UIKit.label("★ การ์ดเฉพาะ %s (เจ้าหญิงคนอื่นใช้ไม่ได้)" % c.exclusive_to.replace("_", " ").capitalize(), 20, UIKit.GOLD))
	var how := _how_to_get(c)
	if how != "":
		dv.add_child(UIKit.label(how, 20, Color(1, 1, 1, 0.55)))
	var in_deck := collection.deck.has(c.id)
	var btn := UIKit.button("นำออกจากเด็ค" if in_deck else "เพิ่มเข้าเด็ค", UIKit.BUTTON_ALT if in_deck else UIKit.BUTTON, 28, Vector2(300, 74))
	btn.name = "DeckToggleButton"
	btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	btn.pressed.connect(func(): toggle_deck(c.id))
	dv.add_child(btn)


func _select(card_id: String) -> void:
	selected_card_id = card_id
	_refresh()


func _how_to_get(c: CardDefinition) -> String:
	var lines: Array[String] = []
	var r := library.craft_recipe_for(c.id) if library else null
	if r != null:
		lines.append("สร้างได้จาก: " + r.cost_text())
	if library:
		for f in library.fusion_recipes:
			if f.result == c:
				lines.append("รวมจาก: " + f.inputs_text())
	return "\n".join(lines)


# ------------------------------------------------------------ tab 1: craft

func _build_craft_tab() -> void:
	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.add_theme_constant_override("separation", 12)
	_content.add_child(v)
	v.add_child(_essence_row())
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 12)
	scroll.add_child(grid)
	if library == null:
		return
	for r in library.craft_recipes:
		grid.add_child(_craft_row(r))


func _essence_row() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 30)
	row.add_child(_nl("Essence ที่มี:", 26, UIKit.GOLD))
	for e in CardTypes.Element.values():
		var key := CardTypes.element_key(e)
		var box := HBoxContainer.new()
		var tex := TextureRect.new()
		tex.texture = CastleTypes.material_icon(key)
		tex.custom_minimum_size = Vector2(56, 56)
		tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		box.add_child(tex)
		var l := _nl("%s x%d" % [CardTypes.ELEMENT_NAMES[e], collection.essence(key)], 26, CardTypes.element_color(e))
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		box.add_child(l)
		row.add_child(box)
	return row


func _craft_row(r: CraftRecipe) -> Control:
	var c := r.result
	var row := UIKit.panel(Color(0.07, 0.04, 0.11, 1), ItemTypes.rarity_color(c.rarity), 16, 3)
	row.custom_minimum_size = Vector2(880, 150)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 16)
	row.add_child(h)
	h.add_child(UIKit.card_icon(c, 116))
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(info)
	info.add_child(UIKit.label("%s  (มี %d)" % [c.display_name, collection.card_count(c.id)], 28, ItemTypes.rarity_color(c.rarity)))
	info.add_child(UIKit.label(c.description, 19, UIKit.LAVENDER))
	var cost_parts: Array[String] = []
	for key in r.cost:
		var e := CardTypes.element_from_key(key)
		var mark := "✓" if collection.essence(key) >= int(r.cost[key]) else "✗"
		cost_parts.append("%s %s %d/%d" % [mark, CardTypes.ELEMENT_NAMES[e], collection.essence(key), int(r.cost[key])])
	var can := collection.can_craft(r)
	info.add_child(UIKit.label("  ".join(cost_parts), 22, Color(0.55, 1, 0.7) if can else Color(1, 0.6, 0.6)))
	var btn := UIKit.button("สร้าง", UIKit.BUTTON, 28, Vector2(150, 90))
	btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	btn.disabled = not can
	btn.pressed.connect(func(): craft(r))
	h.add_child(btn)
	craft_buttons[c.id] = btn
	return row


# ------------------------------------------------------------ tab 2: fusion

func _build_fusion_tab() -> void:
	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.add_theme_constant_override("separation", 14)
	_content.add_child(v)
	v.add_child(UIKit.label("รวมการ์ดหลายใบเป็นการ์ดที่แข็งแกร่งกว่า — การ์ดที่ใช้รวมจะหายไป", 26, UIKit.LAVENDER))
	if library == null:
		return
	for f in library.fusion_recipes:
		v.add_child(_fusion_row(f))


func _fusion_row(f: FusionRecipe) -> Control:
	var res := f.result
	var row := UIKit.panel(Color(0.07, 0.04, 0.11, 1), ItemTypes.rarity_color(res.rarity), 16, 3)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 18)
	row.add_child(h)
	var need := f.needed()
	for card_id in need:
		var c := _find_card(card_id, f)
		var box := VBoxContainer.new()
		box.add_child(UIKit.card_icon(c, 110))
		var have := collection.card_count(card_id)
		box.add_child(UIKit.label("%s\nมี %d/%d" % [c.display_name, have, need[card_id]], 20,
			Color(0.55, 1, 0.7) if have >= need[card_id] else Color(1, 0.6, 0.6), HORIZONTAL_ALIGNMENT_CENTER))
		h.add_child(box)
		var plus := _nl("+", 48, UIKit.LAVENDER)
		plus.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		h.add_child(plus)
	h.remove_child(h.get_child(h.get_child_count() - 1)) # drop the last "+"
	var arrow := _nl("→", 64, UIKit.GOLD)
	arrow.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	h.add_child(arrow)
	h.add_child(UIKit.card_icon(res, 140))
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_child(UIKit.label(res.display_name, 32, ItemTypes.rarity_color(res.rarity)))
	info.add_child(UIKit.label(res.description, 21, UIKit.LAVENDER))
	h.add_child(info)
	var btn := UIKit.button("รวม", UIKit.BUTTON, 30, Vector2(150, 90))
	btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	btn.disabled = not collection.can_fuse(f)
	btn.pressed.connect(func(): fuse(f))
	h.add_child(btn)
	fuse_buttons[res.id] = btn
	return row


func _find_card(card_id: String, f: FusionRecipe) -> CardDefinition:
	for c in f.inputs:
		if c != null and c.id == card_id:
			return c
	return collection.get_card(card_id)


func _name(card_id: String) -> String:
	var c := collection.get_card(card_id)
	return c.display_name if c else card_id


func _say(text: String) -> void:
	_toast.text = text


## Label that never wraps (for labels inside HBoxContainers, which would otherwise
## squeeze them to one character per line).
func _nl(text: String, size: int, color: Color) -> Label:
	var l := UIKit.label(text, size, color)
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	return l
