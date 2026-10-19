extends RefCounted
## Test-only orchestration. Core actions always call the production resolver.
const CONTRACTS = preload("res://tests/support/contracts.gd")
static func apply(state: Dictionary, command: Dictionary, contracts: RefCounted) -> Dictionary:
	if command.kind not in ["draw", "advance", "spawn"]:
		return contracts.action(state, command)
	var next: Dictionary = state.duplicate(true)
	match command.kind:
		"draw":
			if command.source == "main":
				next.hand.append(next.deck.pop_front())
			else:
				next.squirrels -= 1
				next.cards[command.token] = command.card.duplicate(true)
				next.hand.append(command.token)
		"advance":
			for lane in range(4):
				if next.enemy[lane] == "" and next.reserve[lane] != "":
					next.enemy[lane] = next.reserve[lane]
					next.reserve[lane] = ""
		"spawn":
			next.cards[command.token] = command.card.duplicate(true)
			next.reserve[command.lane] = command.token
	return {"state": next, "events": [], "error": ""}
