class_name ItemTypes
## Enums and display helpers for equipment.

enum Slot { WEAPON, HEADGEAR, WING, ARMOR, ACCESSORY }

enum Rarity { COMMON, RARE, EPIC, LEGENDARY, MYTHIC }

## Special effects make items more than numbers. Value meaning per effect:
enum Special {
	NONE,
	LIFESTEAL,   ## heal value × damage dealt (0.1 = 10%)
	THORNS,      ## reflect value × damage taken back to the attacker
	CRIT_POWER,  ## +value to the crit multiplier (0.5 = 1.5x → 2.0x)
	POISON_EDGE, ## value = chance per hit to poison (4% max HP, 2 turns)
}

## Reward tiers for loot quality (normal battle / mini boss / boss).
enum Tier { NORMAL, MINI_BOSS, BOSS }

const SLOT_NAMES := ["อาวุธ", "เครื่องประดับศีรษะ", "ปีก", "ชุดเกราะ", "เครื่องราง"]
const SLOT_NAMES_EN := ["Weapon", "Headgear", "Wing", "Armor", "Accessory"]
const RARITY_NAMES := ["Common", "Rare", "Epic", "Legendary", "Mythic"]
const RARITY_COLORS := [
	Color(0.80, 0.80, 0.84),
	Color(0.40, 0.70, 1.00),
	Color(0.78, 0.48, 1.00),
	Color(1.00, 0.72, 0.25),
	Color(1.00, 0.35, 0.45),
]

## Paper-doll draw order relative to the body (negative = behind the body).
const SLOT_Z := [4, 3, -1, 1, 2]


static func slot_name(slot: int) -> String:
	return SLOT_NAMES[slot]

static func rarity_name(r: int) -> String:
	return RARITY_NAMES[r]

static func rarity_color(r: int) -> Color:
	return RARITY_COLORS[r]

static func special_text(effect: int, value: float) -> String:
	match effect:
		Special.LIFESTEAL: return "ดูดเลือด %d%% ของดาเมจที่ทำ" % roundi(value * 100)
		Special.THORNS: return "สะท้อนดาเมจ %d%% กลับใส่ผู้โจมตี" % roundi(value * 100)
		Special.CRIT_POWER: return "คริติคอลแรงขึ้น +%d%%" % roundi(value * 100)
		Special.POISON_EDGE: return "โอกาส %d%% ทำให้ศัตรูติดพิษเมื่อโจมตี" % roundi(value * 100)
	return ""
