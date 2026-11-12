class_name BattleController
extends Node2D
## Scene entry point for a battle stage. Owns the BattleEngine of the current encounter,
## spawns UnitViews, turns HUD presses into PlayerCommands and replays the resulting events.
##
## Inspector (scenes/battle.tscn > Battle):
##   princess       = res://data/princess_sword.tres
##   stage          = res://data/stage_01.tres
##   balance        = res://data/balance_config.tres
##   unit_view_scene= res://scenes/unit_view.tscn

signal encounter_ended(outcome: int)

const Phase = CombatTypes.Phase
const Outcome = CombatTypes.Outcome
const Team = CombatTypes.Team
const EV = BattleEvent.Type

@export_group("Data")
@export var princess: PrincessDefinition
@export var stage: StageDefinition
@export var balance: BattleConfig
@export var unit_view_scene: PackedScene
## Equipment rewards (Phase 2).
@export var loot: LootTable
## Phase 5: companion princess (back row). Overridden by the castle choice when use_active_princess.
@export var companion: PrincessDefinition

@export_group("Layout (feet positions, 1920x1080 world)")
@export var player_slot := Vector2(430, 730)
@export var player_scale := 1.6
## Companion stands behind the princess and assists every few rounds.
@export var companion_slot := Vector2(215, 640)
@export var companion_scale := 1.15
@export var monster_scale := 1.3
## Enemy positions in spawn order; encounters bigger than this are truncated.
@export var enemy_slots := PackedVector2Array([
	Vector2(1150, 725), Vector2(1350, 575), Vector2(1470, 725),
	Vector2(1660, 575), Vector2(1760, 725), Vector2(1040, 575)])

@export_group("Presentation")
@export var turn_banner_delay := 0.35
@export var before_action_delay := 0.15
@export var after_hit_delay := 0.35
@export var after_status_delay := 0.25
@export var after_death_delay := 0.45
## Monster intents at or above this fraction of the princess max HP are shown as dangerous.
@export_range(0.0, 1.0) var dangerous_intent := 0.25

@export_group("Debug")
## 0 = random every run; any other value makes battles repeatable.
@export var random_seed := 0
@export var auto_start := true
## Use the princess chosen in the castle (GameState) instead of the `princess` field.
@export var use_active_princess := true

@onready var units_root: Node2D = $Units
@onready var popups_root: Node2D = $Popups
@onready var hud: BattleHUD = $HUD

var engine: BattleEngine
var encounter_index := 0
var is_busy := false
var last_outcome: int = Outcome.NONE
var stage_cleared := false
var selected_target_id := -1

var _views := {} # unit id -> UnitView
var _rng: RandomSource
var _next_id := 0
var _carried_hp := -1
var _pending := "" # "next" | "restart"
var _token := 0     # bumps on every new encounter; stale coroutines stop when it changes

var game_state: Node            # the GameState autoload (persistent collection + save)
var collection: Collection
var reward_screen: RewardScreen
var equipment_screen: EquipmentScreen
var cards_screen: CardsScreen
var settings_screen: SettingsScreen
## Essences dropped by the last won encounter (key -> amount).
var last_drops := {}
var roster: PrincessRoster
var castle: CastleProgress
## Last princess line / expression (for tests / autoplay).
var last_speech := ""
var last_expression := 0
var newly_unlocked: Array[String] = []
var _expression_token := 0
var _bubble: SpeechBubble
## Last reward roll (exposed for tests / autoplay).
var reward_options: Array = []
## Phase 5: pair bonus in effect, EXP from the last victory, slot index per enemy unit.
var synergy: Synergy
var last_exp := 0
var last_level_ups := 0
var companion_unit: CombatUnit
var _slot_of := {} # unit id -> enemy_slots index
## Auto battle (the AUTO button): plays cards + actions with the same smart policy the tests use.
## Kept for the whole session so it stays on from battle to battle.
static var auto_session := false
var _policy := AutoBattlePolicy.new()
var _auto_cards := 0


func _ready() -> void:
	_rng = RandomSource.new(random_seed)
	hud.ability_pressed.connect(_on_ability_pressed)
	hud.defend_pressed.connect(_on_defend_pressed)
	hud.continue_pressed.connect(_on_continue_pressed)
	hud.equipment_pressed.connect(open_equipment)
	hud.cards_pressed.connect(open_cards)
	hud.castle_pressed.connect(go_to_castle)
	hud.card_pressed.connect(_on_card_pressed)
	hud.auto_toggled.connect(set_auto)
	hud.set_auto(auto_session)

	game_state = get_node_or_null("/root/GameState")
	if game_state == null:
		# Running without the autoload (e.g. a bare test scene): keep progress in memory only.
		game_state = load("res://scripts/core/game_state.gd").new()
		game_state.persist = false
		add_child(game_state)
	game_state.setup(loot, princess)
	roster = game_state.roster
	castle = game_state.castle if game_state.get("castle") != null else CastleProgress.new()
	var chosen = game_state.active_princess() if game_state.has_method("active_princess") else null
	if chosen != null and use_active_princess:
		princess = chosen
		game_state.setup(loot, princess)
		# Phase 5: stage + companion picked in the castle.
		if game_state.has_method("selected_stage") and game_state.selected_stage() != null:
			stage = game_state.selected_stage()
		companion = game_state.companion_princess() if game_state.has_method("companion_princess") else null
	collection = game_state.collection
	if companion != null and princess != null and companion.id == princess.id:
		companion = null
	if companion != null:
		collection.ensure_starting_gear(companion)
	synergy = roster.synergy_for(princess.id, companion.id) if roster != null and companion != null and princess != null else null

	reward_screen = RewardScreen.new()
	add_child(reward_screen)
	equipment_screen = EquipmentScreen.new()
	add_child(equipment_screen)
	equipment_screen.equipment_changed.connect(_on_equipment_changed)
	cards_screen = CardsScreen.new()
	add_child(cards_screen)
	cards_screen.collection_changed.connect(func(): game_state.save_game())
	settings_screen = SettingsScreen.new()
	add_child(settings_screen)
	settings_screen.new_game_started.connect(go_to_castle)
	for layer in [hud, reward_screen, equipment_screen, cards_screen, settings_screen]:
		SafeArea.apply_to_layer(layer)

	if auto_start:
		start_stage()


