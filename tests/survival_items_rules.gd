extends SceneTree
const RULES = preload("res://scripts/battle_rules.gd")
const CATALOG = preload("res://scripts/card_catalog.gd")
func card(id: String, owner := "player") -> Dictionary:
	var base = CATALOG.find(id)
	return {"attack": base.attack, "health": base.health, "max_health": base.health, "cost": base.cost, "cost_type": base.cost_type, "sigils": Array(base.sigils), "sacrificable": base.sacrificable, "owner": owner}
func setup() -> Dictionary:
	return {"cards": {"a": card("ashen_stag"), "c": card("ossuary_hound"), "e": card("wolf", "enemy"), "q": card("raven", "enemy")}, "player": ["a", "", "", "", "", "", "", ""], "enemy": ["e", "", "", ""], "reserve": ["", "q", "", ""], "hand": ["c"], "bones": 0, "balance": 0, "items": []}
func _initialize() -> void:
	var state := setup()
	var old := JSON.stringify(state)
	var result: Dictionary = RULES.resolve_play(state, "c", 0, ["a"])
	assert(JSON.stringify(state) == old and result.error == "")
	assert(result.state.player[0] == "c" and result.state.bones == 1)
	assert(result.events.any(func(e): return e.type == "sigil" and e.sigil == "worthy_sacrifice"))
	state.cards.c.cost = 2 # Overpayment is legal; surplus is not banked.
	assert(RULES.resolve_play(state, "c", 4, ["a"]).error == "")
	assert(RULES.resolve_play(state, "c", 4, ["a", "a"]).error != "")
	state.cards.a.sigils.append("many_lives")
	result = RULES.resolve_play(state, "c", 4, ["a"])
	assert(result.error == "" and result.state.player[0] == "a" and result.state.player[4] == "c" and result.state.bones == 0)
	assert(not result.events.any(func(e): return e.type == "death"))
	assert(RULES.resolve_play(state, "c", 0, ["a"]).error != "")
	# Many Lives survives sacrifices but dies to combat. Bone King and Unkillable combine.
	state = setup()
	state.cards.a = card("revenant_raven")
	state.cards.a.sigils.append("bone_king")
	state.cards.a.attack = 4
	state.cards.a.max_health = 5
	state.cards.a.health = 1
	result = RULES.resolve_attack(state, "e", 0, true)
	assert(result.state.bones == 4 and result.state.hand.has("a"))
	assert(result.state.cards.a.health == 5 and result.state.cards.a.attack == 4)
	assert(result.events.back().type == "outcome" and not result.events.back().won) # Wipeout still ends battle.
	state = setup()
	state.cards.a = card("revenant_raven")
	state.cards.c.cost = 1
	result = RULES.resolve_play(state, "c", 4, ["a"])
	assert(result.state.hand == ["a"] and result.state.player[4] == "c" and result.state.bones == 1)
	# Item failures preserve the entire input and do not consume anything.
	for item in ["scissors", "fish_hook"]:
		state = setup()
		state.items = [item]
		old = JSON.stringify(state)
		assert(RULES.resolve_item(state, 0, 3, 4).error != "")
		assert(JSON.stringify(state) == old)
	state = setup()
	state.items = ["fish_hook"]
	assert(RULES.resolve_item(state, 0, 0, 0).error != "")
	result = RULES.resolve_item(state, 0, 0, 7)
	assert(result.state.enemy[0] == "" and result.state.player[7] == "e" and result.state.cards.e.owner == "player")
	assert(result.state.cards.e.health == 4 and result.state.items.is_empty())
	state.items = ["scissors"]
	result = RULES.resolve_item(state, 0, 0)
	assert(result.state.enemy[0] == "" and result.state.bones == 0 and result.state.items.is_empty())
	state.player[0] = "" # Item use before deploying is not a player wipeout.
	result = RULES.resolve_item(state, 0, 0)
	assert(not result.events.any(func(e): return e.type == "outcome"))
	state.reserve[1] = ""
	result = RULES.resolve_item(state, 0, 0)
	assert(result.events.back().type == "outcome" and result.events.back().won)
	state.items = ["squirrel_bottle", "squirrel_bottle"]
	result = RULES.resolve_item(state, 0)
	var first: String = result.state.hand.back()
	result = RULES.resolve_item(result.state, 0)
	assert(result.state.hand.back() != first and result.state.hand.size() == 3)
	state.items = ["pliers"]
	state.balance = 4
	result = RULES.resolve_item(state, 0)
	assert(result.state.balance == 5 and result.events.back().won)
	state = setup()
	state.items = ["hourglass", "hourglass", "fan"]
	result = RULES.resolve_item(state, 0)
	assert(result.state.skip_enemy and RULES.resolve_item(result.state, 0).error != "")
	result = RULES.resolve_item(result.state, 1)
	assert(result.state.fan_active)
	result.state.cards.a.attack = 2
	var hit: Dictionary = RULES.resolve_attack(result.state, "a", 0, false)
	assert(hit.state.balance == 2 and hit.state.cards.e.health == 4)
	result.state.cards.e.sigils = ["mighty_leap"]
	hit = RULES.resolve_attack(result.state, "a", 0, false)
	assert(hit.state.balance == 0 and hit.state.cards.e.health == 2)
	result = RULES.resolve_round_cleanup(result.state)
	assert(not result.state.fan_active and not result.state.skip_enemy)
	print("PASS: four survival sigils, combined deaths/upgrades, overpayment, slot safety, all six items and expiration")
	quit()
