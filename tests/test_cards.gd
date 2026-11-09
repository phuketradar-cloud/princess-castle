extends RefCounted
## Phase 3 tests: card play & mana, new statuses, boss control rules, crafting, fusion, deck, save.

const ScriptedRandom = preload("res://tests/scripted_random.gd")
const T = CombatTypes.Target
const S = CombatTypes.Status
const EV = BattleEvent.Type
const Phase = CombatTypes.Phase

var failures: Array[String] = []


func check(cond: bool, msg: String) -> void:
	if not cond:
		failures.append(msg)

func eq(actual, expected, msg: String) -> void:
	if actual != expected:
		failures.append("%s (expected %s, got %s)" % [msg, str(expected), str(actual)])

func cfg(start_mana := 6) -> BattleConfig:
	var c := BattleConfig.new()
	c.damage_variance = 0.0
	c.luck_to_crit = 0.0
	c.defend_heal_fraction = 0.0
	c.start_mana = start_mana
	return c

func player(hp := 100, atk := 20) -> CombatUnit:
	return CombatUnit.new(0, "p", "Princess", CombatTypes.Team.PLAYER, StatBlock.make(hp, atk, 0),
		[AbilitySpec.make("attack", "Attack", T.SINGLE_OPPONENT, 1.0)])

func enemy(id: int, hp := 100, atk := 10, boss := false, extra: Array = []) -> CombatUnit:
	var abilities: Array = extra.duplicate()
	abilities.append(AbilitySpec.make("hit", "Hit", T.SINGLE_OPPONENT, 1.0))
	return CombatUnit.new(id, "e", "E%d" % id, CombatTypes.Team.ENEMY, StatBlock.make(hp, atk, 0), abilities, boss)

func card(id: String, cost: int, spec: AbilitySpec, rarity := 0) -> CardDefinition:
	var c := CardDefinition.new()
	c.id = id
	c.display_name = id
	c.mana_cost = cost
	c.effect = spec
	c.rarity = rarity
	return c

func control_card(id: String, status: int, turns: int, target := T.SINGLE_OPPONENT, dmg := 0.0) -> CardDefinition:
	return card(id, 1, AbilitySpec.make(id, id, target, dmg).with_status(status, turns, 0.0))

func battle(p: CombatUnit, enemies: Array, deck: Array, mana := 6) -> BattleEngine:
	var b := BattleEngine.new(p, enemies, cfg(mana), ScriptedRandom.new(), null, deck)
	b.start()
	return b

func count(events: Array[BattleEvent], type: int, filter := Callable()) -> int:
	var n := 0
	for e in events:
		if e.type == type and (not filter.is_valid() or filter.call(e)):
			n += 1
	return n


# ------------------------------------------------------------ mana & card play

func test_card_costs_mana_and_keeps_turn() -> void:
	var e := enemy(1, 200)
	var b := battle(player(), [e], [card("fb", 2, AbilitySpec.make("fb", "fb", T.SINGLE_OPPONENT, 2.0))], 3)
	eq(b.mana, 3, "start mana")
	var ev := b.play_card(0, e.id)
	eq(b.mana, 1, "spent 2")
	eq(e.current_hp, 160, "40 damage")
	eq(b.phase, Phase.PLAYER_TURN, "still the player's turn")
	check(ev.any(func(x): return x.type == EV.ACTION_STARTED and x.card != null), "card event")
	check(b.validate_card(0, e.id) != "", "once per battle")

func test_not_enough_mana() -> void:
	var b := battle(player(), [enemy(1)], [card("big", 4, AbilitySpec.make("b", "b", T.ALL_OPPONENTS, 1.0))], 1)
	check(b.validate_card(0) != "", "rejected")
	eq(b.play_card(0).size(), 0, "nothing happens")
	eq(b.mana, 1, "mana untouched")

func test_mana_regenerates_and_caps() -> void:
	var c := cfg(1)
	c.max_mana = 3
	var b := BattleEngine.new(player(), [enemy(1, 1000, 1)], c, ScriptedRandom.new())
	b.start()
	eq(b.mana, 1, "round 1")
	for r in 4:
		b.execute_player_command(PlayerCommand.defend())
		b.run_enemy_turn()
	eq(b.mana, 3, "capped at max")

