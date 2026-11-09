extends SceneTree
## Draws placeholder art: the princess body (no gear) and every equipment layer.
## Equipment is drawn in the princess's own pixel space and cropped around its slot anchor,
## so each layer lines up on the body automatically (paper doll).
##   Godot_console.exe --headless --path . --script res://tools/generate_art.gd
## Replace any PNG with real art of the same size/anchor later.

const OUT := "res://assets/art/"
const OUTLINE := Color8(28, 14, 38)
const SKIN := Color8(255, 226, 214)
const WHITE := Color.WHITE
const CX := 86.0  # princess centre x in her texture
const HY := 168.0 # head centre y

## Slot anchors in princess texture pixels (y up). Must match PrincessDefinition.slot_anchors:
## local = (px - 90, -py)
const ANCHOR_WEAPON := Vector2(114, 108)
const ANCHOR_HEAD := Vector2(86, 206)
const ANCHOR_WING := Vector2(86, 122)
const ANCHOR_ARMOR := Vector2(86, 100)
const ANCHOR_ACC := Vector2(86, 126)


func _init() -> void:
	# `-- --only=castle` regenerates just the Phase 4 art (faster).
	var only := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--only="):
			only = a.substr(7)
	if only == "" or only == "monsters":
		MonsterArt.generate_all(self)
	if only == "monsters":
		print("generate_art: OK")
		quit(0)
		return
	if only == "" or only == "castle":
		CastleArt.generate_all(self)
	if only == "castle":
		print("generate_art: OK")
		quit(0)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT + "items"))
	_princess()
	_weapons()
	_headgear()
	_wings()
	_armor()
	_accessories()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT + "cards"))
	_cards()
	_essences()
	print("generate_art: OK")
	quit(0)


# ------------------------------------------------------------ helpers

## Draws `draw` twice: enlarged in the outline colour, then normal.
func outlined(draw: Callable, size := 3.0) -> void:
	draw.call(size)
	draw.call(0.0)

func col(o: float, c: Color) -> Color:
	return OUTLINE if o > 0.0 else c

func canvas(w: int, h: int, anchor: Vector2) -> PixelCanvas:
	var c := PixelCanvas.new(w, h)
	c.origin = Vector2(w * 0.5, h * 0.5) - anchor
	return c

func save(c: PixelCanvas, file: String) -> void:
	var err := c.save_png(ProjectSettings.globalize_path(OUT + file))
	if err != OK:
		push_error("could not save " + file)


# ------------------------------------------------------------ princess body

func _princess() -> void:
	var c := PixelCanvas.new(180, 230)
	var dress := Color8(150, 40, 90)
	var hair := Color8(70, 40, 110)
	var accent := Color8(255, 120, 160)
	# twin tails
	outlined(func(o): c.ellipse(CX - 46, 135, 16 + o, 40 + o, col(o, hair)))
	outlined(func(o): c.ellipse(CX + 46, 135, 16 + o, 40 + o, col(o, hair)))
	# skirt + bodice
	outlined(func(o): c.quad(Vector2(CX - 52 - o, 8 - o), Vector2(CX + 52 + o, 8 - o), Vector2(CX + 20 + o, 110 + o), Vector2(CX - 20 - o, 110 + o), col(o, dress)))
	c.quad(Vector2(CX - 46, 8), Vector2(CX + 46, 8), Vector2(CX + 40, 22), Vector2(CX - 40, 22), dress.darkened(0.35))
	for i in range(-2, 3):
		c.circle(CX + i * 18, 15, 5, dress.lightened(0.3))
	outlined(func(o): c.round_rect(CX - 20 - o, 92 - o, CX + 20 + o, 132 + o, 8, col(o, dress)))
	c.tri(Vector2(CX - 8, 128), Vector2(CX + 8, 128), Vector2(CX, 112), accent)
	# arms
	outlined(func(o): c.ellipse(CX - 26, 108, 8 + o, 18 + o, col(o, SKIN)))
	outlined(func(o): c.ellipse(CX + 28, 108, 8 + o, 18 + o, col(o, SKIN)))
	# head
	outlined(func(o): c.circle(CX, HY, 42 + o, col(o, hair)))
	c.ellipse(CX, HY - 6, 36, 33, SKIN)
	c.ellipse(CX - 12, HY + 22, 26, 14, hair)
	c.ellipse(CX + 16, HY + 20, 22, 14, hair)
	c.tri(Vector2(CX - 4, HY + 30), Vector2(CX + 8, HY + 30), Vector2(CX + 2, HY + 6), hair)
	for ex in [-14.0, 14.0]:
		c.ellipse(CX + ex, HY - 8, 8, 11, OUTLINE)
		c.ellipse(CX + ex, HY - 10, 6, 8, accent)
		c.circle(CX + ex + 2.5, HY - 4, 3, WHITE)
		c.circle(CX + ex - 2, HY - 12, 1.4, WHITE)
	c.ellipse(CX - 24, HY - 20, 6, 3.5, Color8(255, 150, 170, 150))
	c.ellipse(CX + 24, HY - 20, 6, 3.5, Color8(255, 150, 170, 150))
	c.ellipse(CX, HY - 22, 4, 2.2, Color8(150, 60, 80))
	save(c, "princess_base.png")


