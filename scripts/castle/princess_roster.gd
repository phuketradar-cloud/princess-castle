class_name PrincessRoster
extends Resource
## All princesses + castle content (res://data/princess_roster.tres).
## Add a princess = add a PrincessDefinition here; her wing, unlock rule, face art and
## lines are all data.

@export var princesses: Array[PrincessDefinition] = []
@export var furniture: Array[FurnitureDefinition] = []
## Furniture every room starts with (one per slot).
@export var starter_furniture: Array[FurnitureDefinition] = []
@export var dialogue: DialogueDB
## Phase 5: adventure stages in order, and princess pair bonuses.
@export var stages: Array[StageDefinition] = []
@export var synergies: Array[Synergy] = []
## Room backgrounds / furniture positions per wing (rooms without one use defaults).
@export var room_layouts: Array[RoomLayout] = []


func find(princess_id: String) -> PrincessDefinition:
	for p in princesses:
		if p != null and p.id == princess_id:
			return p
	return null


func find_furniture(furniture_id: String) -> FurnitureDefinition:
	for f in furniture:
		if f != null and f.id == furniture_id:
			return f
	for f in starter_furniture:
		if f != null and f.id == furniture_id:
			return f
	return null


func craftable_furniture() -> Array[FurnitureDefinition]:
	var out: Array[FurnitureDefinition] = []
	for f in furniture:
		if f != null and not f.recipe.is_empty():
			out.append(f)
	return out


func layout_for(wing: int) -> RoomLayout:
	for l in room_layouts:
		if l != null and l.wing == wing:
			return l
	return null


func find_stage(stage_id: String) -> StageDefinition:
	for s in stages:
		if s != null and s.id == stage_id:
			return s
	return null


func synergy_for(a: String, b: String) -> Synergy:
	if a == "" or b == "" or a == b:
		return null
	for s in synergies:
		if s != null and s.matches(a, b):
			return s
	return null
