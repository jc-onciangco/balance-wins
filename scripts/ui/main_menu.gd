extends Control
## Title screen: Play, Collection, Exit.

const GAME_SCENE := "res://game.tscn"
const COLLECTION_SCENE := "res://collection.tscn"

var play_button: Button
var collection_button: Button
var exit_button: Button


func _ready() -> void:
	theme = UiKit.make_theme()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	UiKit.add_background(self)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var v := VBoxContainer.new()
	v.custom_minimum_size = Vector2(380, 0)
	v.add_theme_constant_override("separation", 14)
	center.add_child(v)

	var critters := UiKit.label("🌱  🐇  🦊  🍄  🐝", 34, UiKit.INK)
	critters.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(critters)
	var title := UiKit.label("Balance Wins", 60, UiKit.INK)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(title)
	var tagline := UiKit.label("Build thriving ecosystems. Collapse your rival's.", 17, UiKit.MUTED)
	tagline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(tagline)

	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 18)
	v.add_child(gap)

	play_button = UiKit.button("Play", 22, Vector2(380, 60))
	UiKit.make_primary(play_button)
	play_button.pressed.connect(_on_play)
	v.add_child(play_button)

	collection_button = UiKit.button("Collection", 20, Vector2(380, 54))
	collection_button.pressed.connect(_on_collection)
	v.add_child(collection_button)

	exit_button = UiKit.button("Exit", 20, Vector2(380, 54))
	exit_button.pressed.connect(_on_exit)
	v.add_child(exit_button)

	var community := UiKit.current_community(self)
	var status := UiKit.label("Your Community: %d species ready" % community.size(), 13, UiKit.MUTED)
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(status)

	play_button.grab_focus.call_deferred()


func _on_play() -> void:
	get_tree().change_scene_to_file(GAME_SCENE)


func _on_collection() -> void:
	get_tree().change_scene_to_file(COLLECTION_SCENE)


func _on_exit() -> void:
	get_tree().quit()
