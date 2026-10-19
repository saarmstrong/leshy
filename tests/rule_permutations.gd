extends SceneTree
const CONTRACTS = preload("res://tests/support/contracts.gd")
const SIGILS = preload("res://scripts/sigil_library.gd")
var spec = CONTRACTS.new()
var cases := 0
var combat_cases := 0
var payment_cases := 0
var item_cases := 0
func _initialize() -> void:
	spec.context = {"suite": "rule-permutations"}
	var ok := coverage_manifest() and combat_matrix() and shielding_matrix() and payment_matrix() and items_matrix() and ownership_matrix() and invalid_attacks()
	if ok:
		spec.report("rule-permutations", {"cases": cases, "combat": combat_cases, "payments": payment_cases, "items": item_cases, "sigils": SIGILS.DEFINITIONS.keys(), "status": "passed"})
		print("PASS: ", cases, " exhaustive cases (combat=", combat_cases, ", payments=", payment_cases, ", items=", item_cases, "); ", spec.checks, " contracts")
	quit(0 if ok else 1)
func coverage_manifest() -> bool:
	var sigils: Array = SIGILS.DEFINITIONS.keys()
	sigils.sort()
	var expected := ["airborne", "bone_king", "many_lives", "mighty_leap", "sharp_quills", "stinky", "touch_of_death", "unkillable", "waterborne", "worthy_sacrifice"]
	if not spec.require(sigils == expected, "Sigil roster changed: extend the oracle and coverage manifest"):
		return false
	var items: Array = preload("res://scripts/item_library.gd").DEFINITIONS.keys()
	items.sort()
	return spec.require(items == ["fan", "fish_hook", "hourglass", "pliers", "scissors", "squirrel_bottle"], "Item roster changed: extend the expected-effect tests")
func run_action(state: Dictionary, command: Dictionary, label: Dictionary) -> Dictionary:
	cases += 1
	spec.context = {"suite": "rule-permutations", "case": cases, "parameters": label}
	spec.initial = state
	spec.trace = [command]
	var before: String = spec.encode(state)
	var result: Dictionary = spec.action(state, command)
	if not spec.verify(state, command, result, before, cases % 97 == 0):
		return {}
	return result
func combat_case(a_sigils: Array, d_sigils: Array, enemy: bool, row: int, profile: int) -> bool:
	combat_cases += 1
	var state: Dictionary = spec.empty()
	var actor: Dictionary = spec.creature("wolf", "enemy" if enemy else "player", a_sigils)
	var defender: Dictionary = spec.creature("wolf", "player" if enemy else "enemy", d_sigils)
	actor.attack = [0, 1, 3][profile]
	actor.health = [1, 1, 3][profile]
	actor.max_health = actor.health + 2 # Return must heal to the upgraded maximum.
	defender.health = [1, 2, 7][profile]
	defender.max_health = defender.health + 1
	state.cards = {"a": actor, "d": defender}
	state["enemy" if enemy else "player"][0 if enemy else row] = "a"
	state["player" if enemy else "enemy"][row if enemy else 0] = "d"
	state.fan_active = profile == 2
	var command := {"kind": "attack", "actor": "a", "lane": 0 if enemy else row, "enemy": enemy}
	var result := run_action(state, command, {"attack": a_sigils, "defense": d_sigils, "enemy": enemy, "row": row, "profile": profile})
	if result.is_empty():
		return false
	var damage: int = maxi(0, actor.attack - (1 if d_sigils.has("stinky") else 0))
	var direct: bool = damage > 0 and (d_sigils.has("waterborne") or ((a_sigils.has("airborne") or (not enemy and state.fan_active)) and not d_sigils.has("mighty_leap")))
	var hit: bool = damage > 0 and not direct
	var defender_dies: bool = hit and (a_sigils.has("touch_of_death") or damage >= defender.health)
	var attacker_dies: bool = hit and d_sigils.has("sharp_quills") and (d_sigils.has("touch_of_death") or actor.health <= 1)
	var expected_bones := 0
	if (attacker_dies and not enemy) or (defender_dies and enemy):
		expected_bones = 4 if (a_sigils if not enemy else d_sigils).has("bone_king") else 1
	var after: Dictionary = result.state
	if not spec.require(after.balance == (-damage if enemy else damage) * int(direct) and after.bones == expected_bones, "Combat disagrees with damage/bone truth table", {"result": result}):
		return false
	var a_zone := "enemy" if enemy else "player"
	var d_zone := "player" if enemy else "enemy"
	if not spec.require(after[a_zone][0 if enemy else row] == ("" if attacker_dies else "a") and after[d_zone][row if enemy else 0] == ("" if defender_dies else "d"), "Combat removed wrong card or used wrong row"):
		return false
	if not defender_dies and not spec.require(after.cards.d.health == defender.health - (damage if hit else 0), "Incorrect surviving defender health"):
		return false
	if not attacker_dies and not spec.require(after.cards.a.health == actor.health - (1 if hit and d_sigils.has("sharp_quills") else 0), "Incorrect retaliation health"):
		return false
	var damage_events: Array = result.events.filter(func(e): return e.type == "damage")
	var expected_hits := (2 if d_sigils.has("sharp_quills") else 1) if hit else 0
	return spec.require(damage_events.size() == expected_hits and result.events.filter(func(e): return e.type == "attack").size() == int(damage > 0), "Blocked/bypassed attack dealt damage or wrong strike count")
