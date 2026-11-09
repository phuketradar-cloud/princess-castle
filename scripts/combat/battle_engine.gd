class_name BattleEngine
extends RefCounted
## Turn-based battle rules: one princess (left) vs N monsters (right). No nodes involved.
##
## Flow:
##   start()                 -> player turn begins, monster intents planned
##   play_card()             -> (optional, any number) spend mana on deck cards; turn continues
##   execute_player_command  -> player acts; phase becomes ENEMY_TURN (or ENDED)
##   run_enemy_turn()        -> every monster acts in order, then next player turn
## If the princess can't act (stun...), phase is ENEMY_TURN right after start()/run_enemy_turn();
## callers loop while phase == ENEMY_TURN.
##
## Timing: DoTs tick / action blockers are checked when the unit's side starts acting;
## durations count down at the end of that side's turn. Cooldowns tick at the start of the
## owner's turn (monsters tick when their intent is planned). Mana refills at player turn start.

const Team = CombatTypes.Team
const Phase = CombatTypes.Phase
const Outcome = CombatTypes.Outcome
const Status = CombatTypes.Status
const Target = CombatTypes.Target


## A deck card during this battle.
class CardState:
	var card: CardDefinition
	var uses_left: int

	func _init(p_card: CardDefinition, uses: int) -> void:
		card = p_card
		uses_left = uses


var player: CombatUnit
var enemies: Array[CombatUnit] = []
var config: BattleConfig
var phase: int = Phase.NOT_STARTED
var outcome: int = Outcome.NONE
var round_number := 0
var mana := 0
var cards: Array[CardState] = []

## Phase 5: companion princess (back row, never targeted) uses `companion_assist`
## automatically every `assist_interval` rounds.
var companion: CombatUnit
var companion_assist: AbilitySpec
var assist_interval := 3
## Creates units for boss summons: func(def: MonsterDefinition, id: int) -> CombatUnit
var summon_factory: Callable
var max_enemies := 6
var _next_summon_id := 1000

var _rng: RandomSource
var _brain: EnemyBrain
var _intents := {} # unit id -> CombatUnit.AbilityState


func _init(p_player: CombatUnit, p_enemies: Array, p_config: BattleConfig = null,
		p_rng: RandomSource = null, p_brain: EnemyBrain = null, p_deck: Array = []) -> void:
	assert(p_player != null and p_player.team == Team.PLAYER, "Player unit must be on Team.PLAYER")
	player = p_player
	for e in p_enemies:
		if e != null:
			assert(e.team == Team.ENEMY, "Enemy '%s' must be on Team.ENEMY" % e.unit_name)
			enemies.append(e)
	assert(not enemies.is_empty(), "A battle needs at least one enemy")
	config = p_config if p_config != null else BattleConfig.new()
	_rng = p_rng if p_rng != null else RandomSource.new()
	_brain = p_brain if p_brain != null else EnemyBrain.new()
	for c in p_deck:
		if c != null and c.effect != null:
			cards.append(CardState.new(c, maxi(1, config.card_uses_per_battle)))


# ---------------------------------------------------------------- queries

func living_enemies() -> Array[CombatUnit]:
	var list: Array[CombatUnit] = []
	for e in enemies:
		if e.is_alive():
			list.append(e)
	return list

## Alive and on the field (not banished) — what the princess can hit.
func targetable_enemies() -> Array[CombatUnit]:
	var list: Array[CombatUnit] = []
	for e in enemies:
		if e.is_targetable():
			list.append(e)
	return list

func first_living_enemy() -> CombatUnit:
	for e in enemies:
		if e.is_alive():
			return e
	return null

func first_targetable_enemy() -> CombatUnit:
	for e in enemies:
		if e.is_targetable():
			return e
	return null

func find_unit(unit_id: int) -> CombatUnit:
	if player.id == unit_id:
		return player
	for e in enemies:
		if e.id == unit_id:
			return e
	return null

