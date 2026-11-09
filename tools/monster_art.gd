class_name MonsterArt
## Phase 5 monsters (placeholder art, facing RIGHT; the battle flips them to face the princess).
## Ice Wisp, Frost Golem, Lich Queen, Imp, Werewolf, Night Witch, Wyvern, Drake, Elder Wyrm.

const OUTLINE := Color8(28, 14, 38)
const WHITE := Color.WHITE

static var g


static func generate_all(generator) -> void:
	g = generator
	_wisp()
	_golem()
	_lich()
	_imp()
	_werewolf()
	_witch()
	_dragon("wyvern", 200, 170, Color8(90, 140, 90), Color8(200, 220, 140), 0.75, false)
	_dragon("drake", 250, 210, Color8(170, 70, 40), Color8(250, 190, 90), 0.95, true)
	_dragon("elder_wyrm", 330, 290, Color8(120, 30, 40), Color8(255, 200, 80), 1.3, true)


static func o(draw: Callable, size := 3.0) -> void:
	g.outlined(draw, size)

static func col(w: float, c: Color) -> Color:
	return OUTLINE if w > 0.0 else c

static func eyes(c: PixelCanvas, x: float, y: float, gap: float, r: float, color: Color) -> void:
	for s in [-1.0, 1.0]:
		c.ellipse(x + s * gap, y, r, r * 1.2, OUTLINE)
		c.ellipse(x + s * gap, y, r * 0.7, r * 0.85, color)
		c.circle(x + s * gap + r * 0.25, y + r * 0.35, r * 0.25, WHITE)


static func _wisp() -> void:
	var c := PixelCanvas.new(140, 170)
	var body := Color8(150, 220, 255)
	c.circle(70, 100, 60, Color(0.6, 0.9, 1, 0.18))
	o(func(w): c.tri(Vector2(40 - w, 90), Vector2(100 + w, 90), Vector2(54, 18 - w), col(w, body)))
	o(func(w): c.circle(70, 100, 34 + w, col(w, body)))
	c.circle(60, 112, 10, Color(1, 1, 1, 0.6))
	eyes(c, 74, 98, 11, 6, Color8(20, 60, 120))
	g.save(c, "monster_ice_wisp.png")


static func _golem() -> void:
	var c := PixelCanvas.new(220, 240)
	var rock := Color8(140, 180, 210)
	o(func(w): c.round_rect(70 - w, 4 - w, 100 + w, 70 + w, 8, col(w, rock.darkened(0.2))))
	o(func(w): c.round_rect(120 - w, 4 - w, 150 + w, 70 + w, 8, col(w, rock.darkened(0.2))))
	o(func(w): c.round_rect(50 - w, 60 - w, 170 + w, 170 + w, 18, col(w, rock)))
	o(func(w): c.round_rect(14 - w, 80 - w, 54 + w, 170 + w, 14, col(w, rock.darkened(0.1))))
	o(func(w): c.round_rect(166 - w, 80 - w, 206 + w, 170 + w, 14, col(w, rock.darkened(0.1))))
	o(func(w): c.round_rect(76 - w, 160 - w, 150 + w, 226 + w, 14, col(w, rock.lightened(0.1))))
	for k in 4:
		c.tri(Vector2(70 + k * 26, 170), Vector2(86 + k * 26, 170), Vector2(78 + k * 26, 196), Color8(220, 245, 255))
	c.rect(90, 186, 136, 196, Color8(60, 200, 255))
	c.circle(112, 115, 14, Color8(60, 200, 255))
	g.save(c, "monster_frost_golem.png")


