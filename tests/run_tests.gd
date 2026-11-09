extends SceneTree
## Headless test runner (no plugins needed).
##   Godot_console.exe --headless --path . --script res://tests/run_tests.gd
## Runs every test_* in the suites below, then simulates the real stage data with loot.
## Set env SIM_RUNS=200 for a quicker simulation. Exit code 0 = all passed.

const SUITES := [
	preload("res://tests/test_combat.gd"),
	preload("res://tests/test_items.gd"),
	preload("res://tests/test_cards.gd"),
	preload("res://tests/test_castle.gd"),
	preload("res://tests/test_progression.gd"),
	preload("res://tests/test_release.gd"),
]


func _init() -> void:
	var passed := 0
	var failed := 0
	# A GDScript runtime error aborts the test function silently; the logger catches it.
	var catcher = load("res://tests/error_catcher.gd").new()
	OS.add_logger(catcher)
	for suite_script in SUITES:
		var suite = suite_script.new()
		for m in suite.get_method_list():
			var name: String = m.name
			if not name.begins_with("test_"):
				continue
			suite.failures.clear()
			var errors_before: int = catcher.script_errors
			suite.call(name)
			if catcher.script_errors > errors_before:
				suite.failures.append("script error: " + catcher.last_message)
			if suite.failures.is_empty():
				passed += 1
				print("PASS ", name)
			else:
				failed += 1
				print("FAIL ", name, " : ", "; ".join(suite.failures))

	if not _simulate_stage():
		failed += 1

	print("\n%d passed, %d failed" % [passed, failed])
	quit(0 if failed == 0 else 1)


## Simulates the real stage INCLUDING loot (reward choice after every win).
##  - First run: fresh collection (starting gear only), smart vs attack-only player.
##  - Progression: gear is kept between attempts (like the real game) -> attempts to first clear.
## Fails if the smart first-run win rate is outside 20%..85% (too hard / trivial).
func _simulate_stage() -> bool:
	var stage: StageDefinition = load("res://data/stage_01.tres")
	var princess: PrincessDefinition = load("res://data/princess_sword.tres")
	var config: BattleConfig = load("res://data/balance_config.tres")
	var loot: LootTable = load("res://data/loot_table.tres")
	if stage == null or princess == null or loot == null:
		print("FAIL simulate_stage : data missing (run tools/generate_data.gd)")
		return false
	var runs := 2000
	if OS.get_environment("SIM_RUNS") != "":
		runs = int(OS.get_environment("SIM_RUNS"))

	var smart_rate := 0.0
	for smart in [true, false]:
		var wins := 0
		var lost_at := []
		lost_at.resize(stage.encounters.size())
		lost_at.fill(0)
		for seed_value in range(1, runs + 1):
			var col := _fresh_collection(loot, princess)
			var lost_index := _play_run(stage, princess, config, loot, col, RandomSource.new(seed_value), smart)
			if lost_index < 0:
				wins += 1
			else:
				lost_at[lost_index] += 1
		var rate := float(wins) / runs
		if smart:
			smart_rate = rate
		print("SIM  %-11s first-run win %5.1f%%   lost at battle 1-%d: %s" % ["smart" if smart else "attack-only",
			rate * 100.0, stage.encounters.size(), str(lost_at)])

	# Progression: the collection is kept between attempts.
	var players := maxi(20, runs / 5)
	var attempts_total := 0
	var cleared_by := [0, 0, 0, 0, 0]
	for p in players:
		var col := _fresh_collection(loot, princess)
		var rng := RandomSource.new(10000 + p)
		for attempt in 10:
			if _play_run(stage, princess, config, loot, col, rng, true) < 0:
				attempts_total += attempt + 1
				if attempt < cleared_by.size():
					cleared_by[attempt] += 1
				break
			if attempt == 9:
				attempts_total += 10
	var cumulative := 0
	var parts: Array[String] = []
	for i in cleared_by.size():
		cumulative += cleared_by[i]
		parts.append("#%d %d%%" % [i + 1, roundi(100.0 * cumulative / players)])
	print("SIM  progression: avg attempts to first clear %.2f | cleared by attempt %s" % [
		float(attempts_total) / players, ", ".join(parts)])

	var ok := smart_rate > 0.2 and smart_rate < 0.85
	print(("PASS" if ok else "FAIL"), " simulate_stage (smart first-run win rate must be 20%..85%)")

	# Phase 4: every princess must be viable but challenging on her first run.
	var roster: PrincessRoster = load("res://data/princess_roster.tres")
	if roster != null:
		var p_runs := maxi(50, runs / 4)
		for p in roster.princesses:
			var cfg := config.with_mana_bonus(p.bonus_start_mana, p.bonus_max_mana)
			var wins := 0
			for seed_value in range(1, p_runs + 1):
				var col := _fresh_collection(loot, p)
				if _play_run(stage, p, cfg, loot, col, RandomSource.new(seed_value), true) < 0:
					wins += 1
			var rate := float(wins) / p_runs
			var p_ok := rate > 0.2 and rate < 0.9
			ok = ok and p_ok
			print("SIM  %-16s first-run win %5.1f%%  %s" % [p.id, rate * 100.0, "" if p_ok else "<- OUT OF RANGE (20%..90%)"])
	ok = _simulate_campaign(config, loot, roster, runs) and ok
	return ok