## Planned ability (CombatUnit.AbilityState) of a monster for the coming enemy turn, or null.
func get_intent(enemy: CombatUnit) -> CombatUnit.AbilityState:
	if enemy == null:
		return null
	return _intents.get(enemy.id)

## Expected total damage of a monster's planned action against the princess (0 if it can't act).
func estimate_intent_damage(enemy: CombatUnit) -> int:
	var plan := get_intent(enemy)
	if plan == null or not plan.spec.deals_damage() or enemy.action_blocker() != Status.NONE:
		return 0
	return DamageCalculator.estimate(enemy, player, plan.spec.damage_multiplier, config) * maxi(1, plan.spec.hit_count)

## "" when the command is legal, otherwise a reason. See PlayerCommand.
func validate_command(cmd: PlayerCommand) -> String:
	if phase != Phase.PLAYER_TURN:
		return "ยังไม่ใช่เทิร์นของเจ้าหญิง"
	if cmd.kind == PlayerCommand.Kind.DEFEND:
		return ""
	var ability := player.find_ability(cmd.ability_id)
	if ability == null:
		return "ไม่รู้จักท่า '%s'" % cmd.ability_id
	if not ability.is_ready():
		return "%s ยังคูลดาวน์ (%d)" % [ability.spec.display_name, ability.cooldown_remaining]
	return _validate_target(ability.spec, cmd.target_id)

## "" when card `index` can be played now on `target_id`.
func validate_card(index: int, target_id := -1) -> String:
	if phase != Phase.PLAYER_TURN:
		return "ยังไม่ใช่เทิร์นของเจ้าหญิง"
	if index < 0 or index >= cards.size():
		return "ไม่มีการ์ดใบนี้"
	var cs := cards[index]
	if cs.uses_left <= 0:
		return "%s ใช้ไปแล้วในการต่อสู้นี้" % cs.card.display_name
	if mana < cs.card.mana_cost:
		return "มานาไม่พอ (%d/%d)" % [mana, cs.card.mana_cost]
	return _validate_target(cs.card.effect, target_id)

func _validate_target(spec: AbilitySpec, target_id: int) -> String:
	if spec.target == Target.SINGLE_OPPONENT and target_id >= 0:
		var t := find_unit(target_id)
		if t == null or t.team != Team.ENEMY or not t.is_targetable():
			return "เป้าหมายไม่ถูกต้อง"
	return ""


# ---------------------------------------------------------------- flow

func start() -> Array[BattleEvent]:
	assert(phase == Phase.NOT_STARTED, "Battle already started")
	var events: Array[BattleEvent] = []
	mana = mini(config.start_mana, config.max_mana)
	_begin_player_turn(events)
	return events


## Plays a deck card. Does NOT end the turn: the princess still takes her action afterwards.
func play_card(index: int, target_id := -1) -> Array[BattleEvent]:
	var events: Array[BattleEvent] = []
	var error := validate_card(index, target_id)
	if error != "":
		push_error("Invalid card: " + error)
		return events
	var cs := cards[index]
	cs.uses_left -= 1
	mana -= cs.card.mana_cost
	var target := find_unit(target_id) if target_id >= 0 else null
	var state := CombatUnit.AbilityState.new(cs.card.effect)
	_execute_ability(player, state, target, events, cs.card)
	_check_end(events)
	return events


func execute_player_command(cmd: PlayerCommand) -> Array[BattleEvent]:
	var events: Array[BattleEvent] = []
	var error := validate_command(cmd)
	if error != "":
		push_error("Invalid command: " + error)
		return events

	if cmd.kind == PlayerCommand.Kind.DEFEND:
		player.is_defending = true
		var d := BattleEvent.make(BattleEvent.Type.DEFEND)
		d.source = player
		events.append(d)
		var healed := player.apply_heal(roundi(player.stats.max_hp * config.defend_heal_fraction))
		if healed > 0:
			events.append(_heal_event(player, player, healed))
	else:
		var target := find_unit(cmd.target_id) if cmd.target_id >= 0 else null
		_execute_ability(player, player.find_ability(cmd.ability_id), target, events)

	if _check_end(events):
		return events
	_end_turn_statuses(player, events)
	phase = Phase.ENEMY_TURN
	return events