# ------------------------------------------------------------ weapons (grip at front hand)

func _sword(file: String, blade: Color, guard: Color, w: float, length: float, glow := Color(0, 0, 0, 0)) -> void:
	var c := canvas(96, 260, ANCHOR_WEAPON)
	var x := ANCHOR_WEAPON.x
	var y := ANCHOR_WEAPON.y
	if glow.a > 0:
		c.ellipse(x, y + 12 + length * 0.5, w + 14, length * 0.55, glow)
	outlined(func(o): c.rect(x - w * 0.5 - o, y + 10 - o, x + w * 0.5 + o, y + 10 + length + o, col(o, blade)))
	outlined(func(o): c.tri(Vector2(x - w * 0.5 - o, y + 10 + length), Vector2(x + w * 0.5 + o, y + 10 + length), Vector2(x, y + 10 + length + w + 6 + o), col(o, blade)))
	c.rect(x - 1, y + 14, x + 1, y + 6 + length, Color(1, 1, 1, 0.55))
	outlined(func(o): c.rect(x - 15 - o, y + 3 - o, x + 15 + o, y + 10 + o, col(o, guard)))
	outlined(func(o): c.rect(x - 3 - o, y - 14 - o, x + 3 + o, y + 3 + o, col(o, Color8(90, 50, 70))))
	c.circle(x, y - 16, 5, guard)
	save(c, "items/" + file)


func _weapons() -> void:
	_sword("rusty_sword.png", Color8(150, 135, 120), Color8(120, 90, 60), 8, 78)
	_sword("rose_rapier.png", Color8(235, 220, 235), Color8(255, 110, 160), 5, 100)
	_sword("moonlight_blade.png", Color8(160, 205, 255), Color8(200, 220, 255), 10, 100, Color(0.5, 0.75, 1, 0.25))
	_sword("dragon_sword.png", Color8(220, 80, 60), Color8(255, 200, 80), 16, 104, Color(1, 0.5, 0.2, 0.2))
	# Mythic scythe: long shaft + curved blade
	var c := canvas(150, 280, ANCHOR_WEAPON)
	var x := ANCHOR_WEAPON.x
	var y := ANCHOR_WEAPON.y
	c.ellipse(x - 20, y + 120, 50, 40, Color(0.7, 0.3, 1, 0.22))
	outlined(func(o): c.rect(x - 3 - o, y - 40 - o, x + 3 + o, y + 130 + o, col(o, Color8(50, 30, 60))))
	outlined(func(o): c.quad(Vector2(x + 3, y + 130 + o), Vector2(x + 3, y + 112 - o), Vector2(x - 50 - o, y + 112), Vector2(x - 66 - o, y + 92 - o), col(o, Color8(170, 90, 255))))
	c.line(Vector2(x - 2, y + 124), Vector2(x - 56, y + 100), 2, Color(1, 1, 1, 0.6))
	c.circle(x, y + 132, 6, Color8(255, 80, 120))
	save(c, "items/abyss_scythe.png")


# ------------------------------------------------------------ headgear (sits on top of the head)

