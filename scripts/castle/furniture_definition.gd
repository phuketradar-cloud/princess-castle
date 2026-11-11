class_name FurnitureDefinition
extends Resource
## A piece of furniture for a princess's room. Its stat bonus applies ONLY to the owner of the
## room it is placed in, and furniture bonuses are capped with diminishing returns
## (see FurnitureRules). Skins are cosmetic only (never give stats).

@export var id: String = ""
@export var display_name: String = ""
@export var slot: CastleTypes.FurnitureSlot = CastleTypes.FurnitureSlot.BED
@export var rarity: ItemTypes.Rarity = ItemTypes.Rarity.COMMON
## Which wing it can be placed in (ANY = every room).
@export var room_type: CastleTypes.Wing = CastleTypes.Wing.ANY
@export_multiline var description: String = ""
@export var stats: StatBlock
## Cosmetic-only variant: stats are ignored.
@export var is_skin: bool = false
@export var texture: Texture2D
## Draw scale in the room (HD art from tools/build_room_art.gd is drawn larger).
@export var room_scale: float = 1.0
## Crafting cost: material key -> amount (empty = not craftable, e.g. starters / bond rewards).
@export var recipe: Dictionary = {}


func bonus() -> StatBlock:
	if is_skin or stats == null:
		return StatBlock.make(0, 0, 0)
	return stats


func fits(wing: int) -> bool:
	return room_type == CastleTypes.Wing.ANY or room_type == wing


func recipe_text() -> String:
	var parts: Array[String] = []
	for key in recipe:
		parts.append("%s x%d" % [CastleTypes.material_name(key), recipe[key]])
	return " + ".join(parts)