func open_cards() -> void:
	cards_screen.open(collection, loot.card_library if loot else null)


func open_equipment() -> void:
	var fb: StatBlock = castle.furniture_bonus(princess.id, roster) if roster != null else null
	equipment_screen.open(princess, collection, roster.dialogue if roster else null, castle.bond_level(princess.id), fb, castle.level(princess.id))


## Equipment changed in the Equipment screen: update the princess on screen and save.
func _on_equipment_changed() -> void:
	game_state.save_game()
	if engine != null:
		var pv := _view(engine.player)
		if pv:
			pv.set_equipment(collection.equipped_items(princess.id), true)


func start_stage() -> void:
	if not _validate_setup():
		return
	_apply_stage_background()
	stage_cleared = false
	_carried_hp = -1
	_begin_encounter(0)


func select_target(unit_id: int) -> void:
	if engine == null:
		return
	var u := engine.find_unit(unit_id)
	if u == null or u.team != Team.ENEMY or not u.is_alive():
		return
	selected_target_id = unit_id
	for id in _views:
		_views[id].set_selected(id == unit_id)


# ------------------------------------------------------------ setup

func _validate_setup() -> bool:
	var problems: Array[String] = []
	if princess == null: problems.append("princess is not assigned")
	if stage == null or stage.encounters.is_empty(): problems.append("stage is missing or has no encounters")
	if unit_view_scene == null: problems.append("unit_view_scene is not assigned")
	if enemy_slots.is_empty(): problems.append("no enemy slots")
	if problems.is_empty():
		return true
	push_error("BattleController setup problems: " + ", ".join(problems))
	hud.set_hint("Setup error: " + ", ".join(problems))
	return false


func _begin_encounter(index: int) -> void:
	_token += 1
	_clear_views()
	hud.hide_result()
	hud.clear_log()
	_pending = ""
	last_outcome = Outcome.NONE

	encounter_index = clampi(index, 0, stage.encounters.size() - 1)
	var encounter := stage.encounters[encounter_index]
	hud.set_stage("%s  •  Battle %d/%d  •  %s" % [stage.display_name, encounter_index + 1,
		stage.encounters.size(), encounter.display_name if encounter else ""])

	var gear := collection.equipped_items(princess.id)
	var player := _create_player(_carried_hp)
	_next_id += 1
	_spawn(player, princess.battle_texture, Color.WHITE, princess.battle_scale * player_scale, player_slot, false, princess.slot_anchors, princess.art_scale)
	_view(player).set_equipment(gear)
	_view(player).doll.setup_face(princess.face_dir, princess.face_anchor)
	_view(player).place_status_beside_hp() # keeps it clear of the battle log (top-left)
	_view(player).hide_name_and_hp() # shown on the HUD plate instead

	# Companion: back row, smaller, never targeted; assists automatically.
	companion_unit = null
	if companion != null and companion.assist != null:
		var c_gear := collection.equipped_items(companion.id)
		companion_unit = UnitFactory.create_companion(companion, _next_id, castle.level(companion.id), c_gear)
		_next_id += 1
		_spawn(companion_unit, companion.battle_texture, Color.WHITE, companion.battle_scale * companion_scale,
			companion_slot, false, companion.slot_anchors, companion.art_scale)
		var cv := _view(companion_unit)
		cv.set_equipment(c_gear)
		cv.doll.setup_face(companion.face_dir, companion.face_anchor)
		cv.z_index -= 5
		cv.set_support_mode()
		cv.overhead.position.y += 70.0 # keep her labels below the battle log box
		cv.set_intent("ASSIST ทุก %d รอบ" % companion.assist_interval, Color(0.6, 0.9, 1))

	var enemies: Array = []
	_slot_of.clear()
	if encounter != null:
		if encounter.monsters.size() > enemy_slots.size():
			push_warning("Encounter '%s' has more monsters than enemy slots; extras skipped" % encounter.display_name)
		for i in mini(encounter.monsters.size(), enemy_slots.size()):
			var def := encounter.monsters[i]
			if def == null:
				continue
			var m := UnitFactory.create_monster(def, _next_id, stage.monster_hp_scale, stage.monster_attack_scale)
			_next_id += 1
			if m == null:
				continue
			enemies.append(m)
			_slot_of[m.id] = i
			# Art faces right; flip so monsters face the princess.
			_spawn(m, def.texture, def.tint, def.visual_scale * monster_scale, enemy_slots[i], not def.faces_left)

	if enemies.is_empty():
		push_error("Encounter %d has no valid monsters" % encounter_index)
		return

	var extra_mana := synergy.start_mana if synergy != null else 0
	var cfg: BattleConfig = (balance if balance != null else BattleConfig.new()).with_mana_bonus(princess.bonus_start_mana + extra_mana, princess.bonus_max_mana)
	var deck := collection.deck_cards().filter(func(c): return c.usable_by(princess.id))
	engine = BattleEngine.new(player, enemies, cfg, _rng, null, deck)
	engine.max_enemies = enemy_slots.size()
	engine.summon_factory = func(def: MonsterDefinition, id: int) -> CombatUnit:
		return UnitFactory.create_monster(def, id, stage.monster_hp_scale, stage.monster_attack_scale)
	if companion_unit != null:
		engine.companion = companion_unit
		engine.companion_assist = companion.assist
		engine.assist_interval = maxi(1, companion.assist_interval)
	selected_target_id = -1
	select_target(engine.first_targetable_enemy().id)

	hud.set_player(_player_label(), player.current_hp, player.stats.max_hp, true)
	_refresh_action_icons()
	_refresh_materials()
	hud.set_hint("แตะมอนสเตอร์เพื่อเลือกเป้าหมาย • ใช้การ์ดได้หลายใบก่อนโจมตี (ใช้มานา) • ESC / ปุ่มย้อนกลับ = ตั้งค่า")
	hud.log_line("มอนสเตอร์ %d ตัวปรากฏตัว!" % enemies.size())
	if companion_unit != null:
		hud.log_line("ผู้ช่วย: %s (%s ทุก %d รอบ)" % [companion.display_name, companion.assist.display_name, companion.assist_interval])
	if synergy != null:
		hud.log_line("★ Synergy %s — %s" % [synergy.display_name, synergy.description])
	var has_boss := false
	for m in enemies:
		has_boss = has_boss or m.is_boss
	_music("boss" if has_boss and encounter.reward_tier == ItemTypes.Tier.BOSS else "battle")
	react("BOSS_APPEAR" if has_boss else "BATTLE_START")
	if has_boss:
		for m in enemies:
			if m.is_boss:
				_boss_banner(m.unit_name, encounter.reward_tier != ItemTypes.Tier.BOSS)
				break
	_run_turn_loop(engine.start())


