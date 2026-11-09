extends RefCounted
## Phase 5 tests: boss phases (enrage / cleanse / shield / heal / summons), companion assist,
## synergy, level growth + EXP, unlock by stage, stage chain, save v4, and the real game data.

const ScriptedRandom = preload("res://tests/scripted_random.gd")
const T = CombatTypes.Target
const S = CombatTypes.Status
const EV = BattleEvent.Type

var failures: Array[String] = []


func check(cond: bool, msg: String) -> void:
	if not cond:
		failures.append(msg)

func eq(actual, expected, msg: String) -> void:
	if actual != expected:
		failures.append("%s (expected %s, got %s)" % [msg, str(expected), str(actual)])

func flat_config() -> BattleConfig:
	var c := BattleConfig.new()
	c.damage_variance = 0.0
	c.luck_to_crit = 0.0
	c.defend_heal_fraction = 0.0
	return c

func player(hp := 100, atk := 20) -> CombatUnit:
	return CombatUnit.new(0, "p", "Princess", CombatTypes.Team.PLAYER, StatBlock.make(hp, atk, 0),
		[AbilitySpec.make("attack", "Attack", T.SINGLE_OPPONENT, 1.0)])

func enemy(id: int, hp := 50, atk := 5, boss := false) -> CombatUnit:
	return CombatUnit.new(id, "e%d" % id, "Enemy%d" % id, CombatTypes.Team.ENEMY, StatBlock.make(hp, atk, 0),
		[AbilitySpec.make("hit", "Hit", T.SINGLE_OPPONENT, 1.0)], boss)

func battle(p: CombatUnit, enemies: Array) -> BattleEngine:
	return BattleEngine.new(p, enemies, flat_config(), ScriptedRandom.new([0.99]))

func count(events: Array[BattleEvent], type: int) -> int:
	var n := 0
	for e in events:
		if e.type == type:
			n += 1
	return n

func minion_def() -> MonsterDefinition:
	var m := MonsterDefinition.new()
	m.id = "minion"
	m.display_name = "Minion"
	m.base_stats = StatBlock.make(10, 3, 0)
	m.abilities = [AbilitySpec.make("hit", "Hit", T.SINGLE_OPPONENT, 1.0)]
	return m

func phase(at: float, enrage := 0.0, cleanse := false, shield := 0.0, heal := 0.0, summons: Array = []) -> BossPhase:
	var p := BossPhase.new()
	p.hp_threshold = at
	p.announce = "phase!"
	p.enrage = enrage
	p.cleanse = cleanse
	p.shield_fraction = shield
	p.heal_fraction = heal
	for s in summons:
		p.summons.append(s)
	return p

func pdef(id: String, unlock_stage := "") -> PrincessDefinition:
	var p := PrincessDefinition.new()
	p.id = id
	p.display_name = id
	p.unlock_stage = unlock_stage
	p.base_stats = StatBlock.make(100, 20, 5, 0.1, 0.05, 10)
	p.abilities = [AbilitySpec.make("attack", "Attack", T.SINGLE_OPPONENT, 1.0)]
	return p


# ------------------------------------------------------------ boss phases

func test_phase_enrage_and_summon_fire_once() -> void:
	var boss := enemy(1, 100, 10, true)
	boss.phases = [phase(0.5, 0.5, false, 0.0, 0.0, [minion_def(), minion_def()])]
	var b := battle(player(100, 30), [boss])
	b.summon_factory = func(def: MonsterDefinition, id: int) -> CombatUnit: return UnitFactory.create_monster(def, id)
	b.start()
	var ev := b.execute_player_command(PlayerCommand.use_ability("attack", boss.id)) # 100 -> 70: no phase
	eq(count(ev, EV.BOSS_PHASE), 0, "no phase above threshold")
	if b.phase == CombatTypes.Phase.ENEMY_TURN:
		b.run_enemy_turn()
	ev = b.execute_player_command(PlayerCommand.use_ability("attack", boss.id)) # 70 -> 40: phase
	eq(count(ev, EV.BOSS_PHASE), 1, "phase announced")
	eq(count(ev, EV.UNIT_SUMMONED), 2, "two minions summoned")
	eq(b.enemies.size(), 3, "minions join the fight")
	check(is_equal_approx(boss.attack_mult, 1.5), "boss enraged (+50%% attack)")
	check(b.get_intent(b.enemies[1]) != null, "summon has an intent right away")
	# Further damage never re-triggers the phase.
	if b.phase == CombatTypes.Phase.ENEMY_TURN:
		b.run_enemy_turn()
	ev = b.execute_player_command(PlayerCommand.use_ability("attack", boss.id))
	eq(count(ev, EV.BOSS_PHASE), 0, "phase fires only once")


