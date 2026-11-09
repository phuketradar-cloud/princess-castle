class_name BattleConfig
extends Resource
## Global combat formula values (data/balance_config.tres). Tune in the Inspector, no code changes.

## Random damage spread, 0.1 = ±10%.
@export var damage_variance: float = 0.1
@export var crit_multiplier: float = 1.5
## Defense mitigation: damage *= K / (K + defense). Diminishing returns, never reaches zero.
@export var defense_constant: float = 50.0
@export var min_damage: int = 1
@export var max_evasion: float = 0.6
@export var max_crit_chance: float = 0.75
## Crit chance added per Luck point.
@export var luck_to_crit: float = 0.002
## Damage taken while defending *= (1 - this).
@export var defend_damage_reduction: float = 0.5
## Defend also heals this fraction of max HP.
@export var defend_heal_fraction: float = 0.05

@export_group("Cards / Mana")
## Mana at the start of each battle.
@export var start_mana: int = 1
## Mana gained at the start of each later player turn.
@export var mana_per_turn: int = 1
@export var max_mana: int = 6
## Each card in the deck can be played this many times per battle.
@export var card_uses_per_battle: int = 1


## Copy with a princess's mana perks applied (Magic Princess: +1 start, +1 max).
func with_mana_bonus(start_bonus: int, max_bonus: int) -> BattleConfig:
	var c: BattleConfig = duplicate()
	c.start_mana += start_bonus
	c.max_mana += max_bonus
	return c