func _spawn(unit: CombatUnit, texture: Texture2D, tint: Color, s: float, slot: Vector2, flip: bool, anchors := {}, art_scale := 1.0) -> void:
	var view: UnitView = unit_view_scene.instantiate()
	units_root.add_child(view)
	view.position = slot
	view.z_index = int(slot.y / 10.0) # lower on screen = in front
	view.bind(unit, texture, tint, s, flip, anchors, art_scale)
	view.clicked.connect(func(v: UnitView): select_target(v.unit.id))
	_views[unit.id] = view


func _clear_views() -> void:
	for v in _views.values():
		v.queue_free()
	_views.clear()


func _view(unit: CombatUnit) -> UnitView:
	return _views.get(unit.id) if unit != null else null


# ------------------------------------------------------------ turn flow

## Plays events, runs enemy turns while needed (e.g. player stunned), then hands control back.
func _run_turn_loop(first_events: Array[BattleEvent]) -> void:
	var token := _token
	is_busy = true
	_refresh_buttons()
	await _play(first_events)
	while token == _token and engine.phase == Phase.ENEMY_TURN:
		await _play(engine.run_enemy_turn())
	if token != _token:
		return
	if engine.phase == Phase.ENDED:
		await _handle_end()
		return
	var sel := engine.find_unit(selected_target_id)
	if sel == null or not sel.is_targetable():
		var first := engine.first_targetable_enemy()
		if first:
			select_target(first.id)
	is_busy = false
	_auto_cards = 0
	_refresh_buttons()
	_maybe_auto()


func _on_ability_pressed(index: int) -> void:
	if is_busy or engine == null or engine.phase != Phase.PLAYER_TURN:
		return
	if index < 0 or index >= engine.player.abilities.size():
		return
	_execute(PlayerCommand.use_ability(engine.player.abilities[index].spec.id, selected_target_id))


func _on_defend_pressed() -> void:
	if is_busy or engine == null or engine.phase != Phase.PLAYER_TURN:
		return
	_execute(PlayerCommand.defend())


## Cards are free actions: play any number (mana permitting), the turn continues.
func _on_card_pressed(index: int) -> void:
	if is_busy or engine == null or engine.phase != Phase.PLAYER_TURN:
		return
	var error := engine.validate_card(index, selected_target_id)
	if error != "":
		hud.log_line(error)
		return
	_run_card(engine.play_card(index, selected_target_id))


func _run_card(events: Array[BattleEvent]) -> void:
	var token := _token
	is_busy = true
	_refresh_buttons()
	await _play(events)
	if token != _token:
		return
	if engine.phase == Phase.ENDED:
		await _handle_end()
		return
	var sel := engine.find_unit(selected_target_id)
	if sel == null or not sel.is_targetable():
		var first := engine.first_targetable_enemy()
		if first:
			select_target(first.id)
	is_busy = false
	_refresh_buttons()
	_maybe_auto()


func _execute(cmd: PlayerCommand) -> void:
	var error := engine.validate_command(cmd)
	if error != "":
		hud.log_line(error)
		return
	_run_turn_loop(engine.execute_player_command(cmd))


func _handle_end() -> void:
	last_outcome = engine.outcome
	for v in _views.values():
		v.set_selected(false)
	hud.set_hint("")
	hud.set_turn("Round %d  •  จบการต่อสู้" % engine.round_number)
	_refresh_intents() # engine cleared intents; hide stale "HEAVY 27" labels
	var player := engine.player
	if last_outcome == Outcome.VICTORY:
		var pv := _view(player)
		_sfx("victory")
		react("VICTORY")
		if roster != null:
			var lvl := castle.add_bond(princess.id, CastleProgress.VICTORY_BOND)
			if lvl > 0:
				hud.log_line("Bond กับ %s เพิ่มเป็น Lv%d!" % [princess.display_name, lvl])
		if pv:
			await pv.visual.victory()
		var token := _token
		var exp_text := _award_exp()
		var drop_text := _collect_essences()
		_refresh_materials()
		var reward_text := await _offer_reward()
		if token != _token:
			return
		if drop_text != "":
			reward_text += "\n" + drop_text
		if exp_text != "":
			reward_text += "\n" + exp_text
		if encounter_index >= stage.encounters.size() - 1:
			stage_cleared = true
			_pending = "restart"
			if roster != null:
				var first_clear := not castle.is_stage_cleared(stage.id)
				for p in castle.mark_stage_cleared(stage.id, roster):
					reward_text += "\n★ ปลดล็อก %s! ห้อง %s เปิดแล้ว" % [p.display_name, CastleTypes.WING_NAMES[p.wing]]
					newly_unlocked.append(p.id)
					_sfx("unlock")
				if first_clear:
					for s in roster.stages:
						if s.unlock_after == stage.id:
							reward_text += "\n★ ด่านใหม่: %s (แนะนำ Lv%d)" % [s.display_name, s.recommended_level]
			game_state.save_game()
			hud.show_result("STAGE CLEAR!", "%s\n%s ปราบมอนสเตอร์ทั้งหมดแล้ว! (%d รอบ)" % [reward_text, princess.display_name, engine.round_number],
				"เล่นอีกครั้ง", Color(1, 0.85, 0.4))
		else:
			# Max HP may have changed with new gear or a level up.
			var max_hp := _create_player(-1).stats.max_hp
			var heal := roundi(max_hp * stage.heal_between_battles)
			var next_hp := mini(max_hp, player.current_hp + heal)
			_carried_hp = next_hp
			_pending = "next"
			hud.show_result("VICTORY!", "%s\nพักฟื้น → HP ในการต่อสู้ถัดไป %d/%d" % [reward_text, next_hp, max_hp],
				"ต่อสู้ต่อ", Color(0.55, 1, 0.7))
	else:
		_pending = "restart"
		_sfx("defeat")
		react("DEFEAT")
		game_state.save_game()
		hud.show_result("DEFEAT", "%s ถอยกลับปราสาท...\nไปถึง Battle %d/%d" % [princess.display_name, encounter_index + 1, stage.encounters.size()],
			"ลองใหม่", Color(1, 0.45, 0.5))
	is_busy = false
	_refresh_buttons()
	encounter_ended.emit(last_outcome)


