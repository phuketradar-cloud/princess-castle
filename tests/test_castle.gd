extends RefCounted
## Phase 4 tests: bond, talk limit, gifts, bond rewards, furniture rules (caps, diminishing returns,
## skins, owner-only, room type), crafting, unlocks, dialogue selection, princess data, save.

const SL = CastleTypes.FurnitureSlot
const W = CastleTypes.Wing

var failures: Array[String] = []


func check(cond: bool, msg: String) -> void:
	if not cond:
		failures.append(msg)

func eq(actual, expected, msg: String) -> void:
	if actual != expected:
		failures.append("%s (expected %s, got %s)" % [msg, str(expected), str(actual)])

func princess(id := "p1", wing := W.SWORD, unlock := 0, liked := "fire") -> PrincessDefinition:
	var p := PrincessDefinition.new()
	p.id = id
	p.display_name = id
	p.wing = wing
	p.unlock_clears = unlock
	p.liked_material = liked
	p.base_stats = StatBlock.make(100, 20, 5)
	p.abilities = [AbilitySpec.make("attack", "Attack", CombatTypes.Target.SINGLE_OPPONENT, 1.0)]
	return p

func furn(id: String, slot: int, stats := [0, 0, 0, 0.0, 0.0, 0.0], wing := W.ANY, skin := false, recipe := {}) -> FurnitureDefinition:
	var f := FurnitureDefinition.new()
	f.id = id
	f.display_name = id
	f.slot = slot
	f.room_type = wing
	f.is_skin = skin
	f.recipe = recipe
	f.stats = StatBlock.make(stats[0], stats[1], stats[2], stats[3], stats[4], stats[5])
	return f

func roster_with(princesses: Array, furniture: Array) -> PrincessRoster:
	var r := PrincessRoster.new()
	for p in princesses:
		r.princesses.append(p)
	for f in furniture:
		r.furniture.append(f)
	r.starter_furniture.append(furn("bed0", SL.BED))
	r.starter_furniture.append(furn("desk0", SL.DESK))
	return r


# ------------------------------------------------------------ bond

func test_bond_levels() -> void:
	eq(CastleTypes.bond_level(0), 0, "0 pts")
	eq(CastleTypes.bond_level(9), 0, "9 pts")
	eq(CastleTypes.bond_level(10), 1, "10 pts")
	eq(CastleTypes.bond_level(45), 3, "45 pts")
	eq(CastleTypes.bond_level(9999), 5, "max level 5")
	eq(CastleTypes.bond_next(9999), 0, "no next when maxed")

func test_talk_daily_limit() -> void:
	var c := CastleProgress.new()
	var gained := 0
	for i in 5:
		gained += c.talk("p1", "2026-01-01")
	eq(gained, 3, "3 talks per day give bond")
	eq(c.talks_left("p1", "2026-01-01"), 0, "none left")
	eq(c.talk("p1", "2026-01-02"), 1, "new day resets")
	eq(c.talk("p2", "2026-01-01"), 1, "limit is per princess")

func test_gifts() -> void:
	var c := CastleProgress.new()
	var col := Collection.new()
	var p := princess("p1", W.SWORD, 0, "fire")
	eq(c.gift(p, "fire", col), -1, "no material -> refused")
	col.add_essence("fire", 1)
	col.add_essence("ice", 1)
	eq(c.gift(p, "fire", col), CastleProgress.GIFT_LIKED_BOND, "liked gift")
	eq(c.gift(p, "ice", col), CastleProgress.GIFT_BOND, "normal gift")
	eq(col.essence("fire"), 0, "material consumed")

