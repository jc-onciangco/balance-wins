extends SceneTree
## Headless test: plays many AI-vs-AI matches (starter and random Communities) and checks invariants.
## Run: godot --headless --path . --script res://tests/sim.gd

var stats := {}


func _random_community(rng: RandomNumberGenerator) -> PackedStringArray:
	var pool: Array = CardLibrary.collection()
	var out := PackedStringArray()
	var pathogens := 0
	while out.size() < 12:
		var d: CardData = pool[rng.randi_range(0, pool.size() - 1)]
		if out.has(d.id):
			continue
		if d.is_pathogen():
			if pathogens >= 2:
				continue
			pathogens += 1
		out.append(d.id)
	return out


func _count(key: String) -> void:
	stats[key] = stats.get(key, 0) + 1


func _init() -> void:
	var wins := [0, 0, 0]
	var errors := 0
	var games := 200
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	for g in games:
		var m := MatchManager.new()
		if g % 2 == 1:
			m.player_community = _random_community(rng)
			m.rival_community = _random_community(rng)
		m.log_message.connect(func(t: String):
			for key in ["Infected", "spread at Dusk", "fuses", "colony", "migrates", "Hatch", "Recruit", "Allelopathy",
					"raids a nest", "eats seeds", "Resprout", "Mast Year", "cache", "cures", "Perishes", "bitten", "bottom"]:
				if t.find(key) >= 0:
					_count(key))
		m.start(g + 1)
		var ai := RivalAI.new()
		var guard := 0
		while not m.finished and guard < 20:
			guard += 1
			ai.plan(m, MatchManager.PLAYER)
			for side in 2:
				if int(m.nutrients[side]) < 0:
					errors += 1
					print("negative nutrients in game ", g)
			m.end_turn()
		if not m.finished or m.season != MatchManager.SEASONS:
			errors += 1
			print("game ", g, " did not finish properly")
		var w: int = m.results["winner"]
		wins[w if w >= 0 else 2] += 1
		for eco in m.ecos:
			for side in 2:
				for c in eco.cards(side):
					if c.value < 0 or c.data.is_pathogen():
						errors += 1
	print("games: ", games, "  player(AI) wins: ", wins[0], "  rival wins: ", wins[1], "  draws: ", wins[2])
	print("events: ", stats)
	print("errors: ", errors)
	quit(1 if errors > 0 else 0)