func _fresh_collection(loot: LootTable, princess: PrincessDefinition) -> Collection:
	var col := Collection.new()
	col.register(loot.items)
	col.register_cards(loot.card_library)
	col.ensure_starting_gear(princess)
	col.ensure_starting_cards(loot.card_library)
	return col


## Plays one full stage with the real rules (cards, mana, rewards, essence drops, crafting).
## Returns -1 on clear, else the encounter index where the princess fell.
func _play_run(stage: StageDefinition, princess: PrincessDefinition, config: BattleConfig, loot: LootTable,
		col: Collection, rng: RandomSource, smart: bool, camp: CastleProgress = null, companion: PrincessDefinition = null, synergy: Synergy = null) -> int:
	var policy := AutoBattlePolicy.new()
	var hp := -1
	var hp_s := stage.monster_hp_scale if OS.get_environment("SIM_HP") == "" else float(OS.get_environment("SIM_HP"))
	var atk_s := stage.monster_attack_scale if OS.get_environment("SIM_ATK") == "" else float(OS.get_environment("SIM_ATK"))
	for i in stage.encounters.size():
		var uid := 0
		var lv := camp.level(princess.id) if camp else 1
		var p := UnitFactory.create_princess(princess, uid, hp, col.equipped_items(princess.id), synergy.stats if synergy else null, lv)
		UnitFactory.apply_synergy(p, synergy)
		uid += 1
		var enemies: Array = []
		for m in stage.encounters[i].monsters:
			enemies.append(UnitFactory.create_monster(m, uid, hp_s, atk_s))
			uid += 1
		var use_cards := smart and OS.get_environment("SIM_NO_CARDS") == ""
		var b := BattleEngine.new(p, enemies, config, rng, null, col.deck_cards().filter(func(c): return c.usable_by(princess.id)) if use_cards else [])
		b.summon_factory = func(def: MonsterDefinition, id: int) -> CombatUnit: return UnitFactory.create_monster(def, id, hp_s, atk_s)
		if companion != null and companion.assist != null:
			b.companion = UnitFactory.create_companion(companion, 900, camp.level(companion.id) if camp else 1, col.equipped_items(companion.id))
			b.companion_assist = companion.assist
			b.assist_interval = companion.assist_interval
		b.start()
		var guard := 0
		while b.phase != CombatTypes.Phase.ENDED:
			guard += 1
			if guard > 400:
				push_error("simulation stuck")
				return i
			if b.phase == CombatTypes.Phase.PLAYER_TURN:
				if smart:
					var plays := 0
					var play := policy.choose_card(b)
					while not play.is_empty() and plays < 6 and b.phase == CombatTypes.Phase.PLAYER_TURN:
						b.play_card(play.index, play.target)
						plays += 1
						play = policy.choose_card(b)
					if b.phase != CombatTypes.Phase.PLAYER_TURN:
						continue
				var target := b.first_targetable_enemy()
				var cmd := policy.decide(b) if smart else (PlayerCommand.use_ability("attack", target.id) if target else PlayerCommand.defend())
				b.execute_player_command(cmd)
			else:
				b.run_enemy_turn()
		if b.outcome == CombatTypes.Outcome.DEFEAT:
			return i
		if camp != null:
			var xp := 0
			for e in b.enemies:
				if not e.is_alive():
					xp += e.exp_reward
			camp.add_exp(princess.id, xp)
			if companion != null:
				camp.add_exp(companion.id, roundi(xp * 0.5))
		# Essence drops from every monster in the encounter.
		for m in stage.encounters[i].monsters:
			for d in m.drops:
				col.add_essence(d.key(), d.roll(rng))
		# Reward choice — same rules as the real game.
		var options := loot.roll_options(stage.encounters[i].reward_tier, rng, col.owned, i < stage.encounters.size() - 1)
		var equipped := {}
		for slot in ItemTypes.Slot.values():
			var it := col.equipped_in(princess.id, slot)
			if it != null:
				equipped[slot] = it
		var pick: LootTable.RewardOption = options[policy.choose_reward(options, equipped, p.current_hp, p.stats.max_hp, col.cards)]
		var cur_hp := p.current_hp
		match pick.kind:
			LootTable.RewardOption.Kind.EQUIPMENT:
				col.add(pick.item)
				col.equip(princess.id, pick.item.id)
			LootTable.RewardOption.Kind.CARD:
				col.add_card(pick.card)
			_:
				cur_hp = mini(p.stats.max_hp, cur_hp + roundi(p.stats.max_hp * pick.heal_fraction))
		if smart:
			AutoBattlePolicy.manage_cards(col, loot.card_library)
		hp = cur_hp + roundi(p.stats.max_hp * stage.heal_between_battles) # clamped by the next battle
	return -1


