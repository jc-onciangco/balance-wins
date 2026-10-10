class_name CardLibrary
extends RefCounted
## All species and tokens for the prototype, built in code.
## To add a species: add one _add(...) line, then (if it has a new ability id)
## handle that id in Rules.compute_value (static effects) or MatchManager._emergence (on reveal).

static var _cards: Dictionary = {}


static func _add(id: String, display_name: String, emoji: String, cost: int, biomass: int,
		role: String, taxon: String, traits: Array, native_biome: String,
		abilities: Array, text: String, token: bool = false) -> void:
	var c := CardData.new()
	c.id = id
	c.display_name = display_name
	c.emoji = emoji
	c.cost = cost
	c.biomass = biomass
	c.role = role
	c.taxon = taxon
	c.traits = PackedStringArray(traits)
	c.native_biome = native_biome
	c.abilities = PackedStringArray(abilities)
	c.text = text
	c.token = token
	_cards[id] = c


static func _add_pathogen(id: String, display_name: String, emoji: String, cost: int,
		taxon: String, abilities: Array, text: String) -> void:
	_add(id, display_name, emoji, cost, 0, "Pathogen", taxon, [], "", abilities, text)
	_cards[id].card_type = "Pathogen"


static func _ensure() -> void:
	if not _cards.is_empty():
		return
	# --- Producers ---
	_add("moss", "Moss", "🌱", 1, 1, "Producer", "Plant", ["Terrestrial"], "",
		["pioneer"], "Pioneer: can be placed in locked zones.")
	_add("phyto", "Phytoplankton", "🦠", 1, 1, "Producer", "Algae", ["Aquatic"], "Coral Reef",
		["reproduce:plankton"], "Emergence: Reproduce (adds a Plankton Bloom to your Nest).")
	_add("grass", "Prairie Grass", "🌾", 1, 2, "Producer", "Plant", ["Terrestrial"], "Savannah",
		[], "A sturdy, cheap foundation.")
	_add("saguaro", "Saguaro Cactus", "🌵", 2, 3, "Producer", "Plant", ["Terrestrial"], "Desert",
		["ignore_climate"], "Ignores climate penalties.")
	_add("oak", "Oak Tree", "🌳", 3, 5, "Producer", "Plant", ["Terrestrial"], "Temperate Forest",
		["adj_trait_bonus:Flying:2"], "Adaptation: adjacent Flying species +2.")
	_add("kelp", "Giant Kelp", "🌿", 4, 6, "Producer", "Algae", ["Aquatic"], "",
		["adj_aquatic_resilient"], "Adaptation: adjacent Aquatic species are Resilient.")
	# --- Herbivores ---
	_add("rabbit", "European Rabbit", "🐇", 2, 2, "Herbivore", "Mammal", ["Burrowing"], "",
		["reproduce:kit"], "Emergence: Reproduce (adds a Rabbit Offspring to your Nest).")
	_add("ant", "Leaf-cutter Ant", "🐜", 2, 2, "Herbivore", "Insect", ["Burrowing"], "Tropical Rainforest",
		["adj_count"], "Adaptation: +1 for each adjacent species.")
	_add("zebra", "Plains Zebra", "🦓", 3, 3, "Herbivore", "Mammal", ["Fast"], "Savannah",
		["pack:Herbivore:1"], "Pack: +1 for each other herbivore in its line.")
	_add("turtle", "Green Sea Turtle", "🐢", 3, 3, "Herbivore", "Reptile", ["Aquatic"], "Coral Reef",
		[], "A steady grazer of seagrass.")
	# --- Predators ---
	_add("fox", "Red Fox", "🦊", 3, 2, "Predator", "Mammal", ["Nocturnal"], "Temperate Forest",
		["prey_facing_herb:2"], "Emergence: Prey on the facing rival herbivore if it has 2 or less biomass.")
	_add("wolf", "Gray Wolf", "🐺", 3, 2, "Predator", "Mammal", ["Fast"], "Temperate Forest",
		["pack:Predator:1", "range_role:Producer:1"], "Pack: +1 per other predator in its line. Range: your Producers in adjacent ecosystems +1.")
	_add("lion", "African Lion", "🦁", 4, 4, "Predator", "Mammal", ["Terrestrial"], "Savannah",
		["lion_herb:2"], "Adaptation: +2 if you have a herbivore in its line.")
	_add("eagle", "Harpy Eagle", "🦅", 5, 4, "Predator", "Bird", ["Flying"], "Tropical Rainforest",
		["end_zone_only", "prey_opp_herb"], "End zone only. Emergence: Prey on the biggest opposing herbivore here.")
	_add("shark", "Great White Shark", "🦈", 5, 5, "Predator", "Fish", ["Aquatic", "Fast"], "Coral Reef",
		["prey_lowest_aquatic"], "Emergence: Prey on the lowest-biomass opposing Aquatic species here.")
	# --- Decomposers ---
	_add("myc", "Mycelium", "🍄", 1, 1, "Decomposer", "Fungus", ["Burrowing"], "",
		["adj_resilient"], "Adaptation: adjacent species are Resilient.")
	_add("worm", "Earthworm", "🪱", 1, 1, "Decomposer", "Other Invertebrate", ["Burrowing"], "",
		["adj_role_bonus:Producer:1"], "Adaptation: adjacent Producers +1.")
	_add("beetle", "Dung Beetle", "🪲", 2, 1, "Decomposer", "Insect", ["Burrowing"], "Savannah",
		["perish_growth:2"], "Gains +2 whenever any species Perishes in this ecosystem.")
	# --- Support ---
	_add("bee", "Honeybee", "🐝", 1, 1, "Pollinator", "Insect", ["Flying"], "",
		["adj_role_bonus:Producer:1", "recruit:Producer"], "Adaptation: adjacent Producers +1. Emergence: Recruit a Producer from your Seed Bank.")
	_add("clown", "Clownfish", "🐠", 2, 2, "Symbiont", "Fish", ["Aquatic"], "Coral Reef",
		["symbiosis:Sea Anemone:3"], "Symbiosis (Sea Anemone): +3.")
	_add("anem", "Sea Anemone", "🪸", 3, 3, "Symbiont", "Other Invertebrate", ["Aquatic"], "Coral Reef",
		["symbiosis:Clownfish:2"], "Symbiosis (Clownfish): +2.")
	# --- Parasites ---
	_add("mosquito", "Mosquito", "🦟", 1, 1, "Parasite", "Insect", ["Flying"], "",
		["parasitize_facing:1"], "Emergence: Parasitize the facing species −1; gain +1.")
	_add("cuckoo", "Common Cuckoo", "🪶", 2, 1, "Parasite", "Bird", ["Flying"], "",
		["cuckoo:chick"], "Invasive. Emergence: place a Cuckoo Chick (Herbivore, 3) in an empty zone of the rival's line here.")
	_add("toad", "Cane Toad", "🐸", 3, 3, "Parasite", "Amphibian", ["Terrestrial"], "",
		["invasive_aura:1"], "Invasive. Adaptation: the facing rival species and those beside it −1.")
	_add("locust", "Desert Locust", "🦗", 2, 1, "Parasite", "Insect", ["Flying"], "Desert",
		["invasive_role:Producer:1", "migratory_dusk"], "Invasive. Opposing Producers in its ecosystem −1. Migratory: moves to an adjacent ecosystem every Dusk.")
	# --- Keystone ---
	_add("otter", "Sea Otter", "🦦", 4, 3, "Predator", "Mammal", ["Aquatic"], "Coral Reef",
		["otter"], "Keystone. Adaptation: your Producers here are Resilient and +1.")
	# --- Pathogen counters ---
	_add("vulture", "Griffon Vulture", "🪽", 3, 2, "Decomposer", "Bird", ["Flying"], "Savannah",
		["immune_all", "detritus_bonus", "cleanse_adjacent"], "Immune to Pathogens. Emergence: +1 per species in your Detritus, and cure an adjacent species of its Pathogen.")
	_add("opossum", "Virginia Opossum", "🐀", 2, 2, "Omnivore", "Mammal", ["Climbing"], "Temperate Forest",
		["immune:Rabies Virus"], "Immune to Rabies (its low body temperature makes rabies rare).")
	# --- Merging ---
	_add("lichen", "Lichen Fungus", "🪨", 1, 1, "Decomposer", "Fungus", [], "",
		["fusion_role:Producer:0"], "Fusion (Producer): merges into an adjacent Producer of yours, which gains the Decomposer role.")
	_add("zoox", "Zooxanthellae", "✨", 1, 1, "Producer", "Algae", ["Aquatic"], "Coral Reef",
		["fusion_name:Brain Coral:2"], "Fusion (Brain Coral): merges into an adjacent Brain Coral, which gains the Producer role and +2.")
	_add("braincoral", "Brain Coral", "🧠", 3, 3, "Symbiont", "Other Invertebrate", ["Aquatic"], "Coral Reef",
		["per_merged:1"], "Adaptation: +1 for each species merged into it.")
	_add("armyant", "Army Ant", "🐜", 1, 1, "Herbivore", "Insect", ["Burrowing"], "Tropical Rainforest",
		["colony:2"], "Colony: merges into an adjacent Herbivore of yours, adding its biomass +2.")
	_add("manowar", "Portuguese Man o' War", "🎐", 2, 2, "Predator", "Other Invertebrate", ["Aquatic"], "Coral Reef",
		["colony:0", "grant:facing_aura:1"], "Colony: merges into an adjacent Predator of yours, which then gives the facing rival species −1.")
	_add("maleangler", "Male Anglerfish", "🎣", 1, 1, "Predator", "Fish", ["Aquatic"], "",
		["absorb:Female Anglerfish:0", "grant:resilient"], "Absorb: fuses into an adjacent Female Anglerfish, which becomes Resilient.")
	_add("femaleangler", "Female Anglerfish", "🐡", 4, 4, "Predator", "Fish", ["Aquatic", "Nocturnal"], "",
		[], "A deep-sea hunter with a glowing lure.")
	# --- Seasonal migration ---
	_add("tern", "Arctic Tern", "🕊️", 2, 2, "Predator", "Bird", ["Flying"], "Arctic Tundra",
		["migratory_season:3,5"], "Migratory (Seasons 3 and 5): moves to an adjacent ecosystem at Dusk.")
	_add("wildebeest", "Blue Wildebeest", "🐃", 3, 3, "Herbivore", "Mammal", ["Fast"], "Savannah",
		["migratory_season:4", "herd_migrate"], "Migratory (Season 4): moves to an adjacent ecosystem at Dusk, taking an adjacent Herbivore with it.")
	_add("salmon", "Sockeye Salmon", "🐟", 2, 2, "Herbivore", "Fish", ["Aquatic"], "",
		["migratory_season:4", "perish_subsidy:Producer:2"], "Migratory (Season 4). When it Perishes, your Producers in adjacent ecosystems +2.")
	# --- Seed Bank effects ---
	_add("frog", "Common Frog", "🐸", 2, 1, "Herbivore", "Amphibian", ["Terrestrial", "Aquatic"], "Temperate Forest",
		["hatch:2"], "Emergence: Hatch 2 (draw 2 species at Dusk).")
	_add("honeyguide", "Greater Honeyguide", "🐦", 2, 2, "Pollinator", "Bird", ["Flying"], "Savannah",
		["recruit:Mammal"], "Emergence: Recruit a Mammal from your Seed Bank.")
	_add("walnut", "Black Walnut", "🌲", 4, 5, "Producer", "Plant", ["Terrestrial"], "Temperate Forest",
		["allelopathy"], "Emergence: Allelopathy (your rival draws no species next season).")
	_add("eggsnake", "Egg-eating Snake", "🐍", 2, 2, "Predator", "Reptile", ["Terrestrial"], "Savannah",
		["nest_raid"], "Emergence: Nest Raid (a random species in your rival's Nest Withers).")
	_add("woodmouse", "Wood Mouse", "🐭", 1, 1, "Herbivore", "Mammal", ["Burrowing"], "Temperate Forest",
		["seed_predation:2"], "Emergence: Seed Predation (the top 2 species of your rival's Seed Bank go to their Detritus).")
	_add("squirrel", "Eurasian Red Squirrel", "🐿️", 2, 2, "Herbivore", "Mammal", ["Climbing"], "Temperate Forest",
		["cache:2"], "Cache: at Dusk, up to 2 unspent nutrients carry over to next season.")
	_add("banksia", "Banksia", "🌼", 3, 3, "Producer", "Plant", ["Terrestrial"], "",
		["resprout"], "Emergence: Resprout (return a Producer from your Detritus to your Nest).")
	_add("beech", "European Beech", "🍁", 3, 4, "Producer", "Plant", ["Terrestrial"], "Temperate Forest",
		["mast_year"], "Emergence: Mast Year (species in your Nest cost 1 less next season).")
	_add("meerkat", "Meerkat", "🐾", 2, 2, "Omnivore", "Mammal", ["Burrowing"], "Desert",
		["lookout:3"], "Emergence: Lookout (look at the top 3 of your Seed Bank; put any on the bottom).")
	# --- Pathogens ---
	_add_pathogen("rabies", "Rabies Virus", "🧬", 2, "Virus",
		["host_taxon:Mammal", "dusk_minus:1", "spread:1", "bite"],
		"Infects a rival Mammal. −1 at each Dusk; spreads to one adjacent Mammal at Dusk; a predator that preys on it gets infected.")
	_add_pathogen("avianflu", "Avian Influenza", "🌡️", 2, "Virus",
		["host_taxon:Bird", "static_minus:2", "spread:1", "spread_facing"],
		"Infects a rival Bird. −2; at Dusk spreads to an adjacent Bird and to the facing Bird.")
	_add_pathogen("chytrid", "Chytrid Fungus", "🧫", 3, "Fungus",
		["host_taxon:Amphibian", "dusk_minus:2", "spread_all"],
		"Infects a rival Amphibian. −2 at each Dusk; spreads to every Amphibian in the ecosystem, both sides.")
	_add_pathogen("myxoma", "Myxoma Virus", "☣️", 2, "Virus",
		["host_taxon:Mammal", "host_role:Herbivore", "host_max_bio:3", "static_minus:2", "spread:1"],
		"Infects a rival Herbivore Mammal with 3 or less biomass. −2; at Dusk spreads to one adjacent host.")
	_add_pathogen("blight", "Chestnut Blight", "🍂", 3, "Fungus",
		["host_taxon:Plant", "host_min_bio:4", "static_minus:2"],
		"Infects a rival Plant with 4+ biomass. −2.")
	# --- Tokens and Residents ---
	_add("kit", "Rabbit Offspring", "🐰", 1, 1, "Herbivore", "Mammal", ["Burrowing"], "",
		[], "Offspring of the European Rabbit.", true)
	_add("plankton", "Plankton Bloom", "🫧", 1, 1, "Producer", "Algae", ["Aquatic"], "",
		[], "Offspring of Phytoplankton.", true)
	_add("chick", "Cuckoo Chick", "🐣", 0, 3, "Herbivore", "Bird", ["Terrestrial"], "",
		[], "Planted by a rival's Common Cuckoo. It counts toward your pyramid.", true)
	_add("acacia", "Acacia Tree", "🌳", 3, 3, "Producer", "Plant", ["Terrestrial"], "Savannah",
		[], "Resident of the Serengeti.", true)
	_add("bison", "European Bison", "🦬", 4, 3, "Herbivore", "Mammal", ["Terrestrial"], "Temperate Forest",
		[], "Resident of Białowieża Forest. Free biomass, but your pyramid must support it.", true)
	_add("brazilnut", "Brazil Nut Tree", "🌰", 3, 3, "Producer", "Plant", ["Terrestrial"], "Tropical Rainforest",
		[], "Resident of the Amazon.", true)
	_add("datepalm", "Date Palm", "🌴", 2, 3, "Producer", "Plant", ["Terrestrial"], "Desert",
		[], "Resident of the Sahara's oases.", true)
	_add("kiwi", "Kiwi", "🥝", 2, 3, "Omnivore", "Bird", ["Terrestrial", "Nocturnal"], "Temperate Forest",
		[], "Resident of New Zealand: a flightless, nocturnal bird.", true)
	_add("res_anem", "Sea Anemone", "🪸", 3, 3, "Symbiont", "Other Invertebrate", ["Aquatic"], "Coral Reef",
		["symbiosis:Clownfish:2"], "Resident of the Great Barrier Reef.", true)


