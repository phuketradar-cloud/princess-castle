class_name CastleProgress
extends RefCounted
## Castle-side progress (pure logic, tested directly; saved by GameState):
## unlocks (stage clears), bond per princess, room furniture, owned furniture.
##
## Bond sources (spec): talk (max 3/day/princess), gifts, decorating her room,
## winning battles with her (companion use comes in Phase 5), special events.
## Bond NEVER adds combat stats; it unlocks dialogue, a story event (Lv3), a cosmetic (Lv4)
## and an exclusive card (Lv5).

signal changed

const TALK_BOND := 1
const TALKS_PER_DAY := 3
const GIFT_BOND := 1
const GIFT_LIKED_BOND := 3
const DECORATE_BOND := 2
const VICTORY_BOND := 1

var stage_clears := 0
var unlock_all := false              ## debug / test switch
var active_princess := ""
var bond := {}                       ## princess id -> points
var talks := {}                      ## princess id -> {"day": "YYYY-MM-DD", "count": n}
var flags: Array[String] = []        ## one-time events: "pid:story3", "pid:reward4", "pid:decor:<fid>"
var furniture := {}                  ## furniture id -> owned copies
var rooms := {}                      ## princess id -> {slot(int): furniture id}
# Phase 5
var levels := {}                     ## princess id -> {"level": n, "exp": n}
var cleared_stages: Array[String] = []
var companion := ""                  ## princess id of the companion ("" = none)
var selected_stage := ""


# ------------------------------------------------------------ unlocks

## Unlocked by clearing her `unlock_stage` (Phase 5) — older data used a clear count.
func is_unlocked(p: PrincessDefinition) -> bool:
	if p == null:
		return false
	if unlock_all:
		return true
	if p.unlock_stage != "":
		return cleared_stages.has(p.unlock_stage)
	return stage_clears >= p.unlock_clears


func is_stage_cleared(stage_id: String) -> bool:
	return cleared_stages.has(stage_id)


func is_stage_unlocked(stage: StageDefinition) -> bool:
	return stage != null and (unlock_all or stage.unlock_after == "" or cleared_stages.has(stage.unlock_after))


## Call when a stage is cleared. Returns the princesses that just became available.
func mark_stage_cleared(stage_id: String, roster: PrincessRoster) -> Array[PrincessDefinition]:
	var before := unlocked(roster)
	stage_clears += 1
	if not cleared_stages.has(stage_id):
		cleared_stages.append(stage_id)
	var newly: Array[PrincessDefinition] = []
	for p in unlocked(roster):
		if not before.has(p):
			newly.append(p)
	changed.emit()
	return newly


# ------------------------------------------------------------ levels

func level(princess_id: String) -> int:
	return int(levels.get(princess_id, {}).get("level", 1))


func exp_points(princess_id: String) -> int:
	return int(levels.get(princess_id, {}).get("exp", 0))


## Adds EXP; returns how many levels were gained.
func add_exp(princess_id: String, amount: int) -> int:
	if amount <= 0:
		return 0
	var lvl := level(princess_id)
	var xp := exp_points(princess_id) + amount
	var gained := 0
	while lvl < CastleTypes.MAX_LEVEL and xp >= CastleTypes.exp_to_next(lvl):
		xp -= CastleTypes.exp_to_next(lvl)
		lvl += 1
		gained += 1
	if lvl >= CastleTypes.MAX_LEVEL:
		xp = 0
	levels[princess_id] = {"level": lvl, "exp": xp}
	changed.emit()
	return gained


## Companion must be an unlocked princess other than the adventurer.
func set_companion(princess_id: String) -> void:
	companion = princess_id
	changed.emit()


func unlocked(roster: PrincessRoster) -> Array[PrincessDefinition]:
	var out: Array[PrincessDefinition] = []
	for p in roster.princesses:
		if is_unlocked(p):
			out.append(p)
	return out


## Call after a stage clear. Returns the princesses that just became available.
func add_stage_clear(roster: PrincessRoster) -> Array[PrincessDefinition]:
	var before := unlocked(roster)
	stage_clears += 1
	var newly: Array[PrincessDefinition] = []
	for p in unlocked(roster):
		if not before.has(p):
			newly.append(p)
	changed.emit()
	return newly


# ------------------------------------------------------------ bond

