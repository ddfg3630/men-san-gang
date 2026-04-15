extends Node2D
## Draws decorative bars behind the title and subtitle. Responsive layout.

func _ready() -> void:
	get_viewport().size_changed.connect(func() -> void: queue_redraw())

func _draw() -> void:
	var vp: Vector2 = get_viewport_rect().size
	var cx := vp.x / 2.0
	var scale := minf(vp.x / 800.0, vp.y / 900.0)
	var title_fs := clampi(int(52 * scale), 32, 64)
	var sub_fs := clampi(int(22 * scale), 16, 30)
	var title_y := vp.y * 0.22
	var sub_y := title_y + 80 * scale
	DrawUtils.draw_text_bar(self, Vector2(cx, title_y), "悶 三 缸", title_fs)
	DrawUtils.draw_text_bar(self, Vector2(cx, sub_y), "傳統棋類對弈遊戲", sub_fs)
