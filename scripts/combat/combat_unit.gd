class_name CombatUnit
extends RefCounted
## A princess or monster inside one battle. Pure logic: no nodes, so whole battles run in tests.

## Runtime cooldown state of one ability.
class AbilityState:
	var spec: AbilitySpec
	var cooldown_remaining: int = 0

	func _init(p_spec: AbilitySpec) -> void:
		spec = p_spec
		cooldown_remaining = maxi(0, p_spec.initial_cooldown)

	func is_ready() -> bool:
		return cooldown_remaining <= 0


## A status currently active on this unit.
class StatusInstance:
	var type: int
	var remaining_turns: int
	var potency: float

	func _init(p_type: int, p_turns: int, p_potency: float) -> void:
		type = p_type
		remaining_turns = p_turns
		potency = p_potency


var id: int
var definition_id: String
var unit_name: String
var team: int
var stats: StatBlock
var current_hp: int
var is_boss: bool
## 0..1 chance to resist control effects (Stun). Bosses use this.
var control_resistance: float
var is_defending := false

## Special-effect modifiers (from equipment; later cards / companions).
var lifesteal := 0.0       ## heal this × damage dealt
var thorns := 0.0          ## reflect this × damage taken
var crit_bonus := 0.0      ## added to the crit multiplier
var poison_on_hit := 0.0   ## chance per hit to poison the target

## Phase 5 modifiers.
var attack_mult := 1.0     ## boss enrage
var damage_bonus := 0.0    ## companion synergy: +x damage dealt
var regen := 0.0           ## heal x × max HP at the start of each own turn
var phases: Array = []     ## BossPhase list (bosses)
var phases_done: Array[int] = []
var is_companion := false  ## supports from the back row; enemies never target her
var exp_reward := 0        ## EXP the princess gets for defeating this unit

var abilities: Array[AbilityState] = []
var statuses: Array[StatusInstance] = []


func _init(p_id: int, p_def_id: String, p_name: String, p_team: int, p_stats: StatBlock,
		p_abilities: Array, p_boss := false, p_resist := 0.0, starting_hp := -1) -> void:
	assert(p_stats != null and p_stats.max_hp > 0, "Unit '%s' needs max_hp > 0" % p_name)
	id = p_id
	definition_id = p_def_id
	unit_name = p_name if p_name != "" else "Unknown"
	team = p_team
	stats = p_stats
	is_boss = p_boss
	control_resistance = clampf(p_resist, 0.0, 1.0)
	current_hp = stats.max_hp if starting_hp < 0 else clampi(starting_hp, 1, stats.max_hp)
	for spec in p_abilities:
		if spec != null:
			abilities.append(AbilityState.new(spec))
	# Every unit must be able to act: fall back to a plain attack if data forgot one.
	if abilities.is_empty():
		abilities.append(AbilityState.new(AbilitySpec.make("attack", "Attack", CombatTypes.Target.SINGLE_OPPONENT, 1.0)))


func is_alive() -> bool:
	return current_hp > 0

func hp_ratio() -> float:
	return float(current_hp) / float(stats.max_hp)

## Attack after Weaken.
func effective_attack() -> float:
	var mult := 1.0
	for s in statuses:
		if s.type == CombatTypes.Status.WEAKEN:
			mult -= s.potency
	return stats.attack * attack_mult * maxf(0.1, mult)

func has_status(type: int) -> bool:
	for s in statuses:
		if s.type == type:
			return true
	return false

func get_status(type: int) -> StatusInstance:
	for s in statuses:
		if s.type == type:
			return s
	return null

func remove_status(type: int) -> bool:
	for i in statuses.size():
		if statuses[i].type == type:
			statuses.remove_at(i)
			return true
	return false

## Banished units are alive but off the field.
func is_targetable() -> bool:
	return is_alive() and not has_status(CombatTypes.Status.BANISH)

## First status that stops this unit from acting (STUN/FREEZE/SLEEP/BANISH), or NONE.
func action_blocker() -> int:
	for s in statuses:
		if CombatTypes.blocks_action(s.type):
			return s.type
	return CombatTypes.Status.NONE

## Crit chance bonus from buffs (Lucky Day).
func crit_buff() -> float:
	var s := get_status(CombatTypes.Status.LUCKY)
	return s.potency if s != null else 0.0

## The basic attack = last ability (what Silence allows).
func basic_ability() -> AbilityState:
	return abilities[abilities.size() - 1]

func find_ability(ability_id: String) -> AbilityState:
	for a in abilities:
		if a.spec.id == ability_id:
			return a
	return null

func apply_damage(value: int) -> int:
	var before := current_hp
	current_hp = maxi(0, current_hp - maxi(0, value))
	return before - current_hp

func apply_heal(value: int) -> int:
	if not is_alive() or value <= 0:
		return 0
	var before := current_hp
	current_hp = mini(stats.max_hp, current_hp + value)
	return current_hp - before

## Same-type statuses don't stack; the longer duration wins.
func add_status(type: int, turns: int, potency: float) -> void:
	for s in statuses:
		if s.type == type:
			s.remaining_turns = maxi(s.remaining_turns, turns)
			return
	statuses.append(StatusInstance.new(type, turns, potency))

## End of this unit's own turn. Returns the types that expired.
func tick_status_durations() -> Array[int]:
	var expired: Array[int] = []
	for i in range(statuses.size() - 1, -1, -1):
		statuses[i].remaining_turns -= 1
		if statuses[i].remaining_turns <= 0:
			expired.append(statuses[i].type)
			statuses.remove_at(i)
	return expired

func tick_cooldowns() -> void:
	for a in abilities:
		if a.cooldown_remaining > 0:
			a.cooldown_remaining -= 1


func _to_string() -> String:
	return "%s#%d (%d/%d)" % [unit_name, id, current_hp, stats.max_hp]
