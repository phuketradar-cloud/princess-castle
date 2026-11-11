class_name SettingsScreen
extends CanvasLayer
## Settings popup (castle + battle): music / SFX volume, battle speed, vibration, FPS limit,
## "Save now" and "New Game" (with confirmation). Values live in the Settings autoload
## (user://settings.cfg); progress lives in GameState. Opened with open(), emits closed.

signal closed
signal new_game_started

## Exposed for tests / autoplay.
var music_slider: HSlider
var sfx_slider: HSlider
var speed_buttons := {}     ## speed -> Button
var fps_buttons := {}       ## fps -> Button
var vibration_button: Button
var shake_button: Button
var save_button: Button
var new_game_button: Button
var confirm_button: Button
var close_button: Button
var status_label: Label

var _root: Control
var _confirm_box: Control
var settings: Node
var game_state: Node


func _init() -> void:
	layer = 50
	visible = false


func open() -> void:
	settings = get_node_or_null("/root/Settings")
	game_state = get_node_or_null("/root/GameState")
	if _root == null:
		_build()
	_refresh()
	_confirm_box.visible = false
	status_label.text = ""
	visible = true


func close() -> void:
	visible = false
	closed.emit()


## Android back button / Esc: close the confirmation first, then the screen.
func back() -> bool:
	if not visible:
		return false
	if _confirm_box.visible:
		_confirm_box.visible = false
	else:
		close()
	return true


func _build() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root)
	_root.add_child(UIKit.dimmer(0.8))
	var main := UIKit.panel()
	main.set_anchors_preset(Control.PRESET_CENTER)
	main.offset_left = -560
	main.offset_right = 560
	main.offset_top = -450
	main.offset_bottom = 450
	_root.add_child(main)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 18)
	main.add_child(v)

	var header := HBoxContainer.new()
	v.add_child(header)
	var title := UIKit.label("ตั้งค่า", 44, UIKit.GOLD)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	close_button = UIKit.button("ปิด", UIKit.BUTTON_ALT, 30, Vector2(180, 80))
	close_button.pressed.connect(close)
	header.add_child(close_button)

	music_slider = _slider_row(v, "เพลง", func(x: float): _change("music_volume", x / 100.0))
	sfx_slider = _slider_row(v, "เสียงเอฟเฟกต์", func(x: float): _change("sfx_volume", x / 100.0))

	var speeds := _row(v, "ความเร็วการต่อสู้")
	for s in GameSettings.SPEEDS:
		var b := UIKit.button("%sx" % str(s), UIKit.BUTTON_ALT, 28, Vector2(150, 80))
		b.pressed.connect(func(): _change("battle_speed", s))
		speeds.add_child(b)
		speed_buttons[s] = b

	var vib := _row(v, "การสั่น (มือถือ)")
	vibration_button = UIKit.button("เปิด", UIKit.BUTTON_ALT, 28, Vector2(150, 80))
	vibration_button.pressed.connect(func(): _change("vibration", not settings.vibration))
	vib.add_child(vibration_button)

	var shk := _row(v, "จอสั่น (ตอนคริ / บอส)")
	shake_button = UIKit.button("เปิด", UIKit.BUTTON_ALT, 28, Vector2(150, 80))
	shake_button.pressed.connect(func(): _change("screen_shake", not settings.screen_shake))
	shk.add_child(shake_button)

	var fps := _row(v, "เฟรมเรต (ประหยัดแบต)")
	for f in GameSettings.FPS_OPTIONS:
		var b := UIKit.button("%d FPS" % f, UIKit.BUTTON_ALT, 28, Vector2(150, 80))
		b.pressed.connect(func(): _change("fps_limit", f))
		fps.add_child(b)
		fps_buttons[f] = b

	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 20)
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(actions)
	save_button = UIKit.button("✓ บันทึกเกมตอนนี้", Color8(40, 110, 80), 28, Vector2(380, 90))
	save_button.pressed.connect(_save_now)
	actions.add_child(save_button)
	new_game_button = UIKit.button("เริ่มเกมใหม่", Color8(130, 40, 50), 28, Vector2(300, 90))
	new_game_button.pressed.connect(func(): _confirm_box.visible = true)
	actions.add_child(new_game_button)
	status_label = UIKit.label("", 24, Color(0.55, 1, 0.7), HORIZONTAL_ALIGNMENT_CENTER)
	v.add_child(status_label)

	# Confirmation for the destructive action.
	_confirm_box = UIKit.panel(Color(0.18, 0.04, 0.08, 1), Color(1, 0.4, 0.4), 18, 4)
	var cv := VBoxContainer.new()
	cv.add_theme_constant_override("separation", 12)
	_confirm_box.add_child(cv)
	cv.add_child(UIKit.label("ลบความคืบหน้าทั้งหมดและเริ่มใหม่? (เซฟเดิมจะถูกเก็บเป็นไฟล์สำรอง .1)", 24, Color(1, 0.8, 0.8)))
	var ch := HBoxContainer.new()
	ch.alignment = BoxContainer.ALIGNMENT_CENTER
	ch.add_theme_constant_override("separation", 20)
	cv.add_child(ch)
	confirm_button = UIKit.button("ยืนยัน เริ่มใหม่", Color8(170, 40, 50), 26, Vector2(280, 80))
	confirm_button.pressed.connect(_new_game)
	ch.add_child(confirm_button)
	var cancel := UIKit.button("ยกเลิก", UIKit.BUTTON_ALT, 26, Vector2(200, 80))
	cancel.pressed.connect(func(): _confirm_box.visible = false)
	ch.add_child(cancel)
	v.add_child(_confirm_box)


