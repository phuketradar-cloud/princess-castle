extends Node
## Autoload "GameState": the player's persistent progress.
##   collection : equipment, cards, deck, materials        (Phase 2-3)
##   castle     : unlocks, bond, rooms & furniture, active princess (Phase 4)
## Saved as JSON in user://. The format is versioned; missing fields get defaults so new
## fields can be added later (Phase 6 extends this into the full save system).

const SAVE_PATH := "user://princess_castle_save.json"
const SAVE_VERSION := 5 # 2 = cards, 3 = castle, 4 = levels/EXP, stages, companion, 5 = checksum wrapper + backups
const ROSTER_PATH := "res://data/princess_roster.tres"
const LOOT_PATH := "res://data/loot_table.tres"

var collection := Collection.new()
var castle := CastleProgress.new()
var roster: PrincessRoster
var loot: LootTable
## Tests / autoplay turn this off so they never touch the player's real save.
var persist := true
## Overridable so tests can save somewhere harmless.
var save_path := SAVE_PATH
var _loaded := false

## Phase 6
signal saved
var last_saved_at := ""
## Which file the last load came from ("" = none / fresh).
var load_source := ""


## Registers catalogs and loads the save once. Safe to call repeatedly from any scene.
func setup(p_loot: LootTable = null, princess: PrincessDefinition = null) -> void:
	if roster == null and ResourceLoader.exists(ROSTER_PATH):
		roster = load(ROSTER_PATH)
	if p_loot == null and loot == null and ResourceLoader.exists(LOOT_PATH):
		p_loot = load(LOOT_PATH)
	if p_loot != null:
		loot = p_loot
		collection.register(loot.items)
		collection.register_cards(loot.card_library)
	if roster != null:
		for p in roster.princesses:
			collection.register(p.starting_equipment)
			if p.bond_card != null:
				collection.card_catalog[p.bond_card.id] = p.bond_card
	if princess != null:
		collection.register(princess.starting_equipment)
	if not _loaded:
		_loaded = true
		load_game()
	if princess != null:
		collection.ensure_starting_gear(princess)
	if loot != null:
		collection.ensure_starting_cards(loot.card_library)


## The princess going on the next adventure (falls back to the first unlocked one).
func active_princess() -> PrincessDefinition:
	if roster == null:
		return null
	var p := roster.find(castle.active_princess)
	if p != null and castle.is_unlocked(p):
		return p
	var list := castle.unlocked(roster)
	return list[0] if not list.is_empty() else null


func set_active_princess(p: PrincessDefinition) -> void:
	castle.active_princess = p.id
	collection.ensure_starting_gear(p)
	save_game()


## Today's date for daily limits (talks).
func today() -> String:
	return Time.get_date_string_from_system()


## Saves everything (equipment, inventory, cards, deck, materials, castle, bond, levels,
## stages, companion). Format: {"version", "saved_at", "checksum", "data": {...}}.
## Safety: write to .tmp -> verify by reading back -> keep the 2 previous saves as
## .1 / .2 -> rename. A crash mid-save never touches the previous good file.
func save_game() -> bool:
	if not persist:
		return false
	var data := {"collection": collection.to_dict(), "castle": castle.to_dict()}
	# Checksum over a canonical form (parse -> stringify) so int/float JSON round-trips match.
	var body := _canonical(data)
	var wrapper := {"version": SAVE_VERSION, "saved_at": Time.get_datetime_string_from_system(),
		"checksum": body.sha256_text(), "data": data}
	var text := JSON.stringify(wrapper, "  ")
	var tmp := save_path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		push_error("Save failed: %s" % error_string(FileAccess.get_open_error()))
		return false
	f.store_string(text)
	f.close()
	if _read_save(tmp).is_empty():
		push_error("Save failed: written file did not verify")
		return false
	# Rotate backups: .1 -> .2, current -> .1
	if FileAccess.file_exists(save_path + ".1"):
		DirAccess.copy_absolute(save_path + ".1", save_path + ".2")
	if FileAccess.file_exists(save_path):
		DirAccess.copy_absolute(save_path, save_path + ".1")
	var err := DirAccess.rename_absolute(tmp, save_path)
	if err != OK:
		push_error("Save failed: %s" % error_string(err))
		return false
	last_saved_at = wrapper.saved_at
	saved.emit()
	return true


## Loads the newest readable save: main file, else backup .1, else .2.
## An unreadable main file is kept as .bak so nothing is ever silently lost.
func load_game() -> void:
	if not persist:
		return
	load_source = ""
	for candidate in [save_path, save_path + ".1", save_path + ".2"]:
		if not FileAccess.file_exists(candidate):
			continue
		var data := _read_save(candidate)
		if data.is_empty():
			push_warning("Save file %s unreadable or damaged" % candidate)
			if candidate == save_path:
				DirAccess.copy_absolute(save_path, save_path + ".bak")
			continue
		collection.from_dict(data.get("collection", {}))
		castle.from_dict(data.get("castle", {}), roster)
		load_source = candidate
		if candidate != save_path:
			push_warning("Loaded backup save %s" % candidate)
		return


## Returns the save's data dictionary, or {} if the file is missing, not JSON or fails its
## checksum. Accepts the old (version <= 4, unwrapped) format too.
func _read_save(path: String) -> Dictionary:
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	if not parsed.has("data"):
		return parsed if parsed.has("collection") or parsed.has("castle") else {}
	var data = parsed.get("data")
	if typeof(data) != TYPE_DICTIONARY:
		return {}
	if parsed.has("checksum") and _canonical(data).sha256_text() != str(parsed.checksum):
		return {}
	return data


static func _canonical(data: Dictionary) -> String:
	return JSON.stringify(JSON.parse_string(JSON.stringify(data)))


## Saves when the app goes to the background / is closed (Android can kill it anytime).
func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_WM_CLOSE_REQUEST:
			if _loaded:
				save_game()


## "New Game": wipes progress (keeps the previous save as backup .1) and starts fresh.
func new_game() -> void:
	if persist and FileAccess.file_exists(save_path):
		DirAccess.copy_absolute(save_path, save_path + ".1")
		DirAccess.remove_absolute(save_path)
	collection = Collection.new()
	castle = CastleProgress.new()
	_loaded = true # do not load the old save again
	setup()
	var p := active_princess()
	if p != null:
		collection.ensure_starting_gear(p)
	save_game()


## Wipes progress (for testing).
func reset() -> void:
	collection.owned.clear()
	collection.equipped.clear()
	castle = CastleProgress.new()
	if persist and FileAccess.file_exists(save_path):
		DirAccess.remove_absolute(save_path)


# ------------------------------------------------------------ Phase 5 helpers

## Stage chosen on the stage select screen (falls back to the first stage).
func selected_stage() -> StageDefinition:
	if roster == null or roster.stages.is_empty():
		return null
	var s := roster.find_stage(castle.selected_stage)
	if s != null and castle.is_stage_unlocked(s):
		return s
	return roster.stages[0]


## Companion if valid (unlocked and not the adventurer), else null.
func companion_princess() -> PrincessDefinition:
	if roster == null:
		return null
	var c := roster.find(castle.companion)
	var a := active_princess()
	if c == null or not castle.is_unlocked(c) or (a != null and c.id == a.id):
		return null
	return c
