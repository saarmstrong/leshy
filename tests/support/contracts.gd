extends RefCounted
## Independent state/event contracts shared by exhaustive and randomized probes.
const RULES = preload("res://scripts/battle_rules.gd")
const CATALOG = preload("res://scripts/card_catalog.gd")
const ITEMS = preload("res://scripts/item_library.gd")
var context: Dictionary = {}
var trace: Array = []
var initial: Dictionary = {}
var checks := 0
var failed := false
func encode(value: Variant) -> String:
	return JSON.stringify(normalize(value), "", true, true)
func normalize(value: Variant) -> Variant:
	# JSON save files load whole numbers as floats; compare their semantic value.
	if typeof(value) == TYPE_FLOAT and value == floor(value):
		return int(value)
	if value is Dictionary:
		var result := {}
		for key in value:
			result[key] = normalize(value[key])
		return result
	if value is Array:
		return value.map(normalize)
	return value
func require(condition: bool, message: String, detail: Dictionary = {}) -> bool:
	checks += 1
	if condition:
		return true
	if not failed:
		failed = true
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://reports/failures"))
		var record := {"engine_version": Engine.get_version_info().string, "context": context, "message": message, "detail": detail, "initial": initial, "actions": trace}
		var file := FileAccess.open("res://reports/failures/%s.json" % context.get("suite", "contracts"), FileAccess.WRITE)
		file.store_string(JSON.stringify(record, "\t", true, true) + "\n")
		printerr("FAIL ", message, " ", encode(context), " — see reports/failures/", context.get("suite", "contracts"), ".json")
	return false
func creature(id: String, owner := "player", sigils: Array = []) -> Dictionary:
	var base = CATALOG.find(id)
	return {"base_id": id, "attack": base.attack, "health": base.health, "max_health": base.health, "cost": base.cost, "cost_type": base.cost_type, "sigils": sigils.duplicate(), "sacrificable": base.sacrificable, "owner": owner}
func empty() -> Dictionary:
	return {"cards": {}, "player": ["", "", "", "", "", "", "", ""], "enemy": ["", "", "", ""], "reserve": ["", "", "", ""], "hand": [], "bones": 0, "balance": 0, "items": [], "fan_active": false, "skip_enemy": false, "starvation": 0}
func subset(values: Array, mask: int) -> Array:
	var result: Array = []
	for i in range(values.size()):
		if mask & (1 << i):
			result.append(values[i])
	return result
func state_valid(state: Dictionary) -> bool:
	if not require(state.player.size() == 8 and state.enemy.size() == 4 and state.reserve.size() == 4, "Board shape changed", {"state": state}):
		return false
	if not require(state.bones >= 0 and state.items.size() <= ITEMS.CAPACITY, "Negative bones or inventory overflow", {"state": state}):
		return false
	for item in state.items:
		if not require(ITEMS.DEFINITIONS.has(item), "Unknown inventory item", {"item": item}):
			return false
	if state.has("squirrels") and not require(state.squirrels >= 0, "Negative squirrel pile"):
		return false
	var seen := {}
	var zones := ["player", "enemy", "reserve", "hand"]
	if state.has("deck"):
		zones.append("deck")
	for zone in zones:
		for token in state[zone]:
			if token == "" and zone not in ["hand", "deck"]:
				continue
			if not require(token != "" and state.cards.has(token) and not seen.has(token), "Missing or duplicated live card", {"token": token, "zone": zone, "state": state}):
				return false
			seen[token] = true
			var card: Dictionary = state.cards[token]
			if not require(card.health > 0 and card.health <= card.max_health and card.attack >= 0, "Invalid live stats", {"token": token, "card": card}):
				return false
			if not require(card.owner == ("enemy" if zone in ["enemy", "reserve"] else "player"), "Ownership disagrees with zone", {"token": token, "zone": zone}):
				return false
	return true
func action(state: Dictionary, command: Dictionary) -> Dictionary:
	match command.kind:
		"play": return RULES.resolve_play(state, command.actor, command.slot, command.offerings)
		"attack": return RULES.resolve_attack(state, command.actor, command.lane, command.enemy)
		"item": return RULES.resolve_item(state, command.index, command.get("target", -1), command.get("slot", -1))
		"cleanup": return RULES.resolve_round_cleanup(state)
		"starve": return RULES.resolve_starvation(state)
	return {"state": state, "events": [], "error": "Unknown test command"}
