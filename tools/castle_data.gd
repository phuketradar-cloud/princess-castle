class_name CastleData
## Phase 4 data: the 5 princesses, furniture, furniture-material drops, exclusive bond cards,
## dialogue database and the roster. Called from tools/generate_data.gd (_generate_castle).

const T = CombatTypes.Target
const S = CombatTypes.Status
const SL = CastleTypes.FurnitureSlot
const W = CastleTypes.Wing
const P = CastleTypes.Personality
const X = CastleTypes.Expr
const R = ItemTypes.Rarity


static func generate(saver: Callable) -> bool:
	var ok := true
	for d in ["res://data/princesses", "res://data/furniture"]:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(d))

	# ---------- starter weapons for the new princesses (not in the loot table)
	var starters := {}
	for row in [
		["apprentice_wand", "Apprentice Wand", [0, 2, 0, 0.0, 0.0, 10.0], "ไม้กายสิทธิ์ของนักเวทฝึกหัด"],
		["twin_dagger", "Twin Dagger", [0, 2, 0, 0.04, 0.0, 0.0], "มีดสั้นคู่ใจ เบาและเร็ว"],
		["prayer_staff", "Prayer Staff", [15, 1, 0, 0.0, 0.0, 0.0], "คทาที่ใช้สวดภาวนาทุกเช้า"],
		["scale_club", "Scale Club", [0, 4, 0, 0.0, 0.0, 0.0], "กระบองหุ้มเกล็ดมังกร หนักแต่ทุบแรง"],
	]:
		var it := EquipmentDefinition.new()
		it.id = row[0]
		it.display_name = row[1]
		it.slot = ItemTypes.Slot.WEAPON
		it.rarity = R.COMMON
		var s: Array = row[2]
		it.stats = StatBlock.make(s[0], s[1], s[2], s[3], s[4], s[5])
		it.description = row[3]
		it.texture = load("res://assets/art/items/%s.png" % it.id)
		var path := "res://data/items/%s.tres" % it.id
		ok = saver.call(it, path) and ok
		starters[it.id] = load(path)

	# ---------- furniture
	var furniture := {}
	# id, name, slot, rarity, wing, [hp, atk, def, crit, eva, luck], skin, recipe, description
	var rows := [
		["simple_bed", "Simple Bed", SL.BED, R.COMMON, W.ANY, [0, 0, 0, 0.0, 0.0, 0.0], false, {}, "เตียงธรรมดาของปราสาท"],
		["old_desk", "Old Desk", SL.DESK, R.COMMON, W.ANY, [0, 0, 0, 0.0, 0.0, 0.0], false, {}, "โต๊ะไม้เก่าๆ"],
		["wooden_dummy", "Wooden Dummy", SL.TRAINING, R.COMMON, W.ANY, [0, 0, 0, 0.0, 0.0, 0.0], false, {}, "หุ่นฝึกไม้"],
		["plain_chair", "Plain Chair", SL.DECOR, R.COMMON, W.ANY, [0, 0, 0, 0.0, 0.0, 0.0], false, {}, "เก้าอี้ธรรมดา"],
		["lucky_bed", "Lucky Bed", SL.BED, R.RARE, W.ANY, [0, 0, 0, 0.0, 0.0, 12.0], false, {"light": 4, "ice": 2}, "นอนแล้วโชคดี (Luck)"],
		["dragon_bed", "Dragon Bed", SL.BED, R.LEGENDARY, W.DRAGON, [25, 3, 0, 0.0, 0.0, 0.0], false, {"dragon_scale": 2, "dragon": 4}, "เตียงเกล็ดมังกร — เฉพาะห้องมังกร"],
		["tea_set_table", "Tea Set Table", SL.DESK, R.RARE, W.ANY, [15, 0, 0, 0.0, 0.0, 0.0], false, {"light": 3, "fire": 2}, "โต๊ะน้ำชายามบ่าย (HP)"],
		["frozen_library", "Frozen Library", SL.DESK, R.EPIC, W.MAGIC, [0, 3, 0, 0.0, 0.0, 8.0], false, {"ice_crystal": 2, "ice": 5}, "ห้องสมุดผลึกน้ำแข็ง — เฉพาะห้องเวท"],
		["training_dummy", "Training Dummy", SL.TRAINING, R.RARE, W.ANY, [0, 2, 0, 0.0, 0.0, 0.0], false, {"fire": 4, "shadow": 1}, "หุ่นฝึกมีเป้า (Attack)"],
		["rose_training_hall", "Rose Training Hall", SL.TRAINING, R.EPIC, W.SWORD, [0, 4, 2, 0.0, 0.0, 0.0], false, {"bone_fragment": 2, "fire": 5}, "ชั้นวางอาวุธอัศวินกุหลาบ — เฉพาะห้องดาบ"],
		["shadow_mirror", "Shadow Mirror", SL.DECOR, R.EPIC, W.SHADOW, [0, 0, 0, 0.0, 0.04, 0.0], false, {"shadow": 6, "bone_fragment": 1}, "กระจกเงา (Evasion) — เฉพาะห้องเงา"],
		["light_throne", "Light Throne", SL.DECOR, R.LEGENDARY, W.LIGHT, [20, 0, 4, 0.0, 0.0, 0.0], false, {"holy_fragment": 2, "light": 6}, "บัลลังก์แสง — เฉพาะห้องแสง"],
		["velvet_wardrobe", "Velvet Wardrobe", SL.DECOR, R.RARE, W.ANY, [0, 0, 2, 0.0, 0.02, 0.0], false, {"shadow": 3, "light": 2}, "ตู้เสื้อผ้ากำมะหยี่"],
		["pink_canopy_bed", "Pink Canopy Bed", SL.BED, R.EPIC, W.ANY, [0, 0, 0, 0.0, 0.0, 0.0], true, {}, "สกินเตียง (ไม่มีค่าสถานะ) — รางวัล Bond"],
		["starry_canopy_bed", "Starry Canopy Bed", SL.BED, R.EPIC, W.ANY, [0, 0, 0, 0.0, 0.0, 0.0], true, {}, "สกินเตียงลายดาว (ไม่มีค่าสถานะ) — รางวัล Bond"],
		["rose_vanity", "Rose Vanity", SL.DECOR, R.EPIC, W.ANY, [0, 0, 0, 0.0, 0.0, 0.0], true, {}, "สกินโต๊ะเครื่องแป้ง (ไม่มีค่าสถานะ) — รางวัล Bond"],
	]
	for row in rows:
		var f := FurnitureDefinition.new()
		f.id = row[0]
		f.display_name = row[1]
		f.slot = row[2]
		f.rarity = row[3]
		f.room_type = row[4]
		var s: Array = row[5]
		f.stats = StatBlock.make(s[0], s[1], s[2], s[3], s[4], s[5])
		f.is_skin = row[6]
		f.recipe = row[7]
		f.description = row[8]
		f.texture = load("res://assets/art/furniture/%s.png" % f.id)
		# HD art from tools/build_room_art.gd replaces the placeholder when present.
		if ResourceLoader.exists("res://assets/art/furniture_hd/%s.png" % f.id):
			f.texture = load("res://assets/art/furniture_hd/%s.png" % f.id)
			f.room_scale = HD_FURNITURE_SCALE
		var path := "res://data/furniture/%s.tres" % f.id
		ok = saver.call(f, path) and ok
		furniture[f.id] = load(path)

	# ---------- exclusive bond cards (Lv5)
	var bond_cards := {}
	var exe := AbilitySpec.make("night_veil", "Night Veil", T.SINGLE_OPPONENT, 1.6).with_status(S.SLEEP, 2, 0.0)
	var heal := AbilitySpec.make("saints_grace", "Saint's Grace", T.SELF, 0.0)
	heal.heal_multiplier = 3.0
	for row in [
		["rose_oath", "Rose Oath", CardTypes.Category.SUPPORT, CardTypes.Element.FIRE, 1,
			AbilitySpec.make("rose_oath", "Rose Oath", T.SELF, 0.0).with_status(S.SHIELD, 3, 3.0), "holy_shield", "คำสาบานกุหลาบ: โล่ 300% ATK (การ์ดเฉพาะ Sword Princess)"],
		["arcane_surge", "Arcane Surge", CardTypes.Category.ATTACK, CardTypes.Element.ICE, 3,
			AbilitySpec.make("arcane_surge", "Arcane Surge", T.ALL_OPPONENTS, 1.5), "fire_blast", "พลังเวทพลุ่งพล่าน: ศัตรูทุกตัว 150% (การ์ดเฉพาะ Magic Princess)"],
		["night_veil", "Night Veil", CardTypes.Category.CONTROL, CardTypes.Element.SHADOW, 2, exe, "sleep", "ม่านราตรี: 160% + หลับ 2 เทิร์น (การ์ดเฉพาะ Shadow Princess)"],
		["saints_grace", "Saint's Grace", CardTypes.Category.SUPPORT, CardTypes.Element.LIGHT, 2, heal, "heal", "พรนักบุญ: ฟื้น HP 300% ATK (การ์ดเฉพาะ Light Princess)"],
		["dragon_soul", "Dragon Soul", CardTypes.Category.SPECIAL, CardTypes.Element.DRAGON, 4,
			AbilitySpec.make("dragon_soul", "Dragon Soul", T.ALL_OPPONENTS, 1.6).with_status(S.BURN, 3, 0.05), "dragons_wrath", "วิญญาณมังกร: ทุกตัว 160% + ติดไฟ (การ์ดเฉพาะ Dragon Princess)"],
	]:
		var c := CardDefinition.new()
		c.id = row[0]
		c.display_name = row[1]
		c.category = row[2]
		c.element = row[3]
		c.rarity = R.LEGENDARY
		c.mana_cost = row[4]
		c.effect = row[5]
		c.icon = load("res://assets/art/cards/%s.png" % row[6])
		c.description = row[7]
		c.drop_weight = 0.0
		var path := "res://data/cards/%s.tres" % c.id
		ok = saver.call(c, path) and ok
		bond_cards[c.id] = load(path)

	# ---------- the 5 princesses
	var exec_spec := AbilitySpec.make("assassinate", "Assassinate", T.SINGLE_OPPONENT, 1.3, 4)
	exec_spec.execute_threshold = 0.3
	exec_spec.execute_boss_multiplier = 2.0
	var prayer := AbilitySpec.make("prayer", "Prayer", T.SELF, 0.0, 3)
	prayer.heal_multiplier = 1.8
	var princesses := []
	var defs := [
		# id, name, title, archetype, personality, wing, unlock, liked, stats, abilities, starter, card, cosmetic, +mana start/max, weights, desc
		["sword_princess", "Sword Princess", "Blade of the Rose", 0, P.BRAVE, W.SWORD, 0, "fire",
			[160, 20, 6, 0.10, 0.05, 10.0],
			[AbilitySpec.make("attack", "Attack", T.SINGLE_OPPONENT, 1.0),
			 AbilitySpec.make("crescent_slash", "Crescent Slash", T.ALL_OPPONENTS, 0.75, 3),
			 AbilitySpec.make("pommel_bash", "Pommel Bash", T.SINGLE_OPPONENT, 0.6, 4).with_status(S.STUN, 1, 0.0)],
			"rusty_sword", "rose_oath", "rose_vanity", 0, 0, [1, 1, 1, 0.5, 3, 0.7, 0.8],
			"สายโจมตีกายภาพ สมดุล ตีเดี่ยวแรงและฟันกวาดทั้งแถว"],
		["magic_princess", "Magic Princess", "Keeper of Frost Tomes", 1, P.SCHOLARLY, W.MAGIC, 1, "ice",
			[130, 22, 3, 0.08, 0.05, 15.0],
			[AbilitySpec.make("attack", "Arcane Bolt", T.SINGLE_OPPONENT, 1.0),
			 AbilitySpec.make("chain_lightning", "Chain Lightning", T.ALL_OPPONENTS, 0.8, 3),
			 AbilitySpec.make("frost_lance", "Frost Lance", T.SINGLE_OPPONENT, 1.4, 4).with_status(S.FREEZE, 1, 0.0)],
			"apprentice_wand", "arcane_surge", "starry_canopy_bed", 1, 1, [0.8, 1, 1, 3, 0.3, 1, 1.5],
			"นักเวท: โจมตีเวทหมู่ มานาเริ่ม +1 และสูงสุด +1 — ใช้การ์ดได้มากที่สุด"],
		["shadow_princess", "Shadow Princess", "Daughter of the Moonless Night", 2, P.MYSTERIOUS, W.SHADOW, 2, "shadow",
			[140, 21, 4, 0.22, 0.18, 20.0],
			[AbilitySpec.make("attack", "Dagger", T.SINGLE_OPPONENT, 1.0),
			 AbilitySpec.make("twin_fangs", "Twin Fangs", T.SINGLE_OPPONENT, 0.65, 2, 2),
			 exec_spec],
			"twin_dagger", "night_veil", "starry_canopy_bed", 0, 0, [0.8, 1.5, 1, 0.6, 0.8, 3, 0.6],
			"นักฆ่าเงา: คริติคอลและหลบหลีกสูง ประหารศัตรูที่ใกล้ตาย"],
		["light_princess", "Light Princess", "Saint of the Morning Bell", 3, P.GENTLE, W.LIGHT, 3, "light",
			[175, 17, 8, 0.06, 0.04, 15.0],
			[AbilitySpec.make("attack", "Holy Strike", T.SINGLE_OPPONENT, 1.0),
			 prayer,
			 AbilitySpec.make("sanctuary", "Sanctuary", T.SELF, 0.0, 4).with_status(S.SHIELD, 3, 2.0)],
			"prayer_staff", "saints_grace", "pink_canopy_bed", 0, 0, [1, 1, 1, 1.5, 0.3, 1, 3],
			"นักบวชแสง: ฟื้นฟู HP และโล่ป้องกัน อึดที่สุด"],
		["dragon_princess", "Dragon Princess", "Last Ember of the Dragon Clan", 4, P.PROUD, W.DRAGON, 4, "dragon",
			[175, 20, 8, 0.08, 0.02, 5.0],
			[AbilitySpec.make("attack", "Claw", T.SINGLE_OPPONENT, 1.0),
			 AbilitySpec.make("dragon_roar", "Dragon Roar", T.ALL_OPPONENTS, 0.6, 3).with_status(S.WEAKEN, 2, 0.25),
			 AbilitySpec.make("dragon_fang", "Dragon Fang", T.SINGLE_OPPONENT, 1.9, 3)],
			"scale_club", "dragon_soul", "pink_canopy_bed", 0, 0, [1, 0.8, 2, 0.3, 2, 0.8, 0.5],
			"เจ้าหญิงมังกร: ตีหนัก ถึก ปราบบอส"],
	]
	for d in defs:
		var p := PrincessDefinition.new()
		p.id = d[0]
		p.display_name = d[1]
		p.title = d[2]
		p.archetype = d[3]
		p.personality = d[4]
		p.wing = d[5]
		p.unlock_clears = d[6]
		p.liked_material = d[7]
		var s: Array = d[8]
		p.base_stats = StatBlock.make(s[0], s[1], s[2], s[3], s[4], s[5])
		p.abilities.assign(d[9])
		var starter_item = starters.get(d[10])
		if starter_item == null:
			starter_item = load("res://data/items/%s.tres" % d[10])
		p.starting_equipment.assign([starter_item])
		p.bond_card = bond_cards[d[11]]
		p.bond_card.exclusive_to = p.id
		ok = saver.call(p.bond_card, p.bond_card.resource_path) and ok
		p.bond_cosmetic = furniture[d[12]]
		p.bonus_start_mana = d[13]
		p.bonus_max_mana = d[14]
		p.activity_weights = PackedFloat32Array(d[15])
		p.description = d[16]
		p.battle_texture = load("res://assets/art/princesses/%s/body.png" % p.id)
		p.face_dir = "res://assets/art/princesses/%s" % p.id
		p.face_anchor = Vector2(-4, -168)
		if HD_ART.has(p.id):
			_apply_hd_art(p, HD_ART[p.id])
		var path := "res://data/princess_sword.tres" if p.id == "sword_princess" else "res://data/princesses/%s.tres" % p.id
		ok = saver.call(p, path) and ok
		princesses.append(load(path))

	# ---------- dialogue
	var db := DialogueDB.new()
	for l in _lines():
		db.lines.append(l)
	ok = saver.call(db, "res://data/dialogue_db.tres") and ok

	# ---------- roster
	var roster := PrincessRoster.new()
	for p in princesses:
		roster.princesses.append(p)
	for id in furniture:
		roster.furniture.append(furniture[id])
	for id in ["simple_bed", "old_desk", "wooden_dummy", "plain_chair"]:
		roster.starter_furniture.append(furniture[id])
	roster.dialogue = load("res://data/dialogue_db.tres")
	roster.room_layouts.clear()
	for l in _room_layouts():
		roster.room_layouts.append(l)
	ok = saver.call(roster, "res://data/princess_roster.tres") and ok
	return ok


