class_name MatchManager
extends RefCounted
## Runs a Standard match: 3 ecosystems, 6 seasons, win 2 of 3 by being Balanced at Year's End.
## UI-independent, so it can be driven by the UI, the AI, or headless tests.

signal log_message(text: String)
signal changed
signal game_over(results: Dictionary)

const PLAYER := 0
const RIVAL := 1
const SEASONS := 6
const HAND_LIMIT := 7
const ECOSYSTEMS := 3

var rng := RandomNumberGenerator.new()
var ecos: Array = []
## decks[side] is the Seed Bank; the top card is the last element.
var decks: Array = [[], []]
var hands: Array = [[], []]
var detritus: Array = [[], []]
var nutrients: Array = [0, 0]
var bonus_nutrients: Array = [0, 0]
var cache_nutrients: Array = [0, 0]
var hatch_pending: Array = [0, 0]
var skip_draw: Array = [false, false]
var mast_season: Array = [0, 0]
## Cards placed this season, not yet revealed:
## species {inst, ei, si} or pathogens {pathogen, ei, si, target}
var pending: Array = [[], []]
## Choices waiting for the player (Recruit, Lookout): {side, kind, options, ...}
var pending_choices: Array = []
var season: int = 0
var finished: bool = false
var results: Dictionary = {}
var rival_ai := RivalAI.new()
## The player's chosen Community. Falls back to the starter set if empty or invalid.
var player_community: PackedStringArray = PackedStringArray()
## Optional override for the rival's Community (used by tests).
var rival_community: PackedStringArray = PackedStringArray()


static func side_name(side: int) -> String:
	return "You" if side == PLAYER else "Rival"


## Verb ending: "You gain" / "Rival gains".
static func vs(side: int) -> String:
	return "" if side == PLAYER else "s"


static func owner_word(side: int) -> String:
	return "Your" if side == PLAYER else "Rival's"


func _log(text: String) -> void:
	log_message.emit(text)


func _shuffle(arr: Array) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = arr[i]
		arr[i] = arr[j]
		arr[j] = tmp


# ---------------------------------------------------------------- setup

func start(seed_value: int = -1) -> void:
	if seed_value >= 0:
		rng.seed = seed_value
	else:
		rng.randomize()
	ecos = []
	decks = [[], []]
	hands = [[], []]
	detritus = [[], []]
	nutrients = [0, 0]
	bonus_nutrients = [0, 0]
	cache_nutrients = [0, 0]
	hatch_pending = [0, 0]
	skip_draw = [false, false]
	mast_season = [0, 0]
	pending = [[], []]
	pending_choices = []
	season = 0
	finished = false
	results = {}
	var regions: Array = RegionLibrary.all()
	_shuffle(regions)
	for i in ECOSYSTEMS:
		ecos.append(EcosystemState.new(regions[i], i))
	var mine := player_community if CardLibrary.is_valid_community(player_community) else CardLibrary.player_community()
	var theirs := rival_community if CardLibrary.is_valid_community(rival_community) else CardLibrary.rival_community()
	var lists := [mine, theirs]
	for side in 2:
		for id in lists[side]:
			decks[side].append(CardLibrary.get_card(id))
		_shuffle(decks[side])
		for k in 3:
			_draw(side)
	_log("A new year begins. Three ecosystems lie unexplored.")
	start_season()


func _draw(side: int) -> bool:
	if decks[side].is_empty() or hands[side].size() >= HAND_LIMIT:
		return false
	hands[side].append(decks[side].pop_back())
	return true


