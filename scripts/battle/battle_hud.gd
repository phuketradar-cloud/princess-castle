class_name BattleHUD
extends CanvasLayer
## Screen-space battle UI. Displays data and forwards button presses as signals;
## it never touches the BattleEngine directly.

signal ability_pressed(index: int)
signal defend_pressed
signal continue_pressed
signal equipment_pressed
signal cards_pressed
signal castle_pressed
signal card_pressed(index: int)
signal auto_toggled(on: bool)

const ATTACK_COLOR := Color8(170, 50, 90)
const SKILL_COLOR := Color8(95, 60, 160)
const DEFEND_COLOR := Color8(50, 90, 140)
## Antique gold for frames (gothic JRPG look).
const GOLD := Color(0.85, 0.68, 0.35)
const PLATE := Color(0.05, 0.03, 0.1, 0.82)
## Skill cards, AUTO and the action cards all share one size.
const CARD_SIZE := Vector2(140, 226)
const ACTION_SIZE := CARD_SIZE

@export var log_lines := 4

@onready var stage_label: Label = %StageLabel
@onready var turn_label: Label = %TurnLabel
@onready var log_label: Label = %LogLabel
@onready var hint_label: Label = %HintLabel
@onready var player_name: Label = %PlayerName
@onready var hp_bar: ProgressBar = %HpBar
@onready var hp_label: Label = %HpLabel
@onready var ability_buttons: Array[Button] = [%AttackButton, %Skill1Button, %Skill2Button]
@onready var defend_button: Button = %DefendButton
@onready var result_panel: Control = %ResultPanel
@onready var result_title: Label = %ResultTitle
@onready var result_subtitle: Label = %ResultSubtitle
@onready var continue_button: Button = %ContinueButton
@onready var equipment_button: Button = %EquipmentButton
@onready var cards_button: Button = %CardsButton
@onready var castle_button: Button = %CastleButton
@onready var mana_label: Label = %ManaLabel
@onready var mana_gems: HBoxContainer = %ManaGems
@onready var card_hand: HBoxContainer = %CardHand

var _log: Array[String] = []
var _hp_target := 1.0
## Card buttons currently in the hand (index = deck index).
var card_buttons: Array[Button] = []
var auto_button: Button
var mana_orb: ManaOrb
var _materials: HBoxContainer
var _auto_on := false


func _ready() -> void:
	for i in ability_buttons.size():
		ability_buttons[i].pressed.connect(func(): ability_pressed.emit(i))
		_style_button(ability_buttons[i], ATTACK_COLOR if i == 0 else SKILL_COLOR)
	defend_button.pressed.connect(func(): defend_pressed.emit())
	_style_button(defend_button, DEFEND_COLOR)
	continue_button.pressed.connect(func(): continue_pressed.emit())
	_style_button(continue_button, ATTACK_COLOR)
	equipment_button.pressed.connect(func(): equipment_pressed.emit())
	_style_button(equipment_button, SKILL_COLOR)
	cards_button.pressed.connect(func(): cards_pressed.emit())
	_style_button(cards_button, Color8(40, 100, 150))
	castle_button.pressed.connect(func(): castle_pressed.emit())
	_style_button(castle_button, Color8(120, 80, 40))
	hide_result()
	_restyle()


## Mana gems: filled = available.
func set_mana(current: int, maximum: int) -> void:
	mana_label.text = "%d/%d" % [current, maximum]
	if mana_orb != null:
		mana_orb.set_mana(current, maximum)
		return
	while mana_gems.get_child_count() < maximum:
		var gem := Panel.new()
		gem.custom_minimum_size = Vector2(42, 42)
		gem.mouse_filter = Control.MOUSE_FILTER_IGNORE
		mana_gems.add_child(gem)
	for i in mana_gems.get_child_count():
		var gem: Panel = mana_gems.get_child(i)
		gem.visible = i < maximum
		var sb := StyleBoxFlat.new()
		sb.set_corner_radius_all(21)
		sb.set_border_width_all(3)
		sb.border_color = Color(0.55, 0.8, 1, 0.9)
		sb.bg_color = Color(0.3, 0.6, 1, 1) if i < current else Color(0.06, 0.05, 0.12, 1)
		gem.add_theme_stylebox_override("panel", sb)


