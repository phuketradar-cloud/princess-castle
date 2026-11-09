class_name Collection
extends RefCounted
## Owned equipment + what each princess wears. Pure logic (tests use it directly);
## the GameState autoload wraps it and handles saving.

signal changed

## Item lookup (id -> EquipmentDefinition), filled from the loot table + starting gear.
var catalog := {}
## Owned item ids (unique).
var owned: Array[String] = []
## princess id -> { slot(int) -> item id }
var equipped := {}

# ---- Phase 3: cards & materials
## Card lookup (id -> CardDefinition).
var card_catalog := {}
## Owned cards: id -> copies.
var cards := {}
## Battle deck: card ids (unique, max deck_size).
var deck: Array[String] = []
var deck_size := 5
## Essences: element key ("fire"...) -> amount.
var materials := {}
var cards_initialized := false


func register(items: Array) -> void:
	for it in items:
		if it != null and it.id != "":
			catalog[it.id] = it


func get_item(item_id: String) -> EquipmentDefinition:
	return catalog.get(item_id)


func owns(item_id: String) -> bool:
	return owned.has(item_id)


func add(item: EquipmentDefinition) -> void:
	if item == null:
		return
	catalog[item.id] = item
	if not owned.has(item.id):
		owned.append(item.id)
	changed.emit()


## Equips an owned item; returns the item it replaced (or null).
func equip(princess_id: String, item_id: String) -> EquipmentDefinition:
	var item := get_item(item_id)
	if item == null or not owns(item_id):
		push_warning("Collection.equip: '%s' is not owned" % item_id)
		return null
	var slots: Dictionary = equipped.get(princess_id, {})
	var previous := get_item(slots.get(item.slot, ""))
	slots[item.slot] = item_id
	equipped[princess_id] = slots
	changed.emit()
	return previous


func unequip(princess_id: String, slot: int) -> void:
	var slots: Dictionary = equipped.get(princess_id, {})
	slots.erase(slot)
	equipped[princess_id] = slots
	changed.emit()


func equipped_in(princess_id: String, slot: int) -> EquipmentDefinition:
	return get_item(equipped.get(princess_id, {}).get(slot, ""))


func is_equipped(princess_id: String, item_id: String) -> bool:
	return equipped.get(princess_id, {}).values().has(item_id)


## Equipped items in slot order (missing slots skipped).
func equipped_items(princess_id: String) -> Array[EquipmentDefinition]:
	var list: Array[EquipmentDefinition] = []
	for slot in ItemTypes.Slot.values():
		var it := equipped_in(princess_id, slot)
		if it != null:
			list.append(it)
	return list


## Gives and equips the princess's starting gear the first time she is used.
func ensure_starting_gear(princess: PrincessDefinition) -> void:
	if equipped.has(princess.id):
		return
	equipped[princess.id] = {}
	for it in princess.starting_equipment:
		if it != null:
			add(it)
			equip(princess.id, it.id)


# ------------------------------------------------------------ cards (Phase 3)

func register_cards(library: CardLibrary) -> void:
	if library == null:
		return
	deck_size = library.max_deck_size
	for c in library.cards:
		if c != null and c.id != "":
			card_catalog[c.id] = c


func get_card(card_id: String) -> CardDefinition:
	return card_catalog.get(card_id)


func card_count(card_id: String) -> int:
	return cards.get(card_id, 0)


## Adds copies; a brand-new card also joins the deck if there is room.
func add_card(card: CardDefinition, copies := 1) -> void:
	if card == null:
		return
	card_catalog[card.id] = card
	var is_new := card_count(card.id) == 0
	cards[card.id] = card_count(card.id) + copies
	if is_new and deck.size() < deck_size and not deck.has(card.id):
		deck.append(card.id)
	changed.emit()


## Gives the starting cards once per save.
func ensure_starting_cards(library: CardLibrary) -> void:
	if cards_initialized or library == null:
		return
	cards_initialized = true
	for c in library.starting_cards:
		add_card(c)


