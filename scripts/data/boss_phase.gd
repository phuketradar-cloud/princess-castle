class_name BossPhase
extends Resource
## A boss mechanic that fires ONCE when the boss's HP ratio drops to `hp_threshold`.
## Several effects can be combined in one phase (e.g. enrage + cleanse).
## Data-driven: add phases to a MonsterDefinition in the Inspector.

@export_range(0.0, 1.0) var hp_threshold: float = 0.5
## Shown on screen when the phase starts ("The Lich Queen calls her guard!").
@export var announce: String = ""

@export_group("Effects")
## Attack multiplier added permanently (0.4 = +40% attack).
@export var enrage: float = 0.0
## Removes all negative statuses from the boss.
@export var cleanse: bool = false
## Shield = this × boss max HP (absorbs damage).
@export var shield_fraction: float = 0.0
## Heals this × boss max HP.
@export var heal_fraction: float = 0.0
## Monsters called to the battle (field limit applies).
@export var summons: Array[MonsterDefinition] = []
