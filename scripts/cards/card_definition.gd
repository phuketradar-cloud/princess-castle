class_name CardDefinition
extends Resource
## A collectible battle card. Its effect is an AbilitySpec (same system as skills),
## so new cards are pure data. Played with mana; each deck card is usable once per battle.

@export var id: String = ""
@export var display_name: String = ""
@export var category: CardTypes.Category = CardTypes.Category.ATTACK
@export var element: CardTypes.Element = CardTypes.Element.FIRE
@export var rarity: ItemTypes.Rarity = ItemTypes.Rarity.COMMON
@export_multiline var description: String = ""
@export var mana_cost: int = 1
@export var effect: AbilitySpec
@export var icon: Texture2D
## Chance weight to appear as a battle reward (0 = only via crafting / fusion).
@export var drop_weight: float = 1.0
## Princess id that can use this card ("" = everyone). Bond Lv5 cards are exclusive.
@export var exclusive_to: String = ""


func usable_by(princess_id: String) -> bool:
	return exclusive_to == "" or exclusive_to == princess_id


func needs_target() -> bool:
	return effect != null and effect.target == CombatTypes.Target.SINGLE_OPPONENT
