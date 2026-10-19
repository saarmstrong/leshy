extends RefCounted
const CATALOG = preload("res://scripts/card_catalog.gd")
const ENEMY_SEQUENCE = ["raven", "wolf", "fox", "stag"]
const STARTER = ["fox", "wolf", "raven", "wolf", "bone_stoat", "grave_raven"]
static func encounter(level: int) -> Dictionary:
	return {"active": [],
		"reserve": [{"id": "raven", "lane": 2}, {"id": "wolf", "lane": 1}] if level > 0 else [{"id": "raven", "lane": 2}, {"id": "bone_stoat", "lane": 1}],
		"extra": [{"id": "bone_stoat", "lane": 3}] if level >= 2 else [],
		"sequence_index": 3 if level >= 2 else 2, "reinforcements": 1 + level}
static func opening(deck: Array) -> Array:
	var deal: Array = []
	for key in deck:
		var base = CATALOG.find(str(key).split("#")[0])
		if base.cost_type == "blood" and base.cost == 1:
			deal.append(key)
			deck.erase(key)
			break
	for key in deck.duplicate():
		if deal.size() < 3 and not deal.any(func(other): return str(other).split("#")[0] == str(key).split("#")[0]):
			deal.append(key)
			deck.erase(key)
	while deal.size() < 3 and not deck.is_empty():
		deal.append(deck.pop_front())
	return deal
