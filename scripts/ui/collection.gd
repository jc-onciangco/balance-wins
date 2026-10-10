extends Control
## Collection: browse every species and choose the 12 that make up your Community.
## Changes save automatically whenever the Community has exactly 12 species.

const MENU_SCENE := "res://main_menu.tscn"
const SIZE := 12
const FILTERS := [
	["All", []],
	["Producers", ["Producer"]],
	["Herbivores", ["Herbivore", "Omnivore"]],
	["Predators", ["Predator"]],
	["Decomposers", ["Decomposer"]],
	["Support", ["Pollinator", "Symbiont"]],
	["Parasites", ["Parasite"]],
	["Pathogens", ["Pathogen"]],
]

var working: Array = []
var filter_index := 0

var count_label: Label
var status_label: Label
var summary_label: Label
var info_label: Label
var community_box: HFlowContainer
var collection_box: HFlowContainer
var filter_buttons: Array = []
var leave_dialog: ConfirmationDialog


func _ready() -> void:
	theme = UiKit.make_theme()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	UiKit.add_background(self)
	for id in UiKit.current_community(self):
		working.append(id)
	_build()
	_refresh()


func _build() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 18)
	add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	margin.add_child(root)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 14)
	root.add_child(header)
	var back := UiKit.button("Back", 15, Vector2(96, 38))
	back.pressed.connect(_on_back)
	header.add_child(back)
	header.add_child(UiKit.label("Collection", 28, UiKit.INK))
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(sp)
	status_label = UiKit.label("", 14, UiKit.MUTED)
	header.add_child(status_label)
	var reset := UiKit.button("Use starter set", 14, Vector2(150, 38))
	reset.pressed.connect(_on_reset)
	header.add_child(reset)
	var clear_btn := UiKit.button("Clear", 14, Vector2(90, 38))
	clear_btn.pressed.connect(_on_clear)
	header.add_child(clear_btn)

	root.add_child(UiKit.label("Choose 12 different cards for your Community (at most 2 Pathogens). Click a card below to add it; click a card in your Community to remove it.", 13, UiKit.MUTED))

	var cpanel := PanelContainer.new()
	cpanel.add_theme_stylebox_override("panel", UiKit.box(UiKit.STRIP, UiKit.LINE, 14, 1, 12))
	root.add_child(cpanel)
	var cv := VBoxContainer.new()
	cv.add_theme_constant_override("separation", 8)
	cpanel.add_child(cv)
	var chead := HBoxContainer.new()
	chead.add_theme_constant_override("separation", 12)
	cv.add_child(chead)
	chead.add_child(UiKit.label("Your Community", 18, UiKit.INK))
	count_label = UiKit.label("", 18, UiKit.ACCENT)
	chead.add_child(count_label)
	var sp2 := Control.new()
	sp2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chead.add_child(sp2)
	summary_label = UiKit.label("", 13, UiKit.MUTED)
	chead.add_child(summary_label)
	community_box = HFlowContainer.new()
	community_box.add_theme_constant_override("h_separation", 8)
	community_box.add_theme_constant_override("v_separation", 8)
	cv.add_child(community_box)

	var filters := HBoxContainer.new()
	filters.add_theme_constant_override("separation", 6)
	root.add_child(filters)
	filters.add_child(UiKit.label("All species", 18, UiKit.INK))
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(12, 0)
	filters.add_child(gap)
	var group := ButtonGroup.new()
	for i in FILTERS.size():
		var fb := UiKit.button(FILTERS[i][0], 13, Vector2(0, 32))
		fb.toggle_mode = true
		fb.button_group = group
		fb.button_pressed = i == filter_index
		var on := UiKit.box(UiKit.ACCENT, UiKit.ACCENT, 10, 1, 10)
		fb.add_theme_stylebox_override("pressed", on)
		fb.add_theme_stylebox_override("hover_pressed", on)
		fb.add_theme_color_override("font_pressed_color", UiKit.CARD_BG)
		fb.add_theme_color_override("font_hover_pressed_color", UiKit.CARD_BG)
		fb.pressed.connect(_on_filter.bind(i))
		filters.add_child(fb)
		filter_buttons.append(fb)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(scroll)
	collection_box = HFlowContainer.new()
	collection_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	collection_box.add_theme_constant_override("h_separation", 8)
	collection_box.add_theme_constant_override("v_separation", 8)
	scroll.add_child(collection_box)

	info_label = UiKit.label("Hover a card to read its abilities.", 13, UiKit.MUTED)
	info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(info_label)

	leave_dialog = ConfirmationDialog.new()
	leave_dialog.title = "Community not complete"
	leave_dialog.ok_button_text = "Leave without saving"
	leave_dialog.cancel_button_text = "Keep editing"
	leave_dialog.confirmed.connect(_go_to_menu)
	add_child(leave_dialog)