func test_card_can_win_the_battle() -> void:
	var e := enemy(1, 10)
	var b := battle(player(), [e], [card("fb", 1, AbilitySpec.make("fb", "fb", T.SINGLE_OPPONENT, 1.0))])
	b.play_card(0, e.id)
	eq(b.outcome, CombatTypes.Outcome.VICTORY, "victory from a card")


# ------------------------------------------------------------ statuses

func test_ice_prison_freezes_for_turns() -> void:
	var e := enemy(1, 1000, 30)
	var p := player()
	var b := battle(p, [e], [control_card("ice", S.FREEZE, 4)])
	b.play_card(0, e.id)
	for r in 4:
		b.execute_player_command(PlayerCommand.defend())
		var ev := b.run_enemy_turn()
		eq(count(ev, EV.TURN_SKIPPED), 1, "frozen turn %d" % (r + 1))
	eq(p.current_hp, 100, "no damage while frozen")
	check(not e.has_status(S.FREEZE), "thawed after 4 turns")

func test_boss_control_halved_and_banish_immune() -> void:
	var boss := enemy(1, 1000, 10, true)
	var b := battle(player(), [boss], [control_card("ice", S.FREEZE, 4), control_card("ban", S.BANISH, 2)])
	b.play_card(0, boss.id)
	eq(boss.get_status(S.FREEZE).remaining_turns, 2, "4 -> 2 on bosses")
	var ev := b.play_card(1, boss.id)
	check(not boss.has_status(S.BANISH), "boss immune to banish")
	eq(count(ev, EV.STATUS_RESISTED), 1, "resisted event")

func test_banish_removes_from_field_then_returns() -> void:
	var e1 := enemy(1, 100, 10)
	var e2 := enemy(2, 100, 10)
	var p := player()
	var b := battle(p, [e1, e2], [control_card("ban", S.BANISH, 2)])
	b.play_card(0, e1.id)
	check(not e1.is_targetable(), "untargetable")
	check(b.validate_command(PlayerCommand.use_ability("attack", e1.id)) != "", "cannot target banished")
	b.execute_player_command(PlayerCommand.use_ability("attack", -1))
	eq(e2.current_hp, 80, "auto-target skips the banished one")
	b.run_enemy_turn()
	eq(p.current_hp, 90, "only e2 attacked")
	b.execute_player_command(PlayerCommand.defend())
	b.run_enemy_turn()
	check(e1.is_targetable(), "back after 2 turns")
	eq(b.phase, Phase.PLAYER_TURN, "battle continues")

func test_banished_enemy_prevents_premature_victory() -> void:
	var e1 := enemy(1, 100, 10)
	var e2 := enemy(2, 5, 10)
	var b := battle(player(), [e1, e2], [control_card("ban", S.BANISH, 2)])
	b.play_card(0, e1.id)
	b.execute_player_command(PlayerCommand.use_ability("attack", e2.id))
	check(not e2.is_alive(), "e2 dead")
	eq(b.outcome, CombatTypes.Outcome.NONE, "banished enemy still alive -> no victory yet")

func test_sleep_wakes_on_damage() -> void:
	var e := enemy(1, 1000, 30)
	var b := battle(player(), [e], [control_card("zz", S.SLEEP, 3)])
	b.play_card(0, e.id)
	check(e.has_status(S.SLEEP), "asleep")
	b.execute_player_command(PlayerCommand.use_ability("attack", e.id))
	check(not e.has_status(S.SLEEP), "woke up when hit")

func test_silence_forces_basic_attack() -> void:
	var heavy := AbilitySpec.make("heavy", "Heavy", T.SINGLE_OPPONENT, 5.0)
	var e := enemy(1, 1000, 10, false, [heavy])
	var p := player()
	var b := battle(p, [e], [control_card("sil", S.SILENCE, 2)])
	eq(b.get_intent(e).spec.id, "heavy", "plans heavy")
	b.play_card(0, e.id)
	eq(b.get_intent(e).spec.id, "hit", "intent switched to basic")
	b.execute_player_command(PlayerCommand.defend())
	b.run_enemy_turn()
	eq(p.current_hp, 95, "only the basic hit (halved by defend)")