func run_enemy_turn() -> Array[BattleEvent]:
	var events: Array[BattleEvent] = []
	if phase != Phase.ENEMY_TURN:
		push_error("run_enemy_turn called outside the enemy turn")
		return events
	var ts := BattleEvent.make(BattleEvent.Type.TURN_STARTED)
	ts.side = Team.ENEMY
	ts.round_number = round_number
	events.append(ts)

	# Copy: monsters summoned during this turn start acting next turn.
	for enemy: CombatUnit in enemies.duplicate():
		if not enemy.is_alive():
			continue
		_apply_start_statuses(enemy, events)
		if _check_end(events):
			return events
		if not enemy.is_alive():
			continue
		var blocker := enemy.action_blocker()
		if blocker != Status.NONE:
			var sk := BattleEvent.make(BattleEvent.Type.TURN_SKIPPED)
			sk.source = enemy
			sk.reason = CombatTypes.status_name(blocker)
			events.append(sk)
			continue
		var plan := get_intent(enemy)
		if plan == null:
			plan = _brain.plan(enemy, enemies, player, _rng)
		if enemy.has_status(Status.SILENCE):
			plan = enemy.basic_ability()
		_execute_ability(enemy, plan, player, events)
		if _check_end(events):
			return events

	for enemy in enemies:
		if enemy.is_alive():
			_end_turn_statuses(enemy, events)

	_begin_player_turn(events)
	return events


# ---------------------------------------------------------------- internals

func _begin_player_turn(events: Array[BattleEvent]) -> void:
	round_number += 1
	phase = Phase.PLAYER_TURN
	if round_number > 1:
		mana = mini(config.max_mana, mana + config.mana_per_turn)
	var ts := BattleEvent.make(BattleEvent.Type.TURN_STARTED)
	ts.side = Team.PLAYER
	ts.round_number = round_number
	events.append(ts)

	player.is_defending = false
	player.tick_cooldowns()

	# Monsters decide now so the player can see (and react to) what is coming.
	_intents.clear()
	for enemy in enemies:
		if enemy.is_alive():
			enemy.tick_cooldowns()
			_intents[enemy.id] = _brain.plan(enemy, enemies, player, _rng)
	events.append(BattleEvent.make(BattleEvent.Type.INTENTS_CHANGED))

	_apply_start_statuses(player, events)
	if _check_end(events):
		return

	# Synergy regeneration.
	if player.regen > 0.0:
		var healed := player.apply_heal(maxi(1, roundi(player.stats.max_hp * player.regen)))
		if healed > 0:
			events.append(_heal_event(player, player, healed))

	# Companion assist (every N rounds, before the princess acts).
	if companion != null and companion_assist != null and assist_interval > 0 and round_number % assist_interval == 0:
		var state := CombatUnit.AbilityState.new(companion_assist)
		_execute_ability(companion, state, _companion_target(), events)
		if _check_end(events):
			return

	var blocker := player.action_blocker()
	if blocker != Status.NONE:
		var sk := BattleEvent.make(BattleEvent.Type.TURN_SKIPPED)
		sk.source = player
		sk.reason = CombatTypes.status_name(blocker)
		events.append(sk)
		_end_turn_statuses(player, events)
		phase = Phase.ENEMY_TURN


