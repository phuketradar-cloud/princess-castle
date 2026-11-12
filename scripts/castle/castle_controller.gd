class_name CastleController
extends Node2D
## Castle hub (main scene). Two views:
##   OVERVIEW : 5 wings (one per princess) — locked/unlocked, bond, current activity,
##              choose who goes on the next adventure.
##   ROOM     : the princess's room with her furniture; she lives there (LivingPrincess).
##              Talk, Gift, Decorate (place + craft furniture), Status/Equipment, Cards,
##              Adventure with her, Bond Lv3 story event.
## UI is built in code with UIKit (same look as the other screens).

const BATTLE_SCENE := "res://scenes/battle.tscn"
const ROOM_SCALE := 1.5
## Furniture slot -> floor position (bottom centre) in the 1920x1080 room.
const SLOT_POS := {
	CastleTypes.FurnitureSlot.BED: Vector2(420, 930),
	CastleTypes.FurnitureSlot.DESK: Vector2(1010, 860),
	CastleTypes.FurnitureSlot.TRAINING: Vector2(1580, 900),
	CastleTypes.FurnitureSlot.DECOR: Vector2(1290, 700),
}
const WINDOW_SPOT := Vector2(640, 800)

var game_state: Node
var roster: PrincessRoster
var castle: CastleProgress
var collection: Collection
var current: PrincessDefinition        ## princess whose room is open (null = overview)
var princess_node: LivingPrincess
var room_layout: RoomLayout           ## layout of the open room (null = defaults)
var last_speech := ""                   ## for tests
var story_lines: Array[DialogueLine] = []

var _world: Node2D
var _bg: Sprite2D
var _furniture_root: Node2D
var _popups: Node2D
var _ui: CanvasLayer
var _overview: Control
var _room_ui: Control
var _panel: Control                     ## current popup panel (gift / decorate)
var _story_panel: Control
var _bond_label: Label
var _activity_label: Label
var _toast: Label
var _bubble: SpeechBubble
var _rng := RandomSource.new()
var equipment_screen: EquipmentScreen
var cards_screen: CardsScreen
var settings_screen: SettingsScreen
var _quit_armed_until := 0 ## Android: press Back twice on the overview to quit
## For tests / autoplay
var wing_buttons := {}                  ## princess id -> Button
var room_buttons := {}                  ## action name -> Button


func _ready() -> void:
	game_state = get_node_or_null("/root/GameState")
	if game_state == null:
		game_state = load("res://scripts/core/game_state.gd").new()
		game_state.persist = false
		add_child(game_state)
	game_state.setup()
	roster = game_state.roster
	castle = game_state.castle
	collection = game_state.collection
	if roster == null:
		push_error("Castle: res://data/princess_roster.tres is missing")
		return
	for p in castle.unlocked(roster):
		castle.ensure_room(p, roster)

	var cam := Camera2D.new()
	cam.position = Vector2(960, 540)
	add_child(cam)
	_world = Node2D.new()
	add_child(_world)
	_bg = Sprite2D.new()
	_bg.position = Vector2(960, 540)
	_bg.z_index = -100
	_world.add_child(_bg)
	_furniture_root = Node2D.new()
	_world.add_child(_furniture_root)
	_popups = Node2D.new()
	_popups.z_index = 200
	_world.add_child(_popups)
	_ui = CanvasLayer.new()
	add_child(_ui)
	equipment_screen = EquipmentScreen.new()
	add_child(equipment_screen)
	equipment_screen.equipment_changed.connect(_on_equipment_changed)
	cards_screen = CardsScreen.new()
	add_child(cards_screen)
	cards_screen.collection_changed.connect(func(): game_state.save_game())
	settings_screen = SettingsScreen.new()
	add_child(settings_screen)
	settings_screen.new_game_started.connect(func(): get_tree().reload_current_scene())
	for layer in [_ui, equipment_screen, cards_screen, settings_screen]:
		SafeArea.apply_to_layer(layer)
	_audio("music", "castle")
	show_overview()


# ============================================================ OVERVIEW

func show_overview() -> void:
	current = null
	room_layout = null
	_clear_room()
	const HD_HALL := "res://assets/art/rooms_hd/castle_overview.png" # AI castle hall at night
	if ResourceLoader.exists(HD_HALL):
		_bg.texture = load(HD_HALL)
		var size := _bg.texture.get_size()
		var cover := maxf(1920.0 / size.x, 1080.0 / size.y)
		_bg.scale = Vector2(cover, cover)
	else:
		_bg.texture = load("res://assets/art/rooms/castle_overview.png")
		_bg.scale = Vector2(5.4, 5.4)
	_build_overview()