func combat_matrix() -> bool:
	var offense := ["airborne", "touch_of_death", "unkillable", "bone_king", "sharp_quills"]
	var defense := ["stinky", "waterborne", "mighty_leap", "sharp_quills", "touch_of_death", "unkillable", "bone_king"]
	for a_mask in range(32):
		for d_mask in range(128):
			for enemy in [false, true]:
				for row in [0, 4]:
					for profile in range(3):
						if not combat_case(spec.subset(offense, a_mask), spec.subset(defense, d_mask), enemy, row, profile):
							return false
	# Every subset of all ten sigils, on either side, including irrelevant effects.
	var all: Array = SIGILS.DEFINITIONS.keys()
	for mask in range(1 << all.size()):
		for side in [false, true]:
			for enemy in [false, true]:
				for row in [0, 4]:
					var selected: Array = spec.subset(all, mask)
					if not combat_case(selected if side else ["airborne", "touch_of_death"], ["stinky", "sharp_quills", "mighty_leap"] if side else selected, enemy, row, 1):
						return false
	return true
func shielding_matrix() -> bool:
	var all: Array = SIGILS.DEFINITIONS.keys()
	for mask in range(1 << all.size()):
		for lane in range(4):
			for front_present in [false, true]:
				for airborne in [false, true]:
					combat_cases += 1
					var state: Dictionary = spec.empty()
					state.cards = {"front": spec.creature("fox"), "back": spec.creature("wolf"), "enemy": spec.creature("wolf", "enemy", ["airborne"] if airborne else []), "reserve": spec.creature("wolf", "enemy")}
					state.cards.back.health = 5
					state.cards.back.max_health = 5
					var target := "front" if front_present else "back"
					state.cards[target].sigils = spec.subset(all, mask)
					state.player[lane] = "front" if front_present else ""
					state.player[lane + 4] = "back"
					state.enemy[lane] = "enemy"
					state.reserve[lane] = "reserve"
					var result := run_action(state, {"kind": "attack", "actor": "enemy", "lane": lane, "enemy": true}, {"shielding": mask, "lane": lane, "front_present": front_present, "airborne": airborne})
					if result.is_empty():
						return false
					var effects: Array = state.cards[target].sigils
					var power := 1 if effects.has("stinky") else 2
					var direct: bool = effects.has("waterborne") or (airborne and not effects.has("mighty_leap"))
					if not spec.require(result.state.balance == (-power if direct else 0) and result.state.cards.back.health == 5 - (power if not front_present and not direct else 0), "Wrong lane, shielding, or illegal hit through the front row"):
						return false
					if front_present and not spec.require(result.state.cards.front.health == 3 - (0 if direct else power), "Front shield health incorrect"):
						return false
	return true
