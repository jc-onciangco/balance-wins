class_name UiKit
extends RefCounted
## Shared colors, theme and widgets used by the menu, collection and game screens.

const INK := Color("17271f")
const MUTED := Color("56685c")
const BG := Color("e4ebe0")
const STRIP := Color("d7e1d2")
const CARD_BG := Color("fbfcf8")
const PENDING_BG := Color("eef3e8")
const LINE := Color("bccab8")
const ACCENT := Color("2c6a4d")
const ACCENT_HOVER := Color("245a41")
const HILITE := Color("e5a41a")
const CARD_SIZE := Vector2(100, 132)

const ROLE_COLORS := {
	"Producer": Color("3b8a3e"), "Herbivore": Color("b0731a"), "Predator": Color("b33838"),
	"Omnivore": Color("a0602a"), "Decomposer": Color("7a5634"), "Pollinator": Color("24758a"),
	"Symbiont": Color("24758a"), "Parasite": Color("7a4c9f"), "Pathogen": Color("9b2c4a"),
}
const DANGER := Color("9b2c4a")
const STATE_COLORS := {
	"balanced": Color("2e8b57"), "at_risk": Color("c98a12"), "collapsed": Color("be3f35"),
	"empty": Color("9aa89c"), "hidden": Color("9aa89c"),
}
const STATE_LABELS := {
	"balanced": "Balanced", "at_risk": "At risk", "collapsed": "Collapsed", "empty": "Empty", "hidden": "",
}


static func make_theme() -> Theme:
	var t := Theme.new()
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Noto Sans", "Segoe UI", "Helvetica Neue", "Arial", "Sans-Serif"])
	var emoji := SystemFont.new()
	emoji.font_names = PackedStringArray(["Noto Color Emoji", "Apple Color Emoji", "Segoe UI Emoji", "Twemoji Mozilla"])
	var fallbacks: Array[Font] = [emoji]
	font.fallbacks = fallbacks
	t.default_font = font
	t.default_font_size = 14
	t.set_color("font_color", "Label", INK)
	t.set_color("default_color", "RichTextLabel", INK)
	t.set_stylebox("normal", "Button", box(CARD_BG, LINE, 10, 1, 10))
	t.set_stylebox("hover", "Button", box(Color("f3f7ef"), ACCENT, 10, 2, 10))
	t.set_stylebox("pressed", "Button", box(Color("e3ecdf"), ACCENT, 10, 2, 10))
	t.set_stylebox("focus", "Button", box(Color(0, 0, 0, 0), HILITE, 10, 2, 10))
	t.set_stylebox("disabled", "Button", box(Color(1, 1, 1, 0.35), LINE, 10, 1, 10))
	t.set_color("font_color", "Button", INK)
	t.set_color("font_hover_color", "Button", INK)
	t.set_color("font_pressed_color", "Button", INK)
	t.set_color("font_focus_color", "Button", INK)
	t.set_color("font_disabled_color", "Button", MUTED)
	t.set_color("font_hover_pressed_color", "Button", INK)
	# Tooltips: opaque dark panel with light text so descriptions are easy to read.
	t.set_stylebox("panel", "TooltipPanel", box(INK, ACCENT, 8, 1, 12))
	t.set_color("font_color", "TooltipLabel", CARD_BG)
	t.set_color("font_shadow_color", "TooltipLabel", Color(0, 0, 0, 0))
	t.set_font_size("font_size", "TooltipLabel", 14)
	return t


## Filled green button for the main action on a screen.
static func make_primary(b: Button) -> void:
	b.add_theme_stylebox_override("normal", box(ACCENT, ACCENT, 10, 1, 10))
	b.add_theme_stylebox_override("hover", box(ACCENT_HOVER, ACCENT_HOVER, 10, 1, 10))
	b.add_theme_stylebox_override("pressed", box(ACCENT_HOVER, HILITE, 10, 2, 10))
	b.add_theme_stylebox_override("focus", box(Color(0, 0, 0, 0), HILITE, 10, 3, 10))
	for key in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		b.add_theme_color_override(key, CARD_BG)


