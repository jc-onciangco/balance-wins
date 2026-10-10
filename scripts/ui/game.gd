extends Control
## Game screen. Builds the whole interface in code and drives a MatchManager.
## Click a species in your Nest, then click a highlighted zone. Click your own
## unrevealed card to take it back. Press "End season" when done.

const MENU_SCENE := "res://main_menu.tscn"
const INK := UiKit.INK
const MUTED := UiKit.MUTED
const STRIP := UiKit.STRIP
const CARD_BG := UiKit.CARD_BG
const LINE := UiKit.LINE
const ACCENT := UiKit.ACCENT
const HILITE := UiKit.HILITE
const CARD_SIZE := UiKit.CARD_SIZE
const STATE_COLORS := UiKit.STATE_COLORS
const STATE_LABELS := UiKit.STATE_LABELS

var m := MatchManager.new()
var selected: int = -1
var _refresh_queued := false

var board_box: VBoxContainer
var hand_box: HFlowContainer
var log_label: RichTextLabel
var season_label: Label
var nutrient_label: Label
var info_label: Label
var end_button: Button
var overlay: PanelContainer
var overlay_text: RichTextLabel
var leave_dialog: ConfirmationDialog
var counts_label: Label
var choice_panel: PanelContainer
var choice_title: Label
var choice_cards: HFlowContainer
var choice_done: Button
var _choice: Dictionary = {}
var _lookout_marks: Array = []


func _ready() -> void:
	theme = UiKit.make_theme()
	_build_layout()
	m.player_community = UiKit.current_community(self)
	m.log_message.connect(_on_log)
	m.changed.connect(_queue_refresh)
	m.game_over.connect(_on_game_over)
	m.start()
	_do_refresh()


# ---------------------------------------------------------------- layout

