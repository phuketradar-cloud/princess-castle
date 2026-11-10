class_name LivingPrincess
extends Node2D
## A princess living in her room (Event Spot system — no free walking / pathfinding).
## Every few seconds she picks an activity (weighted by her personality), walks to that
## activity's spot, takes the pose (sprite transforms + props + expression) and may say a line.
##
## Poses are built from the same paper doll as battle:
##   STANDING idle · SITTING squashed on the chair · SLEEPING lying on the bed, eyes closed, Zzz
##   READING book + curious · TRAINING lunge loop next to the dummy · LOOKING_OUTSIDE by the window
##   DRINKING_TEA teacup + happy

signal activity_changed(activity: int)
signal tapped

const A = CastleTypes.Activity
const X = CastleTypes.Expr

## activity -> {pos: Vector2, rot: float, face_left: bool}; filled by the room.
var spots := {}
var princess: PrincessDefinition
var activity: int = A.STANDING
var interval := Vector2(6.0, 10.0)
var walk_speed := 420.0
var auto_live := true

var visual: CharacterAnimator
var doll: PaperDoll
var _timer := 0.0
var _busy := false
var _train_tween: Tween
var _hit_rect := Rect2(-110, -360, 220, 380)
var _rng := RandomNumberGenerator.new()
var _scale := 1.5


func setup(p: PrincessDefinition, equipment: Array, room_scale := 1.5) -> void:
	princess = p
	_scale = room_scale
	visual = CharacterAnimator.new()
	add_child(visual)
	doll = PaperDoll.new()
	visual.add_child(doll)
	doll.setup(p.battle_texture, Color.WHITE, false, p.slot_anchors, p.art_scale)
	doll.setup_face(p.face_dir, p.face_anchor)
	doll.set_equipment(equipment)
	visual.rest_scale = Vector2(_scale, _scale)
	_rng.randomize()
	_timer = 1.5


func _process(delta: float) -> void:
	if not auto_live or _busy:
		return
	_timer -= delta
	if _timer <= 0.0:
		_timer = _rng.randf_range(interval.x, interval.y)
		do_activity(pick_activity())


## Weighted random activity (never the same twice in a row).
func pick_activity() -> int:
	var w := princess.activity_weights
	var total := 0.0
	for i in w.size():
		if i != activity and spots.has(i):
			total += maxf(0.0, w[i])
	var r := _rng.randf() * total
	for i in w.size():
		if i == activity or not spots.has(i):
			continue
		r -= maxf(0.0, w[i])
		if r <= 0.0:
			return i
	return A.STANDING


## Walk to the spot, then pose.
func do_activity(next: int) -> void:
	if not spots.has(next):
		return
	_busy = true
	_clear_pose()
	var spot: Dictionary = spots[next]
	var target: Vector2 = spot.pos
	var dist := position.distance_to(target)
	if dist > 4.0:
		_face(target.x < position.x)
		var tw := create_tween()
		tw.tween_property(self, "position", target, dist / walk_speed)
		# little hops while walking
		var hops := maxi(1, int(dist / 90.0))
		var hop := create_tween()
		hop.tween_method(func(t: float): visual.position.y = -absf(sin(t * PI * hops)) * 10.0, 0.0, 1.0, dist / walk_speed)
		await tw.finished
	activity = next
	_apply_pose(spot)
	_busy = false
	activity_changed.emit(activity)


func _face(left: bool) -> void:
	visual.rest_scale = Vector2(-_scale if left else _scale, _scale)


func _clear_pose() -> void:
	if _train_tween:
		_train_tween.kill()
		_train_tween = null
	visual.rotation = 0.0
	visual.position = Vector2.ZERO
	visual.breathe = true
	doll.position = Vector2.ZERO
	doll.scale = Vector2.ONE
	doll.force_eyes("")
	doll.set_prop("")
	doll.set_expression(X.NORMAL)


func _apply_pose(spot: Dictionary) -> void:
	_face(spot.get("face_left", false))
	match activity:
		A.SITTING:
			doll.scale = Vector2(1.0, 0.86)
			doll.position = Vector2(0, -24)
		A.SLEEPING:
			visual.breathe = false
			visual.rotation = deg_to_rad(-78.0)
			doll.force_eyes("closed")
			doll.set_prop("zzz")
			var breathe := create_tween().set_loops()
			breathe.tween_property(doll, "scale", Vector2(1.0, 1.03), 1.4)
			breathe.tween_property(doll, "scale", Vector2(1.0, 1.0), 1.4)
			_train_tween = breathe
		A.READING:
			doll.set_prop("book")
			doll.set_expression(X.CURIOUS)
		A.TRAINING:
			doll.set_expression(X.ANGRY)
			var t := create_tween().set_loops()
			t.tween_property(visual, "position", Vector2(30 if not spot.get("face_left", false) else -30, 0), 0.25)
			t.tween_property(visual, "position", Vector2.ZERO, 0.3)
			t.tween_interval(0.35)
			_train_tween = t
		A.LOOKING_OUTSIDE:
			var tilt := create_tween().set_loops()
			tilt.tween_property(visual, "rotation", deg_to_rad(4), 1.6)
			tilt.tween_property(visual, "rotation", deg_to_rad(-2), 1.6)
			_train_tween = tilt
		A.DRINKING_TEA:
			doll.set_prop("teacup")
			doll.set_expression(X.HAPPY)


## Happy jump (Bond Lv2+ animation) / reactions.
func happy_jump() -> void:
	if activity == A.SLEEPING:
		return
	var t := create_tween()
	t.tween_property(visual, "position:y", -60.0, 0.16).set_ease(Tween.EASE_OUT)
	t.tween_property(visual, "position:y", 0.0, 0.2).set_ease(Tween.EASE_IN)
	t.tween_property(visual, "position:y", -30.0, 0.12)
	t.tween_property(visual, "position:y", 0.0, 0.14)


func head_tilt() -> void:
	var t := create_tween()
	t.tween_property(visual, "rotation", deg_to_rad(8), 0.2)
	t.tween_property(visual, "rotation", 0.0, 0.3)


func popup_position() -> Vector2:
	return global_position + Vector2(0, -230 * _scale) if activity != A.SLEEPING else global_position + Vector2(60, -140)


func _unhandled_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb == null or not mb.pressed or mb.button_index != MOUSE_BUTTON_LEFT:
		return
	if _hit_rect.has_point(to_local(get_global_mouse_position())):
		tapped.emit()
		get_viewport().set_input_as_handled()
