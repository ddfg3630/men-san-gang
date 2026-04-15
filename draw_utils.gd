class_name DrawUtils
## Shared drawing utilities for rounded rects and text bars.

static var _font: Font = preload("res://fonts/NotoSansTC-Regular.otf")

static func get_font() -> Font:
	if _font != null:
		return _font
	return ThemeDB.fallback_font

static func draw_rounded_rect(canvas: CanvasItem, rect: Rect2, radius: float, color: Color) -> void:
	canvas.draw_rect(Rect2(rect.position.x + radius, rect.position.y, rect.size.x - radius * 2, rect.size.y), color)
	canvas.draw_rect(Rect2(rect.position.x, rect.position.y + radius, radius, rect.size.y - radius * 2), color)
	canvas.draw_rect(Rect2(rect.position.x + rect.size.x - radius, rect.position.y + radius, radius, rect.size.y - radius * 2), color)
	canvas.draw_circle(rect.position + Vector2(radius, radius), radius, color)
	canvas.draw_circle(rect.position + Vector2(rect.size.x - radius, radius), radius, color)
	canvas.draw_circle(rect.position + Vector2(radius, rect.size.y - radius), radius, color)
	canvas.draw_circle(rect.position + Vector2(rect.size.x - radius, rect.size.y - radius), radius, color)

static func draw_rounded_rect_outline(canvas: CanvasItem, rect: Rect2, radius: float, color: Color, width: float) -> void:
	canvas.draw_line(rect.position + Vector2(radius, 0), rect.position + Vector2(rect.size.x - radius, 0), color, width)
	canvas.draw_line(rect.position + Vector2(radius, rect.size.y), rect.position + Vector2(rect.size.x - radius, rect.size.y), color, width)
	canvas.draw_line(rect.position + Vector2(0, radius), rect.position + Vector2(0, rect.size.y - radius), color, width)
	canvas.draw_line(rect.position + Vector2(rect.size.x, radius), rect.position + Vector2(rect.size.x, rect.size.y - radius), color, width)
	canvas.draw_arc(rect.position + Vector2(radius, radius), radius, PI, PI * 1.5, 12, color, width)
	canvas.draw_arc(rect.position + Vector2(rect.size.x - radius, radius), radius, PI * 1.5, TAU, 12, color, width)
	canvas.draw_arc(rect.position + Vector2(radius, rect.size.y - radius), radius, PI * 0.5, PI, 12, color, width)
	canvas.draw_arc(rect.position + Vector2(rect.size.x - radius, rect.size.y - radius), radius, 0, PI * 0.5, 12, color, width)

static func draw_text_bar(canvas: CanvasItem, center: Vector2, text: String, font_size: int, bg_color := Color(0.28, 0.2, 0.12, 0.72)) -> Rect2:
	var font: Font = get_font()
	var text_size: Vector2 = font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
	var padding := Vector2(32, 14)
	var bar_size := text_size + padding * 2
	var bar_rect := Rect2(center - bar_size / 2, bar_size)
	var radius := 12.0

	draw_rounded_rect(canvas, bar_rect, radius, bg_color)
	var shine_rect := Rect2(bar_rect.position, Vector2(bar_rect.size.x, bar_rect.size.y * 0.45))
	draw_rounded_rect(canvas, shine_rect, radius, Color(1, 1, 1, 0.1))
	draw_rounded_rect_outline(canvas, bar_rect, radius, Color(0.4, 0.3, 0.15, 0.5), 1.5)

	var text_pos := Vector2(center.x - text_size.x / 2, center.y + text_size.y / 4)
	canvas.draw_string(font, text_pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(1, 1, 1, 0.95))
	return bar_rect

static func draw_color_button(canvas: CanvasItem, rect: Rect2, text: String, font_size: int, bg_color: Color, border_color: Color) -> void:
	var radius := 12.0
	draw_rounded_rect(canvas, rect, radius, bg_color)
	var shine := Rect2(rect.position, Vector2(rect.size.x, rect.size.y * 0.45))
	draw_rounded_rect(canvas, shine, radius, Color(1, 1, 1, 0.15))
	draw_rounded_rect_outline(canvas, rect, radius, border_color, 1.5)

	var font: Font = get_font()
	var ts: Vector2 = font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
	var cx := rect.position.x + (rect.size.x - ts.x) / 2
	var cy := rect.position.y + (rect.size.y + ts.y) / 2 - 4
	canvas.draw_string(font, Vector2(cx, cy), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(1, 1, 1, 0.95))
