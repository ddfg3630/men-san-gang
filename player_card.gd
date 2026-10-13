class_name PlayerCard
extends PanelContainer
## Compact card showing one side's name, role, and progress; glows on its turn.

var player := 0
var _name: Label
var _detail: Label
var _dot: Panel
var _active := false

func _init(p: int = 0) -> void:
	player = p
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 12)
	add_child(hb)
	_dot = Panel.new()
	_dot.custom_minimum_size = Vector2(30, 30)
	_dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var dot_box := UITheme.box(UITheme.PLAYER_COLORS[p], 15, UITheme.PLAYER_DARK[p], 3)
	_dot.add_theme_stylebox_override("panel", dot_box)
	hb.add_child(_dot)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 0)
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(vb)
	_name = UITheme.make_label("", 23, "TitleLabel")
	_detail = UITheme.make_label("", 16, "MutedLabel")
	vb.add_child(_name)
	vb.add_child(_detail)
	_apply_style()

func set_info(title: String, detail: String) -> void:
	_name.text = title
	_detail.text = detail

func pulse() -> void:
	## Brief pop to draw the eye when this side's turn starts.
	pivot_offset = size / 2.0
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector2(1.05, 1.05), 0.12).set_trans(Tween.TRANS_SINE)
	tw.tween_property(self, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_SINE)

func set_active(active: bool) -> void:
	if active == _active:
		return
	_active = active
	_apply_style()

func _apply_style() -> void:
	var c := UITheme.PLAYER_COLORS[player]
	var sb: StyleBoxFlat
	if _active:
		sb = UITheme.box(UITheme.PAPER.lerp(c, 0.08), 16, c, 3, 12, Vector2(16, 10))
	else:
		sb = UITheme.box(Color(UITheme.PAPER, 0.65), 16, UITheme.PAPER_BORDER, 2, 0, Vector2(16, 10))
	add_theme_stylebox_override("panel", sb)
	modulate = Color(1, 1, 1, 1.0 if _active else 0.75)
