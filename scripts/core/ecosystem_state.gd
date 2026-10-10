class_name EcosystemState
extends RefCounted
## One ecosystem on the board: a region plus each player's line of zones.

var region: RegionData
var index: int = 0
var revealed: bool = false
## slots[side][zone] -> CardInstance or null. Side 0 = player, 1 = rival.
var slots: Array = [[], []]
## succession[side][zone] -> true if the next species placed there gets +2.
var succession: Array = [[], []]


func _init(r: RegionData = null, i: int = 0) -> void:
	if r == null:
		return
	region = r
	index = i
	slots = [[], []]
	succession = [[], []]
	for side in 2:
		for z in r.zones.size():
			slots[side].append(null)
			succession[side].append(false)


func zone_count() -> int:
	return region.zones.size()


func card_at(side: int, idx: int) -> CardInstance:
	if idx < 0 or idx >= zone_count():
		return null
	return slots[side][idx]


func neighbors(side: int, idx: int) -> Array:
	var out: Array = []
	for j in [idx - 1, idx + 1]:
		var c := card_at(side, j)
		if c != null:
			out.append(c)
	return out


func cards(side: int) -> Array:
	var out: Array = []
	for c in slots[side]:
		if c != null:
			out.append(c)
	return out
