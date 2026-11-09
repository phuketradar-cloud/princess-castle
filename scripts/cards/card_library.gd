class_name CardLibrary
extends Resource
## All cards + crafting and fusion recipes (res://data/card_library.tres).
## Add a card or recipe = add it here in the Inspector.

@export var cards: Array[CardDefinition] = []
@export var craft_recipes: Array[CraftRecipe] = []
@export var fusion_recipes: Array[FusionRecipe] = []
## Cards every new player starts with (also put in the starting deck).
@export var starting_cards: Array[CardDefinition] = []
@export var max_deck_size: int = 5

@export_group("Card reward rarity weights (Common..Mythic)")
@export var normal_weights: PackedFloat32Array = PackedFloat32Array([60, 32, 8, 0, 0])
@export var mini_boss_weights: PackedFloat32Array = PackedFloat32Array([25, 45, 25, 5, 0])
@export var boss_weights: PackedFloat32Array = PackedFloat32Array([0, 35, 45, 18, 2])


func find(card_id: String) -> CardDefinition:
	for c in cards:
		if c != null and c.id == card_id:
			return c
	return null


func craft_recipe_for(card_id: String) -> CraftRecipe:
	for r in craft_recipes:
		if r != null and r.result != null and r.result.id == card_id:
			return r
	return null


## Random droppable card for a reward, weighted by rarity tier then drop_weight.
func roll_card(tier: int, rng: RandomSource) -> CardDefinition:
	var weights := normal_weights
	if tier == ItemTypes.Tier.MINI_BOSS:
		weights = mini_boss_weights
	elif tier == ItemTypes.Tier.BOSS:
		weights = boss_weights
	var total := 0.0
	var entries := []
	for c in cards:
		if c == null or c.drop_weight <= 0.0 or c.rarity >= weights.size():
			continue
		var w := weights[c.rarity] * c.drop_weight
		if w > 0.0:
			entries.append([c, w])
			total += w
	if total <= 0.0:
		return null
	var pick := rng.value() * total
	for e in entries:
		pick -= e[1]
		if pick < 0.0:
			return e[0]
	return entries[entries.size() - 1][0]
