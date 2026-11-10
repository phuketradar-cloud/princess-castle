extends SceneTree
## End-to-end test of the REAL battle scene: presses the actual HUD buttons (chosen by
## AutoBattlePolicy) until the stage is cleared or lost.
##
## Headless (fast, CI):   Godot_console.exe --headless --path . --script res://tests/autoplay.gd
## With screenshots:      Godot_console.exe --path . --resolution 1920x1080 --script res://tests/autoplay.gd -- --shots=C:/tmp/shots --seed=3
## Exit code 0 = stage reached a result screen without errors.

var controller: BattleController
var policy := AutoBattlePolicy.new()
var shot_dir := ""
var deadline_ms := 0
var actions := 0
var shots_taken := {}
var settle_frames := 0
var max_encounter := 0


func _initialize() -> void:
	var seed_value := 0
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shots="):
			shot_dir = arg.substr(8)
			DirAccess.make_dir_recursive_absolute(shot_dir)
		elif arg.begins_with("--seed="):
			seed_value = int(arg.substr(7))
		elif arg.begins_with("--stage="):
			p5_stage = arg.substr(8)
		elif arg.begins_with("--level="):
			p5_level = int(arg.substr(8))
		elif arg.begins_with("--companion="):
			p5_companion = arg.substr(12)
	# Never touch the player's real save file.
	var gs := root.get_node_or_null("GameState")
	var st := root.get_node_or_null("Settings")
	if st != null:
		st.persist = false
	if gs != null:
		gs.persist = false
		# Phase 5 setup: chosen stage, level and companion (everything unlocked for the test).
		if p5_stage != "":
			gs.setup()
			gs.castle.unlock_all = true
			gs.castle.selected_stage = p5_stage
			gs.castle.companion = p5_companion
			if p5_level > 1:
				gs.castle.levels["sword_princess"] = {"level": p5_level, "exp": 0}
				if p5_companion != "":
					gs.castle.levels[p5_companion] = {"level": p5_level, "exp": 0}
			level_before = p5_level
	var scene: BattleController = load("res://scenes/battle.tscn").instantiate()
	scene.random_seed = seed_value
	root.add_child(scene)
	controller = scene
	# Screenshots run at normal-ish speed so popups are visible; headless runs fast.
	Engine.time_scale = 3.0 if shot_dir != "" else 25.0
	deadline_ms = Time.get_ticks_msec() + 240000


