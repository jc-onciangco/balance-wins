class_name RegionData
extends Resource
## A real-world region (Amazon, Serengeti...) belonging to one biome.

@export var id: String = ""
@export var display_name: String = ""
@export var biome: String = ""
## Each zone: {name, kind ("all"|"role"|"trait"|"trait_any"|"none"), key, amount, allow ("land"|"water"|"both"), locked_until}
@export var zones: Array = []
## Climate rule ids handled in Rules.climate_mod
@export var climates: PackedStringArray = PackedStringArray()
@export var climate_text: String = ""
## {type: "role"|"min_roles"|"trait_any", value: ...}
@export var requirement: Dictionary = {}
@export var requirement_text: String = ""
@export var twist_text: String = ""
## Card ids that may appear as mirrored Residents; "none" means no Resident.
## Region tags such as "Island" (Invasive and Pathogen effects doubled).
@export var tags: PackedStringArray = PackedStringArray()
@export var residents: PackedStringArray = PackedStringArray()