func _headgear() -> void:
	var a := ANCHOR_HEAD
	var gold := Color8(255, 210, 90)
	# Ribbon bow (common)
	var c := canvas(130, 100, a)
	var red := Color8(220, 50, 80)
	outlined(func(o): c.tri(Vector2(a.x + 18, a.y - 2), Vector2(a.x - 2 - o, a.y + 16 + o), Vector2(a.x - 2 - o, a.y - 18 - o), col(o, red)))
	outlined(func(o): c.tri(Vector2(a.x + 18, a.y - 2), Vector2(a.x + 38 + o, a.y + 16 + o), Vector2(a.x + 38 + o, a.y - 18 - o), col(o, red)))
	outlined(func(o): c.circle(a.x + 18, a.y - 2, 6 + o, col(o, red.lightened(0.2))))
	save(c, "items/ribbon_bow.png")
	# Silver tiara (rare)
	c = canvas(130, 100, a)
	var silver := Color8(215, 225, 240)
	outlined(func(o): c.ellipse(a.x, a.y - 4, 32 + o, 7 + o, col(o, silver)))
	for i in range(-2, 3):
		var h := 16.0 if i == 0 else 9.0
		outlined(func(o): c.tri(Vector2(a.x + i * 12 - 5 - o, a.y), Vector2(a.x + i * 12 + 5 + o, a.y), Vector2(a.x + i * 12, a.y + h + o), col(o, silver)))
	c.circle(a.x, a.y + 4, 4, Color8(90, 160, 255))
	save(c, "items/silver_tiara.png")
	# Witch hat (epic)
	c = canvas(160, 140, a)
	var hat := Color8(80, 40, 120)
	outlined(func(o): c.ellipse(a.x, a.y - 2, 60 + o, 12 + o, col(o, hat)))
	outlined(func(o): c.quad(Vector2(a.x - 32 - o, a.y), Vector2(a.x + 32 + o, a.y), Vector2(a.x + 8 + o, a.y + 52), Vector2(a.x + 30, a.y + 66 + o), col(o, hat)))
	c.rect(a.x - 31, a.y + 2, a.x + 31, a.y + 11, Color8(255, 150, 60))
	c.circle(a.x, a.y + 6, 5, gold)
	save(c, "items/witch_hat.png")
	# Queen crown (legendary)
	c = canvas(130, 100, a)
	outlined(func(o): c.rect(a.x - 26 - o, a.y - 6 - o, a.x + 26 + o, a.y + 6 + o, col(o, gold)))
	for i in range(-2, 3):
		var h2 := 30.0 if i == 0 else (24.0 if absi(i) == 1 else 16.0)
		outlined(func(o): c.tri(Vector2(a.x + i * 12 - 7 - o, a.y + 5), Vector2(a.x + i * 12 + 7 + o, a.y + 5), Vector2(a.x + i * 12, a.y + h2 + o), col(o, gold)))
		c.circle(a.x + i * 12, a.y + h2 - 2, 3, WHITE)
	c.circle(a.x, a.y, 5, Color8(220, 40, 80))
	c.circle(a.x - 15, a.y, 3.5, Color8(60, 140, 255))
	c.circle(a.x + 15, a.y, 3.5, Color8(60, 200, 120))
	save(c, "items/queen_crown.png")
	# Starfall halo (mythic)
	c = canvas(140, 110, a)
	# Hollow glowing ring built from dots along an ellipse.
	for k in 72:
		var t := k * TAU / 72.0
		var p := Vector2(a.x + cos(t) * 38.0, a.y + 24 + sin(t) * 10.0)
		c.circle(p.x, p.y, 6, Color(1, 0.95, 0.6, 0.12))
		c.circle(p.x, p.y, 3.2, Color8(255, 240, 150))
	for p in [Vector2(-34, 36), Vector2(30, 40), Vector2(0, 42)]:
		_star(c, a + p, 7, Color8(255, 250, 200))
	save(c, "items/starfall_halo.png")


