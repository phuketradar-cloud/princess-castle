class_name StageData
## Phase 5 content: 9 new monsters (mini bosses + bosses with phases), stages 2-4,
## princess progression (unlock stage, growth, companion assist) and pair synergies.
## Called from tools/generate_data.gd AFTER the castle data exists (it edits the princesses).
## Difficulty grows through monster count, mechanics and boss phases — not just HP.

const T = CombatTypes.Target
const S = CombatTypes.Status
const FIRE := CardTypes.Element.FIRE
const ICE := CardTypes.Element.ICE
const SHADOW := CardTypes.Element.SHADOW
const LIGHT := CardTypes.Element.LIGHT
const DRAGON := CardTypes.Element.DRAGON
const NORMAL := ItemTypes.Tier.NORMAL
const MINI := ItemTypes.Tier.MINI_BOSS
const BOSS := ItemTypes.Tier.BOSS

static var _saver: Callable
static var _ok := true


static func generate(saver: Callable) -> bool:
	_saver = saver
	_ok = true
	var m := _monsters()
	_stages(m)
	_progression()
	return _ok


static func _save(res: Resource, path: String) -> Resource:
	_ok = _saver.call(res, path) and _ok
	return load(path)


# ------------------------------------------------------------ monsters

static func _mon(id: String, display: String, desc: String, stats: StatBlock, scale: float) -> MonsterDefinition:
	var m := MonsterDefinition.new()
	m.id = id
	m.display_name = display
	m.description = desc
	m.base_stats = stats
	m.texture = load("res://assets/art/monster_%s.png" % id)
	m.visual_scale = scale
	return m


static func _basic(id: String, display: String) -> AbilitySpec:
	var a := AbilitySpec.make(id, display, T.SINGLE_OPPONENT, 1.0)
	a.intent_tag = "ATK"
	return a


static func _tag(a: AbilitySpec, tag: String, chance := 1.0, first_cd := 0) -> AbilitySpec:
	a.intent_tag = tag
	a.ai_use_chance = chance
	a.initial_cooldown = first_cd
	return a


static func _phase(at: float, text: String, enrage := 0.0, cleanse := false, shield := 0.0,
		heal := 0.0, summons: Array = []) -> BossPhase:
	var p := BossPhase.new()
	p.hp_threshold = at
	p.announce = text
	p.enrage = enrage
	p.cleanse = cleanse
	p.shield_fraction = shield
	p.heal_fraction = heal
	for s in summons:
		p.summons.append(s)
	return p


static func _path(id: String) -> String:
	return "res://data/monsters/%s.tres" % id


