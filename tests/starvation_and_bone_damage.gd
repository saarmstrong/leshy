extends SceneTree
const RULES = preload("res://scripts/battle_rules.gd")
const SETUP = preload("res://scripts/battle_setup.gd")
func _initialize() -> void:
	call_deferred("checks")
func checks() -> void:
	for reduced in [false, true]:
		var scene = load("res://scenes/attack_preview.tscn").instantiate()
		root.add_child(scene)
		scene.reduced.button_pressed = reduced
		for id in ["bone_stoat", "grave_raven", "carrion_hound"]:
			for row in [0, 4]:
				for foe in scene.enemies:
					if is_instance_valid(foe):
						foe.queue_free()
				scene.enemies = [null, null, null, null]
				var card = scene._make_card(id)
				scene.board[row] = card
				card.position = scene._slot(row)
				scene.balance = 0
				scene.bones = 7
				await scene._strike(card, row)
				assert(scene.balance == card.power and scene.bones == 7)
				assert(card.position.is_equal_approx(scene._slot(row)))
				scene.board[row] = null
				card.queue_free()
		# No draw cards left: pressure grows and a neutral scale must resolve.
		scene.deck.clear()
		scene.squirrels = 0
		scene.balance = 0
		for amount in [1, 2, 3]:
			var original: Dictionary = scene._snapshot()
			var encoded := JSON.stringify(original)
			var result: Dictionary = RULES.resolve_starvation(original)
			assert(JSON.stringify(original) == encoded)
			assert(result.events[0].amount == amount)
			await scene._starve()
			assert(scene.starvation == amount)
		assert(scene.balance == -6 and scene.finished and not scene.battle_won)
		scene._reset()
		assert(scene.starvation == 0 and not scene.finished)
		scene.queue_free()
		await process_frame
		print("PASS: all bone creatures deal face damage in both rows; exhaustion resolves/reset; reduced=", reduced)
	# Scene encounter state must agree with the data used by the balance probe.
	for level in range(3):
		var scene = load("res://scenes/attack_preview.tscn").instantiate()
		var entries: Array = []
		for i in range(SETUP.STARTER.size()):
			entries.append({"id": SETUP.STARTER[i], "uid": i})
		scene.configure_run(entries, level)
		root.add_child(scene)
		var config: Dictionary = SETUP.encounter(level)
		assert(scene.reinforcements_left == config.reinforcements and scene.reserve_index == config.sequence_index)
		assert(scene.enemies.count(null) == 4 - config.active.size())
		assert(scene.reserve.count(null) == 4 - config.reserve.size() - config.extra.size())
		for entry in config.reserve + config.extra:
			assert(scene.reserve[entry.lane].definition.id == entry.id)
		scene.queue_free()
		await process_frame
	print("PASS: live encounters match the shared simulation schedule at all three levels")
	quit()
