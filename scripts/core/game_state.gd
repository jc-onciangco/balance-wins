extends Node
## Autoload "GameState": remembers the player's Community between sessions.

const SAVE_PATH := "user://community.cfg"

var community: PackedStringArray = PackedStringArray()


func _ready() -> void:
	load_community()


func load_community() -> void:
	community = CardLibrary.player_community()
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) == OK:
		var saved: PackedStringArray = PackedStringArray(cfg.get_value("community", "cards", PackedStringArray()))
		if CardLibrary.is_valid_community(saved):
			community = saved


func save_community(cards: PackedStringArray) -> bool:
	if not CardLibrary.is_valid_community(cards):
		return false
	community = cards
	var cfg := ConfigFile.new()
	cfg.set_value("community", "cards", cards)
	cfg.save(SAVE_PATH)
	return true