func _build_overview() -> void:
	for c in _ui.get_children():
		c.queue_free()
	wing_buttons.clear()
	_overview = Control.new()
	_overview.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(_overview)
	var shade_g := Gradient.new()
	shade_g.set_color(0, Color(0.12, 0.05, 0.22, 0.2))
	shade_g.set_color(1, Color(0.03, 0.01, 0.08, 0.45))
	var shade_t := GradientTexture2D.new()
	shade_t.gradient = shade_g
	shade_t.fill_to = Vector2(0, 1)
	shade_t.width = 8
	shade_t.height = 256
	var shade := TextureRect.new()
	shade.texture = shade_t
	shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overview.add_child(shade)

	var top := UIKit.panel(Color(0.08, 0.03, 0.12, 0.85), UIKit.EDGE, 0, 0)
	top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top.custom_minimum_size.y = 90
	_overview.add_child(top)
	var th := HBoxContainer.new()
	th.add_theme_constant_override("separation", 24)
	top.add_child(th)
	th.add_child(_nl("ปราสาทเจ้าหญิง", 44, UIKit.GOLD))
	th.add_child(_nl("ผ่านด่านแล้ว %d/%d" % [castle.cleared_stages.size(), roster.stages.size()], 26, UIKit.LAVENDER))
	th.add_child(_nl(_team_text().get_slice("\n", 0), 22, Color(0.6, 0.9, 1)))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	th.add_child(spacer)
	th.add_child(_materials_row(20)) # compact: all 9 materials must fit
	var gear := UIKit.button("ตั้งค่า", UIKit.BUTTON_ALT, 24, Vector2(130, 72))
	gear.name = "SettingsButton"
	gear.pressed.connect(open_settings)
	th.add_child(gear)
	th.move_child(gear, 0) # left side: the materials row can be long
	room_buttons["settings"] = gear

	var row := HBoxContainer.new()
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.offset_top = 110
	row.offset_bottom = -118
	row.offset_left = 30
	row.offset_right = -30
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 22)
	_overview.add_child(row)
	for p in roster.princesses:
		row.add_child(_wing_card(p))

	var bottom := HBoxContainer.new()
	bottom.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.offset_top = -100
	bottom.offset_bottom = -14
	bottom.offset_left = 40
	bottom.offset_right = -40
	bottom.alignment = BoxContainer.ALIGNMENT_CENTER
	bottom.add_theme_constant_override("separation", 24)
	_overview.add_child(bottom)
	var active: PrincessDefinition = game_state.active_princess()
	var go := UIKit.button("▶  ออกผจญภัยกับ %s" % (active.display_name if active else "-"), UIKit.BUTTON, 30, Vector2(540, 82))
	_glow_button(go, UIKit.GOLD, 12)
	go.name = "AdventureButton"
	go.pressed.connect(func(): open_stage_select(active))
	bottom.add_child(go)
	room_buttons["adventure_overview"] = go
	if OS.is_debug_build():
		var dev := UIKit.button("[ทดสอบ] ปลดล็อกทั้งหมด", Color(0.25, 0.25, 0.3), 20, Vector2(280, 64))
		dev.pressed.connect(func():
			castle.unlock_all = not castle.unlock_all
			for p in castle.unlocked(roster):
				castle.ensure_room(p, roster)
			_build_overview())
		bottom.add_child(dev)
	_toast = _nl("", 26, Color(0.55, 1, 0.7))
	_toast.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_toast.offset_top = -150
	_overview.add_child(_toast)


## Room art per wing (the card's backdrop); missing art = plain tinted card.
const WING_ROOMS := ["sword_wing", "magic_wing", "shadow_wing", "light_wing", "dragon_wing"]
## Card glow per wing: rose, frost, violet, gold, ember.
const WING_GLOW := [Color(1, 0.4, 0.55), Color(0.4, 0.8, 1), Color(0.68, 0.45, 1), Color(1, 0.84, 0.4), Color(1, 0.5, 0.25)]