func test_phase_cleanse_shield_heal() -> void:
	var boss := enemy(1, 100, 10, true)
	boss.phases = [phase(0.8, 0.0, true, 0.3, 0.1)]
	boss.add_status(S.POISON, 3, 0.05)
	boss.add_status(S.WEAKEN, 2, 0.3)
	var b := battle(player(100, 30), [boss])
	b.start()
	b.execute_player_command(PlayerCommand.use_ability("attack", boss.id)) # 100 -> 70 (+10 heal)
	check(not boss.has_status(S.POISON) and not boss.has_status(S.WEAKEN), "debuffs cleansed")
	var sh := boss.get_status(S.SHIELD)
	check(sh != null and int(sh.potency) == 30, "shield = 30%% max HP")
	eq(boss.current_hp, 80, "healed 10%% after the hit")


func test_summons_respect_max_enemies() -> void:
	var boss := enemy(1, 100, 10, true)
	boss.phases = [phase(0.9, 0.0, false, 0.0, 0.0, [minion_def(), minion_def(), minion_def()])]
	var b := battle(player(100, 30), [boss, enemy(2)])
	b.max_enemies = 3
	b.summon_factory = func(def: MonsterDefinition, id: int) -> CombatUnit: return UnitFactory.create_monster(def, id)
	b.start()
	var ev := b.execute_player_command(PlayerCommand.use_ability("attack", boss.id))
	eq(count(ev, EV.UNIT_SUMMONED), 1, "only up to max_enemies living")


func test_real_boss_resists_control() -> void:
	for id in ["frost_golem", "lich_queen", "werewolf", "night_witch", "drake", "elder_wyrm"]:
		var m: MonsterDefinition = load("res://data/monsters/%s.tres" % id)
		check(m.is_boss, id + " is a boss")
		check(m.control_resistance >= 0.5, id + " resists Stun/Freeze")
		check(not m.phases.is_empty(), id + " has a phase mechanic")


# ------------------------------------------------------------ companion & synergy

func test_companion_assists_every_interval() -> void:
	var e := enemy(1, 1000, 1)
	var b := battle(player(100, 1), [e])
	var comp := CombatUnit.new(50, "c", "Companion", CombatTypes.Team.PLAYER, StatBlock.make(80, 10, 0), [])
	comp.is_companion = true
	b.companion = comp
	b.companion_assist = AbilitySpec.make("zap", "Zap", T.SINGLE_OPPONENT, 2.0)
	b.assist_interval = 2
	var assists := 0
	var ev := b.start()
	for _r in 6:
		for x in ev:
			if x.type == EV.ACTION_STARTED and x.source == comp:
				assists += 1
		ev = b.execute_player_command(PlayerCommand.defend())
		while b.phase == CombatTypes.Phase.ENEMY_TURN:
			ev.append_array(b.run_enemy_turn())
	eq(assists, 3, "assist on rounds 2, 4, 6")
	check(e.current_hp < 1000 - 3 * 19, "assist dealt damage")
	check(not b.targetable_enemies().has(comp), "companion is never a target")


func test_companion_blessing_heals_princess() -> void:
	var p := player(100, 1)
	p.current_hp = 40
	var b := battle(p, [enemy(1, 1000, 0)])
	var comp := CombatUnit.new(50, "c", "Companion", CombatTypes.Team.PLAYER, StatBlock.make(80, 10, 0), [])
	b.companion = comp
	var bless := AbilitySpec.make("blessing", "Blessing", T.LOWEST_HP_ALLY, 0.0)
	bless.heal_multiplier = 2.0
	b.companion_assist = bless
	b.assist_interval = 1
	b.start()
	eq(p.current_hp, 60, "companion healed the princess by 2x her ATK")


func test_synergy_damage_and_regen() -> void:
	var syn := Synergy.new()
	syn.princess_a = "a"
	syn.princess_b = "b"
	syn.damage_bonus = 0.5
	syn.regen = 0.1
	check(syn.matches("b", "a"), "pair matches both ways")
	var p := player(100, 20)
	UnitFactory.apply_synergy(p, syn)
	var e := enemy(1, 200, 0)
	var b := battle(p, [e])
	b.start()
	b.execute_player_command(PlayerCommand.use_ability("attack", e.id))
	eq(e.current_hp, 170, "+50%% damage")
	p.current_hp = 50
	var regen := 0
	while b.phase == CombatTypes.Phase.ENEMY_TURN:
		for x in b.run_enemy_turn():
			if x.type == EV.HEAL and x.target == p:
				regen = x.amount
	eq(regen, 10, "regen 10%% of max HP at turn start")


