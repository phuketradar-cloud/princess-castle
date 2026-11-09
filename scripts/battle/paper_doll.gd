class_name PaperDoll
extends Node2D
## Layered character sprite: body + face (eyes / eyebrows / mouth) + equipment + props.
## Origin = feet. Equipment is centered on the body's slot anchor (+ item.layer_offset)
## and ordered by ItemTypes.SLOT_Z (wings behind the body, weapon in front).
## Facial expressions swap the face layers (files eyes_<v>.png, brows_<v>.png, mouth_<v>.png
## in the princess's face_dir) and the eyes blink on their own.
## Used by UnitView in battle, the Equipment screen preview and the castle rooms.

const FACE_Z := 1
const PROP_Z := 6
const PROP_POS := {"book": Vector2(-4, -104), "teacup": Vector2(18, -126), "zzz": Vector2(36, -236)}
## Eye variants that look open (these blink).
const BLINKING := ["normal", "curious", "surprised", "fear", "angry", "crying"]

var body: Sprite2D
var expression: int = CastleTypes.Expr.NORMAL
var _layers := {} # slot -> Sprite2D
var _anchors := {}
var _flip := false
var _face_dir := ""
var _face_anchor := Vector2.ZERO
var _eyes: Sprite2D
var _brows: Sprite2D
var _mouth: Sprite2D
var _eyes_variant := "normal"
var _eyes_forced := ""      # e.g. "closed" while sleeping
var _blink_left := 3.0
var _blink_time := 0.0
var _prop: Sprite2D
var _tex_cache := {}


func _ready() -> void:
	_ensure_body()


func _ensure_body() -> void:
	if body == null:
		body = Sprite2D.new()
		body.name = "Body"
		body.centered = false
		add_child(body)


func setup(texture: Texture2D, tint: Color, flip: bool, anchors: Dictionary = {}) -> void:
	_ensure_body()
	_flip = flip
	_anchors = anchors
	body.texture = texture
	body.self_modulate = tint
	body.flip_h = flip
	var size := texture.get_size() if texture != null else Vector2(120, 160)
	body.offset = Vector2(-size.x * 0.5, -size.y)


## Enables the layered face. face_dir = folder with eyes_/brows_/mouth_ PNGs.
func setup_face(face_dir: String, face_anchor: Vector2) -> void:
	_face_dir = face_dir
	_face_anchor = face_anchor
	if face_dir == "":
		return
	if _eyes == null:
		_mouth = _face_sprite("Mouth")
		_eyes = _face_sprite("Eyes")
		_brows = _face_sprite("Brows")
	var pos := face_anchor
	if _flip:
		pos.x = -pos.x
	for s in [_eyes, _brows, _mouth]:
		s.position = pos
		s.flip_h = _flip
	set_expression(expression)


func has_face() -> bool:
	return _eyes != null


func _face_sprite(n: String) -> Sprite2D:
	var s := Sprite2D.new()
	s.name = n
	s.z_index = FACE_Z
	add_child(s)
	return s


## Sets one of CastleTypes.Expr. Missing files are skipped silently (art can be partial).
func set_expression(expr: int) -> void:
	expression = expr
	if _eyes == null:
		return
	var parts: Array = CastleTypes.EXPRESSION_PARTS.get(expr, CastleTypes.EXPRESSION_PARTS[CastleTypes.Expr.NORMAL])
	_eyes_variant = parts[0]
	_eyes.texture = _tex("eyes_" + (_eyes_forced if _eyes_forced != "" else _eyes_variant))
	_brows.texture = _tex("brows_" + parts[1])
	_mouth.texture = _tex("mouth_" + parts[2])


## Force eyes shut (sleeping) or "" to release.
func force_eyes(variant: String) -> void:
	_eyes_forced = variant
	set_expression(expression)


func _tex(file: String) -> Texture2D:
	if _tex_cache.has(file):
		return _tex_cache[file]
	var path := "%s/%s.png" % [_face_dir, file]
	var t: Texture2D = load(path) if ResourceLoader.exists(path) else null
	_tex_cache[file] = t
	return t


func _process(delta: float) -> void:
	if _eyes == null or _eyes_forced != "" or not BLINKING.has(_eyes_variant):
		return
	if _blink_time > 0.0:
		_blink_time -= delta
		if _blink_time <= 0.0:
			_eyes.texture = _tex("eyes_" + _eyes_variant)
		return
	_blink_left -= delta
	if _blink_left <= 0.0:
		_blink_left = randf_range(2.2, 5.0)
		_blink_time = 0.13
		_eyes.texture = _tex("eyes_closed")


## Activity prop: "book", "teacup", "zzz" or "" for none.
func set_prop(prop_name: String) -> void:
	if _prop == null:
		_prop = Sprite2D.new()
		_prop.name = "Prop"
		_prop.z_index = PROP_Z
		add_child(_prop)
	if prop_name == "":
		_prop.visible = false
		return
	_prop.texture = load("res://assets/art/props/%s.png" % prop_name)
	var pos: Vector2 = PROP_POS.get(prop_name, Vector2.ZERO)
	if _flip:
		pos.x = -pos.x
	_prop.position = pos
	_prop.flip_h = _flip
	_prop.visible = true


## Replaces all equipment layers. Items without a texture or anchor are skipped.
func set_equipment(items: Array) -> void:
	for s in _layers.values():
		s.queue_free()
	_layers.clear()
	for item in items:
		if item == null or item.texture == null or not _anchors.has(item.slot):
			continue
		var s := Sprite2D.new()
		s.name = "Layer_%s" % ItemTypes.SLOT_NAMES_EN[item.slot]
		s.texture = item.texture
		var pos: Vector2 = _anchors[item.slot] + item.layer_offset
		if _flip:
			pos.x = -pos.x
		s.position = pos
		s.flip_h = _flip
		s.z_index = ItemTypes.SLOT_Z[item.slot]
		add_child(s)
		_layers[item.slot] = s


func layer_count() -> int:
	return _layers.size()


func texture_size() -> Vector2:
	return body.texture.get_size() if body != null and body.texture != null else Vector2(120, 160)
