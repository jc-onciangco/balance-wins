extends SceneTree
## Focused rule checks for pathogens, merging, migration, Seed Bank effects, zones and regions.
## Run: godot --headless --path . --script res://tests/rules_test.gd

var fails := 0
var passes := 0


func check(cond: bool, what: String) -> void:
	if cond:
		passes += 1
	else:
		fails += 1
		print("FAIL: ", what)


func region(id: String) -> RegionData:
	for r in RegionLibrary.all():
		if r.id == id:
			return r
	return null


## A manager with three chosen, revealed, empty ecosystems.
func setup(ids: Array, season := 3) -> MatchManager:
	var m := MatchManager.new()
	m.start(1)
	m.ecos = []
	for i in ids.size():
		var e := EcosystemState.new(region(ids[i]), i)
		e.revealed = true
		m.ecos.append(e)
	m.season = season
	m.pending = [[], []]
	m.pending_choices = []
	return m


func put(m: MatchManager, ei: int, side: int, si: int, id: String) -> CardInstance:
	var c := CardInstance.new(CardLibrary.get_card(id), side)
	m.ecos[ei].slots[side][si] = c
	Rules.recompute(m.ecos, m.season)
	return c


func _init() -> void:
	# Savannah Grassland rewards Producers or Herbivores; Acacia Woodland rewards Climbing or Flying
	var m := setup(["serengeti", "reef", "newzealand"])
	var grass := put(m, 0, 0, 1, "grass")
	check(grass.value == 2 + 1 + 1, "Grassland gives a Producer +1 (plus native +1)")
	var eagle := put(m, 0, 0, 2, "eagle")
	check(Rules.zone_bonus(eagle.data, m.ecos[0].region.zones[2]) == 1, "Acacia Woodland gives a Flying species +1")

	# Zone hints
	var turtle := CardLibrary.get_card("turtle")
	m.nutrients = [10, 10]
	check(m.block_reason(0, turtle, 0, 0) == "Land only", "aquatic species blocked from land zones")
	check(m.block_reason(0, CardLibrary.get_card("grass"), 1, 0) == "Water only", "land species blocked from reef")
	check(Rules.block_reason(m.ecos[0], CardLibrary.get_card("eagle"), 1, m.season) == "End zones only", "end-zone-only species blocked from middle")
	m.nutrients = [0, 0]
	check(m.block_reason(0, CardLibrary.get_card("lion"), 0, 3) == "Too expensive", "cost shown as reason")

	# Pathogens: targeting, static effect, Dusk damage, spread and dilution
	m = setup(["serengeti", "bialowieza", "reef"])
	m.nutrients = [10, 10]
	var rab := put(m, 0, 1, 0, "rabbit")
	var zeb := put(m, 0, 1, 1, "zebra")
	var gr := put(m, 0, 1, 2, "grass")
	var lion := put(m, 0, 1, 3, "lion")
	var rabies := CardLibrary.get_card("rabies")
	check(not m.can_infect(0, rabies, 0, 2), "rabies can't target a plant")
	check(m.can_infect(0, rabies, 0, 0), "rabies can target a mammal")
	m.hands[0] = [rabies]
	check(m.infect(0, 0, 0, 0), "infect queues the pathogen")
	m._resolve_reveals()
	check(rab.infection == rabies, "rabies attaches on reveal")
	var before := zeb.perm_mod
	m._dusk_pathogens()
	check(zeb.infection == rabies, "rabies spreads to the adjacent mammal")
	check(rab.perm_mod == -1, "rabies deals -1 at Dusk")
	m._dusk_pathogens()
	check(gr.infection == null and lion.infection == null, "the grass blocks spread to the lion (dilution)")
	var blight := CardLibrary.get_card("blight")
	var oak := put(m, 1, 1, 2, "oak")
	var v0 := oak.value
	oak.infection = blight
	Rules.recompute(m.ecos, m.season)
	check(oak.value == v0 - 2, "chestnut blight gives -2")

	# Immunity and cures
	var opo := put(m, 1, 1, 0, "opossum")
	check(not Rules.can_be_infected(rabies, opo), "opossum is immune to rabies")
	var vul := put(m, 1, 1, 1, "vulture")
	opo.infection = CardLibrary.get_card("myxoma")
	m._emergence(1, 1, 1)
	check(opo.infection == null, "vulture cures an adjacent species")

	# Bite: predator that kills an infected prey gets infected
	m = setup(["serengeti", "bialowieza", "reef"])
	var prey := put(m, 0, 1, 1, "kit")
	prey.infection = rabies
	var fox := put(m, 0, 0, 1, "fox")
	m._emergence(0, 0, 1)
	check(m.ecos[0].card_at(1, 1) == null, "fox preys on the weak herbivore")
	check(fox.infection == rabies, "rabies bite infects the predator")

	# Merging
	m = setup(["bialowieza", "reef", "serengeti"])
	var host := put(m, 0, 0, 1, "grass")
	put(m, 0, 0, 2, "lichen")
	m._emergence(0, 0, 2)
	check(m.ecos[0].card_at(0, 2) == null, "lichen leaves its zone when it fuses")
	check(host.extra_roles.has("Decomposer"), "fusion host gains the Decomposer role")
	check(m.ecos[0].succession[0][2] == false, "merging doesn't trigger Succession")
	put(m, 0, 0, 0, "rabbit")
	Rules.recompute(m.ecos, m.season)
	var ev := Rules.evaluate(m.ecos[0], 0)
	check(not ev["fail_req"], "fused Decomposer role meets the forest's Decomposer requirement")
	var coral := put(m, 1, 0, 2, "braincoral")
	var cv0 := coral.value
	put(m, 1, 0, 3, "zoox")
	m._emergence(0, 1, 3)
	Rules.recompute(m.ecos, m.season)
	check(coral.extra_roles.has("Producer") and coral.value == cv0 + 1 + 2 + 1, "zooxanthellae fuses into brain coral (+1 base +2 bonus +1 per merged)")
	var her := put(m, 2, 0, 1, "zebra")
	var hz := her.value
	put(m, 2, 0, 0, "armyant")
	m._emergence(0, 2, 0)
	Rules.recompute(m.ecos, m.season)
	check(her.value >= hz + 3 - 1, "army ant colony adds biomass to the herbivore")
	var fem := put(m, 1, 0, 0, "femaleangler")
	put(m, 1, 0, 1, "maleangler")
	m._emergence(0, 1, 1)
	check(Rules.is_resilient(m.ecos, 1, 0, 0), "absorbed male anglerfish makes the female Resilient")

	# Seasonal migration with herd
	m = setup(["serengeti", "bialowieza", "reef"], 4)
	var wb := put(m, 0, 0, 1, "wildebeest")
	var buddy := put(m, 0, 0, 2, "zebra")
	m._dusk_migration()
	check(m.ecos[1].slots[0].has(wb), "wildebeest migrates in season 4")
	check(m.ecos[1].slots[0].has(buddy), "an adjacent herbivore travels with the herd")
	m = setup(["serengeti", "bialowieza", "reef"], 2)
	var tern := put(m, 0, 0, 0, "tern")
	m._dusk_migration()
	check(m.ecos[0].slots[0].has(tern), "arctic tern stays outside its seasons")
	m.season = 3
	m._dusk_migration()
	check(m.ecos[1].slots[0].has(tern), "arctic tern migrates in season 3")

	# Salmon subsidy
	m = setup(["bialowieza", "reef", "serengeti"])
	var prod := put(m, 0, 0, 0, "grass")
	put(m, 1, 0, 0, "salmon")
	var p0 := prod.perm_mod
	m._perish(1, 0, 0, "test")
	check(prod.perm_mod == p0 + 2, "salmon feeds producers in adjacent ecosystems when it perishes")

	# Seed Bank effects
	m = setup(["bialowieza", "reef", "serengeti"])
	var w := put(m, 0, 0, 0, "walnut")
	m._emergence(0, 0, 0)
	check(m.skip_draw[1], "allelopathy blocks the rival's next draw")
	var b := put(m, 0, 0, 1, "beech")
	m._emergence(0, 0, 1)
	m.season += 1
	check(m.cost_for(0, CardLibrary.get_card("lion"), m.ecos[0]) == 3, "mast year lowers costs next season")
	var hand_before: int = m.hands[1].size()
	var snake := put(m, 0, 0, 2, "eggsnake")
	m._emergence(0, 0, 2)
	check(m.hands[1].size() == hand_before - 1, "nest raid removes a card from the rival's Nest")
	var deck_before: int = m.decks[1].size()
	put(m, 0, 0, 3, "woodmouse")
	m._emergence(0, 0, 3)
	check(m.decks[1].size() == maxi(deck_before - 2, 0), "seed predation mills 2 from the rival's Seed Bank")
	m.decks[0] = [CardLibrary.get_card("oak"), CardLibrary.get_card("rabbit"), CardLibrary.get_card("fox")]
	m.hands[0] = []
	m._queue_recruit(0, "Producer", "Test")
	check(m.hands[0].has(CardLibrary.get_card("oak")), "recruit with one option resolves at once")
	m.decks[0] = [CardLibrary.get_card("lion"), CardLibrary.get_card("rabbit"), CardLibrary.get_card("fox"), CardLibrary.get_card("zebra")]
	m._queue_recruit(0, "Mammal", "Test")
	check(m.pending_choices.size() == 1, "recruit with several options waits for the player")
	m.resolve_recruit(m.pending_choices[0], CardLibrary.get_card("fox"))
	check(m.hands[0].has(CardLibrary.get_card("fox")) and m.pending_choices.is_empty(), "player picks the recruited species")
	m._queue_lookout(0, 3, "Test")
	var top: CardData = m.decks[0].back()
	m.resolve_lookout(m.pending_choices[0], [top])
	check(m.decks[0][0] == top, "lookout sends a card to the bottom")
	m.detritus[0] = [CardLibrary.get_card("oak")]
	var bk := put(m, 1, 0, 0, "zoox")
	m.ecos[1].slots[0][0] = null
	put(m, 2, 0, 0, "banksia")
	m.hands[0] = []
	m._emergence(0, 2, 0)
	check(m.hands[0].has(CardLibrary.get_card("oak")), "resprout returns a producer from Detritus")
	put(m, 2, 0, 1, "squirrel")
	m.nutrients[0] = 3
	m._dusk()
	check(m.cache_nutrients[0] == 2, "cache stores up to 2 unspent nutrients")
	var frog := put(m, 2, 0, 2, "frog")
	m.decks[0] = [CardLibrary.get_card("lion"), CardLibrary.get_card("rabbit")]
	m.hands[0] = []
	m._emergence(0, 2, 2)
	m._dusk()
	check(m.hands[0].size() == 2, "hatch draws 2 at Dusk")

	# New Zealand: Land of Birds and island doubling
	m = setup(["newzealand", "reef", "serengeti"])
	var kiwi := put(m, 0, 0, 1, "kiwi")
	var k0 := kiwi.value
	put(m, 0, 1, 3, "fox")
	Rules.recompute(m.ecos, m.season)
	check(kiwi.value == k0 - 1, "a land predator in New Zealand gives birds -1, even across sides")
	var target := put(m, 0, 0, 2, "rabbit")
	var t0 := target.value
	target.infection = CardLibrary.get_card("myxoma")
	Rules.recompute(m.ecos, m.season)
	check(target.value == maxi(t0 - 4, 0), "pathogen effects are doubled on islands")

	print("rules test: ", passes, " passed, ", fails, " failed")
	quit(1 if fails > 0 else 0)