func start_season() -> void:
	season += 1
	_log("[b]Season %d[/b]" % season)
	if season <= ecos.size():
		_reveal(ecos[season - 1])
	for side in 2:
		if skip_draw[side]:
			skip_draw[side] = false
			_log("%s draw%s nothing this season (Allelopathy)." % [side_name(side), vs(side)])
		else:
			_draw(side)
		var extra := mini(int(bonus_nutrients[side]), 2)
		bonus_nutrients[side] = 0
		var cached := int(cache_nutrients[side])
		cache_nutrients[side] = 0
		nutrients[side] = season + extra + cached
		if extra > 0:
			_log("%s gain%s +%d nutrient%s from Nutrient Cycling." % [side_name(side), vs(side), extra, "" if extra == 1 else "s"])
		if cached > 0:
			_log("%s gain%s +%d cached nutrient%s." % [side_name(side), vs(side), cached, "" if cached == 1 else "s"])
		if mast_season[side] == season:
			_log("Mast Year: %s species cost 1 less this season." % owner_word(side).to_lower())
	if season == SEASONS:
		var counts := winning_counts()
		for side in 2:
			if counts[side] < counts[1 - side]:
				nutrients[side] += 1
				_log("%s gain%s +1 nutrient from Adaptive Pressure." % [side_name(side), vs(side)])
	pending = [[], []]
	Rules.recompute(ecos, season)
	changed.emit()


func _reveal(eco: EcosystemState) -> void:
	eco.revealed = true
	_log("%s (%s) is revealed. %s" % [eco.region.display_name, eco.region.biome, eco.region.requirement_text])
	var options: PackedStringArray = eco.region.residents
	if options.is_empty():
		return
	var pick: String = options[rng.randi_range(0, options.size() - 1)]
	if pick == "none":
		return
	var data := CardLibrary.get_card(pick)
	var slot := _resident_slot(eco, data)
	if slot < 0:
		return
	for side in 2:
		var inst := CardInstance.new(data, side)
		inst.resident = true
		eco.slots[side][slot] = inst
	_log("Resident %s already lives here, mirrored on both sides." % data.display_name)


func _resident_slot(eco: EcosystemState, data: CardData) -> int:
	var fallback := -1
	for si in eco.zone_count():
		if not Rules.slot_allows(eco, data, si, season):
			continue
		if Rules.zone_bonus(data, eco.region.zones[si]) > 0:
			return si
		if fallback < 0:
			fallback = si
	return fallback


# ---------------------------------------------------------------- costs and placing species

func cost_for(side: int, card: CardData, eco: EcosystemState) -> int:
	var c := Rules.effective_cost(card, eco)
	if mast_season[side] == season:
		c -= 1
	return maxi(c, 0)


## Cheapest cost of a card across revealed ecosystems (for display in the Nest).
func display_cost(side: int, card: CardData) -> int:
	var best := card.cost
	for eco in ecos:
		if eco.revealed:
			best = mini(best, cost_for(side, card, eco))
	return best


func can_place(side: int, card: CardData, ei: int, si: int) -> bool:
	if finished or card.is_pathogen() or ei < 0 or ei >= ecos.size():
		return false
	var eco: EcosystemState = ecos[ei]
	if not eco.revealed or si < 0 or si >= eco.zone_count():
		return false
	if eco.slots[side][si] != null:
		return false
	if not Rules.slot_allows(eco, card, si, season):
		return false
	return cost_for(side, card, eco) <= int(nutrients[side])


## Why the card can't go in this empty zone, or "" if it can (or the zone isn't empty).
func block_reason(side: int, card: CardData, ei: int, si: int) -> String:
	var eco: EcosystemState = ecos[ei]
	if not eco.revealed or eco.slots[side][si] != null:
		return ""
	var r := Rules.block_reason(eco, card, si, season)
	if r != "":
		return r
	if cost_for(side, card, eco) > int(nutrients[side]):
		return "Too expensive"
	return ""


