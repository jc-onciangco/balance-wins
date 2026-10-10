class_name Rules
extends RefCounted
## Pure rules: biomass calculation, placement legality, pathogens, balance checks.

const PLAYER := 0
const RIVAL := 1


# ---------------------------------------------------------------- ability helpers

static func ability_args(card: CardData, ability_id: String) -> PackedStringArray:
	return _find_args(card.abilities, ability_id)


static func has_ability(card: CardData, ability_id: String) -> bool:
	return ability_args(card, ability_id).size() > 0


static func _find_args(list: PackedStringArray, ability_id: String) -> PackedStringArray:
	for a in list:
		var parts: PackedStringArray = a.split(":")
		if parts[0] == ability_id:
			return parts
	return PackedStringArray()


## A card's own abilities plus any granted to it by merges.
static func abilities_of(ci: CardInstance) -> PackedStringArray:
	var out := ci.data.abilities.duplicate()
	out.append_array(ci.granted)
	return out


static func ci_args(ci: CardInstance, ability_id: String) -> PackedStringArray:
	return _find_args(abilities_of(ci), ability_id)


static func ci_has(ci: CardInstance, ability_id: String) -> bool:
	return ci_args(ci, ability_id).size() > 0


static func is_herbivore(card: CardData) -> bool:
	return card.role == "Herbivore" or card.role == "Omnivore"


static func is_island(eco: EcosystemState) -> bool:
	return eco.region.tags.has("Island")


static func invasive_mult(eco: EcosystemState) -> int:
	return 2 if is_island(eco) else 1


static func count_role(line: Array, role: String) -> int:
	var n := 0
	for c in line:
		if c != null and c.data.role == role:
			n += 1
	return n


static func line_has_herbivore(eco: EcosystemState, side: int) -> bool:
	for c in eco.cards(side):
		if is_herbivore(c.data):
			return true
	return false


static func is_land_predator(card: CardData) -> bool:
	return card.role == "Predator" and not card.has_trait("Flying") and not card.is_aquatic_only()


static func effective_cost(card: CardData, eco: EcosystemState) -> int:
	var c := card.cost
	if eco.region.climates.has("desert"):
		c -= 1
	return maxi(c, 0)


# ---------------------------------------------------------------- placement

## Can this species legally occupy this zone (ignoring cost and whether it is empty)?
static func slot_allows(eco: EcosystemState, card: CardData, si: int, season: int) -> bool:
	return block_reason(eco, card, si, season) == ""


## Why a species can't live in this zone, or "" if it can.
static func block_reason(eco: EcosystemState, card: CardData, si: int, season: int) -> String:
	if card.is_pathogen():
		return "Targets rival species"
	var zone: Dictionary = eco.region.zones[si]
	if int(zone.get("locked_until", 0)) > season and not has_ability(card, "pioneer"):
		return "Locked until\nseason %d" % int(zone["locked_until"])
	var allow: String = zone.get("allow", "land")
	if allow == "water" and not card.has_trait("Aquatic"):
		return "Water only"
	if allow == "land" and card.is_aquatic_only():
		return "Land only"
	if has_ability(card, "end_zone_only") and si != 0 and si != eco.zone_count() - 1:
		return "End zones only"
	return ""


static func zone_bonus(card: CardData, zone: Dictionary) -> int:
	var amount: int = zone.get("amount", 0)
	match String(zone.get("kind", "none")):
		"all":
			return amount
		"role":
			return amount if card.role == zone["key"] else 0
		"trait":
			return amount if card.has_trait(zone["key"]) else 0
		"trait_any":
			for t in zone["key"]:
				if card.has_trait(t):
					return amount
		"any_of":
			for k in zone["key"]:
				if card.role == k or card.has_trait(k):
					return amount
	return 0


# ---------------------------------------------------------------- pathogens

static func is_immune(ci: CardInstance, pathogen: CardData) -> bool:
	if ci_has(ci, "immune_all"):
		return true
	var imm := ci_args(ci, "immune")
	return imm.size() > 1 and imm[1] == pathogen.display_name


