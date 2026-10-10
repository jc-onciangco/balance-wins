extends SceneTree
## Menu + collection smoke test: builds a Community through the Collection screen,
## then starts a match with it. Run: godot --headless --path . --script res://tests/menu_smoke.gd

var step := 0
var scene: Node


func _initialize() -> void:
	scene = load("res://main_menu.tscn").instantiate()
	root.add_child(scene)


func _swap(path: String) -> void:
	root.remove_child(scene)
	scene.queue_free()
	scene = load(path).instantiate()
	root.add_child(scene)


func _process(_d: float) -> bool:
	step += 1
	match step:
		3:
			print("menu buttons: ", scene.play_button.text, ", ", scene.collection_button.text, ", ", scene.exit_button.text)
			_swap("res://collection.tscn")
		6:
			var c = scene
			c._on_clear()
			# pick the first 12 non-parasite species
			for data in CardLibrary.collection():
				if c.working.size() < 12 and data.role != "Parasite":
					c.working.append(data.id)
			c._refresh()
			print("collection cards shown: ", c.collection_box.get_child_count(), "  community: ", c.working.size(), "  status: ", c.status_label.text)
			print("summary: ", c.summary_label.text)
			for i in c.FILTERS.size():
				c._on_filter(i)
				c._refresh()
			var chosen := PackedStringArray(c.working)
			print("valid community: ", CardLibrary.is_valid_community(chosen))
			_swap("res://game.tscn")
			scene.m.player_community = chosen
			scene._on_play_again()
			var hand_ids := []
			for d in scene.m.hands[0]:
				hand_ids.append(d.id)
			var ok := true
			for id in hand_ids:
				if not chosen.has(id) and not CardLibrary.get_card(id).token:
					ok = false
			print("hand drawn from chosen community: ", ok, " ", hand_ids)
		9:
			scene._do_refresh()
			print("end button: ", scene.end_button.text, "  info: ", scene.info_label.text.substr(0, 60))
			return true
	return false
