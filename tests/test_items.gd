extends RefCounted
## Tests for Phase 2: equipment stats, special effects, loot rolls, collection & save format.

const ScriptedRandom = preload("res://tests/scripted_random.gd")
const T = CombatTypes.Target
const EV = BattleEvent.Type
const Slot = ItemTypes.Slot
const Rarity = ItemTypes.Rarity

var failures: Array[String] = []


func check(cond: bool, msg: String) -> void:
	if not cond:
		failures.append(msg)

func eq(actual, expected, msg: String) -> void:
	if actual != expected:
		failures.append("%s (expected %s, got %s)" % [msg, str(expected), str(actual)])

func item(id: String, slot: int, rarity: int, stats := [0, 0, 0, 0.0, 0.0, 0.0], special := 0, value := 0.0) -> EquipmentDefinition:
	var e := EquipmentDefinition.new()
	e.id = id
	e.display_name = id
	e.slot = slot
	e.rarity = rarity
	e.stats = StatBlock.make(stats[0], stats[1], stats[2], stats[3], stats[4], stats[5])
	e.special = special
	e.special_value = value
	return e

func princess_def() -> PrincessDefinition:
	var p := PrincessDefinition.new()
	p.id = "test_princess"
	p.base_stats = StatBlock.make(100, 20, 0)
	p.abilities = [AbilitySpec.make("attack", "Attack", T.SINGLE_OPPONENT, 1.0)]
	return p

func flat_config() -> BattleConfig:
	var c := BattleConfig.new()
	c.damage_variance = 0.0
	c.luck_to_crit = 0.0
	c.defend_heal_fraction = 0.0
	return c

func enemy(id: int, hp := 100, atk := 10) -> CombatUnit:
	return CombatUnit.new(id, "e", "E%d" % id, CombatTypes.Team.ENEMY, StatBlock.make(hp, atk, 0),
		[AbilitySpec.make("hit", "Hit", T.SINGLE_OPPONENT, 1.0)])


# ------------------------------------------------------------ stats

func test_equipment_adds_stats() -> void:
	var gear := [item("s", Slot.WEAPON, Rarity.RARE, [0, 6, 0, 0.05, 0.0, 0.0]),
		item("a", Slot.ARMOR, Rarity.COMMON, [20, 0, 4, 0.0, 0.0, 0.0])]
	var u := UnitFactory.create_princess(princess_def(), 0, -1, gear)
	eq(u.stats.max_hp, 120, "hp")
	eq(u.stats.attack, 26, "atk")
	eq(u.stats.defense, 4, "def")
	check(is_equal_approx(u.stats.critical, 0.05), "crit")
	eq(princess_def().base_stats.attack, 20, "base stats untouched")

func test_carried_hp_is_clamped_to_new_max() -> void:
	var u := UnitFactory.create_princess(princess_def(), 0, 500, [])
	eq(u.current_hp, 100, "clamped")

func test_item_stat_lines() -> void:
	var lines := item("x", Slot.WING, Rarity.EPIC, [10, 0, 0, 0.0, 0.09, 0.0]).stat_lines()
	check(lines.has("HP +10") and lines.has("EVA +9%"), "lines: %s" % str(lines))


# ------------------------------------------------------------ special effects

func test_lifesteal_heals_attacker() -> void:
	var p := UnitFactory.create_princess(princess_def(), 0, 50, [item("v", Slot.ACCESSORY, Rarity.EPIC, [0, 0, 0, 0.0, 0.0, 0.0], ItemTypes.Special.LIFESTEAL, 0.5)])
	var e := enemy(1, 200)
	var b := BattleEngine.new(p, [e], flat_config(), ScriptedRandom.new())
	b.start()
	var ev := b.execute_player_command(PlayerCommand.use_ability("attack", e.id))
	eq(p.current_hp, 60, "healed half of 20")
	check(ev.any(func(x): return x.type == EV.HEAL and x.target == p), "heal event")

func test_thorns_reflects_damage() -> void:
	var p := UnitFactory.create_princess(princess_def(), 0, -1, [item("t", Slot.ARMOR, Rarity.EPIC, [0, 0, 0, 0.0, 0.0, 0.0], ItemTypes.Special.THORNS, 0.5)])
	var e := enemy(1, 200, 20)
	var b := BattleEngine.new(p, [e], flat_config(), ScriptedRandom.new())
	b.start()
	b.execute_player_command(PlayerCommand.defend())
	var ev := b.run_enemy_turn()
	eq(p.current_hp, 90, "princess took 10 (defending)")
	eq(e.current_hp, 195, "enemy took 5 back")
	check(ev.any(func(x): return x.type == EV.DAMAGE and x.reflected), "reflected event")