func _execute_ability(actor: CombatUnit, ability: CombatUnit.AbilityState, explicit_target: CombatUnit,
		events: Array[BattleEvent], card: CardDefinition = null) -> void:
	var spec := ability.spec
	var started := BattleEvent.make(BattleEvent.Type.ACTION_STARTED)
	started.source = actor
	started.ability = spec
	started.card = card
	events.append(started)
	ability.cooldown_remaining = maxi(0, spec.cooldown)

	for target in _resolve_targets(actor, spec.target, explicit_target):
		var landed := not spec.deals_damage() # non-damaging abilities always "land"

		if spec.deals_damage():
			for i in maxi(1, spec.hit_count):
				if not target.is_alive():
					break
				# Execute: finish off weakened targets (bosses take heavy damage instead).
				if spec.execute_threshold > 0.0 and target.hp_ratio() <= spec.execute_threshold and not target.is_boss:
					landed = true
					var dealt := target.current_hp
					target.apply_damage(dealt)
					var ex := _damage_event(actor, target, dealt, true, false)
					ex.executed = true
					events.append(ex)
					events.append(_died_event(target))
					break
				var mult := spec.damage_multiplier
				if spec.execute_threshold > 0.0 and target.is_boss and target.hp_ratio() <= spec.execute_threshold:
					mult *= spec.execute_boss_multiplier
				var hit := DamageCalculator.compute_hit(actor, target, mult, config, _rng)
				if hit.dodged:
					var dg := BattleEvent.make(BattleEvent.Type.DODGE)
					dg.source = actor
					dg.target = target
					events.append(dg)
					continue
				landed = true
				var taken := _deal_damage(actor, target, hit.damage, hit.crit, events)
				_apply_on_hit_effects(actor, target, taken, events)
				if not actor.is_alive():
					return # killed by thorns

		if spec.heals() and target.is_alive():
			var healed := target.apply_heal(roundi(actor.effective_attack() * spec.heal_multiplier))
			events.append(_heal_event(actor, target, healed))

		if landed and target.is_alive() and spec.has_status():
			_try_apply_status(actor, target, spec, events)


## Applies a hit through shields; wakes sleepers. Returns HP actually lost.
func _deal_damage(src: CombatUnit, target: CombatUnit, amount: int, crit: bool, events: Array[BattleEvent]) -> int:
	var absorbed := 0
	var shield := target.get_status(Status.SHIELD)
	if shield != null and amount > 0:
		absorbed = mini(int(shield.potency), amount)
		shield.potency -= absorbed
		amount -= absorbed
		if shield.potency <= 0.0:
			target.remove_status(Status.SHIELD)
			events.append(_status_event(BattleEvent.Type.STATUS_EXPIRED, target, Status.SHIELD))
	target.apply_damage(amount)
	var e := _damage_event(src, target, amount, crit, false)
	e.absorbed = absorbed
	events.append(e)
	if not target.is_alive():
		events.append(_died_event(target))
	elif amount > 0 and target.remove_status(Status.SLEEP):
		events.append(_status_event(BattleEvent.Type.STATUS_EXPIRED, target, Status.SLEEP))
	_check_phases(target, events)
	return amount


## Companion picks the princess's current target logic: weakest targetable monster.
func _companion_target() -> CombatUnit:
	var best: CombatUnit = null
	for e in targetable_enemies():
		if best == null or e.current_hp < best.current_hp:
			best = e
	return best