## Character card: glowing border in her colour, her room behind a big doll, EXP bar,
## Bond with a heart, compact buttons.
func _wing_card(p: PrincessDefinition) -> Control:
	var unlocked := castle.is_unlocked(p)
	var glow: Color = (WING_GLOW[p.wing] if p.wing < WING_GLOW.size() else p.theme_color) if unlocked else Color(1, 1, 1, 0.25)
	var card := PanelContainer.new()
	var card_bg := Color(0.06, 0.03, 0.1).lerp(glow, 0.1) if unlocked else Color(0.06, 0.03, 0.1)
	var sb := UIKit.panel_style(Color(card_bg, 0.92), glow, 20, 3)
	sb.shadow_color = Color(glow, 0.55 if unlocked else 0.15)
	sb.shadow_size = 16
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 10
	sb.content_margin_bottom = 14
	card.add_theme_stylebox_override("panel", sb)
	card.custom_minimum_size = Vector2(330, 0)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	card.add_child(v)
	v.add_child(_card_art(p, unlocked, glow, card_bg))
	v.add_child(_label_c(p.display_name if unlocked else "???", 30, Color.WHITE))
	if unlocked:
		var title := _label_c(p.title, 18, UIKit.LAVENDER)
		title.custom_minimum_size.y = 46 # two lines, so every card's rows line up
		title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		v.add_child(title)
		var lv := castle.level(p.id)
		var maxed := lv >= CastleTypes.MAX_LEVEL
		var need := CastleTypes.exp_to_next(lv) if not maxed else 1
		v.add_child(_bar(castle.exp_points(p.id) if not maxed else 1, need, glow, _level_text(p)))
		var pts := castle.bond_points(p.id)
		v.add_child(_label_c("Bond Lv %d ♥ (%d/%d)" % [castle.bond_level(p.id), pts, CastleTypes.bond_next(pts)], 22, Color(1, 0.6, 0.8)))
		var act: String = CastleTypes.ACTIVITY_NAMES[_rng_activity(p)]
		v.add_child(_label_c("ตอนนี้: %s" % act, 18, Color(1, 1, 1, 0.6)))
		var enter := UIKit.button("เข้าห้อง", UIKit.BUTTON_ALT, 26, Vector2(290, 60))
		_glow_button(enter, Color(0.75, 0.55, 1))
		enter.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		enter.pressed.connect(func(): enter_room(p))
		v.add_child(enter)
		wing_buttons[p.id] = enter
		var is_active: bool = game_state.active_princess() == p
		var is_comp: bool = game_state.companion_princess() == p
		var pick := UIKit.button("✓ ตัวที่ออกผจญภัย" if is_active else "เลือกออกผจญภัย", Color(0.2, 0.35, 0.25), 20, Vector2(270, 46))
		pick.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		pick.disabled = is_active
		pick.pressed.connect(func():
			if is_comp:
				castle.set_companion("")
			game_state.set_active_princess(p)
			_build_overview())
		v.add_child(pick)
		var comp := UIKit.button("✓ ผู้ช่วย (กดเพื่อถอด)" if is_comp else "เลือกเป็นผู้ช่วย", Color(0.2, 0.3, 0.45), 20, Vector2(270, 46))
		comp.name = "Companion_" + p.id
		comp.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		comp.disabled = is_active
		comp.pressed.connect(func(): toggle_companion(p))
		v.add_child(comp)
		room_buttons["companion_" + p.id] = comp
	else:
		v.add_child(_label_c("✗ ล็อกอยู่", 26, Color(1, 1, 1, 0.5)))
		v.add_child(_label_c(_unlock_text(p), 20, Color(1, 1, 1, 0.5)))
	return card


## Top of the card: her room (darkened, fading into the card), wing name, big doll.
func _card_art(p: PrincessDefinition, unlocked: bool, glow: Color, card_bg: Color) -> Control:
	var art := Control.new()
	art.custom_minimum_size = Vector2(310, 420)
	art.clip_contents = true
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var room_path := ""
	if p.wing < WING_ROOMS.size():
		room_path = "res://assets/art/rooms_hd/%s.png" % WING_ROOMS[p.wing]
	if room_path != "" and ResourceLoader.exists(room_path):
		var bg := TextureRect.new()
		bg.texture = load(room_path)
		bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		bg.set_anchors_preset(Control.PRESET_FULL_RECT)
		bg.modulate = Color(0.8, 0.8, 0.85) if unlocked else Color(0.15, 0.12, 0.18)
		bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		art.add_child(bg)
	else:
		var tint := ColorRect.new()
		tint.color = Color(glow, 0.15)
		tint.set_anchors_preset(Control.PRESET_FULL_RECT)
		tint.mouse_filter = Control.MOUSE_FILTER_IGNORE
		art.add_child(tint)
	# fade the bottom into the card so the name sits on a calm background
	var g := Gradient.new()
	g.set_color(0, Color(card_bg, 0.0))
	g.set_color(1, Color(card_bg, 1.0))
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill_from = Vector2(0, 0)
	gt.fill_to = Vector2(0, 1)
	gt.width = 8
	gt.height = 128
	var fade := TextureRect.new()
	fade.texture = gt
	fade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	fade.anchor_left = 0.0
	fade.anchor_right = 1.0
	fade.anchor_top = 0.55
	fade.anchor_bottom = 1.0
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art.add_child(fade)
	# big doll
	var box := SubViewportContainer.new()
	box.stretch = true
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art.add_child(box)
	var vp := SubViewport.new()
	vp.transparent_bg = true
	vp.size = Vector2i(310, 420)
	box.add_child(vp)
	var doll := PaperDoll.new()
	doll.position = Vector2(155, 405)
	doll.scale = Vector2(1.45, 1.45)
	vp.add_child(doll)
	doll.setup(p.battle_texture, Color.WHITE if unlocked else Color(0.05, 0.03, 0.08), false, p.slot_anchors, p.art_scale)
	if unlocked:
		doll.setup_face(p.face_dir, p.face_anchor)
		doll.set_equipment(collection.equipped_items(p.id))
		doll.set_expression(CastleTypes.Expr.HAPPY if game_state.active_princess() == p else CastleTypes.Expr.NORMAL)
	var wing := _label_c(CastleTypes.WING_NAMES[p.wing], 26, UIKit.GOLD)
	wing.set_anchors_preset(Control.PRESET_TOP_WIDE)
	wing.offset_top = 6
	wing.add_theme_color_override("font_outline_color", Color(0.1, 0.03, 0.12))
	wing.add_theme_constant_override("outline_size", 8)
	art.add_child(wing)
	return art


