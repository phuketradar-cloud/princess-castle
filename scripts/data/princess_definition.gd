class_name PrincessDefinition
extends Resource
## Static data for one princess. Add a princess = new .tres file (Inspector: New Resource > PrincessDefinition).

enum Archetype { SWORD, MAGIC, SHADOW, LIGHT, DRAGON }

@export var id: String = "sword_princess"
@export var display_name: String = "Sword Princess"
@export var title: String = ""
@export var archetype: Archetype = Archetype.SWORD
@export_multiline var description: String = ""

@export var base_stats: StatBlock
## Index 0 = basic attack. The rest become skill buttons.
@export var abilities: Array[AbilitySpec] = []

## Equipped automatically the first time this princess is used.
@export var starting_equipment: Array[EquipmentDefinition] = []

@export_group("Castle & personality (Phase 4)")
@export var personality: CastleTypes.Personality = CastleTypes.Personality.BRAVE
@export var wing: CastleTypes.Wing = CastleTypes.Wing.SWORD
## Stage clears needed to unlock her (0 = available from the start).
@export var unlock_clears: int = 0
## Gifts of this essence give extra bond.
@export var liked_material: String = "fire"
## Folder with face layers: eyes_*.png, brows_*.png, mouth_*.png
@export_dir var face_dir: String = ""
## Face centre on the body, relative to the feet (same space as slot_anchors).
@export var face_anchor: Vector2 = Vector2(-4, -168)
## Card granted at bond level 5 (exclusive).
@export var bond_card: CardDefinition
## Cosmetic (skin) furniture granted at bond level 4.
@export var bond_cosmetic: FurnitureDefinition
## Small mana perks (Magic Princess).
@export var bonus_start_mana: int = 0
@export var bonus_max_mana: int = 0
@export_group("Progression (Phase 5)")
## Stage that must be cleared to unlock her ("" = available from the start).
@export var unlock_stage: String = ""
## Stats gained per level above 1 (HP, ATK, DEF can be fractional: rounded at each level).
@export var growth_hp: float = 8.0
@export var growth_attack: float = 1.2
@export var growth_defense: float = 0.4
@export var growth_critical: float = 0.0
@export var growth_evasion: float = 0.0
@export var growth_luck: float = 0.5
## Her assist when she is the companion (used automatically every assist_interval rounds).
@export var assist: AbilitySpec
@export var assist_interval: int = 3

## Activity weights (CastleTypes.Activity order) — what she likes to do in her room.
@export var activity_weights: PackedFloat32Array = PackedFloat32Array([1, 1, 1, 1, 1, 1, 1])

@export_group("Visuals")
## Body art WITHOUT equipment; equipment is layered on top (paper doll).
@export var battle_texture: Texture2D
@export var theme_color: Color = Color(0.85, 0.35, 0.55)
@export var battle_scale: float = 1.0
## Body + face art is drawn at this scale (high-res art, e.g. 0.46 = drawn at ~2x). Slot and
## face anchors stay in on-screen (scaled) pixels, so equipment sizes are unaffected.
@export var art_scale: float = 1.0
## Where each equipment slot sits on this body, in pixels relative to the FEET
## (bottom-centre of battle_texture, y up is negative). Keys = ItemTypes.Slot.
@export var slot_anchors: Dictionary = {
	ItemTypes.Slot.WEAPON: Vector2(24, -108),
	ItemTypes.Slot.HEADGEAR: Vector2(-4, -206),
	ItemTypes.Slot.WING: Vector2(-4, -122),
	ItemTypes.Slot.ARMOR: Vector2(-4, -100),
	ItemTypes.Slot.ACCESSORY: Vector2(-4, -126),
}


## Base stats at a level (level 1 = base_stats).
func level_stats(level: int) -> StatBlock:
	var n := maxi(0, level - 1)
	var b := base_stats if base_stats != null else StatBlock.make(100, 10, 0)
	return StatBlock.make(b.max_hp + roundi(growth_hp * n), b.attack + roundi(growth_attack * n),
		b.defense + roundi(growth_defense * n), b.critical + growth_critical * n,
		b.evasion + growth_evasion * n, b.luck + growth_luck * n)
