extends SceneTree
## Renders the game with a pathogen selected and a tooltip showing (needs a display).

var scene: Node
var frame := 0
var hover_pos := Vector2.ZERO


func _initialize() -> void:
	scene = load("res://game.tscn").instantiate()
	root.add_child(scene)


func _process(_d: float) -> bool:
	frame += 1
	if frame == 5:
		var m: MatchManager = scene.m
		scene.log_label.clear()
		m.rival_community = PackedStringArray(["grass", "rabbit", "zebra", "lion", "fox", "oak", "myc", "worm", "moss", "phyto", "kit_dummy", "bee"])
		m.rival_community = PackedStringArray(["grass", "rabbit", "zebra", "lion", "fox", "oak", "myc", "worm", "moss", "phyto", "wolf", "bee"])
		m.player_community = PackedStringArray(["grass", "oak", "moss", "rabbit", "zebra", "fox", "myc", "lichen", "walnut", "frog", "rabies", "blight"])
		m.start(11)
		var ai := RivalAI.new()
		for i in 2:
			ai.plan(m, 0)
			m.end_turn()
		ai.plan(m, 0)
		m.hands[0].append(CardLibrary.get_card("rabies"))
		m.nutrients[0] = 3
		scene.selected = m.hands[0].size() - 1
		scene._do_refresh()
	if frame == 30:
		# find a rival card and hover it
		var cards: Array = scene.board_box.find_children("*", "PanelContainer", true, false)
		for c in cards:
			if c.tooltip_text.begins_with("🐇") or c.tooltip_text.find("Mammal") > 0:
				hover_pos = c.get_global_rect().get_center()
				break
		var ev := InputEventMouseMotion.new()
		ev.position = hover_pos
		ev.global_position = hover_pos
		root.push_input(ev)
	if frame == 90:
		root.get_texture().get_image().save_png("res://docs/pathogen_tooltip.png")
		print("saved; hovered at ", hover_pos)
		return true
	return false
