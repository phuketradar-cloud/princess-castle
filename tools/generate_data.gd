extends SceneTree
## Regenerates the Phase 1 data files in res://data/ (princess, monsters, encounters, stage, balance).
## Run:  Godot_console.exe --headless --path . --script res://tools/generate_data.gd
## Afterwards tune values in the Inspector by opening the .tres files. Re-running OVERWRITES them.
## Numbers tuned by simulation (2000 runs): ~56% stage clear with smart play, ~2% attack-only.

const T = CombatTypes.Target
const S = CombatTypes.Status
## Tuned with tests/run_tests.gd simulation (see README).
const BASE_HP := 160
const BASE_ATK := 20
const E_FIRE := CardTypes.Element.FIRE
const E_ICE := CardTypes.Element.ICE
const E_SHADOW := CardTypes.Element.SHADOW
const E_LIGHT := CardTypes.Element.LIGHT
const E_DRAGON := CardTypes.Element.DRAGON
## id -> [layer_scale, layer_offset]: grip of the rose rapier lands on the hand anchor
## (art from tools/build_princess_art_v2.gd).
## AI item art (assets/art/items_hd, tools/build_item_art.gd): [layer scale, offset from the slot
## anchor]. Weapons: offset = (image centre - grip) x scale, so the grip sits in her fist.
## Armor / accessories are not drawn on the HD princesses (outfit = armor): icon only.
const HD_ITEMS := {
	"rose_rapier": [0.155, Vector2(-49.8, 36.3)],
	"rusty_sword": [0.19, Vector2(16.5, -31.4)],
	"moonlight_blade": [0.21, Vector2(28.6, -43.9)],
	"dragon_sword": [0.22, Vector2(33.2, -61.8)],
	"abyss_scythe": [0.28, Vector2(53.5, -54.6)],
	"silver_tiara": [0.062, Vector2(0, 0)],
	"ribbon_bow": [0.19, Vector2(-12, 2)],
	"witch_hat": [0.33, Vector2(0, -14)],
	"queen_crown": [0.215, Vector2(0, -6)],
	"starfall_halo": [0.3, Vector2(0, -30)],
	"moth_wings": [0.65, Vector2.ZERO],
	"bat_wings": [0.7, Vector2.ZERO],
	"fairy_wings": [0.7, Vector2.ZERO],
	"dragon_wings": [0.75, Vector2.ZERO],
	"seraph_wings": [0.9, Vector2.ZERO],
	"leather_corset": [1.0, Vector2.ZERO], "lace_guard_dress": [1.0, Vector2.ZERO],
	"thorn_plate": [1.0, Vector2.ZERO], "rose_knight_armor": [1.0, Vector2.ZERO],
	"clover_charm": [1.0, Vector2.ZERO], "ruby_pendant": [1.0, Vector2.ZERO],
	"vampire_locket": [1.0, Vector2.ZERO], "mirror_of_thorns": [1.0, Vector2.ZERO],
	"moon_tear": [1.0, Vector2.ZERO],
}


