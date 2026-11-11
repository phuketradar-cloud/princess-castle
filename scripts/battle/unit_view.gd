class_name UnitView
extends Node2D
## On-screen princess / monster: sprite, HP bar, labels, target ring and tap handling.
## Contains no rules; BattleController tells it what to show. Origin = feet.

signal clicked(view: UnitView)

@export var hp_bar_width := 170.0
@export var player_hp_color := Color(0.45, 0.9, 0.6)
@export var enemy_hp_color := Color(0.95, 0.35, 0.45)

@onready var visual: CharacterAnimator = $Visual
@onready var doll: PaperDoll = $Visual/Doll
@onready var selection: EllipseShape = $Selection
@onready var shadow: EllipseShape = $Shadow
@onready var overhead: Node2D = $Overhead
@onready var intent_label: Label = $Overhead/IntentLabel
@onready var name_label: Label = $Overhead/NameLabel
@onready var status_label: Label = $Overhead/StatusLabel
@onready var hp_back: ColorRect = $Overhead/HpBack
@onready var hp_fill: ColorRect = $Overhead/HpFill
@onready var hp_label: Label = $Overhead/HpLabel

var unit: CombatUnit
var _shown_ratio := 1.0
var _target_ratio := 1.0
var _hit_rect := Rect2(-80, -200, 160, 220)
var _time := 0.0


## anchors = slot -> position on the body (princesses only; monsters pass {}).
func bind(p_unit: CombatUnit, texture: Texture2D, tint: Color, visual_scale: float, flip: bool, anchors: Dictionary = {}, art_scale := 1.0) -> void:
	unit = p_unit
	name = "Unit_%s_%d" % [unit.unit_name.replace(" ", ""), unit.id]
	doll.setup(texture, tint, flip, anchors, art_scale)
	var tex_size := doll.texture_size()
	visual.rest_scale = Vector2.ONE * visual_scale
	visual.reset_pose()

	# Size everything from the artwork so real art of any size just works.
	var w := tex_size.x * visual_scale
	var h := tex_size.y * visual_scale
	overhead.position = Vector2(0, -h - 10)
	var hit_w := maxf(w, 140.0)
	_hit_rect = Rect2(-hit_w * 0.5, -h - 70, hit_w, h + 90)
	shadow.radius = Vector2(w * 0.38, 16)
	selection.radius = Vector2(maxf(w * 0.5, 80.0), 26)

	name_label.text = ("[BOSS] " if unit.is_boss else "") + unit.unit_name
	name_label.add_theme_color_override("font_color", Color(1, 0.84, 0.47) if unit.is_boss else Color(0.88, 0.82, 0.96))
	hp_fill.color = player_hp_color if unit.team == CombatTypes.Team.PLAYER else enemy_hp_color
	hp_back.size = Vector2(hp_bar_width + 6, 22)
	hp_back.position = Vector2(-hp_bar_width * 0.5 - 3, -25)
	hp_fill.position = Vector2(-hp_bar_width * 0.5, -22)

	_shown_ratio = unit.hp_ratio()
	set_hp(unit.current_hp, unit.stats.max_hp, true)
	set_intent("", Color.WHITE)
	set_status_text("")
	set_selected(false)


## Shows equipment on the body immediately (paper doll) with a little sparkle pop.
func set_equipment(items: Array, animate := false) -> void:
	doll.set_equipment(items)
	if animate:
		visual.brace()


func set_hp(current: int, max_hp: int, instant := false) -> void:
	_target_ratio = clampf(float(current) / max_hp, 0.0, 1.0) if max_hp > 0 else 0.0
	if instant:
		_shown_ratio = _target_ratio
	hp_label.text = "%d/%d" % [current, max_hp]
	_update_bar()


func set_intent(text: String, color: Color) -> void:
	intent_label.text = text
	intent_label.add_theme_color_override("font_color", color)


func set_status_text(text: String) -> void:
	status_label.text = text


func set_selected(selected: bool) -> void:
	selection.visible = selected


## Banish: the unit fades almost out and its labels hide until it returns.
func set_banished(banished: bool) -> void:
	create_tween().tween_property(self, "modulate:a", 0.18 if banished else 1.0, 0.35)
	overhead.visible = not banished
	if banished:
		set_selected(false)


## Ice Prison / Time Stop look: icy blue tint on the body.
func set_frozen(frozen: bool) -> void:
	doll.modulate = Color(0.55, 0.8, 1.25) if frozen else Color.WHITE


## Companion in the back row: no HP bar (she is never attacked), just a name + assist label.
func set_support_mode() -> void:
	hp_back.visible = false
	hp_fill.visible = false
	hp_label.visible = false


## Status text to the right of the HP bar instead of above the name (used for the princess,
## whose overhead area sits under the battle log).
func place_status_beside_hp() -> void:
	status_label.offset_left = 96.0
	status_label.offset_right = 520.0
	status_label.offset_top = -34.0
	status_label.offset_bottom = 4.0
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT


func set_dead_visuals() -> void:
	set_selected(false)
	overhead.visible = false
	shadow.visible = false


func popup_position() -> Vector2:
	return overhead.global_position + Vector2(0, -90)


func _process(delta: float) -> void:
	_time += delta
	if not is_equal_approx(_shown_ratio, _target_ratio):
		_shown_ratio = move_toward(_shown_ratio, _target_ratio, delta * 1.5)
		_update_bar()
	if selection.visible:
		var pulse := 1.0 + sin(_time * 6.0) * 0.06
		selection.scale = Vector2(pulse, pulse)


func _update_bar() -> void:
	hp_fill.size = Vector2(hp_bar_width * _shown_ratio, 16)


## Tap on a monster = select it as the target. HUD buttons consume their own taps first.
func _unhandled_input(event: InputEvent) -> void:
	if unit == null or not unit.is_targetable() or unit.team != CombatTypes.Team.ENEMY:
		return
	var mb := event as InputEventMouseButton
	if mb == null or not mb.pressed or mb.button_index != MOUSE_BUTTON_LEFT:
		return
	if _hit_rect.has_point(to_local(get_global_mouse_position())):
		clicked.emit(self)
		get_viewport().set_input_as_handled()