func _star(c: PixelCanvas, p: Vector2, r: float, color: Color) -> void:
	c.tri(p + Vector2(-r, 0), p + Vector2(r, 0), p + Vector2(0, r * 1.6), color)
	c.tri(p + Vector2(-r, 0), p + Vector2(r, 0), p + Vector2(0, -r * 1.6), color)
	c.tri(p + Vector2(0, -r), p + Vector2(0, r), p + Vector2(r * 1.6, 0), color)
	c.tri(p + Vector2(0, -r), p + Vector2(0, r), p + Vector2(-r * 1.6, 0), color)


# ------------------------------------------------------------ wings (behind the back)

func _wing_pair(c: PixelCanvas, draw_one: Callable) -> void:
	draw_one.call(-1.0)
	draw_one.call(1.0)


func _wings() -> void:
	var a := ANCHOR_WING
	# Moth (common): soft round wings
	var c := canvas(300, 220, a)
	_wing_pair(c, func(s):
		outlined(func(o): c.ellipse(a.x + s * 56, a.y + 26, 46 + o, 34 + o, col(o, Color8(225, 205, 170))))
		outlined(func(o): c.ellipse(a.x + s * 46, a.y - 20, 30 + o, 24 + o, col(o, Color8(205, 180, 145))))
		c.circle(a.x + s * 62, a.y + 30, 10, Color8(150, 110, 80)))
	save(c, "items/moth_wings.png")
	# Bat (rare)
	c = canvas(300, 220, a)
	var bat := Color8(70, 35, 95)
	_wing_pair(c, func(s):
		outlined(func(o): c.tri(Vector2(a.x + s * 10, a.y + 20), Vector2(a.x + s * (118 + o), a.y + 70 + o), Vector2(a.x + s * 96, a.y - 40 - o), col(o, bat)))
		c.tri(Vector2(a.x + s * 60, a.y + 5), Vector2(a.x + s * 96, a.y - 40), Vector2(a.x + s * 80, a.y - 10), bat.lightened(0.15)))
	save(c, "items/bat_wings.png")
	# Fairy (epic): translucent teal
	c = canvas(300, 220, a)
	_wing_pair(c, func(s):
		c.ellipse(a.x + s * 58, a.y + 40, 52, 30, Color(0.5, 1, 0.9, 0.55))
		c.ellipse(a.x + s * 48, a.y - 18, 36, 22, Color(0.6, 0.9, 1, 0.5))
		c.line(Vector2(a.x + s * 10, a.y + 10), Vector2(a.x + s * 100, a.y + 52), 2, Color(1, 1, 1, 0.7)))
	save(c, "items/fairy_wings.png")
	# Dragon (legendary): big red membrane with bones
	c = canvas(340, 240, a)
	var red := Color8(170, 40, 50)
	_wing_pair(c, func(s):
		outlined(func(o): c.quad(Vector2(a.x + s * 8, a.y + 30), Vector2(a.x + s * (100 + o), a.y + 100 + o), Vector2(a.x + s * (150 + o), a.y + 30), Vector2(a.x + s * 110, a.y - 50 - o), col(o, red)))
		for b in [Vector2(100, 100), Vector2(150, 30), Vector2(110, -50)]:
			c.line(Vector2(a.x + s * 10, a.y + 30), Vector2(a.x + s * b.x, a.y + b.y), 4, Color8(240, 200, 120)))
	save(c, "items/dragon_wings.png")
	# Seraph (mythic): layered white feathers + glow
	c = canvas(340, 240, a)
	c.ellipse(a.x, a.y + 30, 160, 90, Color(1, 0.95, 0.7, 0.18))
	_wing_pair(c, func(s):
		for i in 5:
			var fx: float = a.x + s * (30 + i * 24)
			var fy: float = a.y + 70 - i * 18
			outlined(func(o): c.ellipse(fx, fy, 16 + o, 44 + o, col(o, WHITE)), 2.0)
			c.ellipse(fx, fy - 10, 9, 26, Color8(230, 235, 255)))
	save(c, "items/seraph_wings.png")


# ------------------------------------------------------------ armor (over the bodice / skirt)