func _process(_delta: float) -> bool:
	if Time.get_ticks_msec() > deadline_ms:
		printerr("AUTOPLAY FAIL: timeout (encounter %d, actions %d)" % [controller.encounter_index, actions])
		quit(1)
		return true
	var hud := controller.hud
	if controller.engine == null:
		return false
	max_encounter = maxi(max_encounter, controller.encounter_index)

	# --- Phase 2: reward choice
	if controller.reward_screen.visible:
		if not _settle(12):
			return false
		_shot("reward_battle%d" % (controller.encounter_index + 1))
		var col := controller.collection
		var equipped := {}
		for slot in ItemTypes.Slot.values():
			var it := col.equipped_in(controller.princess.id, slot)
			if it != null:
				equipped[slot] = it
		var p := controller.engine.player
		var pick := policy.choose_reward(controller.reward_options, equipped, p.current_hp, p.stats.max_hp, col.cards)
		var opt = controller.reward_options[pick]
		print("REWARD battle %d options=%s pick=%d hp=%d/%d" % [controller.encounter_index + 1,
			str(controller.reward_options.map(func(o): return o.item.id if o.item else ("card:" + o.card.id if o.card else "restore"))),
			pick, p.current_hp, p.stats.max_hp])
		var cards_before := col.card_count(opt.card.id) if opt.card else 0
		controller.reward_screen.cards[pick].pressed.emit()
		if opt.kind == LootTable.RewardOption.Kind.CARD:
			rewards_taken.append("card:" + opt.card.id)
			if col.card_count(opt.card.id) != cards_before + 1:
				_fail("card reward %s was not added to the collection" % opt.card.id)
				return true
		if opt.kind == LootTable.RewardOption.Kind.EQUIPMENT:
			rewards_taken.append(opt.item.id)
			if not col.is_equipped(controller.princess.id, opt.item.id):
				_fail("picked item %s was not equipped" % opt.item.id)
				return true
			# Paper doll must show every equipped item on the princess.
			var pv: UnitView = controller._view(p)
			# Items in slots this princess draws (her slot_anchors); e.g. HD art hides armor.
			var drawn := col.equipped_items(controller.princess.id).filter(func(i): return controller.princess.slot_anchors.has(i.slot)).size()
			if pv.doll.layer_count() != drawn:
				_fail("paper doll shows %d layers, expected %d" % [pv.doll.layer_count(), drawn])
				return true
		settle_frames = 0
		return false

	# --- Phase 2: equipment screen (visited once after the first victory)
	if controller.equipment_screen.visible:
		if not _settle(8):
			return false
		_shot("equipment_screen")
		var es := controller.equipment_screen
		# Unequip + re-equip the weapon through the real buttons, checking stats change.
		var weapon := controller.collection.equipped_in(controller.princess.id, ItemTypes.Slot.WEAPON)
		if weapon != null and equip_step == 0:
			es.select_item(weapon.id)  # show details first (screenshot next frames)
			equip_step = 1
			settle_frames = 0
			return false
		if weapon != null and equip_step == 1:
			_shot("equipment_detail")
			es._action_button.pressed.emit() # unequip
			if controller.collection.equipped_in(controller.princess.id, ItemTypes.Slot.WEAPON) != null:
				_fail("unequip via button failed")
				return true
			es._action_button.pressed.emit() # equip again
			if controller.collection.equipped_in(controller.princess.id, ItemTypes.Slot.WEAPON) != weapon:
				_fail("re-equip via button failed")
				return true
		equip_step += 1
		es.close()
		settle_frames = 0
		return false

	# --- Phase 3: cards screen (visited after the first victory): tabs, deck toggle, craft
	if controller.cards_screen.visible:
		if not _settle(8):
			return false
		var cs := controller.cards_screen
		match cards_step:
			0:
				if not cs.deck_buttons.is_empty():
					cs.deck_buttons[0].pressed.emit() # select first deck card -> details
				cards_step = 1
			1:
				_shot("cards_deck")
				# remove + re-add the selected card through the real button
				var sel := cs.selected_card_id
				var in_deck := controller.collection.deck.has(sel)
				cs.toggle_deck(sel)
				if controller.collection.deck.has(sel) == in_deck:
					_fail("deck toggle did nothing")
					return true
				cs.toggle_deck(sel)
				cs.select_tab(1)
				cards_step = 2
			2:
				_shot("cards_craft")
				for card_id in cs.craft_buttons:
					var b: Button = cs.craft_buttons[card_id]
					if not b.disabled:
						var before := controller.collection.card_count(card_id)
						b.pressed.emit()
						if controller.collection.card_count(card_id) != before + 1:
							_fail("craft button did not create %s" % card_id)
							return true
						crafted.append(card_id)
						break
				cards_step = 3
			3:
				if not crafted.is_empty():
					_shot("cards_craft_done")
				cs.select_tab(2)
				cards_step = 4
			4:
				_shot("cards_fusion")
				cs.close()
				cards_step = 5
		settle_frames = 0
		return false

	if hud.is_result_visible():
		if not _settle():
			return false
		_shot("result_battle%d_%s" % [controller.encounter_index + 1, hud.result_title.text.replace("!", "").replace(" ", "_")])
		if not equipment_visited and controller.last_outcome == CombatTypes.Outcome.VICTORY:
			equipment_visited = true
			hud.equipment_button.pressed.emit()
			settle_frames = 0
			return false
		if cards_step == 0 and controller.last_outcome == CombatTypes.Outcome.VICTORY and controller.encounter_index >= 1:
			hud.cards_button.pressed.emit()
			settle_frames = 0
			return false
		if controller.stage_cleared or controller.last_outcome == CombatTypes.Outcome.DEFEAT:
			print("AUTOPLAY OK: %s after %d actions, reached battle %d/%d, rewards taken: %s, equipped: %s" % [
				hud.result_title.text, actions, max_encounter + 1, controller.stage.encounters.size(),
				str(rewards_taken), str(controller.collection.equipped_items(controller.princess.id).map(func(i): return i.id))])
			print("AUTOPLAY CARDS: played %d cards %s | crafted %s | deck %s | essences %s" % [cards_played.size(),
				str(cards_played), str(crafted), str(controller.collection.deck), str(controller.collection.materials)])
			var audio := root.get_node_or_null("Audio")
			if audio != null:
				for id in ["hit", "death", "card", "victory" if controller.last_outcome == CombatTypes.Outcome.VICTORY else "defeat"]:
					if not audio.history.has(id) and not _sfx_seen.has(id):
						_fail("battle sound '%s' never played" % id)
						return true
				print("AUTOPLAY AUDIO: music %s, sfx seen %s" % [audio.current_music, str(_sfx_seen.keys())])
			if cards_played.is_empty():
				_fail("no card was played during the whole stage")
				return true
			if p5_stage != "" and not _check_phase5():
				return true
			quit(0)
			return true
		hud.continue_button.pressed.emit()
		return false

	_track_phase5()
	var engine := controller.engine
	if controller.is_busy or engine.phase != CombatTypes.Phase.PLAYER_TURN:
		settle_frames = 0
		# Mid-action screenshot: catches popups / lunges.
		if actions == 1:
			_shot("battle%d_action" % (controller.encounter_index + 1))
		return false
	if not _settle():
		return false
	_shot("battle%d_turn%d" % [controller.encounter_index + 1, engine.round_number])

	# --- Phase 3: play cards through the real hand buttons first (free actions, cost mana)
	var play := policy.choose_card(engine)
	if not play.is_empty() and cards_this_turn < 6:
		var btn: Button = hud.card_buttons[play.index]
		if play.target >= 0:
			controller.select_target(play.target)
		var mana_before := engine.mana
		_press(btn, "card " + engine.cards[play.index].card.id)
		if engine.mana >= mana_before:
			_fail("playing a card did not spend mana")
			return true
		cards_played.append(engine.cards[play.index].card.id)
		cards_this_turn += 1
		settle_frames = 0
		return false
	cards_this_turn = 0

	var cmd := policy.decide(engine)
	if cmd.kind == PlayerCommand.Kind.DEFEND:
		_press(hud.defend_button, "Defend")
	else:
		var index := -1
		for i in engine.player.abilities.size():
			if engine.player.abilities[i].spec.id == cmd.ability_id:
				index = i
		if index < 0 or index >= hud.ability_buttons.size():
			printerr("AUTOPLAY FAIL: no button for ", cmd.ability_id)
			quit(1)
			return true
		if cmd.target_id >= 0:
			controller.select_target(cmd.target_id)
		_press(hud.ability_buttons[index], cmd.ability_id)
	actions += 1
	settle_frames = 0
	return false