## states: Array of {card: CardDefinition, enabled: bool, used: bool}
func set_cards(states: Array) -> void:
	while card_buttons.size() < states.size():
		var b := Button.new()
		b.custom_minimum_size = CARD_SIZE
		b.focus_mode = Control.FOCUS_NONE
		_vertical_card(b, 120, 21)
		var index := card_buttons.size()
		b.pressed.connect(func(): card_pressed.emit(index))
		card_hand.add_child(b)
		card_buttons.append(b)
	for i in card_buttons.size():
		var b := card_buttons[i]
		b.visible = i < states.size()
		if not b.visible:
			continue
		var st: Dictionary = states[i]
		var c: CardDefinition = st.card
		b.icon = c.icon
		b.text = "%s\n◆%d %s" % [c.display_name, c.mana_cost, "ใช้แล้ว" if st.used else CardTypes.category_name(c.category)]
		b.disabled = not st.enabled
		b.tooltip_text = c.description
		_card_style(b, CardTypes.category_color(c.category).darkened(0.45), ItemTypes.rarity_color(c.rarity))


func _process(delta: float) -> void:
	if not is_equal_approx(hp_bar.value, _hp_target):
		hp_bar.value = move_toward(hp_bar.value, _hp_target, delta * 1.5)


func set_stage(text: String) -> void:
	stage_label.text = text

func set_turn(text: String) -> void:
	turn_label.text = text

func set_hint(text: String) -> void:
	hint_label.text = text

func set_player(display_name: String, hp: int, max_hp: int, instant := false) -> void:
	player_name.text = display_name
	hp_label.text = "HP %d / %d" % [hp, max_hp]
	_hp_target = clampf(float(hp) / max_hp, 0.0, 1.0) if max_hp > 0 else 0.0
	if instant:
		hp_bar.value = _hp_target


## Icons on the action cards: [attack, skill 1, skill 2] (null = text only); defend has its own.
func set_action_icons(icons: Array, defend_icon: Texture2D) -> void:
	for i in ability_buttons.size():
		ability_buttons[i].icon = icons[i] if i < icons.size() else null
	defend_button.icon = defend_icon


## Materials (essences) in the top bar, right side. counts: Array of {icon, count}.
func set_materials(counts: Array) -> void:
	if _materials == null:
		return
	for c in _materials.get_children():
		c.queue_free()
	for e in counts:
		var icon := TextureRect.new()
		icon.texture = e.icon
		icon.custom_minimum_size = Vector2(36, 36)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		_materials.add_child(icon)
		var l := UIKit.label("x%d" % e.count, 20, UIKit.LAVENDER)
		l.autowrap_mode = TextServer.AUTOWRAP_OFF
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_materials.add_child(l)


func set_auto(on: bool) -> void:
	_auto_on = on
	if auto_button == null:
		return
	auto_button.text = "AUTO\n▶ ON" if on else "AUTO\nOFF"
	_card_style(auto_button, Color8(150, 110, 30) if on else Color(0.12, 0.08, 0.2), GOLD if on else Color(GOLD, 0.6), 16, on)


func is_auto() -> bool:
	return _auto_on


## states: Array of {visible, enabled, title, subtitle}, one per ability button.
func set_actions(states: Array, defend_enabled: bool) -> void:
	for i in ability_buttons.size():
		var b := ability_buttons[i]
		var has: bool = i < states.size() and states[i].visible
		b.visible = has
		if not has:
			continue
		b.disabled = not states[i].enabled
		b.text = states[i].title if states[i].subtitle == "" else "%s\n%s" % [states[i].title, states[i].subtitle]
	defend_button.disabled = not defend_enabled


func log_line(line: String) -> void:
	if line == "":
		return
	_log.append(line)
	while _log.size() > log_lines:
		_log.pop_front()
	log_label.text = "\n".join(_log)

func clear_log() -> void:
	_log.clear()
	log_label.text = ""


