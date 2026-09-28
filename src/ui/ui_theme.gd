class_name UiTheme
extends RefCounted
## Builds the player-facing Theme (warm wood/parchment, square pixel bevels) and a
## cooler, denser "technical" variant for the admin panel. Font sizes are integer
## multiples of the 9px bitmap font so glyphs stay crisp.

const FONT_S := 18
const FONT_L := 27

const INK := Color("#120c0a")
const PANEL := Color("#2a211d")
const PANEL_2 := Color("#3a2e27")
const BEVEL := Color("#5e4a3a")
const BTN := Color("#4a3a2e")
const BTN_HOVER := Color("#5f4a3a")
const BTN_PRESS := Color("#241b16")
const GOLD := Color("#e8b84a")
const TEXT := Color("#f0e2c0")
const MUTED := Color("#b0a088")
const GOOD := Color("#8fd06a")
const BAD := Color("#e0685a")

const ADMIN_PANEL := Color("#161c24")
const ADMIN_BTN := Color("#26303c")
const ADMIN_ACCENT := Color("#5ab4e0")

static var _game: Theme
static var _admin: Theme


static func game() -> Theme:
	if _game == null:
		_game = _build(false)
	return _game


static func admin() -> Theme:
	if _admin == null:
		_admin = _build(true)
	return _admin


static func box(bg: Color, border: Color, bevel: Color = Color(0, 0, 0, 0), pad: int = 6, border_w: int = 2) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(border_w)
	s.set_corner_radius_all(0)
	s.anti_aliasing = false
	s.set_content_margin_all(pad)
	if bevel.a > 0.0:
		s.shadow_color = Color(0, 0, 0, 0.35)
		s.shadow_size = 0
		s.shadow_offset = Vector2(0, 2)
		s.expand_margin_top = 0
		# Inner top highlight is faked with a thicker top border in the bevel color.
		s.border_width_top = border_w + 1
		s.border_color = border
	return s


