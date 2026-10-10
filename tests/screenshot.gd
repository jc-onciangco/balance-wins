extends SceneTree
## Renders the menu, collection and game screens to PNGs (needs a display, e.g. xvfb-run).

var scene: Node
var frame := 0


func _initialize() -> void:
	_show("res://main_menu.tscn")


func _show(path: String) -> void:
	if scene != null:
		root.remove_child(scene)
		scene.queue_free()
	scene = load(path).instantiate()
	root.add_child(scene)


func _save(name: String) -> void:
	root.get_texture().get_image().save_png("res://docs/%s.png" % name)
	print("saved ", name)


func _process(_delta: float) -> bool:
	frame += 1
	match frame:
		30:
			_save("menu")
			_show("res://collection.tscn")
		60:
			_save("collection")
			_show("res://game.tscn")
		64:
			var m: MatchManager = scene.m
			scene.log_label.clear()
			m.start(7)
			var ai := RivalAI.new()
			for i in 3:
				ai.plan(m, 0)
				m.end_turn()
			ai.plan(m, 0)
			scene._do_refresh()
		95:
			_save("screenshot")
			return true
	return false
