class_name BattleData
## Applies the AI battle art (tools/build_battle_art.gd) to the monster and stage data.
## Called at the end of tools/generate_data.gd. Monsters without HD art keep their old art.

## On-screen height (px at 1080p) of each monster: small < normal < mini boss < boss.
const HEIGHTS := {
	"slime": 150, "bat": 150, "goblin": 210, "skeleton_knight": 330, "dark_shaman": 225,
	"ice_wisp": 165, "frost_golem": 330, "lich_queen": 410,
	"imp": 155, "werewolf": 340, "night_witch": 410,
	"wyvern": 240, "drake": 340, "elder_wyrm": 440,
}
## Background shift so each picture's ground line (~y 520 on screen) meets the back row of
## monsters (feet at y 575); measured from the art: ground top x 1.406 (cover scale).
const BG_OFFSET := {
	"stage_01": Vector2(0, -85), "stage_02": Vector2(0, -169),
	"stage_03": Vector2(0, -169), "stage_04": Vector2(0, -267),
}
## BattleController.monster_scale (monster textures are drawn at visual_scale x this).
const MONSTER_SCALE := 1.3


static func apply(saver: Callable) -> bool:
	var ok := true
	for id in HEIGHTS:
		var path := "res://data/monsters/%s.tres" % id
		var hd := "res://assets/art/monsters_hd/%s.png" % id
		if not ResourceLoader.exists(path) or not ResourceLoader.exists(hd):
			continue
		var m: MonsterDefinition = load(path)
		m.texture = load(hd)
		m.faces_left = true
		m.visual_scale = float(HEIGHTS[id]) / (m.texture.get_height() * MONSTER_SCALE)
		ok = saver.call(m, path) and ok
	for stage_id in BG_OFFSET:
		var path := "res://data/%s.tres" % stage_id
		var bg := "res://assets/art/battle_bg/%s.png" % stage_id
		if not ResourceLoader.exists(path) or not ResourceLoader.exists(bg):
			continue
		var s: StageDefinition = load(path)
		s.background = load(bg)
		s.background_offset = BG_OFFSET[stage_id]
		ok = saver.call(s, path) and ok
	return ok