func test_holy_shield_absorbs() -> void:
	var p := player(100, 20)
	var e := enemy(1, 1000, 30)
	var b := battle(p, [e], [card("sh", 1, AbilitySpec.make("sh", "sh", T.SELF, 0.0).with_status(S.SHIELD, 3, 1.0))])
	b.play_card(0)
	eq(int(p.get_status(S.SHIELD).potency), 20, "shield = 1.0 x ATK")
	b.execute_player_command(PlayerCommand.use_ability("attack", e.id))
	var ev := b.run_enemy_turn()
	eq(p.current_hp, 90, "30 - 20 absorbed")
	check(ev.any(func(x): return x.type == EV.DAMAGE and x.absorbed == 20), "absorbed reported")
	check(not p.has_status(S.SHIELD), "shield used up")

func test_lucky_day_crit() -> void:
	var p := player(100, 20)
	p.add_status(S.LUCKY, 2, 0.5)
	var hit := DamageCalculator.compute_hit(p, enemy(1), 1.0, cfg(), ScriptedRandom.new([0.5, 0.3]))
	check(hit.crit, "0.3 < 50% lucky crit")

func test_execute_kills_low_hp_and_hurts_boss() -> void:
	var spec := AbilitySpec.make("ex", "ex", T.SINGLE_OPPONENT, 1.0)
	spec.execute_threshold = 0.35
	spec.execute_boss_multiplier = 3.0
	var e := enemy(1, 100)
	e.apply_damage(70)
	var b := battle(player(100, 20), [e, enemy(2)], [card("ex", 1, spec)])
	var ev := b.play_card(0, e.id)
	check(not e.is_alive(), "executed")
	check(ev.any(func(x): return x.executed), "executed flag")
	var boss := enemy(3, 100, 10, true)
	boss.apply_damage(70)
	var b2 := battle(player(100, 20), [boss], [card("ex", 1, spec)])
	b2.play_card(0, boss.id)
	eq(boss.current_hp, 0, "boss took 20 x 3 = 60 > 30 left")

func test_burn_ticks() -> void:
	var e := enemy(1, 100, 1)
	var b := battle(player(), [e], [card("fb", 1, AbilitySpec.make("fb", "fb", T.SINGLE_OPPONENT, 0.01).with_status(S.BURN, 2, 0.1))])
	b.play_card(0, e.id)
	b.execute_player_command(PlayerCommand.defend())
	var ev := b.run_enemy_turn()
	eq(count(ev, EV.DAMAGE, func(x): return x.from_status and x.status == S.BURN), 1, "burn tick")

func test_time_stop_stuns_all() -> void:
	var e1 := enemy(1, 100, 10)
	var e2 := enemy(2, 100, 10)
	var p := player()
	var b := battle(p, [e1, e2], [control_card("ts", S.STUN, 1, T.ALL_OPPONENTS)])
	b.play_card(0)
	b.execute_player_command(PlayerCommand.defend())
	var ev := b.run_enemy_turn()
	eq(count(ev, EV.TURN_SKIPPED), 2, "both stopped")
	eq(p.current_hp, 100, "no damage")


# ------------------------------------------------------------ collection: craft, fuse, deck, save

func _lib() -> CardLibrary:
	var lib := CardLibrary.new()
	var fb := card("fireball", 1, AbilitySpec.make("fb", "fb", T.SINGLE_OPPONENT, 1.0))
	var blast := card("fire_blast", 2, AbilitySpec.make("bl", "bl", T.SINGLE_OPPONENT, 3.0), 2)
	blast.drop_weight = 0.0
	lib.cards = [fb, blast]
	var r := CraftRecipe.new()
	r.result = fb
	r.cost = {"fire": 3}
	lib.craft_recipes = [r]
	var f := FusionRecipe.new()
	f.inputs = [fb, fb, fb]
	f.result = blast
	lib.fusion_recipes = [f]
	lib.max_deck_size = 2
	return lib

func test_crafting_spends_essence() -> void:
	var lib := _lib()
	var col := Collection.new()
	col.register_cards(lib)
	col.add_essence("fire", 2)
	check(not col.can_craft(lib.craft_recipes[0]), "2 < 3")
	eq(col.craft(lib.craft_recipes[0]), null, "craft refused")
	col.add_essence("fire", 4)
	eq(col.craft(lib.craft_recipes[0]).id, "fireball", "crafted")
	eq(col.essence("fire"), 3, "6 - 3")
	eq(col.card_count("fireball"), 1, "in collection")
	check(col.deck.has("fireball"), "new card joins the deck")

