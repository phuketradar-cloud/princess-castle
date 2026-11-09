class_name CastleArt
## Phase 4 placeholder art: 5 princess bodies (no face), face layers per princess
## (eyes / brows / mouth variants), props, furniture, room backgrounds, castle overview,
## starter weapons and furniture material icons. Called from tools/generate_art.gd.

const OUT := "res://assets/art/"
const OUTLINE := Color8(28, 14, 38)
const SKIN := Color8(255, 226, 214)
const CX := 86.0
const HY := 168.0
const FACE_ANCHOR := Vector2(86, 168)

## id, dress, hair, eyes, hair style
const PRINCESSES := [
	["sword_princess", Color8(150, 40, 90), Color8(70, 40, 110), Color8(255, 120, 160), "twintails"],
	["magic_princess", Color8(45, 75, 160), Color8(225, 225, 245), Color8(110, 190, 255), "long"],
	["shadow_princess", Color8(45, 32, 60), Color8(32, 26, 44), Color8(220, 60, 100), "bob"],
	["light_princess", Color8(245, 232, 205), Color8(255, 215, 120), Color8(90, 175, 120), "wavy"],
	["dragon_princess", Color8(175, 45, 35), Color8(240, 120, 50), Color8(255, 200, 60), "dragon"],
]

static var g # the generator (for outlined / col / save helpers)


static func generate_all(generator) -> void:
	g = generator
	for d in ["princesses", "furniture", "rooms", "materials", "props"]:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT + d))
	for p in PRINCESSES:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT + "princesses/" + p[0]))
		_body(p[0], p[1], p[2], p[4])
		_faces(p[0], p[2], p[3])
	_mouths()
	_props()
	_furniture()
	_rooms()
	_castle_bg()
	_starter_weapons()
	_materials()


static func o(draw: Callable, size := 3.0) -> void:
	g.outlined(draw, size)

static func col(w: float, c: Color) -> Color:
	return OUTLINE if w > 0.0 else c

static func save(c: PixelCanvas, file: String) -> void:
	g.save(c, file)


# ------------------------------------------------------------ bodies (no face)