func place(side: int, hand_index: int, ei: int, si: int) -> bool:
	if hand_index < 0 or hand_index >= hands[side].size():
		return false
	var card: CardData = hands[side][hand_index]
	if not can_place(side, card, ei, si):
		return false
	var eco: EcosystemState = ecos[ei]
	nutrients[side] -= cost_for(side, card, eco)
	hands[side].remove_at(hand_index)
	var inst := CardInstance.new(card, side)
	inst.revealed = false
	if eco.succession[side][si]:
		inst.perm_mod += 2
		inst.used_succession = true
		eco.succession[side][si] = false
	eco.slots[side][si] = inst
	pending[side].append({"inst": inst, "ei": ei, "si": si})
	Rules.recompute(ecos, season)
	changed.emit()
	return true


## Take back a species placed this season (before ending the season).
func unplace(side: int, ei: int, si: int) -> bool:
	var eco: EcosystemState = ecos[ei]
	var inst := eco.card_at(side, si)
	if inst == null or inst.revealed:
		return false
	for k in pending[side].size():
		if pending[side][k].get("inst") == inst:
			pending[side].remove_at(k)
			break
	eco.slots[side][si] = null
	if inst.used_succession:
		eco.succession[side][si] = true
	nutrients[side] += cost_for(side, inst.data, eco)
	hands[side].append(inst.data)
	Rules.recompute(ecos, season)
	changed.emit()
	return true


# ---------------------------------------------------------------- pathogens

## Can `side` play this pathogen on the rival species at (ei, si)?
func can_infect(side: int, card: CardData, ei: int, si: int) -> bool:
	if finished or not card.is_pathogen() or ei < 0 or ei >= ecos.size():
		return false
	var eco: EcosystemState = ecos[ei]
	if not eco.revealed:
		return false
	var target := eco.card_at(1 - side, si)
	if target == null or not target.revealed or not Rules.can_be_infected(card, target):
		return false
	if pending_infection(side, ei, si) != null:
		return false
	return cost_for(side, card, eco) <= int(nutrients[side])


func infect(side: int, hand_index: int, ei: int, si: int) -> bool:
	if hand_index < 0 or hand_index >= hands[side].size():
		return false
	var card: CardData = hands[side][hand_index]
	if not can_infect(side, card, ei, si):
		return false
	var eco: EcosystemState = ecos[ei]
	nutrients[side] -= cost_for(side, card, eco)
	hands[side].remove_at(hand_index)
	pending[side].append({"pathogen": card, "ei": ei, "si": si, "target": eco.card_at(1 - side, si)})
	changed.emit()
	return true


## The pathogen `side` has queued against the rival card at (ei, si), or null.
func pending_infection(side: int, ei: int, si: int) -> CardData:
	for p in pending[side]:
		if p.has("pathogen") and p["ei"] == ei and p["si"] == si:
			return p["pathogen"]
	return null


func uninfect(side: int, ei: int, si: int) -> bool:
	for k in pending[side].size():
		var p: Dictionary = pending[side][k]
		if p.has("pathogen") and p["ei"] == ei and p["si"] == si:
			pending[side].remove_at(k)
			nutrients[side] += cost_for(side, p["pathogen"], ecos[ei])
			hands[side].append(p["pathogen"])
			changed.emit()
			return true
	return false


func _apply_infection(target: CardInstance, pathogen: CardData, where: String) -> void:
	target.infection = pathogen
	_log("  %s %s is Infected with %s %s." % [owner_word(target.owner), target.data.display_name, pathogen.emoji, pathogen.display_name] + where)


# ---------------------------------------------------------------- turn flow

func end_turn() -> void:
	if finished:
		return
	auto_resolve_choices(PLAYER)
	rival_ai.plan(self, RIVAL)
	_resolve_reveals()
	_dusk()
	Rules.recompute(ecos, season)
	changed.emit()
	if season >= SEASONS:
		_year_end()
	else:
		start_season()


func winning_counts() -> Array:
	var counts := [0, 0]
	for eco in ecos:
		var w := Rules.resolve(eco)
		if w >= 0:
			counts[w] += 1
	return counts


