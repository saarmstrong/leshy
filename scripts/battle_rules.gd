extends RefCounted
## Pure synchronous rules. Inputs contain values/IDs only, never Nodes or Tweens.
## Resolve a whole action atomically, then let the scene present ordered events.
static func _result(state: Dictionary, events: Array, error := "") -> Dictionary:
	return {"state": state, "events": events, "error": error}
static func _has(card: Dictionary, sigil: String) -> bool:
	return card.get("sigils", []).has(sigil)
static func _trigger(events: Array, actor: String, sigil: String) -> void:
	events.append({"type": "sigil", "actor": actor, "sigil": sigil})
static func _death(state: Dictionary, id: String, events: Array, cause: String) -> void:
	var card: Dictionary = state.cards[id]
	for zone in ["player", "enemy", "reserve", "hand"]:
		var index: int = state[zone].find(id)
		if index >= 0:
			if zone == "hand":
				state[zone].remove_at(index)
			else:
				state[zone][index] = ""
	if card.owner == "player" and _has(card, "bone_king"):
		_trigger(events, id, "bone_king")
	if card.owner == "player" and _has(card, "unkillable"):
		_trigger(events, id, "unkillable")
	events.append({"type": "death", "actor": id, "cause": cause, "player_owned": card.owner == "player"})
	if card.owner == "player":
		var amount := 4 if _has(card, "bone_king") else 1
		state.bones += amount
		events.append({"type": "bones_gained", "actor": id, "amount": amount})
	if card.owner == "player" and _has(card, "unkillable"):
		card.health = int(card.get("max_health", maxi(1, card.health)))
		state.hand.append(id)
		events.append({"type": "returned", "actor": id})
static func _outcome(state: Dictionary, events: Array, combat_death: bool) -> void:
	var player_empty: bool = state.player.all(func(id): return id == "")
	var opponent_empty: bool = state.enemy.all(func(id): return id == "") and state.reserve.all(func(id): return id == "")
	if combat_death and player_empty:
		events.append({"type": "outcome", "won": false, "reason": "Your last creature has fallen."})
	elif combat_death and opponent_empty:
		events.append({"type": "outcome", "won": true, "reason": "The last opposing creature has fallen."})
	elif abs(state.balance) >= 5:
		events.append({"type": "outcome", "won": state.balance >= 5, "reason": "The balance has tipped in your favor." if state.balance >= 5 else "The balance has tipped against you."})

static func blood_value(card: Dictionary) -> int:
	return 3 if _has(card, "worthy_sacrifice") else 1

static func resolve_play(input: Dictionary, actor: String, slot: int, offerings: Array) -> Dictionary:
	var state: Dictionary = input.duplicate(true)
	var events: Array = []
	if slot < 0 or slot >= 8 or not state.hand.has(actor):
		return _result(input, [], "Invalid card or destination.")
	var card: Dictionary = state.cards[actor]
	var seen := {}
	if card.cost_type == "bones":
		if not offerings.is_empty() or state.bones < card.cost:
			return _result(input, [], "Not enough bones.")
	else:
		var blood := 0
		for id in offerings:
			if seen.has(id) or not state.player.has(id) or not state.cards[id].sacrificable:
				return _result(input, [], "Invalid offering.")
			seen[id] = true
			blood += blood_value(state.cards[id])
		if blood < card.cost or (card.cost == 0 and not offerings.is_empty()):
			return _result(input, [], "Not enough blood.")
	if state.player[slot] != "" and (not offerings.has(state.player[slot]) or _has(state.cards[state.player[slot]], "many_lives")):
		return _result(input, [], "That slot is occupied.")
	events.append({"type": "payment", "actor": actor, "cost_type": card.cost_type, "amount": card.cost})
	if card.cost_type == "bones":
		state.bones -= card.cost
	for id in offerings:
		events.append({"type": "sacrifice", "actor": id})
		if _has(state.cards[id], "worthy_sacrifice"):
			_trigger(events, id, "worthy_sacrifice")
		if _has(state.cards[id], "many_lives"):
			_trigger(events, id, "many_lives")
		else:
			_death(state, id, events, "sacrifice")
	state.hand.erase(actor)
	state.player[slot] = actor
	events.append({"type": "played", "actor": actor, "slot": slot})
	return _result(state, events)

static func resolve_attack(input: Dictionary, actor: String, lane: int, enemy: bool) -> Dictionary:
	var state: Dictionary = input.duplicate(true)
	var events: Array = []
	if not state.cards.has(actor) or state.cards[actor].health <= 0 or lane < 0 or lane >= (4 if enemy else 8):
		return _result(input, [], "Invalid attacker.")
	if state["enemy" if enemy else "player"][lane] != actor or state.cards[actor].owner != ("enemy" if enemy else "player"):
		return _result(input, [], "Invalid attacker.")
	var attacker: Dictionary = state.cards[actor]
	var slot := lane % 4
	var zone := "player" if enemy else "enemy"
	if enemy and state.player[slot] == "":
		slot += 4
	var victim: String = state[zone][slot]
	var power: int = attacker.attack
	if victim != "" and _has(state.cards[victim], "stinky"):
		power = maxi(0, power - 1)
		_trigger(events, victim, "stinky")
	if power <= 0:
		events.append({"type": "attack_blocked", "actor": actor})
		return _result(state, events)
	events.append({"type": "attack", "actor": actor, "slot": slot, "enemy": enemy})
	if victim != "" and _has(state.cards[victim], "waterborne"):
		_trigger(events, victim, "waterborne")
		victim = ""
	elif victim != "" and (_has(attacker, "airborne") or (not enemy and state.get("fan_active", false))):
		_trigger(events, actor, "airborne")
		if _has(state.cards[victim], "mighty_leap"):
			_trigger(events, victim, "mighty_leap")
		else:
			victim = ""
	if victim == "":
		state.balance += -power if enemy else power
		events.append({"type": "direct_damage", "actor": actor, "amount": power, "slot": slot, "enemy": enemy})
		events.append({"type": "attack_return", "actor": actor})
		_outcome(state, events, false)
		return _result(state, events)
	var defender: Dictionary = state.cards[victim]
	defender.health -= power
	if _has(attacker, "touch_of_death"):
		defender.health = 0
		_trigger(events, actor, "touch_of_death")
	events.append({"type": "damage", "actor": actor, "target": victim, "amount": power, "remaining_health": defender.health})
	# Retaliation is resolved even if the normal hit is lethal.
	if _has(defender, "sharp_quills"):
		_trigger(events, victim, "sharp_quills")
		attacker.health -= 1
		if _has(defender, "touch_of_death"):
			attacker.health = 0
			_trigger(events, victim, "touch_of_death")
		events.append({"type": "damage", "actor": victim, "target": actor, "amount": 1, "remaining_health": attacker.health, "retaliation": true})
	events.append({"type": "attack_return", "actor": actor})
	var died := false
	for id in [victim, actor]:
		if state.cards[id].health <= 0:
			_death(state, id, events, "combat")
			died = true
	_outcome(state, events, died)
	return _result(state, events)

static func resolve_starvation(input: Dictionary) -> Dictionary:
	var state: Dictionary = input.duplicate(true)
	var events: Array = []
	state.starvation = int(state.get("starvation", 0)) + 1
	state.balance -= state.starvation
	events.append({"type": "starvation", "amount": state.starvation})
	_outcome(state, events, false)
	return _result(state, events)

static func resolve_item(input: Dictionary, index: int, target := -1, destination := -1) -> Dictionary:
	var state: Dictionary = input.duplicate(true)
	var events: Array = []
	var inventory: Array = state.get("items", [])
	if index < 0 or index >= inventory.size():
		return _result(input, [], "No item in that pocket.")
	var item: String = inventory[index]
	if not preload("res://scripts/item_library.gd").DEFINITIONS.has(item):
		return _result(input, [], "Unknown item.")
	if item in ["scissors", "fish_hook"]:
		if target < 0 or target >= 4 or state.enemy[target] == "":
			return _result(input, [], "Choose an active enemy, not a reserve card.")
	if item == "fish_hook" and (destination < 0 or destination >= 8 or state.player[destination] != ""):
		return _result(input, [], "Choose an empty slot in either of your rows.")
	if (item == "hourglass" and state.get("skip_enemy", false)) or (item == "fan" and state.get("fan_active", false)):
		return _result(input, [], "That effect is already waiting.")
	inventory.remove_at(index)
	events.append({"type": "item_used", "item": item})
	match item:
		"squirrel_bottle":
			var serial: int = int(state.get("generated_serial", 0)) + 1
			var token := "bottle_%d" % serial
			while state.cards.has(token):
				serial += 1
				token = "bottle_%d" % serial
			state.generated_serial = serial
			state.cards[token] = {"base_id": "squirrel", "attack": 0, "health": 1, "max_health": 1, "sigils": [], "owner": "player", "sacrificable": true, "cost": 0, "cost_type": "blood"}
			state.hand.append(token)
			events.append({"type": "created", "actor": token})
		"pliers":
			state.balance += 1
		"scissors":
			_death(state, state.enemy[target], events, "item")
		"hourglass":
			state.skip_enemy = true
		"fan":
			state.fan_active = true
		"fish_hook":
			var token: String = state.enemy[target]
			state.enemy[target] = ""
			state.player[destination] = token
			state.cards[token].owner = "player"
			events.append({"type": "stolen", "actor": token, "slot": destination})
	# A tool cannot kill our army: an empty opening board is not a wipeout.
	if item in ["scissors", "fish_hook"] and state.enemy.all(func(id): return id == "") and state.reserve.all(func(id): return id == ""):
		events.append({"type": "outcome", "won": true, "reason": "The last opposing creature has fallen."})
	else:
		_outcome(state, events, false)
	return _result(state, events)

static func resolve_round_cleanup(input: Dictionary) -> Dictionary:
	var state: Dictionary = input.duplicate(true)
	state.skip_enemy = false
	state.fan_active = false
	return _result(state, [])