## Slim rounded progress bar with its text on top.
func _bar(value: int, max_value: int, color: Color, text: String) -> Control:
	var bar := ProgressBar.new()
	bar.min_value = 0
	bar.max_value = maxi(max_value, 1)
	bar.value = clampi(value, 0, maxi(max_value, 1))
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(270, 28)
	bar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.02, 0.01, 0.05, 0.85)
	bg.set_corner_radius_all(14)
	bg.set_border_width_all(2)
	bg.border_color = Color(color, 0.6)
	var fill := StyleBoxFlat.new()
	fill.bg_color = color.darkened(0.15)
	fill.set_corner_radius_all(14)
	bar.add_theme_stylebox_override("background", bg)
	bar.add_theme_stylebox_override("fill", fill)
	var l := UIKit.label(text, 17, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	l.set_anchors_preset(Control.PRESET_FULL_RECT)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_color_override("font_outline_color", Color(0.05, 0.02, 0.1))
	l.add_theme_constant_override("outline_size", 6)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(l)
	return bar


## Soft outer glow on a button's normal / hover look.
func _glow_button(b: Button, color: Color, size := 8) -> void:
	for state in ["normal", "hover"]:
		var sb := b.get_theme_stylebox(state) as StyleBoxFlat
		if sb == null:
			continue
		sb = sb.duplicate()
		sb.shadow_color = Color(color, 0.5)
		sb.shadow_size = size
		sb.border_color = Color(color.lightened(0.3), 0.8)
		b.add_theme_stylebox_override(state, sb)


func _level_text(p: PrincessDefinition) -> String:
	var lv := castle.level(p.id)
	if lv >= CastleTypes.MAX_LEVEL:
		return "Lv %d (MAX)" % lv
	return "Lv %d  EXP %d/%d" % [lv, castle.exp_points(p.id), CastleTypes.exp_to_next(lv)]


func _unlock_text(p: PrincessDefinition) -> String:
	if p.unlock_stage != "":
		var s := roster.find_stage(p.unlock_stage)
		return "ปลดล็อกเมื่อผ่านด่าน\n%s" % (s.display_name if s else p.unlock_stage)
	return "ปลดล็อกเมื่อผ่านด่านครบ %d ครั้ง\n(ตอนนี้ %d)" % [p.unlock_clears, castle.stage_clears]


## Companion = the second princess who assists from the back row (one at a time).
func toggle_companion(p: PrincessDefinition) -> void:
	if game_state.companion_princess() == p:
		castle.set_companion("")
	else:
		castle.set_companion(p.id)
		collection.ensure_starting_gear(p)
	game_state.save_game()
	_build_overview()


func _team_text() -> String:
	var a: PrincessDefinition = game_state.active_princess()
	var c: PrincessDefinition = game_state.companion_princess()
	if a == null:
		return ""
	if c == null:
		return "ทีม: %s Lv%d  (ยังไม่มีผู้ช่วย)" % [a.display_name, castle.level(a.id)]
	var text := "ทีม: %s Lv%d + ผู้ช่วย %s Lv%d (%s)" % [a.display_name, castle.level(a.id), c.display_name,
		castle.level(c.id), c.assist.display_name if c.assist else "-"]
	var syn := roster.synergy_for(a.id, c.id)
	if syn != null:
		text += "\n★ Synergy %s: %s" % [syn.display_name, syn.description]
	return text


# ============================================================ STAGE SELECT

## Stage list: locked / cleared, recommended level, boss. Start = go to battle.
func open_stage_select(p: PrincessDefinition = null) -> void:
	_close_panel()
	if p != null and p != game_state.active_princess():
		game_state.set_active_princess(p)
	var panel := _popup_panel("เลือกด่าน")
	var v: VBoxContainer = panel.get_child(0)
	v.add_child(UIKit.label(_team_text(), 24, Color(0.6, 0.9, 1)))
	var a: PrincessDefinition = game_state.active_princess()
	var lv := castle.level(a.id) if a else 1
	for s in roster.stages:
		var open := castle.is_stage_unlocked(s)
		var cleared := castle.is_stage_cleared(s.id)
		var row := UIKit.panel(Color(0.07, 0.04, 0.11, 1), UIKit.GOLD if cleared else (Color(0.6, 0.5, 0.9) if open else Color(1, 1, 1, 0.15)), 14, 3)
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 18)
		row.add_child(h)
		var info := VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(info)
		var title := "%s%s" % [s.display_name, "  ✓ ผ่านแล้ว" if cleared else ""]
		info.add_child(UIKit.label(title if open else "✗ " + s.display_name, 30, UIKit.GOLD if open else Color(1, 1, 1, 0.45)))
		var boss := s.boss_name()
		var detail := "แนะนำ Lv%d%s  •  %d การต่อสู้%s" % [s.recommended_level, " (คุณ Lv%d)" % lv if lv < s.recommended_level else "",
			s.encounters.size(), "  •  บอส: " + boss if boss != "" else ""]
		info.add_child(UIKit.label(detail, 22, Color(1, 0.55, 0.55) if lv < s.recommended_level else UIKit.LAVENDER))
		if open:
			info.add_child(UIKit.label(s.description, 20, Color(1, 1, 1, 0.7)))
		else:
			var need := roster.find_stage(s.unlock_after)
			info.add_child(UIKit.label("ผ่าน %s ก่อน" % (need.display_name if need else s.unlock_after), 20, Color(1, 1, 1, 0.45)))
		var go := UIKit.button("เริ่ม" if open else "ล็อก", UIKit.BUTTON if open else Color(0.2, 0.2, 0.25), 28, Vector2(180, 80))
		go.disabled = not open
		go.pressed.connect(func(): start_stage(s))
		room_buttons["stage_" + s.id] = go
		h.add_child(go)
		v.add_child(row)