static func _monsters() -> Dictionary:
	var out := {}

	# --- Frozen Library
	var wisp := _mon("ice_wisp", "Ice Wisp", "สร้างโล่น้ำแข็งให้ตัวเอง — ต้องตีแรงๆ ทีเดียวให้ทะลุ",
		StatBlock.make(46, 12, 2, 0.05, 0.12), 0.9)
	wisp.abilities = [
		_tag(AbilitySpec.make("ice_barrier", "Ice Barrier", T.SELF, 0.0, 4).with_status(S.SHIELD, 3, 1.6), "SHIELD", 0.6, 1),
		_tag(AbilitySpec.make("chill_touch", "Chill Touch", T.SINGLE_OPPONENT, 0.8, 3).with_status(S.WEAKEN, 2, 0.2), "CHILL", 0.5),
		_basic("frost_spark", "Frost Spark")]
	wisp.drops = [EssenceDrop.make(ICE, 0.9, 1, 1), EssenceDrop.make_material("ice_crystal", 0.25, 1, 1)]
	out.wisp = _save(wisp, _path("ice_wisp"))

	var golem := _mon("frost_golem", "Frost Golem",
		"มินิบอส: เกราะหนามาก ส่งสัญญาณ Glacier Slam ก่อนทุบ (กด Defend!) — เลือด 50% จะสร้างแกนน้ำแข็งป้องกัน",
		StatBlock.make(150, 15, 15, 0.0, 0.0), 1.0)
	golem.is_boss = true
	golem.control_resistance = 0.6
	golem.abilities = [
		_tag(AbilitySpec.make("glacier_slam", "Glacier Slam", T.SINGLE_OPPONENT, 2.3, 3), "HEAVY", 1.0, 2),
		_basic("stone_fist", "Stone Fist")]
	golem.phases = [_phase(0.5, "Frost Golem: แกนน้ำแข็งก่อตัว! (โล่)", 0.0, true, 0.2)]
	golem.drops = [EssenceDrop.make(ICE, 1.0, 2, 3), EssenceDrop.make_material("ice_crystal", 1.0, 1, 2)]
	out.golem = _save(golem, _path("frost_golem"))

	var lich := _mon("lich_queen", "Lich Queen",
		"บอส: สาปให้เลือดไหลทุกเทิร์น เรียกภูติน้ำแข็งที่ 70% และคลั่งพร้อมล้างสถานะที่ 35%",
		StatBlock.make(240, 17, 8, 0.05, 0.05), 1.0)
	lich.is_boss = true
	lich.control_resistance = 0.7
	lich.abilities = [
		_tag(AbilitySpec.make("death_curse", "Death Curse", T.SINGLE_OPPONENT, 0.6, 3).with_status(S.POISON, 3, 0.05), "CURSE", 1.0, 1),
		_tag(AbilitySpec.make("soul_frost", "Soul Frost", T.SINGLE_OPPONENT, 1.8, 4), "HEAVY", 1.0, 3),
		_basic("frost_bolt", "Frost Bolt")]
	lich.phases = [
		_phase(0.7, "Lich Queen: ลุกขึ้นมา ข้ารับใช้ของข้า!", 0.0, false, 0.0, 0.0, [out.wisp, out.wisp]),
		_phase(0.35, "Lich Queen: เจ้ากล้าดียังไง! (คลั่ง + ล้างสถานะ)", 0.35, true)]
	lich.drops = [EssenceDrop.make(ICE, 1.0, 3, 4), EssenceDrop.make(SHADOW, 1.0, 1, 2),
		EssenceDrop.make_material("ice_crystal", 1.0, 2, 3), EssenceDrop.make_material("bone_fragment", 1.0, 1, 2)]
	out.lich = _save(lich, _path("lich_queen"))

	# --- Shadow Woods
	var imp := _mon("imp", "Imp", "ตัวเล็ก หลบเก่ง พ่นไฟติดเผาไหม้ — มากันเป็นฝูง",
		StatBlock.make(40, 13, 2, 0.15, 0.2), 0.8)
	imp.abilities = [
		_tag(AbilitySpec.make("fire_spit", "Fire Spit", T.SINGLE_OPPONENT, 0.7, 3).with_status(S.BURN, 3, 0.04), "BURN", 0.7, 1),
		_basic("scratch", "Scratch")]
	imp.drops = [EssenceDrop.make(FIRE, 0.9, 1, 1)]
	out.imp = _save(imp, _path("imp"))

	var wolf := _mon("werewolf", "Werewolf",
		"มินิบอส: กัดรัว 3 ครั้ง — เลือดต่ำกว่าครึ่งจะคลั่งใต้แสงจันทร์ (โจมตีแรงขึ้นมาก)",
		StatBlock.make(200, 19, 8, 0.15, 0.08), 1.05)
	wolf.is_boss = true
	wolf.control_resistance = 0.6
	wolf.abilities = [
		_tag(AbilitySpec.make("frenzy_bite", "Frenzy Bite", T.SINGLE_OPPONENT, 0.65, 3, 3), "FRENZY", 1.0, 1),
		_basic("claw", "Claw")]
	wolf.phases = [_phase(0.5, "Werewolf: อาวู้ววว! จันทร์สีเลือด! (คลั่ง)", 0.45, true)]
	wolf.drops = [EssenceDrop.make(SHADOW, 1.0, 2, 3), EssenceDrop.make_material("bone_fragment", 1.0, 1, 2)]
	out.wolf = _save(wolf, _path("werewolf"))

	var witch := _mon("night_witch", "Night Witch",
		"บอส: สาปให้อ่อนแรง กางโล่และเรียกอิมพ์ที่ 66% ล้างสถานะ+ฟื้นเลือด+เรียกอิมพ์ที่ 33%",
		StatBlock.make(270, 19, 6, 0.08, 0.1), 1.0)
	witch.is_boss = true
	witch.control_resistance = 0.7
	witch.abilities = [
		_tag(AbilitySpec.make("withering_hex", "Withering Hex", T.SINGLE_OPPONENT, 0.8, 3).with_status(S.WEAKEN, 2, 0.3), "HEX", 1.0, 1),
		_tag(AbilitySpec.make("midnight_curse", "Midnight Curse", T.SINGLE_OPPONENT, 0.7, 4).with_status(S.POISON, 3, 0.06), "CURSE", 1.0, 2),
		_basic("shadow_bolt", "Shadow Bolt")]
	witch.phases = [
		_phase(0.66, "Night Witch: ลูกๆ แห่งราตรี มาหาแม่สิ!", 0.0, false, 0.2, 0.0, [out.imp, out.imp]),
		_phase(0.33, "Night Witch: ม่านจันทร์ปกป้องข้า! (ล้างสถานะ + ฟื้นฟู)", 0.15, true, 0.0, 0.12, [out.imp])]
	witch.drops = [EssenceDrop.make(SHADOW, 1.0, 3, 4), EssenceDrop.make(LIGHT, 1.0, 1, 2),
		EssenceDrop.make_material("holy_fragment", 1.0, 1, 2)]
	out.witch = _save(witch, _path("night_witch"))

	# --- Dragon's Peak
	var wyvern := _mon("wyvern", "Wyvern", "หางพิษ ตีแรง — ตัวหลักของรังมังกร",
		StatBlock.make(78, 17, 5, 0.08, 0.1), 0.9)
	wyvern.abilities = [
		_tag(AbilitySpec.make("tail_sting", "Tail Sting", T.SINGLE_OPPONENT, 0.8, 3).with_status(S.POISON, 3, 0.05), "POISON", 0.7, 1),
		_basic("dive", "Dive")]
	wyvern.drops = [EssenceDrop.make(DRAGON, 0.8, 1, 1), EssenceDrop.make_material("dragon_scale", 0.2, 1, 1)]
	out.wyvern = _save(wyvern, _path("wyvern"))

	var drake := _mon("drake", "Fire Drake",
		"มินิบอส: พ่นไฟติดเผาไหม้ — เลือดครึ่งหนึ่งจะคลั่งและสร้างเกราะเกล็ด",
		StatBlock.make(270, 21, 12, 0.08, 0.0), 1.0)
	drake.is_boss = true
	drake.control_resistance = 0.65
	drake.abilities = [
		_tag(AbilitySpec.make("flame_breath", "Flame Breath", T.SINGLE_OPPONENT, 1.3, 3).with_status(S.BURN, 3, 0.05), "FIRE", 1.0, 1),
		_basic("bite", "Bite")]
	drake.phases = [_phase(0.5, "Fire Drake: เกล็ดลุกเป็นไฟ! (คลั่ง + โล่)", 0.3, true, 0.15)]
	drake.drops = [EssenceDrop.make(DRAGON, 1.0, 2, 3), EssenceDrop.make(FIRE, 1.0, 1, 2),
		EssenceDrop.make_material("dragon_scale", 1.0, 1, 2)]
	out.drake = _save(drake, _path("drake"))

	var wyrm := _mon("elder_wyrm", "Elder Wyrm",
		"บอสใหญ่: ส่งสัญญาณ INFERNO ก่อนพ่นไฟมหาประลัย (Defend!) เรียกไวเวิร์นที่ 60% คลั่งที่ 30%",
		StatBlock.make(440, 23, 14, 0.08, 0.0), 1.0)
	wyrm.is_boss = true
	wyrm.control_resistance = 0.75
	wyrm.abilities = [
		_tag(AbilitySpec.make("inferno", "Inferno", T.SINGLE_OPPONENT, 2.6, 4).with_status(S.BURN, 3, 0.04), "HEAVY", 1.0, 2),
		_tag(AbilitySpec.make("tail_sweep", "Tail Sweep", T.SINGLE_OPPONENT, 1.0, 3).with_status(S.WEAKEN, 2, 0.25), "SWEEP", 0.6),
		_basic("crush", "Crush")]
	wyrm.phases = [
		_phase(0.6, "Elder Wyrm: บุตรแห่งเปลวเพลิง จงมา!", 0.0, false, 0.0, 0.0, [out.wyvern, out.wyvern]),
		_phase(0.3, "Elder Wyrm: ข้าคือราชันมังกร!! (คลั่ง + ล้างสถานะ)", 0.4, true, 0.1)]
	wyrm.drops = [EssenceDrop.make(DRAGON, 1.0, 4, 5), EssenceDrop.make(FIRE, 1.0, 2, 3),
		EssenceDrop.make_material("dragon_scale", 1.0, 3, 4)]
	out.wyrm = _save(wyrm, _path("elder_wyrm"))

	for old in ["slime", "bat", "goblin", "skeleton_knight", "dark_shaman"]:
		out[old] = load(_path(old))
	return out


