extends SceneTree
const CATALOG = preload("res://scripts/card_catalog.gd")
const CARD = preload("res://scripts/ritual_card.gd")
func _initialize() -> void:
	call_deferred("checks")
func checks() -> void:
	assert(CATALOG.validation_errors().is_empty())
	assert(CATALOG.ids().size() == 13)
	assert(CATALOG.find("bone_stoat").cost_type == "bones")
	assert(CATALOG.find("wolf").tribe == "canine")
	for id in {"raven": "airborne", "fox": "stinky", "stag": "mighty_leap", "bone_stoat": "sharp_quills", "grave_raven": "waterborne", "carrion_hound": "touch_of_death"}:
		var expected: String = {"raven": "airborne", "fox": "stinky", "stag": "mighty_leap", "bone_stoat": "sharp_quills", "grave_raven": "waterborne", "carrion_hound": "touch_of_death"}[id]
		assert(CATALOG.find(id).sigils.has(expected), "Lost baseline sigil on " + id)
	var base = CATALOG.find("fox")
	var upgraded = CARD.new()
	var ordinary = CARD.new()
	root.add_child(upgraded)
	root.add_child(ordinary)
	var permanent := {"attack_bonus": 1, "health_bonus": 2, "added_sigils": ["test_effect"]}
	upgraded.configure(base, permanent)
	ordinary.configure(base)
	assert(upgraded.power == 3 and upgraded.health == 5 and ordinary.power == 2)
	upgraded.health -= 2
	upgraded.apply_temporary_bonus(2, 1)
	assert(upgraded.power == 5 and upgraded.health == 4 and upgraded.maximum_health() == 6)
	assert(base.attack == 2 and base.health == 3)
	assert(permanent.attack_bonus == 1 and permanent.health_bonus == 2)
	assert(base.sigils == PackedStringArray(["stinky"]) and ordinary.sigils == base.sigils)
	assert(upgraded.sigils == PackedStringArray(["stinky", "test_effect"]))
	upgraded.configure(base, permanent)
	assert(upgraded.power == 3 and upgraded.health == 5 and upgraded.temporary_attack_bonus == 0)
	# Sacrifice eligibility is enforced by actual placement/marking paths.
	var scene = load("res://scenes/attack_preview.tscn").instantiate()
	root.add_child(scene)
	var object_definition = CATALOG.find("squirrel").duplicate(true)
	object_definition.sacrificable = false
	var object = CARD.new()
	object.configure(object_definition)
	object.set_meta("card_id", "squirrel")
	scene.add_child(object)
	scene.board[0] = object
	object.position = scene._slot(0)
	scene.hand.append(scene._make_card("fox"))
	scene._select_card(scene.hand.size() - 1)
	scene._choose_lane(0)
	scene._toggle_offering(0, true)
	assert(scene.offerings.is_empty() and not object.marked)
	assert(CATALOG.find("squirrel").sacrificable)
	# Forged marks also cannot fund a placement.
	scene.offerings.append(object)
	scene._place(1)
	assert(scene.board[1] == null and not scene.busy)
	scene.queue_free()
	upgraded.queue_free()
	ordinary.queue_free()
	await process_frame
	print("PASS: resource validation, shared catalog, permanent/temporary isolation, sigil copying, sacrifice eligibility")
	quit()
