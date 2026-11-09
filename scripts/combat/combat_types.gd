class_name CombatTypes
## Shared enums for the combat system. Pure data, no nodes.

enum Team { PLAYER, ENEMY }

enum Target {
	SINGLE_OPPONENT, ## one enemy of the user (player picks, AI hits the princess)
	ALL_OPPONENTS,   ## every living (targetable) opponent
	SELF,            ## the user
	LOWEST_HP_ALLY,  ## living ally (incl. self) with the lowest HP ratio
}

## Values are saved in .tres files: only ever APPEND new statuses.
enum Status {
	NONE,
	POISON,  ## damage at turn start; potency = fraction of victim max HP
	STUN,    ## victim skips its turn
	WEAKEN,  ## attack reduced; potency = fraction removed (0.3 = -30%)
	FREEZE,  ## Ice Prison: cannot act
	BANISH,  ## removed from the field: cannot act, cannot be targeted, returns when it ends
	SLEEP,   ## cannot act; wakes up when damaged
	SILENCE, ## can only use its basic attack (no special abilities)
	SHIELD,  ## absorbs damage; potency = attack multiplier when applied, then remaining absorb
	LUCKY,   ## +potency crit chance
	BURN,    ## like poison (fire); potency = fraction of victim max HP
}

enum Phase { NOT_STARTED, PLAYER_TURN, ENEMY_TURN, ENDED }

enum Outcome { NONE, VICTORY, DEFEAT }

const STATUS_NAMES := {
	Status.POISON: "POISON", Status.STUN: "STUN", Status.WEAKEN: "WEAKEN", Status.FREEZE: "FREEZE",
	Status.BANISH: "BANISH", Status.SLEEP: "SLEEP", Status.SILENCE: "SILENCE", Status.SHIELD: "SHIELD",
	Status.LUCKY: "LUCKY", Status.BURN: "BURN",
}


static func status_name(s: int) -> String:
	return STATUS_NAMES.get(s, "")


## Control effects: bosses get reduced duration / resistance (and are immune to Banish).
static func is_control(s: int) -> bool:
	return s in [Status.STUN, Status.FREEZE, Status.SLEEP, Status.BANISH]


## Statuses that make the unit skip its turn.
static func blocks_action(s: int) -> bool:
	return s in [Status.STUN, Status.FREEZE, Status.SLEEP, Status.BANISH]


## Damage-over-time statuses (tick at turn start).
static func is_dot(s: int) -> bool:
	return s == Status.POISON or s == Status.BURN


## Self buffs are never resisted.
static func is_buff(s: int) -> bool:
	return s == Status.SHIELD or s == Status.LUCKY