# ------------------------------------------------------------ stages

static func _enc(file: String, display: String, monsters: Array, tier := NORMAL) -> EncounterDefinition:
	var e := EncounterDefinition.new()
	e.display_name = display
	e.reward_tier = tier
	for mm in monsters:
		e.monsters.append(mm)
	return _save(e, "res://data/encounters/%s.tres" % file)


static func _stages(m: Dictionary) -> void:
	# Stage 1 already exists (generate_data.gd); give it its Phase 5 fields.
	var s1: StageDefinition = load("res://data/stage_01.tres")
	s1.id = "stage_01"
	s1.display_name = "Haunted Gate"
	s1.description = "ประตูผีสิงหน้าปราสาท — มินิบอส Skeleton Knight"
	s1.recommended_level = 1
	s1.unlock_after = ""
	s1 = _save(s1, "res://data/stage_01.tres")

	var s2 := StageDefinition.new()
	s2.id = "stage_02"
	s2.display_name = "Frozen Library"
	s2.description = "ห้องสมุดเยือกแข็ง: ภูติน้ำแข็งสร้างโล่ — ใช้สกิลแรง/ติดสถานะ"
	s2.recommended_level = 6
	s2.unlock_after = "stage_01"
	s2.heal_between_battles = 0.4
	s2.monster_hp_scale = 1.3
	s2.monster_attack_scale = 1.2
	s2.encounters = [
		_enc("s2_01_whispering_stacks", "Whispering Stacks", [m.wisp, m.wisp, m.bat]),
		_enc("s2_02_haunted_shelves", "Haunted Shelves", [m.wisp, m.dark_shaman, m.wisp]),
		_enc("s2_03_frozen_guardian", "Frozen Guardian", [m.golem, m.wisp], MINI),
		_enc("s2_04_throne_of_frost", "Throne of Frost", [m.lich, m.wisp], BOSS),
	]

	var s3 := StageDefinition.new()
	s3.id = "stage_03"
	s3.display_name = "Shadow Woods"
	s3.description = "ป่าเงา: ฝูงอิมพ์ติดไฟ หมาป่าคลั่ง และแม่มดราตรี"
	s3.recommended_level = 10
	s3.unlock_after = "stage_02"
	s3.heal_between_battles = 0.4
	s3.monster_hp_scale = 2.0
	s3.monster_attack_scale = 1.8
	s3.encounters = [
		_enc("s3_01_imp_swarm", "Imp Swarm", [m.imp, m.imp, m.goblin]),
		_enc("s3_02_cursed_grove", "Cursed Grove", [m.imp, m.dark_shaman, m.bat, m.imp]),
		_enc("s3_03_blood_moon", "Blood Moon", [m.wolf, m.imp], MINI),
		_enc("s3_04_witch_hut", "Witch's Hut", [m.witch, m.imp], BOSS),
	]

	var s4 := StageDefinition.new()
	s4.id = "stage_04"
	s4.display_name = "Dragon's Peak"
	s4.description = "ยอดเขามังกร: ด่านสุดท้าย — ราชันมังกร Elder Wyrm"
	s4.recommended_level = 14
	s4.unlock_after = "stage_03"
	s4.heal_between_battles = 0.45
	s4.monster_hp_scale = 2.1
	s4.monster_attack_scale = 1.8
	s4.encounters = [
		_enc("s4_01_wyvern_nest", "Wyvern Nest", [m.wyvern, m.wyvern, m.imp]),
		_enc("s4_02_scorched_cliffs", "Scorched Cliffs", [m.wyvern, m.imp, m.imp, m.wyvern]),
		_enc("s4_03_drake_lair", "Drake's Lair", [m.drake, m.wyvern], MINI),
		_enc("s4_04_wyrm_throne", "Wyrm's Throne", [m.wyrm], BOSS),
	]

	var roster: PrincessRoster = load("res://data/princess_roster.tres")
	roster.stages.clear()
	roster.stages.append(s1)
	roster.stages.append(_save(s2, "res://data/stage_02.tres"))
	roster.stages.append(_save(s3, "res://data/stage_03.tres"))
	roster.stages.append(_save(s4, "res://data/stage_04.tres"))
	roster.synergies.clear()
	for syn in _synergies():
		roster.synergies.append(syn)
	_save(roster, "res://data/princess_roster.tres")