func _refresh() -> void:
	count_label.text = "%d / %d" % [working.size(), SIZE]
	_update_status()
	summary_label.text = _role_summary()

	UiKit.clear(community_box)
	for i in SIZE:
		if i < working.size():
			var data := CardLibrary.get_card(working[i])
			var view := UiKit.card_view(data, data.biomass, {"tag": "Remove"})
			view.gui_input.connect(_on_community_input.bind(working[i]))
			view.mouse_entered.connect(_show_info.bind(data))
			community_box.add_child(view)
		else:
			var empty := PanelContainer.new()
			empty.custom_minimum_size = UiKit.CARD_SIZE
			empty.add_theme_stylebox_override("panel", UiKit.box(Color(1, 1, 1, 0.3), UiKit.LINE, 10, 1, 4))
			var l := UiKit.label("Empty", 11, UiKit.MUTED)
			l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			empty.add_child(l)
			community_box.add_child(empty)

	UiKit.clear(collection_box)
	var roles: Array = FILTERS[filter_index][1]
	for data in CardLibrary.collection():
		if not roles.is_empty() and not roles.has(data.role):
			continue
		var chosen := working.has(data.id)
		var view := UiKit.card_view(data, data.biomass, {
			"selected": chosen,
			"tag": "In Community" if chosen else "",
			"dim": not chosen and (working.size() >= SIZE or (data.is_pathogen() and _pathogen_count() >= CardLibrary.MAX_PATHOGENS)),
		})
		view.gui_input.connect(_on_collection_input.bind(data.id))
		view.mouse_entered.connect(_show_info.bind(data))
		collection_box.add_child(view)


func _update_status() -> void:
	var n := working.size()
	if n == SIZE:
		status_label.text = "Saved. Ready to play."
		status_label.add_theme_color_override("font_color", UiKit.ACCENT)
	elif n < SIZE:
		status_label.text = "Add %d more to save" % (SIZE - n)
		status_label.add_theme_color_override("font_color", UiKit.MUTED)
	else:
		status_label.text = "Too many species"
		status_label.add_theme_color_override("font_color", UiKit.STATE_COLORS["collapsed"])


func _role_summary() -> String:
	var counts := {"Producer": 0, "Herbivore": 0, "Predator": 0, "Decomposer": 0, "Support": 0, "Parasite": 0, "Pathogen": 0}
	for id in working:
		var r := CardLibrary.get_card(id).role
		match r:
			"Omnivore":
				r = "Herbivore"
			"Pollinator", "Symbiont":
				r = "Support"
		counts[r] += 1
	var parts: Array = []
	for k in counts:
		parts.append("%s %d" % [k, counts[k]])
	var text := "   ".join(PackedStringArray(parts))
	if working.size() > 0 and counts["Producer"] == 0:
		text += "   (no producers: you can't balance!)"
	return text


func _pathogen_count() -> int:
	var n := 0
	for id in working:
		if CardLibrary.get_card(id).is_pathogen():
			n += 1
	return n


func _save_if_complete() -> void:
	if working.size() != SIZE:
		return
	var gs := UiKit.game_state(self)
	if gs != null:
		gs.save_community(PackedStringArray(working))


func _show_info(data: CardData) -> void:
	info_label.text = UiKit.describe(data).replace("\n", "   ")


func _on_collection_input(ev: InputEvent, id: String) -> void:
	if not UiKit.is_click(ev):
		return
	if working.has(id):
		working.erase(id)
	elif working.size() >= SIZE:
		info_label.text = "Your Community is full. Remove a species first."
		return
	elif CardLibrary.get_card(id).is_pathogen() and _pathogen_count() >= CardLibrary.MAX_PATHOGENS:
		info_label.text = "A Community can include at most 2 Pathogens. Remove one first."
		return
	else:
		working.append(id)
	_save_if_complete()
	_refresh.call_deferred()


func _on_community_input(ev: InputEvent, id: String) -> void:
	if UiKit.is_click(ev):
		working.erase(id)
		_refresh.call_deferred()


func _on_filter(i: int) -> void:
	filter_index = i
	_refresh.call_deferred()


func _on_reset() -> void:
	working.clear()
	for id in CardLibrary.player_community():
		working.append(id)
	_save_if_complete()
	_refresh.call_deferred()


func _on_clear() -> void:
	working.clear()
	_refresh.call_deferred()


func _on_back() -> void:
	if working.size() == SIZE:
		_save_if_complete()
		_go_to_menu()
	else:
		leave_dialog.dialog_text = "Your Community has %d of 12 species, so these changes won't be saved.\nYour last saved Community will be used." % working.size()
		leave_dialog.popup_centered()


func _go_to_menu() -> void:
	get_tree().change_scene_to_file(MENU_SCENE)