static func _lich() -> void:
	var c := PixelCanvas.new(210, 270)
	var robe := Color8(70, 40, 110)
	var bone := Color8(235, 230, 215)
	o(func(w): c.rect(166 - w, 6, 174 + w, 230 + w, col(w, Color8(60, 40, 50))))
	c.circle(170, 236, 18, Color(0.6, 1, 0.8, 0.3))
	o(func(w): c.circle(170, 236, 11 + w, col(w, Color8(120, 255, 200))))
	o(func(w): c.tri(Vector2(30 - w, 6 - w), Vector2(160 + w, 6 - w), Vector2(95, 190 + w), col(w, robe)))
	c.tri(Vector2(60, 6), Vector2(130, 6), Vector2(95, 120), robe.lightened(0.2))
	o(func(w): c.ellipse(95, 196, 32 + w, 30 + w, col(w, bone)))
	c.ellipse(83, 198, 8, 10, OUTLINE)
	c.ellipse(107, 198, 8, 10, OUTLINE)
	c.circle(83, 197, 3, Color8(120, 255, 200))
	c.circle(107, 197, 3, Color8(120, 255, 200))
	var gold := Color8(255, 210, 90)
	o(func(w): c.rect(70 - w, 220 - w, 120 + w, 228 + w, col(w, gold)), 2.0)
	for k in 3:
		c.tri(Vector2(72 + k * 18, 227), Vector2(86 + k * 18, 227), Vector2(79 + k * 18, 250), gold)
	g.save(c, "monster_lich_queen.png")


static func _imp() -> void:
	var c := PixelCanvas.new(150, 160)
	var red := Color8(220, 70, 60)
	o(func(w): c.tri(Vector2(40, 70), Vector2(4 - w, 110 + w), Vector2(30, 120 + w), col(w, red.darkened(0.3))))
	o(func(w): c.tri(Vector2(110, 70), Vector2(146 + w, 110 + w), Vector2(120, 120 + w), col(w, red.darkened(0.3))))
	o(func(w): c.ellipse(75, 50, 30 + w, 36 + w, col(w, red)))
	o(func(w): c.circle(75, 104, 30 + w, col(w, red)))
	for s in [-1.0, 1.0]:
		c.tri(Vector2(75 + s * 14, 124), Vector2(75 + s * 26, 120), Vector2(75 + s * 30, 152), Color8(255, 220, 160))
	eyes(c, 80, 106, 11, 6, Color8(255, 230, 80))
	c.line(Vector2(66, 90), Vector2(92, 92), 3, OUTLINE)
	c.line(Vector2(104, 30), Vector2(140, 10), 3, red.darkened(0.2))
	c.tri(Vector2(136, 4), Vector2(146, 16), Vector2(134, 18), red.darkened(0.2))
	g.save(c, "monster_imp.png")


static func _werewolf() -> void:
	var c := PixelCanvas.new(210, 250)
	var fur := Color8(110, 100, 120)
	o(func(w): c.round_rect(60 - w, 6 - w, 150 + w, 150 + w, 30, col(w, fur)))
	c.round_rect(80, 30, 130, 130, 20, fur.lightened(0.2))
	for s in [-1.0, 1.0]:
		o(func(w): c.ellipse(105 + s * 52, 100, 14 + w, 44 + w, col(w, fur.darkened(0.1))))
		for k in 3:
			c.tri(Vector2(105 + s * 52 - 8 + k * 6, 60), Vector2(105 + s * 52 - 4 + k * 6, 60), Vector2(105 + s * 52 - 6 + k * 6, 44), WHITE)
	o(func(w): c.ellipse(105, 180, 46 + w, 42 + w, col(w, fur)))
	o(func(w): c.ellipse(148, 170, 24 + w, 16 + w, col(w, fur.lightened(0.15))))
	c.circle(168, 172, 6, OUTLINE)
	for s in [-1.0, 1.0]:
		o(func(w): c.tri(Vector2(105 + s * 20, 212), Vector2(105 + s * 40, 208), Vector2(105 + s * 36, 246 + w), col(w, fur)))
	c.ellipse(116, 190, 8, 6, Color8(255, 200, 60))
	c.circle(118, 190, 3, OUTLINE)
	for k in 3:
		c.tri(Vector2(138 + k * 8, 160), Vector2(144 + k * 8, 160), Vector2(141 + k * 8, 150), WHITE)
	g.save(c, "monster_werewolf.png")