static func _body(id: String, dress: Color, hair: Color, style: String) -> void:
	var c := PixelCanvas.new(180, 230)
	# hair behind
	match style:
		"twintails":
			o(func(w): c.ellipse(CX - 46, 135, 16 + w, 40 + w, col(w, hair)))
			o(func(w): c.ellipse(CX + 46, 135, 16 + w, 40 + w, col(w, hair)))
		"long":
			o(func(w): c.round_rect(CX - 44 - w, 70 - w, CX + 44 + w, 180 + w, 24, col(w, hair)))
		"wavy":
			for k in 5:
				o(func(w): c.circle(CX - 40 + (k % 2) * 4, 165 - k * 22, 18 + w, col(w, hair)))
				o(func(w): c.circle(CX + 40 - (k % 2) * 4, 165 - k * 22, 18 + w, col(w, hair)))
		"dragon":
			# tail
			o(func(w): c.quad(Vector2(CX + 20, 30), Vector2(CX + 30, 50), Vector2(CX + 78 + w, 20), Vector2(CX + 70, 6 - w), col(w, Color8(200, 60, 40))))
			c.tri(Vector2(CX + 66, 4), Vector2(CX + 86, 22), Vector2(CX + 90, 2), Color8(255, 170, 60))
	# skirt + bodice
	o(func(w): c.quad(Vector2(CX - 52 - w, 8 - w), Vector2(CX + 52 + w, 8 - w), Vector2(CX + 20 + w, 110 + w), Vector2(CX - 20 - w, 110 + w), col(w, dress)))
	c.quad(Vector2(CX - 46, 8), Vector2(CX + 46, 8), Vector2(CX + 40, 22), Vector2(CX - 40, 22), dress.darkened(0.35))
	for i in range(-2, 3):
		c.circle(CX + i * 18, 15, 5, dress.lightened(0.3))
	o(func(w): c.round_rect(CX - 20 - w, 92 - w, CX + 20 + w, 132 + w, 8, col(w, dress)))
	c.tri(Vector2(CX - 8, 128), Vector2(CX + 8, 128), Vector2(CX, 112), dress.lightened(0.45))
	# arms
	o(func(w): c.ellipse(CX - 26, 108, 8 + w, 18 + w, col(w, SKIN)))
	o(func(w): c.ellipse(CX + 28, 108, 8 + w, 18 + w, col(w, SKIN)))
	# head
	o(func(w): c.circle(CX, HY, 42 + w, col(w, hair)))
	c.ellipse(CX, HY - 6, 36, 33, SKIN)
	c.ellipse(CX - 24, HY - 20, 6, 3.5, Color8(255, 150, 170, 150))
	c.ellipse(CX + 24, HY - 20, 6, 3.5, Color8(255, 150, 170, 150))
	# bangs
	match style:
		"bob":
			c.ellipse(CX, HY + 24, 38, 14, hair)
			c.tri(Vector2(CX - 38, HY + 20), Vector2(CX - 20, HY + 20), Vector2(CX - 36, HY - 30), hair)
			c.tri(Vector2(CX + 38, HY + 20), Vector2(CX + 20, HY + 20), Vector2(CX + 36, HY - 30), hair)
		"long", "wavy":
			c.ellipse(CX - 14, HY + 22, 24, 14, hair)
			c.ellipse(CX + 14, HY + 22, 24, 14, hair)
			c.rect(CX - 38, HY - 30, CX - 30, HY + 18, hair)
			c.rect(CX + 30, HY - 30, CX + 38, HY + 18, hair)
		"dragon":
			c.ellipse(CX - 10, HY + 22, 26, 13, hair)
			c.ellipse(CX + 16, HY + 20, 22, 14, hair)
			for s in [-1.0, 1.0]:
				o(func(w): c.tri(Vector2(CX + s * 22, HY + 30), Vector2(CX + s * 34, HY + 26), Vector2(CX + s * (40 + w), HY + 62 + w), col(w, Color8(255, 235, 200))), 2.0)
		_:
			c.ellipse(CX - 12, HY + 22, 26, 14, hair)
			c.ellipse(CX + 16, HY + 20, 22, 14, hair)
			c.tri(Vector2(CX - 4, HY + 30), Vector2(CX + 8, HY + 30), Vector2(CX + 2, HY + 6), hair)
	save(c, "princesses/%s/body.png" % id)


# ------------------------------------------------------------ faces (layers centred on FACE_ANCHOR)

static func face_canvas() -> PixelCanvas:
	var c := PixelCanvas.new(100, 90)
	c.origin = Vector2(50, 45) - FACE_ANCHOR
	return c


## Thick arc along an ellipse from angle a0 to a1 (radians, y-up).
static func arc(c: PixelCanvas, center: Vector2, rx: float, ry: float, a0: float, a1: float, thick: float, color: Color) -> void:
	var steps := 18
	for i in steps + 1:
		var t := lerpf(a0, a1, float(i) / steps)
		c.circle(center.x + cos(t) * rx, center.y + sin(t) * ry, thick * 0.5, color)


static func _eye(c: PixelCanvas, x: float, y: float, iris: Color, kind: String, side: float) -> void:
	match kind:
		"closed":
			arc(c, Vector2(x, y + 2), 7, 4, PI, TAU, 2.6, OUTLINE)
		"happy":
			arc(c, Vector2(x, y - 4), 7, 6, 0, PI, 2.8, OUTLINE)
		"surprised":
			c.ellipse(x, y, 9, 12, OUTLINE)
			c.ellipse(x, y, 7, 10, Color.WHITE)
			c.circle(x, y - 1, 4, iris)
			c.circle(x + 1.5, y + 1.5, 1.5, Color.WHITE)
		"fear":
			c.ellipse(x, y, 8, 11, OUTLINE)
			c.ellipse(x, y, 6, 9, Color.WHITE)
			c.circle(x, y - 2, 2.2, iris.darkened(0.3))
		"curious":
			if side > 0:
				c.ellipse(x, y, 8, 8, OUTLINE)
				c.ellipse(x, y - 1, 6, 6, iris)
				c.circle(x + 2, y + 2, 2, Color.WHITE)
			else:
				_eye(c, x, y, iris, "normal", side)
		"sly":
			_eye(c, x, y, iris, "normal", side)
			c.rect(x - 9, y + 1, x + 9, y + 13, SKIN)
			c.line(Vector2(x - 8, y + 1), Vector2(x + 8, y + 2), 2.4, OUTLINE)
		"angry":
			_eye(c, x, y, iris, "normal", side)
			c.tri(Vector2(x - 10, y + 13), Vector2(x + 10, y + 13), Vector2(x - side * 10, y + 2), SKIN)
			c.line(Vector2(x - 9, y + 4 + side * 4), Vector2(x + 9, y + 4 - side * 4), 2.4, OUTLINE)
		"crying":
			_eye(c, x, y, iris, "normal", side)
			c.rect(x - 2, y - 30, x + 2, y - 9, Color(0.5, 0.75, 1, 0.85))
			c.circle(x, y - 30, 3, Color(0.5, 0.75, 1, 0.85))
		_:
			c.ellipse(x, y, 8, 11, OUTLINE)
			c.ellipse(x, y - 2, 6, 8, iris)
			c.circle(x + 2.5, y + 4, 3, Color.WHITE)
			c.circle(x - 2, y - 4, 1.4, Color.WHITE)


