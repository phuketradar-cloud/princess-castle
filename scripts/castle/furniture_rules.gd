class_name FurnitureRules
## Furniture stat bonuses with balance limits:
##  - only furniture in the princess's OWN room counts
##  - per-stat cap with diminishing returns:  effective = cap * raw / (raw + cap)
##    (the first points count almost fully, stacking more approaches but never reaches the cap)
##  - skins give nothing

## Max effective bonus per stat. Edit here to rebalance.
const CAPS := {"max_hp": 40.0, "attack": 6.0, "defense": 6.0, "critical": 0.0, "evasion": 0.06, "luck": 30.0}


static func diminish(raw: float, cap: float) -> float:
	if raw <= 0.0 or cap <= 0.0:
		return 0.0
	return cap * raw / (raw + cap)


## Effective bonus from a list of furniture (all from ONE room).
static func room_bonus(furniture: Array) -> StatBlock:
	var raw := {"max_hp": 0.0, "attack": 0.0, "defense": 0.0, "critical": 0.0, "evasion": 0.0, "luck": 0.0}
	for f in furniture:
		if f == null:
			continue
		var b: StatBlock = f.bonus()
		raw.max_hp += b.max_hp
		raw.attack += b.attack
		raw.defense += b.defense
		raw.critical += b.critical
		raw.evasion += b.evasion
		raw.luck += b.luck
	return StatBlock.make(
		roundi(diminish(raw.max_hp, CAPS.max_hp)),
		roundi(diminish(raw.attack, CAPS.attack)),
		roundi(diminish(raw.defense, CAPS.defense)),
		diminish(raw.critical, CAPS.critical),
		snappedf(diminish(raw.evasion, CAPS.evasion), 0.001),
		roundf(diminish(raw.luck, CAPS.luck)))
