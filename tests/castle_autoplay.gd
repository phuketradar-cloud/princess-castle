extends SceneTree
## End-to-end test of the castle (Phase 4) through its real buttons:
## overview -> room -> activities -> talk (daily limit) -> gift -> craft + place furniture
## (room-type rule, owner-only bonus) -> Bond Lv3 story event -> Lv4/Lv5 rewards -> status screen
## -> another princess's room -> adventure: the battle scene loads with that princess.
##   Godot_console.exe --headless --path . --script res://tests/castle_autoplay.gd
##   (add `--resolution 1920x1080 ... -- --shots=C:/tmp/shots` without --headless for screenshots)

var shot_dir := ""
var castle_scene: CastleController
var gs: Node
var step := 0
var wait := 0
var deadline := 0
var log_lines: Array[String] = []


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots="):
			shot_dir = a.substr(8)
			DirAccess.make_dir_recursive_absolute(shot_dir)
	gs = root.get_node_or_null("GameState")
	if gs == null:
		gs = load("res://scripts/core/game_state.gd").new()
		gs.name = "GameState"
		root.add_child(gs)
	gs.persist = false
	var st := root.get_node_or_null("Settings")
	if st != null:
		st.persist = false # never touch the player's settings file
	gs.setup()
	# Test materials so crafting / gifts are possible.
	for key in ["fire", "ice", "shadow", "light", "dragon", "bone_fragment", "dragon_scale", "ice_crystal", "holy_fragment"]:
		gs.collection.add_essence(key, 20)
	gs.castle.unlock_all = true
	castle_scene = load("res://scenes/castle.tscn").instantiate()
	root.add_child(castle_scene)
	current_scene = castle_scene # so change_scene_to_file replaces it like in the real game
	deadline = Time.get_ticks_msec() + 180000
	Engine.time_scale = 4.0
	wait = 30 # let the overview (SubViewports) render first


