class_name AbilitySpec
extends Resource
## Data for one ability (basic attack, princess skill or monster move).
## Stored inside .tres data files so new abilities need no code. Cards (Phase 3) reuse this.

@export var id: String = "attack"
@export var display_name: String = "Attack"
@export var target: CombatTypes.Target = CombatTypes.Target.SINGLE_OPPONENT

@export_group("Damage / Heal")
## Damage per hit = attack * damage_multiplier. 0 = no damage.
@export var damage_multiplier: float = 1.0
@export var hit_count: int = 1
## Heal = user's attack * heal_multiplier. 0 = no heal.
@export var heal_multiplier: float = 0.0

@export_group("Timing")
## Usable once every N own turns. 0 = always.
@export var cooldown: int = 0
## Own turns before the first use (lets monsters wind up big attacks).
@export var initial_cooldown: int = 0

@export_group("AI")
## Chance (0..1) a monster picks this when ready.
@export_range(0.0, 1.0) var ai_use_chance: float = 1.0
## Short label shown above monsters as intent ("HEAVY", "POISON").
@export var intent_tag: String = ""

@export_group("Execute")
## If > 0: targets at or below this HP ratio are executed (killed outright).
@export_range(0.0, 1.0) var execute_threshold: float = 0.0
## Bosses can't be executed; they take this × damage instead.
@export var execute_boss_multiplier: float = 3.0

@export_group("Status effect")
@export var status: CombatTypes.Status = CombatTypes.Status.NONE
@export var status_turns: int = 0
@export var status_potency: float = 0.0
@export_range(0.0, 1.0) var status_chance: float = 1.0


func deals_damage() -> bool:
	return damage_multiplier > 0.0

func heals() -> bool:
	return heal_multiplier > 0.0

func has_status() -> bool:
	return status != CombatTypes.Status.NONE and status_turns > 0 and status_chance > 0.0


static func make(p_id: String, p_name: String, p_target: CombatTypes.Target, dmg: float,
		p_cooldown := 0, hits := 1) -> AbilitySpec:
	var a := AbilitySpec.new()
	a.id = p_id
	a.display_name = p_name
	a.target = p_target
	a.damage_multiplier = dmg
	a.cooldown = p_cooldown
	a.hit_count = hits
	return a


## Builder helper: attach a status effect and return self.
func with_status(s: CombatTypes.Status, turns: int, potency: float, chance := 1.0) -> AbilitySpec:
	status = s
	status_turns = turns
	status_potency = potency
	status_chance = chance
	return self