static func _build(admin_variant: bool) -> Theme:
	var t := Theme.new()
	var font := PixelFont.get_font()
	t.default_font = font
	t.default_font_size = FONT_S
	var panel_c := ADMIN_PANEL if admin_variant else PANEL
	var btn_c := ADMIN_BTN if admin_variant else BTN
	var accent := ADMIN_ACCENT if admin_variant else GOLD
	var text_c := Color("#d8e4ee") if admin_variant else TEXT

	t.set_stylebox("panel", "Panel", box(panel_c, INK, BEVEL, 8))
	t.set_stylebox("panel", "PanelContainer", box(panel_c, INK, BEVEL, 8))
	var inset := box(PANEL_2 if not admin_variant else Color("#1e2630"), INK, Color(0, 0, 0, 0), 6)
	t.set_stylebox("panel", "Inset", inset)
	t.set_type_variation("Inset", "PanelContainer")

	for kind in ["Button", "OptionButton", "MenuButton", "CheckButton"]:
		t.set_stylebox("normal", kind, box(btn_c, INK, BEVEL, 6))
		t.set_stylebox("hover", kind, box(btn_c.lightened(0.12), INK, BEVEL, 6))
		t.set_stylebox("pressed", kind, box(BTN_PRESS if not admin_variant else Color("#10161c"), accent, Color(0, 0, 0, 0), 6))
		t.set_stylebox("hover_pressed", kind, box(BTN_PRESS if not admin_variant else Color("#10161c"), accent, Color(0, 0, 0, 0), 6))
		t.set_stylebox("disabled", kind, box(btn_c.darkened(0.35), INK, Color(0, 0, 0, 0), 6))
		t.set_stylebox("focus", kind, StyleBoxEmpty.new())
		t.set_color("font_color", kind, text_c)
		t.set_color("font_hover_color", kind, Color.WHITE)
		t.set_color("font_pressed_color", kind, accent)
		t.set_color("font_hover_pressed_color", kind, accent)
		t.set_color("font_disabled_color", kind, MUTED.darkened(0.3))
	t.set_type_variation("ToolButton", "Button")
	t.set_stylebox("normal", "ToolButton", box(btn_c, INK, BEVEL, 4))
	t.set_stylebox("hover", "ToolButton", box(btn_c.lightened(0.15), accent.darkened(0.3), BEVEL, 4))
	t.set_stylebox("pressed", "ToolButton", box(BTN_PRESS, accent, Color(0, 0, 0, 0), 4, 3))
	t.set_stylebox("hover_pressed", "ToolButton", box(BTN_PRESS, accent, Color(0, 0, 0, 0), 4, 3))
	t.set_type_variation("TabButton", "Button")
	t.set_stylebox("normal", "TabButton", box(panel_c.darkened(0.25), INK, Color(0, 0, 0, 0), 6))
	t.set_stylebox("pressed", "TabButton", box(panel_c, accent, Color(0, 0, 0, 0), 6))
	t.set_stylebox("hover_pressed", "TabButton", box(panel_c, accent, Color(0, 0, 0, 0), 6))
	t.set_stylebox("hover", "TabButton", box(panel_c.lightened(0.05), INK, Color(0, 0, 0, 0), 6))

	t.set_color("font_color", "Label", text_c)
	t.set_color("font_shadow_color", "Label", Color(0, 0, 0, 0.6))
	t.set_constant("shadow_offset_x", "Label", 0)
	t.set_constant("shadow_offset_y", "Label", 2)
	t.set_type_variation("MutedLabel", "Label")
	t.set_color("font_color", "MutedLabel", MUTED if not admin_variant else Color("#8aa0b4"))
	t.set_type_variation("TitleLabel", "Label")
	t.set_font_size("font_size", "TitleLabel", FONT_L)
	t.set_color("font_color", "TitleLabel", accent if admin_variant else TEXT)
	t.set_type_variation("GoldLabel", "Label")
	t.set_color("font_color", "GoldLabel", accent)

	t.set_stylebox("normal", "LineEdit", box(Color("#1a1310") if not admin_variant else Color("#0e1318"), INK, Color(0, 0, 0, 0), 5))
	t.set_stylebox("focus", "LineEdit", box(Color("#1a1310") if not admin_variant else Color("#0e1318"), accent, Color(0, 0, 0, 0), 5))
	t.set_color("font_color", "LineEdit", text_c)
	t.set_color("caret_color", "LineEdit", accent)

	var bar_bg := box(Color("#1a1310"), INK, Color(0, 0, 0, 0), 0)
	t.set_stylebox("background", "ProgressBar", bar_bg)
	t.set_stylebox("fill", "ProgressBar", box(GOOD.darkened(0.1), Color(0, 0, 0, 0), Color(0, 0, 0, 0), 0, 0))
	t.set_color("font_color", "ProgressBar", TEXT)
	t.set_font_size("font_size", "ProgressBar", FONT_S)

	t.set_stylebox("panel", "TooltipPanel", box(Color("#1c1512"), accent.darkened(0.2), Color(0, 0, 0, 0), 8))
	t.set_color("font_color", "TooltipLabel", TEXT)

	t.set_stylebox("panel", "ItemList", box(Color("#1a1310") if not admin_variant else Color("#0e1318"), INK, Color(0, 0, 0, 0), 4))
	t.set_stylebox("focus", "ItemList", StyleBoxEmpty.new())
	t.set_stylebox("selected", "ItemList", box(accent.darkened(0.55), accent, Color(0, 0, 0, 0), 2))
	t.set_stylebox("selected_focus", "ItemList", box(accent.darkened(0.55), accent, Color(0, 0, 0, 0), 2))
	t.set_color("font_color", "ItemList", text_c)

	t.set_stylebox("panel", "TabContainer", box(panel_c, INK, Color(0, 0, 0, 0), 8))
	t.set_stylebox("tab_selected", "TabContainer", box(panel_c, accent, Color(0, 0, 0, 0), 6))
	t.set_stylebox("tab_unselected", "TabContainer", box(panel_c.darkened(0.3), INK, Color(0, 0, 0, 0), 6))
	t.set_stylebox("tab_hovered", "TabContainer", box(panel_c.lightened(0.05), INK, Color(0, 0, 0, 0), 6))
	t.set_color("font_selected_color", "TabContainer", accent)
	t.set_color("font_unselected_color", "TabContainer", text_c.darkened(0.2))

	t.set_stylebox("normal", "SpinBox", box(Color("#0e1318"), INK, Color(0, 0, 0, 0), 4))
	t.set_stylebox("panel", "PopupMenu", box(panel_c, accent.darkened(0.3), Color(0, 0, 0, 0), 6))
	t.set_stylebox("hover", "PopupMenu", box(accent.darkened(0.5), Color(0, 0, 0, 0), Color(0, 0, 0, 0), 2, 0))
	t.set_color("font_color", "PopupMenu", text_c)
	t.set_stylebox("normal", "RichTextLabel", StyleBoxEmpty.new())
	t.set_color("default_color", "RichTextLabel", text_c)
	t.set_font("normal_font", "RichTextLabel", font)
	t.set_font_size("normal_font_size", "RichTextLabel", FONT_S)
	t.set_constant("separation", "VBoxContainer", 4)
	t.set_constant("separation", "HBoxContainer", 4)
	var sep := StyleBoxLine.new()
	sep.color = BEVEL
	sep.thickness = 2
	t.set_stylebox("separator", "HSeparator", sep)
	var sb := box(Color("#1a1310"), Color(0, 0, 0, 0), Color(0, 0, 0, 0), 0, 0)
	t.set_stylebox("scroll", "VScrollBar", sb)
	t.set_stylebox("grabber", "VScrollBar", box(BEVEL, Color(0, 0, 0, 0), Color(0, 0, 0, 0), 0, 0))
	t.set_stylebox("grabber_highlight", "VScrollBar", box(accent.darkened(0.3), Color(0, 0, 0, 0), Color(0, 0, 0, 0), 0, 0))
	t.set_stylebox("grabber_pressed", "VScrollBar", box(accent, Color(0, 0, 0, 0), Color(0, 0, 0, 0), 0, 0))
	return t


static func icon(id: String) -> AtlasTexture:
	var at := AtlasTexture.new()
	at.atlas = _icon_atlas()
	var k := AssetForge.icon_index(id)
	at.region = Rect2(k * AssetForge.ICON, 0, AssetForge.ICON, AssetForge.ICON)
	return at


static var _icons: ImageTexture


static func _icon_atlas() -> ImageTexture:
	if _icons == null:
		_icons = ImageTexture.create_from_image(AssetForge.build_icon_atlas())
	return _icons


static func label(text: String, variation: String = "") -> Label:
	var l := Label.new()
	l.text = text
	if variation != "":
		l.theme_type_variation = variation
	return l


static func icon_rect(id: String, px: int = 32) -> TextureRect:
	var r := TextureRect.new()
	r.texture = icon(id)
	r.custom_minimum_size = Vector2(px, px)
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	return r