func _init() -> void:
	var ok := true
	ok = _save(BattleConfig.new(), "res://data/balance_config.tres") and ok
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://data/items"))

	# ---------- equipment (Phase 2). Each tier also has a different LOOK on the princess.
	var W := ItemTypes.Slot.WEAPON
	var H := ItemTypes.Slot.HEADGEAR
	var G := ItemTypes.Slot.WING
	var A := ItemTypes.Slot.ARMOR
	var X := ItemTypes.Slot.ACCESSORY
	var C := ItemTypes.Rarity.COMMON
	var R := ItemTypes.Rarity.RARE
	var E := ItemTypes.Rarity.EPIC
	var L := ItemTypes.Rarity.LEGENDARY
	var M := ItemTypes.Rarity.MYTHIC
	var SP := ItemTypes.Special
	# id, name, slot, rarity, [hp, atk, def, crit, eva, luck], special, value, description
	var item_rows := [
		["rusty_sword", "Rusty Sword", W, C, [0, 3, 0, 0, 0, 0], SP.NONE, 0.0, "ดาบเก่าจากคลังอาวุธของปราสาท"],
		["rose_rapier", "Rose Rapier", W, R, [0, 6, 0, 0.05, 0, 0], SP.NONE, 0.0, "เรเปียร์เบาหวิว แทงได้แม่นยำ"],
		["moonlight_blade", "Moonlight Blade", W, E, [0, 9, 0, 0.08, 0, 0], SP.CRIT_POWER, 0.25, "ดาบที่ส่องประกายใต้แสงจันทร์"],
		["dragon_sword", "Dragon Sword", W, L, [0, 14, 0, 0.05, 0, 0], SP.CRIT_POWER, 0.5, "ดาบเล่มนี้หนักจัง... แต่ฟันทีเดียวแทบขาด"],
		["abyss_scythe", "Abyss Scythe", W, M, [0, 18, 0, 0.08, 0, 0], SP.LIFESTEAL, 0.15, "เคียวจากก้นเหว ดูดพลังชีวิตศัตรู"],
		["ribbon_bow", "Ribbon Bow", H, C, [0, 0, 0, 0, 0, 15], SP.NONE, 0.0, "โบว์นำโชค"],
		["silver_tiara", "Silver Tiara", H, R, [10, 0, 0, 0.05, 0, 10], SP.NONE, 0.0, "มงกุฎเงินเล็กๆ ของเจ้าหญิงฝึกหัด"],
		["witch_hat", "Witch Hat", H, E, [0, 4, 0, 0.06, 0, 0], SP.POISON_EDGE, 0.3, "หมวกแม่มดที่ทำให้อาวุธอาบยาพิษ"],
		["queen_crown", "Queen Crown", H, L, [20, 3, 0, 0.08, 0, 25], SP.NONE, 0.0, "มันสวยเกินไปหรือเปล่านะ?"],
		["starfall_halo", "Starfall Halo", H, M, [25, 0, 0, 0.12, 0.05, 30], SP.NONE, 0.0, "วงแหวนดาวตกที่ลอยเหนือศีรษะ"],
		["moth_wings", "Moth Wings", G, C, [0, 0, 0, 0, 0.03, 0], SP.NONE, 0.0, "ปีกผีเสื้อกลางคืนนุ่มๆ"],
		["bat_wings", "Bat Wings", G, R, [0, 2, 0, 0, 0.06, 0], SP.NONE, 0.0, "ปีกค้างคาวที่ช่วยหลบหลีก"],
		["fairy_wings", "Fairy Wings", G, E, [10, 0, 0, 0, 0.09, 10], SP.NONE, 0.0, "ปีกนางฟ้าโปร่งแสง"],
		["dragon_wings", "Dragon Wings", G, L, [15, 5, 4, 0, 0.06, 0], SP.NONE, 0.0, "ฉันดูน่ากลัวขึ้นไหม?"],
		["seraph_wings", "Seraph Wings", G, M, [30, 0, 2, 0, 0.12, 0], SP.NONE, 0.0, "ปีกเทวดาหกชั้น"],
		["leather_corset", "Leather Corset", A, C, [15, 0, 3, 0, 0, 0], SP.NONE, 0.0, "เสื้อรัดหนังทนทาน"],
		["lace_guard_dress", "Lace Guard Dress", A, R, [25, 0, 5, 0, 0, 0], SP.NONE, 0.0, "ชุดลูกไม้เสริมเกราะเงิน"],
		["thorn_plate", "Thorn Plate", A, E, [30, 0, 8, 0, 0, 0], SP.THORNS, 0.2, "เกราะหนามกุหลาบ ใครตีก็เจ็บเอง"],
		["rose_knight_armor", "Rose Knight Armor", A, L, [50, 0, 12, 0, 0, 0], SP.NONE, 0.0, "เกราะอัศวินกุหลาบเต็มตัว"],
		["clover_charm", "Clover Charm", X, C, [0, 0, 0, 0, 0, 25], SP.NONE, 0.0, "ใบโคลเวอร์สี่แฉก"],
		["ruby_pendant", "Ruby Pendant", X, R, [20, 2, 0, 0, 0, 0], SP.NONE, 0.0, "จี้ทับทิมอุ่นๆ"],
		["vampire_locket", "Vampire Locket", X, E, [10, 0, 0, 0, 0, 0], SP.LIFESTEAL, 0.1, "ล็อกเก็ตรูปหัวใจที่กระหายเลือด"],
		["mirror_of_thorns", "Mirror of Thorns", X, L, [15, 0, 4, 0, 0, 0], SP.THORNS, 0.3, "กระจกที่สะท้อนความเจ็บปวดกลับไป"],
		["moon_tear", "Moon Tear", X, M, [30, 4, 4, 0.05, 0.05, 20], SP.NONE, 0.0, "หยดน้ำตาของดวงจันทร์"],
	]
	var all_items: Array[EquipmentDefinition] = []
	for row in item_rows:
		var it := EquipmentDefinition.new()
		it.id = row[0]
		it.display_name = row[1]
		it.slot = row[2]
		it.rarity = row[3]
		var s: Array = row[4]
		it.stats = StatBlock.make(s[0], s[1], s[2], s[3], s[4], s[5])
		it.special = row[5]
		it.special_value = row[6]
		it.description = row[7]
		it.texture = load("res://assets/art/items/%s.png" % it.id)
		# HD art from the Sword Princess sheet (tools/build_princess_art.gd): scale + hand offset.
		if HD_ITEMS.has(it.id):
			it.texture = load("res://assets/art/items_hd/%s.png" % it.id)
			it.layer_scale = HD_ITEMS[it.id][0]
			it.layer_offset = HD_ITEMS[it.id][1]
		var path := "res://data/items/%s.tres" % it.id
		ok = _save(it, path) and ok
		all_items.append(load(path))

	var loot := LootTable.new()
	loot.items = all_items
	ok = _save(loot, "res://data/loot_table.tres") and ok

	# ---------- princess
	var sword := PrincessDefinition.new()
	sword.id = "sword_princess"
	sword.display_name = "Sword Princess"
	sword.title = "Blade of the Rose"
	sword.archetype = PrincessDefinition.Archetype.SWORD
	sword.description = "สายโจมตีกายภาพ สมดุล ตีเดี่ยวแรงและฟันกวาดทั้งแถว"
	# Base stats are lower than Phase 1: equipment now makes up the difference.
	sword.base_stats = StatBlock.make(BASE_HP, BASE_ATK, 6, 0.10, 0.05, 10)
	sword.starting_equipment = [load("res://data/items/rusty_sword.tres")]
	sword.abilities = [
		AbilitySpec.make("attack", "Attack", T.SINGLE_OPPONENT, 1.0),
		AbilitySpec.make("crescent_slash", "Crescent Slash", T.ALL_OPPONENTS, 0.75, 3),
		AbilitySpec.make("pommel_bash", "Pommel Bash", T.SINGLE_OPPONENT, 0.6, 4).with_status(S.STUN, 1, 0.0),
	]
	sword.battle_texture = load("res://assets/art/princess_base.png")
	sword.theme_color = Color8(150, 40, 90)
	ok = _save(sword, "res://data/princess_sword.tres") and ok

	# ---------- monsters: each has a distinct mechanic
	var slime := _monster("slime", "Slime", "ตัวเดียวไม่น่ากลัว แต่ Sticky Goo ลดพลังโจมตี",
		StatBlock.make(38, 9, 2), "slime.png", 0.9)
	var goo := AbilitySpec.make("sticky_goo", "Sticky Goo", T.SINGLE_OPPONENT, 0.6, 3).with_status(S.WEAKEN, 2, 0.25)
	goo.ai_use_chance = 0.5
	goo.intent_tag = "GOO"
	slime.abilities = [goo, _basic("tackle", "Tackle")]
	slime.drops = [EssenceDrop.make(E_ICE, 0.8, 1, 1), EssenceDrop.make(E_LIGHT, 0.25, 1, 1)]
	ok = _save(slime, "res://data/monsters/slime.tres") and ok

	var bat := _monster("bat", "Night Bat", "บอบบางแต่หลบเก่ง (30%) กัดสองครั้ง",
		StatBlock.make(22, 7, 0, 0.05, 0.30), "bat.png", 0.85)
	var double_bite := AbilitySpec.make("double_bite", "Double Bite", T.SINGLE_OPPONENT, 0.6, 2, 2)
	double_bite.ai_use_chance = 0.7
	double_bite.intent_tag = "BITE"
	bat.abilities = [double_bite, _basic("bite", "Bite")]
	bat.drops = [EssenceDrop.make(E_SHADOW, 0.8, 1, 1)]
	ok = _save(bat, "res://data/monsters/bat.tres") and ok

	var goblin := _monster("goblin", "Goblin", "Poison Dagger ทำดาเมจ 4% HP ทุกเทิร์น 3 เทิร์น",
		StatBlock.make(38, 9, 4, 0.1, 0.05), "goblin.png", 1.0)
	var dagger := AbilitySpec.make("poison_dagger", "Poison Dagger", T.SINGLE_OPPONENT, 0.8, 3).with_status(S.POISON, 3, 0.04)
	dagger.initial_cooldown = 1
	dagger.intent_tag = "POISON"
	goblin.abilities = [dagger, _basic("slash", "Slash")]
	goblin.drops = [EssenceDrop.make(E_FIRE, 0.9, 1, 2)]
	ok = _save(goblin, "res://data/monsters/goblin.tres") and ok

	var skeleton := _monster("skeleton_knight", "Skeleton Knight",
		"มินิบอส: ส่งสัญญาณก่อนใช้ Bone Crusher (ตีหนักมาก) ให้กด Defend ตอนเห็น! ต้าน Stun 50%",
		StatBlock.make(80, 13, 10, 0.05), "skeleton.png", 1.05)
	var crusher := AbilitySpec.make("bone_crusher", "Bone Crusher", T.SINGLE_OPPONENT, 2.4, 3)
	crusher.initial_cooldown = 2
	crusher.intent_tag = "HEAVY"
	skeleton.abilities = [crusher, _basic("cleave", "Cleave")]
	skeleton.is_boss = true
	skeleton.control_resistance = 0.5
	skeleton.drops = [EssenceDrop.make(E_SHADOW, 1.0, 2, 3), EssenceDrop.make(E_DRAGON, 1.0, 1, 2)]
	ok = _save(skeleton, "res://data/monsters/skeleton_knight.tres") and ok

	var shaman := _monster("dark_shaman", "Dark Shaman", "ฮีลมอนสเตอร์ที่เลือดน้อยที่สุด และสาปให้อ่อนแรง — ฆ่าก่อน!",
		StatBlock.make(40, 10, 3, 0.05, 0.05), "shaman.png", 1.0)
	var mend := AbilitySpec.make("dark_mend", "Dark Mend", T.LOWEST_HP_ALLY, 0.0, 2)
	mend.heal_multiplier = 1.6
	mend.intent_tag = "HEAL"
	var hex := AbilitySpec.make("hex", "Hex", T.SINGLE_OPPONENT, 0.7, 3).with_status(S.WEAKEN, 2, 0.3)
	hex.ai_use_chance = 0.6
	hex.intent_tag = "HEX"
	shaman.abilities = [mend, hex, _basic("shadow_bolt", "Shadow Bolt")]
	shaman.drops = [EssenceDrop.make(E_LIGHT, 1.0, 1, 2), EssenceDrop.make(E_SHADOW, 0.5, 1, 1)]
	ok = _save(shaman, "res://data/monsters/dark_shaman.tres") and ok

	# Reload saved monsters so encounters reference the files (not embedded copies).
	slime = load("res://data/monsters/slime.tres")
	bat = load("res://data/monsters/bat.tres")
	goblin = load("res://data/monsters/goblin.tres")
	skeleton = load("res://data/monsters/skeleton_knight.tres")
	shaman = load("res://data/monsters/dark_shaman.tres")

	# ---------- encounters & stage (difficulty grows by count and mechanics)
	var e1 := _encounter("Slime Ambush", [slime, slime])
	var e2 := _encounter("Night Wings", [slime, bat, bat])
	var e3 := _encounter("Goblin Patrol", [goblin, bat, goblin])
	var e4 := _encounter("Crypt Guardians", [skeleton, shaman, goblin])
	e4.reward_tier = ItemTypes.Tier.MINI_BOSS # better loot after the mini boss
	ok = _save(e1, "res://data/encounters/01_slime_ambush.tres") and ok
	ok = _save(e2, "res://data/encounters/02_night_wings.tres") and ok
	ok = _save(e3, "res://data/encounters/03_goblin_patrol.tres") and ok
	ok = _save(e4, "res://data/encounters/04_crypt_guardians.tres") and ok

	var stage := StageDefinition.new()
	stage.display_name = "Haunted Gate"
	stage.heal_between_battles = 0.4
	# Phase 3: cards make the princess much stronger -> monsters scaled up (simulated: ~54% first-run clear).
	stage.monster_hp_scale = 1.3
	stage.monster_attack_scale = 1.3
	stage.encounters = [
		load("res://data/encounters/01_slime_ambush.tres"),
		load("res://data/encounters/02_night_wings.tres"),
		load("res://data/encounters/03_goblin_patrol.tres"),
		load("res://data/encounters/04_crypt_guardians.tres"),
	]
	ok = _save(stage, "res://data/stage_01.tres") and ok

	ok = _generate_cards() and ok
	ok = _generate_castle() and ok
	ok = StageData.generate(_save) and ok # Phase 5: stages 2-4, bosses, progression, synergies
	ok = BattleData.apply(_save) and ok # AI battle art: monsters + stage backgrounds
	print("generate_data: ", "OK" if ok else "FAILED")
	quit(0 if ok else 1)