func _resolve_reveals() -> void:
	var counts := winning_counts()
	var first := PLAYER
	if counts[RIVAL] > counts[PLAYER] or (counts[RIVAL] == counts[PLAYER] and rng.randf() < 0.5):
		first = RIVAL
	for side in [first, 1 - first]:
		for p in pending[side]:
			var ei: int = p["ei"]
			var si: int = p["si"]
			var eco: EcosystemState = ecos[ei]
			if p.has("pathogen"):
				var target: CardInstance = p["target"]
				var pathogen: CardData = p["pathogen"]
				if eco.slots[1 - side][si] == target and Rules.can_be_infected(pathogen, target):
					_log("%s release%s %s %s in %s." % [side_name(side), vs(side), pathogen.emoji, pathogen.display_name, eco.region.display_name])
					_apply_infection(target, pathogen, "")
				else:
					_log("%s %s finds no host and fades away." % [owner_word(side), pathogen.display_name])
				detritus[side].append(pathogen)
				Rules.recompute(ecos, season)
				continue
			var inst: CardInstance = p["inst"]
			if eco.slots[side][si] != inst:
				continue
			inst.revealed = true
			_log("%s reveal%s %s %s in %s." % [side_name(side), vs(side), inst.data.emoji, inst.data.display_name, eco.region.display_name])
			_emergence(side, ei, si)
			Rules.recompute(ecos, season)
	pending = [[], []]


func _emergence(side: int, ei: int, si: int) -> void:
	var eco: EcosystemState = ecos[ei]
	var inst := eco.card_at(side, si)
	if _try_merge(side, ei, si):
		return
	var opp := 1 - side
	for a in inst.data.abilities:
		var p: PackedStringArray = a.split(":")
		match p[0]:
			"reproduce":
				if hands[side].size() < HAND_LIMIT:
					hands[side].append(CardLibrary.get_card(p[1]))
					_log("  %s reproduces: offspring added to the Nest." % inst.data.display_name)
			"prey_facing_herb":
				var target := eco.card_at(opp, si)
				if target != null and target.revealed and Rules.is_herbivore(target.data) and target.value <= int(p[1]):
					_attempt_perish(ei, opp, si, inst.data.display_name, inst)
			"prey_opp_herb":
				var best := -1
				for j in eco.zone_count():
					var c := eco.card_at(opp, j)
					if c != null and c.revealed and Rules.is_herbivore(c.data):
						if best < 0 or c.value > eco.card_at(opp, best).value:
							best = j
				if best >= 0:
					_attempt_perish(ei, opp, best, inst.data.display_name, inst)
			"prey_lowest_aquatic":
				var low := -1
				for j in eco.zone_count():
					var c := eco.card_at(opp, j)
					if c != null and c.revealed and c.data.has_trait("Aquatic"):
						if low < 0 or c.value < eco.card_at(opp, low).value:
							low = j
				if low >= 0:
					_attempt_perish(ei, opp, low, inst.data.display_name, inst)
			"parasitize_facing":
				var t := eco.card_at(opp, si)
				if t != null and t.revealed:
					t.perm_mod -= int(p[1])
					inst.perm_mod += int(p[1])
					_log("  %s parasitizes %s." % [inst.data.display_name, t.data.display_name])
			"cuckoo":
				var chick := CardLibrary.get_card(p[1])
				for j in eco.zone_count():
					if eco.card_at(opp, j) == null and Rules.slot_allows(eco, chick, j, season):
						eco.slots[opp][j] = CardInstance.new(chick, opp)
						_log("  The Cuckoo plants a chick in %s %s line." % ["your" if opp == PLAYER else "the rival's", eco.region.display_name])
						break
			"detritus_bonus":
				var n: int = detritus[side].size()
				if n > 0:
					inst.perm_mod += n
					_log("  %s feeds on Detritus: +%d." % [inst.data.display_name, n])
			"cleanse_adjacent":
				for nb in eco.neighbors(side, si):
					if nb.infection != null:
						_log("  %s cures %s of %s." % [inst.data.display_name, nb.data.display_name, nb.infection.display_name])
						nb.infection = null
						break
			"hatch":
				hatch_pending[side] += int(p[1])
				_log("  %s will Hatch %s species at Dusk." % [inst.data.display_name, p[1]])
			"recruit":
				_queue_recruit(side, p[1], inst.data.display_name)
			"lookout":
				_queue_lookout(side, int(p[1]), inst.data.display_name)
			"allelopathy":
				skip_draw[opp] = true
				_log("  %s releases chemicals: %s draw%s nothing next season." % [inst.data.display_name, side_name(opp), vs(opp)])
			"nest_raid":
				if not hands[opp].is_empty():
					var k := rng.randi_range(0, hands[opp].size() - 1)
					var lost: CardData = hands[opp][k]
					hands[opp].remove_at(k)
					detritus[opp].append(lost)
					_log("  %s raids a nest: %s %s Withers." % [inst.data.display_name, owner_word(opp), lost.display_name])
			"seed_predation":
				var eaten: Array = []
				for k in int(p[1]):
					if decks[opp].is_empty():
						break
					var seed: CardData = decks[opp].pop_back()
					detritus[opp].append(seed)
					eaten.append(seed.display_name)
				if not eaten.is_empty():
					_log("  %s eats seeds from %s Seed Bank: %s." % [inst.data.display_name, owner_word(opp).to_lower(), ", ".join(PackedStringArray(eaten))])
			"resprout":
				var pick := -1
				for k in detritus[side].size():
					var d: CardData = detritus[side][k]
					if d.role == "Producer" and not d.token and (pick < 0 or d.biomass > detritus[side][pick].biomass):
						pick = k
				if pick >= 0 and hands[side].size() < HAND_LIMIT:
					var back: CardData = detritus[side][pick]
					detritus[side].remove_at(pick)
					hands[side].append(back)
					_log("  %s helps %s Resprout into the Nest." % [inst.data.display_name, back.display_name])
			"mast_year":
				mast_season[side] = season + 1
				_log("  Mast Year: %s species cost 1 less next season." % owner_word(side).to_lower())


