class_name Modal
extends Control
## Dimmed full-screen overlay with a centered panel that pops in.
## Add children to `content`. Call open()/close().

signal closed

var dismissible := true  # click outside / Esc closes it
var content: VBoxContainer
var panel: PanelContainer
var _dim: ColorRect
var _tween: Tween

func _init() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	_dim = ColorRect.new()
	_dim.color = Color(0.16, 0.11, 0.06, 0.5)
	_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	panel = PanelContainer.new()
	panel.add_theme_stylebox_override("panel",
		UITheme.box(UITheme.PAPER, 24, UITheme.PAPER_BORDER, 2, 24, Vector2(36, 28)))
	center.add_child(panel)
	content = VBoxContainer.new()
	content.add_theme_constant_override("separation", 14)
	panel.add_child(content)

func open() -> void:
	visible = true
	_kill()
	modulate.a = 0.0
	panel.pivot_offset = panel.size / 2.0
	panel.scale = Vector2(0.88, 0.88)
	_tween = create_tween().set_parallel(true)
	_tween.tween_property(self, "modulate:a", 1.0, 0.18)
	_tween.tween_property(panel, "scale", Vector2.ONE, 0.32).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	# Re-center the pivot once the container has laid out the panel
	panel.resized.connect(func() -> void: panel.pivot_offset = panel.size / 2.0, CONNECT_ONE_SHOT)
	var first := _first_button(content)
	if first:
		first.grab_focus.call_deferred()

func close() -> void:
	if not visible:
		return
	_kill()
	_tween = create_tween()
	_tween.tween_property(self, "modulate:a", 0.0, 0.14)
	_tween.tween_callback(func() -> void:
		visible = false
		closed.emit())

func _kill() -> void:
	if _tween and _tween.is_valid():
		_tween.kill()

func _gui_input(event: InputEvent) -> void:
	if dismissible and event is InputEventMouseButton and event.pressed \
			and not panel.get_global_rect().has_point(event.global_position):
		close()
		accept_event()

func _unhandled_input(event: InputEvent) -> void:
	if visible and dismissible and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()

func _first_button(n: Node) -> Button:
	for c in n.get_children():
		if c is Button:
			return c
		var b := _first_button(c)
		if b:
			return b
	return null

# ── Shared content ──

static func make_rules() -> Modal:
	var m := Modal.new()
	m.content.add_child(UITheme.make_label("遊戲規則", 32, "TitleLabel"))
	var rt := RichTextLabel.new()
	rt.bbcode_enabled = true
	rt.fit_content = true
	rt.scroll_active = false
	rt.custom_minimum_size = Vector2(600, 0)
	rt.text = (
		"[b]棋盤[/b]：上方三個「缸」，中間一排、下方一排，共九個點。\n"
		+ "[b]開局[/b]：藍方三子在左列、紅方三子在右列，藍方先走。\n"
		+ "[b]走法[/b]：每回合沿線把自己一子移到相鄰的空點。\n"
		+ "[b]禁回頭[/b]：不能立刻把上一步走回去（若因此無路可走則解除）。\n"
		+ "[b]讓路[/b]：一方被堵死時，對手必須讓出一步替他解圍；雙方都動不了則平局。\n"
		+ "[b][color=#b8443a]勝利[/color][/b]：把對手三子全困進上方的缸，並以自己三子封住[color=#a77a43]中排[/color]（棋盤上的金色帶）。")
	m.content.add_child(rt)
	var ok := Button.new()
	ok.text = "知道了"
	ok.custom_minimum_size = Vector2(200, 52)
	ok.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	ok.pressed.connect(m.close)
	m.content.add_child(ok)
	return m