## Builds the princess unit: level stats + gear + room furniture + synergy pair bonus.
func _create_player(current_hp: int) -> CombatUnit:
	var gear := collection.equipped_items(princess.id)
	var extra: StatBlock = castle.furniture_bonus(princess.id, roster) if roster != null else null
	if synergy != null and synergy.stats != null:
		extra = synergy.stats if extra == null else extra.plus(synergy.stats)
	var unit := UnitFactory.create_princess(princess, _next_id, current_hp, gear, extra, castle.level(princess.id))
	UnitFactory.apply_synergy(unit, synergy)
	return unit


func _player_label() -> String:
	return "%s Lv%d" % [princess.display_name, castle.level(princess.id)]


## EXP for every monster defeated in this battle (summons included). The companion gets half.
func _award_exp() -> String:
	last_exp = 0
	last_level_ups = 0
	for e in engine.enemies:
		if not e.is_alive():
			last_exp += e.exp_reward
	if last_exp <= 0:
		return ""
	last_level_ups = castle.add_exp(princess.id, last_exp)
	var text := "EXP +%d" % last_exp
	if last_level_ups > 0:
		text += "  ★ LEVEL UP! %s Lv%d" % [princess.display_name, castle.level(princess.id)]
		var pv := _view(engine.player)
		if pv:
			FloatingText.spawn(popups_root, pv.popup_position() + Vector2(0, -60), "LEVEL UP!", Color(1, 0.9, 0.3), 60)
		_sfx("level_up")
		react("LEVEL_UP")
	hud.log_line(text)
	if companion != null:
		var share := roundi(last_exp * 0.5)
		var c_up := castle.add_exp(companion.id, share)
		castle.add_bond(companion.id, 1)
		text += "\nผู้ช่วย %s EXP +%d%s" % [companion.display_name, share,
			"  ★ Lv%d!" % castle.level(companion.id) if c_up > 0 else ""]
	game_state.save_game()
	return text


## Picks a free enemy slot for a summoned monster (reuses slots of defeated monsters).
func _free_slot() -> int:
	var used := {}
	for id in _slot_of:
		var u := engine.find_unit(id)
		if u != null and u.is_alive():
			used[_slot_of[id]] = id
	for i in enemy_slots.size():
		if not used.has(i):
			return i
	return -1


func _spawn_summon(unit: CombatUnit) -> void:
	var slot := _free_slot()
	if slot < 0:
		return
	# A defeated monster's body leaves the slot to make room.
	for id in _slot_of.keys():
		if _slot_of[id] == slot and _views.has(id):
			_views[id].queue_free()
			_views.erase(id)
	_slot_of[unit.id] = slot
	var def := _find_monster_def(unit.definition_id)
	var tex: Texture2D = def.texture if def else null
	_spawn(unit, tex, def.tint if def else Color.WHITE, (def.visual_scale if def else 1.0) * monster_scale, enemy_slots[slot], not (def != null and def.faces_left))
	var v := _view(unit)
	if v:
		v.set_hp(unit.current_hp, unit.stats.max_hp, true)
		FloatingText.spawn(popups_root, v.popup_position(), "SUMMONED!", Color(1, 0.5, 0.8), 44)


## Looks up a monster definition among this stage's monsters and boss summons.
func _find_monster_def(def_id: String) -> MonsterDefinition:
	for enc in stage.encounters:
		for m in enc.monsters:
			if m == null:
				continue
			if m.id == def_id:
				return m
			for ph in m.phases:
				for s in ph.summons:
					if s != null and s.id == def_id:
						return s
	return null