func show_result(title: String, subtitle: String, button_text: String, color: Color) -> void:
	result_panel.visible = true
	result_title.text = title
	result_title.add_theme_color_override("font_color", color)
	result_subtitle.text = subtitle
	continue_button.text = button_text
	result_panel.modulate.a = 0.0
	create_tween().tween_property(result_panel, "modulate:a", 1.0, 0.3)

func hide_result() -> void:
	result_panel.visible = false

func is_result_visible() -> bool:
	return result_panel.visible


func _style_button(b: Button, color: Color) -> void:
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		var sb := StyleBoxFlat.new()
		sb.set_corner_radius_all(18)
		sb.border_color = Color(1, 1, 1, 0.25)
		sb.set_border_width_all(3)
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


# ------------------------------------------------------------ gothic JRPG layout
# hud.tscn keeps every node the game and tests use; this re-places and re-skins them:
# top bar with a framed round banner + materials, a player plate top-left with the log under
# it, a mana orb, vertical card buttons, and an AUTO toggle.

func _restyle() -> void:
	var root: Control = $Root
	# --- top bar
	var top: ColorRect = stage_label.get_parent()
	top.color = Color(0.04, 0.02, 0.08, 0.78)
	var gold_line := ColorRect.new()
	gold_line.color = Color(GOLD, 0.85)
	gold_line.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	gold_line.offset_top = -2
	gold_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(gold_line)
	stage_label.add_theme_font_size_override("font_size", 28)
	stage_label.add_theme_color_override("font_color", UIKit.GOLD)
	stage_label.offset_right = 760
	stage_label.clip_text = true
	var banner := Panel.new()
	banner.add_theme_stylebox_override("panel", _frame(Color(0.1, 0.05, 0.18, 0.95), GOLD, 16, 3, 10))
	banner.set_anchors_preset(Control.PRESET_CENTER_TOP)
	banner.offset_left = -250
	banner.offset_right = 250
	banner.offset_top = 8
	banner.offset_bottom = 72
	banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(banner)
	turn_label.reparent(banner, false)
	turn_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	turn_label.offset_left = 0
	turn_label.offset_right = 0
	turn_label.offset_top = 0
	turn_label.offset_bottom = 0
	turn_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	turn_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	turn_label.add_theme_font_size_override("font_size", 26)
	_materials = HBoxContainer.new()
	_materials.add_theme_constant_override("separation", 6)
	_materials.alignment = BoxContainer.ALIGNMENT_END
	_materials.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	_materials.offset_left = -640
	_materials.offset_right = -30
	_materials.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(_materials)

	# --- player plate (top-left) and the log under it
	var plate := Panel.new()
	plate.add_theme_stylebox_override("panel", _frame(PLATE, GOLD, 14, 2, 8))
	plate.position = Vector2(24, 88)
	plate.size = Vector2(580, 64)
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(plate)
	root.move_child(plate, 1)
	player_name.reparent(root, false)
	player_name.position = Vector2(40, 92)
	player_name.size = Vector2(250, 56)
	player_name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	player_name.add_theme_font_size_override("font_size", 24)
	player_name.clip_text = true
	hp_bar.reparent(root, false)
	hp_bar.position = Vector2(292, 103)
	hp_bar.size = Vector2(296, 34)
	_bar_style(hp_bar, Color(0.35, 0.85, 0.5))
	hp_label.add_theme_font_size_override("font_size", 22)
	var log_panel: ColorRect = log_label.get_parent()
	log_panel.color = Color(0.03, 0.02, 0.07, 0.6)
	log_panel.position = Vector2(24, 158)
	log_panel.size = Vector2(580, 140)
	log_label.add_theme_font_size_override("font_size", 18)

	# --- bottom panel
	var bottom: ColorRect = mana_gems.get_parent()
	bottom.color = Color(0.05, 0.03, 0.09, 0.93)
	var edge: ColorRect = bottom.get_node("TopEdge")
	edge.color = GOLD
	edge.offset_bottom = 3
	mana_gems.visible = false
	mana_label.visible = false
	var mana_title: Label = bottom.get_node("ManaTitle")
	mana_title.position = Vector2(40, 10)
	mana_title.add_theme_color_override("font_color", Color(0.6, 0.85, 1))
	mana_orb = ManaOrb.new()
	mana_orb.position = Vector2(46, 46)
	mana_orb.size = Vector2(224, 224)
	bottom.add_child(mana_orb)
	card_hand.offset_left = 300
	card_hand.offset_right = 1000
	card_hand.offset_top = 22
	card_hand.offset_bottom = 22 + CARD_SIZE.y
	card_hand.add_theme_constant_override("separation", 12)
	var actions: HBoxContainer = defend_button.get_parent()
	actions.offset_left = -(ACTION_SIZE.x * 5 + 12 * 4) - 30 # AUTO + 4 actions
	actions.offset_right = -30
	actions.anchor_top = 0.0 # same row as the skill cards (scene anchors it to the bottom)
	actions.anchor_bottom = 0.0
	actions.offset_top = card_hand.offset_top
	actions.offset_bottom = card_hand.offset_bottom
	actions.add_theme_constant_override("separation", 12)
	var colors := [Color8(150, 35, 55), Color8(85, 45, 150), Color8(110, 60, 30)]
	for i in ability_buttons.size():
		var b := ability_buttons[i]
		b.custom_minimum_size = ACTION_SIZE
		_vertical_card(b, 120, 21)
		_card_style(b, colors[i], GOLD)
	defend_button.custom_minimum_size = ACTION_SIZE
	_vertical_card(defend_button, 120, 21)
	_card_style(defend_button, Color8(35, 75, 140), GOLD)
	hint_label.offset_left = 300
	hint_label.add_theme_font_size_override("font_size", 19)
	hint_label.offset_right = 1880

	# --- AUTO toggle: a card of its own between the skill cards and the action cards
	auto_button = Button.new()
	auto_button.name = "AutoButton"
	auto_button.focus_mode = Control.FOCUS_NONE
	auto_button.custom_minimum_size = ACTION_SIZE
	auto_button.add_theme_font_size_override("font_size", 30)
	auto_button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	auto_button.pressed.connect(func():
		set_auto(not _auto_on)
		auto_toggled.emit(_auto_on))
	actions.add_child(auto_button)
	actions.move_child(auto_button, 0)
	set_auto(false)


