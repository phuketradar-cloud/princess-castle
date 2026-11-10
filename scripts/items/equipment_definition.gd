class_name EquipmentDefinition
extends Resource
## One equipment item. Its texture is drawn ON the princess (paper doll), centered on the
## princess's anchor for this slot (+ layer_offset). Add items = new .tres, no code changes.

@export var id: String = ""
@export var display_name: String = ""
@export var slot: ItemTypes.Slot = ItemTypes.Slot.WEAPON
@export var rarity: ItemTypes.Rarity = ItemTypes.Rarity.COMMON
@export_multiline var description: String = ""

## Bonus stats added to the princess's base stats.
@export var stats: StatBlock

@export var special: ItemTypes.Special = ItemTypes.Special.NONE
@export var special_value: float = 0.0

@export_group("Visuals")
## Paper-doll layer art; also used as the icon.
@export var texture: Texture2D
## Fine-tune position relative to the princess's slot anchor (texture pixels).
@export var layer_offset: Vector2 = Vector2.ZERO
## Scale of the texture when drawn on the princess (high-res art, e.g. 0.46).
@export var layer_scale: float = 1.0


func bonus() -> StatBlock:
	return stats if stats != null else StatBlock.make(0, 0, 0)


## Lines like "ATK +6", "CRI +5%" for UI.
func stat_lines() -> Array[String]:
	return ItemStats.describe(bonus())