## Shows "Choose a Reward", waits for the pick, applies it. Returns a summary line.
func _offer_reward() -> String:
	if loot == null:
		return ""
	var encounter := stage.encounters[encounter_index]
	var last := encounter_index >= stage.encounters.size() - 1
	reward_options = loot.roll_options(encounter.reward_tier, _rng, collection.owned, not last)
	var title := "CHOOSE A REWARD"
	if encounter.reward_tier == ItemTypes.Tier.MINI_BOSS:
		title += "  ★ MINI BOSS"
	elif encounter.reward_tier == ItemTypes.Tier.BOSS:
		title += "  ★★ BOSS"
	reward_screen.show_options(reward_options, collection, princess.id, title)
	var index: int = await reward_screen.chosen
	_sfx("reward")
	var option = reward_options[index]
	var player := engine.player
	var pv := _view(player)

	if option.kind == LootTable.RewardOption.Kind.EQUIPMENT:
		var item: EquipmentDefinition = option.item
		collection.add(item)
		collection.equip(princess.id, item.id)
		game_state.save_game()
		if pv:
			pv.set_equipment(collection.equipped_items(princess.id), true)
			FloatingText.spawn(popups_root, pv.popup_position(), "NEW! " + item.display_name, ItemTypes.rarity_color(item.rarity), 40)
		hud.log_line("ได้รับ %s และสวมใส่ทันที" % item.display_name)
		react("ITEM_RECEIVED", item)
		return "ได้รับ [%s] %s — สวมใส่แล้ว" % [ItemTypes.rarity_name(item.rarity), item.display_name]

	if option.kind == LootTable.RewardOption.Kind.CARD:
		var card: CardDefinition = option.card
		var was_new := collection.card_count(card.id) == 0
		collection.add_card(card)
		game_state.save_game()
		if pv:
			FloatingText.spawn(popups_root, pv.popup_position(), "NEW CARD! " + card.display_name, ItemTypes.rarity_color(card.rarity), 40)
		hud.log_line("ได้รับการ์ด %s" % card.display_name)
		var where := "เข้าเด็คแล้ว" if collection.deck.has(card.id) and was_new else "เก็บในคอลเลกชัน"
		return "ได้รับการ์ด [%s] %s — %s" % [ItemTypes.rarity_name(card.rarity), card.display_name, where]

	var healed := player.apply_heal(roundi(player.stats.max_hp * option.heal_fraction))
	if pv:
		pv.set_hp(player.current_hp, player.stats.max_hp)
		FloatingText.spawn(popups_root, pv.popup_position(), "+%d" % healed, Color(0.45, 1, 0.6), 48)
	hud.set_player(_player_label(), player.current_hp, player.stats.max_hp)
	return "พักฟื้น +%d HP" % healed


## Princess reaction: picks a line from the dialogue DB (by trigger, personality, item...),
## shows it in a speech bubble and changes her facial expression for a moment.
func react(trigger: String, item: EquipmentDefinition = null) -> void:
	if roster == null or roster.dialogue == null or engine == null:
		return
	var ctx := DialogueDB.context(princess, castle.bond_level(princess.id), item)
	var line := roster.dialogue.pick(trigger, ctx, _rng)
	if line == null:
		return
	last_speech = line.text
	last_expression = line.expression
	var pv := _view(engine.player)
	if pv == null:
		return
	pv.doll.set_expression(line.expression)
	if _bubble != null and is_instance_valid(_bubble):
		_bubble.queue_free()
	# just above her head (her name / HP bar are on the HUD plate, not over her)
	_bubble = SpeechBubble.say(popups_root, pv.overhead.global_position + Vector2(0, 10), line.text, 2.8)
	_expression_token += 1
	var token := _expression_token
	await get_tree().create_timer(2.8).timeout
	# Back to normal unless something newer changed it (crying stays after defeat).
	if token == _expression_token and is_instance_valid(pv) and trigger != "DEFEAT":
		pv.doll.set_expression(CastleTypes.Expr.NORMAL)


## Android Back (Esc on desktop): close overlays; leave to the castle only from a result screen.
## Mid-fight it opens Settings (there is no settings button on the battle screen).
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		on_back()


# _input (not _unhandled): a focused button / slider in Settings must not swallow Esc.
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		on_back()
		get_viewport().set_input_as_handled()


func on_back() -> void:
	if settings_screen != null and settings_screen.back():
		return
	if equipment_screen != null and equipment_screen.visible:
		equipment_screen.close()
	elif cards_screen != null and cards_screen.visible:
		cards_screen.close()
	elif reward_screen != null and reward_screen.visible:
		return # a reward must be chosen
	elif hud.is_result_visible():
		go_to_castle()
	else:
		settings_screen.open()


func go_to_castle() -> void:
	game_state.save_game()
	get_tree().change_scene_to_file("res://scenes/castle.tscn")


## Rolls every defeated monster's essence drops into the collection. Returns a summary.
func _collect_essences() -> String:
	last_drops = {}
	for m in stage.encounters[encounter_index].monsters:
		if m == null:
			continue
		for d in m.drops:
			var n := d.roll(_rng)
			if n > 0:
				var key := d.key()
				last_drops[key] = last_drops.get(key, 0) + n
	if last_drops.is_empty():
		return ""
	var parts: Array[String] = []
	for key in last_drops:
		collection.add_essence(key, last_drops[key])
		parts.append("%s x%d" % [CastleTypes.material_name(key), last_drops[key]])
	game_state.save_game()
	hud.log_line("ได้ Essence: " + ", ".join(parts))
	return "Essence: " + ", ".join(parts)


func _on_continue_pressed() -> void:
	match _pending:
		"next": _begin_encounter(encounter_index + 1)
		"restart": start_stage()


# ------------------------------------------------------------ event playback

func _play(events: Array[BattleEvent]) -> void:
	var token := _token
	for e in events:
		if token != _token:
			return
		await _play_one(e)