func test_roster_synergies() -> void:
	var r: PrincessRoster = load("res://data/princess_roster.tres")
	eq(r.synergies.size(), 10, "every pair of 5 princesses has a synergy")
	var sm := r.synergy_for("sword_princess", "magic_princess")
	check(sm != null and sm.damage_bonus > 0.0, "Sword+Magic = more damage")
	var sl := r.synergy_for("light_princess", "sword_princess")
	check(sl != null and sl.regen > 0.0, "Sword+Light = healing")
	var sd := r.synergy_for("shadow_princess", "dragon_princess")
	check(sd != null and sd.stats.critical > 0.0, "Shadow+Dragon = crit")
	check(r.synergy_for("sword_princess", "sword_princess") == null, "no self synergy")
	for p in r.princesses:
		check(p.assist != null, p.id + " has a companion assist")


# ------------------------------------------------------------ levels, unlocks, stages, save

func test_level_stats_growth() -> void:
	var p := pdef("x")
	p.growth_hp = 10.0
	p.growth_attack = 1.5
	var s1 := p.level_stats(1)
	var s5 := p.level_stats(5)
	eq(s1.max_hp, 100, "Lv1 = base")
	eq(s5.max_hp, 140, "Lv5 HP +40")
	eq(s5.attack, 26, "Lv5 ATK +6")


func test_exp_and_level_cap() -> void:
	var c := CastleProgress.new()
	eq(c.level("x"), 1, "starts at Lv1")
	var gained := c.add_exp("x", CastleTypes.exp_to_next(1) + 5)
	eq(gained, 1, "one level")
	eq(c.level("x"), 2, "Lv2")
	eq(c.exp_points("x"), 5, "leftover EXP kept")
	c.add_exp("x", 10000000)
	eq(c.level("x"), CastleTypes.MAX_LEVEL, "capped at max level")
	eq(c.exp_points("x"), 0, "no EXP at max")


func test_unlock_by_stage_and_chain() -> void:
	var roster := PrincessRoster.new()
	roster.princesses = [pdef("a"), pdef("b", "s1")]
	var s1 := StageDefinition.new()
	s1.id = "s1"
	var s2 := StageDefinition.new()
	s2.id = "s2"
	s2.unlock_after = "s1"
	roster.stages = [s1, s2]
	var c := CastleProgress.new()
	check(c.is_unlocked(roster.princesses[0]), "a free")
	check(not c.is_unlocked(roster.princesses[1]), "b locked")
	check(c.is_stage_unlocked(s1) and not c.is_stage_unlocked(s2), "s2 locked until s1")
	var newly := c.mark_stage_cleared("s1", roster)
	eq(newly.size(), 1, "b unlocked by clearing s1")
	check(c.is_stage_unlocked(s2), "s2 opens")
	eq(c.mark_stage_cleared("s1", roster).size(), 0, "replay unlocks nothing new")


func test_save_v4_roundtrip_and_migration() -> void:
	var c := CastleProgress.new()
	c.add_exp("a", 100)
	c.cleared_stages.append("stage_02")
	c.set_companion("b")
	c.selected_stage = "stage_02"
	var d: Dictionary = JSON.parse_string(JSON.stringify(c.to_dict()))
	var c2 := CastleProgress.new()
	c2.from_dict(d, null)
	eq(c2.level("a"), c.level("a"), "level saved")
	eq(c2.exp_points("a"), c.exp_points("a"), "exp saved")
	check(c2.cleared_stages.has("stage_02"), "cleared stages saved")
	eq(c2.companion, "b", "companion saved")
	eq(c2.selected_stage, "stage_02", "selected stage saved")
	# v3 save: only a clear counter -> stage 1 counts as cleared.
	var old := CastleProgress.new()
	old.from_dict({"stage_clears": 2}, null)
	check(old.is_stage_cleared("stage_01"), "old clears migrate to stage_01")


func test_real_stages() -> void:
	var r: PrincessRoster = load("res://data/princess_roster.tres")
	eq(r.stages.size(), 4, "4 stages")
	var prev_rec := 0
	for i in r.stages.size():
		var s: StageDefinition = r.stages[i]
		check(s.recommended_level > prev_rec, s.id + " recommended level rises")
		prev_rec = s.recommended_level
		if i > 0:
			eq(s.unlock_after, r.stages[i - 1].id, s.id + " unlock chain")
			check(s.boss_name() != "", s.id + " ends with a boss")
			var tiers := []
			for e in s.encounters:
				tiers.append(e.reward_tier)
			check(tiers.has(ItemTypes.Tier.MINI_BOSS) and tiers.has(ItemTypes.Tier.BOSS), s.id + " has mini boss + boss rewards")
	for p in r.princesses:
		if p.id != "sword_princess":
			check(r.find_stage(p.unlock_stage) != null, p.id + " unlocks through a real stage")