# ------------------------------------------------------------ princesses

static func _progression() -> void:
	var magic_nova := AbilitySpec.make("frost_nova", "Frost Nova", T.ALL_OPPONENTS, 0.6).with_status(S.FREEZE, 1, 0.0, 0.3)
	var shadow_mark := AbilitySpec.make("shadow_mark", "Shadow Mark", T.SINGLE_OPPONENT, 1.1)
	shadow_mark.execute_threshold = 0.2
	shadow_mark.execute_boss_multiplier = 1.5
	var blessing := AbilitySpec.make("blessing", "Blessing", T.LOWEST_HP_ALLY, 0.0)
	blessing.heal_multiplier = 1.6
	# id: [unlock_stage, growth hp, atk, def, crit, eva, luck, assist, interval]
	var rows := {
		"sword_princess": ["", 9.0, 1.3, 0.5, 0.0, 0.0, 0.5,
			AbilitySpec.make("cross_slash", "Cross Slash", T.SINGLE_OPPONENT, 1.2).with_status(S.WEAKEN, 2, 0.2), 3],
		"magic_princess": ["stage_01", 6.0, 1.5, 0.3, 0.0, 0.0, 0.6, magic_nova, 3],
		"shadow_princess": ["stage_02", 7.0, 1.3, 0.3, 0.004, 0.003, 0.8, shadow_mark, 3],
		"light_princess": ["stage_02", 10.0, 1.0, 0.6, 0.0, 0.0, 0.6, blessing, 3],
		"dragon_princess": ["stage_03", 10.0, 1.3, 0.5, 0.0, 0.0, 0.3,
			AbilitySpec.make("ember_breath", "Ember Breath", T.ALL_OPPONENTS, 0.5).with_status(S.BURN, 2, 0.04), 3],
	}
	var roster: PrincessRoster = load("res://data/princess_roster.tres")
	for p in roster.princesses:
		var r: Array = rows[p.id]
		p.unlock_stage = r[0]
		p.growth_hp = r[1]
		p.growth_attack = r[2]
		p.growth_defense = r[3]
		p.growth_critical = r[4]
		p.growth_evasion = r[5]
		p.growth_luck = r[6]
		p.assist = r[7]
		p.assist_interval = r[8]
		_ok = _saver.call(p, p.resource_path) and _ok


