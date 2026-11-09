class_name EnemyBrain
extends RefCounted
## Default monster AI. Abilities are listed in priority order in data:
## the first ready ability that makes sense and passes its ai_use_chance roll is chosen.
## The last ability (basic attack) is the fallback.
## Extend this class and override plan() for bosses with custom behaviour.

## Healing is only considered when an ally is below this HP ratio.
var heal_threshold := 0.6


## Returns the CombatUnit.AbilityState to use on the coming enemy turn.
func plan(unit: CombatUnit, allies: Array[CombatUnit], _player: CombatUnit, rng: RandomSource) -> CombatUnit.AbilityState:
	# Silenced monsters can only use their basic attack.
	if unit.has_status(CombatTypes.Status.SILENCE):
		return unit.basic_ability()
	var needs_heal := _any_ally_needs_healing(allies)
	var fallback: CombatUnit.AbilityState = null

	for a in unit.abilities:
		if not a.is_ready():
			continue
		if a.spec.heals() and not needs_heal:
			continue
		fallback = a
		if rng.roll(a.spec.ai_use_chance):
			return a

	if fallback != null:
		return fallback
	return unit.abilities[unit.abilities.size() - 1]


func _any_ally_needs_healing(allies: Array[CombatUnit]) -> bool:
	for a in allies:
		if a.is_alive() and a.hp_ratio() < heal_threshold:
			return true
	return false
