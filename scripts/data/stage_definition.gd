class_name StageDefinition
extends Resource
## An adventure run: encounters fought back to back. HP carries over between battles
## (with a partial heal), so early choices matter. Mini boss / boss loot comes from each
## encounter's reward_tier.

@export var id: String = "stage_01"
@export var display_name: String = "Stage 1"
@export_multiline var description: String = ""
@export var encounters: Array[EncounterDefinition] = []
## Fraction of max HP restored after each won battle.
@export_range(0.0, 1.0) var heal_between_battles: float = 0.4
## Shown on the stage select screen.
@export var recommended_level: int = 1
## Stage that must be cleared first ("" = available from the start).
@export var unlock_after: String = ""

@export_group("Difficulty")
## Multiplies every monster's Max HP in this stage (later stages / progression).
@export var monster_hp_scale: float = 1.0
## Multiplies every monster's Attack in this stage.
@export var monster_attack_scale: float = 1.0


func boss_name() -> String:
	if encounters.is_empty() or encounters[-1] == null:
		return ""
	for m in encounters[-1].monsters:
		if m != null and m.is_boss:
			return m.display_name
	return ""