## Boss mechanics: each phase fires once when HP drops to its threshold.
func _check_phases(unit: CombatUnit, events: Array[BattleEvent]) -> void:
	if unit.phases.is_empty() or not unit.is_alive():
		return
	for i in unit.phases.size():
		var ph = unit.phases[i]
		if ph == null or unit.phases_done.has(i) or unit.hp_ratio() > ph.hp_threshold:
			continue
		unit.phases_done.append(i)
		var announce := BattleEvent.make(BattleEvent.Type.BOSS_PHASE)
		announce.source = unit
		announce.reason = ph.announce
		events.append(announce)
		if ph.enrage > 0.0:
			unit.attack_mult += ph.enrage
		if ph.cleanse:
			for s in unit.statuses.duplicate():
				if not CombatTypes.is_buff(s.type):
					unit.remove_status(s.type)
					events.append(_status_event(BattleEvent.Type.STATUS_EXPIRED, unit, s.type))
		if ph.shield_fraction > 0.0:
			var amount := roundi(unit.stats.max_hp * ph.shield_fraction)
			unit.remove_status(Status.SHIELD)
			unit.add_status(Status.SHIELD, 99, amount)
			var se := _status_event(BattleEvent.Type.STATUS_APPLIED, unit, Status.SHIELD)
			se.amount = amount
			se.turns = 99
			events.append(se)
		if ph.heal_fraction > 0.0:
			var healed := unit.apply_heal(roundi(unit.stats.max_hp * ph.heal_fraction))
			events.append(_heal_event(unit, unit, healed))
		for def in ph.summons:
			if def == null or not summon_factory.is_valid() or living_enemies().size() >= max_enemies:
				continue
			_next_summon_id += 1
			var s_unit: CombatUnit = summon_factory.call(def, _next_summon_id)
			if s_unit == null:
				continue
			enemies.append(s_unit)
			var su := BattleEvent.make(BattleEvent.Type.UNIT_SUMMONED)
			su.target = s_unit
			su.source = unit
			events.append(su)
			# Summoned on the player's turn: show its intent right away (it acts this enemy turn).
			if phase == Phase.PLAYER_TURN:
				_intents[s_unit.id] = _brain.plan(s_unit, enemies, player, _rng)
				events.append(BattleEvent.make(BattleEvent.Type.INTENTS_CHANGED))


## Equipment special effects triggered by a landed hit.
func _apply_on_hit_effects(actor: CombatUnit, target: CombatUnit, damage: int, events: Array[BattleEvent]) -> void:
	if damage <= 0:
		return
	# Lifesteal: attacker heals a share of the damage dealt.
	if actor.lifesteal > 0.0 and actor.is_alive():
		var healed := actor.apply_heal(maxi(1, roundi(damage * actor.lifesteal)))
		if healed > 0:
			events.append(_heal_event(actor, actor, healed))
	# Poison edge: chance to poison the target (4% max HP, 2 turns).
	if actor.poison_on_hit > 0.0 and target.is_alive() and _rng.roll(actor.poison_on_hit):
		target.add_status(Status.POISON, 2, 0.04)
		var p := _status_event(BattleEvent.Type.STATUS_APPLIED, target, Status.POISON)
		p.turns = 2
		events.append(p)
	# Thorns: defender reflects a share of the damage taken.
	if target.thorns > 0.0 and actor.is_alive():
		var reflect := maxi(1, roundi(damage * target.thorns))
		var r_events: Array[BattleEvent] = []
		_deal_damage(target, actor, reflect, false, r_events)
		for r in r_events:
			if r.type == BattleEvent.Type.DAMAGE:
				r.reflected = true
			events.append(r)


func _try_apply_status(actor: CombatUnit, target: CombatUnit, spec: AbilitySpec, events: Array[BattleEvent]) -> void:
	var turns := spec.status_turns
	var potency := spec.status_potency
	if not CombatTypes.is_buff(spec.status):
		if not _rng.roll(spec.status_chance):
			return
		if CombatTypes.is_control(spec.status) and target.is_boss:
			# Bosses: immune to Banish, other control effects last half as long.
			if spec.status == Status.BANISH:
				events.append(_status_event(BattleEvent.Type.STATUS_RESISTED, target, spec.status))
				return
			turns = maxi(1, ceili(turns / 2.0))
		if CombatTypes.is_control(spec.status) and target.control_resistance > 0.0 and _rng.roll(target.control_resistance):
			events.append(_status_event(BattleEvent.Type.STATUS_RESISTED, target, spec.status))
			return
	if spec.status == Status.SHIELD:
		potency = roundi(actor.effective_attack() * spec.status_potency) # absorb amount
		target.remove_status(Status.SHIELD)
	target.add_status(spec.status, turns, potency)
	var e := _status_event(BattleEvent.Type.STATUS_APPLIED, target, spec.status)
	e.turns = turns
	e.amount = int(potency) if spec.status == Status.SHIELD else 0
	events.append(e)
	# Silenced monsters drop their special move right away (the player sees the intent change).
	if spec.status == Status.SILENCE and target.team == Team.ENEMY and _intents.has(target.id):
		_intents[target.id] = target.basic_ability()


