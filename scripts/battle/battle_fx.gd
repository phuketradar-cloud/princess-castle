class_name BattleFx
## Code-only battle effects (no textures needed, work on web / mobile Compatibility renderer).
## Every effect is a short-lived node added to `parent` that frees itself.
##   BattleFx.slash(popups, pos, Color.WHITE)        sword arc on a hit
##   BattleFx.burst(popups, pos, BattleFx.FIRE, 18)   spark burst (elements / impacts)
##   BattleFx.ring(popups, pos, Color.CYAN)           expanding ring (shield, summon, phase)
##   BattleFx.rise(popups, pos, BattleFx.HEAL)        sparkles floating up (heal)

const HIT := Color(1, 0.95, 0.85)
const CRIT := Color(1, 0.8, 0.25)
const FIRE := Color(1, 0.5, 0.15)
const POISON := Color(0.55, 0.95, 0.3)
const ICE := Color(0.6, 0.9, 1.0)
const HEAL := Color(0.5, 1.0, 0.6)
const SHIELD := Color(0.55, 0.75, 1.0)
const SHADOW := Color(0.7, 0.45, 1.0)
const STUN := Color(1, 0.9, 0.3)
const SMOKE := Color(0.75, 0.7, 0.8)

## Effect colour for a status (used when it is applied or ticks).
static func status_color(status: int) -> Color:
	match status:
		CombatTypes.Status.BURN: return FIRE
		CombatTypes.Status.POISON: return POISON
		CombatTypes.Status.FREEZE: return ICE
		CombatTypes.Status.SHIELD: return SHIELD
		CombatTypes.Status.STUN: return STUN
		CombatTypes.Status.LUCKY: return CRIT
		_: return SHADOW


## Crescent sword arc that sweeps and fades. `size` ~ 1 for normal hits, bigger for crits.
static func slash(parent: Node, pos: Vector2, color: Color, size := 1.0) -> void:
	if parent == null:
		return
	var p := Polygon2D.new()
	var pts := PackedVector2Array()
	var r := 70.0 * size
	for i in 17: # outer arc
		var a := lerpf(-1.1, 1.1, i / 16.0)
		pts.append(Vector2(cos(a), sin(a)) * r)
	for i in 17: # inner arc (thinner at the ends -> crescent)
		var a := lerpf(1.1, -1.1, i / 16.0)
		pts.append(Vector2(cos(a), sin(a)) * r * 0.72 + Vector2(r * 0.12, 0))
	# Shift so the arc passes through the hit point instead of circling around it.
	for i in pts.size():
		pts[i] -= Vector2(r * 0.86, 0)
	p.polygon = pts
	p.color = color
	p.position = pos
	p.rotation = randf_range(-0.9, -0.3) if randf() < 0.5 else randf_range(0.3, 0.9)
	p.scale = Vector2(0.5, 0.5)
	p.z_index = 300
	parent.add_child(p)
	var tw := p.create_tween().set_parallel()
	tw.tween_property(p, "scale", Vector2(1.15, 1.15), 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(p, "rotation", p.rotation + 0.6, 0.22)
	tw.tween_property(p, "modulate:a", 0.0, 0.25).set_delay(0.06)
	tw.chain().tween_callback(p.queue_free)


## One-shot particle burst.
static func burst(parent: Node, pos: Vector2, color: Color, amount := 16, speed := 260.0, gravity := 300.0) -> void:
	if parent == null:
		return
	var c := CPUParticles2D.new()
	c.position = pos
	c.z_index = 301
	c.one_shot = true
	c.explosiveness = 0.95
	c.amount = amount
	c.lifetime = 0.55
	c.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	c.emission_sphere_radius = 14.0
	c.direction = Vector2.UP
	c.spread = 180.0
	c.initial_velocity_min = speed * 0.4
	c.initial_velocity_max = speed
	c.gravity = Vector2(0, gravity)
	c.texture = _dot_texture()
	c.scale_amount_min = 0.5
	c.scale_amount_max = 1.0
	var ramp := Gradient.new()
	ramp.set_color(0, color)
	ramp.set_color(1, Color(color, 0.0))
	c.color_ramp = ramp
	parent.add_child(c)
	c.emitting = true
	_free_after(c, c.lifetime + 0.2)


## Sparkles floating upward (heals, buffs).
static func rise(parent: Node, pos: Vector2, color: Color, amount := 14) -> void:
	if parent == null:
		return
	var c := CPUParticles2D.new()
	c.position = pos
	c.z_index = 301
	c.one_shot = true
	c.explosiveness = 0.7
	c.amount = amount
	c.lifetime = 0.9
	c.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	c.emission_rect_extents = Vector2(60, 40)
	c.direction = Vector2.UP
	c.spread = 20.0
	c.initial_velocity_min = 60.0
	c.initial_velocity_max = 140.0
	c.gravity = Vector2(0, -40)
	c.texture = _dot_texture()
	c.scale_amount_min = 0.45
	c.scale_amount_max = 0.85
	var ramp := Gradient.new()
	ramp.set_color(0, color)
	ramp.set_color(1, Color(color, 0.0))
	c.color_ramp = ramp
	parent.add_child(c)
	c.emitting = true
	_free_after(c, c.lifetime + 0.2)


## Expanding ring (shield up, summon, boss phase).
static func ring(parent: Node, pos: Vector2, color: Color, radius := 120.0) -> void:
	if parent == null:
		return
	var l := Line2D.new()
	var pts := PackedVector2Array()
	for i in 41:
		var a := TAU * i / 40.0
		pts.append(Vector2(cos(a), sin(a) * 0.45) * radius) # flattened: lies on the ground
	l.points = pts
	l.width = 8.0
	l.default_color = color
	l.position = pos
	l.scale = Vector2(0.3, 0.3)
	l.z_index = 299
	parent.add_child(l)
	var tw := l.create_tween().set_parallel()
	tw.tween_property(l, "scale", Vector2(1.2, 1.2), 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "modulate:a", 0.0, 0.45)
	tw.chain().tween_callback(l.queue_free)


## Soft round dot for particles (generated once, no image file needed).
static var _dot: Texture2D

static func _dot_texture() -> Texture2D:
	if _dot == null:
		var g := Gradient.new()
		g.set_color(0, Color.WHITE)
		g.set_color(1, Color(1, 1, 1, 0))
		var t := GradientTexture2D.new()
		t.gradient = g
		t.fill = GradientTexture2D.FILL_RADIAL
		t.fill_from = Vector2(0.5, 0.5)
		t.fill_to = Vector2(1.0, 0.5)
		t.width = 32
		t.height = 32
		_dot = t
	return _dot


static func _free_after(n: Node, seconds: float) -> void:
	var t := n.get_tree().create_timer(seconds) if n.is_inside_tree() else null
	if t != null:
		t.timeout.connect(func(): if is_instance_valid(n): n.queue_free())
