class_name PlayerCommand
extends RefCounted
## What the princess does this turn.

enum Kind { USE_ABILITY, DEFEND }

var kind: Kind = Kind.USE_ABILITY
var ability_id: String = ""
## Selected enemy unit id, or -1 to auto-pick the first living enemy.
var target_id: int = -1


static func use_ability(p_ability_id: String, p_target_id := -1) -> PlayerCommand:
	var c := PlayerCommand.new()
	c.kind = Kind.USE_ABILITY
	c.ability_id = p_ability_id
	c.target_id = p_target_id
	return c


static func defend() -> PlayerCommand:
	var c := PlayerCommand.new()
	c.kind = Kind.DEFEND
	return c