func test_bond_rewards_granted_once() -> void:
	var c := CastleProgress.new()
	var col := Collection.new()
	var p := princess()
	p.bond_cosmetic = furn("skin", SL.BED, [0, 0, 0, 0.0, 0.0, 0.0], W.ANY, true)
	var card := CardDefinition.new()
	card.id = "excl"
	card.effect = AbilitySpec.new()
	p.bond_card = card
	c.add_bond(p.id, CastleTypes.BOND_THRESHOLDS[4])
	eq(c.claim_bond_rewards(p, col).size(), 1, "Lv4 -> cosmetic only")
	eq(c.furniture.get("skin", 0), 1, "cosmetic owned")
	check(not col.cards.has("excl"), "no card before Lv5")
	c.add_bond(p.id, 100)
	eq(c.claim_bond_rewards(p, col).size(), 1, "Lv5 -> card")
	check(col.cards.has("excl"), "exclusive card owned")
	eq(c.claim_bond_rewards(p, col).size(), 0, "never granted twice")

func test_add_bond_reports_level_up() -> void:
	var c := CastleProgress.new()
	eq(c.add_bond("p", 5), -1, "no level up")
	eq(c.add_bond("p", 5), 1, "level 1 reached")


# ------------------------------------------------------------ furniture rules

func test_diminishing_returns_and_cap() -> void:
	eq(FurnitureRules.diminish(0.0, 6.0), 0.0, "zero")
	check(absf(FurnitureRules.diminish(6.0, 6.0) - 3.0) < 0.001, "raw = cap -> half the cap")
	check(FurnitureRules.diminish(1000.0, 6.0) < 6.0, "never reaches the cap")
	var many := []
	for i in 10:
		many.append(furn("a%d" % i, SL.TRAINING, [0, 10, 0, 0.0, 0.0, 0.0]))
	check(FurnitureRules.room_bonus(many).attack <= int(FurnitureRules.CAPS.attack), "attack capped")

func test_skin_gives_no_stats() -> void:
	var skin := furn("s", SL.BED, [50, 50, 50, 0.0, 0.5, 50.0], W.ANY, true)
	var b := FurnitureRules.room_bonus([skin])
	eq(b.max_hp + b.attack + b.defense, 0, "skin ignored")

func test_furniture_owner_only_and_room_type() -> void:
	var lucky := furn("lucky", SL.BED, [0, 0, 0, 0.0, 0.0, 12.0])
	var dragon_bed := furn("dbed", SL.BED, [20, 0, 0, 0.0, 0.0, 0.0], W.DRAGON)
	var p1 := princess("p1", W.SWORD)
	var p2 := princess("p2", W.MAGIC)
	var r := roster_with([p1, p2], [lucky, dragon_bed])
	var c := CastleProgress.new()
	c.ensure_room(p1, r)
	c.ensure_room(p2, r)
	c.furniture["lucky"] = 1
	c.furniture["dbed"] = 1
	check(c.place(p1, dragon_bed) != "", "Dragon-only furniture refused in Sword wing")
	eq(c.place(p1, lucky), "", "placed")
	check(c.furniture_bonus("p1", r).luck > 0, "owner gets luck")
	eq(c.furniture_bonus("p2", r).luck, 0.0, "other princess gets nothing")
	check(c.place(p2, lucky) != "", "only one copy -> can't place twice")
	eq(c.in_slot("p1", SL.BED, r).id, "lucky", "replaced the starter bed")
	eq(c.available("bed0"), 1, "starter bed returned to storage")

func test_decorate_bond_once_per_piece() -> void:
	var f := furn("f", SL.DESK)
	var p := princess()
	var r := roster_with([p], [f])
	var c := CastleProgress.new()
	c.ensure_room(p, r)
	c.furniture["f"] = 1
	c.place(p, f)
	var pts := c.bond_points(p.id)
	eq(pts, CastleProgress.DECORATE_BOND, "first placement gives bond")
	c.place(p, r.starter_furniture[1])
	c.place(p, f)
	eq(c.bond_points(p.id), pts + CastleProgress.DECORATE_BOND, "starter desk gave bond once, f not again")