func payment_matrix() -> bool:
	var effects := ["worthy_sacrifice", "many_lives", "unkillable", "bone_king"]
	for a_mask in range(16):
		for b_mask in range(16):
			for cost in range(7):
				for offered_mask in range(4):
					var offerings: Array = spec.subset(["a", "b"], offered_mask)
					var orders := [offerings]
					if offerings.size() == 2:
						orders.append(["b", "a"])
					for order in orders:
						for slot in [0, 4, 7]:
							payment_cases += 1
							var state: Dictionary = spec.empty()
							state.cards = {"a": spec.creature("squirrel", "player", spec.subset(effects, a_mask)), "b": spec.creature("squirrel", "player", spec.subset(effects, b_mask)), "c": spec.creature("wolf")}
							state.player[0] = "a"
							state.player[4] = "b"
							state.hand = ["c"]
							state.cards.c.cost = cost
							var blood := 0
							var bones := 0
							for token in order:
								blood += 3 if state.cards[token].sigils.has("worthy_sacrifice") else 1
								if not state.cards[token].sigils.has("many_lives"):
									bones += 4 if state.cards[token].sigils.has("bone_king") else 1
							var occupant: String = state.player[slot]
							var valid: bool = blood >= cost and (cost != 0 or order.is_empty()) and (occupant == "" or (order.has(occupant) and not state.cards[occupant].sigils.has("many_lives")))
							var result := run_action(state, {"kind": "play", "actor": "c", "slot": slot, "offerings": order}, {"a": a_mask, "b": b_mask, "cost": cost, "offerings": order, "slot": slot})
							if result.is_empty() or not spec.require(result.error.is_empty() == valid, "Payment acceptance disagrees with blood/occupancy truth table"):
								return false
							if valid and not spec.require(result.state.bones == bones and result.state.player[slot] == "c", "Paid card or bone reward incorrect"):
								return false
	# All bone-bank boundaries and slots; non-sacrificable and duplicate offerings.
	for bank in range(9):
		for cost in range(7):
			for slot in range(8):
				payment_cases += 1
				var state: Dictionary = spec.empty()
				state.cards.c = spec.creature("bone_stoat")
				state.cards.c.cost = cost
				state.hand = ["c"]
				state.bones = bank
				var result := run_action(state, {"kind": "play", "actor": "c", "slot": slot, "offerings": []}, {"bank": bank, "cost": cost, "slot": slot})
				if result.is_empty() or not spec.require(result.error.is_empty() == (bank >= cost), "Bone affordability boundary wrong"):
					return false
				if bank >= cost and not spec.require(result.state.bones == bank - cost, "Bone payment not exact"):
					return false
	for offerings in [["a", "a"], ["missing"], ["enemy"], ["a"]]:
		var state: Dictionary = spec.empty()
		state.cards = {"a": spec.creature("squirrel"), "c": spec.creature("wolf")}
		state.cards.a.sacrificable = false
		state.cards.c.cost = 1
		state.player[0] = "a"
		state.hand = ["c"]
		var result := run_action(state, {"kind": "play", "actor": "c", "slot": 7, "offerings": offerings}, {"invalid_offerings": offerings})
		if result.is_empty() or not spec.require(not result.error.is_empty(), "Invalid sacrifice accepted"):
			return false
	return true
func items_matrix() -> bool:
	var ids: Array = preload("res://scripts/item_library.gd").DEFINITIONS.keys()
	var orders := [[0, 1, 2], [0, 2, 1], [1, 0, 2], [1, 2, 0], [2, 0, 1], [2, 1, 0]]
	for first in ids:
		for second in ids:
			for third in ids:
				for order in orders:
					var state: Dictionary = spec.empty()
					state.items = [first, second, third]
					state.balance = -4
					for lane in range(4):
						var token := "enemy%d" % lane
						state.cards[token] = spec.creature("wolf", "enemy")
						state.enemy[lane] = token
					var pockets := [0, 1, 2]
					for original_index in order:
						item_cases += 1
						var index: int = pockets.find(original_index)
						var item: String = state.items[index]
						var target := 0
						while state.enemy[target] == "":
							target += 1
						var destination: int = state.player.find("")
						var command := {"kind": "item", "index": index, "target": target, "slot": destination}
						var result := run_action(state, command, {"inventory": [first, second, third], "order": order, "original_pocket": original_index})
						if result.is_empty():
							return false
						var waiting: bool = (item == "fan" and state.fan_active) or (item == "hourglass" and state.skip_enemy)
						if not spec.require(result.error.is_empty() != waiting, "Duplicate timed item accepted or valid item rejected"):
							return false
						if not waiting:
							pockets.erase(original_index)
						state = result.state
	# Every tool against every active lane / both rows, with occupied/invalid slots.
	for item in ["scissors", "fish_hook"]:
		for target in range(-1, 5):
			for slot in range(-1, 9):
				item_cases += 1
				var state: Dictionary = spec.empty()
				state.items = [item]
				state.cards = {"e": spec.creature("raven", "enemy"), "p": spec.creature("squirrel")}
				state.enemy[2] = "e"
				state.player[4] = "p"
				var expected: bool = target == 2 and (item == "scissors" or (slot >= 0 and slot < 8 and slot != 4))
				var result := run_action(state, {"kind": "item", "index": 0, "target": target, "slot": slot}, {"item": item, "target": target, "slot": slot})
				if result.is_empty() or not spec.require(result.error.is_empty() == expected, "Item targeting boundary wrong"):
					return false
	return true