## Furniture-material drops added to existing monsters.
static func add_material_drops(slime: MonsterDefinition, skeleton: MonsterDefinition, shaman: MonsterDefinition) -> void:
	slime.drops.append(EssenceDrop.make_material("ice_crystal", 0.12, 1, 1))
	skeleton.drops.append(EssenceDrop.make_material("bone_fragment", 1.0, 1, 2))
	skeleton.drops.append(EssenceDrop.make_material("dragon_scale", 0.3, 1, 1))
	shaman.drops.append(EssenceDrop.make_material("holy_fragment", 0.4, 1, 1))


static func L(trigger: String, text: String, expr := 0, personality := -1, extra := {}) -> DialogueLine:
	var l := DialogueLine.make(trigger, text, expr, personality)
	l.princess_id = extra.get("princess", "")
	l.item_id = extra.get("item", "")
	l.slot = extra.get("slot", -1)
	l.min_rarity = extra.get("rarity", -1)
	l.min_bond = extra.get("bond", 0)
	return l


static func _lines() -> Array:
	var IS := ItemTypes.Slot
	return [
		# greeting
		L("GREETING", "ยินดีต้อนรับกลับมานะ!", X.HAPPY),
		L("GREETING", "กลับมาแล้วเหรอ! วันนี้ไปฝึกด้วยกันไหม?", X.HAPPY, P.BRAVE),
		L("GREETING", "อ๊ะ... ขอโทษที เพลินอ่านหนังสืออยู่น่ะ", X.CURIOUS, P.SCHOLARLY),
		L("GREETING", "ฉันรู้อยู่แล้วว่าเธอจะมา... ฮึๆ", X.SLY_SMILE, P.MYSTERIOUS),
		L("GREETING", "เหนื่อยไหม? มาจิบชาด้วยกันสิ", X.HAPPY, P.GENTLE),
		L("GREETING", "ฮึ่ม มาช้านะ... ไม่ได้รอหรอกนะ!", X.ANGRY, P.PROUD),
		# talk
		L("TALK", "อืม? มีอะไรเหรอ", X.CURIOUS),
		L("TALK", "ดาบต้องลับทุกวัน ใจก็เหมือนกัน!", X.HAPPY, P.BRAVE),
		L("TALK", "ถ้ามีมอนสเตอร์มาอีก ฉันจะปกป้องปราสาทเอง", X.NORMAL, P.BRAVE),
		L("TALK", "ขอบคุณที่อยู่ข้างๆ ฉันเสมอนะ", X.HAPPY, P.BRAVE, {"bond": 2}),
		L("TALK", "ถ้าไม่มีเธอ... ฉันคงไม่กล้าขนาดนี้หรอก", X.HAPPY, P.BRAVE, {"bond": 4}),
		L("TALK", "รู้ไหม Ice Prison เกิดจากผลึกน้ำแข็งสามชั้น!", X.CURIOUS, P.SCHOLARLY),
		L("TALK", "หนังสือเล่มนี้บอกว่าบอสกลัวไฟนะ... มั้ง", X.CURIOUS, P.SCHOLARLY),
		L("TALK", "เธอฟังฉันพูดเรื่องเวทมนตร์ได้ทั้งวันเลยเหรอ? ดีใจจัง", X.HAPPY, P.SCHOLARLY, {"bond": 2}),
		L("TALK", "ฉันจดชื่อเธอไว้ในหน้าแรกของสมุดเลยนะ", X.HAPPY, P.SCHOLARLY, {"bond": 4}),
		L("TALK", "เงาในห้องนี้คุยด้วยสนุกกว่าคนอื่น...", X.SLY_SMILE, P.MYSTERIOUS),
		L("TALK", "อย่ามองฉันนานนักสิ เดี๋ยวก็หายไปหรอก", X.SLY_SMILE, P.MYSTERIOUS),
		L("TALK", "ความลับของฉัน... บอกเธอคนเดียวก็ได้", X.SLY_SMILE, P.MYSTERIOUS, {"bond": 2}),
		L("TALK", "ในความมืด มีเธอเป็นแสงเดียวที่ฉันมองเห็น", X.HAPPY, P.MYSTERIOUS, {"bond": 4}),
		L("TALK", "วันนี้อากาศดีจัง ดอกไม้ในสวนบานแล้วนะ", X.HAPPY, P.GENTLE),
		L("TALK", "อย่าลืมดูแลตัวเองด้วยนะ", X.NORMAL, P.GENTLE),
		L("TALK", "ชาที่ชงวันนี้ ตั้งใจชงให้เธอเลยนะ", X.HAPPY, P.GENTLE, {"bond": 2}),
		L("TALK", "พรของฉันจะคุ้มครองเธอเสมอ", X.HAPPY, P.GENTLE, {"bond": 4}),
		L("TALK", "อย่าคิดว่าฉันชอบคุยกับเธอนะ!", X.ANGRY, P.PROUD),
		L("TALK", "มังกรอย่างฉันไม่กลัวอะไรทั้งนั้น... ยกเว้นแมงมุม", X.FEAR, P.PROUD),
		L("TALK", "ก็... ไม่ได้แย่ที่มีเธออยู่ด้วยหรอก", X.SLY_SMILE, P.PROUD, {"bond": 2}),
		L("TALK", "ฉันยอมรับเธอเป็นคู่หูก็ได้... แค่คนเดียวนะ!", X.HAPPY, P.PROUD, {"bond": 4}),
		L("TALK_LIMIT", "วันนี้คุยกันเยอะแล้ว พรุ่งนี้มาใหม่นะ", X.HAPPY),
		# activities
		L("ACTIVITY_SLEEPING", "ฮ้าว... ขอนอนอีกห้านาที...", X.NORMAL),
		L("ACTIVITY_READING", "หน้านี้น่าสนใจจัง...", X.CURIOUS),
		L("ACTIVITY_TRAINING", "ฮึบ! อีกร้อยครั้ง!", X.ANGRY),
		L("ACTIVITY_TRAINING", "เหงื่อออกแล้ว~ แต่สนุก!", X.HAPPY, P.BRAVE),
		L("ACTIVITY_LOOKING_OUTSIDE", "ดาวคืนนี้สวยจัง...", X.NORMAL),
		L("ACTIVITY_LOOKING_OUTSIDE", "ข้างนอกนั่น... มีอะไรซ่อนอยู่นะ", X.SLY_SMILE, P.MYSTERIOUS),
		L("ACTIVITY_DRINKING_TEA", "ชาหอมจัง~", X.HAPPY),
		L("ACTIVITY_SITTING", "พักสักหน่อยนะ", X.NORMAL),
		L("ACTIVITY_STANDING", "วันนี้ทำอะไรดีนะ", X.CURIOUS),
		# gifts / decorate / bond
		L("GIFT_LIKED", "ว้าว! ของที่ชอบที่สุดเลย ขอบคุณนะ!", X.HAPPY),
		L("GIFT_LIKED", "ฮะ!? ร-รู้ได้ไงว่าฉันชอบ... ขอบใจ", X.SURPRISED, P.PROUD),
		L("GIFT", "ขอบคุณนะ จะเก็บไว้อย่างดี", X.HAPPY),
		L("DECORATE", "ห้องดูสวยขึ้นเยอะเลย!", X.HAPPY),
		L("DECORATE", "มุมนี้ได้เงาสวยดี... ชอบนะ", X.SLY_SMILE, P.MYSTERIOUS),
		L("BOND_UP", "รู้สึกเหมือนเราสนิทกันมากขึ้นนะ", X.HAPPY),
		L("BOND_UP", "อ-อย่าเข้าใจผิดนะ! แค่... นิดเดียวเอง", X.ANGRY, P.PROUD),
		L("UNLOCK", "ยินดีที่ได้รู้จักนะ! ต่อจากนี้ฝากตัวด้วย", X.HAPPY),
		# equipment reactions (spec section 6)
		L("ITEM_RECEIVED", "ของใหม่! ขอบคุณนะ", X.HAPPY),
		L("ITEM_RECEIVED", "อาวุธใหม่! ลองฟันดูหน่อยดีกว่า", X.HAPPY, -1, {"slot": IS.WEAPON}),
		L("ITEM_RECEIVED", "เข้ากับฉันไหมนะ?", X.CURIOUS, -1, {"slot": IS.HEADGEAR}),
		L("ITEM_RECEIVED", "ปีกนี้... บินได้จริงหรือเปล่า?", X.SURPRISED, -1, {"slot": IS.WING}),
		L("ITEM_RECEIVED", "อุ่นจัง แต่หนักนิดหน่อยนะ", X.NORMAL, -1, {"slot": IS.ARMOR}),
		L("ITEM_RECEIVED", "แวววาวจัง~", X.HAPPY, -1, {"slot": IS.ACCESSORY}),
		L("ITEM_RECEIVED", "ข-ของระดับตำนาน!? จริงเหรอเนี่ย!", X.SURPRISED, -1, {"rarity": ItemTypes.Rarity.LEGENDARY}),
		L("ITEM_RECEIVED", "ฮึ ของที่คู่ควรกับฉันก็ต้องระดับนี้แหละ", X.SLY_SMILE, P.PROUD, {"rarity": ItemTypes.Rarity.LEGENDARY}),
		L("ITEM_RECEIVED", "ดาบเล่มนี้หนักจัง...", X.SURPRISED, -1, {"item": "dragon_sword"}),
		L("ITEM_RECEIVED", "มันสวยเกินไปหรือเปล่านะ?", X.CURIOUS, -1, {"item": "queen_crown"}),
		L("ITEM_RECEIVED", "ฉันดูน่ากลัวขึ้นไหม?", X.FEAR, -1, {"item": "dragon_wings"}),
		L("ITEM_RECEIVED", "หมวกแม่มด... รู้สึกฉลาดขึ้นเลย", X.SLY_SMILE, -1, {"item": "witch_hat"}),
		L("ITEM_RECEIVED", "เคียวนี้... เย็นยะเยือกจัง", X.FEAR, -1, {"item": "abyss_scythe"}),
		L("ITEM_RECEIVED", "ได้ยินเสียงกระซิบจากล็อกเก็ต...", X.FEAR, -1, {"item": "vampire_locket"}),
		L("ITEM_EQUIPPED", "เป็นไงบ้าง เหมาะกับฉันไหม?", X.HAPPY),
		L("ITEM_EQUIPPED", "พร้อมออกรบแล้ว!", X.HAPPY, P.BRAVE),
		L("ITEM_EQUIPPED", "แน่นอนว่าฉันใส่อะไรก็ดูดี", X.SLY_SMILE, P.PROUD),
		L("ITEM_EQUIPPED", "ขอดูในหนังสือก่อนว่าใช้ยังไง...", X.CURIOUS, P.SCHOLARLY),
		L("ITEM_CHANGED", "ขอบคุณของชิ้นเก่าที่ดูแลกันมานะ", X.NORMAL),
		L("ITEM_CHANGED", "ลาก่อน... ของเก่า", X.SLY_SMILE, P.MYSTERIOUS),
		L("ITEM_CHANGED", "เปลี่ยนแล้วรู้สึกเบาตัวขึ้นเลย", X.HAPPY, P.GENTLE),
		# battle (expressions per spec: boss=Fear, legendary=Surprised, win=Happy, lose=Crying, special=Sly)
		L("BATTLE_START", "ไปกันเถอะ!", X.NORMAL),
		L("BATTLE_START", "วิเคราะห์ศัตรูแล้ว... เริ่มได้!", X.CURIOUS, P.SCHOLARLY),
		L("BOSS_APPEAR", "ต-ตัวใหญ่จัง...", X.FEAR),
		L("BOSS_APPEAR", "น่ากลัว... แต่ฉันไม่ถอย!", X.FEAR, P.BRAVE),
		L("BOSS_APPEAR", "ม-มังกรอย่างฉันไม่กลัวหรอก!", X.FEAR, P.PROUD),
		L("VICTORY", "ชนะแล้ว!", X.HAPPY),
		L("VICTORY", "ก็บอกแล้วว่าฉันเก่งที่สุด", X.SLY_SMILE, P.PROUD),
		L("VICTORY", "ทุกคนปลอดภัยนะ ดีจัง", X.HAPPY, P.GENTLE),
		L("DEFEAT", "ฮึก... ขอโทษนะ...", X.CRYING),
		L("DEFEAT", "ครั้งหน้าฉันจะแข็งแกร่งกว่านี้...", X.CRYING, P.BRAVE),
		L("DEFEAT", "ฉ-ฉันไม่ได้ร้องไห้นะ!", X.CRYING, P.PROUD),
		L("CARD_SPECIAL", "ดูนี่สิ~", X.SLY_SMILE),
		L("CARD_SPECIAL", "หายไปซะ...", X.SLY_SMILE, P.MYSTERIOUS),
		# Phase 5: boss phases, level ups
		L("BOSS_PHASE", "ม-มันแข็งแกร่งขึ้นอีกแล้ว!", X.SURPRISED),
		L("BOSS_PHASE", "ระวัง! มันเปลี่ยนท่าแล้ว", X.FEAR, P.GENTLE),
		L("BOSS_PHASE", "ฮึ แค่นี้เองเหรอ?", X.ANGRY, P.PROUD),
		L("BOSS_PHASE", "น่าสนใจ... รูปแบบการโจมตีเปลี่ยนไป", X.CURIOUS, P.SCHOLARLY),
		L("LEVEL_UP", "รู้สึกแข็งแกร่งขึ้นเลย!", X.HAPPY),
		L("LEVEL_UP", "เห็นไหม ฉันเก่งขึ้นอีกแล้ว", X.SLY_SMILE, P.PROUD),
		L("LEVEL_UP", "เลเวลอัป! ต้องจดบันทึกไว้", X.CURIOUS, P.SCHOLARLY),
		# bond Lv3 story events (sequences)
		L("STORY_BOND3", "รู้ไหม... ตอนเด็กๆ ฉันกลัวความมืดมาก", X.NORMAL, -1, {"princess": "sword_princess", "bond": 3}),
		L("STORY_BOND3", "ท่านแม่มอบดาบเล่มแรกให้ แล้วบอกว่าความกล้าไม่ใช่การไม่กลัว", X.CURIOUS, -1, {"princess": "sword_princess", "bond": 3}),
		L("STORY_BOND3", "แต่คือการเดินหน้าทั้งที่กลัว... วันนี้ฉันเข้าใจแล้ว เพราะมีเธอ", X.HAPPY, -1, {"princess": "sword_princess", "bond": 3}),
		L("STORY_BOND3", "ห้องสมุดนี้เคยเป็นของอาจารย์ฉัน", X.NORMAL, -1, {"princess": "magic_princess", "bond": 3}),
		L("STORY_BOND3", "ท่านหายไปในคืนที่ดาวตก... ทิ้งไว้แค่สมุดเล่มนี้", X.CRYING, -1, {"princess": "magic_princess", "bond": 3}),
		L("STORY_BOND3", "ฉันจะอ่านมันให้จบ แล้วพาเธอไปหาท่านด้วยกันนะ", X.HAPPY, -1, {"princess": "magic_princess", "bond": 3}),
		L("STORY_BOND3", "ฉันเกิดในวันที่ไม่มีดวงจันทร์", X.SLY_SMILE, -1, {"princess": "shadow_princess", "bond": 3}),
		L("STORY_BOND3", "ทุกคนบอกว่าฉันเป็นลางร้าย ฉันจึงซ่อนตัวอยู่ในเงา", X.CRYING, -1, {"princess": "shadow_princess", "bond": 3}),
		L("STORY_BOND3", "แต่เธอเป็นคนแรกที่เรียกฉันออกมา... ขอบใจนะ", X.HAPPY, -1, {"princess": "shadow_princess", "bond": 3}),
		L("STORY_BOND3", "แสงของฉันรักษาคนอื่นได้ แต่รักษาตัวเองไม่ได้", X.NORMAL, -1, {"princess": "light_princess", "bond": 3}),
		L("STORY_BOND3", "บางคืนฉันก็เหนื่อยจนอยากร้องไห้", X.CRYING, -1, {"princess": "light_princess", "bond": 3}),
		L("STORY_BOND3", "แต่พอเห็นเธอยิ้ม ฉันก็มีแรงอีกครั้ง", X.HAPPY, -1, {"princess": "light_princess", "bond": 3}),
		L("STORY_BOND3", "ฉันเป็นมังกรตัวสุดท้ายของเผ่า", X.ANGRY, -1, {"princess": "dragon_princess", "bond": 3}),
		L("STORY_BOND3", "เลยต้องทำตัวเข้มแข็งตลอดเวลา...", X.CRYING, -1, {"princess": "dragon_princess", "bond": 3}),
		L("STORY_BOND3", "แต่กับเธอ... ฉันไม่ต้องฝืนก็ได้ใช่ไหม?", X.SURPRISED, -1, {"princess": "dragon_princess", "bond": 3}),
	]


