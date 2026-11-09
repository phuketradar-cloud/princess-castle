class_name MonsterDefinition
extends Resource
## Static data for one monster type. Difficulty should come from abilities and enemy count,
## not only HP: poison, telegraphed heavy hits, healing, evasion...

@export var id: String = "slime"
@export var display_name: String = "Slime"
@export_multiline var description: String = ""

@export var base_stats: StatBlock
## Priority order. The AI uses the first ready ability that passes ai_use_chance.
## Put the basic attack LAST as the fallback.
@export var abilities: Array[AbilitySpec] = []

@export var is_boss: bool = false
## 0..1 chance to resist Stun. Bosses should have > 0.
@export_range(0.0, 1.0) var control_resistance: float = 0.0

## EXP the princess earns for defeating it (0 = automatic from HP / attack).
@export var exp_reward: int = 0
## Boss mechanics (one-time effects at HP thresholds).
@export var phases: Array[BossPhase] = []

## Essences dropped when this monster is defeated (card crafting material).
@export var drops: Array[EssenceDrop] = []

@export_group("Visuals")
@export var texture: Texture2D
@export var tint: Color = Color.WHITE
@export var visual_scale: float = 1.0


func exp_value() -> int:
	if exp_reward > 0:
		return exp_reward
	if base_stats == null:
		return 1
	return maxi(1, roundi(base_stats.max_hp / 6.0 + base_stats.attack * 0.8) * (3 if is_boss else 1))