var rewards_taken: Array[String] = []
var cards_played: Array[String] = []
var crafted: Array[String] = []
var cards_this_turn := 0
var cards_step := 0
var equipment_visited := false
var equip_step := 0


func _fail(msg: String) -> void:
	printerr("AUTOPLAY FAIL: " + msg)
	quit(1)


## Wait a few frames in a stable state so the screen is fully drawn.
func _settle(frames := 4) -> bool:
	settle_frames += 1
	return settle_frames >= frames


func _press(button: Button, what: String) -> void:
	if button.disabled or not button.visible:
		printerr("AUTOPLAY FAIL: button for %s is not clickable on the player's turn" % what)
		quit(1)
		return
	button.pressed.emit()


func _shot(name: String) -> void:
	if shot_dir == "" or shots_taken.has(name) or DisplayServer.get_name() == "headless":
		return
	shots_taken[name] = true
	var img := root.get_texture().get_image()
	img.save_png("%s/%s.png" % [shot_dir, name])


# ------------------------------------------------------------ Phase 5 checks
var _sfx_seen := {}
var p5_stage := ""
var p5_level := 1
var p5_companion := ""
var level_before := 1
var phases_seen := {}
var summons_seen := 0
var assists_seen := 0
var _seen_units := {}
var _last_round := -1


func _track_phase5() -> void:
	var audio := root.get_node_or_null("Audio")
	if audio != null:
		for id in audio.history:
			_sfx_seen[id] = true
	var engine := controller.engine
	if engine == null:
		return
	for e in engine.enemies:
		if e.id >= 1000 and not _seen_units.has(e.id) and not controller.is_busy:
			_seen_units[e.id] = true
			summons_seen += 1
			if controller._view(e) == null:
				_fail("summoned %s has no view on screen" % e.unit_name)
		for i in e.phases_done:
			if not phases_seen.has("%s#%d" % [e.unit_name, i]):
				phases_seen["%s#%d" % [e.unit_name, i]] = true
				_shot("boss_phase_%s_%d" % [e.definition_id, i])
	if engine.companion != null and engine.round_number != _last_round:
		_last_round = engine.round_number
		if engine.round_number % engine.assist_interval == 0:
			assists_seen += 1


func _check_phase5() -> bool:
	var gs := root.get_node_or_null("GameState")
	var lv: int = gs.castle.level("sword_princess")
	print("AUTOPLAY PHASE5: stage %s | companion %s | synergy %s | boss phases %s | summons %d | assist rounds %d | Lv %d -> %d | EXP last battle %d" % [
		controller.stage.id, p5_companion, controller.synergy.display_name if controller.synergy else "-",
		str(phases_seen.keys()), summons_seen, assists_seen, level_before, lv, controller.last_exp])
	if controller.stage.id != p5_stage:
		_fail("battle used %s instead of %s" % [controller.stage.id, p5_stage])
		return false
	if p5_companion != "" and controller.companion_unit == null:
		_fail("companion missing in battle")
		return false
	if controller.stage_cleared and phases_seen.is_empty():
		_fail("stage cleared but no boss phase triggered")
		return false
	var xp: int = gs.castle.exp_points("sword_princess")
	if lv <= level_before and xp <= 0 and controller.encounter_index > 0:
		_fail("no EXP gained after winning battles")
		return false
	return true
