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

const ATTACK_COLOR := Color8(170, 50, 90)
const SKILL_COLOR := Color8(95, 60, 160)
const DEFEND_COLOR := Color8(50, 90, 140)

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


## Mana gems: filled = available.
func set_mana(current: int, maximum: int) -> void:
	mana_label.text = "%d/%d" % [current, maximum]
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
		b.custom_minimum_size = Vector2(250, 112)
		b.focus_mode = Control.FOCUS_NONE
		b.expand_icon = true
		b.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.add_theme_constant_override("icon_max_width", 76)
		b.add_theme_font_size_override("font_size", 22)
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
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
		b.text = "%s\n◆%d  %s" % [c.display_name, c.mana_cost, "ใช้แล้ว" if st.used else CardTypes.category_name(c.category)]
		b.disabled = not st.enabled
		b.tooltip_text = c.description
		UIKit.style_button(b, CardTypes.category_color(c.category).darkened(0.35), 14)
		var border := ItemTypes.rarity_color(c.rarity)
		for state in ["normal", "hover", "pressed"]:
			var sb: StyleBoxFlat = b.get_theme_stylebox(state)
			sb.border_color = border


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