static func _brow(c: PixelCanvas, x: float, y: float, color: Color, kind: String, side: float) -> void:
	# side: -1 left eye, +1 right eye; "inner" end is toward the face centre.
	var outer := Vector2(x + side * 8, y)
	var inner := Vector2(x - side * 6, y)
	match kind:
		"raised":
			outer.y += 6; inner.y += 6
		"worried":
			inner.y += 5; outer.y -= 1
		"angry":
			inner.y -= 4; outer.y += 3
		"tilted":
			if side > 0:
				outer.y += 6; inner.y += 4
			else:
				outer.y -= 1
	c.line(outer, inner, 3.2, color)


static func _faces(id: String, hair: Color, iris: Color) -> void:
	var brow_col := hair.darkened(0.45)
	for kind in ["normal", "closed", "happy", "surprised", "curious", "fear", "crying", "angry", "sly"]:
		var c := face_canvas()
		_eye(c, CX - 14, HY - 8, iris, kind, -1.0)
		_eye(c, CX + 14, HY - 8, iris, kind, 1.0)
		save(c, "princesses/%s/eyes_%s.png" % [id, kind])
	for kind in ["normal", "raised", "worried", "angry", "tilted"]:
		var c := face_canvas()
		_brow(c, CX - 14, HY + 7, brow_col, kind, -1.0)
		_brow(c, CX + 14, HY + 7, brow_col, kind, 1.0)
		save(c, "princesses/%s/brows_%s.png" % [id, kind])


## Mouths are shared by all princesses (copied into each folder for a uniform layout).
static func _mouths() -> void:
	var lip := Color8(150, 60, 80)
	var shapes := {
		"smile": func(c): arc(c, Vector2(CX, HY - 19), 5, 3, PI, TAU, 2.2, lip),
		"open_smile": func(c):
			c.ellipse(CX, HY - 22, 7, 5, lip)
			c.rect(CX - 7, HY - 22, CX + 7, HY - 16, SKIN)
			c.ellipse(CX, HY - 25, 3.5, 2, Color8(255, 130, 140)),
		"o": func(c):
			c.ellipse(CX, HY - 22, 4, 5, lip)
			c.ellipse(CX, HY - 22, 2, 3, Color8(90, 30, 40)),
		"small": func(c): c.rect(CX - 3, HY - 22, CX + 3, HY - 20, lip),
		"frown": func(c): arc(c, Vector2(CX, HY - 25), 5, 3, 0, PI, 2.2, lip),
		"wavy": func(c):
			for i in 4:
				c.line(Vector2(CX - 7 + i * 4, HY - 21 + (i % 2) * 2), Vector2(CX - 3 + i * 4, HY - 21 + ((i + 1) % 2) * 2), 1.8, lip),
		"cry": func(c):
			c.ellipse(CX, HY - 23, 7, 4, lip)
			c.ellipse(CX, HY - 23, 5, 2.4, Color8(90, 30, 40)),
		"smirk": func(c):
			c.line(Vector2(CX - 5, HY - 21), Vector2(CX + 3, HY - 21), 2.0, lip)
			c.line(Vector2(CX + 3, HY - 21), Vector2(CX + 7, HY - 18), 2.0, lip),
		"neutral": func(c): c.rect(CX - 4, HY - 21, CX + 4, HY - 19.5, lip),
	}
	for kind in shapes:
		var c := face_canvas()
		shapes[kind].call(c)
		for p in PRINCESSES:
			save(c, "princesses/%s/mouth_%s.png" % [p[0], kind])