# ---------------------------------------------------------------- merging

func _try_merge(side: int, ei: int, si: int) -> bool:
	var eco: EcosystemState = ecos[ei]
	var inst := eco.card_at(side, si)
	var kind := ""
	var match_key := ""
	var bonus := 0
	for a in inst.data.abilities:
		var p: PackedStringArray = a.split(":")
		match p[0]:
			"fusion_role":
				kind = "fusion_role"
				match_key = p[1]
				bonus = int(p[2])
			"fusion_name":
				kind = "fusion_name"
				match_key = p[1]
				bonus = int(p[2])
			"colony":
				kind = "colony"
				match_key = inst.data.role
				bonus = int(p[1])
			"absorb":
				kind = "absorb"
				match_key = p[1]
				bonus = int(p[2])
	if kind == "":
		return false
	var host: CardInstance = null
	for j in [si - 1, si + 1]:
		var c := eco.card_at(side, j)
		if c == null:
			continue
		var ok := false
		match kind:
			"fusion_role", "colony":
				ok = c.data.role == match_key
			"fusion_name", "absorb":
				ok = c.data.display_name == match_key
		if ok and (host == null or c.value > host.value):
			host = c
	if host == null:
		return false
	eco.slots[side][si] = null
	host.perm_mod += inst.data.biomass + bonus
	host.merged.append(inst.data)
	if kind.begins_with("fusion") and inst.data.role != host.data.role and not host.extra_roles.has(inst.data.role):
		host.extra_roles.append(inst.data.role)
	for a in inst.data.abilities:
		if a.begins_with("grant:"):
			host.granted.append(a.substr(6))
	var verb: String = {"fusion_role": "fuses with", "fusion_name": "fuses with", "colony": "joins the colony of", "absorb": "fuses onto"}[kind]
	_log("  %s %s %s (+%d)." % [inst.data.display_name, verb, host.data.display_name, inst.data.biomass + bonus])
	return true


