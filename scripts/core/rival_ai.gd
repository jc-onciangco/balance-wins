class_name RivalAI
extends RefCounted
## Greedy AI: repeatedly tries every legal placement (species into zones, pathogens onto
## rival species), scores the resulting board, and plays the best one while it improves.


func plan(m: MatchManager, side: int) -> void:
	m.auto_resolve_choices(side)
	for _step in 8:
		var base := _score(m, side)
		var best: Dictionary = {}
		var best_score := -INF
		for hi in m.hands[side].size():
			var card: CardData = m.hands[side][hi]
			for ei in m.ecos.size():
				var eco: EcosystemState = m.ecos[ei]
				if not eco.revealed:
					continue
				for si in eco.zone_count():
					var s := -INF
					if card.is_pathogen():
						if not m.can_infect(side, card, ei, si):
							continue
						var target := eco.card_at(1 - side, si)
						target.infection = card
						Rules.recompute(m.ecos, m.season)
						s = _score(m, side) - base + _pathogen_heuristic(eco, card, 1 - side, si) + m.rng.randf() * 0.6
						target.infection = null
					else:
						if not m.can_place(side, card, ei, si):
							continue
						var probe := CardInstance.new(card, side)
						if eco.succession[side][si]:
							probe.perm_mod = 2
						eco.slots[side][si] = probe
						Rules.recompute(m.ecos, m.season)
						s = _score(m, side) - base + _heuristic(m, side, card, ei, si) + m.rng.randf() * 0.6
						eco.slots[side][si] = null
					if s > best_score:
						best_score = s
						best = {"hi": hi, "ei": ei, "si": si, "pathogen": card.is_pathogen()}
		Rules.recompute(m.ecos, m.season)
		if best.is_empty() or best_score < 0.0:
			return
		if best["pathogen"]:
			m.infect(side, best["hi"], best["ei"], best["si"])
		else:
			m.place(side, best["hi"], best["ei"], best["si"])


func _score(m: MatchManager, side: int) -> float:
	var total := 0.0
	for eco in m.ecos:
		if not eco.revealed:
			continue
		total += _eco_value(Rules.evaluate(eco, side))
		total -= 0.5 * _eco_value(Rules.evaluate(eco, 1 - side))
	return total


func _eco_value(ev: Dictionary) -> float:
	match String(ev["state"]):
		"balanced":
			return 14.0 + ev["total"] * 0.3
		"at_risk":
			return 11.0 + ev["total"] * 0.3
		"collapsed":
			return 5.0 - ev["broken"] * 2.0 + ev["total"] * 0.2 + ev["species"] * 0.5
	return 0.0


## Future damage from Dusk effects and spreading, which the board simulation can't see.
func _pathogen_heuristic(eco: EcosystemState, card: CardData, target_side: int, si: int) -> float:
	var bonus := 0.0
	if Rules.has_ability(card, "dusk_minus"):
		bonus += 2.0
	if Rules.has_ability(card, "spread") or Rules.has_ability(card, "spread_all"):
		for j in [si - 1, si + 1]:
			if Rules.is_host(card, eco.card_at(target_side, j)):
				bonus += 1.5
	return bonus


## Rough value of Emergence effects, which the board simulation can't see.
func _heuristic(m: MatchManager, side: int, card: CardData, ei: int, si: int) -> float:
	var eco: EcosystemState = m.ecos[ei]
	var opp := 1 - side
	var bonus := 0.0
	for a in card.abilities:
		var p: PackedStringArray = a.split(":")
		match p[0]:
			"prey_opp_herb":
				for c in eco.cards(opp):
					if c.revealed and Rules.is_herbivore(c.data):
						bonus += 5.0
						break
			"prey_lowest_aquatic":
				for c in eco.cards(opp):
					if c.revealed and c.data.has_trait("Aquatic"):
						bonus += 4.0
						break
			"prey_facing_herb":
				var t := eco.card_at(opp, si)
				if t != null and Rules.is_herbivore(t.data) and t.value <= int(p[1]):
					bonus += 5.0
			"cuckoo":
				var n := eco.cards(opp).size()
				if n > 0 and n < eco.zone_count():
					bonus += 3.0
			"parasitize_facing":
				if eco.card_at(opp, si) != null:
					bonus += 1.5
			"reproduce", "hatch", "recruit", "resprout", "lookout":
				bonus += 1.0
			"allelopathy", "nest_raid", "seed_predation", "mast_year":
				bonus += 1.5
			"fusion_role", "colony":
				for nb in eco.neighbors(side, si):
					if (p[0] == "colony" and nb.data.role == card.role) or (p[0] == "fusion_role" and nb.data.role == p[1]):
						bonus += 2.0
						break
			"fusion_name", "absorb":
				for nb in eco.neighbors(side, si):
					if nb.data.display_name == p[1]:
						bonus += 3.0
						break
	return bonus