func _armor() -> void:
	var a := ANCHOR_ARMOR
	# Leather corset (common)
	var c := canvas(140, 150, a)
	var leather := Color8(130, 80, 50)
	outlined(func(o): c.round_rect(CX - 21 - o, 90 - o, CX + 21 + o, 122 + o, 6, col(o, leather)), 2.0)
	for i in 4:
		c.line(Vector2(CX - 6, 96 + i * 7), Vector2(CX + 6, 100 + i * 7), 2, Color8(240, 220, 180))
	save(c, "items/leather_corset.png")
	# Lace guard dress (rare)
	c = canvas(140, 150, a)
	var lace := Color8(240, 240, 250)
	outlined(func(o): c.round_rect(CX - 22 - o, 96 - o, CX + 22 + o, 132 + o, 8, col(o, Color8(200, 205, 225))), 2.0)
	for i in range(-2, 3):
		c.circle(CX + i * 9, 130, 5, lace)
	c.quad(Vector2(CX - 30, 70), Vector2(CX + 30, 70), Vector2(CX + 24, 80), Vector2(CX - 24, 80), lace)
	c.circle(CX, 112, 5, Color8(90, 160, 255))
	save(c, "items/lace_guard_dress.png")
	# Thorn plate (epic)
	c = canvas(150, 150, a)
	var thorn := Color8(50, 90, 60)
	outlined(func(o): c.round_rect(CX - 23 - o, 90 - o, CX + 23 + o, 132 + o, 6, col(o, thorn)), 2.0)
	for s in [-1.0, 1.0]:
		outlined(func(o): c.ellipse(CX + s * 26, 128, 12 + o, 9 + o, col(o, thorn.lightened(0.15))), 2.0)
		for k in 3:
			c.tri(Vector2(CX + s * (18 + k * 7), 132), Vector2(CX + s * (24 + k * 7), 132), Vector2(CX + s * (21 + k * 7), 146), Color8(170, 220, 120))
	c.circle(CX, 112, 6, Color8(200, 40, 60))
	save(c, "items/thorn_plate.png")
	# Rose knight armor (legendary)
	c = canvas(160, 160, a)
	var steel := Color8(205, 210, 225)
	outlined(func(o): c.quad(Vector2(CX - 40 - o, 30 - o), Vector2(CX + 40 + o, 30 - o), Vector2(CX + 22 + o, 92), Vector2(CX - 22 - o, 92), col(o, Color8(150, 155, 175))), 2.0)
	outlined(func(o): c.round_rect(CX - 23 - o, 88 - o, CX + 23 + o, 134 + o, 8, col(o, steel)), 2.0)
	for s in [-1.0, 1.0]:
		outlined(func(o): c.ellipse(CX + s * 27, 126, 14 + o, 11 + o, col(o, steel)), 2.0)
	c.circle(CX, 112, 7, Color8(220, 40, 80))
	c.circle(CX, 112, 3, Color8(255, 210, 90))
	c.rect(CX - 23, 88, CX + 23, 92, Color8(255, 210, 90))
	save(c, "items/rose_knight_armor.png")


# ------------------------------------------------------------ accessories (chest)