func start_stage(s: StageDefinition) -> void:
	if s == null or not castle.is_stage_unlocked(s):
		return
	castle.selected_stage = s.id
	start_adventure(game_state.active_princess())


func _rng_activity(p: PrincessDefinition) -> int:
	# What she is "doing" while you look at the overview (weighted like in her room).
	var w := p.activity_weights
	var total := 0.0
	for x in w:
		total += x
	var r := randf() * total
	for i in w.size():
		r -= w[i]
		if r <= 0.0:
			return i
	return 0


func start_adventure(p: PrincessDefinition) -> void:
	if p == null:
		return
	game_state.set_active_princess(p)
	game_state.save_game()
	get_tree().change_scene_to_file(BATTLE_SCENE)


# ============================================================ ROOM

func enter_room(p: PrincessDefinition) -> void:
	if not castle.is_unlocked(p):
		return
	current = p
	castle.ensure_room(p, roster)
	collection.ensure_starting_gear(p)
	room_layout = roster.layout_for(p.wing)
	if room_layout != null and room_layout.background != null:
		_bg.texture = room_layout.background
		var size := room_layout.background.get_size()
		var cover := maxf(1920.0 / size.x, 1080.0 / size.y) # fill the screen, keep aspect
		_bg.scale = Vector2(cover, cover)
	else:
		_bg.texture = load("res://assets/art/rooms/%s.png" % ["sword_wing", "magic_wing", "shadow_wing", "light_wing", "dragon_wing"][p.wing])
		_bg.scale = Vector2(4.0, 4.0) * 1.35
	_build_room_world()
	_build_room_ui()
	_say_trigger("GREETING")
	_check_story_and_rewards()


func _clear_room() -> void:
	for c in _furniture_root.get_children():
		c.queue_free()
	if princess_node != null:
		princess_node.queue_free()
		princess_node = null


func _build_room_world() -> void:
	_clear_room()
	for slot in SLOT_POS:
		var f := castle.in_slot(current.id, slot, roster)
		if f == null or f.texture == null:
			continue
		var s := Sprite2D.new()
		s.texture = f.texture
		s.centered = false
		s.offset = Vector2(-f.texture.get_width() * 0.5, -f.texture.get_height())
		s.position = _slot_pos(slot)
		var k := f.room_scale * _slot_depth(slot)
		s.scale = Vector2(k, k)
		s.z_index = int(s.position.y / 10.0)
		s.name = "Furniture_%s" % f.id
		_furniture_root.add_child(s)
	princess_node = LivingPrincess.new()
	princess_node.setup(current, collection.equipped_items(current.id), ROOM_SCALE)
	princess_node.position = room_layout.stand_spot if room_layout else Vector2(960, 980)
	princess_node.z_index = 100
	princess_node.spots = _spots()
	_world.add_child(princess_node)
	princess_node.activity_changed.connect(_on_activity)
	princess_node.tapped.connect(talk)
	if _activity_label:
		_activity_label.text = ""


func _slot_pos(slot: int) -> Vector2:
	if room_layout != null and room_layout.slot_positions.has(slot):
		return room_layout.slot_positions[slot]
	return SLOT_POS[slot]


func _slot_depth(slot: int) -> float:
	return float(room_layout.slot_depth_scale.get(slot, 1.0)) if room_layout != null else 1.0


## Event spots for every activity based on where the furniture is.
func _spots() -> Dictionary:
	var A := CastleTypes.Activity
	var bed := _slot_pos(CastleTypes.FurnitureSlot.BED)
	var desk := _slot_pos(CastleTypes.FurnitureSlot.DESK)
	var train := _slot_pos(CastleTypes.FurnitureSlot.TRAINING)
	var decor := _slot_pos(CastleTypes.FurnitureSlot.DECOR)
	var off := room_layout.spot_offsets if room_layout else {}
	return {
		A.STANDING: {"pos": room_layout.stand_spot if room_layout else Vector2(960, 990)},
		A.SITTING: {"pos": decor + off.get(A.SITTING, Vector2(0, 8))},
		A.SLEEPING: {"pos": bed + off.get(A.SLEEPING, Vector2(120, -95))},
		A.READING: {"pos": desk + off.get(A.READING, Vector2(-170, 60)), "face_left": false},
		A.TRAINING: {"pos": train + off.get(A.TRAINING, Vector2(-190, 40)), "face_left": false},
		A.LOOKING_OUTSIDE: {"pos": room_layout.window_spot if room_layout else WINDOW_SPOT, "face_left": true},
		A.DRINKING_TEA: {"pos": desk + off.get(A.DRINKING_TEA, Vector2(160, 70)), "face_left": true},
	}


func _on_activity(activity: int) -> void:
	if _activity_label:
		_activity_label.text = "กำลัง%s" % CastleTypes.ACTIVITY_NAMES[activity]
	if randf() < 0.5:
		_say_trigger("ACTIVITY_" + CastleTypes.ACTIVITY_KEYS[activity])


