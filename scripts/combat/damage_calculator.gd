class_name DamageCalculator
## Stateless damage formula. Order:
##   1. Dodge roll   (defender evasion, capped by max_evasion)
##   2. Base         = attacker effective attack * multiplier
##   3. Variance     = * (1 ± damage_variance)
##   4. Defense      = * K / (K + defense)
##   5. Critical     = * crit_multiplier (chance = critical + luck * luck_to_crit, capped)
##   6. Defending    = * (1 - defend_damage_reduction)
##   7. Round, clamp to min_damage
## Returns {"dodged": bool, "crit": bool, "damage": int}


static func compute_hit(attacker: CombatUnit, defender: CombatUnit, multiplier: float,
		config: BattleConfig, rng: RandomSource) -> Dictionary:
	var evasion := clampf(defender.stats.evasion, 0.0, config.max_evasion)
	if rng.roll(evasion):
		return {"dodged": true, "crit": false, "damage": 0}

	var dmg := attacker.effective_attack() * multiplier
	dmg *= 1.0 + rng.range_f(-config.damage_variance, config.damage_variance)

	var k := maxf(1.0, config.defense_constant)
	dmg *= k / (k + maxi(0, defender.stats.defense))

	var crit_chance := clampf(attacker.stats.critical + attacker.crit_buff() + attacker.stats.luck * config.luck_to_crit,
		0.0, config.max_crit_chance)
	var crit := rng.roll(crit_chance)
	if crit:
		dmg *= config.crit_multiplier + attacker.crit_bonus

	dmg *= 1.0 + attacker.damage_bonus

	if defender.is_defending:
		dmg *= 1.0 - clampf(config.defend_damage_reduction, 0.0, 0.95)

	return {"dodged": false, "crit": crit, "damage": maxi(config.min_damage, roundi(dmg))}


## Damage estimate without randomness, for intent previews.
static func estimate(attacker: CombatUnit, defender: CombatUnit, multiplier: float, config: BattleConfig) -> int:
	var k := maxf(1.0, config.defense_constant)
	var dmg := attacker.effective_attack() * multiplier * k / (k + maxi(0, defender.stats.defense)) * (1.0 + attacker.damage_bonus)
	return maxi(config.min_damage, roundi(dmg))
