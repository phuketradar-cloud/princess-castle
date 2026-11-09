class_name EncounterDefinition
extends Resource
## One battle: monsters that appear together (max = number of enemy slots in the battle scene).

@export var display_name: String = "Encounter"
@export var monsters: Array[MonsterDefinition] = []
## Loot quality after winning: NORMAL, MINI_BOSS (better) or BOSS (best).
@export var reward_tier: ItemTypes.Tier = ItemTypes.Tier.NORMAL