# ---------------------------------------------------------------- perishing

func _attempt_perish(ei: int, side: int, si: int, cause: String, attacker: CardInstance = null) -> void:
	var eco: EcosystemState = ecos[ei]
	var target := eco.card_at(side, si)
	if target == null:
		return
	if Rules.is_resilient(ecos, ei, side, si):
		_log("  %s is Resilient and survives the %s." % [target.data.display_name, cause])
		return
	var disease := target.infection
	_perish(ei, side, si, cause)
	if attacker != null and disease != null and Rules.has_ability(disease, "bite") and Rules.can_be_infected(disease, attacker):
		_apply_infection(attacker, disease, " (bitten while hunting)")


func _perish(ei: int, side: int, si: int, cause: String) -> void:
	var eco: EcosystemState = ecos[ei]
	var inst := eco.card_at(side, si)
	if inst == null:
		return
	eco.slots[side][si] = null
	detritus[side].append(inst.data)
	for d in inst.merged:
		detritus[side].append(d)
	bonus_nutrients[side] += 2 if not inst.merged.is_empty() else 1
	eco.succession[side][si] = true
	_log("  %s %s Perishes (%s). Nutrients will return next season; Succession +2 here." % [owner_word(side), inst.data.display_name, cause])
	for s in 2:
		for c in eco.cards(s):
			var g := Rules.ci_args(c, "perish_growth")
			if g.size() > 0:
				c.perm_mod += int(g[1])
	var sub := Rules.ability_args(inst.data, "perish_subsidy")
	if sub.size() > 0:
		for aj in [ei - 1, ei + 1]:
			if aj < 0 or aj >= ecos.size() or not ecos[aj].revealed:
				continue
			for c in ecos[aj].cards(side):
				if c.data.role == sub[1]:
					c.perm_mod += int(sub[2])
		_log("  Its nutrients feed %s Producers in neighboring ecosystems (+%s)." % [owner_word(side).to_lower(), sub[2]])


# ---------------------------------------------------------------- Dusk

func _dusk() -> void:
	_dusk_pathogens()
	for side in 2:
		var n := int(hatch_pending[side])
		hatch_pending[side] = 0
		var drawn := 0
		for k in n:
			if _draw(side):
				drawn += 1
		if drawn > 0:
			_log("Dusk: %s hatch%s %d species into the Nest." % [side_name(side), "" if side == PLAYER else "es", drawn])
		for eco in ecos:
			for c in eco.cards(side):
				var ca := Rules.ci_args(c, "cache")
				if ca.size() > 0 and c.revealed:
					cache_nutrients[side] = maxi(int(cache_nutrients[side]), mini(int(nutrients[side]), int(ca[1])))
		if int(cache_nutrients[side]) > 0:
			_log("Dusk: %s cache%s %d nutrient%s for next season." % [side_name(side), "" if side == PLAYER else "s",
				cache_nutrients[side], "" if cache_nutrients[side] == 1 else "s"])
	_dusk_migration()