func ownership_matrix() -> bool:
	var effects := ["worthy_sacrifice", "many_lives", "unkillable", "bone_king"]
	for mask in range(16):
		for slot in range(8):
			var state: Dictionary = spec.empty()
			state.cards = {"stolen": spec.creature("wolf", "enemy", spec.subset(effects, mask)), "anchor": spec.creature("wolf", "enemy"), "replacement": spec.creature("fox")}
			state.enemy[0] = "stolen"
			state.reserve[3] = "anchor"
			state.hand = ["replacement"]
			state.items = ["fish_hook"]
			var hooked := run_action(state, {"kind": "item", "index": 0, "target": 0, "slot": slot}, {"hooked_sigils": mask, "slot": slot})
			if hooked.is_empty() or not spec.require(hooked.state.cards.stolen.owner == "player" and hooked.state.cards.stolen.sigils == state.cards.stolen.sigils, "Hook failed to preserve/change ownership correctly"):
				return false
			var replacement_slot := 1 if slot == 0 else 0
			var offered := run_action(hooked.state, {"kind": "play", "actor": "replacement", "slot": replacement_slot, "offerings": ["stolen"]}, {"hooked_then_sacrificed": mask, "slot": slot})
			var survives: bool = state.cards.stolen.sigils.has("many_lives")
			var bones := 0 if survives else (4 if state.cards.stolen.sigils.has("bone_king") else 1)
			if offered.is_empty() or not spec.require(offered.state.bones == bones and (offered.state.player[slot] == "stolen") == survives, "Captured sacrifice did not use player-owned triggers"):
				return false
			var fighting: Dictionary = hooked.state.duplicate(true)
			fighting.cards.killer = spec.creature("wolf", "enemy")
			fighting.cards.killer.attack = 9
			fighting.enemy[slot % 4] = "killer"
			var killed := run_action(fighting, {"kind": "attack", "actor": "killer", "lane": slot % 4, "enemy": true}, {"hooked_then_killed": mask, "slot": slot})
			if killed.is_empty() or not spec.require(killed.state.bones == (4 if state.cards.stolen.sigils.has("bone_king") else 1), "Captured death awarded wrong bones"):
				return false
	return true
func invalid_attacks() -> bool:
	var fixture = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/invalid-hand-attack.json"))
	for command in fixture.actions:
		var result := run_action(fixture.initial, command, {"fixture": "invalid-hand-attack"})
		if result.is_empty() or not spec.require(result.error == fixture.expected_error, "Saved invalid-attack regression returned"):
			return false
	var state: Dictionary = spec.empty()
	state.cards = {"hand": spec.creature("wolf"), "board": spec.creature("wolf"), "enemy": spec.creature("wolf", "enemy")}
	state.hand = ["hand"]
	state.player[4] = "board"
	state.reserve[1] = "enemy"
	for command in [{"kind": "attack", "actor": "hand", "lane": 0, "enemy": false}, {"kind": "attack", "actor": "enemy", "lane": 1, "enemy": true}, {"kind": "attack", "actor": "board", "lane": 0, "enemy": false}, {"kind": "attack", "actor": "board", "lane": 12, "enemy": false}, {"kind": "attack", "actor": "board", "lane": -1, "enemy": false}]:
		var result := run_action(state, command, {"invalid_attack": command})
		if result.is_empty() or not spec.require(not result.error.is_empty(), "Hand/reserve/wrong-slot attacker was accepted"):
			return false
	return true
