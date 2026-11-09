extends RefCounted
## Phase 6 tests: settings (validation, persistence), save safety (checksum, backups,
## fallback, old format, new game), sound bank completeness, safe area, export preset.

var failures: Array[String] = []


func check(cond: bool, msg: String) -> void:
	if not cond:
		failures.append(msg)

func eq(actual, expected, msg: String) -> void:
	if actual != expected:
		failures.append("%s (expected %s, got %s)" % [msg, str(expected), str(actual)])

func tmp(name: String) -> String:
	return OS.get_temp_dir().path_join("pc_%s_%d" % [name, Time.get_ticks_usec()])

func cleanup(path: String) -> void:
	for suffix in ["", ".1", ".2", ".bak", ".tmp"]:
		if FileAccess.file_exists(path + suffix):
			DirAccess.remove_absolute(path + suffix)

func new_state(path: String) -> Node:
	var gs = load("res://scripts/core/game_state.gd").new()
	gs.save_path = path
	return gs


# ------------------------------------------------------------ settings

func test_settings_validate_and_persist() -> void:
	var s = load("res://scripts/core/game_settings.gd").new()
	s.from_dict({"music_volume": 5.0, "sfx_volume": -1, "battle_speed": 7.0, "fps_limit": 144, "vibration": false})
	eq(s.music_volume, 1.0, "volume clamped high")
	eq(s.sfx_volume, 0.0, "volume clamped low")
	eq(s.battle_speed, 1.0, "unknown speed -> 1x")
	eq(s.fps_limit, 60, "unknown fps -> 60")
	eq(s.vibration, false, "vibration read")
	var path := tmp("settings") + ".cfg"
	s.path = path
	s.set_value("battle_speed", 2.0)
	s.set_value("music_volume", 0.3)
	var s2 = load("res://scripts/core/game_settings.gd").new()
	s2.path = path
	s2.load_settings()
	eq(s2.battle_speed, 2.0, "speed persisted")
	check(is_equal_approx(s2.music_volume, 0.3), "music volume persisted")
	eq(GameSettings.linear_db(0.0), -80.0, "0 = muted")
	check(is_equal_approx(GameSettings.linear_db(1.0), 0.0), "1 = 0 dB")
	DirAccess.remove_absolute(path)
	s.free()
	s2.free()


# ------------------------------------------------------------ save safety

func test_save_has_checksum_and_rotates_backups() -> void:
	var path := tmp("save")
	var gs := new_state(path)
	gs.castle.add_exp("sword_princess", 30)
	check(gs.save_game(), "save ok")
	gs.castle.add_bond("sword_princess", 5)
	gs.save_game()
	gs.castle.add_bond("sword_princess", 5)
	gs.save_game()
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	check(parsed.has("checksum") and parsed.has("data") and parsed.has("saved_at"), "wrapped format")
	eq(int(parsed.version), 5, "version 5")
	check(FileAccess.file_exists(path + ".1") and FileAccess.file_exists(path + ".2"), "two backups kept")
	check(not FileAccess.file_exists(path + ".tmp"), "no temp file left")
	var gs2 := new_state(path)
	gs2.load_game()
	eq(gs2.castle.level("sword_princess"), 2, "level loaded")
	eq(gs2.castle.bond_points("sword_princess"), 10, "latest bond loaded")
	cleanup(path)
	gs.free()
	gs2.free()


func test_damaged_save_falls_back_to_backup() -> void:
	var path := tmp("save")
	var gs := new_state(path)
	gs.castle.add_bond("sword_princess", 4)
	gs.save_game()
	gs.castle.add_bond("sword_princess", 4)
	gs.save_game() # main = 8, .1 = 4
	# Tamper with the data but keep valid JSON -> checksum must reject it.
	var parsed: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	parsed.data.castle.bond["sword_princess"] = 999
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify(parsed))
	f.close()
	var gs2 := new_state(path)
	gs2.load_game()
	eq(gs2.castle.bond_points("sword_princess"), 4, "tampered main rejected, backup .1 loaded")
	eq(gs2.load_source, path + ".1", "load source = backup")
	check(FileAccess.file_exists(path + ".bak"), "damaged main kept as .bak")
	# Truncated (crash mid-write) main + backup
	f = FileAccess.open(path, FileAccess.WRITE)
	f.store_string("{\"version\": 5, \"da")
	f.close()
	var gs3 := new_state(path)
	gs3.load_game()
	eq(gs3.castle.bond_points("sword_princess"), 4, "truncated main -> backup")
	cleanup(path)
	gs.free()
	gs2.free()
	gs3.free()


func test_old_unwrapped_save_still_loads() -> void:
	var path := tmp("save")
	var c := CastleProgress.new()
	c.add_bond("light_princess", 7)
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify({"version": 4, "collection": {}, "castle": c.to_dict()}))
	f.close()
	var gs := new_state(path)
	gs.load_game()
	eq(gs.castle.bond_points("light_princess"), 7, "v4 save loads")
	cleanup(path)
	gs.free()


