class_name UnitFactory
## Converts definitions (Resources) into runtime CombatUnits.
## This is the single place where bonuses are combined: base stats + equipment
## (later: furniture, companion, bond).


## extra = furniture bonus from her room (already capped by FurnitureRules).
static func create_princess(def: PrincessDefinition, unit_id: int, current_hp := -1, equipment: Array = [], extra: StatBlock = null, level := 1) -> CombatUnit:
	if def == null or def.base_stats == null:
		push_error("UnitFactory: princess definition or its base_stats is missing")
		return null
	var stats := ItemStats.total(def.level_stats(level), equipment)
	if extra != null:
		stats = stats.plus(extra)
	stats.max_hp = maxi(1, stats.max_hp)
	var unit := CombatUnit.new(unit_id, def.id, def.display_name, CombatTypes.Team.PLAYER,
		stats, def.abilities, false, 0.0, current_hp)
	apply_specials(unit, equipment)
	return unit


## hp_scale / attack_scale come from the stage (difficulty knob).
static func create_monster(def: MonsterDefinition, unit_id: int, hp_scale := 1.0, attack_scale := 1.0) -> CombatUnit:
	if def == null or def.base_stats == null:
		push_error("UnitFactory: monster definition or its base_stats is missing")
		return null
	var s := def.base_stats
	var stats := StatBlock.make(maxi(1, roundi(s.max_hp * hp_scale)), maxi(1, roundi(s.attack * attack_scale)),
		s.defense, s.critical, s.evasion, s.luck)
	var unit := CombatUnit.new(unit_id, def.id, def.display_name, CombatTypes.Team.ENEMY,
		stats, def.abilities, def.is_boss, def.control_resistance)
	unit.phases = def.phases.duplicate()
	unit.exp_reward = roundi(def.exp_value() * maxf(hp_scale, attack_scale))
	return unit


## Equipment special effects stack additively.
static func apply_specials(unit: CombatUnit, equipment: Array) -> void:
	for item in equipment:
		if item == null:
			continue
		match item.special:
			ItemTypes.Special.LIFESTEAL: unit.lifesteal += item.special_value
			ItemTypes.Special.THORNS: unit.thorns += item.special_value
			ItemTypes.Special.CRIT_POWER: unit.crit_bonus += item.special_value
			ItemTypes.Special.POISON_EDGE: unit.poison_on_hit += item.special_value


## Princess + companion pair bonus (Phase 5).
static func apply_synergy(unit: CombatUnit, synergy: Synergy) -> void:
	if synergy == null or unit == null:
		return
	unit.damage_bonus += synergy.damage_bonus
	unit.regen += synergy.regen


## The companion as a back-row unit (her level stats + her own gear; never targeted).
static func create_companion(def: PrincessDefinition, unit_id: int, level: int, equipment: Array) -> CombatUnit:
	var stats := ItemStats.total(def.level_stats(level), equipment)
	var unit := CombatUnit.new(unit_id, def.id, def.display_name, CombatTypes.Team.PLAYER, stats, [def.assist])
	unit.is_companion = true
	apply_specials(unit, equipment)
	return unit