func test_thorns_can_kill_attacker() -> void:
	var p := UnitFactory.create_princess(princess_def(), 0, -1, [item("t", Slot.ARMOR, Rarity.EPIC, [0, 0, 0, 0.0, 0.0, 0.0], ItemTypes.Special.THORNS, 1.0)])
	var e := enemy(1, 5, 20)
	var b := BattleEngine.new(p, [e], flat_config(), ScriptedRandom.new())
	b.start()
	b.execute_player_command(PlayerCommand.defend())
	b.run_enemy_turn()
	check(not e.is_alive(), "enemy died to thorns")
	eq(b.outcome, CombatTypes.Outcome.VICTORY, "victory by thorns")

func test_crit_power_increases_crit_damage() -> void:
	var gear := [item("d", Slot.WEAPON, Rarity.LEGENDARY, [0, 0, 0, 0.5, 0.0, 0.0], ItemTypes.Special.CRIT_POWER, 0.5)]
	var p := UnitFactory.create_princess(princess_def(), 0, -1, gear)
	var hit := DamageCalculator.compute_hit(p, enemy(1), 1.0, flat_config(), ScriptedRandom.new([0.5, 0.0]))
	check(hit.crit, "crit")
	eq(hit.damage, 40, "20 * (1.5 + 0.5)")

func test_poison_edge_applies_poison() -> void:
	var p := UnitFactory.create_princess(princess_def(), 0, -1, [item("w", Slot.HEADGEAR, Rarity.EPIC, [0, 0, 0, 0.0, 0.0, 0.0], ItemTypes.Special.POISON_EDGE, 1.0)])
	var e := enemy(1, 200)
	var b := BattleEngine.new(p, [e], flat_config(), ScriptedRandom.new())
	b.start()
	b.execute_player_command(PlayerCommand.use_ability("attack", e.id))
	check(e.has_status(CombatTypes.Status.POISON), "poisoned")


# ------------------------------------------------------------ loot

func _loot() -> LootTable:
	var lt := LootTable.new()
	var list: Array[EquipmentDefinition] = []
	for r in 5:
		for i in 3:
			list.append(item("r%d_%d" % [r, i], i % 5, r))
	lt.items = list
	return lt

func test_reward_options_shape() -> void:
	var lt := _loot()
	lt.option_kinds = PackedStringArray(["equipment", "equipment", "restore"])
	var opts := lt.roll_options(ItemTypes.Tier.NORMAL, RandomSource.new(1), [])
	eq(opts.size(), 3, "3 options")
	eq(opts[0].kind, LootTable.RewardOption.Kind.EQUIPMENT, "first is equipment")
	eq(opts[1].kind, LootTable.RewardOption.Kind.EQUIPMENT, "second is equipment")
	eq(opts[2].kind, LootTable.RewardOption.Kind.RESTORE, "third is restore when configured")
	check(opts[0].item.id != opts[1].item.id, "no duplicate items in one roll")

func test_owned_items_are_skipped() -> void:
	var lt := _loot()
	var owned := []
	for it in lt.items:
		if it.id != "r0_2":
			owned.append(it.id)
	var got := lt.roll_item(ItemTypes.Tier.NORMAL, RandomSource.new(3), owned)
	eq(got.id, "r0_2", "only unowned item")
	eq(lt.roll_item(ItemTypes.Tier.NORMAL, RandomSource.new(3), owned + ["r0_2"]), null, "nothing left")

func test_rarity_weights_respected() -> void:
	var lt := _loot()
	var rng := RandomSource.new(42)
	var counts := [0, 0, 0, 0, 0]
	for i in 5000:
		counts[lt.roll_rarity(ItemTypes.Tier.NORMAL, rng)] += 1
	eq(counts[4], 0, "no mythic from normal battles")
	check(counts[0] > counts[1] and counts[1] > counts[2], "common > rare > epic: %s" % str(counts))
	var boss := [0, 0, 0, 0, 0]
	for i in 5000:
		boss[lt.roll_rarity(ItemTypes.Tier.BOSS, rng)] += 1
	eq(boss[0], 0, "no common from boss")
	check(boss[4] > 0, "boss can drop mythic")


# ------------------------------------------------------------ collection & save

func test_equip_replaces_slot() -> void:
	var col := Collection.new()
	var a := item("a", Slot.WEAPON, Rarity.COMMON)
	var b := item("b", Slot.WEAPON, Rarity.RARE)
	col.add(a)
	col.add(b)
	eq(col.equip("p", "a"), null, "nothing replaced")
	eq(col.equip("p", "b"), a, "a replaced")
	eq(col.equipped_in("p", Slot.WEAPON), b, "b equipped")
	check(col.owns("a"), "a still owned (in bag)")
	col.unequip("p", Slot.WEAPON)
	eq(col.equipped_items("p").size(), 0, "unequipped")

