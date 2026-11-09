class_name FusionRecipe
extends Resource
## Cards -> a stronger card. List the same card several times to require copies
## (e.g. Fireball, Fireball, Fireball -> Fire Blast). The input cards are consumed.

@export var inputs: Array[CardDefinition] = []
@export var result: CardDefinition


## card id -> copies needed
func needed() -> Dictionary:
	var n := {}
	for c in inputs:
		if c != null:
			n[c.id] = n.get(c.id, 0) + 1
	return n


func inputs_text() -> String:
	var parts: Array[String] = []
	var n := needed()
	for c in inputs:
		if c != null and n.has(c.id):
			parts.append("%s x%d" % [c.display_name, n[c.id]])
			n.erase(c.id)
	return " + ".join(parts)
