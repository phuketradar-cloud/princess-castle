class_name CraftRecipe
extends Resource
## Essences -> card. cost keys are essence keys ("fire", "ice", ...) -> amount.

@export var result: CardDefinition
@export var cost: Dictionary = {}


func cost_text() -> String:
	var parts: Array[String] = []
	for key in cost:
		parts.append("%s x%d" % [CardTypes.ELEMENT_NAMES[CardTypes.element_from_key(key)], cost[key]])
	return " + ".join(parts)