# ------------------------------------------------------------ props (centred on their anchor)

static func _props() -> void:
	# Book held at the chest (anchor 86,104)
	var c := PixelCanvas.new(80, 70)
	c.origin = Vector2(40, 35) - Vector2(86, 104)
	o(func(w): c.quad(Vector2(60 - w, 92 - w), Vector2(86, 96 - w), Vector2(86, 122 + w), Vector2(62 - w, 118 + w), col(w, Color8(120, 50, 70))), 2.0)
	o(func(w): c.quad(Vector2(112 + w, 92 - w), Vector2(86, 96 - w), Vector2(86, 122 + w), Vector2(110 + w, 118 + w), col(w, Color8(140, 60, 80))), 2.0)
	c.quad(Vector2(64, 96), Vector2(85, 99), Vector2(85, 118), Vector2(66, 115), Color8(250, 240, 220))
	c.quad(Vector2(108, 96), Vector2(87, 99), Vector2(87, 118), Vector2(106, 115), Color8(250, 240, 220))
	save(c, "props/book.png")
	# Teacup near the front hand (anchor 108,126)
	c = PixelCanvas.new(60, 50)
	c.origin = Vector2(30, 25) - Vector2(108, 126)
	c.ellipse(108, 112, 18, 4, Color8(240, 240, 250))
	o(func(w): c.round_rect(96 - w, 114 - w, 120 + w, 134 + w, 8, col(w, Color8(250, 250, 255))), 2.0)
	o(func(w): c.ellipse(124, 126, 5 + w, 6 + w, col(w, Color(0, 0, 0, 0))), 2.0)
	c.ellipse(108, 132, 10, 2.5, Color8(170, 100, 60))
	c.rect(98, 120, 118, 123, Color8(230, 120, 160))
	for k in 3:
		c.circle(102 + k * 6, 140 + k * 3, 2.5, Color(1, 1, 1, 0.35))
	save(c, "props/teacup.png")
	# Zzz bubble
	c = PixelCanvas.new(60, 60)
	for z in [[18.0, 18.0, 8.0], [38.0, 38.0, 11.0]]:
		var x: float = z[0]
		var y: float = z[1]
		var s: float = z[2]
		c.rect(x - s, y + s - 3, x + s, y + s, Color.WHITE)
		c.rect(x - s, y - s, x + s, y - s + 3, Color.WHITE)
		c.line(Vector2(x + s - 2, y + s - 2), Vector2(x - s + 2, y - s + 2), 3, Color.WHITE)
	save(c, "props/zzz.png")


# ------------------------------------------------------------ furniture (feet/floor at bottom centre)

static func _furniture() -> void:
	var wood := Color8(120, 75, 50)
	_bed("simple_bed", wood, Color8(200, 200, 215), Color8(150, 150, 170), false)
	_bed("lucky_bed", Color8(90, 140, 80), Color8(220, 245, 210), Color8(110, 200, 120), false, true)
	_bed("dragon_bed", Color8(150, 40, 30), Color8(255, 210, 160), Color8(200, 60, 40), false, false, true)
	_bed("pink_canopy_bed", Color8(230, 150, 190), Color8(255, 230, 240), Color8(240, 130, 180), true)
	_bed("starry_canopy_bed", Color8(60, 50, 120), Color8(200, 210, 255), Color8(80, 70, 170), true)
	# desks / tables (reading + tea)
	_desk("old_desk", wood, false, false)
	_desk("tea_set_table", Color8(240, 230, 245), false, true)
	_desk("frozen_library", Color8(150, 200, 235), true, false)
	# training
	_dummy("wooden_dummy", wood, Color8(200, 170, 120))
	_dummy("training_dummy", Color8(90, 60, 45), Color8(230, 80, 90))
	_rack("rose_training_hall")
	# decor
	_chair("plain_chair", wood)
	_mirror("shadow_mirror", Color8(60, 30, 90), Color8(140, 90, 200))
	_throne("light_throne")
	_wardrobe("velvet_wardrobe", Color8(120, 30, 70))
	_mirror("rose_vanity", Color8(230, 140, 170), Color8(255, 220, 230))


