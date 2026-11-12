extends SceneTree
## The AUTO button plays a whole battle by itself: press it once (through the real button),
## never touch anything else, and the first encounter must end (reward screen or result).
##   Godot_console.exe --headless --path . --script res://tests/auto_button_test.gd

var controller: BattleController
var deadline_ms := 0
var pressed := false


func _initialize() -> void:
	var gs := root.get_node_or_null("GameState")
	var st := root.get_node_or_null("Settings")
	if st != null:
		st.persist = false
	if gs != null:
		gs.persist = false
		gs.setup()
		gs.castle.unlock_all = true
		gs.castle.selected_stage = "stage_01"
		gs.castle.levels["sword_princess"] = {"level": 8, "exp": 0}
	controller = load("res://scenes/battle.tscn").instantiate()
	controller.random_seed = 7
	BattleController.auto_session = false
	root.add_child(controller)
	Engine.time_scale = 25.0
	deadline_ms = Time.get_ticks_msec() + 120000


func _process(_delta: float) -> bool:
	if Time.get_ticks_msec() > deadline_ms:
		printerr("AUTO TEST FAIL: timeout, round %d" % (controller.engine.round_number if controller.engine else -1))
		quit(1)
		return true
	var hud := controller.hud
	if controller.engine == null:
		return false
	if not pressed:
		if hud.auto_button == null:
			printerr("AUTO TEST FAIL: no AUTO button")
			quit(1)
			return true
		hud.auto_button.pressed.emit()
		pressed = true
		if not BattleController.auto_session or not hud.is_auto():
			printerr("AUTO TEST FAIL: AUTO did not turn on")
			quit(1)
			return true
		return false
	if controller.reward_screen.visible or hud.is_result_visible():
		var won := controller.last_outcome == CombatTypes.Outcome.VICTORY
		print("AUTO TEST OK: battle 1 ended by itself (%s) after %d rounds" % ["victory" if won else "defeat", controller.engine.round_number])
		BattleController.auto_session = false
		quit(0 if won else 1)
		return true
	return false
