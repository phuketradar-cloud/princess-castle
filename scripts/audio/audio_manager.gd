extends Node
## Autoload "Audio": plays sounds by id from res://data/sound_bank.tres.
##   Audio.sfx("hit")      Audio.music("battle")
## Creates the "Music" and "SFX" buses if the project has no bus layout, uses a small pool
## of players for overlapping effects, and cross-fades music. Every button in the game
## clicks automatically (hooked when it enters the tree).

const BANK_PATH := "res://data/sound_bank.tres"
const POOL_SIZE := 8
const FADE := 0.6

var bank: SoundBank
var current_music := ""
## Last sfx ids played (tests check that game events make sound).
var history: Array[String] = []
var _pool: Array[AudioStreamPlayer] = []
var _next := 0
var _music_a: AudioStreamPlayer
var _music_b: AudioStreamPlayer
var _tween: Tween


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_bus("Music")
	_ensure_bus("SFX")
	if ResourceLoader.exists(BANK_PATH):
		bank = load(BANK_PATH)
	for i in POOL_SIZE:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_pool.append(p)
	_music_a = _music_player()
	_music_b = _music_player()
	get_tree().node_added.connect(_on_node_added)
	var settings := get_node_or_null("/root/Settings")
	if settings != null:
		settings.apply() # buses exist now


func _music_player() -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.bus = "Music"
	add_child(p)
	return p


func _ensure_bus(bus_name: String) -> void:
	if AudioServer.get_bus_index(bus_name) >= 0:
		return
	AudioServer.add_bus()
	var i := AudioServer.bus_count - 1
	AudioServer.set_bus_name(i, bus_name)
	AudioServer.set_bus_send(i, "Master")


func sfx(id: String, pitch_jitter := 0.0) -> void:
	history.append(id)
	if history.size() > 64:
		history.pop_front()
	if bank == null:
		return
	var stream := bank.get_sfx(id)
	if stream == null:
		push_warning("Audio: no sfx '%s'" % id)
		return
	var p := _pool[_next]
	_next = (_next + 1) % _pool.size()
	p.stream = stream
	p.volume_db = float(bank.sfx_db.get(id, 0.0))
	p.pitch_scale = 1.0 + randf_range(-pitch_jitter, pitch_jitter)
	p.play()


## Switches the looping track with a short cross-fade. Same id = keep playing.
func music(id: String) -> void:
	if id == current_music or bank == null:
		return
	current_music = id
	var stream := bank.get_music(id)
	var old := _music_a
	_music_a = _music_b
	_music_b = old
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween().set_parallel(true)
	if old.playing:
		_tween.tween_property(old, "volume_db", -40.0, FADE)
		_tween.chain().tween_callback(old.stop)
	if stream != null:
		_music_a.stream = stream
		_music_a.volume_db = -40.0
		_music_a.play()
		_tween.tween_property(_music_a, "volume_db", 0.0, FADE)


func stop_music() -> void:
	current_music = ""
	_music_a.stop()
	_music_b.stop()


func _on_node_added(node: Node) -> void:
	if node is BaseButton and not node.has_meta("no_click"):
		node.pressed.connect(func(): sfx("click"))