func _build_room_ui() -> void:
	for c in _ui.get_children():
		c.queue_free()
	room_buttons.clear()
	_room_ui = Control.new()
	_room_ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	_room_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(_room_ui)

	var top := UIKit.panel(Color(0.08, 0.03, 0.12, 0.85), UIKit.EDGE, 0, 0)
	top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_room_ui.add_child(top)
	var th := HBoxContainer.new()
	th.add_theme_constant_override("separation", 22)
	top.add_child(th)
	var back := UIKit.button("← ปราสาท", UIKit.BUTTON_ALT, 26, Vector2(180, 64))
	back.pressed.connect(show_overview)
	th.add_child(back)
	room_buttons["back"] = back
	th.add_child(_nl("%s  •  %s" % [current.display_name, CastleTypes.WING_NAMES[current.wing]], 34, UIKit.GOLD))
	th.add_child(_nl("นิสัย: %s" % CastleTypes.PERSONALITY_NAMES[current.personality], 22, UIKit.LAVENDER))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	th.add_child(spacer)
	_bond_label = _nl("", 26, Color(1, 0.6, 0.8))
	th.add_child(_bond_label)

	_activity_label = _nl("", 24, Color(1, 1, 1, 0.75))
	_activity_label.position = Vector2(30, 110)
	_room_ui.add_child(_activity_label)

	var side := VBoxContainer.new()
	side.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	side.offset_left = -300
	side.offset_right = -24
	side.offset_top = 120
	side.offset_bottom = -30
	side.add_theme_constant_override("separation", 12)
	_room_ui.add_child(side)
	for entry in [["talk", "♥ พูดคุย", UIKit.BUTTON, talk], ["gift", "✦ ให้ของขวัญ", Color8(170, 90, 40), open_gift],
			["decorate", "◆ ตกแต่งห้อง", Color8(60, 110, 90), open_decorate],
			["status", "สถานะ & อุปกรณ์", UIKit.BUTTON_ALT, open_status], ["cards", "การ์ด", Color8(40, 100, 150), open_cards],
			["adventure", "▶ ออกผจญภัยกับเธอ", Color8(150, 40, 60), func(): open_stage_select(current)]]:
		var b := UIKit.button(entry[1], entry[2], 26, Vector2(276, 84))
		b.pressed.connect(entry[3])
		side.add_child(b)
		room_buttons[entry[0]] = b
	_toast = _nl("", 26, Color(0.55, 1, 0.7))
	_toast.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_toast.offset_top = -70
	_toast.offset_left = -400
	_room_ui.add_child(_toast)
	_refresh_bond()


func _refresh_bond() -> void:
	if _bond_label == null or current == null:
		return
	var pts := castle.bond_points(current.id)
	var nxt := CastleTypes.bond_next(pts)
	_bond_label.text = "♥ Bond Lv %d  (%d/%s)  •  คุยได้อีก %d ครั้งวันนี้" % [castle.bond_level(current.id), pts,
		str(nxt) if nxt > 0 else "MAX", castle.talks_left(current.id, game_state.today())]


# ------------------------------------------------------------ actions

func talk() -> void:
	if current == null:
		return
	var gained := castle.talk(current.id, game_state.today())
	if gained > 0:
		_say_trigger("TALK")
		if castle.bond_level(current.id) >= 2:
			princess_node.happy_jump()
		else:
			princess_node.head_tilt()
		_show_toast("Bond +%d" % gained)
	else:
		_say_trigger("TALK_LIMIT")
	_after_bond_change()


func open_gift() -> void:
	_close_panel()
	var panel := _popup_panel("ให้ของขวัญ %s (ชอบ: %s)" % [current.display_name, CastleTypes.material_name(current.liked_material)])
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	panel.get_child(0).add_child(grid)
	var any := false
	for key in CastleTypes.MATERIALS:
		var n := collection.essence(key)
		if n <= 0:
			continue
		any = true
		var liked: bool = key == current.liked_material
		var b := UIKit.button("%s x%d%s" % [CastleTypes.material_name(key), n, "  ♥" if liked else ""],
			Color8(150, 60, 110) if liked else Color(0.2, 0.12, 0.3), 22, Vector2(330, 80))
		b.icon = CastleTypes.material_icon(key)
		b.expand_icon = true
		b.add_theme_constant_override("icon_max_width", 56)
		b.pressed.connect(func(): give_gift(key))
		b.name = "Gift_" + key
		grid.add_child(b)
	if not any:
		panel.get_child(0).add_child(UIKit.label("ยังไม่มีวัตถุดิบ — ชนะการต่อสู้เพื่อรับ Essence", 24))


func give_gift(key: String) -> void:
	var gained := castle.gift(current, key, collection)
	if gained < 0:
		return
	_audio("sfx", "coin")
	_say_trigger("GIFT_LIKED" if key == current.liked_material else "GIFT")
	princess_node.happy_jump()
	_show_toast("Bond +%d" % gained)
	_after_bond_change()
	open_gift()


