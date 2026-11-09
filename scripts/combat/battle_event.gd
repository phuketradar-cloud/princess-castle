class_name BattleEvent
extends RefCounted
## One thing that happened in battle. The engine returns ordered lists of these;
## the scene replays them as animations, tests just inspect them.
## Rules (engine) and presentation (views) stay fully separated.

enum Type {
	TURN_STARTED,    ## side, round
	ACTION_STARTED,  ## source, ability
	DAMAGE,          ## source (null = poison), target, amount, crit, from_status, hp_after
	DODGE,           ## source, target
	HEAL,            ## source, target, amount, hp_after
	DEFEND,          ## source
	STATUS_APPLIED,  ## target, status, turns
	STATUS_RESISTED, ## target, status
	STATUS_EXPIRED,  ## target, status
	TURN_SKIPPED,    ## source, reason
	UNIT_DIED,       ## target
	INTENTS_CHANGED, ## enemies re-planned (start of each player turn)
	BATTLE_ENDED,    ## outcome
	BOSS_PHASE,      ## source = boss, reason = announcement (Phase 5)
	UNIT_SUMMONED,   ## target = the new monster (Phase 5)
}

var type: Type
var source: CombatUnit
var target: CombatUnit
var ability: AbilitySpec
var amount: int = 0
var hp_after: int = 0
var crit: bool = false
var from_status: bool = false
## DAMAGE caused by Thorns (reflected back at the attacker).
var reflected: bool = false
## DAMAGE soaked by a Shield (not included in amount).
var absorbed: int = 0
## DAMAGE that executed the target.
var executed: bool = false
## ACTION_STARTED from a card (null for normal attacks / skills).
var card: CardDefinition
var status: int = CombatTypes.Status.NONE
var turns: int = 0
var side: int = CombatTypes.Team.PLAYER
var round_number: int = 0
var reason: String = ""
var outcome: int = CombatTypes.Outcome.NONE


static func make(p_type: Type) -> BattleEvent:
	var e := BattleEvent.new()
	e.type = p_type
	return e


func _to_string() -> String:
	return "%s(%s -> %s, %d)" % [Type.keys()[type], source.unit_name if source else "-",
		target.unit_name if target else "-", amount]