func test_craft_furniture() -> void:
	var f := furn("t", SL.TRAINING, [0, 2, 0, 0.0, 0.0, 0.0], W.ANY, false, {"fire": 4, "bone_fragment": 1})
	var c := CastleProgress.new()
	var col := Collection.new()
	col.add_essence("fire", 4)
	check(not c.can_craft(f, col), "missing bone")
	col.add_essence("bone_fragment", 2)
	check(c.craft(f, col), "crafted")
	eq(col.essence("fire"), 0, "fire spent")
	eq(col.essence("bone_fragment"), 1, "bone spent")
	eq(c.furniture.get("t", 0), 1, "owned")


# ------------------------------------------------------------ unlocks

func test_unlock_by_stage_clears() -> void:
	var a := princess("a", W.SWORD, 0)
	var b := princess("b", W.MAGIC, 1)
	var d := princess("d", W.DRAGON, 2)
	var r := roster_with([a, b, d], [])
	var c := CastleProgress.new()
	eq(c.unlocked(r).size(), 1, "only the first")
	var newly := c.add_stage_clear(r)
	eq(newly.size(), 1, "one unlocked")
	eq(newly[0].id, "b", "magic princess")
	c.add_stage_clear(r)
	eq(c.unlocked(r).size(), 3, "all three")


# ------------------------------------------------------------ dialogue

func test_dialogue_specificity() -> void:
	var db := DialogueDB.new()
	db.lines = [
		DialogueLine.make("ITEM_RECEIVED", "generic"),
		_l("ITEM_RECEIVED", "weapon", {"slot": ItemTypes.Slot.WEAPON}),
		_l("ITEM_RECEIVED", "dragon sword", {"item": "dragon_sword"}),
		_l("ITEM_RECEIVED", "proud generic", {"personality": CastleTypes.Personality.PROUD}),
		_l("TALK", "bond talk", {"bond": 3}),
		DialogueLine.make("TALK", "normal talk"),
	]
	var p := princess()
	p.personality = CastleTypes.Personality.BRAVE
	var item := EquipmentDefinition.new()
	item.id = "dragon_sword"
	item.slot = ItemTypes.Slot.WEAPON
	eq(db.pick("ITEM_RECEIVED", DialogueDB.context(p, 0, item)).text, "dragon sword", "item line wins")
	item.id = "other_sword"
	eq(db.pick("ITEM_RECEIVED", DialogueDB.context(p, 0, item)).text, "weapon", "slot line next")
	var armor := EquipmentDefinition.new()
	armor.slot = ItemTypes.Slot.ARMOR
	eq(db.pick("ITEM_RECEIVED", DialogueDB.context(p, 0, armor)).text, "generic", "generic fallback")
	p.personality = CastleTypes.Personality.PROUD
	eq(db.pick("ITEM_RECEIVED", DialogueDB.context(p, 0, armor)).text, "proud generic", "personality line")
	eq(db.pick("TALK", DialogueDB.context(p, 0)).text, "normal talk", "bond line locked")
	eq(db.pick("TALK", DialogueDB.context(p, 3)).text, "bond talk", "bond line unlocked")
	eq(db.pick("NOPE", DialogueDB.context(p, 0)), null, "unknown trigger")

func _l(trigger: String, text: String, f: Dictionary) -> DialogueLine:
	var l := DialogueLine.make(trigger, text, 0, f.get("personality", -1))
	l.item_id = f.get("item", "")
	l.slot = f.get("slot", -1)
	l.min_bond = f.get("bond", 0)
	return l


# ------------------------------------------------------------ combat hooks

func test_furniture_bonus_and_mana_perk_in_battle() -> void:
	var p := princess()
	var u := UnitFactory.create_princess(p, 0, -1, [], StatBlock.make(10, 3, 1))
	eq(u.stats.max_hp, 110, "hp + furniture")
	eq(u.stats.attack, 23, "atk + furniture")
	var cfg := BattleConfig.new().with_mana_bonus(1, 1)
	eq(cfg.start_mana, BattleConfig.new().start_mana + 1, "start mana +1")
	eq(cfg.max_mana, BattleConfig.new().max_mana + 1, "max mana +1")

