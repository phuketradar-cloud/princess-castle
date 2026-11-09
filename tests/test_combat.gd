extends RefCounted
## Unit tests for the pure combat logic. Every func starting with "test_" is run by run_tests.gd.

const ScriptedRandom = preload("res://tests/scripted_random.gd")
const T = CombatTypes.Target
const S = CombatTypes.Status
const Phase = CombatTypes.Phase
const Outcome = CombatTypes.Outcome
const EV = BattleEvent.Type

var failures: Array[String] = []


# ------------------------------------------------------------ helpers

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

func rng(values: Array[float] = [0.99]) -> RandomSource:
	return ScriptedRandom.new(values)

func make_player(hp := 100, atk := 20, def := 0, crit := 0.0, eva := 0.0, extra: Array = []) -> CombatUnit:
	var abilities: Array = [AbilitySpec.make("attack", "Attack", T.SINGLE_OPPONENT, 1.0)]
	abilities.append_array(extra)
	return CombatUnit.new(0, "p", "Princess", CombatTypes.Team.PLAYER, StatBlock.make(hp, atk, def, crit, eva), abilities)

func make_enemy(id: int, hp := 50, atk := 10, def := 0, eva := 0.0, boss := false, resist := 0.0, extra: Array = []) -> CombatUnit:
	var abilities: Array = extra.duplicate()
	abilities.append(AbilitySpec.make("hit", "Hit", T.SINGLE_OPPONENT, 1.0))
	return CombatUnit.new(id, "e", "Enemy%d" % id, CombatTypes.Team.ENEMY, StatBlock.make(hp, atk, def, 0.0, eva), abilities, boss, resist)

func battle(player: CombatUnit, enemies: Array) -> BattleEngine:
	return BattleEngine.new(player, enemies, flat_config(), rng())

func count(events: Array[BattleEvent], type: int, filter := Callable()) -> int:
	var n := 0
	for e in events:
		if e.type == type and (not filter.is_valid() or filter.call(e)):
			n += 1
	return n


# ------------------------------------------------------------ damage formula
# Random order in compute_hit: [dodge roll] [variance] [crit roll]; 0.99 fails rolls, 0.0 succeeds.

func test_damage_equals_attack_without_defense() -> void:
	var hit := DamageCalculator.compute_hit(make_player(), make_enemy(1), 1.0, flat_config(), rng())
	eq(hit.damage, 20, "plain hit")
	check(not hit.crit and not hit.dodged, "no crit / dodge")

func test_defense_diminishing_returns() -> void:
	var p := make_player()
	eq(DamageCalculator.compute_hit(p, make_enemy(1, 50, 10, 50), 1.0, flat_config(), rng()).damage, 10, "def 50")
	eq(DamageCalculator.compute_hit(p, make_enemy(1, 50, 10, 150), 1.0, flat_config(), rng()).damage, 5, "def 150")

func test_critical_multiplies() -> void:
	var hit := DamageCalculator.compute_hit(make_player(100, 20, 0, 0.5), make_enemy(1), 1.0, flat_config(), rng([0.5, 0.0]))
	check(hit.crit, "should crit")
	eq(hit.damage, 30, "crit damage")

func test_evasion_dodges_and_is_capped() -> void:
	check(DamageCalculator.compute_hit(make_player(), make_enemy(1, 50, 10, 0, 0.3), 1.0, flat_config(), rng([0.1])).dodged, "dodge")
	var cfg := flat_config()
	cfg.max_evasion = 0.5
	check(not DamageCalculator.compute_hit(make_player(), make_enemy(1, 50, 10, 0, 0.95), 1.0, cfg, rng([0.55, 0.5, 0.99])).dodged, "cap 50%")

func test_defending_halves_and_min_damage() -> void:
	var e := make_enemy(1)
	e.is_defending = true
	eq(DamageCalculator.compute_hit(make_player(), e, 1.0, flat_config(), rng()).damage, 10, "defend halves")
	eq(DamageCalculator.compute_hit(make_player(100, 1), make_enemy(2, 50, 1, 1000), 0.1, flat_config(), rng()).damage, 1, "min damage")

func test_estimate_matches_flat_hit() -> void:
	var p := make_player(100, 30)
	var e := make_enemy(1, 50, 10, 25)
	eq(DamageCalculator.estimate(p, e, 1.5, flat_config()), DamageCalculator.compute_hit(p, e, 1.5, flat_config(), rng()).damage, "estimate")


# ------------------------------------------------------------ engine flow

func test_start_plans_intents() -> void:
	var e := make_enemy(1)
	var b := battle(make_player(), [e])
	var ev := b.start()
	eq(b.phase, Phase.PLAYER_TURN, "phase")
	eq(b.round_number, 1, "round")
	check(b.get_intent(e) != null, "intent planned")
	eq(count(ev, EV.INTENTS_CHANGED), 1, "intents event")