## Is this species a valid host for the pathogen right now?
static func is_host(pathogen: CardData, ci: CardInstance) -> bool:
	if ci == null or ci.data.is_pathogen():
		return false
	var d := ci.data
	for a in pathogen.abilities:
		var p: PackedStringArray = a.split(":")
		match p[0]:
			"host_taxon":
				if d.taxon != p[1]:
					return false
			"host_role":
				if d.role != p[1]:
					return false
			"host_max_bio":
				if ci.value > int(p[1]):
					return false
			"host_min_bio":
				if ci.value < int(p[1]):
					return false
	return true


static func can_be_infected(pathogen: CardData, ci: CardInstance) -> bool:
	return ci != null and ci.infection == null and is_host(pathogen, ci) and not is_immune(ci, pathogen)


# ---------------------------------------------------------------- biomass

static func climate_mod(card: CardData, eco: EcosystemState, side: int, season: int) -> int:
	var total := 0
	for c in eco.region.climates:
		match c:
			"temperate":
				if season >= 4:
					if card.role == "Producer":
						total -= 1
					elif card.role == "Decomposer":
						total += 2
			"old_growth":
				if card.role == "Decomposer":
					total += 1
			"rainforest":
				if card.role == "Producer":
					total += 1
				if card.taxon == "Amphibian":
					total += 1
			"desert":
				total -= 1
				if card.taxon == "Reptile":
					total += 1
			"tundra":
				if card.role == "Producer":
					total -= 1
				if card.taxon == "Reptile" or card.taxon == "Amphibian":
					total -= 2
			"savannah":
				if card.role == "Predator" and not line_has_herbivore(eco, side):
					total -= 2
			"land_of_birds":
				if card.taxon == "Bird":
					total += 1
					for s in 2:
						for other in eco.cards(s):
							if is_land_predator(other.data):
								total -= 1
	if total < 0 and has_ability(card, "ignore_climate"):
		total = 0
	return total


## Recompute every card's displayed biomass from base stats and all active effects.
static func recompute(ecos: Array, season: int) -> void:
	for ei in ecos.size():
		var eco: EcosystemState = ecos[ei]
		for side in 2:
			for i in eco.zone_count():
				var ci: CardInstance = eco.slots[side][i]
				if ci != null:
					ci.value = maxi(0, compute_value(ecos, ei, side, i, season))


static func compute_value(ecos: Array, ei: int, side: int, idx: int, season: int) -> int:
	var eco: EcosystemState = ecos[ei]
	var ci: CardInstance = eco.slots[side][idx]
	var d: CardData = ci.data
	var v := d.biomass + ci.perm_mod
	v += zone_bonus(d, eco.region.zones[idx])
	if d.native_biome != "" and d.native_biome == eco.region.biome:
		v += 1
	v += climate_mod(d, eco, side, season)

	var nbrs := eco.neighbors(side, idx)
	# Self Adaptations (own and granted)
	for a in abilities_of(ci):
		var p: PackedStringArray = a.split(":")
		match p[0]:
			"adj_count":
				v += nbrs.size()
			"pack":
				var same := count_role(eco.slots[side], p[1])
				if d.role == p[1]:
					same -= 1
				v += int(p[2]) * same
			"lion_herb":
				if line_has_herbivore(eco, side):
					v += int(p[1])
			"symbiosis":
				for n in nbrs:
					if n.data.display_name == p[1]:
						v += int(p[2])
						break
			"per_merged":
				v += int(p[1]) * ci.merged.size()
	# Adaptations from neighbors
	for n in nbrs:
		for a in abilities_of(n):
			var p: PackedStringArray = a.split(":")
			match p[0]:
				"adj_trait_bonus":
					if d.has_trait(p[1]):
						v += int(p[2])
				"adj_role_bonus":
					if d.role == p[1]:
						v += int(p[2])
	# Ecosystem-wide effects from your own line
	for other in eco.cards(side):
		if other != ci and ci_has(other, "otter") and d.role == "Producer":
			v += 1
	# Range from your species in adjacent ecosystems
	for aj in [ei - 1, ei + 1]:
		if aj < 0 or aj >= ecos.size():
			continue
		var adj: EcosystemState = ecos[aj]
		if not adj.revealed:
			continue
		for other in adj.cards(side):
			var r := ci_args(other, "range_role")
			if r.size() > 0 and d.role == r[1]:
				v += int(r[2])
	# Invasive effects from revealed rival cards (doubled on islands)
	var mult := invasive_mult(eco)
	var opp_line: Array = eco.slots[1 - side]
	for j in opp_line.size():
		var o: CardInstance = opp_line[j]
		if o == null or not o.revealed:
			continue
		var aura := ci_args(o, "invasive_aura")
		if aura.size() > 0 and absi(j - idx) <= 1:
			v -= int(aura[1]) * mult
		var rr := ci_args(o, "invasive_role")
		if rr.size() > 0 and d.role == rr[1]:
			v -= int(rr[2]) * mult
		var fa := ci_args(o, "facing_aura")
		if fa.size() > 0 and j == idx:
			v -= int(fa[1]) * mult
	# Pathogen
	if ci.infection != null:
		var sm := _find_args(ci.infection.abilities, "static_minus")
		if sm.size() > 0:
			v -= int(sm[1]) * mult
	return v


