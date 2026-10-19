extends SceneTree
func _initialize() -> void:
	call_deferred("checks")
func clear_zone(scene: Node, name: String) -> void:
	var zone: Array = scene.get(name)
	for i in range(zone.size()):
		if zone[i] != null:
			zone[i].queue_free()
		zone[i] = null
func checks() -> void:
	for low_motion in [false, true]:
		var scene = load("res://scenes/attack_preview.tscn").instantiate()
		root.add_child(scene)
		scene.reduced.button_pressed = low_motion
		clear_zone(scene, "enemies")
		scene.board[0] = scene._make_card("raven")
		scene.board[0].position = scene._slot(0)
		scene.enemies[0] = scene._make_card("wolf")
		scene.enemies[0].position = scene._slot(0, true)
		await scene._strike(scene.board[0], 0)
		assert(scene.balance == 1 and scene.enemies[0].health == 4)
		assert(scene.event_log.any(func(event): return event.type == "sigil" and event.sigil == "airborne"))
		scene.enemies[0].queue_free()
		scene.enemies[0] = scene._make_card("stag")
		scene.enemies[0].position = scene._slot(0, true)
		await scene._strike(scene.board[0], 0)
		assert(scene.balance == 1 and scene.enemies[0].health == 3)
		assert(scene.enemies[0].display_health == 3)
		assert(scene.board[0].position.is_equal_approx(scene._slot(0)))
		clear_zone(scene, "board")
		scene.enemies[0].queue_free()
		scene.board[0] = scene._make_card("carrion_hound")
		scene.board[0].position = scene._slot(0)
		scene.enemies[0] = scene._make_card("bone_stoat")
		scene.enemies[0].position = scene._slot(0, true)
		await scene._strike(scene.board[0], 0)
		assert(scene.enemies[0] == null and scene.board[0].health == 2)
		assert(scene.bones == 0 and not scene.finished) # Enemy death does not grant bones; reserve survives.
		var previous := 0
		for event in scene.event_log:
			assert(event.sequence > previous)
			previous = event.sequence
		assert(scene.ambience.reduced == low_motion)
		scene.queue_free()
		await process_frame
		print("PASS: airborne/reach, sigil playback, retaliation, display health, event journal, reduced motion = ", low_motion)
	quit()