func _gem_pendant(file: String, gem: Color, chain: Color, shape := "round") -> void:
	var a := ANCHOR_ACC
	var c := canvas(70, 70, a)
	c.line(Vector2(a.x - 12, a.y + 6), Vector2(a.x, a.y - 4), 2, chain)
	c.line(Vector2(a.x + 12, a.y + 6), Vector2(a.x, a.y - 4), 2, chain)
	match shape:
		"heart":
			outlined(func(o): c.circle(a.x - 4, a.y - 8, 5 + o, col(o, gem)), 2.0)
			outlined(func(o): c.circle(a.x + 4, a.y - 8, 5 + o, col(o, gem)), 2.0)
			outlined(func(o): c.tri(Vector2(a.x - 9 - o, a.y - 9), Vector2(a.x + 9 + o, a.y - 9), Vector2(a.x, a.y - 20 - o), col(o, gem)), 2.0)
		"drop":
			c.circle(a.x, a.y - 12, 12, Color(0.6, 0.85, 1, 0.3))
			outlined(func(o): c.circle(a.x, a.y - 14, 7 + o, col(o, gem)), 2.0)
			outlined(func(o): c.tri(Vector2(a.x - 6 - o, a.y - 12), Vector2(a.x + 6 + o, a.y - 12), Vector2(a.x, a.y - 2 + o), col(o, gem)), 2.0)
		"clover":
			for p in [Vector2(-4, -6), Vector2(4, -6), Vector2(-4, -14), Vector2(4, -14)]:
				outlined(func(o): c.circle(a.x + p.x, a.y + p.y, 4.5 + o, col(o, gem)), 2.0)
		"mirror":
			for k in 8:
				var ang := k * TAU / 8.0
				c.tri(Vector2(a.x, a.y - 12) + Vector2(cos(ang), sin(ang)) * 7, Vector2(a.x, a.y - 12) + Vector2(cos(ang + 0.4), sin(ang + 0.4)) * 7,
					Vector2(a.x, a.y - 12) + Vector2(cos(ang + 0.2), sin(ang + 0.2)) * 14, Color8(150, 220, 120))
			outlined(func(o): c.circle(a.x, a.y - 12, 8 + o, col(o, gem)), 2.0)
		_:
			outlined(func(o): c.circle(a.x, a.y - 10, 7 + o, col(o, gem)), 2.0)
	c.circle(a.x + 2, a.y - 8, 2, Color(1, 1, 1, 0.8))
	save(c, "items/" + file)


func _accessories() -> void:
	var gold := Color8(255, 210, 90)
	_gem_pendant("clover_charm.png", Color8(90, 200, 100), gold, "clover")
	_gem_pendant("ruby_pendant.png", Color8(220, 40, 70), gold)
	_gem_pendant("vampire_locket.png", Color8(140, 10, 40), Color8(200, 200, 210), "heart")
	_gem_pendant("mirror_of_thorns.png", Color8(210, 225, 245), Color8(200, 200, 210), "mirror")
	_gem_pendant("moon_tear.png", Color8(170, 220, 255), Color8(230, 235, 255), "drop")


# ------------------------------------------------------------ cards (Phase 3) — 160x160 icons, centre (80,80)

const ORANGE := Color8(255, 140, 40)
const YELLOW := Color8(255, 230, 120)
const RED := Color8(220, 50, 50)
const ICE := Color8(140, 215, 255)
const PURPLE := Color8(150, 80, 220)
const DARK := Color8(40, 20, 60)
const GREEN := Color8(90, 220, 120)
const GOLDC := Color8(255, 205, 80)


func _glow(c: PixelCanvas, x: float, y: float, r: float, color: Color) -> void:
	for k in 4:
		c.circle(x, y, r * (1.0 - k * 0.18), Color(color.r, color.g, color.b, 0.12 + k * 0.06))


func _flame(c: PixelCanvas, x: float, y: float, s: float, color: Color) -> void:
	c.ellipse(x, y, 14 * s, 18 * s, color)
	c.tri(Vector2(x - 13 * s, y + 4 * s), Vector2(x + 13 * s, y + 4 * s), Vector2(x + 2 * s, y + 40 * s), color)


func _bars(c: PixelCanvas, color: Color) -> void:
	for i in 5:
		outlined(func(o): c.rect(40 + i * 20 - o, 32, 46 + i * 20 + o, 128, col(o, color)), 2.0)
	outlined(func(o): c.rect(34, 120 - o, 126, 128 + o, col(o, color)), 2.0)
	outlined(func(o): c.rect(34, 32 - o, 126, 40 + o, col(o, color)), 2.0)


func _card(id: String, draw: Callable) -> void:
	var c := PixelCanvas.new(160, 160)
	draw.call(c)
	save(c, "cards/%s.png" % id)