func test_cannot_equip_unowned() -> void:
	var col := Collection.new()
	col.register([item("x", Slot.WING, Rarity.EPIC)])
	eq(col.equip("p", "x"), null, "not owned")
	eq(col.equipped_items("p").size(), 0, "still empty")

func test_starting_gear_given_once() -> void:
	var col := Collection.new()
	var def := princess_def()
	def.starting_equipment = [item("start", Slot.WEAPON, Rarity.COMMON)]
	col.ensure_starting_gear(def)
	col.unequip(def.id, Slot.WEAPON)
	col.ensure_starting_gear(def)
	eq(col.equipped_items(def.id).size(), 0, "not re-equipped after the player removed it")

func test_save_roundtrip_and_unknown_items() -> void:
	var col := Collection.new()
	var a := item("a", Slot.WEAPON, Rarity.COMMON)
	var h := item("h", Slot.HEADGEAR, Rarity.EPIC)
	col.add(a)
	col.add(h)
	col.equip("p", "a")
	col.equip("p", "h")
	var data = JSON.parse_string(JSON.stringify(col.to_dict())) # through real JSON
	data["owned"].append("removed_item")
	data["future_field"] = 123
	var col2 := Collection.new()
	col2.register([a, h])
	col2.from_dict(data)
	eq(col2.owned.size(), 2, "unknown item dropped")
	eq(col2.equipped_in("p", Slot.WEAPON), a, "weapon restored")
	eq(col2.equipped_in("p", Slot.HEADGEAR), h, "headgear restored")


# ------------------------------------------------------------ real data sanity

func test_real_item_data_is_valid() -> void:
	var lt: LootTable = load("res://data/loot_table.tres")
	if lt == null:
		failures.append("loot_table.tres missing")
		return
	var per_slot := [0, 0, 0, 0, 0]
	var ids := {}
	for it in lt.items:
		check(it != null and it.id != "", "item has id")
		check(not ids.has(it.id), "unique id %s" % it.id)
		ids[it.id] = true
		check(it.texture != null, "%s has art" % it.id)
		per_slot[it.slot] += 1
	for s in 5:
		check(per_slot[s] >= 3, "slot %s has items" % ItemTypes.SLOT_NAMES_EN[s])
	# Every princess draws weapon, headgear and wings. Placeholder-art princesses draw all 5
	# slots; HD-art ones (art_scale != 1) may skip armor / accessory (their outfit is armor).
	var roster: PrincessRoster = load("res://data/princess_roster.tres")
	for princess in roster.princesses:
		var must: Array = [ItemTypes.Slot.WEAPON, ItemTypes.Slot.HEADGEAR, ItemTypes.Slot.WING] if princess.art_scale != 1.0 else ItemTypes.Slot.values()
		for s in must:
			check(princess.slot_anchors.has(s), "%s has anchor for slot %d" % [princess.id, s])


func test_game_state_writes_and_reads_json_file() -> void:
	var path := OS.get_temp_dir().path_join("pc_test_save_%d.json" % Time.get_ticks_usec())
	var gs = load("res://scripts/core/game_state.gd").new()
	gs.save_path = path
	var a := item("a", Slot.WEAPON, Rarity.COMMON)
	gs.collection.add(a)
	gs.collection.equip("p", "a")
	gs.save_game()
	check(FileAccess.file_exists(path), "save file written")
	var h := item("h", Slot.HEADGEAR, Rarity.RARE)
	gs.collection.add(h)
	gs.collection.equip("p", "h")
	gs.save_game() # second save must overwrite the first (rename over an existing file)
	var gs2 = load("res://scripts/core/game_state.gd").new()
	gs2.save_path = path
	gs2.collection.register([a, h])
	gs2.load_game()
	eq(gs2.collection.equipped_in("p", Slot.WEAPON), a, "loaded from disk")
	eq(gs2.collection.equipped_in("p", Slot.HEADGEAR), h, "second save persisted")
	# Corrupt file -> start fresh without crashing, keep a .bak copy
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string("{not json")
	f.close()
	var gs3 = load("res://scripts/core/game_state.gd").new()
	gs3.save_path = path
	gs3.load_game()
	eq(gs3.collection.owned.size(), 0, "corrupt save ignored")
	check(FileAccess.file_exists(path + ".bak"), "backup kept")
	DirAccess.remove_absolute(path)
	DirAccess.remove_absolute(path + ".bak")
	gs.free()
	gs2.free()
	gs3.free()