func _row(parent: Control, text: String) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 16)
	parent.add_child(h)
	var l := UIKit.label(text, 30)
	l.custom_minimum_size.x = 380
	h.add_child(l)
	return h


func _slider_row(parent: Control, text: String, on_change: Callable) -> HSlider:
	var h := _row(parent, text)
	var s := HSlider.new()
	s.min_value = 0
	s.max_value = 100
	s.step = 5
	s.custom_minimum_size = Vector2(520, 70) # big touch target
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	s.add_theme_stylebox_override("slider", UIKit.panel_style(Color(0.2, 0.12, 0.28), UIKit.EDGE, 10, 2))
	s.add_theme_stylebox_override("grabber_area", UIKit.panel_style(UIKit.BUTTON, UIKit.BUTTON, 10, 0))
	s.add_theme_stylebox_override("grabber_area_highlight", UIKit.panel_style(UIKit.BUTTON, UIKit.BUTTON, 10, 0))
	h.add_child(s)
	var value := UIKit.label("", 28, UIKit.GOLD)
	value.custom_minimum_size.x = 90
	h.add_child(value)
	s.set_meta("value_label", value)
	# Only real user changes reach here: _refresh() uses set_value_no_signal.
	s.value_changed.connect(func(x: float):
		value.text = "%d%%" % int(x)
		on_change.call(x))
	return s


func _change(key: String, value) -> void:
	if settings == null:
		return
	settings.set_value(key, value)
	_refresh()


func _refresh() -> void:
	if settings == null:
		return
	_show_slider(music_slider, settings.music_volume)
	_show_slider(sfx_slider, settings.sfx_volume)
	for s in speed_buttons:
		_mark(speed_buttons[s], is_equal_approx(settings.battle_speed, s))
	for f in fps_buttons:
		_mark(fps_buttons[f], settings.fps_limit == f)
	vibration_button.text = "เปิด" if settings.vibration else "ปิด"
	_mark(vibration_button, settings.vibration)
	shake_button.text = "เปิด" if settings.screen_shake else "ปิด"
	_mark(shake_button, settings.screen_shake)


func _show_slider(s: HSlider, v: float) -> void:
	s.set_value_no_signal(v * 100.0)
	(s.get_meta("value_label") as Label).text = "%d%%" % roundi(v * 100.0)


func _mark(b: Button, on: bool) -> void:
	UIKit.style_button(b, UIKit.BUTTON if on else Color(0.22, 0.18, 0.3))


func _save_now() -> void:
	if game_state == null:
		return
	var ok: bool = game_state.save_game()
	status_label.text = ("บันทึกแล้ว %s" % game_state.last_saved_at.replace("T", " ")) if ok else "บันทึกไม่สำเร็จ (โหมดทดสอบหรือพื้นที่เต็ม)"


func _new_game() -> void:
	_confirm_box.visible = false
	if game_state != null:
		game_state.new_game()
	status_label.text = "เริ่มเกมใหม่แล้ว"
	new_game_started.emit()
