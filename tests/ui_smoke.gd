extends SceneTree
## UI smoke test: loads the main scene, plays a full match through the UI handlers.
## Run: godot --headless --path . --script res://tests/ui_smoke.gd

var main: Control
var frame := 0
var placed := 0


func _initialize() -> void:
	main = load("res://game.tscn").instantiate()
	root.add_child(main)


func _process(_delta: float) -> bool:
	frame += 1
	if frame < 3:
		return false
	var m: MatchManager = main.m
	if m.finished:
		print("UI smoke: match finished. Player placed ", placed, " cards. Winner: ", m.results["winner"],
			" (", m.results["reason"], ")")
		print("Board children: ", main.board_box.get_child_count(), "  overlay visible: ", main.overlay.visible)
		return true
	# Place the first card that fits anywhere, through the UI handlers.
	var did := false
	for hi in m.hands[0].size():
		for ei in m.ecos.size():
			for si in m.ecos[ei].zone_count():
				if not did and m.can_place(0, m.hands[0][hi], ei, si):
					main.selected = hi
					main._do_refresh()
					main._on_slot_pressed(ei, si)
					placed += 1
					did = true
	if not did:
		main._on_end_turn()
	main._do_refresh()
	return false