## Phase 5: plays the whole campaign like a player: stages in order, gear/cards/levels kept,
## a companion once one is unlocked (with synergy). Reports attempts and level per stage.
## Fails if a stage is (almost) never cleared, or later stages are trivial on the first try.
func _simulate_campaign(config: BattleConfig, loot: LootTable, roster: PrincessRoster, runs: int) -> bool:
	if roster == null or roster.stages.is_empty():
		return true
	var players := maxi(20, runs / 10)
	var max_attempts := 15
	var sword := roster.find("sword_princess")
	var prefer := ["light_princess", "magic_princess", "dragon_princess", "shadow_princess"]
	var n := roster.stages.size()
	var cleared := []
	var attempts := []
	var first_try := []
	var level_at := []
	for arr in [cleared, attempts, first_try, level_at]:
		arr.resize(n)
		arr.fill(0)
	for pl in players:
		var col := _fresh_collection(loot, sword)
		var camp := CastleProgress.new()
		var rng := RandomSource.new(50000 + pl)
		for si in n:
			var stage: StageDefinition = roster.stages[si]
			var comp: PrincessDefinition = null
			for id in prefer:
				var c := roster.find(id)
				if c != null and camp.is_unlocked(c):
					comp = c
					break
			if comp != null:
				col.ensure_starting_gear(comp)
			var syn := roster.synergy_for(sword.id, comp.id) if comp else null
			var cfg := config.with_mana_bonus(sword.bonus_start_mana + (syn.start_mana if syn else 0), sword.bonus_max_mana)
			var won := false
			for a in max_attempts:
				if _play_run(stage, sword, cfg, loot, col, rng, true, camp, comp, syn) < 0:
					won = true
					cleared[si] += 1
					attempts[si] += a + 1
					if a == 0:
						first_try[si] += 1
					level_at[si] += camp.level(sword.id)
					camp.mark_stage_cleared(stage.id, roster)
					break
			if not won:
				break
	var ok := true
	for si in n:
		var s: StageDefinition = roster.stages[si]
		var c: int = cleared[si]
		var rate := float(c) / players
		var first := float(first_try[si]) / maxi(1, c)
		var s_ok := rate >= 0.7 and (si == 0 or first < 0.85)
		ok = ok and s_ok
		print("SIM  campaign %-15s cleared %3d%% | avg attempts %.1f | first-try %3d%% | Lv at clear %.1f (rec %d) %s" % [
			s.display_name, roundi(rate * 100), float(attempts[si]) / maxi(1, c), roundi(first * 100),
			float(level_at[si]) / maxi(1, c), s.recommended_level, "" if s_ok else "<- OUT OF RANGE"])
	print(("PASS" if ok else "FAIL"), " simulate_campaign (every stage cleared by 70 percent within %d attempts, later stages not trivial)" % max_attempts)
	return ok
