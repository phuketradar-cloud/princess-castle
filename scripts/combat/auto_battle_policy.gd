class_name AutoBattlePolicy
extends RefCounted
## A sensible "smart player" used by tests and balance simulation (later: an Auto-Battle button).
## Works from ability/card data only (no hard-coded ids).
##
## Action each turn:
##   1. Stun the monster about to hit hardest (if a stun is ready and it isn't a boss)
##   2. Defend when incoming damage is dangerous
##   3. Area attack when 2+ monsters are alive
##   4. Otherwise attack: healers first, then the lowest-HP monster
## Cards (before the action): choose_card() is called repeatedly while it returns a play.

## Defend if total expected incoming damage >= this fraction of current HP.
var defend_threshold := 0.45


func decide(engine: BattleEngine) -> PlayerCommand:
	var player := engine.player
	var info := _threats(engine)
	var incoming: int = info.incoming
	var most_dangerous: CombatUnit = info.most
	var most_damage: int = info.most_damage
	var targets := engine.targetable_enemies()

	var stun: CombatUnit.AbilityState = null
	var aoe: CombatUnit.AbilityState = null
	var basic: CombatUnit.AbilityState = null
	for a in player.abilities:
		if not a.is_ready():
			continue
		if a.spec.status == CombatTypes.Status.STUN and a.spec.target == CombatTypes.Target.SINGLE_OPPONENT:
			if stun == null: stun = a
		elif a.spec.target == CombatTypes.Target.ALL_OPPONENTS and a.spec.deals_damage():
			if aoe == null: aoe = a
		elif a.spec.target == CombatTypes.Target.SINGLE_OPPONENT and a.spec.deals_damage():
			if basic == null: basic = a

	if stun != null and most_dangerous != null and most_dangerous.is_targetable() and not most_dangerous.is_boss \
			and most_damage >= player.stats.max_hp * 0.15:
		return PlayerCommand.use_ability(stun.spec.id, most_dangerous.id)

	# Self skills (Light Princess): heal when hurt, shield before big hits.
	for a in player.abilities:
		if not a.is_ready() or a.spec.target != CombatTypes.Target.SELF:
			continue
		if a.spec.heals():
			var heal := player.effective_attack() * a.spec.heal_multiplier
			if player.stats.max_hp - player.current_hp >= heal * 0.8:
				return PlayerCommand.use_ability(a.spec.id)
		elif a.spec.status == CombatTypes.Status.SHIELD and not player.has_status(CombatTypes.Status.SHIELD) \
				and incoming >= player.stats.max_hp * 0.12:
			return PlayerCommand.use_ability(a.spec.id)

	if incoming >= player.current_hp * defend_threshold or targets.is_empty():
		return PlayerCommand.defend()

	if aoe != null and targets.size() >= 2:
		return PlayerCommand.use_ability(aoe.spec.id)

	var target := _focus_target(targets)
	var attack := basic if basic != null else player.abilities[0]
	if not attack.is_ready():
		return PlayerCommand.defend()
	return PlayerCommand.use_ability(attack.spec.id, target.id if target != null else -1)


## Best card to play now as {"index": int, "target": int}, or {} to stop playing cards.
func choose_card(engine: BattleEngine) -> Dictionary:
	if engine.phase != CombatTypes.Phase.PLAYER_TURN:
		return {}
	var player := engine.player
	var info := _threats(engine)
	var targets := engine.targetable_enemies()
	if targets.is_empty():
		return {}
	var best := {}
	var best_value := 0.0
	for i in engine.cards.size():
		var cs: BattleEngine.CardState = engine.cards[i]
		if cs.uses_left <= 0 or engine.mana < cs.card.mana_cost:
			continue
		var plan := _value_card(engine, cs.card.effect, info, targets)
		# Cheaper cards first when equally good; keep spending once value is real.
		var value: float = plan.value - cs.card.mana_cost * 0.5
		if plan.value > 0.0 and value > best_value and engine.validate_card(i, plan.target) == "":
			best_value = value
			best = {"index": i, "target": plan.target}
	return best