func verify(before: Dictionary, command: Dictionary, result: Dictionary, encoded_before: String, replay := true) -> bool:
	if not require(encode(before) == encoded_before, "Resolver mutated its input", {"command": command}):
		return false
	if replay and not require(encode(result) == encode(action(before, command)), "Action replay is nondeterministic", {"command": command}):
		return false
	if not result.error.is_empty():
		return require(result.events.is_empty() and encode(result.state) == encoded_before, "Rejected action changed state or emitted events", {"command": command, "result": result})
	if replay:
		# Detect future shallow-copy regressions, not only mutation during resolution.
		result.state.items.append("probe")
		var isolated: bool = encode(before) == encoded_before
		result.state.items.pop_back()
		if not require(isolated, "Successful result shares its inventory array with input"):
			return false
		if not result.state.cards.is_empty():
			var token: String = result.state.cards.keys()[0]
			var attack: int = result.state.cards[token].attack
			result.state.cards[token].attack = attack + 1
			isolated = encode(before) == encoded_before
			result.state.cards[token].attack = attack
			if not require(isolated, "Successful result shares nested card data with input"):
				return false
	if not state_valid(result.state):
		return false
	var bone_delta := 0
	var deaths := {}
	for event in result.events:
		for key in ["actor", "target"]:
			if event.has(key) and not require(result.state.cards.has(event[key]), "Event references unknown card", {"event": event}):
				return false
		if event.type == "payment" and event.cost_type == "bones":
			bone_delta -= event.amount
		if event.type == "death":
			if not require(not deaths.has(event.actor), "Duplicate death event", {"event": event}):
				return false
			deaths[event.actor] = true
			var card: Dictionary = before.cards[event.actor]
			var award := (4 if card.sigils.has("bone_king") else 1) if card.owner == "player" else 0
			bone_delta += award
			var gains: Array = result.events.filter(func(e): return e.type == "bones_gained" and e.actor == event.actor)
			if not require((gains.is_empty() if award == 0 else gains.size() == 1 and gains[0].amount == award), "Death bone award is wrong", {"event": event, "gains": gains}):
				return false
			if not require(not (event.cause == "sacrifice" and card.sigils.has("many_lives")), "Many Lives died to sacrifice"):
				return false
			var returns: Array = result.events.filter(func(e): return e.type == "returned" and e.actor == event.actor)
			var should_return: bool = card.owner == "player" and card.sigils.has("unkillable")
			if not require(returns.size() == (1 if should_return else 0), "Incorrect return-to-hand count", {"event": event}):
				return false
			if should_return and not require(result.state.hand.has(event.actor) and result.state.cards[event.actor].health == card.max_health and result.state.cards[event.actor].attack == card.attack and result.state.cards[event.actor].sigils == card.sigils, "Return lost stats, sigils or max health"):
				return false
	if not require(result.state.bones == before.bones + bone_delta, "Bone total disagrees with payments/deaths", {"command": command, "before": before.bones, "after": result.state.bones}):
		return false
	var expected_items: Array = before.items.duplicate()
	if command.kind == "item":
		expected_items.remove_at(command.index)
	if not require(result.state.items == expected_items, "Item consumption changed another pocket", {"command": command}):
		return false
	var outcomes: Array = result.events.filter(func(e): return e.type == "outcome")
	return require(outcomes.size() <= 1 and (outcomes.is_empty() or result.events.back().type == "outcome"), "Outcome missing final event ordering")
func report(name: String, data: Dictionary) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://reports"))
	var failure_path: String = "res://reports/failures/" + context.get("suite", name) + ".json"
	if FileAccess.file_exists(failure_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(failure_path))
	data.engine_version = Engine.get_version_info().string
	data.contract_checks = checks
	var file := FileAccess.open("res://reports/" + name + ".json", FileAccess.WRITE)
	file.store_string(JSON.stringify(data, "\t", true, true) + "\n")
