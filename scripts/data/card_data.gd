class_name CardData
extends Resource
## Static definition of one species (or token). Instances in play are CardInstance.

## "Species" (placed in zones) or "Pathogen" (attaches to a rival species).
@export var card_type: String = "Species"
@export var id: String = ""
@export var display_name: String = ""
@export var emoji: String = ""
@export var cost: int = 1
@export var biomass: int = 1
## Producer, Herbivore, Predator, Omnivore, Decomposer, Pollinator, Symbiont, Parasite
@export var role: String = "Producer"
## Mammal, Bird, Reptile, Amphibian, Fish, Insect, Other Invertebrate, Plant, Algae, Fungus, Microbe
@export var taxon: String = "Plant"
@export var traits: PackedStringArray = PackedStringArray()
## Biome name that gives +1 when played in a region of that biome.
@export var native_biome: String = ""
## Ability ids with parameters, e.g. "symbiosis:anem:3". Handled in Rules and MatchManager.
@export var abilities: PackedStringArray = PackedStringArray()
@export_multiline var text: String = ""
## Tokens (offspring, chicks, residents) never appear in a Community.
@export var token: bool = false


func has_trait(t: String) -> bool:
	return traits.has(t)


func is_pathogen() -> bool:
	return card_type == "Pathogen"


func is_aquatic_only() -> bool:
	return has_trait("Aquatic") and not has_trait("Terrestrial")