func _play_one(e: BattleEvent) -> void:
	match e.type:
		EV.TURN_STARTED:
			hud.set_turn("Round %d  •  เทิร์นของคุณ" % e.round_number if e.side == Team.PLAYER else "เทิร์นมอนสเตอร์")
			_refresh_buttons() # mana refill
			await _wait(turn_banner_delay)

		EV.ACTION_STARTED:
			var v := _view(e.source)
			if e.card != null:
				hud.log_line("ใช้การ์ด %s" % e.card.display_name)
				_sfx("card")
				if e.card.category == CardTypes.Category.SPECIAL or e.card.rarity >= ItemTypes.Rarity.EPIC:
					react("CARD_SPECIAL")
				if v:
					FloatingText.spawn(popups_root, v.popup_position() + Vector2(0, -40), e.card.display_name,
						CardTypes.category_color(e.card.category).lightened(0.35), 46)
				_refresh_buttons()
			else:
				hud.log_line("%s: %s" % [e.source.unit_name, e.ability.display_name])
			await _wait(before_action_delay)
			if v:
				if e.ability.deals_damage():
					await v.visual.lunge(Vector2.RIGHT if e.source.team == Team.PLAYER else Vector2.LEFT)
				else:
					await v.visual.brace()

		EV.DAMAGE:
			if e.amount > 0 or e.absorbed > 0:
				_sfx("crit" if e.crit or e.executed else ("status" if e.from_status else "hit"), 40 if e.crit else 0)
			var v := _view(e.target)
			if v:
				var color := Color(0.75, 0.5, 1) if e.from_status else (Color(1, 0.8, 0.25) if e.crit else Color(1, 0.95, 0.95))
				if e.from_status and e.status == CombatTypes.Status.BURN:
					color = Color(1, 0.55, 0.2)
				var text := ("CRIT %d!" if e.crit else "%d") % e.amount
				if e.executed:
					text = "EXECUTE!"
					color = Color(1, 0.3, 0.4)
				elif e.absorbed > 0:
					text = "%d  (SHIELD -%d)" % [e.amount, e.absorbed]
				FloatingText.spawn(popups_root, v.popup_position(), text, color, 64 if (e.crit or e.executed) else 52)
				v.set_hp(e.hp_after, e.target.stats.max_hp)
				if e.target.is_alive():
					v.visual.hit()
				# Effects: sword arc + sparks on hits, element burst on burn / poison ticks.
				var at := _body_center(v)
				if e.from_status:
					BattleFx.burst(popups_root, at, BattleFx.status_color(e.status), 12, 160.0, -120.0)
				elif e.amount > 0 or e.absorbed > 0:
					var big := e.crit or e.executed
					BattleFx.slash(popups_root, at, BattleFx.CRIT if big else BattleFx.HIT, 1.5 if big else 1.0)
					BattleFx.burst(popups_root, at, BattleFx.CRIT if big else BattleFx.HIT, 22 if big else 10)
					if e.absorbed > 0:
						BattleFx.ring(popups_root, v.position, BattleFx.SHIELD, 110.0)
					if big:
						_shake(12.0, 0.25)
			if e.from_status:
				hud.log_line("%s โดน%s %d" % [e.target.unit_name, "ไฟเผา" if e.status == CombatTypes.Status.BURN else "พิษ", e.amount])
			_on_unit_changed(e.target)
			await _wait(after_hit_delay)

		EV.DODGE:
			_sfx("miss")
			var v := _view(e.target)
			if v:
				FloatingText.spawn(popups_root, v.popup_position(), "MISS", Color(0.7, 0.85, 1), 44)
				v.visual.dodge(Vector2.LEFT if e.target.team == Team.PLAYER else Vector2.RIGHT)
			hud.log_line("%s หลบได้!" % e.target.unit_name)
			await _wait(after_hit_delay)

		EV.HEAL:
			if e.amount > 0:
				_sfx("heal")
			var v := _view(e.target)
			if v:
				FloatingText.spawn(popups_root, v.popup_position(), "+%d" % e.amount, Color(0.45, 1, 0.6), 48)
				if e.amount > 0:
					BattleFx.rise(popups_root, _body_center(v), BattleFx.HEAL)
				v.set_hp(e.hp_after, e.target.stats.max_hp)
			_on_unit_changed(e.target)
			await _wait(after_status_delay)

		EV.DEFEND:
			var v := _view(e.source)
			if v:
				FloatingText.spawn(popups_root, v.popup_position(), "GUARD", Color(0.7, 0.85, 1), 44)
				await v.visual.brace()
			hud.log_line("%s ตั้งท่าป้องกัน" % e.source.unit_name)
			_on_unit_changed(e.source)

		EV.STATUS_APPLIED:
			_sfx("shield" if e.status == CombatTypes.Status.SHIELD else "status")
			var v := _view(e.target)
			if v:
				var label := CombatTypes.status_name(e.status)
				if e.status == CombatTypes.Status.SHIELD:
					label = "SHIELD %d" % e.amount
				elif e.status == CombatTypes.Status.SLEEP:
					label = "Zzz..."
				FloatingText.spawn(popups_root, v.popup_position(), label, Color(0.8, 0.6, 1), 40)
				if e.status == CombatTypes.Status.SHIELD:
					BattleFx.ring(popups_root, v.position, BattleFx.SHIELD, 140.0)
				else:
					BattleFx.burst(popups_root, _body_center(v), BattleFx.status_color(e.status), 14, 200.0, 60.0)
				_apply_status_visual(v, e.target)
			hud.log_line("%s ติด %s (%d เทิร์น)" % [e.target.unit_name, CombatTypes.status_name(e.status), e.turns])
			_on_unit_changed(e.target)
			await _wait(after_status_delay)

		EV.STATUS_RESISTED:
			var v := _view(e.target)
			if v:
				FloatingText.spawn(popups_root, v.popup_position(), "RESIST", Color(0.7, 0.85, 1), 40)
			hud.log_line("%s ต้านทาน %s ได้" % [e.target.unit_name, CombatTypes.status_name(e.status)])
			await _wait(after_status_delay)

		EV.STATUS_EXPIRED:
			var v := _view(e.target)
			if v:
				_apply_status_visual(v, e.target)
				if e.status == CombatTypes.Status.BANISH:
					hud.log_line("%s กลับเข้าสนาม!" % e.target.unit_name)
			_on_unit_changed(e.target)

		EV.TURN_SKIPPED:
			var v := _view(e.source)
			if v and e.reason != "BANISH":
				FloatingText.spawn(popups_root, v.popup_position(), e.reason, Color(0.7, 0.85, 1), 40)
			hud.log_line("%s ขยับไม่ได้ (%s)" % [e.source.unit_name, e.reason])
			await _wait(after_status_delay)

		EV.UNIT_DIED:
			_sfx("death")
			hud.log_line("%s ถูกปราบ!" % e.target.unit_name)
			var v := _view(e.target)
			if v:
				BattleFx.burst(popups_root, _body_center(v), BattleFx.SMOKE, 20, 140.0, -60.0)
				v.set_dead_visuals()
				await v.visual.die()
			await _wait(after_death_delay)

		EV.INTENTS_CHANGED:
			_refresh_intents()

		EV.BOSS_PHASE:
			_sfx("boss_phase", 150)
			var v := _view(e.source)
			hud.log_line("⚠ " + e.reason)
			if v:
				FloatingText.spawn(popups_root, v.popup_position() + Vector2(0, -50), "PHASE!", Color(1, 0.3, 0.45), 64)
				BattleFx.ring(popups_root, v.position, Color(1, 0.3, 0.45), 220.0)
				BattleFx.burst(popups_root, _body_center(v), Color(1, 0.35, 0.4), 30, 380.0, 200.0)
				_shake(16.0, 0.4)
				await v.visual.brace()
			hud.set_hint(e.reason)
			react("BOSS_PHASE")
			await _wait(after_death_delay)

		EV.UNIT_SUMMONED:
			_sfx("summon")
			_spawn_summon(e.target)
			var sv := _view(e.target)
			if sv:
				BattleFx.ring(popups_root, sv.position, BattleFx.SHADOW, 130.0)
				BattleFx.burst(popups_root, _body_center(sv), BattleFx.SHADOW, 16, 220.0, -80.0)
			hud.log_line("%s ปรากฏตัว!" % e.target.unit_name)
			_refresh_intents()
			await _wait(after_status_delay)

		EV.BATTLE_ENDED:
			pass