func _build_layout() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	UiKit.add_background(self)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 8)
	margin.add_child(root)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 16)
	root.add_child(header)
	var menu_button := UiKit.button("Menu", 15, Vector2(90, 36))
	menu_button.pressed.connect(_on_menu)
	header.add_child(menu_button)
	header.add_child(_label("Balance Wins", 28, INK))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)
	season_label = _label("", 16, INK)
	header.add_child(season_label)
	counts_label = _label("", 13, MUTED)
	header.add_child(counts_label)
	nutrient_label = _label("", 16, ACCENT)
	header.add_child(nutrient_label)
	end_button = UiKit.button("End season", 15, Vector2(150, 36))
	end_button.pressed.connect(_on_end_turn)
	header.add_child(end_button)

	info_label = _label("", 13, MUTED)
	info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(info_label)

	var middle := HBoxContainer.new()
	middle.size_flags_vertical = Control.SIZE_EXPAND_FILL
	middle.add_theme_constant_override("separation", 12)
	root.add_child(middle)

	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	middle.add_child(scroll)
	board_box = VBoxContainer.new()
	board_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	board_box.add_theme_constant_override("separation", 10)
	scroll.add_child(board_box)

	var log_panel := PanelContainer.new()
	log_panel.custom_minimum_size = Vector2(300, 0)
	log_panel.add_theme_stylebox_override("panel", _box(CARD_BG, LINE, 12, 1, 10))
	middle.add_child(log_panel)
	log_label = RichTextLabel.new()
	log_label.bbcode_enabled = true
	log_label.scroll_following = true
	log_label.add_theme_font_size_override("normal_font_size", 13)
	log_label.add_theme_font_size_override("bold_font_size", 14)
	log_panel.add_child(log_label)

	root.add_child(_label("Your Nest", 15, MUTED))
	hand_box = HFlowContainer.new()
	hand_box.add_theme_constant_override("h_separation", 8)
	hand_box.add_theme_constant_override("v_separation", 8)
	hand_box.custom_minimum_size = Vector2(0, CARD_SIZE.y)
	root.add_child(hand_box)

	overlay = PanelContainer.new()
	overlay.custom_minimum_size = Vector2(520, 0)
	overlay.add_theme_stylebox_override("panel", _box(CARD_BG, ACCENT, 16, 3, 24))
	overlay.visible = false
	add_child(overlay)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	overlay.grow_horizontal = Control.GROW_DIRECTION_BOTH
	overlay.grow_vertical = Control.GROW_DIRECTION_BOTH
	var ov := VBoxContainer.new()
	ov.add_theme_constant_override("separation", 14)
	overlay.add_child(ov)
	overlay_text = RichTextLabel.new()
	overlay_text.bbcode_enabled = true
	overlay_text.fit_content = true
	overlay_text.custom_minimum_size = Vector2(470, 0)
	ov.add_child(overlay_text)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 10)
	ov.add_child(buttons)
	var again := UiKit.button("Play again", 16, Vector2(0, 44))
	again.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UiKit.make_primary(again)
	again.pressed.connect(_on_play_again)
	buttons.add_child(again)
	var to_menu := UiKit.button("Main menu", 16, Vector2(0, 44))
	to_menu.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	to_menu.pressed.connect(_go_to_menu)
	buttons.add_child(to_menu)

	leave_dialog = ConfirmationDialog.new()
	leave_dialog.title = "Leave match?"
	leave_dialog.dialog_text = "Return to the main menu? This match will be lost."
	leave_dialog.ok_button_text = "Leave match"
	leave_dialog.cancel_button_text = "Keep playing"
	leave_dialog.confirmed.connect(_go_to_menu)
	add_child(leave_dialog)

	choice_panel = PanelContainer.new()
	choice_panel.add_theme_stylebox_override("panel", _box(CARD_BG, HILITE, 16, 3, 20))
	choice_panel.visible = false
	add_child(choice_panel)
	choice_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	choice_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	choice_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	var cv := VBoxContainer.new()
	cv.add_theme_constant_override("separation", 12)
	choice_panel.add_child(cv)
	choice_title = _label("", 16, INK)
	choice_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	choice_title.custom_minimum_size = Vector2(440, 0)
	cv.add_child(choice_title)
	choice_cards = HFlowContainer.new()
	choice_cards.add_theme_constant_override("h_separation", 8)
	choice_cards.add_theme_constant_override("v_separation", 8)
	cv.add_child(choice_cards)
	choice_done = UiKit.button("Done", 15, Vector2(0, 40))
	UiKit.make_primary(choice_done)
	choice_done.pressed.connect(_on_choice_done)
	cv.add_child(choice_done)


# ---------------------------------------------------------------- refresh

func _queue_refresh() -> void:
	if _refresh_queued:
		return
	_refresh_queued = true
	call_deferred("_do_refresh")


func _do_refresh() -> void:
	_refresh_queued = false
	if board_box == null:
		return
	season_label.text = "Season %d of %d" % [m.season, MatchManager.SEASONS]
	nutrient_label.text = "Nutrients: %d" % int(m.nutrients[MatchManager.PLAYER])
	counts_label.text = "You: Seed Bank %d, Nest %d   Rival: Seed Bank %d, Nest %d" % [
		m.decks[0].size(), m.hands[0].size(), m.decks[1].size(), m.hands[1].size()]
	end_button.disabled = m.finished
	var no_moves := not m.finished and not _has_any_move()
	if no_moves:
		UiKit.make_primary(end_button)
		end_button.text = "End season ✓"
	else:
		for key in ["normal", "hover", "pressed", "focus"]:
			end_button.remove_theme_stylebox_override(key)
		for key in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
			end_button.remove_theme_color_override(key)
		end_button.text = "End season"
	if selected >= m.hands[MatchManager.PLAYER].size():
		selected = -1
	_clear(board_box)
	for ei in m.ecos.size():
		board_box.add_child(_build_ecosystem(ei))
	_clear(hand_box)
	var hand: Array = m.hands[MatchManager.PLAYER]
	for hi in hand.size():
		var data: CardData = hand[hi]
		var view := _card_view(data, data.biomass, {"selected": hi == selected, "dim": not _card_playable(data),
			"cost": m.display_cost(MatchManager.PLAYER, data)})
		view.gui_input.connect(_on_hand_input.bind(hi))
		hand_box.add_child(view)
	_update_info()
	_maybe_show_choice()


