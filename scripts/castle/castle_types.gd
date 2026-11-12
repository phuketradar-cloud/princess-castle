class_name CastleTypes
## Enums and tables for the castle: wings, personalities, furniture slots, activities,
## expressions and crafting materials.

## One wing per princess archetype (same order as PrincessDefinition.Archetype).
enum Wing { SWORD, MAGIC, SHADOW, LIGHT, DRAGON, ANY }

enum Personality { BRAVE, SCHOLARLY, MYSTERIOUS, GENTLE, PROUD }

enum FurnitureSlot { BED, DESK, TRAINING, DECOR }

## Living Princess activities (Event Spot system).
enum Activity { STANDING, SITTING, SLEEPING, READING, TRAINING, LOOKING_OUTSIDE, DRINKING_TEA }

## Facial expressions (Eyes / Eyebrows / Mouth layers).
enum Expr { NORMAL, HAPPY, SURPRISED, CURIOUS, FEAR, CRYING, ANGRY, SLY_SMILE }

const WING_NAMES := ["Sword Wing", "Magic Wing", "Shadow Wing", "Light Wing", "Dragon Wing", "ทุกห้อง"]
const PERSONALITY_NAMES := ["กล้าหาญ ตรงไปตรงมา", "ช่างสงสัย รักการอ่าน", "ลึกลับ ขี้แกล้ง", "อ่อนโยน ใจดี", "หยิ่งทะนง ปากแข็ง"]
const SLOT_NAMES := ["เตียง", "โต๊ะ", "ฝึกซ้อม", "ของตกแต่ง"]
const ACTIVITY_NAMES := ["ยืนเล่น", "นั่งพัก", "นอนหลับ", "อ่านหนังสือ", "ฝึกซ้อม", "มองออกไปนอกหน้าต่าง", "จิบชา"]
const ACTIVITY_KEYS := ["STANDING", "SITTING", "SLEEPING", "READING", "TRAINING", "LOOKING_OUTSIDE", "DRINKING_TEA"]
const EXPRESSION_NAMES := ["Normal", "Happy", "Surprised", "Curious", "Fear", "Crying", "Angry", "Sly Smile"]

## Expression -> [eyes, brows, mouth] layer variants (files: eyes_<v>.png, brows_<v>.png, mouth_<v>.png).
const EXPRESSION_PARTS := {
	Expr.NORMAL: ["normal", "normal", "smile"],
	Expr.HAPPY: ["happy", "raised", "open_smile"],
	Expr.SURPRISED: ["surprised", "raised", "o"],
	Expr.CURIOUS: ["curious", "tilted", "small"],
	Expr.FEAR: ["fear", "worried", "wavy"],
	Expr.CRYING: ["crying", "worried", "cry"],
	Expr.ANGRY: ["angry", "angry", "frown"],
	Expr.SLY_SMILE: ["sly", "tilted", "smirk"],
}

## Crafting materials: the 5 card essences + furniture materials from mini bosses / bosses.
const MATERIALS := {
	"fire": "Fire Essence", "ice": "Ice Essence", "shadow": "Shadow Essence",
	"light": "Light Essence", "dragon": "Dragon Essence",
	"bone_fragment": "Bone Fragment", "dragon_scale": "Dragon Scale",
	"ice_crystal": "Ice Crystal", "holy_fragment": "Holy Fragment",
}

## Bond points needed for level 1..5 (index = level).
const BOND_THRESHOLDS := [0, 10, 25, 45, 70, 100]
const MAX_BOND_LEVEL := 5


static func is_material(key: String) -> bool:
	return MATERIALS.has(key)

static func material_name(key: String) -> String:
	return MATERIALS.get(key, key)

static func material_icon(key: String) -> Texture2D:
	var hd := "res://assets/art/materials_hd/%s.png" % key # AI icons (tools/build_material_art.gd)
	if ResourceLoader.exists(hd):
		return load(hd)
	var path := "res://assets/art/cards/essence_%s.png" % key
	if not ResourceLoader.exists(path):
		path = "res://assets/art/materials/%s.png" % key
	return load(path) if ResourceLoader.exists(path) else null

static func bond_level(points: int) -> int:
	var lvl := 0
	for i in BOND_THRESHOLDS.size():
		if points >= BOND_THRESHOLDS[i]:
			lvl = i
	return mini(lvl, MAX_BOND_LEVEL)

## Points needed for the next level (0 when maxed).
static func bond_next(points: int) -> int:
	var lvl := bond_level(points)
	return 0 if lvl >= MAX_BOND_LEVEL else BOND_THRESHOLDS[lvl + 1]


# ------------------------------------------------------------ levels (Phase 5)

const MAX_LEVEL := 30


## EXP needed to go from `level` to level + 1.
static func exp_to_next(level: int) -> int:
	return 0 if level >= MAX_LEVEL else roundi(20.0 * pow(level, 1.5))
