class_name RegionLibrary
extends RefCounted
## Real-world regions. Each belongs to a biome that defines its zones (Carrying Capacity: 3 to 5).


static func _zone(zone_name: String, kind: String, key: Variant, amount: int,
		allow: String = "land", locked_until: int = 0) -> Dictionary:
	return {"name": zone_name, "kind": kind, "key": key, "amount": amount,
		"allow": allow, "locked_until": locked_until}


static func _region(id: String, display_name: String, biome: String, zones: Array,
		climates: Array, climate_text: String, requirement: Dictionary,
		requirement_text: String, twist_text: String, residents: Array, tags: Array = []) -> RegionData:
	var r := RegionData.new()
	r.id = id
	r.display_name = display_name
	r.biome = biome
	r.zones = zones
	r.climates = PackedStringArray(climates)
	r.climate_text = climate_text
	r.requirement = requirement
	r.requirement_text = requirement_text
	r.twist_text = twist_text
	r.residents = PackedStringArray(residents)
	r.tags = PackedStringArray(tags)
	return r


static func all() -> Array:
	return [
		_region("bialowieza", "Białowieża Forest", "Temperate Forest", [
				_zone("Leaf Litter", "role", "Decomposer", 2),
				_zone("Undergrowth", "role", "Herbivore", 1),
				_zone("Trunk", "trait", "Climbing", 2),
				_zone("Crown", "trait", "Flying", 2),
			], ["temperate", "old_growth"],
			"From season 4: Producers −1, Decomposers +2.",
			{"type": "role", "value": "Decomposer"}, "Needs a Decomposer.",
			"Old-growth: Decomposers +1.", ["bison", "none"]),
		_region("serengeti", "Serengeti", "Savannah", [
				_zone("Waterhole", "all", "", 1),
				_zone("Grassland", "any_of", ["Producer", "Herbivore"], 1),
				_zone("Acacia Woodland", "any_of", ["Climbing", "Flying"], 1),
				_zone("Kopje", "role", "Predator", 2),
			], ["savannah"],
			"Predators with no herbivore in their line −2.",
			{"type": "role", "value": "Predator"}, "Needs a Predator.",
			"", ["acacia", "none"]),
		_region("reef", "Great Barrier Reef", "Coral Reef", [
				_zone("Seagrass Bed", "role", "Herbivore", 2, "water"),
				_zone("Shallows", "role", "Producer", 2, "water"),
				_zone("Reef Crest", "role", "Symbiont", 2, "water"),
				_zone("Reef Wall", "trait", "Aquatic", 1, "water"),
				_zone("Drop-off", "role", "Predator", 2, "water"),
			], [],
			"Aquatic species only.",
			{"type": "role", "value": "Symbiont"}, "Needs a Symbiont.",
			"", ["res_anem", "none"]),
		_region("amazon", "Amazon Rainforest", "Tropical Rainforest", [
				_zone("Forest Floor", "role", "Decomposer", 2, "both"),
				_zone("Understory", "trait", "Nocturnal", 2, "both"),
				_zone("Rainforest Stream", "trait", "Aquatic", 2, "both"),
				_zone("Canopy", "trait", "Climbing", 2),
				_zone("Emergent", "trait", "Flying", 3),
			], ["rainforest"],
			"Producers +1; Amphibians +1.",
			{"type": "min_roles", "value": 4}, "Needs 4 different roles.",
			"Flooded Forest: Aquatic species may use the Forest Floor and Understory.",
			["brazilnut", "none"]),
		_region("sahara", "Sahara Desert", "Desert", [
				_zone("Dunes", "trait", "Burrowing", 2),
				_zone("Oasis", "all", "", 3),
				_zone("Rock Crevice", "trait", "Nocturnal", 2),
			], ["desert"],
			"Species cost 1 less but have −1 biomass; Reptiles +1.",
			{"type": "trait_any", "value": ["Burrowing", "Nocturnal"]}, "Needs a Burrowing or Nocturnal species.",
			"", ["datepalm", "none"]),
		_region("newzealand", "New Zealand", "Temperate Forest", [
				_zone("Leaf Litter", "role", "Decomposer", 2),
				_zone("Undergrowth", "role", "Herbivore", 1),
				_zone("Trunk", "trait", "Climbing", 2),
				_zone("Crown", "trait", "Flying", 2),
			], ["temperate", "land_of_birds"],
			"From season 4: Producers −1, Decomposers +2. Island: Invasive and Pathogen effects doubled.",
			{"type": "role", "value": "Decomposer"}, "Needs a Decomposer.",
			"Land of Birds: Birds +1; each land Predator here gives all Birds −1, both sides.",
			["kiwi", "none"], ["Island"]),
		_region("arctic", "Arctic Tundra", "Arctic Tundra", [
				_zone("Permafrost", "none", "", 0, "land", 3),
				_zone("Open Tundra", "role", "Herbivore", 1),
				_zone("Ice Edge", "trait_any", ["Aquatic", "Flying"], 2, "both"),
			], ["tundra"],
			"Producers −1; Reptiles and Amphibians −2. Permafrost opens in season 3.",
			{}, "No extra requirement.",
			"", ["none"]),
	]