func _update_info() -> void:
	if m.finished:
		info_label.text = "Year's End. See the results, then play again."
	elif not _has_any_move() and selected < 0:
		info_label.text = "No more moves this season (Nutrients: %d). Press End season to reveal cards and continue." % int(m.nutrients[MatchManager.PLAYER])
	elif selected >= 0:
		var d: CardData = m.hands[MatchManager.PLAYER][selected]
		if d.is_pathogen():
			info_label.text = "%s %s (Pathogen, cost %d). %s  Click a highlighted rival species to infect it." % [
				d.emoji, d.display_name, d.cost, d.text]
		else:
			var homes: Array = []
			for eco in m.ecos:
				if not eco.revealed:
					continue
				for si in eco.zone_count():
					if Rules.slot_allows(eco, d, si, m.season):
						homes.append(eco.region.display_name)
						break
			var where := ("Can live in: " + ", ".join(PackedStringArray(homes))) if not homes.is_empty() else "No revealed ecosystem fits it yet."
			info_label.text = "%s %s (%s, %s; biomass %d). %s  %s." % [
				d.emoji, d.display_name, d.role, d.taxon, d.biomass, d.text, where]
	else:
		info_label.text = "Click a species in your Nest, then a highlighted zone. Click your unrevealed card to take it back. Each line needs at least 3 species and 3 roles, with Producers ≥ Herbivores ≥ Predators."


func _build_ecosystem(ei: int) -> Control:
	var eco: EcosystemState = m.ecos[ei]
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _box(STRIP, LINE, 14, 1, 12))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	panel.add_child(v)
	if not eco.revealed:
		var l := _label("Unexplored ecosystem: revealed in season %d" % (ei + 1), 16, MUTED)
		l.custom_minimum_size = Vector2(0, 70)
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		v.add_child(l)
		return panel

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	head.add_child(_label(eco.region.display_name, 20, INK))
	head.add_child(_label(eco.region.biome, 13, MUTED))
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(sp)
	var ey := Rules.evaluate(eco, MatchManager.PLAYER)
	var er := Rules.evaluate(eco, MatchManager.RIVAL)
	var totals := "You %d, rival %d" % [ey["total"], er["total"]]
	if m.finished:
		var w := Rules.resolve(eco)
		totals += "   " + ("You win this ecosystem" if w == 0 else ("Rival wins" if w == 1 else "Tie"))
	head.add_child(_label(totals, 13, MUTED))
	v.add_child(head)

	var notes: Array = [eco.region.requirement_text, eco.region.climate_text]
	if eco.region.twist_text != "":
		notes.append(eco.region.twist_text)
	var rules_label := _label("   ".join(PackedStringArray(notes)), 12, MUTED)
	rules_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(rules_label)

	var grid := GridContainer.new()
	grid.columns = eco.zone_count() + 2
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 4)
	grid.add_child(_side_label("Rival"))
	for si in eco.zone_count():
		grid.add_child(_slot_view(ei, MatchManager.RIVAL, si))
	grid.add_child(_pyramid(er))
	grid.add_child(Control.new())
	for si in eco.zone_count():
		grid.add_child(_zone_label(eco.region.zones[si]))
	grid.add_child(Control.new())
	grid.add_child(_side_label("You"))
	for si in eco.zone_count():
		grid.add_child(_slot_view(ei, MatchManager.PLAYER, si))
	grid.add_child(_pyramid(ey))
	v.add_child(grid)
	return panel


func _side_label(text: String) -> Control:
	var l := _label(text, 13, MUTED)
	l.custom_minimum_size = Vector2(48, 0)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	return l