static func fcanvas(w: int, h: int) -> PixelCanvas:
	return PixelCanvas.new(w, h)


static func _bed(id: String, frame: Color, sheet: Color, blanket: Color, canopy: bool, clover := false, scales := false) -> void:
	var c := fcanvas(420, 300 if canopy else 220)
	var top := 130.0
	if canopy:
		o(func(w): c.rect(20 - w, 10, 34 + w, 290 + w, col(w, frame)))
		o(func(w): c.rect(386 - w, 10, 400 + w, 290 + w, col(w, frame)))
		o(func(w): c.round_rect(10 - w, 262 - w, 410 + w, 296 + w, 12, col(w, frame)))
		c.quad(Vector2(22, 262), Vector2(110, 262), Vector2(60, 120), Vector2(22, 150), blanket.lightened(0.3) * Color(1, 1, 1, 0.75))
		c.quad(Vector2(398, 262), Vector2(310, 262), Vector2(360, 120), Vector2(398, 150), blanket.lightened(0.3) * Color(1, 1, 1, 0.75))
	o(func(w): c.round_rect(30 - w, 8 - w, 390 + w, 70 + w, 10, col(w, frame)))
	o(func(w): c.round_rect(20 - w, 8 - w, 70 + w, top + w, 14, col(w, frame)))
	o(func(w): c.round_rect(360 - w, 8 - w, 400 + w, 100 + w, 12, col(w, frame)))
	o(func(w): c.round_rect(60 - w, 56 - w, 370 + w, 100 + w, 16, col(w, sheet)))
	o(func(w): c.round_rect(140 - w, 50 - w, 372 + w, 104 + w, 18, col(w, blanket)))
	o(func(w): c.ellipse(105, 102, 36 + w, 16 + w, col(w, Color.WHITE)))
	if clover:
		for p in [Vector2(-10, 0), Vector2(10, 0), Vector2(0, 10), Vector2(0, -10)]:
			c.circle(255 + p.x, 78 + p.y, 10, Color8(60, 170, 80))
	if scales:
		for k in 6:
			c.ellipse(170 + k * 34, 70, 14, 10, blanket.lightened(0.25))
			c.ellipse(170 + k * 34, 90, 14, 10, blanket.darkened(0.15))
	save(c, "furniture/%s.png" % id)


static func _desk(id: String, wood: Color, shelf: bool, tea: bool) -> void:
	var c := fcanvas(300, 300 if shelf else 220)
	if shelf:
		o(func(w): c.rect(20 - w, 120, 280 + w, 296 + w, col(w, wood.darkened(0.2))))
		for row in 3:
			for k in 9:
				var bc := Color.from_hsv(fmod(k * 0.13 + row * 0.3, 1.0), 0.5, 0.85)
				c.rect(32 + k * 27, 132 + row * 54, 52 + k * 27, 176 + row * 54, bc)
			c.rect(24, 128 + row * 54, 276, 132 + row * 54, wood.darkened(0.45))
		for k in 5:
			c.tri(Vector2(30 + k * 55, 296), Vector2(60 + k * 55, 296), Vector2(45 + k * 55, 270), Color(0.85, 0.95, 1, 0.85))
	o(func(w): c.round_rect(10 - w, 110 - w, 290 + w, 128 + w, 6, col(w, wood)))
	for x in [24.0, 262.0]:
		o(func(w): c.rect(x - w, 4, x + 14 + w, 112, col(w, wood.darkened(0.15))))
	if tea:
		o(func(w): c.ellipse(150, 140, 30 + w, 10 + w, col(w, Color8(250, 250, 255))), 2.0)
		o(func(w): c.round_rect(122 - w, 130 - w, 178 + w, 172 + w, 14, col(w, Color8(250, 240, 250))), 2.0)
		c.ellipse(150, 172, 8, 5, Color8(230, 120, 160))
		o(func(w): c.round_rect(206 - w, 128 - w, 228 + w, 146 + w, 6, col(w, Color8(255, 255, 255))), 2.0)
		o(func(w): c.round_rect(64 - w, 128 - w, 86 + w, 146 + w, 6, col(w, Color8(255, 255, 255))), 2.0)
	elif not shelf:
		o(func(w): c.quad(Vector2(170 - w, 128), Vector2(240 + w, 128), Vector2(236, 140 + w), Vector2(174, 140 + w), col(w, Color8(250, 240, 220))), 2.0)
		c.ellipse(80, 140, 10, 10, Color8(255, 210, 120, 220))
	save(c, "furniture/%s.png" % id)