func _cards() -> void:
	_card("fireball", func(c):
		_glow(c, 70, 70, 50, ORANGE)
		_flame(c, 76, 76, 1.6, ORANGE)
		c.circle(70, 66, 26, ORANGE)
		c.circle(66, 62, 15, YELLOW))
	_card("fire_blast", func(c):
		_glow(c, 80, 80, 70, ORANGE)
		for k in 10:
			var a := k * TAU / 10.0
			c.tri(Vector2(80, 80) + Vector2(cos(a + 0.25), sin(a + 0.25)) * 18, Vector2(80, 80) + Vector2(cos(a - 0.25), sin(a - 0.25)) * 18,
				Vector2(80, 80) + Vector2(cos(a), sin(a)) * 72, ORANGE if k % 2 == 0 else RED)
		c.circle(80, 80, 28, YELLOW)
		c.circle(80, 80, 14, WHITE))
	_card("meteor", func(c):
		for k in 5:
			c.line(Vector2(60 - k * 4, 60 + k * 4), Vector2(140 - k * 6, 140 - k * 2), 10 - k, Color(1, 0.5 + k * 0.08, 0.2, 0.5))
		_glow(c, 58, 58, 40, ORANGE)
		outlined(func(o): c.circle(56, 56, 26 + o, col(o, Color8(120, 80, 60))))
		c.circle(48, 64, 6, Color8(80, 50, 40))
		c.circle(64, 46, 5, Color8(80, 50, 40)))
	_card("dragon_breath", func(c):
		c.quad(Vector2(30, 80), Vector2(150, 140), Vector2(155, 80), Vector2(150, 20), Color(1, 0.45, 0.15, 0.8))
		c.quad(Vector2(30, 80), Vector2(150, 115), Vector2(155, 80), Vector2(150, 45), Color(1, 0.8, 0.3, 0.9))
		outlined(func(o): c.ellipse(30, 80, 24 + o, 18 + o, col(o, RED)))
		c.tri(Vector2(16, 92), Vector2(28, 96), Vector2(8, 120), RED)
		c.circle(26, 86, 4, YELLOW))
	_card("ice_prison", func(c):
		_glow(c, 80, 80, 60, ICE)
		outlined(func(o): c.quad(Vector2(80, 130 + o), Vector2(112 + o, 80), Vector2(80, 30 - o), Vector2(48 - o, 80), col(o, ICE)))
		c.quad(Vector2(80, 120), Vector2(96, 80), Vector2(80, 40), Vector2(64, 80), Color(1, 1, 1, 0.6))
		_bars(c, Color8(200, 235, 255)))
	_card("shadow_prison", func(c):
		_glow(c, 80, 80, 60, PURPLE)
		c.circle(80, 80, 32, DARK)
		c.ellipse(70, 84, 6, 4, Color8(255, 80, 120))
		c.ellipse(90, 84, 6, 4, Color8(255, 80, 120))
		_bars(c, PURPLE))
	_card("dimensional_prison", func(c):
		for k in 6:
			c.ellipse(80, 80, 70 - k * 10, 60 - k * 9, PURPLE.lerp(ICE, k / 5.0) * Color(1, 1, 1, 0.55))
		c.circle(80, 80, 12, WHITE)
		_bars(c, Color8(220, 200, 255)))
	_card("banish", func(c):
		for k in 7:
			var col2 := PURPLE.lerp(DARK, k / 6.0)
			c.ellipse(80 + sin(k) * 4, 80 + cos(k) * 3, 66 - k * 9, 66 - k * 9, col2)
		c.circle(80, 80, 8, Color8(255, 200, 255)))
	_card("sleep", func(c):
		_glow(c, 70, 80, 50, YELLOW)
		c.circle(70, 80, 40, YELLOW)
		c.circle(88, 92, 36, Color(0, 0, 0, 0))
		c.circle(90, 94, 34, Color8(40, 25, 70))
		for z in [[110, 120, 14.0], [128, 140, 10.0]]:
			var x: float = z[0]
			var y: float = z[1]
			var s: float = z[2]
			c.rect(x - s, y + s - 3, x + s, y + s, WHITE)
			c.rect(x - s, y - s, x + s, y - s + 3, WHITE)
			c.line(Vector2(x + s - 2, y + s - 2), Vector2(x - s + 2, y - s + 2), 3, WHITE))
	_card("silence", func(c):
		_glow(c, 80, 80, 60, Color8(255, 120, 170))
		outlined(func(o): c.ellipse(80, 76, 40 + o, 18 + o, col(o, Color8(230, 90, 130))))
		c.rect(46, 74, 114, 78, Color8(120, 30, 60))
		c.line(Vector2(36, 36), Vector2(124, 120), 10, WHITE)
		c.line(Vector2(36, 120), Vector2(124, 36), 10, WHITE))
	_card("heal", func(c):
		_glow(c, 80, 80, 66, GREEN)
		outlined(func(o): c.round_rect(64 - o, 30 - o, 96 + o, 130 + o, 8, col(o, GREEN)))
		outlined(func(o): c.round_rect(30 - o, 64 - o, 130 + o, 96 + o, 8, col(o, GREEN)))
		c.round_rect(70, 36, 90, 124, 6, Color8(200, 255, 210)))
	_card("holy_shield", func(c):
		_glow(c, 80, 84, 70, GOLDC)
		outlined(func(o): c.round_rect(40 - o, 70 - o, 120 + o, 130 + o, 14, col(o, GOLDC)))
		outlined(func(o): c.tri(Vector2(40 - o, 74), Vector2(120 + o, 74), Vector2(80, 22 - o), col(o, GOLDC)))
		c.rect(74, 44, 86, 118, WHITE)
		c.rect(56, 92, 104, 104, WHITE))
	_card("lucky_day", func(c):
		_glow(c, 80, 80, 60, GREEN)
		for p in [Vector2(-20, 0), Vector2(20, 0), Vector2(0, 20), Vector2(0, -20)]:
			outlined(func(o): c.circle(80 + p.x, 86 + p.y, 20 + o, col(o, GREEN)))
		c.circle(80, 86, 8, Color8(40, 140, 60))
		c.line(Vector2(80, 60), Vector2(92, 26), 5, Color8(40, 140, 60))
		_star(c, Vector2(124, 128), 14, YELLOW))
	_card("time_stop", func(c):
		_glow(c, 80, 80, 66, ICE)
		outlined(func(o): c.circle(80, 80, 50 + o, col(o, Color8(240, 240, 255))))
		for k in 12:
			var a := k * TAU / 12.0
			c.circle(80 + cos(a) * 40, 80 + sin(a) * 40, 3, DARK)
		c.line(Vector2(80, 80), Vector2(80, 116), 6, DARK)
		c.line(Vector2(80, 80), Vector2(106, 80), 5, DARK)
		c.circle(80, 80, 6, RED))
	_card("shadow_execution", func(c):
		_glow(c, 80, 80, 66, PURPLE)
		outlined(func(o): c.quad(Vector2(30 - o, 30), Vector2(40, 22 - o), Vector2(132 + o, 124), Vector2(124, 132 + o), col(o, Color8(60, 30, 90))))
		c.line(Vector2(36, 32), Vector2(126, 124), 3, Color8(200, 160, 255))
		c.line(Vector2(30, 120), Vector2(130, 40), 8, Color(1, 0.2, 0.3, 0.85)))
	_card("dragons_wrath", func(c):
		_glow(c, 80, 80, 74, RED)
		for k in 6:
			_flame(c, 30 + k * 20, 34 + (k % 2) * 8, 0.9, ORANGE if k % 2 == 0 else RED)
		outlined(func(o): c.ellipse(80, 86, 50 + o, 30 + o, col(o, YELLOW)))
		c.ellipse(80, 86, 10, 28, Color8(30, 10, 10))
		c.circle(70, 96, 6, WHITE))


func _essences() -> void:
	var colors := {"fire": Color8(255, 120, 50), "ice": Color8(120, 210, 255), "shadow": Color8(160, 90, 230),
		"light": Color8(255, 235, 140), "dragon": Color8(220, 60, 60)}
	for key in colors:
		var c := PixelCanvas.new(72, 72)
		var color: Color = colors[key]
		c.circle(36, 36, 30, Color(color.r, color.g, color.b, 0.2))
		outlined(func(o): c.quad(Vector2(36, 64 + o), Vector2(58 + o, 36), Vector2(36, 8 - o), Vector2(14 - o, 36), col(o, color)), 3.0)
		c.quad(Vector2(36, 58), Vector2(48, 36), Vector2(36, 30), Vector2(24, 36), color.lightened(0.45))
		c.circle(30, 46, 4, Color(1, 1, 1, 0.8))
		save(c, "cards/essence_%s.png" % key)