static func _witch() -> void:
	var c := PixelCanvas.new(200, 270)
	var robe := Color8(40, 30, 60)
	var skin := Color8(150, 210, 140)
	o(func(w): c.tri(Vector2(20 - w, 6 - w), Vector2(170 + w, 6 - w), Vector2(95, 170 + w), col(w, robe)))
	o(func(w): c.circle(95, 170, 32 + w, col(w, skin)))
	eyes(c, 100, 172, 11, 6, Color8(255, 80, 200))
	c.line(Vector2(84, 154), Vector2(108, 152), 3, OUTLINE)
	o(func(w): c.ellipse(95, 196, 70 + w, 12 + w, col(w, robe)))
	o(func(w): c.quad(Vector2(60 - w, 198), Vector2(130 + w, 198), Vector2(120, 250 + w), Vector2(140 + w, 266 + w), col(w, robe)))
	c.rect(64, 200, 128, 208, Color8(200, 60, 200))
	o(func(w): c.rect(176 - w, 20, 184 + w, 200 + w, col(w, Color8(100, 70, 50))))
	c.circle(180, 206, 14, Color(1, 0.4, 0.9, 0.35))
	o(func(w): c.circle(180, 206, 8 + w, col(w, Color8(255, 120, 230))))
	g.save(c, "monster_night_witch.png")


static func _dragon(id: String, w: int, h: int, body: Color, belly: Color, s: float, horns: bool) -> void:
	var c := PixelCanvas.new(w, h)
	var cx := w * 0.45
	var base := 10.0
	# wings
	o(func(ww): c.tri(Vector2(cx - 10 * s, base + 110 * s), Vector2(cx - 90 * s - ww, base + 160 * s + ww), Vector2(cx + 30 * s, base + 170 * s + ww), col(ww, body.darkened(0.3))))
	c.tri(Vector2(cx - 5 * s, base + 112 * s), Vector2(cx - 70 * s, base + 152 * s), Vector2(cx + 20 * s, base + 160 * s), belly * Color(1, 1, 1, 0.35))
	# tail
	o(func(ww): c.quad(Vector2(cx - 40 * s, base + 30 * s), Vector2(cx - 20 * s, base + 50 * s), Vector2(cx - 110 * s - ww, base + 20 * s), Vector2(cx - 100 * s, base + 2 * s - ww), col(ww, body)))
	# body
	o(func(ww): c.ellipse(cx, base + 60 * s, 58 * s + ww, 48 * s + ww, col(ww, body)))
	c.ellipse(cx + 10 * s, base + 52 * s, 34 * s, 34 * s, belly)
	# legs
	for k in [-1.0, 1.0]:
		o(func(ww): c.round_rect(cx + k * 30 * s - 12 * s - ww, base - ww, cx + k * 30 * s + 12 * s + ww, base + 40 * s, 6, col(ww, body.darkened(0.15))))
	# neck + head
	o(func(ww): c.quad(Vector2(cx + 30 * s, base + 70 * s), Vector2(cx + 54 * s, base + 90 * s), Vector2(cx + 80 * s + ww, base + 150 * s), Vector2(cx + 56 * s - ww, base + 150 * s), col(ww, body)))
	o(func(ww): c.ellipse(cx + 82 * s, base + 160 * s, 34 * s + ww, 24 * s + ww, col(ww, body)))
	o(func(ww): c.ellipse(cx + 110 * s, base + 152 * s, 22 * s + ww, 14 * s + ww, col(ww, body.lightened(0.1))))
	c.ellipse(cx + 90 * s, base + 166 * s, 8 * s, 6 * s, Color8(255, 220, 60))
	c.circle(cx + 92 * s, base + 166 * s, 3 * s, OUTLINE)
	for k in 3:
		c.tri(Vector2(cx + (104 + k * 9) * s, base + 142 * s), Vector2(cx + (110 + k * 9) * s, base + 142 * s), Vector2(cx + (107 + k * 9) * s, base + 134 * s), WHITE)
	if horns:
		for k in [0.0, 14.0]:
			o(func(ww): c.tri(Vector2(cx + (70 + k) * s, base + 178 * s), Vector2(cx + (80 + k) * s, base + 180 * s), Vector2(cx + (60 + k) * s - ww, base + 210 * s + ww), col(ww, Color8(240, 230, 200))), 2.0)
	g.save(c, "monster_%s.png" % id)