## Button laid out like a collectible card: big icon on top, text below.
func _vertical_card(b: Button, icon_w: int, font_size: int) -> void:
	b.expand_icon = true
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
	b.alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.add_theme_constant_override("icon_max_width", icon_w)
	b.add_theme_font_size_override("font_size", font_size)
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.add_theme_color_override("font_outline_color", Color(0.05, 0.02, 0.08))
	b.add_theme_constant_override("outline_size", 5)


## Card look: coloured body, gold (or rarity) frame, soft glow while it can be used.
func _card_style(b: Button, body: Color, frame: Color, radius := 14, glow := true) -> void:
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		var sb := _frame(body, frame, radius, 3, 10)
		match state:
			"hover":
				sb.bg_color = body.lightened(0.15)
				sb.border_color = frame.lightened(0.3)
			"pressed":
				sb.bg_color = body.darkened(0.25)
			"disabled":
				sb.bg_color = body.darkened(0.6)
				sb.border_color = Color(frame, 0.25)
			"focus":
				sb.draw_center = false
		if glow and state in ["normal", "hover"]:
			sb.shadow_color = Color(frame, 0.35)
			sb.shadow_size = 8
		b.add_theme_stylebox_override(state, sb)
	b.add_theme_color_override("font_disabled_color", Color(1, 1, 1, 0.35))
	b.add_theme_color_override("icon_disabled_color", Color(1, 1, 1, 0.3))


func _frame(bg: Color, border: Color, radius: int, width: int, margin: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(width)
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = margin
	sb.content_margin_right = margin
	sb.content_margin_top = margin
	sb.content_margin_bottom = margin
	return sb


func _bar_style(bar: ProgressBar, color: Color) -> void:
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.02, 0.01, 0.05, 0.9)
	bg.set_corner_radius_all(12)
	bg.set_border_width_all(2)
	bg.border_color = Color(GOLD, 0.7)
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	fill.set_corner_radius_all(12)
	bar.add_theme_stylebox_override("background", bg)
	bar.add_theme_stylebox_override("fill", fill)