func _zone_label(zone: Dictionary) -> Control:
	var bonus := ""
	match String(zone["kind"]):
		"all":
			bonus = "All +%d" % zone["amount"]
		"role", "trait":
			bonus = "%s +%d" % [zone["key"], zone["amount"]]
		"trait_any", "any_of":
			bonus = "%s +%d" % [" or ".join(PackedStringArray(zone["key"])), zone["amount"]]
	var l := _label("%s\n%s" % [zone["name"], bonus], 11, MUTED)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.custom_minimum_size = Vector2(CARD_SIZE.x, 0)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


func _slot_view(ei: int, side: int, si: int) -> Control:
	var eco: EcosystemState = m.ecos[ei]
	var ci := eco.card_at(side, si)
	if ci != null:
		var badges: Array = []
		var extra: Array = []
		if ci.infection != null:
			badges.append("%s %s" % [ci.infection.emoji, ci.infection.display_name])
			extra.append("Infected: %s" % ci.infection.text)
		var queued: CardData = null
		if side == MatchManager.RIVAL:
			queued = m.pending_infection(MatchManager.PLAYER, ei, si)
			if queued != null:
				badges.append("Pending: %s" % queued.display_name)
				extra.append("Click to take back your %s." % queued.display_name)
		for d in ci.merged:
			badges.append("+ %s" % d.display_name)
		if not ci.merged.is_empty():
			extra.append("Merged: " + ", ".join(PackedStringArray(ci.merged.map(func(x): return x.display_name))))
		if not ci.extra_roles.is_empty():
			extra.append("Extra roles: " + ", ".join(PackedStringArray(ci.extra_roles)))
		if Rules.ci_has(ci, "resilient"):
			extra.append("Resilient (granted).")
		var mig := Rules.ability_args(ci.data, "migratory_season")
		var tag := ""
		if mig.size() > 1:
			tag = "Migr. S" + mig[1].replace(",", "/")
		elif Rules.has_ability(ci.data, "migratory_dusk"):
			tag = "Migratory"
		var target_ok := side == MatchManager.RIVAL and selected >= 0 \
			and m.can_infect(MatchManager.PLAYER, m.hands[MatchManager.PLAYER][selected], ei, si)
		var opts := {"resident": ci.resident, "pending": not ci.revealed,
			"cost": Rules.effective_cost(ci.data, eco), "badges": badges, "extra": extra, "selected": target_ok}
		if target_ok:
			opts["tag_override"] = "Infect"
		elif tag != "":
			opts["tag_override"] = tag
		var view := _card_view(ci.data, ci.value, opts)
		if side == MatchManager.PLAYER and not ci.revealed:
			view.gui_input.connect(_on_pending_input.bind(ei, si))
		elif side == MatchManager.RIVAL:
			view.gui_input.connect(_on_rival_input.bind(ei, si))
		return view
	var b := Button.new()
	b.custom_minimum_size = CARD_SIZE
	b.add_theme_font_size_override("font_size", 11)
	var can := side == MatchManager.PLAYER and selected >= 0 \
		and m.can_place(MatchManager.PLAYER, m.hands[MatchManager.PLAYER][selected], ei, si)
	var text := ""
	var zone: Dictionary = eco.region.zones[si]
	if int(zone.get("locked_until", 0)) > m.season:
		text = "Locked until\nseason %d" % int(zone["locked_until"])
	if eco.succession[side][si]:
		text = "Succession\n+2"
	if can:
		text = "Place here"
	elif side == MatchManager.PLAYER and selected >= 0:
		var why := m.block_reason(MatchManager.PLAYER, m.hands[MatchManager.PLAYER][selected], ei, si)
		if why != "":
			text = why
	b.text = text
	b.disabled = not can
	var normal := _box(Color(1, 1, 1, 0.3), LINE, 10, 1, 4)
	var hot := _box(Color(1, 0.97, 0.88), HILITE, 10, 3, 4)
	b.add_theme_stylebox_override("normal", hot if can else normal)
	b.add_theme_stylebox_override("hover", hot)
	b.add_theme_stylebox_override("pressed", hot)
	b.add_theme_stylebox_override("disabled", normal)
	b.add_theme_stylebox_override("focus", hot)
	b.add_theme_color_override("font_color", INK)
	b.add_theme_color_override("font_hover_color", INK)
	b.add_theme_color_override("font_disabled_color", MUTED)
	b.pressed.connect(_on_slot_pressed.bind(ei, si))
	return b


