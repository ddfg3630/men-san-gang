class_name UITheme
## Shared palette, fonts, and Theme for every screen.
## Scenes call UITheme.get_theme() and assign it to their root Control.

const FONT := preload("res://fonts/NotoSansTC-Regular.otf")
## Serif display face (subset to the glyphs the UI uses — see tools/subset_title_font.py).
const TITLE_FONT := preload("res://fonts/NotoSerifTC-Bold-subset.otf")

# ── Palette ──
const BG_TOP := Color("f7f1e6")
const BG_BOTTOM := Color("e4d4ba")
const INK := Color("2e2a25")
const INK_SOFT := Color("74685a")
const PAPER := Color("fffaf1")
const PAPER_BORDER := Color("dcc9a6")
const WOOD := Color("dcb680")
const WOOD_DARK := Color("a77a43")
const WOOD_LINE := Color("5a3e22")
const JAR_RIM := Color("9a6b42")
const JAR_INNER := Color("3a281a")
const ACCENT := Color("e3a92b")
const PRIMARY := Color("6b4a2b")
const NEUTRAL := Color("8d7f6e")
const PLAYER_COLORS: Array[Color] = [Color("3a78d0"), Color("c9433a")]
const PLAYER_DARK: Array[Color] = [Color("1f4c8c"), Color("862620")]
const PLAYER_NAMES: Array[String] = ["藍方", "紅方"]
const DIFFICULTY_NAMES: Array[String] = ["簡單", "普通", "困難"]
const DIFFICULTY_COLORS: Array[Color] = [Color("4f9a57"), Color("d18d24"), Color("b8443a")]

static var _theme: Theme = null
static var _bold: FontVariation = null

static func bold_font() -> Font:
	if _bold == null:
		_bold = FontVariation.new()
		_bold.base_font = FONT
		_bold.variation_embolden = 0.8
	return _bold

static func box(bg: Color, radius: int = 14, border := Color.TRANSPARENT, border_w: int = 0,
		shadow: int = 0, pad := Vector2(18, 10)) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(radius)
	sb.corner_detail = 12
	sb.anti_aliasing = true
	if border_w > 0:
		sb.border_color = border
		sb.set_border_width_all(border_w)
	if shadow > 0:
		sb.shadow_color = Color(0.29, 0.19, 0.08, 0.18)
		sb.shadow_size = shadow
		sb.shadow_offset = Vector2(0, shadow * 0.45)
	sb.content_margin_left = pad.x
	sb.content_margin_right = pad.x
	sb.content_margin_top = pad.y
	sb.content_margin_bottom = pad.y
	return sb

static func _button_box(base: Color, bottom: int, top_pad: float) -> StyleBoxFlat:
	## Raised "key" look: darker bottom edge that compresses when pressed.
	var sb := box(base, 14, base.darkened(0.3), 0, 0, Vector2(22, 10))
	sb.border_width_bottom = bottom
	sb.content_margin_top = top_pad
	sb.content_margin_bottom = 10.0 + 4 - bottom
	return sb

static func apply_button(btn: Button, base: Color, text_color := PAPER) -> void:
	## Per-button color override (used for side / difficulty pickers).
	btn.add_theme_stylebox_override("normal", _button_box(base, 4, 10))
	btn.add_theme_stylebox_override("hover", _button_box(base.lightened(0.1), 4, 10))
	btn.add_theme_stylebox_override("pressed", _button_box(base.darkened(0.08), 1, 13))
	btn.add_theme_stylebox_override("hover_pressed", _button_box(base.darkened(0.08), 1, 13))
	btn.add_theme_stylebox_override("disabled", _button_box(base.lerp(Color(0.7, 0.7, 0.7), 0.6), 4, 10))
	for key in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		btn.add_theme_color_override(key, text_color)

static func get_theme() -> Theme:
	if _theme != null:
		return _theme
	var t := Theme.new()
	t.default_font = FONT
	t.default_font_size = 22

	# Buttons
	t.set_stylebox("normal", "Button", _button_box(PRIMARY, 4, 10))
	t.set_stylebox("hover", "Button", _button_box(PRIMARY.lightened(0.12), 4, 10))
	t.set_stylebox("pressed", "Button", _button_box(PRIMARY.darkened(0.1), 1, 13))
	t.set_stylebox("hover_pressed", "Button", _button_box(PRIMARY.darkened(0.1), 1, 13))
	t.set_stylebox("disabled", "Button", _button_box(NEUTRAL.lightened(0.3), 4, 10))
	var focus := box(Color.TRANSPARENT, 16, ACCENT, 3)
	focus.draw_center = false
	focus.set_expand_margin_all(3)
	t.set_stylebox("focus", "Button", focus)
	for key in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		t.set_color(key, "Button", PAPER)
	t.set_color("font_disabled_color", "Button", Color(1, 1, 1, 0.7))
	t.set_font_size("font_size", "Button", 22)

	# Flat "ghost" button variation for secondary actions (top bar)
	t.set_type_variation("GhostButton", "Button")
	var ghost := box(Color(1, 1, 1, 0.0), 12, PAPER_BORDER, 2, 0, Vector2(16, 6))
	var ghost_hover := box(Color(1, 1, 1, 0.55), 12, WOOD_DARK, 2, 0, Vector2(16, 6))
	var ghost_pressed := box(Color(0.6, 0.45, 0.25, 0.18), 12, WOOD_DARK, 2, 0, Vector2(16, 6))
	t.set_stylebox("normal", "GhostButton", ghost)
	t.set_stylebox("hover", "GhostButton", ghost_hover)
	t.set_stylebox("pressed", "GhostButton", ghost_pressed)
	t.set_stylebox("hover_pressed", "GhostButton", ghost_pressed)
	for key in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		t.set_color(key, "GhostButton", INK)
	t.set_font_size("font_size", "GhostButton", 18)

	# Panels
	t.set_stylebox("panel", "PanelContainer", box(PAPER, 18, PAPER_BORDER, 2, 10, Vector2(22, 16)))

	# Labels
	t.set_color("font_color", "Label", INK)
	t.set_type_variation("TitleLabel", "Label")
	t.set_font("font", "TitleLabel", TITLE_FONT)
	t.set_type_variation("MutedLabel", "Label")
	t.set_color("font_color", "MutedLabel", INK_SOFT)
	t.set_font_size("font_size", "MutedLabel", 17)

	# Rich text (rules)
	t.set_color("default_color", "RichTextLabel", INK)
	t.set_font("normal_font", "RichTextLabel", FONT)
	t.set_font("bold_font", "RichTextLabel", bold_font())
	t.set_font_size("normal_font_size", "RichTextLabel", 19)
	t.set_font_size("bold_font_size", "RichTextLabel", 19)
	t.set_constant("line_separation", "RichTextLabel", 6)

	_theme = t
	return t

static func make_label(text: String, size: int, variation := "", color := Color.TRANSPARENT) -> Label:
	var l := Label.new()
	l.text = text
	if variation != "":
		l.theme_type_variation = variation
	l.add_theme_font_size_override("font_size", size)
	if color.a > 0:
		l.add_theme_color_override("font_color", color)
	return l