func _dusk_pathogens() -> void:
	var queue: Array = []
	var queued := {}
	for ei in ecos.size():
		var eco: EcosystemState = ecos[ei]
		var mult := Rules.invasive_mult(eco)
		for side in 2:
			for si in eco.zone_count():
				var ci := eco.card_at(side, si)
				if ci == null or ci.infection == null:
					continue
				var path := ci.infection
				var dm := Rules.ability_args(path, "dusk_minus")
				if dm.size() > 0:
					ci.perm_mod -= int(dm[1]) * mult
					_log("Dusk: %s weakens %s %s (−%d)." % [path.display_name, owner_word(side).to_lower(), ci.data.display_name, int(dm[1]) * mult])
				var targets: Array = []
				if Rules.has_ability(path, "spread"):
					for j in [si - 1, si + 1]:
						var nb := eco.card_at(side, j)
						if Rules.can_be_infected(path, nb) and not queued.has(nb.get_instance_id()):
							targets.append(nb)
							break
				if Rules.has_ability(path, "spread_facing"):
					var f := eco.card_at(1 - side, si)
					if Rules.can_be_infected(path, f):
						targets.append(f)
				if Rules.has_ability(path, "spread_all"):
					for s2 in 2:
						for c in eco.cards(s2):
							if Rules.can_be_infected(path, c):
								targets.append(c)
				for t in targets:
					if not queued.has(t.get_instance_id()):
						queued[t.get_instance_id()] = true
						queue.append([t, path])
	for q in queue:
		_apply_infection(q[0], q[1], " (spread at Dusk)")


func _dusk_migration() -> void:
	var movers: Array = []
	for ei in ecos.size():
		var eco: EcosystemState = ecos[ei]
		for side in 2:
			for si in eco.zone_count():
				var c := eco.card_at(side, si)
				if c == null or not c.revealed:
					continue
				var seasonal := Rules.ability_args(c.data, "migratory_season")
				var moves := Rules.has_ability(c.data, "migratory_dusk")
				if seasonal.size() > 1 and seasonal[1].split(",").has(str(season)):
					moves = true
				if moves:
					movers.append([c, ei, side])
	for mv in movers:
		var c: CardInstance = mv[0]
		var ei: int = mv[1]
		var side: int = mv[2]
		var si: int = ecos[ei].slots[side].find(c)
		if si < 0:
			continue
		for tei in [ei + 1, ei - 1]:
			if tei < 0 or tei >= ecos.size() or not ecos[tei].revealed:
				continue
			var dest := _nearest_open(tei, side, c.data, si)
			if dest < 0:
				continue
			var companion: CardInstance = null
			if Rules.has_ability(c.data, "herd_migrate"):
				for nb in ecos[ei].neighbors(side, si):
					if Rules.is_herbivore(nb.data) and not nb.resident:
						companion = nb
						break
			ecos[ei].slots[side][si] = null
			ecos[tei].slots[side][dest] = c
			_log("Dusk: %s %s migrates from %s to %s." % [owner_word(side), c.data.display_name,
				ecos[ei].region.display_name, ecos[tei].region.display_name])
			if companion != null:
				var csi: int = ecos[ei].slots[side].find(companion)
				var cdest := _nearest_open(tei, side, companion.data, dest)
				if csi >= 0 and cdest >= 0:
					ecos[ei].slots[side][csi] = null
					ecos[tei].slots[side][cdest] = companion
					_log("  %s travels with the herd." % companion.data.display_name)
			break


func _nearest_open(ei: int, side: int, card: CardData, from_si: int) -> int:
	var eco: EcosystemState = ecos[ei]
	var best := -1
	for si in eco.zone_count():
		if eco.slots[side][si] != null or not Rules.slot_allows(eco, card, si, season):
			continue
		if best < 0 or absi(si - from_si) < absi(best - from_si):
			best = si
	return best


# ---------------------------------------------------------------- choices (Recruit, Lookout)

func _queue_recruit(side: int, type: String, source: String) -> void:
	var options: Array = []
	for d in decks[side]:
		if d.role == type or d.taxon == type:
			options.append(d)
	if options.is_empty():
		_log("  %s finds no %s to Recruit." % [source, type])
		return
	var choice := {"side": side, "kind": "recruit", "type": type, "source": source, "options": options}
	if side == PLAYER and options.size() > 1:
		pending_choices.append(choice)
		_log("  %s can Recruit a %s: choose one." % [source, type])
	else:
		resolve_recruit(choice, _best_option(options))