static func _syn(a: String, b: String, display: String, desc: String, stats: StatBlock,
		dmg := 0.0, regen := 0.0, mana := 0) -> Synergy:
	var s := Synergy.new()
	s.princess_a = a
	s.princess_b = b
	s.display_name = display
	s.description = desc
	s.stats = stats
	s.damage_bonus = dmg
	s.regen = regen
	s.start_mana = mana
	return s


static func _synergies() -> Array:
	var SW := "sword_princess"
	var MG := "magic_princess"
	var SH := "shadow_princess"
	var LT := "light_princess"
	var DR := "dragon_princess"
	var none := StatBlock.make(0, 0, 0)
	return [
		_syn(SW, MG, "Spellblade", "ดาบอาบเวท: ความเสียหายทั้งหมด +15%", none, 0.15),
		_syn(SW, LT, "Holy Oath", "คำสาบานศักดิ์สิทธิ์: ฟื้น HP 4% ทุกเทิร์น", none, 0.0, 0.04),
		_syn(SH, DR, "Eclipse Fang", "เขี้ยวสุริยคราส: คริติคอล +12%", StatBlock.make(0, 0, 0, 0.12)),
		_syn(SW, SH, "Twin Edge", "คมคู่: ATK +3 คริติคอล +5%", StatBlock.make(0, 3, 0, 0.05)),
		_syn(SW, DR, "Knight & Wyrm", "อัศวินกับมังกร: HP +30 DEF +4", StatBlock.make(30, 0, 4)),
		_syn(MG, SH, "Moonless Rite", "พิธีไร้จันทร์: มานาเริ่ม +1 หลบหลีก +5%", StatBlock.make(0, 0, 0, 0, 0.05), 0.0, 0.0, 1),
		_syn(MG, LT, "Starlit Prayer", "บทสวดใต้แสงดาว: มานาเริ่ม +1 ฟื้น HP 2% ทุกเทิร์น", none, 0.0, 0.02, 1),
		_syn(MG, DR, "Elemental Storm", "พายุธาตุ: ความเสียหาย +12%", none, 0.12),
		_syn(SH, LT, "Dusk & Dawn", "สนธยา: หลบหลีก +8% ฟื้น HP 2% ทุกเทิร์น", StatBlock.make(0, 0, 0, 0, 0.08), 0.0, 0.02),
		_syn(LT, DR, "Sacred Flame", "เปลวไฟศักดิ์สิทธิ์: HP +40 ฟื้น HP 3% ทุกเทิร์น", StatBlock.make(40, 0, 0), 0.0, 0.03),
	]