func _monster(id: String, display: String, desc: String, stats: StatBlock, tex: String, scale: float) -> MonsterDefinition:
	var m := MonsterDefinition.new()
	m.id = id
	m.display_name = display
	m.description = desc
	m.base_stats = stats
	m.texture = load("res://assets/art/" + tex)
	m.visual_scale = scale
	return m


func _basic(id: String, display: String) -> AbilitySpec:
	var a := AbilitySpec.make(id, display, T.SINGLE_OPPONENT, 1.0)
	a.intent_tag = "ATK"
	return a


func _encounter(display: String, monsters: Array) -> EncounterDefinition:
	var e := EncounterDefinition.new()
	e.display_name = display
	for m in monsters:
		e.monsters.append(m)
	return e


func _save(res: Resource, path: String) -> bool:
	var err := ResourceSaver.save(res, path)
	if err != OK:
		push_error("Could not save %s (%d)" % [path, err])
		return false
	return true


# ------------------------------------------------------------ Phase 3: cards, recipes, library

func _generate_cards() -> bool:
	var ok := true
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://data/cards"))
	var A := CardTypes.Category.ATTACK
	var CT := CardTypes.Category.CONTROL
	var SU := CardTypes.Category.SUPPORT
	var SP := CardTypes.Category.SPECIAL
	var C := ItemTypes.Rarity.COMMON
	var R := ItemTypes.Rarity.RARE
	var E := ItemTypes.Rarity.EPIC
	var L := ItemTypes.Rarity.LEGENDARY
	var M := ItemTypes.Rarity.MYTHIC

	var exe := AbilitySpec.make("shadow_execution", "Shadow Execution", T.SINGLE_OPPONENT, 1.4)
	exe.execute_threshold = 0.35
	exe.execute_boss_multiplier = 2.5
	var heal := AbilitySpec.make("heal", "Heal", T.SELF, 0.0)
	heal.heal_multiplier = 1.2

	# id, name, category, element, rarity, mana, effect, drop weight, description
	var rows := [
		["fireball", "Fireball", A, E_FIRE, C, 1, AbilitySpec.make("fireball", "Fireball", T.SINGLE_OPPONENT, 1.5).with_status(S.BURN, 2, 0.04), 1.0,
			"ลูกไฟใส่ศัตรู 1 ตัว (150%) + ติดไฟ 2 เทิร์น"],
		["fire_blast", "Fire Blast", A, E_FIRE, E, 2, AbilitySpec.make("fire_blast", "Fire Blast", T.SINGLE_OPPONENT, 3.0).with_status(S.BURN, 3, 0.05), 0.0,
			"ระเบิดเพลิงใส่ศัตรู 1 ตัว (300%) + ติดไฟ 3 เทิร์น — ได้จาก Fusion"],
		["meteor", "Meteor", A, E_FIRE, E, 3, AbilitySpec.make("meteor", "Meteor", T.ALL_OPPONENTS, 1.1), 0.6,
			"อุกกาบาตถล่มศัตรูทุกตัว (110%)"],
		["dragon_breath", "Dragon Breath", A, E_DRAGON, L, 3, AbilitySpec.make("dragon_breath", "Dragon Breath", T.ALL_OPPONENTS, 1.0).with_status(S.BURN, 3, 0.05), 0.5,
			"พ่นไฟมังกรใส่ศัตรูทุกตัว (100%) + ติดไฟ 3 เทิร์น"],
		["ice_prison", "Ice Prison", CT, E_ICE, R, 2, AbilitySpec.make("ice_prison", "Ice Prison", T.SINGLE_OPPONENT, 0.3).with_status(S.FREEZE, 4, 0.0), 1.0,
			"กักขังศัตรูที่เลือกในน้ำแข็ง 4 เทิร์น (บอส: ครึ่งเดียว)"],
		["shadow_prison", "Shadow Prison", CT, E_SHADOW, R, 1, AbilitySpec.make("shadow_prison", "Shadow Prison", T.SINGLE_OPPONENT, 0.8).with_status(S.WEAKEN, 3, 0.4), 1.0,
			"โซ่เงาพันธนาการ (80%) ลดพลังโจมตีศัตรู 40% 3 เทิร์น"],
		["dimensional_prison", "Dimensional Prison", CT, E_SHADOW, L, 3, AbilitySpec.make("dimensional_prison", "Dimensional Prison", T.ALL_OPPONENTS, 0.3).with_status(S.FREEZE, 2, 0.0), 0.0,
			"กักขังศัตรูทุกตัวในมิติ 2 เทิร์น — ได้จาก Fusion"],
		["banish", "Banish", CT, E_SHADOW, E, 2, AbilitySpec.make("banish", "Banish", T.SINGLE_OPPONENT, 0.0).with_status(S.BANISH, 2, 0.0), 0.8,
			"ส่งศัตรูที่เลือกออกจากสนาม 2 เทิร์น (บอสไม่มีผล)"],
		["sleep", "Sleep", CT, E_LIGHT, C, 1, AbilitySpec.make("sleep", "Sleep", T.SINGLE_OPPONENT, 0.0).with_status(S.SLEEP, 3, 0.0), 1.0,
			"ทำให้ศัตรูหลับ 3 เทิร์น (ตื่นเมื่อโดนโจมตี)"],
		["silence", "Silence", CT, E_SHADOW, C, 1, AbilitySpec.make("silence", "Silence", T.SINGLE_OPPONENT, 0.0).with_status(S.SILENCE, 3, 0.0), 1.0,
			"ห้ามศัตรูใช้ความสามารถพิเศษ 3 เทิร์น (ตีธรรมดาได้)"],
		["heal", "Heal", SU, E_LIGHT, C, 1, heal, 1.0,
			"ฟื้น HP เท่ากับ 120% ของพลังโจมตี"],
		["holy_shield", "Holy Shield", SU, E_LIGHT, R, 2, AbilitySpec.make("holy_shield", "Holy Shield", T.SELF, 0.0).with_status(S.SHIELD, 3, 2.5), 1.0,
			"โล่ศักดิ์สิทธิ์ดูดซับดาเมจ = 250% ATK นาน 3 เทิร์น"],
		["lucky_day", "Lucky Day", SU, E_LIGHT, R, 1, AbilitySpec.make("lucky_day", "Lucky Day", T.SELF, 0.0).with_status(S.LUCKY, 3, 0.35), 1.0,
			"โอกาสคริติคอล +35% นาน 3 เทิร์น"],
		["time_stop", "Time Stop", SP, E_ICE, L, 4, AbilitySpec.make("time_stop", "Time Stop", T.ALL_OPPONENTS, 0.0).with_status(S.STUN, 1, 0.0), 0.4,
			"หยุดเวลา: ศัตรูทุกตัวขยับไม่ได้ 1 เทิร์น (บอสอาจต้านได้)"],
		["shadow_execution", "Shadow Execution", SP, E_SHADOW, E, 3, exe, 0.6,
			"ฟัน 140% — ถ้าเป้าหมาย HP ≤ 35% ประหารทันที (บอสโดน 250% แทน)"],
		["dragons_wrath", "Dragon's Wrath", SP, E_DRAGON, M, 5, AbilitySpec.make("dragons_wrath", "Dragon's Wrath", T.ALL_OPPONENTS, 2.0).with_status(S.BURN, 3, 0.06), 0.3,
			"โทสะมังกร: ศัตรูทุกตัว 200% + ติดไฟ 3 เทิร์น"],
	]
	var by_id := {}
	for row in rows:
		var c := CardDefinition.new()
		c.id = row[0]
		c.display_name = row[1]
		c.category = row[2]
		c.element = row[3]
		c.rarity = row[4]
		c.mana_cost = row[5]
		c.effect = row[6]
		c.drop_weight = row[7]
		c.description = row[8]
		c.icon = load("res://assets/art/cards/%s.png" % c.id)
		var path := "res://data/cards/%s.tres" % c.id
		ok = _save(c, path) and ok
		by_id[c.id] = load(path)

	var lib := CardLibrary.new()
	for row in rows:
		lib.cards.append(by_id[row[0]])
	var crafts := [
		["fireball", {"fire": 3}], ["ice_prison", {"ice": 5}], ["dragon_breath", {"dragon": 5, "fire": 5}],
		["sleep", {"light": 2, "ice": 1}], ["silence", {"shadow": 3}], ["shadow_prison", {"shadow": 5}],
		["heal", {"light": 3}], ["holy_shield", {"light": 4, "ice": 2}], ["lucky_day", {"light": 2, "shadow": 2}],
		["meteor", {"fire": 6, "light": 2}], ["banish", {"shadow": 4, "light": 2}],
		["shadow_execution", {"shadow": 6, "dragon": 1}], ["time_stop", {"ice": 4, "shadow": 4, "light": 4}],
	]
	for cr in crafts:
		var r := CraftRecipe.new()
		r.result = by_id[cr[0]]
		r.cost = cr[1]
		lib.craft_recipes.append(r)
	var fusions := [
		[["fireball", "fireball", "fireball"], "fire_blast"],
		[["ice_prison", "shadow_prison"], "dimensional_prison"],
		[["dragon_breath", "dragon_breath"], "dragons_wrath"],
	]
	for fu in fusions:
		var f := FusionRecipe.new()
		for card_id in fu[0]:
			f.inputs.append(by_id[card_id])
		f.result = by_id[fu[1]]
		lib.fusion_recipes.append(f)
	lib.starting_cards = [by_id["fireball"], by_id["heal"]]
	ok = _save(lib, "res://data/card_library.tres") and ok

	# Hook the library into the loot table (3rd reward option = card).
	var loot: LootTable = load("res://data/loot_table.tres")
	loot.card_library = load("res://data/card_library.tres")
	loot.option_kinds = PackedStringArray(["equipment", "equipment", "card"])
	ok = _save(loot, "res://data/loot_table.tres") and ok
	return ok


# ------------------------------------------------------------ Phase 4: castle

func _generate_castle() -> bool:
	# Furniture materials dropped by existing monsters.
	var slime: MonsterDefinition = load("res://data/monsters/slime.tres")
	var skeleton: MonsterDefinition = load("res://data/monsters/skeleton_knight.tres")
	var shaman: MonsterDefinition = load("res://data/monsters/dark_shaman.tres")
	CastleData.add_material_drops(slime, skeleton, shaman)
	var ok := _save(slime, "res://data/monsters/slime.tres")
	ok = _save(skeleton, "res://data/monsters/skeleton_knight.tres") and ok
	ok = _save(shaman, "res://data/monsters/dark_shaman.tres") and ok
	return CastleData.generate(_save) and ok
