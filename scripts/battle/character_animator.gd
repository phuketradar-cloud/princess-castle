class_name CharacterAnimator
extends Node2D
## Code-driven "fixed pose" animation for any character (princess or monster): no Spine,
## no AnimationPlayer needed. Put it on a "Visual" node whose children are the sprite layers
## (paper-doll layers in later phases), so every character reuses the same moves.
## Uses Godot Tweens (the built-in equivalent of DOTween). Every move can be awaited:
##     await visual.lunge(Vector2.RIGHT)

@export var breathe := true
@export_range(0.0, 0.1) var breath_amount := 0.025
@export var breath_speed := 2.2
@export var hit_flash_color := Color(1.0, 0.4, 0.4)

## Base scale (e.g. per-monster size). Breathing and squash are applied on top.
var rest_scale := Vector2.ONE
var is_dead := false

var _offset := Vector2.ZERO
var _scale_mul := Vector2.ONE
var _time := 0.0
var _phase := 0.0


func _ready() -> void:
	_phase = randf() * TAU


func _process(delta: float) -> void:
	_time += delta
	var b := 0.0
	if breathe and not is_dead:
		b = sin(_time * breath_speed + _phase) * breath_amount
	position = _offset
	scale = rest_scale * Vector2(1.0 - b * 0.5, 1.0 + b) * _scale_mul


func reset_pose() -> void:
	is_dead = false
	_offset = Vector2.ZERO
	_scale_mul = Vector2.ONE
	rotation = 0.0
	modulate = Color.WHITE


## Dash toward the target and back (attacks).
func lunge(direction: Vector2, distance := 70.0, duration := 0.28) -> void:
	if is_dead:
		return
	var tw := create_tween()
	tw.tween_property(self, "_offset", direction.normalized() * distance, duration * 0.5) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "_offset", Vector2.ZERO, duration * 0.5) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await tw.finished


## Red flash + shake.
func hit(duration := 0.3) -> void:
	if is_dead:
		return
	modulate = hit_flash_color
	var tw := create_tween().set_parallel()
	tw.tween_property(self, "modulate", Color.WHITE, duration)
	tw.tween_method(func(t: float): _offset = Vector2(sin(t * 50.0) * 12.0 * (1.0 - t), 0.0), 0.0, 1.0, duration)
	await tw.finished
	_offset = Vector2.ZERO


## Hop away with a ghostly fade.
func dodge(away: Vector2, duration := 0.3) -> void:
	if is_dead:
		return
	var tw := create_tween()
	tw.tween_method(func(t: float):
		var arc := sin(t * PI)
		_offset = away.normalized() * 45.0 * arc + Vector2.UP * 15.0 * arc
		modulate.a = 1.0 - 0.55 * arc, 0.0, 1.0, duration)
	await tw.finished
	_offset = Vector2.ZERO
	modulate.a = 1.0


## Squash (defend / cast / heal).
func brace(duration := 0.3) -> void:
	if is_dead:
		return
	var tw := create_tween()
	tw.tween_method(func(t: float):
		var s := sin(t * PI) * 0.12
		_scale_mul = Vector2(1.0 + s, 1.0 - s), 0.0, 1.0, duration)
	await tw.finished
	_scale_mul = Vector2.ONE


## Two happy hops.
func victory(duration := 0.7) -> void:
	if is_dead:
		return
	var tw := create_tween()
	tw.tween_method(func(t: float): _offset = Vector2.UP * 35.0 * absf(sin(t * TAU)), 0.0, 1.0, duration)
	await tw.finished
	_offset = Vector2.ZERO


## Tilt, sink and fade out.
func die(duration := 0.6) -> void:
	is_dead = true
	var tw := create_tween().set_parallel()
	tw.tween_property(self, "rotation", deg_to_rad(-20.0), duration)
	tw.tween_property(self, "_offset", Vector2(0, 30), duration)
	tw.tween_property(self, "modulate", Color(0.6, 0.6, 0.7, 0.0), duration)
	await tw.finished
