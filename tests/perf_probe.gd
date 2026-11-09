extends SceneTree
## Performance probe (needs a real window, not --headless):
##   Godot_console.exe --path . --resolution 1920x1080 --script res://tests/perf_probe.gd
## Measures each scene for a few seconds with vsync + FPS cap OFF (raw cost), then prints
## avg / worst frame time, draw calls, node count, memory. Fails if any scene averages
## above BUDGET_MS (desktop budget; phones are ~3-5x slower, so this keeps 60 FPS headroom).

const BUDGET_MS := 4.0
const SECONDS := 3.0

var results: Array[String] = []
var _scene: Node
var _step := 0
var _t0 := 0
var _frames := 0
var _worst := 0.0
var _sum := 0.0
var _draw := 0.0
var _warm := 0
var _ok := true
var gs: Node

var STEPS := [
	["castle overview", func(): _load("res://scenes/castle.tscn")],
	["castle room", func(): _scene.enter_room(gs.roster.find("sword_princess"))],
	["battle stage 1", func(): _load("res://scenes/battle.tscn")],
	["battle boss (stage 4, 6 monsters)", func():
		gs.castle.unlock_all = true
		gs.castle.selected_stage = "stage_04"
		_load("res://scenes/battle.tscn")
		_scene._begin_encounter(1)],
]


func _initialize() -> void:
	gs = root.get_node_or_null("GameState")
	gs.persist = false
	gs.setup()
	var settings := root.get_node_or_null("Settings")
	if settings:
		settings.persist = false
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	_start(0)


func _load(path: String) -> void:
	if _scene != null:
		_scene.queue_free()
	_scene = load(path).instantiate()
	root.add_child(_scene)
	current_scene = _scene


func _start(i: int) -> void:
	_step = i
	STEPS[i][1].call()
	_warm = 30
	_frames = 0
	_sum = 0.0
	_worst = 0.0
	_draw = 0.0


func _process(delta: float) -> bool:
	Engine.max_fps = 0 # Settings autoload may re-apply its cap
	if _warm > 0:
		_warm -= 1
		if _warm == 0:
			_t0 = Time.get_ticks_msec()
		return false
	var ms := delta * 1000.0
	_frames += 1
	_sum += ms
	_worst = maxf(_worst, ms)
	_draw += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	if Time.get_ticks_msec() - _t0 < SECONDS * 1000:
		return false
	var avg := _sum / _frames
	var line := "PERF %-34s avg %5.2f ms (%4d FPS) | worst %5.1f ms | draw calls %4d | nodes %4d | mem %5.1f MB" % [
		STEPS[_step][0], avg, roundi(1000.0 / avg), _worst, roundi(_draw / _frames),
		int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
		Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0]
	if avg > BUDGET_MS:
		line += "  <- OVER BUDGET"
		_ok = false
	print(line)
	if _step + 1 < STEPS.size():
		_start(_step + 1)
		return false
	print("PERF ", "OK" if _ok else "FAIL")
	quit(0 if _ok else 1)
	return true