func _card_view(data: CardData, value: int, opts: Dictionary) -> Control:
	var o := opts.duplicate()
	if o.has("tag_override"):
		o["tag"] = o["tag_override"]
	elif o.get("resident", false):
		o["tag"] = "Resident"
	elif o.get("pending", false):
		o["tag"] = "Pending"
	return UiKit.card_view(data, value, o)


func _card_playable(data: CardData) -> bool:
	for ei in m.ecos.size():
		for si in m.ecos[ei].zone_count():
			if data.is_pathogen():
				if m.can_infect(MatchManager.PLAYER, data, ei, si):
					return true
			elif m.can_place(MatchManager.PLAYER, data, ei, si):
				return true
	return false


func _has_any_move() -> bool:
	for data in m.hands[MatchManager.PLAYER]:
		if _card_playable(data):
			return true
	return false


func _pyramid(ev: Dictionary) -> Control:
	var v := VBoxContainer.new()
	v.custom_minimum_size = Vector2(100, 0)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 2)
	var state: String = ev["state"]
	if state == "hidden":
		return v
	var col: Color = STATE_COLORS.get(state, MUTED)
	var tiers := [
		["Predators", ev["D"], 44, ev["fail_chain"]],
		["Herbivores", ev["H"], 66, ev["fail_foundation"]],
		["Producers", ev["P"], 88, false],
	]
	for t in tiers:
		var pc := PanelContainer.new()
		pc.custom_minimum_size = Vector2(t[2], 20)
		pc.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		pc.add_theme_stylebox_override("panel", _box(col, INK if t[3] else col, 4, 2 if t[3] else 0, 1))
		pc.tooltip_text = "%s: %d" % [t[0], t[1]]
		var l := _label(str(t[1]), 11, Color.WHITE)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		pc.add_child(l)
		v.add_child(pc)
	var lab := _label(STATE_LABELS.get(state, ""), 12, col)
	lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(lab)
	if state == "collapsed":
		var why: Array = []
		if ev["fail_min"]:
			why.append("needs 3 species / roles")
		if ev["fail_foundation"]:
			why.append("too few producers")
		if ev["fail_chain"]:
			why.append("predators too heavy")
		if ev["fail_req"]:
			why.append("biome rule")
		var w := _label(", ".join(PackedStringArray(why)), 10, MUTED)
		w.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		w.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		w.custom_minimum_size = Vector2(100, 0)
		v.add_child(w)
	return v


# ---------------------------------------------------------------- helpers

func _label(text: String, size: int, color: Color) -> Label:
	return UiKit.label(text, size, color)


func _box(bg: Color, border: Color, radius: int, border_w: int, pad: int = 8) -> StyleBoxFlat:
	return UiKit.box(bg, border, radius, border_w, pad)


func _clear(node: Node) -> void:
	UiKit.clear(node)


# ---------------------------------------------------------------- input

func _is_click(ev: InputEvent) -> bool:
	return UiKit.is_click(ev)


func _on_hand_input(ev: InputEvent, hi: int) -> void:
	if _is_click(ev) and not m.finished:
		selected = -1 if selected == hi else hi
		_queue_refresh()


func _on_slot_pressed(ei: int, si: int) -> void:
	if selected >= 0 and m.place(MatchManager.PLAYER, selected, ei, si):
		selected = -1
	_queue_refresh()


func _on_pending_input(ev: InputEvent, ei: int, si: int) -> void:
	if _is_click(ev):
		m.unplace(MatchManager.PLAYER, ei, si)
		_queue_refresh()