static func is_resilient(ecos: Array, ei: int, side: int, idx: int) -> bool:
	var eco: EcosystemState = ecos[ei]
	var ci := eco.card_at(side, idx)
	if ci == null:
		return false
	if ci_has(ci, "resilient"):
		return true
	for n in eco.neighbors(side, idx):
		if ci_has(n, "adj_resilient"):
			return true
		if ci_has(n, "adj_aquatic_resilient") and ci.data.has_trait("Aquatic"):
			return true
	if ci.data.role == "Producer":
		for c in eco.cards(side):
			if c != ci and ci_has(c, "otter"):
				return true
	return false


# ---------------------------------------------------------------- balance

## Pyramid of biomass check for one player's line.
static func evaluate(eco: EcosystemState, side: int) -> Dictionary:
	var res := {"state": "empty", "P": 0, "H": 0, "D": 0, "total": 0, "broken": 4,
		"species": 0, "fail_foundation": false, "fail_chain": false, "fail_min": false, "fail_req": false}
	if not eco.revealed:
		res["state"] = "hidden"
		return res
	var roles := {}
	var traits := {}
	var has_consumer := false
	var species := 0
	for ci in eco.cards(side):
		var d: CardData = ci.data
		species += 1
		roles[d.role] = true
		for r in ci.extra_roles:
			roles[r] = true
		for t in d.traits:
			traits[t] = true
		res["total"] += ci.value
		match d.role:
			"Producer":
				res["P"] += ci.value
			"Herbivore", "Omnivore":
				res["H"] += ci.value
				has_consumer = true
			"Predator":
				res["D"] += ci.value
				has_consumer = true
	res["species"] = species
	if species == 0:
		return res
	var min_roles := 3
	var req_ok := true
	var req: Dictionary = eco.region.requirement
	match String(req.get("type", "")):
		"role":
			req_ok = roles.has(req["value"])
		"min_roles":
			min_roles = int(req["value"])
		"trait_any":
			req_ok = false
			for t in req["value"]:
				if traits.has(t):
					req_ok = true
	var min_ok: bool = species >= 3 and roles.size() >= min_roles and res["P"] > 0 and has_consumer
	var found_ok: bool = res["P"] >= res["H"]
	var chain_ok: bool = res["H"] >= res["D"]
	res["fail_min"] = not min_ok
	res["fail_foundation"] = not found_ok
	res["fail_chain"] = not chain_ok
	res["fail_req"] = not req_ok
	var broken := 0
	for ok in [min_ok, found_ok, chain_ok, req_ok]:
		if not ok:
			broken += 1
	res["broken"] = broken
	if broken > 0:
		res["state"] = "collapsed"
	elif res["P"] == res["H"] or (res["D"] > 0 and res["H"] == res["D"]):
		res["state"] = "at_risk"
	else:
		res["state"] = "balanced"
	return res


static func is_balanced(ev: Dictionary) -> bool:
	return ev["state"] == "balanced" or ev["state"] == "at_risk"


## Returns the winning side for this ecosystem, or -1 for a tie.
static func resolve(eco: EcosystemState) -> int:
	if not eco.revealed:
		return -1
	var a := evaluate(eco, PLAYER)
	var b := evaluate(eco, RIVAL)
	var ab := is_balanced(a)
	var bb := is_balanced(b)
	if ab and not bb:
		return PLAYER
	if bb and not ab:
		return RIVAL
	if not ab and not bb and a["broken"] != b["broken"]:
		return PLAYER if a["broken"] < b["broken"] else RIVAL
	if a["total"] != b["total"]:
		return PLAYER if a["total"] > b["total"] else RIVAL
	return -1