## "" on success, otherwise why not.
func add_to_deck(card_id: String) -> String:
	if card_count(card_id) <= 0:
		return "ยังไม่มีการ์ดใบนี้"
	if deck.has(card_id):
		return "อยู่ในเด็คแล้ว"
	if deck.size() >= deck_size:
		return "เด็คเต็ม (%d ใบ)" % deck_size
	deck.append(card_id)
	changed.emit()
	return ""


func remove_from_deck(card_id: String) -> void:
	deck.erase(card_id)
	changed.emit()


func deck_cards() -> Array[CardDefinition]:
	var list: Array[CardDefinition] = []
	for card_id in deck:
		var c := get_card(card_id)
		if c != null:
			list.append(c)
	return list


func essence(key: String) -> int:
	return materials.get(key, 0)


func add_essence(key: String, amount: int) -> void:
	if amount <= 0:
		return
	materials[key] = essence(key) + amount
	changed.emit()


func can_craft(recipe: CraftRecipe) -> bool:
	if recipe == null or recipe.result == null:
		return false
	for key in recipe.cost:
		if essence(key) < int(recipe.cost[key]):
			return false
	return true


## Spends essences and adds the card. Returns the card, or null if not affordable.
func craft(recipe: CraftRecipe) -> CardDefinition:
	if not can_craft(recipe):
		return null
	for key in recipe.cost:
		materials[key] = essence(key) - int(recipe.cost[key])
	add_card(recipe.result)
	return recipe.result


func can_fuse(recipe: FusionRecipe) -> bool:
	if recipe == null or recipe.result == null or recipe.inputs.is_empty():
		return false
	var need := recipe.needed()
	for card_id in need:
		if card_count(card_id) < need[card_id]:
			return false
	return true


## Consumes the input cards (removing them from the deck if none are left) and adds the result.
func fuse(recipe: FusionRecipe) -> CardDefinition:
	if not can_fuse(recipe):
		return null
	var need := recipe.needed()
	for card_id in need:
		cards[card_id] = card_count(card_id) - need[card_id]
		if cards[card_id] <= 0:
			cards.erase(card_id)
			deck.erase(card_id)
	add_card(recipe.result)
	return recipe.result


# ------------------------------------------------------------ save format

## Versioned, forward-compatible dictionary (unknown fields are ignored on load).
func to_dict() -> Dictionary:
	var eq := {}
	for pid in equipped:
		var slots := {}
		for slot in equipped[pid]:
			slots[ItemTypes.SLOT_NAMES_EN[slot]] = equipped[pid][slot]
		eq[pid] = slots
	return {"owned": owned.duplicate(), "equipped": eq, "cards": cards.duplicate(),
		"deck": deck.duplicate(), "materials": materials.duplicate(), "cards_initialized": cards_initialized}


func from_dict(data: Dictionary) -> void:
	owned.clear()
	equipped.clear()
	for item_id in data.get("owned", []):
		# Items removed from the game are dropped instead of crashing the load.
		if catalog.has(item_id) and not owned.has(item_id):
			owned.append(item_id)
	var eq: Dictionary = data.get("equipped", {})
	for pid in eq:
		var slots := {}
		for slot_name in eq[pid]:
			var slot := ItemTypes.SLOT_NAMES_EN.find(slot_name)
			var item_id: String = eq[pid][slot_name]
			if slot >= 0 and owned.has(item_id) and catalog[item_id].slot == slot:
				slots[slot] = item_id
		equipped[pid] = slots

	# Phase 3 fields (absent in Phase 2 saves -> defaults).
	cards.clear()
	var saved_cards: Dictionary = data.get("cards", {})
	for card_id in saved_cards:
		if card_catalog.has(card_id) and int(saved_cards[card_id]) > 0:
			cards[card_id] = int(saved_cards[card_id])
	deck.clear()
	for card_id in data.get("deck", []):
		if cards.has(card_id) and not deck.has(card_id) and deck.size() < deck_size:
			deck.append(card_id)
	materials.clear()
	var saved_mats: Dictionary = data.get("materials", {})
	for key in saved_mats:
		if CastleTypes.is_material(key):
			materials[key] = int(saved_mats[key])
	cards_initialized = bool(data.get("cards_initialized", false))
	changed.emit()