## Banish / Freeze appearance follows the unit's current statuses.
func _apply_status_visual(v: UnitView, unit: CombatUnit) -> void:
	if not unit.is_alive():
		return
	v.set_banished(unit.has_status(CombatTypes.Status.BANISH))
	v.set_frozen(unit.has_status(CombatTypes.Status.FREEZE) or unit.has_status(CombatTypes.Status.STUN))
	if unit.has_status(CombatTypes.Status.BANISH) and unit.id == selected_target_id:
		var first := engine.first_targetable_enemy()
		if first:
			select_target(first.id)


func _wait(seconds: float) -> void:
	if seconds > 0.0:
		await get_tree().create_timer(seconds / _speed()).timeout


## Battle speed from Settings (1x / 1.5x / 2x).
func _speed() -> float:
	var s := get_node_or_null("/root/Settings")
	return maxf(0.25, s.battle_speed) if s != null else 1.0


## Sound by id (no-op without the Audio autoload, e.g. bare test scenes).
func _sfx(id: String, vibrate_ms := 0) -> void:
	var a := get_node_or_null("/root/Audio")
	if a != null:
		a.sfx(id, 0.06)
	if vibrate_ms > 0:
		var s := get_node_or_null("/root/Settings")
		if s != null:
			s.vibrate(vibrate_ms)


func _music(id: String) -> void:
	var a := get_node_or_null("/root/Audio")
	if a != null:
		a.music(id)


# ------------------------------------------------------------ effects (Phase 6+)

## Camera shake (crits, boss phases). Off when Settings > screen shake is off.
func _shake(strength := 10.0, duration := 0.25) -> void:
	var s := get_node_or_null("/root/Settings")
	var cam := get_node_or_null("Camera2D") as Camera2D
	if cam == null or (s != null and not s.screen_shake):
		return
	var tw := cam.create_tween()
	tw.tween_method(func(t: float):
		var k := strength * (1.0 - t)
		cam.offset = Vector2(randf_range(-k, k), randf_range(-k, k)), 0.0, 1.0, duration)
	tw.tween_callback(func(): cam.offset = Vector2.ZERO)


## Middle of a character's body (between feet and the HP bar), for effects.
func _body_center(v: UnitView) -> Vector2:
	return (v.position + v.popup_position()) * 0.5 + Vector2(0, 40)


