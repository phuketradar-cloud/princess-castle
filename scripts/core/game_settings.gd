class_name GameSettings
extends Node
## Autoload "Settings": player preferences, stored separately from game progress in
## user://settings.cfg (a ConfigFile), so a corrupt save never resets volume etc. and
## "New Game" keeps the player's preferences.
## Other systems read the values and listen to `changed`; nothing here knows about them.

signal changed

const PATH := "user://settings.cfg"
## Battle playback speeds offered in the Settings screen.
const SPEEDS := [1.0, 1.5, 2.0]
const FPS_OPTIONS := [30, 60]

var music_volume := 0.7   ## 0..1
var sfx_volume := 0.9     ## 0..1
var battle_speed := 1.0   ## multiplies battle animation speed (delays are divided by it)
var vibration := true     ## short vibration on crits / boss phases (Android)
var screen_shake := true  ## camera shake on crits / boss phases
var fps_limit := 60       ## lower = less battery / heat
## Tests turn this off so they never touch the player's settings file.
var persist := true
var path := PATH


func _ready() -> void:
	load_settings()
	apply()


func to_dict() -> Dictionary:
	return {"music_volume": music_volume, "sfx_volume": sfx_volume, "battle_speed": battle_speed,
		"vibration": vibration, "fps_limit": fps_limit, "screen_shake": screen_shake}


## Unknown / missing / out-of-range values fall back to safe defaults.
func from_dict(d: Dictionary) -> void:
	music_volume = clampf(float(d.get("music_volume", music_volume)), 0.0, 1.0)
	sfx_volume = clampf(float(d.get("sfx_volume", sfx_volume)), 0.0, 1.0)
	var spd := float(d.get("battle_speed", battle_speed))
	battle_speed = spd if SPEEDS.has(spd) else 1.0
	vibration = bool(d.get("vibration", vibration))
	screen_shake = bool(d.get("screen_shake", screen_shake))
	var fps := int(d.get("fps_limit", fps_limit))
	fps_limit = fps if FPS_OPTIONS.has(fps) else 60


func load_settings() -> void:
	if not persist:
		return
	var cfg := ConfigFile.new()
	if cfg.load(path) != OK:
		return # first run or unreadable: keep defaults
	var d := {}
	for key in to_dict():
		d[key] = cfg.get_value("settings", key, to_dict()[key])
	from_dict(d)


func save_settings() -> void:
	if not persist:
		return
	var cfg := ConfigFile.new()
	var d := to_dict()
	for key in d:
		cfg.set_value("settings", key, d[key])
	var err := cfg.save(path)
	if err != OK:
		push_warning("Settings not saved: %s" % error_string(err))


## Change one value (key from to_dict), apply, save and notify.
func set_value(key: String, value) -> void:
	var d := to_dict()
	if not d.has(key):
		push_warning("Unknown setting: " + key)
		return
	d[key] = value
	from_dict(d)
	apply()
	save_settings()
	changed.emit()


func apply() -> void:
	Engine.max_fps = fps_limit
	_set_bus("Music", music_volume)
	_set_bus("SFX", sfx_volume)


## Linear 0..1 slider -> bus dB (0 = muted).
static func linear_db(v: float) -> float:
	return -80.0 if v <= 0.001 else linear_to_db(v)


func _set_bus(bus_name: String, v: float) -> void:
	var i := AudioServer.get_bus_index(bus_name)
	if i < 0:
		return
	AudioServer.set_bus_volume_db(i, linear_db(v))
	AudioServer.set_bus_mute(i, v <= 0.001)


## PC: F11 or Alt+Enter toggles fullscreen (desktop only; phones are always fullscreen).
func _unhandled_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k == null or not k.pressed or k.echo or OS.has_feature("mobile"):
		return
	if k.keycode == KEY_F11 or (k.keycode == KEY_ENTER and k.alt_pressed):
		var full := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if full else DisplayServer.WINDOW_MODE_FULLSCREEN)
		get_viewport().set_input_as_handled()


func vibrate(ms := 60) -> void:
	if vibration and (OS.has_feature("mobile") or OS.has_feature("web_android")):
		Input.vibrate_handheld(ms)