func test_new_game_resets_and_keeps_backup() -> void:
	var path := tmp("save")
	var gs := new_state(path)
	gs.setup()
	gs.castle.add_exp("sword_princess", 500)
	gs.castle.cleared_stages.append("stage_01")
	gs.collection.add_essence("fire", 10)
	gs.save_game()
	gs.new_game()
	eq(gs.castle.level("sword_princess"), 1, "level reset")
	check(gs.castle.cleared_stages.is_empty(), "stages reset")
	eq(gs.collection.essence("fire"), 0, "materials reset")
	check(not gs.collection.equipped_items("sword_princess").is_empty(), "starting gear given")
	check(FileAccess.file_exists(path + ".1"), "old progress kept as backup")
	var gs2 := new_state(path)
	gs2.load_game()
	eq(gs2.castle.level("sword_princess"), 1, "fresh save on disk")
	cleanup(path)
	gs.free()
	gs2.free()


func test_save_contains_every_progress_field() -> void:
	var gs := new_state(tmp("unused"))
	var d: Dictionary = {"collection": gs.collection.to_dict(), "castle": gs.castle.to_dict()}
	for key in ["owned", "equipped", "cards", "deck", "materials"]:
		check(d.collection.has(key), "collection saves " + key)
	for key in ["bond", "rooms", "furniture", "levels", "cleared_stages", "companion", "active_princess"]:
		check(d.castle.has(key), "castle saves " + key)
	gs.free()


# ------------------------------------------------------------ audio, UI, export

func test_sound_bank_complete() -> void:
	var bank: SoundBank = load("res://data/sound_bank.tres")
	check(bank != null, "sound bank exists")
	for id in ["click", "hit", "crit", "miss", "heal", "shield", "status", "death", "card", "victory",
			"defeat", "level_up", "boss_phase", "summon", "reward", "coin", "unlock"]:
		var s := bank.get_sfx(id)
		check(s is AudioStreamWAV and (s as AudioStreamWAV).data.size() > 100, "sfx " + id)
	for id in ["castle", "battle", "boss"]:
		var m := bank.get_music(id) as AudioStreamWAV
		check(m != null and m.loop_mode == AudioStreamWAV.LOOP_FORWARD, "music %s loops" % id)


func test_safe_area_fits_layer() -> void:
	var layer := CanvasLayer.new()
	SafeArea.apply_to_layer(layer, Rect2(0, 0, 1, 1))
	check(layer.transform == Transform2D.IDENTITY, "full screen = no change")
	SafeArea.apply_to_layer(layer, Rect2(0.05, 0.0, 0.9, 1.0)) # notch left + right
	check(is_equal_approx(layer.transform.get_scale().x, 0.9), "scaled to safe width")
	check(layer.transform.origin.x >= 1920 * 0.05 - 0.5, "moved past the notch")
	check(layer.transform.origin.x + 1920 * 0.9 <= 1920 * 0.95 + 0.5, "right edge inside")
	layer.free()


func test_android_export_preset() -> void:
	var cfg := ConfigFile.new()
	check(cfg.load("res://export_presets.cfg") == OK, "export_presets.cfg exists")
	eq(cfg.get_value("preset.0", "platform", ""), "Android", "Android preset")
	eq(cfg.get_value("preset.0.options", "package/unique_name", ""), "com.princesscastle.game", "package name")
	check(cfg.get_value("preset.0.options", "architectures/arm64-v8a", false), "arm64 enabled")
	check(cfg.get_value("preset.0.options", "permissions/vibrate", false), "vibrate permission")
	eq(ProjectSettings.get_setting("application/config/quit_on_go_back"), false, "Back button handled by the game")
	check(ProjectSettings.get_setting("rendering/textures/vram_compression/import_etc2_astc"), "mobile texture compression")


## Web / Android have no Windows fonts: every character in the game text must exist in the
## bundled fonts (Prompt for Thai + Latin, Noto Sans Symbols 2 for ★ ✓ ♥ ...).
func test_bundled_fonts_cover_all_game_text() -> void:
	var prompt: FontFile = load("res://assets/fonts/Prompt-SemiBold.ttf")
	var symbols: FontFile = load("res://assets/fonts/NotoSansSymbols2-Regular.ttf")
	var ui: Font = load("res://assets/fonts/ui_font.tres")
	check(ui is FontVariation and (ui as FontVariation).base_font == prompt, "UI font is the bundled Prompt font")
	var missing := {}
	for dir in ["res://scripts", "res://data", "res://scenes"]:
		for path in _files(dir):
			var text := FileAccess.get_file_as_string(path)
			for i in text.length():
				var c := text.unicode_at(i)
				if c < 32 or c == 0xFEFF:
					continue
				if not prompt.has_char(c) and not symbols.has_char(c):
					missing[String.chr(c)] = path.get_file()
	check(missing.is_empty(), "characters missing from bundled fonts: %s" % str(missing))


func _files(dir: String) -> Array[String]:
	var out: Array[String] = []
	var d := DirAccess.open(dir)
	if d == null:
		return out
	for f in d.get_files():
		if f.ends_with(".gd") or f.ends_with(".tres") or f.ends_with(".tscn"):
			out.append(dir.path_join(f))
	for sub in d.get_directories():
		out.append_array(_files(dir.path_join(sub)))
	return out