func test_exclusive_cards() -> void:
	var c := CardDefinition.new()
	c.exclusive_to = "sword_princess"
	check(c.usable_by("sword_princess"), "owner can use")
	check(not c.usable_by("magic_princess"), "others cannot")
	check(CardDefinition.new().usable_by("anyone"), "normal cards for all")


# ------------------------------------------------------------ save

func test_castle_save_roundtrip() -> void:
	var f := furn("lucky", SL.BED)
	var p := princess()
	var r := roster_with([p], [f])
	var c := CastleProgress.new()
	c.ensure_room(p, r)
	c.furniture["lucky"] = 1
	c.place(p, f)
	c.add_bond("p1", 30)
	c.talk("p1", "2026-01-01")
	c.stage_clears = 2
	c.active_princess = "p1"
	var data = JSON.parse_string(JSON.stringify(c.to_dict()))
	var c2 := CastleProgress.new()
	c2.from_dict(data, r)
	eq(c2.stage_clears, 2, "clears")
	eq(c2.bond_points("p1"), c.bond_points("p1"), "bond")
	eq(c2.in_slot("p1", SL.BED, r).id, "lucky", "room")
	eq(c2.active_princess, "p1", "active princess")
	eq(c2.talks_left("p1", "2026-01-01"), 2, "talk log")
	var c3 := CastleProgress.new()
	c3.from_dict({}, r) # Phase 3 save: no castle section
	eq(c3.stage_clears, 0, "defaults")


# ------------------------------------------------------------ real data

func test_real_roster() -> void:
	var r: PrincessRoster = load("res://data/princess_roster.tres")
	if r == null:
		failures.append("princess_roster.tres missing")
		return
	eq(r.princesses.size(), 5, "5 princesses")
	var wings := {}
	for p in r.princesses:
		wings[p.wing] = true
		check(p.abilities.size() >= 3, "%s has 3 abilities" % p.id)
		check(not p.starting_equipment.is_empty(), "%s has starter weapon" % p.id)
		check(p.bond_card != null and p.bond_card.exclusive_to == p.id, "%s exclusive card" % p.id)
		check(p.bond_cosmetic != null and p.bond_cosmetic.is_skin, "%s cosmetic is a skin" % p.id)
		for expr in CastleTypes.EXPRESSION_PARTS:
			var parts: Array = CastleTypes.EXPRESSION_PARTS[expr]
			check(ResourceLoader.exists("%s/eyes_%s.png" % [p.face_dir, parts[0]]), "%s eyes_%s" % [p.id, parts[0]])
			if p.art_scale != 1.0:
				continue # HD art: one whole-face overlay per expression (eyes_*), no brow / mouth layers
			check(ResourceLoader.exists("%s/brows_%s.png" % [p.face_dir, parts[1]]), "%s brows_%s" % [p.id, parts[1]])
			check(ResourceLoader.exists("%s/mouth_%s.png" % [p.face_dir, parts[2]]), "%s mouth_%s" % [p.id, parts[2]])
		check(ResourceLoader.exists(p.face_dir + "/eyes_closed.png"), "%s blink frame" % p.id)
	eq(wings.size(), 5, "one wing each")
	eq(r.starter_furniture.size(), 4, "a starter piece per slot")
	for f in r.craftable_furniture():
		check(f.texture != null, "%s art" % f.id)
		for key in f.recipe:
			check(CastleTypes.is_material(key), "%s recipe key %s" % [f.id, key])
	check(r.dialogue != null and r.dialogue.lines.size() >= 60, "dialogue database")
	for p in r.princesses:
		eq(r.dialogue.sequence("STORY_BOND3", p.id).size(), 3, "%s story event" % p.id)
