class_name ItemStats
## Helpers to combine and describe equipment stats.


## Base stats + every item's bonus.
static func total(base: StatBlock, items: Array) -> StatBlock:
	var s := StatBlock.make(base.max_hp, base.attack, base.defense, base.critical, base.evasion, base.luck)
	for item in items:
		if item != null:
			s = s.plus(item.bonus())
	return s


## Non-zero stats as readable lines.
static func describe(s: StatBlock, show_sign := true) -> Array[String]:
	var lines: Array[String] = []
	var plus := "+" if show_sign else ""
	if s.max_hp != 0: lines.append("HP %s%d" % [plus if s.max_hp > 0 else "", s.max_hp])
	if s.attack != 0: lines.append("ATK %s%d" % [plus if s.attack > 0 else "", s.attack])
	if s.defense != 0: lines.append("DEF %s%d" % [plus if s.defense > 0 else "", s.defense])
	if not is_zero_approx(s.critical): lines.append("CRI %s%d%%" % [plus if s.critical > 0 else "", roundi(s.critical * 100)])
	if not is_zero_approx(s.evasion): lines.append("EVA %s%d%%" % [plus if s.evasion > 0 else "", roundi(s.evasion * 100)])
	if not is_zero_approx(s.luck): lines.append("LUK %s%d" % [plus if s.luck > 0 else "", roundi(s.luck)])
	return lines


## Difference new - old (for "compare with equipped").
static func diff(new_s: StatBlock, old_s: StatBlock) -> StatBlock:
	return StatBlock.make(new_s.max_hp - old_s.max_hp, new_s.attack - old_s.attack, new_s.defense - old_s.defense,
		new_s.critical - old_s.critical, new_s.evasion - old_s.evasion, new_s.luck - old_s.luck)


## Rough "power" of an item, used by the auto player and to sort the bag.
static func power(item: EquipmentDefinition) -> float:
	if item == null:
		return 0.0
	var s := item.bonus()
	var p := s.max_hp * 0.5 + s.attack * 3.0 + s.defense * 2.0 + s.critical * 150.0 + s.evasion * 150.0 + s.luck * 0.3
	match item.special:
		ItemTypes.Special.LIFESTEAL: p += item.special_value * 120.0
		ItemTypes.Special.THORNS: p += item.special_value * 80.0
		ItemTypes.Special.CRIT_POWER: p += item.special_value * 30.0
		ItemTypes.Special.POISON_EDGE: p += item.special_value * 40.0
	return p