func test_kill_last_enemy_is_victory() -> void:
	var e := make_enemy(1, 15)
	var b := battle(make_player(), [e])
	b.start()
	var ev := b.execute_player_command(PlayerCommand.use_ability("attack", e.id))
	check(not e.is_alive(), "enemy dead")
	eq(b.outcome, Outcome.VICTORY, "victory")
	eq(b.phase, Phase.ENDED, "ended")
	eq(count(ev, EV.UNIT_DIED), 1, "died event")

func test_player_death_is_defeat() -> void:
	var e := make_enemy(1, 500, 200)
	var b := battle(make_player(50), [e])
	b.start()
	b.execute_player_command(PlayerCommand.use_ability("attack", e.id))
	eq(b.phase, Phase.ENEMY_TURN, "enemy turn")
	b.run_enemy_turn()
	eq(b.outcome, Outcome.DEFEAT, "defeat")
	eq(b.player.current_hp, 0, "hp 0")

func test_full_round() -> void:
	var e := make_enemy(1, 500, 10)
	var b := battle(make_player(), [e])
	b.start()
	b.execute_player_command(PlayerCommand.use_ability("attack", e.id))
	b.run_enemy_turn()
	eq(b.phase, Phase.PLAYER_TURN, "back to player")
	eq(b.round_number, 2, "round 2")
	eq(b.player.current_hp, 90, "player took 10")
	eq(e.current_hp, 480, "enemy took 20")

func test_multiple_enemies_all_act_and_targeting() -> void:
	var e1 := make_enemy(1, 100, 5)
	var e2 := make_enemy(2, 100, 7)
	var e3 := make_enemy(3, 100, 9)
	var b := battle(make_player(), [e1, e2, e3])
	b.start()
	b.execute_player_command(PlayerCommand.use_ability("attack", e3.id))
	eq(e3.current_hp, 80, "explicit target hit")
	eq(e1.current_hp, 100, "others untouched")
	var ev := b.run_enemy_turn()
	eq(count(ev, EV.ACTION_STARTED), 3, "3 enemies act")
	eq(b.player.current_hp, 100 - 21, "damage sum")

func test_area_attack_hits_all() -> void:
	var e1 := make_enemy(1, 100)
	var e2 := make_enemy(2, 100)
	var b := battle(make_player(100, 20, 0, 0, 0, [AbilitySpec.make("sweep", "Sweep", T.ALL_OPPONENTS, 0.5, 3)]), [e1, e2])
	b.start()
	b.execute_player_command(PlayerCommand.use_ability("sweep"))
	eq(e1.current_hp, 90, "e1")
	eq(e2.current_hp, 90, "e2")

func test_cooldown() -> void:
	var e := make_enemy(1, 10000, 1)
	var b := battle(make_player(100, 20, 0, 0, 0, [AbilitySpec.make("big", "Big", T.SINGLE_OPPONENT, 2.0, 3)]), [e])
	b.start()
	b.execute_player_command(PlayerCommand.use_ability("big", e.id))
	b.run_enemy_turn()
	check(b.validate_command(PlayerCommand.use_ability("big", e.id)) != "", "round 2 cooling")
	b.execute_player_command(PlayerCommand.use_ability("attack", e.id))
	b.run_enemy_turn()
	check(b.validate_command(PlayerCommand.use_ability("big", e.id)) != "", "round 3 cooling")
	b.execute_player_command(PlayerCommand.use_ability("attack", e.id))
	b.run_enemy_turn()
	eq(b.validate_command(PlayerCommand.use_ability("big", e.id)), "", "round 4 ready")

func test_stun_skips_enemy_turn() -> void:
	var bash := AbilitySpec.make("bash", "Bash", T.SINGLE_OPPONENT, 0.1, 4).with_status(S.STUN, 1, 0.0)
	var e := make_enemy(1, 1000, 30)
	var b := battle(make_player(100, 20, 0, 0, 0, [bash]), [e])
	b.start()
	b.execute_player_command(PlayerCommand.use_ability("bash", e.id))
	check(e.has_status(S.STUN), "stunned")
	var ev := b.run_enemy_turn()
	eq(count(ev, EV.TURN_SKIPPED), 1, "skipped")
	eq(b.player.current_hp, 100, "no damage")
	check(not e.has_status(S.STUN), "stun expired")

func test_boss_resists_stun() -> void:
	var bash := AbilitySpec.make("bash", "Bash", T.SINGLE_OPPONENT, 0.1).with_status(S.STUN, 1, 0.0)
	var boss := make_enemy(1, 1000, 10, 0, 0.0, true, 1.0)
	var b := battle(make_player(100, 20, 0, 0, 0, [bash]), [boss])
	b.start()
	var ev := b.execute_player_command(PlayerCommand.use_ability("bash", boss.id))
	check(not boss.has_status(S.STUN), "not stunned")
	eq(count(ev, EV.STATUS_RESISTED), 1, "resisted event")

