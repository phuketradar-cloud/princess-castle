class_name Synergy
extends Resource
## Passive bonus when two specific princesses adventure together (princess + companion).
## Each pair has its own flavour, e.g. Sword + Magic = stronger spell-blades,
## Sword + Light = healing, Shadow + Dragon = more critical hits.

@export var princess_a: String = ""
@export var princess_b: String = ""
@export var display_name: String = ""
@export_multiline var description: String = ""
## Flat stats added to the adventuring princess.
@export var stats: StatBlock
## +x damage dealt by the princess (0.15 = +15%).
@export var damage_bonus: float = 0.0
## Heals x × max HP at the start of each of her turns.
@export var regen: float = 0.0
## Extra mana at the start of battle.
@export var start_mana: int = 0


func matches(a: String, b: String) -> bool:
	return (princess_a == a and princess_b == b) or (princess_a == b and princess_b == a)