func bond_points(princess_id: String) -> int:
	return bond.get(princess_id, 0)


func bond_level(princess_id: String) -> int:
	return CastleTypes.bond_level(bond_points(princess_id))


## Adds bond; returns the new level if it went up, else -1.
func add_bond(princess_id: String, amount: int) -> int:
	if amount <= 0:
		return -1
	var before := bond_level(princess_id)
	bond[princess_id] = bond_points(princess_id) + amount
	changed.emit()
	var after := bond_level(princess_id)
	return after if after > before else -1


## Talking: +1 bond up to 3 times per day per princess. Returns the bond gained.
func talk(princess_id: String, day: String) -> int:
	var t: Dictionary = talks.get(princess_id, {"day": "", "count": 0})
	if t.day != day:
		t = {"day": day, "count": 0}
	if t.count >= TALKS_PER_DAY:
		talks[princess_id] = t
		return 0
	t.count += 1
	talks[princess_id] = t
	add_bond(princess_id, TALK_BOND)
	return TALK_BOND


func talks_left(princess_id: String, day: String) -> int:
	var t: Dictionary = talks.get(princess_id, {})
	return TALKS_PER_DAY if t.get("day", "") != day else maxi(0, TALKS_PER_DAY - t.count)


## Gift one material. Returns bond gained, or -1 if the player doesn't have it.
func gift(p: PrincessDefinition, material_key: String, col: Collection) -> int:
	if col.essence(material_key) <= 0:
		return -1
	col.materials[material_key] = col.essence(material_key) - 1
	var gain := GIFT_LIKED_BOND if material_key == p.liked_material else GIFT_BOND
	add_bond(p.id, gain)
	return gain


## Bond rewards not yet granted (Lv4 cosmetic, Lv5 exclusive card). Grants them; returns messages.
func claim_bond_rewards(p: PrincessDefinition, col: Collection) -> Array[String]:
	var out: Array[String] = []
	var lvl := bond_level(p.id)
	if lvl >= 4 and p.bond_cosmetic != null and not has_flag("%s:reward4" % p.id):
		flags.append("%s:reward4" % p.id)
		furniture[p.bond_cosmetic.id] = furniture.get(p.bond_cosmetic.id, 0) + 1
		out.append("ได้รับของตกแต่งพิเศษ: %s" % p.bond_cosmetic.display_name)
	if lvl >= 5 and p.bond_card != null and not has_flag("%s:reward5" % p.id):
		flags.append("%s:reward5" % p.id)
		col.add_card(p.bond_card)
		out.append("ได้รับการ์ดเฉพาะตัว: %s" % p.bond_card.display_name)
	if not out.is_empty():
		changed.emit()
	return out


func has_flag(flag: String) -> bool:
	return flags.has(flag)


func set_flag(flag: String) -> void:
	if not flags.has(flag):
		flags.append(flag)
		changed.emit()


# ------------------------------------------------------------ rooms & furniture

## Gives a princess her starter furniture the first time her room is used.
func ensure_room(p: PrincessDefinition, roster: PrincessRoster) -> void:
	if rooms.has(p.id):
		return
	var room := {}
	for f in roster.starter_furniture:
		if f != null and not room.has(f.slot):
			furniture[f.id] = furniture.get(f.id, 0) + 1
			room[f.slot] = f.id
	rooms[p.id] = room
	changed.emit()


func room_items(princess_id: String, roster: PrincessRoster) -> Array[FurnitureDefinition]:
	var out: Array[FurnitureDefinition] = []
	var room: Dictionary = rooms.get(princess_id, {})
	for slot in CastleTypes.FurnitureSlot.values():
		if room.has(slot):
			var f := roster.find_furniture(room[slot])
			if f != null:
				out.append(f)
	return out


func in_slot(princess_id: String, slot: int, roster: PrincessRoster) -> FurnitureDefinition:
	return roster.find_furniture(rooms.get(princess_id, {}).get(slot, ""))


## Stat bonus for this princess from HER room only (capped, diminishing).
func furniture_bonus(princess_id: String, roster: PrincessRoster) -> StatBlock:
	return FurnitureRules.room_bonus(room_items(princess_id, roster))