func _on_rival_input(ev: InputEvent, ei: int, si: int) -> void:
	if not _is_click(ev) or m.finished:
		return
	if selected >= 0 and m.hands[MatchManager.PLAYER][selected].is_pathogen():
		if m.infect(MatchManager.PLAYER, selected, ei, si):
			selected = -1
	elif m.pending_infection(MatchManager.PLAYER, ei, si) != null:
		m.uninfect(MatchManager.PLAYER, ei, si)
	_queue_refresh()


# ---------------------------------------------------------------- choices (Recruit, Lookout)

func _maybe_show_choice() -> void:
	if choice_panel.visible or m.finished:
		return
	for c in m.pending_choices:
		if c["side"] == MatchManager.PLAYER:
			_show_choice(c)
			return


func _show_choice(c: Dictionary) -> void:
	_choice = c
	_lookout_marks = []
	_clear(choice_cards)
	if c["kind"] == "recruit":
		choice_title.text = "%s: Recruit a %s from your Seed Bank. Click the species you want." % [c["source"], c["type"]]
		choice_done.visible = false
		for d in c["options"]:
			var view := UiKit.card_view(d, d.biomass)
			view.gui_input.connect(_on_choice_card.bind(d))
			choice_cards.add_child(view)
	else:
		choice_title.text = "%s: these are the top species of your Seed Bank (next draw first). Click any to send them to the bottom, then press Done." % c["source"]
		choice_done.visible = true
		_render_lookout()
	choice_panel.visible = true


func _render_lookout() -> void:
	_clear(choice_cards)
	for d in _choice["options"]:
		var marked := _lookout_marks.has(d)
		var view := UiKit.card_view(d, d.biomass, {"tag": "To bottom" if marked else "Keep", "dim": marked})
		view.gui_input.connect(_on_choice_card.bind(d))
		choice_cards.add_child(view)


func _on_choice_card(ev: InputEvent, d: CardData) -> void:
	if not _is_click(ev) or _choice.is_empty():
		return
	if _choice["kind"] == "recruit":
		var c := _choice
		_choice = {}
		choice_panel.visible = false
		m.resolve_recruit(c, d)
		_queue_refresh()
	else:
		if _lookout_marks.has(d):
			_lookout_marks.erase(d)
		else:
			_lookout_marks.append(d)
		_render_lookout.call_deferred()


func _on_choice_done() -> void:
	if _choice.is_empty():
		return
	var c := _choice
	_choice = {}
	choice_panel.visible = false
	m.resolve_lookout(c, _lookout_marks.duplicate())
	_queue_refresh()


func _on_end_turn() -> void:
	selected = -1
	m.end_turn()
	_queue_refresh()


func _on_log(text: String) -> void:
	if log_label != null:
		log_label.append_text(text + "\n")


func _on_game_over(res: Dictionary) -> void:
	var lines: Array = []
	var w: int = res["winner"]
	var title := "It's a draw."
	if w == MatchManager.PLAYER:
		title = "You win!"
	elif w == MatchManager.RIVAL:
		title = "The rival wins."
	lines.append("[font_size=28][b]%s[/b][/font_size]" % title)
	lines.append("Decided by %s." % res["reason"])
	lines.append("")
	for e in res["ecosystems"]:
		var who := "Tie"
		if e["winner"] == 0:
			who = "You"
		elif e["winner"] == 1:
			who = "Rival"
		lines.append("[b]%s[/b]: %s  (you: %s, %d; rival: %s, %d)" % [
			e["name"], who, STATE_LABELS[e["you"]["state"]], e["you"]["total"],
			STATE_LABELS[e["rival"]["state"]], e["rival"]["total"]])
	overlay_text.text = "\n".join(PackedStringArray(lines))
	overlay.visible = true


func _on_play_again() -> void:
	overlay.visible = false
	choice_panel.visible = false
	_choice = {}
	selected = -1
	log_label.clear()
	m.start()
	_do_refresh()


func _on_menu() -> void:
	if m.finished:
		_go_to_menu()
	else:
		leave_dialog.popup_centered()


func _go_to_menu() -> void:
	get_tree().change_scene_to_file(MENU_SCENE)