static func _dummy(id: String, wood: Color, accent: Color) -> void:
	var c := fcanvas(220, 330)
	o(func(w): c.round_rect(60 - w, 4 - w, 160 + w, 24 + w, 8, col(w, wood)))
	o(func(w): c.rect(102 - w, 20, 118 + w, 210, col(w, wood)))
	o(func(w): c.round_rect(70 - w, 120 - w, 150 + w, 230 + w, 20, col(w, Color8(210, 180, 130))))
	o(func(w): c.rect(30 - w, 180 - w, 190 + w, 194 + w, col(w, wood)))
	o(func(w): c.circle(110, 270, 34 + w, col(w, Color8(210, 180, 130))))
	c.circle(110, 175, 18, accent)
	c.circle(110, 175, 8, Color.WHITE)
	save(c, "furniture/%s.png" % id)


static func _rack(id: String) -> void:
	var c := fcanvas(260, 330)
	var wood := Color8(110, 40, 50)
	o(func(w): c.rect(20 - w, 4, 36 + w, 300 + w, col(w, wood)))
	o(func(w): c.rect(224 - w, 4, 240 + w, 300 + w, col(w, wood)))
	o(func(w): c.round_rect(10 - w, 280 - w, 250 + w, 304 + w, 8, col(w, wood)))
	o(func(w): c.rect(20, 150 - w, 240, 164 + w, col(w, wood)))
	for k in 4:
		var x := 60 + k * 48.0
		o(func(w): c.rect(x - 4 - w, 60, x + 4 + w, 270 + w, col(w, Color8(210, 215, 230))))
		c.rect(x - 12, 150, x + 12, 158, Color8(255, 200, 90))
	c.circle(130, 300, 14, Color8(230, 60, 100))
	save(c, "furniture/%s.png" % id)


static func _chair(id: String, wood: Color) -> void:
	var c := fcanvas(200, 300)
	o(func(w): c.rect(40 - w, 4, 54 + w, 140, col(w, wood)))
	o(func(w): c.rect(146 - w, 4, 160 + w, 140, col(w, wood)))
	o(func(w): c.round_rect(30 - w, 120 - w, 170 + w, 150 + w, 8, col(w, Color8(170, 60, 80))))
	o(func(w): c.round_rect(40 - w, 150 - w, 160 + w, 290 + w, 16, col(w, wood)))
	c.round_rect(56, 166, 144, 270, 12, Color8(170, 60, 80))
	save(c, "furniture/%s.png" % id)


static func _mirror(id: String, frame: Color, glass: Color) -> void:
	var c := fcanvas(220, 330)
	o(func(w): c.round_rect(30 - w, 4 - w, 190 + w, 40 + w, 10, col(w, frame)))
	o(func(w): c.ellipse(110, 200, 80 + w, 120 + w, col(w, frame)))
	c.ellipse(110, 200, 64, 104, glass)
	c.ellipse(90, 230, 18, 40, Color(1, 1, 1, 0.35))
	c.circle(110, 318, 10, frame.lightened(0.3))
	save(c, "furniture/%s.png" % id)


static func _throne(id: String) -> void:
	var c := fcanvas(240, 340)
	var gold := Color8(250, 210, 100)
	o(func(w): c.round_rect(40 - w, 140 - w, 200 + w, 330 + w, 30, col(w, gold)))
	c.round_rect(64, 160, 176, 310, 20, Color8(255, 250, 235))
	for k in 3:
		c.tri(Vector2(70 + k * 50, 320), Vector2(90 + k * 50, 320), Vector2(80 + k * 50, 338), gold)
	o(func(w): c.round_rect(20 - w, 4 - w, 220 + w, 150 + w, 14, col(w, gold)))
	c.round_rect(40, 100, 200, 140, 10, Color8(255, 250, 235))
	c.circle(120, 250, 16, Color8(255, 255, 255))
	save(c, "furniture/%s.png" % id)


