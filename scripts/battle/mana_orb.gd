class_name ManaOrb
extends Control
## Circular mana indicator: a glowing orb with "current/max" in the middle and one gem per
## mana point around it (filled = available). Code-drawn, no textures.

const GOLD := Color(0.85, 0.68, 0.35)
const GEM_ON := Color(0.35, 0.7, 1.0)
const GEM_OFF := Color(0.07, 0.06, 0.14)

var current := 0
var maximum := 6
var _font_size := 40


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_mana(p_current: int, p_maximum: int) -> void:
	current = p_current
	maximum = maxi(p_maximum, 1)
	queue_redraw()


func _draw() -> void:
	var c := size * 0.5
	var r := minf(size.x, size.y) * 0.5 - 4.0
	var ring_r := r * 0.82        # gems sit on this circle
	var gem_r := r * 0.13
	var core_r := r * 0.52
	# outer gold ring + dark plate
	draw_circle(c, r, Color(0.05, 0.03, 0.1, 0.92))
	draw_arc(c, r, 0, TAU, 64, GOLD, 3.0, true)
	draw_arc(c, ring_r - gem_r - 6.0, 0, TAU, 64, Color(GOLD, 0.45), 2.0, true)
	# glowing purple core, fuller when there is more mana
	var fill := float(current) / maximum
	for i in 6:
		var t := 1.0 - i / 6.0
		draw_circle(c, core_r * (0.55 + 0.45 * t), Color(0.45, 0.25, 0.85, 0.12 + 0.16 * fill))
	draw_circle(c, core_r * 0.62, Color(0.55, 0.35, 0.95, 0.35 + 0.4 * fill))
	draw_arc(c, core_r, 0, TAU, 48, Color(0.75, 0.6, 1, 0.8), 2.0, true)
	# gems around (start at the top, clockwise)
	for i in maximum:
		var a := -PI * 0.5 + TAU * i / maximum
		var p := c + Vector2(cos(a), sin(a)) * ring_r
		var on := i < current
		if on:
			draw_circle(p, gem_r * 1.45, Color(GEM_ON, 0.25))
		draw_circle(p, gem_r, GEM_ON if on else GEM_OFF)
		draw_arc(p, gem_r, 0, TAU, 20, Color(0.75, 0.9, 1, 0.9) if on else Color(GOLD, 0.6), 2.0, true)
		if on:
			draw_circle(p + Vector2(-gem_r * 0.3, -gem_r * 0.3), gem_r * 0.3, Color(1, 1, 1, 0.7))
	# value
	var font := get_theme_default_font()
	var text := "%d/%d" % [current, maximum]
	var fs := int(core_r * 0.62)
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, fs).x
	var base := c + Vector2(-w * 0.5, fs * 0.36)
	draw_string_outline(font, base, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 6, Color(0.08, 0.02, 0.15))
	draw_string(font, base, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.WHITE)