func open_decorate() -> void:
	_close_panel()
	var panel := _popup_panel("ตกแต่งห้อง %s — โบนัสใช้กับเจ้าของห้องเท่านั้น" % current.display_name)
	var v: VBoxContainer = panel.get_child(0)
	var bonus := ItemStats.describe(castle.furniture_bonus(current.id, roster))
	v.add_child(UIKit.label("โบนัสห้องตอนนี้ (มีเพดาน + ลดหลั่น): %s" % (", ".join(bonus) if not bonus.is_empty() else "ไม่มี"), 22, Color(0.55, 1, 0.7)))
	v.add_child(_materials_row(20))
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(1300, 640)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 10)
	scroll.add_child(list)
	var all: Array[FurnitureDefinition] = []
	for f in roster.starter_furniture:
		all.append(f)
	for f in roster.furniture:
		if not all.has(f):
			all.append(f)
	for slot in CastleTypes.FurnitureSlot.values():
		var placed := castle.in_slot(current.id, slot, roster)
		list.add_child(UIKit.label("— %s: %s —" % [CastleTypes.SLOT_NAMES[slot], placed.display_name if placed else "ว่าง"], 26, UIKit.GOLD))
		for f in all:
			if f.slot == slot:
				list.add_child(_furniture_row(f, placed == f))


func _furniture_row(f: FurnitureDefinition, is_placed: bool) -> Control:
	var row := UIKit.panel(Color(0.07, 0.04, 0.11, 1), ItemTypes.rarity_color(f.rarity), 14, 3)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 14)
	row.add_child(h)
	var icon := TextureRect.new()
	icon.texture = f.texture
	icon.custom_minimum_size = Vector2(110, 90)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	h.add_child(icon)
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(info)
	var owned: int = castle.furniture.get(f.id, 0)
	info.add_child(UIKit.label("%s  [%s]  มี %d (ว่าง %d)%s" % [f.display_name, ItemTypes.rarity_name(f.rarity), owned, castle.available(f.id),
		"  • สกิน" if f.is_skin else ""], 24, ItemTypes.rarity_color(f.rarity)))
	var stat := ItemStats.describe(f.bonus())
	var wing_note: String = "" if f.room_type == CastleTypes.Wing.ANY else "  • เฉพาะ " + CastleTypes.WING_NAMES[f.room_type]
	info.add_child(UIKit.label("%s%s  %s" % [", ".join(stat) if not stat.is_empty() else "ไม่มีค่าสถานะ", wing_note, f.description], 19, UIKit.LAVENDER))
	if not f.recipe.is_empty():
		var can := castle.can_craft(f, collection)
		info.add_child(UIKit.label("สูตร: " + f.recipe_text(), 19, Color(0.55, 1, 0.7) if can else Color(1, 0.6, 0.6)))
		var craft := UIKit.button("สร้าง", Color8(60, 110, 90), 22, Vector2(120, 70))
		craft.disabled = not can
		craft.name = "Craft_" + f.id
		craft.pressed.connect(func():
			if castle.craft(f, collection):
				_show_toast("สร้าง %s สำเร็จ!" % f.display_name)
				_audio("sfx", "reward")
				game_state.save_game()
			open_decorate())
		h.add_child(craft)
		room_buttons["craft_" + f.id] = craft
	var place := UIKit.button("วางแล้ว" if is_placed else "วาง", UIKit.BUTTON, 22, Vector2(120, 70))
	place.disabled = is_placed or castle.available(f.id) <= 0 or not f.fits(current.wing)
	place.name = "Place_" + f.id
	place.pressed.connect(func(): place_furniture(f))
	h.add_child(place)
	room_buttons["place_" + f.id] = place
	return row


func place_furniture(f: FurnitureDefinition) -> void:
	var before := castle.bond_points(current.id)
	var err := castle.place(current, f)
	if err != "":
		_show_toast(err)
		return
	_audio("sfx", "coin")
	_build_room_world()
	_say_trigger("DECORATE")
	if castle.bond_points(current.id) > before:
		_show_toast("วาง %s แล้ว • Bond +%d" % [f.display_name, castle.bond_points(current.id) - before])
	_after_bond_change()
	open_decorate()


func open_status() -> void:
	_close_panel()
	equipment_screen.open(current, collection, roster.dialogue, castle.bond_level(current.id), castle.furniture_bonus(current.id, roster), castle.level(current.id))


func open_cards() -> void:
	_close_panel()
	cards_screen.open(collection, game_state.loot.card_library if game_state.loot else null)


func _on_equipment_changed() -> void:
	game_state.save_game()
	if princess_node != null and current != null:
		princess_node.doll.set_equipment(collection.equipped_items(current.id))


# ------------------------------------------------------------ bond, story, rewards

func _after_bond_change() -> void:
	game_state.save_game()
	_refresh_bond()
	_check_story_and_rewards()


func _check_story_and_rewards() -> void:
	if current == null:
		return
	for msg in castle.claim_bond_rewards(current, collection):
		_show_toast("♥ " + msg)
		_say_trigger("BOND_UP")
	var flag := "%s:story3" % current.id
	if castle.bond_level(current.id) >= 3 and not castle.has_flag(flag) and roster.dialogue != null:
		var seq := roster.dialogue.sequence("STORY_BOND3", current.id)
		if not seq.is_empty():
			castle.set_flag(flag)
			game_state.save_game()
			show_story(seq)