static func _wardrobe(id: String, color: Color) -> void:
	var c := fcanvas(230, 330)
	o(func(w): c.round_rect(14 - w, 4 - w, 216 + w, 326 + w, 16, col(w, color)))
	c.rect(113, 20, 117, 310, color.darkened(0.4))
	c.round_rect(30, 30, 104, 300, 10, color.lightened(0.15))
	c.round_rect(126, 30, 200, 300, 10, color.lightened(0.15))
	c.circle(100, 160, 6, Color8(255, 210, 90))
	c.circle(130, 160, 6, Color8(255, 210, 90))
	save(c, "furniture/%s.png" % id)


# ------------------------------------------------------------ rooms (480x270, window at x=160)

const WING_THEMES := [
	["sword_wing", Color8(70, 25, 45), Color8(120, 30, 60)],
	["magic_wing", Color8(25, 35, 75), Color8(60, 90, 170)],
	["shadow_wing", Color8(25, 18, 35), Color8(80, 50, 120)],
	["light_wing", Color8(90, 75, 55), Color8(220, 190, 120)],
	["dragon_wing", Color8(70, 25, 20), Color8(190, 80, 40)],
]

static func _rooms() -> void:
	for t in WING_THEMES:
		var c := PixelCanvas.new(480, 270)
		var wall: Color = t[1]
		var accent: Color = t[2]
		for y in 270:
			var tt := y / 270.0
			var colr := wall.lightened(0.15).lerp(wall.darkened(0.2), tt) if y > 110 else wall.darkened(0.45).lerp(wall.darkened(0.2), y / 110.0)
			for x in 480:
				c.blend(x, y, colr)
		# wallpaper pattern
		for k in 24:
			for r in 6:
				c.circle(10 + k * 20, 125 + r * 24, 2.2, accent * Color(1, 1, 1, 0.35))
		# window (moonlight)
		c.round_rect(130, 130, 190, 240, 26, Color8(30, 20, 50))
		c.round_rect(134, 134, 186, 236, 24, Color8(120, 110, 190))
		c.circle(170, 210, 10, Color8(250, 245, 220))
		c.rect(158, 134, 162, 236, Color8(30, 20, 50))
		c.rect(134, 180, 186, 184, Color8(30, 20, 50))
		c.quad(Vector2(134, 134), Vector2(186, 134), Vector2(240, 30), Vector2(120, 30), Color(0.8, 0.75, 1, 0.07))
		# curtains
		c.quad(Vector2(118, 120), Vector2(134, 120), Vector2(140, 250), Vector2(112, 250), accent)
		c.quad(Vector2(186, 120), Vector2(202, 120), Vector2(208, 250), Vector2(180, 250), accent)
		# skirting board + floor rug
		c.rect(0, 106, 480, 112, accent.darkened(0.3))
		c.ellipse(240, 40, 170, 28, accent * Color(1, 1, 1, 0.35))
		c.ellipse(240, 40, 158, 23, accent.darkened(0.3) * Color(1, 1, 1, 0.45))
		# wall emblem
		c.circle(370, 200, 22, accent.darkened(0.2))
		c.circle(370, 200, 14, accent.lightened(0.3))
		save(c, "rooms/%s.png" % t[0])


static func _castle_bg() -> void:
	var c := PixelCanvas.new(480, 270)
	for y in 270:
		var colr := Color8(20, 10, 35).lerp(Color8(80, 40, 110), y / 270.0)
		for x in 480:
			c.blend(x, y, colr)
	c.circle(390, 220, 24, Color8(250, 240, 210))
	c.circle(398, 226, 22, Color8(70, 38, 100))
	var rnd := RandomNumberGenerator.new()
	rnd.seed = 11
	for i in 70:
		c.circle(rnd.randf() * 480, 120 + rnd.randf() * 150, 0.7 + rnd.randf() * 0.8, Color(1, 0.95, 1, 0.6))
	var stone := Color8(45, 28, 65)
	c.rect(60, 0, 420, 120, stone)
	for k in 5:
		var x := 80 + k * 80.0
		var h := 150.0 + (20 if k == 2 else 0)
		c.rect(x - 22, 0, x + 22, h, stone.lightened(0.05))
		c.tri(Vector2(x - 30, h), Vector2(x + 30, h), Vector2(x, h + 60), stone.darkened(0.2))
		c.round_rect(x - 8, h - 50, x + 8, h - 20, 7, Color8(255, 210, 120, 200))
	c.rect(0, 0, 480, 22, Color8(25, 15, 35))
	save(c, "rooms/castle_overview.png")