func _resolve_targets(actor: CombatUnit, target_type: int, explicit_target: CombatUnit) -> Array[CombatUnit]:
	var result: Array[CombatUnit] = []
	match target_type:
		Target.SELF:
			result.append(actor)
		Target.ALL_OPPONENTS:
			result = _living_opponents(actor)
		Target.LOWEST_HP_ALLY:
			var allies: Array[CombatUnit] = []
			if actor.team == Team.PLAYER:
				allies.append(player)
			else:
				allies = enemies
			var best: CombatUnit = null
			for a in allies:
				if a.is_targetable() and (best == null or a.hp_ratio() < best.hp_ratio()):
					best = a
			if best != null:
				result.append(best)
		_:
			if explicit_target != null and explicit_target.is_targetable() and explicit_target.team != actor.team:
				result.append(explicit_target)
			else:
				var opponents := _living_opponents(actor)
				if not opponents.is_empty():
					result.append(opponents[0])
	return result


func _living_opponents(actor: CombatUnit) -> Array[CombatUnit]:
	if actor.team == Team.ENEMY:
		var l: Array[CombatUnit] = []
		if player.is_alive():
			l.append(player)
		return l
	return targetable_enemies()


func _apply_start_statuses(unit: CombatUnit, events: Array[BattleEvent]) -> void:
	for s in unit.statuses.duplicate():
		if not CombatTypes.is_dot(s.type) or not unit.is_alive():
			continue
		var dmg := maxi(1, roundi(unit.stats.max_hp * s.potency))
		unit.apply_damage(dmg)
		var e := _damage_event(null, unit, dmg, false, true)
		e.status = s.type
		events.append(e)
		if not unit.is_alive():
			events.append(_died_event(unit))
		_check_phases(unit, events)


func _end_turn_statuses(unit: CombatUnit, events: Array[BattleEvent]) -> void:
	for expired in unit.tick_status_durations():
		events.append(_status_event(BattleEvent.Type.STATUS_EXPIRED, unit, expired))


func _check_end(events: Array[BattleEvent]) -> bool:
	if phase == Phase.ENDED:
		return true
	var result: int = Outcome.NONE
	if not player.is_alive():
		result = Outcome.DEFEAT
	elif first_living_enemy() == null:
		result = Outcome.VICTORY
	if result == Outcome.NONE:
		return false
	outcome = result
	phase = Phase.ENDED
	_intents.clear()
	var e := BattleEvent.make(BattleEvent.Type.BATTLE_ENDED)
	e.outcome = result
	events.append(e)
	return true


static func _damage_event(src: CombatUnit, tgt: CombatUnit, value: int, is_crit: bool, dot: bool) -> BattleEvent:
	var e := BattleEvent.make(BattleEvent.Type.DAMAGE)
	e.source = src
	e.target = tgt
	e.amount = value
	e.crit = is_crit
	e.from_status = dot
	e.hp_after = tgt.current_hp
	return e

static func _heal_event(src: CombatUnit, tgt: CombatUnit, value: int) -> BattleEvent:
	var e := BattleEvent.make(BattleEvent.Type.HEAL)
	e.source = src
	e.target = tgt
	e.amount = value
	e.hp_after = tgt.current_hp
	return e

static func _died_event(tgt: CombatUnit) -> BattleEvent:
	var e := BattleEvent.make(BattleEvent.Type.UNIT_DIED)
	e.target = tgt
	return e

static func _status_event(type: BattleEvent.Type, tgt: CombatUnit, status: int) -> BattleEvent:
	var e := BattleEvent.make(type)
	e.target = tgt
	e.status = status
	return e