## Princesses with real (AI parts-sheet) art built by tools/build_princess_art.gd.
## dir, art_scale, face anchor and slot anchors in on-screen pixels from her feet.
## Armor / accessory slots are left out: her outfit already IS armor, so those items
## give stats but are not drawn over the dress.
const HD_ART := {
	# v2 art (tools/build_princess_art_v2.gd): image px from feet x 0.35
	"sword_princess": {
		"dir": "res://assets/art/princesses/sword_princess_v2",
		"art_scale": 0.35,
		"face_anchor": Vector2(8.75, -165.2),
		"anchors": {ItemTypes.Slot.WEAPON: Vector2(47.3, -116.9), ItemTypes.Slot.HEADGEAR: Vector2(4.0, -217.0),
			ItemTypes.Slot.WING: Vector2(0.0, -124.0)},
	},
}


static func _apply_hd_art(p: PrincessDefinition, art: Dictionary) -> void:
	p.battle_texture = load(art.dir + "/body.png")
	p.face_dir = art.dir
	p.face_anchor = art.face_anchor
	p.art_scale = art.art_scale
	p.slot_anchors = art.anchors.duplicate()


## HD furniture (AI art) is drawn this much larger in the room.
const HD_FURNITURE_SCALE := 1.45


## Rooms with real background art: positions read off the background (1920x1080 screen,
## floor contact points). Back pieces are a bit smaller (depth).
static func _room_layouts() -> Array:
	var SLOT := CastleTypes.FurnitureSlot
	var sword := RoomLayout.new()
	sword.wing = CastleTypes.Wing.SWORD
	sword.background = load("res://assets/art/rooms_hd/sword_wing.png")
	sword.slot_positions = {SLOT.BED: Vector2(350, 1005), SLOT.DESK: Vector2(1300, 830),
		SLOT.TRAINING: Vector2(1530, 1015), SLOT.DECOR: Vector2(1030, 810)}
	sword.slot_depth_scale = {SLOT.BED: 1.1, SLOT.DESK: 0.9, SLOT.TRAINING: 1.1, SLOT.DECOR: 0.88}
	sword.window_spot = Vector2(700, 845)
	sword.stand_spot = Vector2(960, 990)
	var A := CastleTypes.Activity
	# Activity spots tuned to this art: lie on the mattress, read / drink tea in front of the desk.
	sword.spot_offsets = {A.SLEEPING: Vector2(215, -180), A.READING: Vector2(-200, 70), A.DRINKING_TEA: Vector2(-40, 110)}
	return [sword]