func _value_card(engine: BattleEngine, spec: AbilitySpec, info: Dictionary, targets: Array[CombatUnit]) -> Dictionary:
	var player := engine.player
	var S := CombatTypes.Status
	var T := CombatTypes.Target
	var max_hp := float(player.stats.max_hp)
	var focus := _focus_target(targets)
	var most: CombatUnit = info.most
	# --- self buffs / heals
	if spec.target == T.SELF:
		if spec.heals():
			var heal := player.effective_attack() * spec.heal_multiplier
			var missing := player.stats.max_hp - player.current_hp
			return {"value": 30.0 if missing >= heal * 0.8 else 0.0, "target": -1}
		if spec.status == S.SHIELD:
			var worth: bool = not player.has_status(S.SHIELD) and info.incoming >= max_hp * 0.15
			return {"value": 28.0 if worth else 0.0, "target": -1}
		if spec.status == S.LUCKY:
			return {"value": 10.0 if not player.has_status(S.LUCKY) else 0.0, "target": -1}
		return {"value": 0.0, "target": -1}
	# --- control
	if CombatTypes.is_control(spec.status) or spec.status == S.SILENCE:
		if spec.target == T.ALL_OPPONENTS:
			return {"value": 35.0 if info.incoming >= max_hp * 0.25 else 0.0, "target": -1}
		if most == null or not most.is_targetable() or most.action_blocker() != S.NONE:
			return {"value": 0.0, "target": -1}
		if spec.status == S.BANISH and most.is_boss:
			return {"value": 0.0, "target": -1}
		if spec.status == S.SILENCE:
			var plan := engine.get_intent(most)
			if plan == null or plan == most.basic_ability():
				return {"value": 0.0, "target": -1}
		var worth2: bool = info.most_damage >= max_hp * 0.10
		return {"value": 25.0 + info.most_damage * 0.5 if worth2 else 0.0, "target": most.id}
	# --- execute
	if spec.execute_threshold > 0.0:
		for e in targets:
			if not e.is_boss and e.hp_ratio() <= spec.execute_threshold and e.current_hp > 15:
				return {"value": 30.0, "target": e.id}
	# --- damage
	if spec.deals_damage():
		if spec.target == T.ALL_OPPONENTS:
			return {"value": 9.0 * targets.size() if targets.size() >= 2 else 0.0, "target": -1}
		return {"value": 12.0, "target": focus.id if focus != null else -1}
	# --- debuff (weaken etc.)
	if spec.has_status() and most != null and most.is_targetable():
		return {"value": 10.0, "target": most.id}
	return {"value": 0.0, "target": -1}


func _threats(engine: BattleEngine) -> Dictionary:
	var incoming := 0
	var most: CombatUnit = null
	var most_damage := 0
	for e in engine.living_enemies():
		var dmg := engine.estimate_intent_damage(e)
		incoming += dmg
		if dmg > most_damage:
			most_damage = dmg
			most = e
	return {"incoming": incoming, "most": most, "most_damage": most_damage}


## Picks a reward index: biggest upgrade over what is equipped, a new card, or a heal.
## equipped: slot -> EquipmentDefinition (or missing). owned_cards: card id -> copies.
func choose_reward(options: Array, equipped: Dictionary, current_hp: int, max_hp: int, owned_cards := {}) -> int:
	var best := 0
	var best_score := -INF
	for i in options.size():
		var o = options[i]
		var score := 0.0
		if o.kind == LootTable.RewardOption.Kind.EQUIPMENT:
			score = ItemStats.power(o.item) - ItemStats.power(equipped.get(o.item.slot))
		elif o.kind == LootTable.RewardOption.Kind.RESTORE:
			score = mini(max_hp - current_hp, roundi(max_hp * o.heal_fraction)) * 0.6
		elif o.kind == LootTable.RewardOption.Kind.CARD:
			var owned: bool = owned_cards.get(o.card.id, 0) > 0
			score = (8.0 + o.card.rarity * 6.0) if owned else (22.0 + o.card.rarity * 12.0)
		if score > best_score:
			best_score = score
			best = i
	return best


## Between battles: craft what we can afford (best results first), fuse, then pick the deck.
static func manage_cards(col: Collection, library: CardLibrary) -> void:
	if library == null:
		return
	var crafted := true
	while crafted:
		crafted = false
		var recipes := library.craft_recipes.duplicate()
		# Prefer cards we don't have yet, then higher rarity.
		recipes.sort_custom(func(a, b):
			var na: int = 1 if col.card_count(a.result.id) == 0 else 0
			var nb: int = 1 if col.card_count(b.result.id) == 0 else 0
			return na > nb or (na == nb and a.result.rarity > b.result.rarity))
		for r in recipes:
			if col.card_count(r.result.id) < 3 and col.can_craft(r):
				col.craft(r)
				crafted = true
				break
	for f in library.fusion_recipes:
		while col.can_fuse(f):
			col.fuse(f)
	# Deck: highest rarity first, a heal/shield kept if owned.
	var owned: Array = []
	for card_id in col.cards:
		var c := col.get_card(card_id)
		if c != null:
			owned.append(c)
	owned.sort_custom(func(a, b): return a.rarity > b.rarity or (a.rarity == b.rarity and a.mana_cost < b.mana_cost))
	col.deck.clear()
	for c in owned:
		if col.deck.size() >= col.deck_size:
			break
		col.deck.append(c.id)


func _focus_target(alive: Array[CombatUnit]) -> CombatUnit:
	var best: CombatUnit = null
	var best_score := INF
	for e in alive:
		var healer := false
		for a in e.abilities:
			if a.spec.heals():
				healer = true
		var score := e.current_hp - (1000.0 if healer else 0.0)
		if score < best_score:
			best_score = score
			best = e
	return best
