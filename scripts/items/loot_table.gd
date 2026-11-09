class_name LootTable
extends Resource
## Post-battle reward generation. All odds live in data (res://data/loot_table.tres).

## One choice on the "Choose a Reward" screen.
class RewardOption:
	enum Kind { EQUIPMENT, RESTORE, CARD }
	var kind: Kind
	var item: EquipmentDefinition
	var card: CardDefinition
	var heal_fraction := 0.0

	static func card_option(p_card: CardDefinition) -> RewardOption:
		var o := RewardOption.new()
		o.kind = Kind.CARD
		o.card = p_card
		return o

	static func equipment(p_item: EquipmentDefinition) -> RewardOption:
		var o := RewardOption.new()
		o.kind = Kind.EQUIPMENT
		o.item = p_item
		return o

	static func restore(fraction: float) -> RewardOption:
		var o := RewardOption.new()
		o.kind = Kind.RESTORE
		o.heal_fraction = fraction
		return o


@export var items: Array[EquipmentDefinition] = []

@export_group("Rarity weights (Common, Rare, Epic, Legendary, Mythic)")
@export var normal_weights: PackedFloat32Array = PackedFloat32Array([60, 30, 9, 1, 0])
@export var mini_boss_weights: PackedFloat32Array = PackedFloat32Array([15, 45, 30, 9, 1])
@export var boss_weights: PackedFloat32Array = PackedFloat32Array([0, 25, 45, 24, 6])

@export_group("Options")
## Kinds offered, in order: "equipment" | "card" | "restore".
@export var option_kinds: PackedStringArray = PackedStringArray(["equipment", "equipment", "card"])
## HP restored (fraction of max) by the "restore" option.
@export var restore_fraction := 0.35
## Source of "card" rewards (Phase 3).
@export var card_library: CardLibrary


func find(item_id: String) -> EquipmentDefinition:
	for it in items:
		if it != null and it.id == item_id:
			return it
	return null


## Rolls the reward choices. Owned items are skipped while unowned ones exist,
## and the same item never appears twice in one roll.
## allow_restore = false after the last battle of a stage (healing would be useless):
## the restore slot becomes another equipment roll.
func roll_options(tier: int, rng: RandomSource, owned_ids: Array, allow_restore := true) -> Array[RewardOption]:
	var options: Array[RewardOption] = []
	var taken: Array[String] = []
	for kind in option_kinds:
		if kind == "restore" and allow_restore:
			options.append(RewardOption.restore(restore_fraction))
			continue
		if kind == "card" and card_library != null:
			var card := card_library.roll_card(tier, rng)
			if card != null:
				options.append(RewardOption.card_option(card))
				continue
		var item := roll_item(tier, rng, owned_ids + taken)
		if item == null:
			options.append(RewardOption.restore(restore_fraction))
		else:
			taken.append(item.id)
			options.append(RewardOption.equipment(item))
	return options


## Picks a rarity by weight, then a random item of that rarity not in `exclude`.
## Falls back to the nearest rarity that still has items.
func roll_item(tier: int, rng: RandomSource, exclude: Array) -> EquipmentDefinition:
	var rarity := roll_rarity(tier, rng)
	for distance in 5:
		for r in [rarity - distance, rarity + distance]:
			if r < 0 or r > ItemTypes.Rarity.MYTHIC:
				continue
			var pool := items.filter(func(it): return it != null and it.rarity == r and not exclude.has(it.id))
			if not pool.is_empty():
				return pool[mini(int(rng.value() * pool.size()), pool.size() - 1)]
	return null


func roll_rarity(tier: int, rng: RandomSource) -> int:
	var w := weights_for(tier)
	var total := 0.0
	for x in w:
		total += maxf(0.0, x)
	if total <= 0.0:
		return ItemTypes.Rarity.COMMON
	var pick := rng.value() * total
	for i in w.size():
		pick -= maxf(0.0, w[i])
		if pick < 0.0:
			return i
	return w.size() - 1


func weights_for(tier: int) -> PackedFloat32Array:
	match tier:
		ItemTypes.Tier.MINI_BOSS: return mini_boss_weights
		ItemTypes.Tier.BOSS: return boss_weights
	return normal_weights
