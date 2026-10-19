extends SceneTree
const RULES = preload("res://scripts/battle_rules.gd")
func creature(power := 2, health := 3, sigils: Array = [], owner := "player", cost := 0, cost_type := "blood") -> Dictionary:
	return {"attack": power, "health": health, "sigils": sigils, "owner": owner, "sacrificable": true, "cost": cost, "cost_type": cost_type}
func setup(a: Dictionary, d: Dictionary) -> Dictionary:
	return {"cards": {"a": a, "d": d}, "player": ["a", "", "", "", "", "", "", ""], "enemy": ["d", "", "", ""], "reserve": ["", "", "", ""], "hand": [], "balance": 0, "bones": 0}
func has_event(result: Dictionary, type: String) -> bool:
	return result.events.any(func(event): return event.type == type)
func _initialize() -> void:
	var state := setup(creature(2, 3, ["airborne"]), creature(2, 5, [], "enemy"))
	var original := JSON.stringify(state)
	var result: Dictionary = RULES.resolve_attack(state, "a", 0, false)
	assert(JSON.stringify(state) == original) # Pure: no mutation of input.
	assert(result.state.balance == 2 and result.state.cards.d.health == 5)
	assert(has_event(result, "sigil") and has_event(result, "direct_damage"))
	state.cards.d.sigils = ["mighty_leap"]
	result = RULES.resolve_attack(state, "a", 0, false)
	assert(result.state.balance == 0 and result.state.cards.d.health == 3)
	state.cards.d.sigils = ["waterborne", "mighty_leap"]
	result = RULES.resolve_attack(state, "a", 0, false)
	assert(result.state.balance == 2 and result.state.cards.d.health == 5)
	state = setup(creature(1), creature(2, 3, ["stinky"], "enemy"))
	result = RULES.resolve_attack(state, "a", 0, false)
	assert(has_event(result, "attack_blocked") and not has_event(result, "damage"))
	state.cards.a.attack = 3
	result = RULES.resolve_attack(state, "a", 0, false)
	assert(result.state.cards.d.health == 1 and state.cards.d.health == 3)
	state = setup(creature(1, 3, ["touch_of_death"]), creature(2, 20, [], "enemy"))
	result = RULES.resolve_attack(state, "a", 0, false)
	assert(result.state.enemy[0] == "" and result.state.bones == 0)
	assert(result.events.back().type == "outcome" and result.events.back().won)
	# Quills retaliates on a lethal hit. Mutual wipeout is a player defeat.
	state = setup(creature(1, 1), creature(1, 1, ["sharp_quills"], "enemy"))
	result = RULES.resolve_attack(state, "a", 0, false)
	assert(result.state.enemy[0] == "" and result.state.player[0] == "")
	assert(result.state.bones == 1 and not result.events.back().won)
	state = setup(creature(1, 10), creature(1, 5, ["sharp_quills", "touch_of_death"], "enemy"))
	result = RULES.resolve_attack(state, "a", 0, false)
	assert(result.state.cards.a.health <= 0 and result.state.cards.d.health == 4)
	# Payment/death/bones/play ordering is synchronous and never checks wipeout mid-sacrifice.
	state = setup(creature(), creature(1, 1, [], "enemy"))
	state.cards.s1 = creature(0, 1)
	state.cards.s2 = creature(0, 1)
	state.cards.w = creature(2, 4, [], "player", 2)
	state.player = ["s1", "", "", "", "s2", "", "", ""]
	state.hand = ["w"]
	result = RULES.resolve_play(state, "w", 0, ["s1", "s2"])
	assert(result.error == "" and result.state.player[0] == "w" and result.state.bones == 2)
	var types: Array = result.events.map(func(event): return event.type)
	assert(types == ["payment", "sacrifice", "death", "bones_gained", "sacrifice", "death", "bones_gained", "played"])
	assert(not has_event(result, "outcome") and state.player[0] == "s1")
	assert(not RULES.resolve_play(state, "w", 0, ["s1", "s1"]).error.is_empty())
	state.cards.s1.sacrificable = false
	assert(not RULES.resolve_play(state, "w", 0, ["s1", "s2"]).error.is_empty())
	state.cards.w.cost_type = "bones"
	state.bones = 2
	result = RULES.resolve_play(state, "w", 7, [])
	assert(result.state.bones == 0 and result.state.player[0] == "s1")
	state.bones = 1
	assert(not RULES.resolve_play(state, "w", 7, []).error.is_empty())
	# Back-row targeting works in both directions.
	state = setup(creature(2), creature(2, 4, [], "enemy"))
	state.player[4] = state.player[0]
	state.player[0] = ""
	result = RULES.resolve_attack(state, "d", 0, true)
	assert(result.state.cards.a.health == 1 and result.state.balance == 0)
	print("PASS: pure ordered actions, six sigils, combined retaliation, payments, deaths, bones, two-row targeting")
	quit()