func placed_count(furniture_id: String) -> int:
	var n := 0
	for pid in rooms:
		for slot in rooms[pid]:
			if rooms[pid][slot] == furniture_id:
				n += 1
	return n


func available(furniture_id: String) -> int:
	return furniture.get(furniture_id, 0) - placed_count(furniture_id)


## Places furniture in a princess's room (replacing what was in that slot). "" = ok.
## First time a piece goes into her room: +bond.
func place(p: PrincessDefinition, f: FurnitureDefinition) -> String:
	if f == null:
		return "ไม่มีเฟอร์นิเจอร์นี้"
	if not f.fits(p.wing):
		return "%s ใช้ได้เฉพาะ %s" % [f.display_name, CastleTypes.WING_NAMES[f.room_type]]
	var room: Dictionary = rooms.get(p.id, {})
	if room.get(f.slot, "") == f.id:
		return "วางอยู่แล้ว"
	if available(f.id) <= 0:
		return "ไม่มี %s เหลือ (วางอยู่ห้องอื่น)" % f.display_name
	room[f.slot] = f.id
	rooms[p.id] = room
	var flag := "%s:decor:%s" % [p.id, f.id]
	if not has_flag(flag):
		flags.append(flag)
		add_bond(p.id, DECORATE_BOND)
	changed.emit()
	return ""


func can_craft(f: FurnitureDefinition, col: Collection) -> bool:
	if f == null or f.recipe.is_empty():
		return false
	for key in f.recipe:
		if col.essence(key) < int(f.recipe[key]):
			return false
	return true


func craft(f: FurnitureDefinition, col: Collection) -> bool:
	if not can_craft(f, col):
		return false
	for key in f.recipe:
		col.materials[key] = col.essence(key) - int(f.recipe[key])
	furniture[f.id] = furniture.get(f.id, 0) + 1
	changed.emit()
	return true


# ------------------------------------------------------------ save format

func to_dict() -> Dictionary:
	var room_out := {}
	for pid in rooms:
		var r := {}
		for slot in rooms[pid]:
			r[CastleTypes.FurnitureSlot.keys()[slot]] = rooms[pid][slot]
		room_out[pid] = r
	return {"stage_clears": stage_clears, "active_princess": active_princess, "bond": bond.duplicate(),
		"talks": talks.duplicate(true), "flags": flags.duplicate(), "furniture": furniture.duplicate(), "rooms": room_out,
		"levels": levels.duplicate(true), "cleared_stages": cleared_stages.duplicate(), "companion": companion,
		"selected_stage": selected_stage}


func from_dict(data: Dictionary, roster: PrincessRoster) -> void:
	stage_clears = int(data.get("stage_clears", 0))
	active_princess = str(data.get("active_princess", ""))
	bond.clear()
	var b: Dictionary = data.get("bond", {})
	for pid in b:
		bond[pid] = int(b[pid])
	talks = data.get("talks", {}).duplicate(true)
	flags.clear()
	for f in data.get("flags", []):
		flags.append(str(f))
	furniture.clear()
	var fu: Dictionary = data.get("furniture", {})
	for fid in fu:
		if roster == null or roster.find_furniture(fid) != null:
			furniture[fid] = int(fu[fid])
	rooms.clear()
	var ro: Dictionary = data.get("rooms", {})
	for pid in ro:
		var r := {}
		for slot_name in ro[pid]:
			var slot := CastleTypes.FurnitureSlot.keys().find(slot_name)
			var fid: String = ro[pid][slot_name]
			if slot >= 0 and furniture.has(fid):
				r[slot] = fid
		rooms[pid] = r
	# Phase 5 fields (absent in older saves -> defaults / migration).
	levels.clear()
	var lv: Dictionary = data.get("levels", {})
	for pid in lv:
		levels[pid] = {"level": clampi(int(lv[pid].get("level", 1)), 1, CastleTypes.MAX_LEVEL), "exp": maxi(0, int(lv[pid].get("exp", 0)))}
	cleared_stages.clear()
	for s in data.get("cleared_stages", []):
		cleared_stages.append(str(s))
	if cleared_stages.is_empty() and stage_clears > 0:
		cleared_stages.append("stage_01") # Phase 4 saves only had stage 1
	companion = str(data.get("companion", ""))
	selected_stage = str(data.get("selected_stage", ""))
	changed.emit()
