@tool
class_name EllipseShape
extends Node2D
## Draws a filled ellipse or an ellipse ring (shadows, target marker). No texture needed.

@export var radius := Vector2(100, 28):
	set(v):
		radius = v
		queue_redraw()
@export var color := Color(0, 0, 0, 0.4):
	set(v):
		color = v
		queue_redraw()
@export var ring := false:
	set(v):
		ring = v
		queue_redraw()
@export var thickness := 7.0:
	set(v):
		thickness = v
		queue_redraw()


func _draw() -> void:
	if radius.x <= 0.0 or radius.y <= 0.0:
		return
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, radius.y / radius.x))
	if ring:
		draw_arc(Vector2.ZERO, radius.x, 0.0, TAU, 64, color, thickness, true)
	else:
		draw_circle(Vector2.ZERO, radius.x, color, true, -1.0, true)