## Special event (Bond Lv3): a short scene, one line at a time.
func show_story(seq: Array[DialogueLine]) -> void:
	story_lines = seq.duplicate()
	if princess_node:
		princess_node.auto_live = false
	_story_panel = Control.new()
	_story_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ui.add_child(_story_panel)
	_story_panel.add_child(UIKit.dimmer(0.55))
	var box := UIKit.panel()
	box.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	box.offset_left = -700
	box.offset_right = 700
	box.offset_top = -330
	box.offset_bottom = -40
	_story_panel.add_child(box)
	var v := VBoxContainer.new()
	box.add_child(v)
	v.add_child(UIKit.label("★ Special Event: %s" % current.display_name, 30, UIKit.GOLD))
	var text := UIKit.label("", 34, Color.WHITE)
	text.name = "StoryText"
	text.custom_minimum_size = Vector2(1300, 120)
	v.add_child(text)
	var next := UIKit.button("ต่อไป ▶", UIKit.BUTTON, 28, Vector2(220, 72))
	next.size_flags_horizontal = Control.SIZE_SHRINK_END
	next.name = "StoryNext"
	v.add_child(next)
	room_buttons["story_next"] = next
	next.pressed.connect(_story_step.bind(text))
	_story_step(text)


func _story_step(text: Label) -> void:
	if story_lines.is_empty():
		_story_panel.queue_free()
		_story_panel = null
		if princess_node:
			princess_node.auto_live = true
		return
	var line: DialogueLine = story_lines.pop_front()
	text.text = "“%s”" % line.text
	last_speech = line.text
	if princess_node:
		princess_node.doll.set_expression(line.expression)


func _say_trigger(trigger: String) -> void:
	if current == null or roster.dialogue == null or princess_node == null:
		return
	var line := roster.dialogue.pick(trigger, DialogueDB.context(current, castle.bond_level(current.id)), _rng)
	if line == null:
		return
	last_speech = line.text
	if princess_node.activity != CastleTypes.Activity.SLEEPING or trigger.begins_with("ACTIVITY"):
		princess_node.doll.set_expression(line.expression)
	if _bubble != null and is_instance_valid(_bubble):
		_bubble.queue_free()
	_bubble = SpeechBubble.say(_popups, princess_node.popup_position(), line.text, 3.2, 32)


# ------------------------------------------------------------ small UI helpers

func _popup_panel(title: String) -> Control:
	var panel := UIKit.panel()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -720
	panel.offset_right = 720
	panel.offset_top = -470
	panel.offset_bottom = 470
	_ui.add_child(panel)
	_panel = panel
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	panel.add_child(v)
	var h := HBoxContainer.new()
	v.add_child(h)
	var t := UIKit.label(title, 30, UIKit.GOLD)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(t)
	var close := UIKit.button("ปิด", UIKit.BUTTON_ALT, 24, Vector2(140, 60))
	close.pressed.connect(_close_panel)
	h.add_child(close)
	room_buttons["panel_close"] = close
	return panel


func _close_panel() -> void:
	if _panel != null and is_instance_valid(_panel):
		_panel.queue_free()
	_panel = null


func _materials_row(size: int) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	for key in CastleTypes.MATERIALS:
		var n := collection.essence(key)
		if n <= 0:
			continue
		var icon := TextureRect.new()
		icon.texture = CastleTypes.material_icon(key)
		icon.custom_minimum_size = Vector2(size * 1.6, size * 1.6)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		row.add_child(icon)
		var l := _nl("x%d" % n, size, UIKit.LAVENDER)
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(l)
	return row


func open_settings() -> void:
	_close_panel()
	settings_screen.open()


## Android Back button (and Esc on desktop): close the top-most thing, never lose progress.
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		on_back()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		on_back()
		get_viewport().set_input_as_handled()


func on_back() -> void:
	if settings_screen != null and settings_screen.back():
		return
	if equipment_screen != null and equipment_screen.visible:
		equipment_screen.close()
	elif cards_screen != null and cards_screen.visible:
		cards_screen.close()
	elif _story_panel != null:
		return # story events finish with their own button
	elif _panel != null:
		_close_panel()
	elif current != null:
		show_overview()
	elif OS.has_feature("web"):
		return # a web page cannot quit itself; the browser tab is closed instead
	elif Time.get_ticks_msec() < _quit_armed_until:
		game_state.save_game()
		get_tree().quit()
	else:
		_quit_armed_until = Time.get_ticks_msec() + 2000
		_show_toast("กด Back อีกครั้งเพื่อออกจากเกม (บันทึกอัตโนมัติ)")


## Sound / music by id through the Audio autoload (no-op if it is missing).
func _audio(kind: String, id: String) -> void:
	var a := get_node_or_null("/root/Audio")
	if a != null:
		a.call(kind, id)


func _show_toast(text: String) -> void:
	if _toast != null and is_instance_valid(_toast):
		_toast.text = text


func _nl(text: String, size: int, color: Color) -> Label:
	var l := UIKit.label(text, size, color)
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	return l


func _label_c(text: String, size: int, color: Color) -> Label:
	var l := UIKit.label(text, size, color, HORIZONTAL_ALIGNMENT_CENTER)
	l.custom_minimum_size.x = 300
	return l
