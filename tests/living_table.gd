extends SceneTree
func _initialize() -> void:
	call_deferred("checks")
func clear_zone(scene: Node, zone_name: String) -> void:
	var zone: Array = scene.get(zone_name)
	for i in range(zone.size()):
		if is_instance_valid(zone[i]):
			zone[i].queue_free()
		zone[i] = null
func checks() -> void:
	for reduced in [false, true]:
		for id in ["bone_stoat", "grave_raven", "carrion_hound"]:
			for row in [0, 4]:
				var scene = load("res://scenes/attack_preview.tscn").instantiate()
				root.add_child(scene)
				scene.reduced.button_pressed = reduced
				for zone in ["board", "enemies", "reserve"]:
					clear_zone(scene, zone)
				var card = scene._make_card(id)
				scene.board[row] = card
				card.health = 20 # Keep this attack test independent of wipeout difficulty.
				card.position = scene._slot(row)
				var target = scene._make_card("stag")
				target.health = 20
				target.position = scene._slot(0, true)
				scene.enemies[0] = target
				scene.event_log.clear()
				await scene._end_round()
				assert(scene.event_log.any(func(e): return e.type == "attack" and e.actor == str(card.get_instance_id())))
				assert(scene.event_log.any(func(e): return e.type == "damage" and e.actor == str(card.get_instance_id()) and e.amount == card.power))
				if id == "carrion_hound":
					assert(scene.enemies[0] == null) # Death touch kills a 20-health defender.
				else:
					assert(target.health == 20 - card.power - (1 if id == "bone_stoat" else 0))
					assert(scene.round_number == 2 and scene.ambience.round_number == 2)
				assert(card.position.is_equal_approx(scene._slot(row)))
				await process_frame
				assert(card.reduced_motion == reduced)
				var before: float = card.idle_time
				await create_timer(0.04).timeout
				assert(card.idle_time == before if reduced else card.idle_time > before)
				for round_value in [1, 2, 3, 4, 9, 16]:
					scene.ambience.set_round(round_value)
					assert(scene.ambience.tooth_positions().size() == round_value)
					assert(scene.ambience.skull_form == (round_value - 1) % 3)
				scene._reset()
				assert(scene.ambience.round_number == 1 and scene.ambience.tooth_positions().size() == 1)
				scene.queue_free()
				await process_frame
		print("PASS: all undead attack through full round in both rows; card motion, teeth, three hauntings, reset; reduced=", reduced)
	# Explicit regression: low attack is blocked by Stinky, not by bone cost.
	var scene = load("res://scenes/attack_preview.tscn").instantiate()
	root.add_child(scene)
	clear_zone(scene, "enemies")
	var stoat = scene._make_card("bone_stoat")
	scene.board[4] = stoat
	stoat.position = scene._slot(4)
	scene.enemies[0] = scene._make_card("fox")
	await scene._strike(stoat, 4)
	assert(scene.event_log.any(func(e): return e.type == "attack_blocked" and e.actor == str(stoat.get_instance_id())))
	assert(scene.enemies[0].health == 3 and scene.status.text.contains("Stinky"))
	print("PASS: Bone Stoat versus Stinky explicitly displays its zero-attack block")
	scene.queue_free()
	await process_frame
	quit()
