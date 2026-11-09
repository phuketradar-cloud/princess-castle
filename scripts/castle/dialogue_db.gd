class_name DialogueDB
extends Resource
## All princess lines (res://data/dialogue_db.tres). pick() returns a random line among the
## MOST SPECIFIC matches, so "Dragon Sword" lines beat generic weapon lines, which beat
## generic "new item" lines, and personality lines beat neutral ones.

@export var lines: Array[DialogueLine] = []


func pick(trigger: String, ctx: Dictionary, rng: RandomSource = null) -> DialogueLine:
	var best := -1
	var candidates: Array[DialogueLine] = []
	for l in lines:
		if l == null:
			continue
		var s := l.score(trigger, ctx)
		if s < 0:
			continue
		if s > best:
			best = s
			candidates.clear()
		if s == best:
			candidates.append(l)
	if candidates.is_empty():
		return null
	var r := rng.value() if rng != null else randf()
	return candidates[mini(int(r * candidates.size()), candidates.size() - 1)]


## All lines of a trigger for one princess, in order (story events).
func sequence(trigger: String, princess_id: String) -> Array[DialogueLine]:
	var out: Array[DialogueLine] = []
	for l in lines:
		if l != null and l.trigger == trigger and l.princess_id == princess_id:
			out.append(l)
	return out


## Context dictionary for pick() from a princess (+ optional item).
static func context(princess: PrincessDefinition, bond_level := 0, item: EquipmentDefinition = null) -> Dictionary:
	var ctx := {"princess_id": princess.id, "personality": princess.personality, "bond": bond_level}
	if item != null:
		ctx.item_id = item.id
		ctx.slot = item.slot
		ctx.rarity = item.rarity
	return ctx