func test_fusion_consumes_cards() -> void:
	var lib := _lib()
	var col := Collection.new()
	col.register_cards(lib)
	col.add_card(lib.cards[0], 2)
	check(not col.can_fuse(lib.fusion_recipes[0]), "needs 3")
	col.add_card(lib.cards[0])
	eq(col.fuse(lib.fusion_recipes[0]).id, "fire_blast", "fused")
	eq(col.card_count("fireball"), 0, "inputs consumed")
	check(not col.deck.has("fireball"), "removed from deck when none left")
	check(col.deck.has("fire_blast"), "result added to deck")

func test_deck_limit_and_rules() -> void:
	var lib := _lib()
	var col := Collection.new()
	col.register_cards(lib)
	check(col.add_to_deck("fireball") != "", "can't add unowned")
	col.add_card(lib.cards[0])
	check(col.add_to_deck("fireball") != "", "no duplicates")
	var extra := card("x", 1, AbilitySpec.make("x", "x", T.SELF, 0.0))
	col.add_card(lib.cards[1])
	col.add_card(extra)
	eq(col.deck.size(), 2, "max deck size respected")
	check(col.add_to_deck("x") != "", "deck full")
	col.remove_from_deck("fireball")
	eq(col.add_to_deck("x"), "", "room again")

func test_fusion_only_cards_never_drop() -> void:
	var lib := _lib()
	var rng := RandomSource.new(5)
	for i in 300:
		var got := lib.roll_card(ItemTypes.Tier.NORMAL, rng)
		eq(got.id if got != null else "null", "fireball", "only droppable card")
		if not failures.is_empty():
			return

func test_essence_drop_range() -> void:
	var d := EssenceDrop.make(CardTypes.Element.FIRE, 1.0, 2, 4)
	var rng := RandomSource.new(9)
	var seen := {}
	for i in 300:
		var n := d.roll(rng)
		check(n >= 2 and n <= 4, "in range")
		seen[n] = true
	eq(seen.size(), 3, "2, 3 and 4 all occur")
	eq(EssenceDrop.make(0, 0.0, 1, 1).roll(rng), 0, "chance 0 never drops")

func test_save_v2_roundtrip_and_v1_compat() -> void:
	var lib := _lib()
	var col := Collection.new()
	col.register_cards(lib)
	col.add_card(lib.cards[0], 2)
	col.add_essence("ice", 7)
	col.cards_initialized = true
	var data = JSON.parse_string(JSON.stringify(col.to_dict()))
	var col2 := Collection.new()
	col2.register_cards(lib)
	col2.from_dict(data)
	eq(col2.card_count("fireball"), 2, "cards restored")
	eq(col2.essence("ice"), 7, "essence restored")
	eq(col2.deck, col.deck, "deck restored")
	check(col2.cards_initialized, "flag restored")
	# A Phase 2 save has no card fields: defaults, and starting cards get granted.
	var col3 := Collection.new()
	col3.register_cards(lib)
	col3.from_dict({"owned": [], "equipped": {}})
	eq(col3.cards.size(), 0, "no cards in old save")
	check(not col3.cards_initialized, "starter cards still pending")


# ------------------------------------------------------------ real data

func test_real_card_data_is_valid() -> void:
	var lib: CardLibrary = load("res://data/card_library.tres")
	if lib == null:
		failures.append("card_library.tres missing")
		return
	check(lib.cards.size() >= 13, "all spec cards present")
	for c in lib.cards:
		check(c.effect != null, "%s has effect" % c.id)
		check(c.icon != null, "%s has icon" % c.id)
		check(c.mana_cost >= 1 and c.mana_cost <= 6, "%s cost in range" % c.id)
	for r in lib.craft_recipes:
		check(r.result != null and not r.cost.is_empty(), "craft recipe valid")
		for key in r.cost:
			check(CardTypes.element_from_key(key) >= 0, "essence key %s" % key)
	for f in lib.fusion_recipes:
		check(f.result != null and f.inputs.size() >= 2, "fusion recipe valid")
	var spec_ids := ["fireball", "meteor", "dragon_breath", "ice_prison", "banish", "sleep", "silence",
		"heal", "holy_shield", "lucky_day", "time_stop", "shadow_execution", "dragons_wrath", "fire_blast", "dimensional_prison"]
	for card_id in spec_ids:
		check(lib.find(card_id) != null, "card %s exists" % card_id)
	var loot: LootTable = load("res://data/loot_table.tres")
	check(loot.card_library != null and loot.option_kinds.has("card"), "card reward wired")
