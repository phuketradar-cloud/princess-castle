class_name StatBlock
extends Resource
## Combat stats shared by princesses and monsters.
## critical / evasion are probabilities 0..1 (0.1 = 10%). luck is points (adds crit chance via BattleConfig).

@export var max_hp: int = 100
@export var attack: int = 10
@export var defense: int = 0
@export_range(0.0, 1.0) var critical: float = 0.0
@export_range(0.0, 1.0) var evasion: float = 0.0
@export var luck: float = 0.0


static func make(hp: int, atk: int, def: int, crit := 0.0, eva := 0.0, lck := 0.0) -> StatBlock:
	var s := StatBlock.new()
	s.max_hp = hp
	s.attack = atk
	s.defense = def
	s.critical = crit
	s.evasion = eva
	s.luck = lck
	return s


## Component-wise sum. Equipment / furniture bonuses (later phases) use this.
func plus(other: StatBlock) -> StatBlock:
	return StatBlock.make(max_hp + other.max_hp, attack + other.attack, defense + other.defense,
		critical + other.critical, evasion + other.evasion, luck + other.luck)