# ------------------------------------------------------------ starter weapons & materials

static func _starter_weapons() -> void:
	g._sword("twin_dagger.png", Color8(190, 190, 210), Color8(80, 60, 110), 7, 46)
	# wand: thin stick + star gem
	var a := Vector2(114, 108)
	var c: PixelCanvas = g.canvas(96, 260, a)
	o(func(w): c.rect(a.x - 3 - w, a.y - 14 - w, a.x + 3 + w, a.y + 70 + w, col(w, Color8(200, 160, 110))))
	g._star(c, Vector2(a.x, a.y + 80), 11, Color8(140, 200, 255))
	save(c, "items/apprentice_wand.png")
	# staff: long + orb
	c = g.canvas(96, 300, a)
	o(func(w): c.rect(a.x - 3 - w, a.y - 70 - w, a.x + 3 + w, a.y + 100 + w, col(w, Color8(240, 230, 200))))
	c.circle(a.x, a.y + 110, 18, Color(1, 0.95, 0.6, 0.3))
	o(func(w): c.circle(a.x, a.y + 110, 11 + w, col(w, Color8(255, 240, 170))))
	save(c, "items/prayer_staff.png")
	# club: thick, scaly head
	c = g.canvas(110, 260, a)
	o(func(w): c.rect(a.x - 4 - w, a.y - 14 - w, a.x + 4 + w, a.y + 40 + w, col(w, Color8(120, 70, 50))))
	o(func(w): c.round_rect(a.x - 16 - w, a.y + 36 - w, a.x + 16 + w, a.y + 96 + w, 14, col(w, Color8(200, 70, 50))))
	for k in 3:
		c.ellipse(a.x, a.y + 48 + k * 16, 10, 6, Color8(240, 130, 70))
	save(c, "items/scale_club.png")


static func _materials() -> void:
	var defs := {
		"bone_fragment": Color8(235, 230, 215), "dragon_scale": Color8(220, 70, 50),
		"ice_crystal": Color8(150, 220, 255), "holy_fragment": Color8(255, 230, 140),
	}
	for key in defs:
		var c := PixelCanvas.new(72, 72)
		var colr: Color = defs[key]
		c.circle(36, 36, 30, colr * Color(1, 1, 1, 0.2))
		match key:
			"bone_fragment":
				o(func(w): c.round_rect(18 - w, 30 - w, 54 + w, 42 + w, 6, col(w, colr)))
				for p in [Vector2(18, 30), Vector2(18, 42), Vector2(54, 30), Vector2(54, 42)]:
					o(func(w): c.circle(p.x, p.y, 7 + w, col(w, colr)), 2.0)
			"dragon_scale":
				o(func(w): c.ellipse(36, 34, 20 + w, 24 + w, col(w, colr)))
				c.ellipse(36, 40, 12, 14, colr.lightened(0.3))
			"ice_crystal":
				o(func(w): c.quad(Vector2(36, 66 + w), Vector2(50 + w, 36), Vector2(36, 6 - w), Vector2(22 - w, 36), col(w, colr)))
				c.quad(Vector2(36, 58), Vector2(42, 36), Vector2(36, 16), Vector2(30, 36), Color(1, 1, 1, 0.6))
			"holy_fragment":
				o(func(w): c.tri(Vector2(16 - w, 14 - w), Vector2(56 + w, 14 - w), Vector2(36, 62 + w), col(w, colr)))
				c.rect(33, 24, 39, 50, Color.WHITE)
				c.rect(26, 38, 46, 44, Color.WHITE)
		save(c, "materials/%s.png" % key)
