class_name SafeArea
## Keeps UI out of phone notches / rounded corners / camera cut-outs.
## apply_to_layer() scales + offsets a whole CanvasLayer so its 1920x1080 design fits the
## OS-reported safe area. On desktop (safe area = whole window) it changes nothing.


## Safe area as fractions of the window: Rect2(left, top, width, height) in 0..1.
static func fraction() -> Rect2:
	# Desktop "safe area" = screen minus taskbar: not a notch, never shrink the game there.
	if not OS.has_feature("mobile"):
		return Rect2(0, 0, 1, 1)
	var win := DisplayServer.window_get_size()
	if win.x <= 0 or win.y <= 0:
		return Rect2(0, 0, 1, 1)
	var safe := Rect2(DisplayServer.get_display_safe_area())
	# Some platforms report screen coordinates; clamp into the window.
	var full := Rect2(Vector2.ZERO, Vector2(win))
	safe = safe.intersection(full)
	if safe.size.x < win.x * 0.5 or safe.size.y < win.y * 0.5:
		return Rect2(0, 0, 1, 1) # implausible value: ignore
	return Rect2(safe.position / Vector2(win), safe.size / Vector2(win))


## Fit a CanvasLayer's content into the safe area (uniform scale keeps the layout).
static func apply_to_layer(layer: CanvasLayer, f: Rect2 = fraction()) -> void:
	if layer == null:
		return
	if f.is_equal_approx(Rect2(0, 0, 1, 1)):
		layer.transform = Transform2D.IDENTITY
		return
	var view := layer.get_viewport().get_visible_rect().size if layer.is_inside_tree() else Vector2(1920, 1080)
	var s := minf(f.size.x, f.size.y)
	var origin := f.position * view + (f.size * view - view * s) * 0.5
	layer.transform = Transform2D(0.0, Vector2(s, s), 0.0, origin)