func _queue_lookout(side: int, count: int, source: String) -> void:
	var options: Array = []
	for k in mini(count, decks[side].size()):
		options.append(decks[side][decks[side].size() - 1 - k])
	if options.is_empty():
		return
	var choice := {"side": side, "kind": "lookout", "source": source, "options": options}
	if side == PLAYER:
		pending_choices.append(choice)
		_log("  %s keeps lookout: choose which species to send to the bottom." % source)
	else:
		resolve_lookout(choice, _ai_lookout_bottom(side, options))


func _best_option(options: Array) -> CardData:
	var best: CardData = options[0]
	for d in options:
		if d.biomass > best.biomass:
			best = d
	return best


func _ai_lookout_bottom(side: int, options: Array) -> Array:
	var out: Array = []
	for d in options:
		if d.cost > season + 2:
			out.append(d)
	return out


func resolve_recruit(choice: Dictionary, card: CardData) -> void:
	var side: int = choice["side"]
	pending_choices.erase(choice)
	var k: int = decks[side].find(card)
	if k < 0:
		return
	if hands[side].size() >= HAND_LIMIT:
		_log("  %s Nest is full; the Recruit fails." % owner_word(side))
		return
	decks[side].remove_at(k)
	hands[side].append(card)
	_log("  %s Recruit%s %s %s." % [side_name(side), vs(side), card.emoji, card.display_name if side == PLAYER else "a species"])
	changed.emit()


func resolve_lookout(choice: Dictionary, to_bottom: Array) -> void:
	var side: int = choice["side"]
	pending_choices.erase(choice)
	for d in to_bottom:
		var k: int = decks[side].find(d)
		if k >= 0:
			decks[side].remove_at(k)
			decks[side].insert(0, d)
	if not to_bottom.is_empty():
		_log("  %s send%s %d species to the bottom of the Seed Bank." % [side_name(side), vs(side), to_bottom.size()])
	changed.emit()


## Resolve any choices still waiting for `side` automatically (used by AI, tests and as a safety net).
func auto_resolve_choices(side: int) -> void:
	for choice in pending_choices.duplicate():
		if choice["side"] != side:
			continue
		if choice["kind"] == "recruit":
			resolve_recruit(choice, _best_option(choice["options"]))
		else:
			resolve_lookout(choice, _ai_lookout_bottom(side, choice["options"]))


# ---------------------------------------------------------------- Year's End

func _year_end() -> void:
	finished = true
	var per: Array = []
	var wins := [0, 0]
	var totals := [0, 0]
	var taxa := [{}, {}]
	for eco in ecos:
		var w := Rules.resolve(eco)
		per.append({"name": eco.region.display_name, "winner": w,
			"you": Rules.evaluate(eco, PLAYER), "rival": Rules.evaluate(eco, RIVAL)})
		if w >= 0:
			wins[w] += 1
		for side in 2:
			for c in eco.cards(side):
				totals[side] += c.value
				taxa[side][c.data.taxon] = true
	var winner := -1
	var reason := "a draw"
	if wins[PLAYER] != wins[RIVAL]:
		winner = PLAYER if wins[PLAYER] > wins[RIVAL] else RIVAL
		reason = "ecosystems won (%d to %d)" % [wins[winner], wins[1 - winner]]
	elif totals[PLAYER] != totals[RIVAL]:
		winner = PLAYER if totals[PLAYER] > totals[RIVAL] else RIVAL
		reason = "total biomass tiebreaker"
	elif taxa[PLAYER].size() != taxa[RIVAL].size():
		winner = PLAYER if taxa[PLAYER].size() > taxa[RIVAL].size() else RIVAL
		reason = "taxon diversity tiebreaker"
	results = {"winner": winner, "reason": reason, "ecosystems": per, "wins": wins, "totals": totals}
	if winner < 0:
		_log("[b]Year's End: a draw.[/b]")
	else:
		_log("[b]Year's End: %s win%s by %s.[/b]" % [side_name(winner), vs(winner), reason])
	changed.emit()
	game_over.emit(results)