static func get_card(id: String) -> CardData:
	_ensure()
	return _cards[id]


static func all_cards() -> Array:
	_ensure()
	return _cards.values()


static func has_card(id: String) -> bool:
	_ensure()
	return _cards.has(id)


const ROLE_ORDER := ["Producer", "Herbivore", "Omnivore", "Predator", "Decomposer", "Pollinator", "Symbiont", "Parasite", "Pathogen"]
const MAX_PATHOGENS := 2


## Every collectible species (no tokens or Residents), sorted by role, then cost, then name.
static func collection() -> Array:
	_ensure()
	var out: Array = []
	for c in _cards.values():
		if not c.token:
			out.append(c)
	out.sort_custom(func(a, b):
		var ra := ROLE_ORDER.find(a.role)
		var rb := ROLE_ORDER.find(b.role)
		if ra != rb:
			return ra < rb
		if a.cost != b.cost:
			return a.cost < b.cost
		return a.display_name < b.display_name)
	return out


## A Community is exactly 12 different collectible species.
static func is_valid_community(cards: PackedStringArray) -> bool:
	if cards.size() != 12:
		return false
	var seen := {}
	var pathogens := 0
	for id in cards:
		if seen.has(id) or not has_card(id) or get_card(id).token:
			return false
		seen[id] = true
		if get_card(id).is_pathogen():
			pathogens += 1
	return pathogens <= MAX_PATHOGENS


## The starter Community the player begins with.
static func player_community() -> PackedStringArray:
	return PackedStringArray(["grass", "oak", "moss", "phyto", "rabbit", "zebra",
		"turtle", "fox", "lion", "myc", "worm", "clown"])


static func rival_community() -> PackedStringArray:
	return PackedStringArray(["grass", "saguaro", "kelp", "ant", "turtle", "eagle",
		"shark", "beetle", "anem", "cuckoo", "rabies", "locust"])