func test_poison_ticks_then_expires() -> void:
	var venom := AbilitySpec.make("venom", "Venom", T.SINGLE_OPPONENT, 0.01).with_status(S.POISON, 2, 0.01)
	var e := make_enemy(1, 1000, 0)
	var b := battle(make_player(100, 1, 0, 0, 0, [venom]), [e])
	b.start()
	b.execute_player_command(PlayerCommand.use_ability("venom", e.id))
	var is_poison := func(x: BattleEvent): return x.from_status
	eq(count(b.run_enemy_turn(), EV.DAMAGE, is_poison), 1, "tick 1")
	b.execute_player_command(PlayerCommand.use_ability("attack", e.id))
	var ev2 := b.run_enemy_turn()
	eq(count(ev2, EV.DAMAGE, is_poison), 1, "tick 2")
	eq(count(ev2, EV.STATUS_EXPIRED), 1, "expired")
	b.execute_player_command(PlayerCommand.use_ability("attack", e.id))
	eq(count(b.run_enemy_turn(), EV.DAMAGE, is_poison), 0, "no more ticks")

func test_defend_halves_incoming() -> void:
	var e := make_enemy(1, 1000, 20)
	var b := battle(make_player(), [e])
	b.start()
	b.execute_player_command(PlayerCommand.defend())
	b.run_enemy_turn()
	eq(b.player.current_hp, 90, "halved")
	check(not b.player.is_defending, "guard resets")

func test_invalid_commands_rejected() -> void:
	var e := make_enemy(1)
	var b := battle(make_player(), [e])
	check(b.validate_command(PlayerCommand.use_ability("attack", e.id)) != "", "not started")
	b.start()
	check(b.validate_command(PlayerCommand.use_ability("nope", e.id)) != "", "unknown ability")
	check(b.validate_command(PlayerCommand.use_ability("attack", b.player.id)) != "", "self target")
	check(b.validate_command(PlayerCommand.use_ability("attack", 999)) != "", "missing unit")
	eq(b.validate_command(PlayerCommand.use_ability("attack", -1)), "", "auto target ok")

func test_healer_heals_lowest_ally() -> void:
	var mend := AbilitySpec.make("mend", "Mend", T.LOWEST_HP_ALLY, 0.0)
	mend.heal_multiplier = 2.0
	var healer := CombatUnit.new(1, "s", "Shaman", CombatTypes.Team.ENEMY, StatBlock.make(100, 10, 0),
		[mend, AbilitySpec.make("hit", "Hit", T.SINGLE_OPPONENT, 1.0)])
	var tank := make_enemy(2, 100, 1)
	var b := battle(make_player(1000, 70), [healer, tank])
	b.start()
	b.execute_player_command(PlayerCommand.use_ability("attack", tank.id))
	eq(tank.current_hp, 30, "tank hurt")
	b.run_enemy_turn()
	b.execute_player_command(PlayerCommand.defend())
	var ev := b.run_enemy_turn()
	eq(count(ev, EV.HEAL, func(x: BattleEvent): return x.target == tank), 1, "heal on tank")
	eq(tank.current_hp, 50, "tank healed 20")

func test_stunned_player_skips_turn() -> void:
	var stomp := AbilitySpec.make("stomp", "Stomp", T.SINGLE_OPPONENT, 0.01, 99).with_status(S.STUN, 1, 0.0)
	var e := make_enemy(1, 1000, 1, 0, 0.0, false, 0.0, [stomp])
	var b := battle(make_player(), [e])
	b.start()
	b.execute_player_command(PlayerCommand.defend())
	var ev := b.run_enemy_turn()
	eq(count(ev, EV.TURN_SKIPPED, func(x: BattleEvent): return x.source == b.player), 1, "player skipped")
	eq(b.phase, Phase.ENEMY_TURN, "straight to enemy turn")
	b.run_enemy_turn()
	eq(b.phase, Phase.PLAYER_TURN, "player turn again")

func test_thousand_random_battles_terminate() -> void:
	var policy := AutoBattlePolicy.new()
	for seed_value in range(1, 1001):
		var enemies: Array = []
		for i in 1 + seed_value % 5:
			enemies.append(make_enemy(i + 1, 20 + seed_value % 40, 4 + seed_value % 9, seed_value % 6, (seed_value % 4) * 0.1))
		var p := make_player(120, 18, 6, 0.1, 0.05, [AbilitySpec.make("aoe", "AoE", T.ALL_OPPONENTS, 0.7, 3)])
		var b := BattleEngine.new(p, enemies, BattleConfig.new(), RandomSource.new(seed_value))
		b.start()
		var guard := 0
		while b.phase != Phase.ENDED:
			guard += 1
			if guard > 500:
				failures.append("seed %d did not end" % seed_value)
				return
			if b.phase == Phase.PLAYER_TURN:
				b.execute_player_command(policy.decide(b))
			else:
				b.run_enemy_turn()
			for u in enemies + [p]:
				if u.current_hp < 0 or u.current_hp > u.stats.max_hp:
					failures.append("seed %d: hp out of range %s" % [seed_value, u])
					return