static func button(text: String, font_size: int = 15, min_size: Vector2 = Vector2(0, 38)) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = min_size
	b.add_theme_font_size_override("font_size", font_size)
	return b


static func label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


static func box(bg: Color, border: Color, radius: int, border_w: int, pad: int = 8) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(border_w)
	sb.set_corner_radius_all(radius)
	sb.set_content_margin_all(pad)
	return sb


static func add_background(parent: Control) -> void:
	var bg := ColorRect.new()
	bg.color = BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(bg)


static func clear(node: Node) -> void:
	for c in node.get_children():
		node.remove_child(c)
		c.queue_free()


## The GameState autoload, or null when running without it (e.g. headless tests).
static func game_state(from: Node) -> Node:
	return from.get_node_or_null("/root/GameState")


static func current_community(from: Node) -> PackedStringArray:
	var gs := game_state(from)
	if gs != null and CardLibrary.is_valid_community(gs.community):
		return gs.community
	return CardLibrary.player_community()


## A species card. opts: cost, tag, selected, pending, dim, badges (Array of strings), extra (tooltip lines)
static func card_view(data: CardData, value: int, opts: Dictionary = {}) -> PanelContainer:
	var p := PanelContainer.new()
	p.custom_minimum_size = CARD_SIZE
	p.mouse_filter = Control.MOUSE_FILTER_STOP
	var col: Color = ROLE_COLORS.get(data.role, MUTED)
	var sb := box(PENDING_BG if opts.get("pending", false) else CARD_BG, col, 10, 2, 6)
	sb.border_width_top = 6
	if opts.get("selected", false):
		sb.border_color = HILITE
		sb.set_border_width_all(4)
	p.add_theme_stylebox_override("panel", sb)
	if opts.get("dim", false):
		p.modulate = Color(1, 1, 1, 0.5)

	var v := VBoxContainer.new()
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_theme_constant_override("separation", 0)
	p.add_child(v)

	var top := HBoxContainer.new()
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(label(str(opts.get("cost", data.cost)), 12, MUTED))
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(sp)
	top.add_child(label(String(opts.get("tag", "")), 10, MUTED))
	v.add_child(top)

	var em := label(data.emoji, 30, INK)
	em.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(em)
	var nm := label(data.display_name, 11, INK)
	nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nm.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	nm.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(nm)
	var badges: Array = opts.get("badges", [])
	if not badges.is_empty():
		var bl := label("\n".join(PackedStringArray(badges)), 9, DANGER)
		bl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		bl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(bl)

	var bottom := HBoxContainer.new()
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom.add_child(label(data.role, 10, col))
	var sp2 := Control.new()
	sp2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sp2.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom.add_child(sp2)
	bottom.add_child(label("" if data.is_pathogen() else str(value), 18, col))
	v.add_child(bottom)

	var tip := describe(data)
	var extra: Array = opts.get("extra", [])
	if not extra.is_empty():
		tip += "\n\n" + "\n".join(PackedStringArray(extra))
	p.tooltip_text = tip
	return p


static func describe(data: CardData) -> String:
	if data.is_pathogen():
		return "%s %s\nPathogen (%s), cost %d\n%s" % [data.emoji, data.display_name, data.taxon, data.cost, data.text]
	var traits := ", ".join(data.traits)
	return "%s %s\n%s, %s%s\nCost %d, base biomass %d%s\n%s" % [
		data.emoji, data.display_name, data.role, data.taxon,
		(" (%s)" % traits) if traits != "" else "",
		data.cost, data.biomass,
		("\nNative: %s" % data.native_biome) if data.native_biome != "" else "",
		data.text]


static func is_click(ev: InputEvent) -> bool:
	return ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT
