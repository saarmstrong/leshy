extends RefCounted
## Seeded, fast balance probe. Uses production actions, opening and encounter data.
## This simple policy is a regression signal, not a prediction of human win rate.
const RULES = preload("res://scripts/battle_rules.gd")
const SETUP = preload("res://scripts/battle_setup.gd")
const CATALOG = preload("res://scripts/card_catalog.gd")
var rng := RandomNumberGenerator.new()
var state: Dictionary
var deck: Array
var serial := 0
var metrics: Dictionary
func add_card(id: String, owner := "player") -> String:
	serial += 1
	var token := "c%d" % serial
	var base = CATALOG.find(id)
	state.cards[token] = {"id": id, "attack": base.attack, "health": base.health, "max_health": base.health, "cost": base.cost, "cost_type": base.cost_type, "sigils": Array(base.sigils), "owner": owner, "sacrificable": base.sacrificable}
	return token
func apply(result: Dictionary) -> String:
	assert(result.error.is_empty())
	state = result.state
	for event in result.events:
		if event.type == "played":
			var id: String = state.cards[event.actor].id
			metrics.plays[id] = metrics.plays.get(id, 0) + 1
		if event.type in ["attack", "attack_blocked"] and state.cards[event.actor].cost_type == "bones":
			var id: String = state.cards[event.actor].id
			var key := "bone_attacks" if event.type == "attack" else "bone_blocks"
			metrics[key][id] = metrics[key].get(id, 0) + 1
		if event.type == "outcome":
			metrics.reason = event.reason
			return "win" if event.won else "loss"
	return ""
func shuffle_seeded(values: Array) -> void:
	for i in range(values.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var old = values[i]
		values[i] = values[j]
		values[j] = old
func sacrifice_value(token: String) -> float:
	var card: Dictionary = state.cards[token]
	return card.attack * 4.0 + card.health * 0.3
func offers_for(card: Dictionary) -> Array:
	if card.cost_type == "bones":
		return []
	var available: Array = state.player.filter(func(token): return token != "" and state.cards[token].sacrificable)
	available.sort_custom(func(a, b): return sacrifice_value(a) < sacrifice_value(b))
	var offerings: Array = []
	var blood := 0
	for token in available:
		if blood >= card.cost:
			break
		offerings.append(token)
		blood += RULES.blood_value(state.cards[token])
	return offerings
func best_slot(card: Dictionary, offerings: Array, careful: bool) -> int:
	var best := -1
	var score := -INF
	for slot in range(8):
		if state.player[slot] != "" and (not offerings.has(state.player[slot]) or state.cards[state.player[slot]].sigils.has("many_lives")):
			continue
		var value := rng.randf() * 20.0
		if careful:
			var actor: String = state.hand.filter(func(token): return state.cards[token] == card)[0]
			var result: Dictionary = RULES.resolve_play(state, actor, slot, offerings)
			value = evaluate_round(result.state) + rng.randf() * 0.01
		if value > score:
			score = value
			best = slot
	return best
func evaluate_round(input: Dictionary) -> float:
	var future: Dictionary = input.duplicate(true)
	for phase in [false, true]:
		if phase:
			for lane in range(4):
				if future.enemy[lane] == "":
					future.enemy[lane] = future.reserve[lane]
					future.reserve[lane] = ""
		var zone: String = "enemy" if phase else "player"
		for lane in range(4 if phase else 8):
			if future[zone][lane] != "":
				var result: Dictionary = RULES.resolve_attack(future, future[zone][lane], lane, phase)
				future = result.state
				for event in result.events:
					if event.type == "outcome":
						return 10000.0 if event.won else -10000.0
	var value: float = future.balance * 10.0 + future.bones * 0.5
	for token in future.player:
		if token != "":
			value += future.cards[token].attack * 3.0 + future.cards[token].health * 0.4 + 1.0
	for token in future.enemy:
		if token != "":
			value -= future.cards[token].health * 0.4
	return value
func play_hand(careful: bool, break_stalemate := false) -> void:
	# Resource cards first; then prefer spending bones and preserving existing power.
	for action in range(12):
		var choices: Array = state.hand.duplicate()
		choices.sort_custom(func(a, b): return state.cards[a].cost == 0 and state.cards[b].cost != 0)
		var played := false
		for token in choices:
			var card: Dictionary = state.cards[token]
			var offers := offers_for(card)
			if card.cost_type == "bones":
				if state.bones < card.cost:
					continue
			elif offers.reduce(func(total, token): return total + RULES.blood_value(state.cards[token]), 0) < card.cost:
				continue
			var lost_attack := 0
			for victim in offers:
				lost_attack += 0 if state.cards[victim].sigils.has("many_lives") else state.cards[victim].attack
			if offers.size() > 0 and lost_attack >= card.attack and not break_stalemate:
				continue
			var slot := best_slot(card, offers, careful)
			if slot < 0:
				continue
			apply(RULES.resolve_play(state, token, slot, offers))
			played = true
			break
		if not played:
			break
func draw_one(squirrels: int) -> int:
	var fodder := 0
	for token in state.player + state.hand:
		if token != "" and state.cards[token].cost == 0:
			fodder += 1
	var needs_blood: bool = state.hand.any(func(token): return state.cards[token].cost_type == "blood" and state.cards[token].cost > fodder)
	if squirrels > 0 and (deck.is_empty() or needs_blood):
		state.hand.append(add_card("squirrel"))
		return squirrels - 1
	if not deck.is_empty():
		state.hand.append(add_card(str(deck.pop_front())))
	return squirrels
func run_seed(seed_value: int, level: int, careful := true, cards: Array = SETUP.STARTER) -> Dictionary:
	rng.seed = seed_value
	serial = 0
	metrics = {"seed": seed_value, "level": level, "policy": "careful" if careful else "reckless", "plays": {}, "bone_attacks": {}, "bone_blocks": {}, "reason": "turn limit", "result": "timeout", "rounds": 0}
	state = {"cards": {}, "player": ["", "", "", "", "", "", "", ""], "enemy": ["", "", "", ""], "reserve": ["", "", "", ""], "hand": [], "bones": 0, "balance": 0}
	deck = cards.duplicate()
	shuffle_seeded(deck)
	for id in SETUP.opening(deck):
		state.hand.append(add_card(id))
	state.hand.append(add_card("squirrel"))
	var config: Dictionary = SETUP.encounter(level)
	for entry in config.active:
		state.enemy[entry.lane] = add_card(entry.id, "enemy")
	for entry in config.reserve + config.extra:
		state.reserve[entry.lane] = add_card(entry.id, "enemy")
	var reinforcements: int = config.reinforcements
	var sequence: int = config.sequence_index
	var squirrels := 9
	var previous_board := ""
	var stagnant_rounds := 0
	for round_index in range(1, 41):
		metrics.rounds = round_index
		if round_index > 1 and deck.is_empty() and squirrels == 0:
			var outcome := apply(RULES.resolve_starvation(state))
			if outcome != "":
				metrics.result = outcome
				return metrics
		if round_index > 1:
			squirrels = draw_one(squirrels)
		var board_key := JSON.stringify([state.player, state.enemy, state.reserve, state.balance, state.cards], "", true)
		stagnant_rounds = stagnant_rounds + 1 if board_key == previous_board else 0
		previous_board = board_key
		metrics.stagnant_max = maxi(metrics.get("stagnant_max", 0), stagnant_rounds)
		play_hand(careful, stagnant_rounds >= 2)
		for lane in range(8):
			if state.player[lane] != "":
				var outcome := apply(RULES.resolve_attack(state, state.player[lane], lane, false))
				if outcome != "":
					metrics.result = outcome
					return metrics
		for lane in range(4):
			if state.enemy[lane] == "" and state.reserve[lane] != "":
				state.enemy[lane] = state.reserve[lane]
				state.reserve[lane] = ""
		for lane in range(4):
			if state.enemy[lane] != "":
				var outcome := apply(RULES.resolve_attack(state, state.enemy[lane], lane, true))
				if outcome != "":
					metrics.result = outcome
					return metrics
		if reinforcements > 0:
			for offset in range(4):
				var lane := (round_index + 1 + offset) % 4
				if state.reserve[lane] == "":
					state.reserve[lane] = add_card(SETUP.ENEMY_SEQUENCE[sequence % 4], "enemy")
					sequence += 1
					reinforcements -= 1
					break
	return metrics
