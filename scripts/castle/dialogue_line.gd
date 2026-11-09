class_name DialogueLine
extends Resource
## One line a princess can say. Filters left at their "any" value match everything;
## the more filters a line sets, the more specific it is and the more likely it wins
## (see DialogueDB.pick). Add lines in data/dialogue_db.tres — no code changes.

## TALK, GREETING, ACTIVITY_<NAME>, GIFT_LIKED, GIFT, DECORATE, BOND_UP, ITEM_RECEIVED, ITEM_EQUIPPED,
## ITEM_CHANGED, LEGENDARY_GET, BOSS_APPEAR, BATTLE_START, VICTORY, DEFEAT, CARD_SPECIAL, STORY_BOND3
@export var trigger: String = "TALK"
@export_multiline var text: String = ""
@export var expression: CastleTypes.Expr = CastleTypes.Expr.NORMAL

@export_group("Filters (leave empty / -1 for any)")
@export var princess_id: String = ""
@export var personality: int = -1
@export var item_id: String = ""
@export var slot: int = -1        ## ItemTypes.Slot
@export var min_rarity: int = -1  ## ItemTypes.Rarity
@export var min_bond: int = 0


static func make(p_trigger: String, p_text: String, p_expr := 0, p_personality := -1) -> DialogueLine:
	var d := DialogueLine.new()
	d.trigger = p_trigger
	d.text = p_text
	d.expression = p_expr
	d.personality = p_personality
	return d


## Returns -1 if this line doesn't match the context, else a specificity score.
## ctx keys: princess_id, personality, item_id, slot, rarity, bond
func score(p_trigger: String, ctx: Dictionary) -> int:
	if trigger != p_trigger:
		return -1
	var s := 0
	if princess_id != "":
		if princess_id != ctx.get("princess_id", ""):
			return -1
		s += 4
	if personality >= 0:
		if personality != ctx.get("personality", -2):
			return -1
		s += 2
	if item_id != "":
		if item_id != ctx.get("item_id", ""):
			return -1
		s += 8
	if slot >= 0:
		if slot != ctx.get("slot", -2):
			return -1
		s += 2
	if min_rarity >= 0:
		if ctx.get("rarity", -1) < min_rarity:
			return -1
		s += 1 + min_rarity
	if min_bond > ctx.get("bond", 0):
		return -1
	s += min_bond
	return s
