class_name CardInstance
extends RefCounted
## A card in play. Its displayed biomass (value) is recomputed from scratch by Rules.recompute.

var data: CardData
var owner: int = 0
## Permanent modifiers from Emergence effects, Succession, Parasitize, merges, Dusk damage...
var perm_mod: int = 0
var value: int = 0
## False while a card is placed this season but not yet revealed to the rival.
var revealed: bool = true
var resident: bool = false
var used_succession: bool = false
## Pathogen attached to this species (a CardData of type Pathogen), or null.
var infection: CardData = null
## Species merged into this one (Fusion, Colony, Absorb).
var merged: Array = []
## Extra roles gained through Fusion; they count for role requirements, not the pyramid.
var extra_roles: Array = []
## Ability strings granted by merges, e.g. "resilient" or "facing_aura:1".
var granted: PackedStringArray = PackedStringArray()


func _init(card: CardData = null, owner_side: int = 0) -> void:
	data = card
	owner = owner_side
	if card != null:
		value = card.biomass