func _process(_d: float) -> bool:
	if Time.get_ticks_msec() > deadline:
		return _fail("timeout at step %d" % step)
	if wait > 0:
		wait -= 1
		return false
	var c := castle_scene
	var sword: PrincessDefinition = gs.roster.find("sword_princess")
	match step:
		0:
			_shot("castle_overview")
			if c.wing_buttons.size() != 5:
				return _fail("expected 5 unlocked wings, got %d" % c.wing_buttons.size())
			# Phase 6: settings through the real ⚙ button
			c.room_buttons["settings"].pressed.emit()
			step = 99
			wait = 10
		1:
			if c.current != sword or c.princess_node == null:
				return _fail("room did not open")
			if c.last_speech == "":
				return _fail("no greeting line")
			_ok("room opened, greeting: " + c.last_speech)
			_shot("room_sword")
			c.princess_node.auto_live = false
			c.princess_node.do_activity(CastleTypes.Activity.SLEEPING)
			_next(60)
		2:
			if c.princess_node.activity != CastleTypes.Activity.SLEEPING or c.princess_node._busy:
				return false # still walking to the bed
			_shot("activity_sleeping")
			c.princess_node.do_activity(CastleTypes.Activity.READING)
			_next(60)
		3:
			if c.princess_node.activity != CastleTypes.Activity.READING or c.princess_node._busy:
				return false
			_shot("activity_reading")
			c.princess_node.do_activity(CastleTypes.Activity.DRINKING_TEA)
			_next(60)
		4:
			if c.princess_node.activity != CastleTypes.Activity.DRINKING_TEA or c.princess_node._busy:
				return false
			_shot("activity_tea")
			_ok("activities: sleeping / reading / tea reached their event spots")
			var before: int = gs.castle.bond_points("sword_princess")
			for i in 4:
				c.room_buttons["talk"].pressed.emit()
			var gained: int = gs.castle.bond_points("sword_princess") - before
			if gained != 3:
				return _fail("talk bond expected +3 (3/day limit), got +%d" % gained)
			_ok("talk x4 -> bond +3 (daily limit works), line: " + c.last_speech)
			_next(20)
		5:
			c.room_buttons["gift"].pressed.emit()
			_next(5)
		6:
			_shot("gift_panel")
			var before: int = gs.castle.bond_points("sword_princess")
			var btn: Button = c._panel.find_child("Gift_fire", true, false)
			if btn == null:
				return _fail("gift button missing")
			btn.pressed.emit()
			var gained: int = gs.castle.bond_points("sword_princess") - before
			if gained != CastleProgress.GIFT_LIKED_BOND:
				return _fail("liked gift should give +%d, got +%d" % [CastleProgress.GIFT_LIKED_BOND, gained])
			_ok("liked gift (fire) -> bond +%d" % gained)
			c.room_buttons["decorate"].pressed.emit()
			_next(5)
		7:
			var luck_before: float = gs.castle.furniture_bonus("sword_princess", gs.roster).luck
			c.room_buttons["craft_lucky_bed"].pressed.emit()
			_next(3)
		8:
			if gs.castle.furniture.get("lucky_bed", 0) != 1:
				return _fail("craft lucky_bed failed")
			c.room_buttons["place_lucky_bed"].pressed.emit()
			_next(3)
		9:
			var fb: StatBlock = gs.castle.furniture_bonus("sword_princess", gs.roster)
			if fb.luck <= 0:
				return _fail("lucky bed gave no luck bonus")
			if gs.castle.furniture_bonus("magic_princess", gs.roster).luck != 0:
				return _fail("bonus leaked into another princess's room")
			if not c.room_buttons["place_dragon_bed"].disabled:
				return _fail("dragon bed (Dragon Wing only) should not be placeable in Sword Wing")
			_ok("crafted + placed Lucky Bed -> LUK +%d (owner only); Dragon Bed blocked by room type" % fb.luck)
			c.room_buttons["craft_rose_training_hall"].pressed.emit()
			_next(3)
		10:
			c.room_buttons["place_rose_training_hall"].pressed.emit()
			_next(3)
		11:
			_shot("decorate_panel")
			c.room_buttons["panel_close"].pressed.emit()
			_next(10)
		12:
			_shot("room_decorated")
			# Push bond to Lv3 -> story event
			gs.castle.add_bond("sword_princess", CastleTypes.BOND_THRESHOLDS[3] - gs.castle.bond_points("sword_princess"))
			c._after_bond_change()
			_next(5)
		13:
			if c._story_panel == null:
				return _fail("Bond Lv3 story event did not start")
			_shot("story_event")
			var lines := 0
			while c._story_panel != null and lines < 10:
				c.room_buttons["story_next"].pressed.emit()
				lines += 1
			_ok("Bond Lv3 story event played (%d lines)" % lines)
			gs.castle.add_bond("sword_princess", 100)
			c._after_bond_change()
			_next(5)
		14:
			if not gs.collection.cards.has("rose_oath"):
				return _fail("Lv5 exclusive card not granted")
			if gs.castle.furniture.get("rose_vanity", 0) != 1:
				return _fail("Lv4 cosmetic not granted")
			_ok("Bond Lv5 rewards: Rose Oath card + Rose Vanity skin")
			c.room_buttons["status"].pressed.emit()
			_next(8)
		15:
			if not c.equipment_screen.visible:
				return _fail("status screen not shown")
			if not c.equipment_screen._stats_label.text.contains("เฟอร์นิเจอร์ห้อง"):
				return _fail("status does not show furniture bonus")
			_shot("status_screen")
			c.equipment_screen.close()
			c.room_buttons["back"].pressed.emit()
			_next(8)
		16:
			if c.current != null:
				return _fail("back to overview failed")
			# Phase 5: Light Princess as companion (Magic + Light = Starlit Prayer synergy).
			c.room_buttons["companion_light_princess"].pressed.emit()
			_next(15)
		17:
			if gs.castle.companion != "light_princess":
				return _fail("companion button did not set the companion")
			_shot("castle_overview_companion")
			gs.castle.cleared_stages.append("stage_01") # stage 2 open
			c.wing_buttons["magic_princess"].pressed.emit()
			_next(15)
		18:
			_shot("room_magic")
			c.room_buttons["adventure"].pressed.emit()
			_next(8)
		99:
			var ss := c.settings_screen
			var st := root.get_node("Settings")
			if not ss.visible:
				return _fail("settings screen did not open")
			ss.speed_buttons[2.0].pressed.emit()
			ss.fps_buttons[30].pressed.emit()
			ss.music_slider.value = 40
			if st.battle_speed != 2.0 or st.fps_limit != 30 or not is_equal_approx(st.music_volume, 0.4):
				return _fail("settings buttons did not change values")
			if Engine.max_fps != 30:
				return _fail("FPS limit not applied")
			var vib: bool = st.vibration
			ss.vibration_button.pressed.emit()
			if st.vibration == vib:
				return _fail("vibration toggle failed")
			wait = 6
			step = 100
		100:
			_shot("settings_screen")
			var ss := c.settings_screen
			var st := root.get_node("Settings")
			ss.speed_buttons[1.0].pressed.emit()
			ss.fps_buttons[60].pressed.emit()
			c.on_back() # Android Back closes the settings screen
			if ss.visible:
				return _fail("Back did not close settings")
			var audio := root.get_node("Audio")
			if not audio.history.has("click") or audio.current_music != "castle":
				return _fail("no click sound / castle music (history %s, music %s)" % [audio.history, audio.current_music])
			_ok("settings: speed 2x, 30 FPS, music 40%, vibration toggled, Back closes; click sfx + castle music playing")
			c.wing_buttons["sword_princess"].pressed.emit()
			wait = 10
			step = 1
		19:
			if c._panel == null or not c.room_buttons.has("stage_stage_02"):
				return _fail("stage select did not open")
			_shot("stage_select")
			_ok("stage select opened (%d stages)" % gs.roster.stages.size())
			c.room_buttons["stage_stage_02"].pressed.emit()
			_next(40)
		20:
			var battle := current_scene as BattleController
			if battle == null:
				return _fail("adventure did not load the battle scene")
			if battle.princess.id != "magic_princess":
				return _fail("battle uses %s, expected magic_princess" % battle.princess.id)
			if battle.stage.id != "stage_02":
				return _fail("battle stage is %s, expected stage_02" % battle.stage.id)
			if battle.companion_unit == null or battle._view(battle.companion_unit) == null:
				return _fail("companion not in battle")
			if battle.synergy == null or battle.synergy.display_name != "Starlit Prayer":
				return _fail("synergy Magic+Light missing")
			if battle.engine == null or battle.engine.mana != 3:
				return _fail("Magic (+1) + Starlit Prayer (+1) should start with 3 mana, got %d" % battle.engine.mana)
			var pv: UnitView = battle._view(battle.engine.player)
			if not pv.doll.has_face():
				return _fail("battle princess has no face layers")
			_ok("battle: Magic Princess + companion Light, Frozen Library, synergy Starlit Prayer, mana 3")
			_next(40)
		21:
			_shot("battle_companion")
			print("CASTLE AUTOPLAY OK\n  " + "\n  ".join(log_lines))
			quit(0)
			return true
	return false


func _next(frames: int) -> void:
	step += 1
	wait = frames


func _ok(msg: String) -> void:
	log_lines.append(msg)


func _fail(msg: String) -> bool:
	printerr("CASTLE AUTOPLAY FAIL: " + msg)
	quit(1)
	return true


func _shot(n: String) -> void:
	if shot_dir == "" or DisplayServer.get_name() == "headless":
		return
	root.get_texture().get_image().save_png("%s/%s.png" % [shot_dir, n])