## Big "BOSS" banner when a boss / mini boss fight starts.
func _boss_banner(boss_name: String, mini: bool) -> void:
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.offset_left = -700
	box.offset_right = 700
	box.offset_top = -170
	box.offset_bottom = 30
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tag := UIKit.label("MINI BOSS" if mini else "BOSS", 48, Color(1, 0.4, 0.45), HORIZONTAL_ALIGNMENT_CENTER)
	var title := UIKit.label(boss_name, 96, UIKit.GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	title.add_theme_constant_override("outline_size", 18)
	title.add_theme_color_override("font_outline_color", Color(0.15, 0.03, 0.08))
	tag.add_theme_constant_override("outline_size", 12)
	tag.add_theme_color_override("font_outline_color", Color(0.15, 0.03, 0.08))
	box.add_child(tag)
	box.add_child(title)
	var layer := CanvasLayer.new() # above the HUD and every unit label
	layer.layer = 30
	add_child(layer)
	layer.add_child(box)
	box.modulate.a = 0.0
	box.scale = Vector2(1.4, 1.4)
	box.pivot_offset = Vector2(700, 100)
	var tw := box.create_tween()
	tw.tween_property(box, "modulate:a", 1.0, 0.25)
	tw.parallel().tween_property(box, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(1.1)
	tw.tween_property(box, "modulate:a", 0.0, 0.4)
	tw.tween_callback(layer.queue_free)
	_shake(8.0, 0.3)


## Stage background (StageDefinition.background), drawn to cover the screen.
func _apply_stage_background() -> void:
	var bg := get_node_or_null("Background") as Sprite2D
	if bg == null or stage == null or stage.background == null:
		return
	bg.texture = stage.background
	bg.position = Vector2(960, 540) + stage.background_offset
	var size := stage.background.get_size()
	var cover := maxf(1920.0 / size.x, 1080.0 / size.y)
	bg.scale = Vector2(cover, cover)


# ------------------------------------------------------------ UI refresh

func _on_unit_changed(unit: CombatUnit) -> void:
	var v := _view(unit)
	if v and unit.is_alive():
		v.set_status_text(_format_statuses(unit))
	if unit.team == Team.PLAYER:
		hud.set_player(_player_label(), unit.current_hp, unit.stats.max_hp)
	else:
		_refresh_intents() # e.g. a frozen monster shows "FROZEN" right away


const BLOCKER_TEXT := {
	CombatTypes.Status.STUN: "STUNNED", CombatTypes.Status.FREEZE: "FROZEN",
	CombatTypes.Status.SLEEP: "ASLEEP", CombatTypes.Status.BANISH: "BANISHED",
}

func _refresh_intents() -> void:
	if engine == null:
		return
	for enemy in engine.enemies:
		var v := _view(enemy)
		if v == null or not enemy.is_alive():
			continue
		v.set_status_text(_format_statuses(enemy))
		var blocker := enemy.action_blocker()
		if blocker != CombatTypes.Status.NONE:
			v.set_intent(BLOCKER_TEXT.get(blocker, "-"), Color(0.7, 0.85, 1))
			continue
		var plan := engine.get_intent(enemy)
		if plan == null:
			v.set_intent("", Color.WHITE)
			continue
		var spec := plan.spec
		var tag := spec.intent_tag if spec.intent_tag != "" else spec.display_name
		if enemy.has_status(CombatTypes.Status.SILENCE):
			tag = "(SILENCED) " + tag
		if spec.deals_damage():
			var est := engine.estimate_intent_damage(enemy)
			var danger := est >= engine.player.stats.max_hp * dangerous_intent
			var hits := " x%d" % spec.hit_count if spec.hit_count > 1 else ""
			v.set_intent("%s %d%s%s" % [tag, est, hits, "!" if danger else ""],
				Color(1, 0.35, 0.35) if danger else Color(1, 0.75, 0.45))
		elif spec.heals():
			v.set_intent(tag, Color(0.5, 1, 0.6))
		else:
			v.set_intent(tag, Color(0.8, 0.6, 1))


func _refresh_buttons() -> void:
	var can_act := not is_busy and engine != null and engine.phase == Phase.PLAYER_TURN
	var states: Array = []
	var card_states: Array = []
	if engine != null:
		for i in hud.ability_buttons.size():
			if i >= engine.player.abilities.size():
				states.append({"visible": false})
				continue
			var a := engine.player.abilities[i]
			var sub := ""
			if not a.is_ready():
				sub = "พร้อมใน %d" % a.cooldown_remaining
			elif a.spec.cooldown > 0:
				sub = "CD %d" % a.spec.cooldown
			states.append({"visible": true, "enabled": can_act and a.is_ready(), "title": a.spec.display_name, "subtitle": sub})
		for i in engine.cards.size():
			var cs: BattleEngine.CardState = engine.cards[i]
			card_states.append({"card": cs.card, "used": cs.uses_left <= 0,
				"enabled": can_act and cs.uses_left > 0 and engine.mana >= cs.card.mana_cost})
		hud.set_player(_player_label(), engine.player.current_hp, engine.player.stats.max_hp)
		hud.set_mana(engine.mana, engine.config.max_mana)
	hud.set_actions(states, can_act)
	hud.set_cards(card_states)


func _format_statuses(unit: CombatUnit) -> String:
	var parts: Array[String] = []
	for s in unit.statuses:
		if s.type == CombatTypes.Status.SHIELD:
			parts.append("SHIELD %d" % int(s.potency))
		else:
			parts.append("%s %d" % [CombatTypes.status_name(s.type), s.remaining_turns])
	if unit.is_defending:
		parts.append("GUARD")
	return "  ".join(parts)


# ------------------------------------------------------------ auto battle + HUD art

func set_auto(on: bool) -> void:
	auto_session = on
	hud.set_auto(on)
	if on:
		_maybe_auto()


## On the player's turn with AUTO on: play the best card (a few per turn), else act.
func _maybe_auto() -> void:
	if not auto_session or is_busy or engine == null or engine.phase != Phase.PLAYER_TURN:
		return
	var token := _token
	await get_tree().create_timer(0.35 / _speed()).timeout
	if token != _token or not auto_session or is_busy or engine == null or engine.phase != Phase.PLAYER_TURN:
		return
	if _auto_cards < 6:
		var play := _policy.choose_card(engine)
		if not play.is_empty():
			_auto_cards += 1
			if int(play.target) >= 0:
				select_target(play.target)
			_on_card_pressed(play.index)
			return
	var cmd := _policy.decide(engine)
	if cmd.target_id >= 0:
		select_target(cmd.target_id)
	_execute(cmd)


## Action card art: her weapon on Attack, a matching card icon on each skill, a shield on Defend.
func _refresh_action_icons() -> void:
	var weapon_icon: Texture2D = null
	for item in collection.equipped_items(princess.id):
		if item != null and item.slot == ItemTypes.Slot.WEAPON:
			weapon_icon = UIKit.icon_texture(item)
	var icons: Array = []
	for i in hud.ability_buttons.size():
		if engine == null or i >= engine.player.abilities.size():
			icons.append(null)
			continue
		var spec := engine.player.abilities[i].spec
		var card := "shadow_execution"
		if i == 0 and weapon_icon != null:
			icons.append(weapon_icon)
			continue
		var own := _card_icon("skill_" + spec.id) # her own skill art (tools/build_card_art.gd)
		if own != null:
			icons.append(own)
			continue
		if spec.target == CombatTypes.Target.ALL_OPPONENTS:
			card = "meteor"
		elif spec.heals():
			card = "heal"
		elif spec.status == CombatTypes.Status.STUN:
			card = "fire_blast"
		elif spec.status == CombatTypes.Status.SHIELD:
			card = "holy_shield"
		icons.append(_card_icon(card))
	var defend := _card_icon("skill_defend")
	hud.set_action_icons(icons, defend if defend != null else _card_icon("holy_shield"))


func _card_icon(id: String) -> Texture2D:
	var path := "res://assets/art/cards/%s.png" % id
	return load(path) if ResourceLoader.exists(path) else null


func _refresh_materials() -> void:
	var counts: Array = []
	for key in CastleTypes.MATERIALS:
		var n := collection.essence(key)
		var icon := CastleTypes.material_icon(key)
		if n > 0 and icon != null:
			counts.append({"icon": icon, "count": n})
	hud.set_materials(counts)
