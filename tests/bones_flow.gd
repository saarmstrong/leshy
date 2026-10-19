extends SceneTree
func _initialize() -> void:
	call_deferred("checks")
func idle(scene: Node) -> void:
	var deadline := Time.get_ticks_msec() + 15000
	while scene.busy and Time.get_ticks_msec() < deadline:
		await process_frame
	assert(not scene.busy)
func give(scene: Node, id: String) -> void:
	scene.hand.append(scene._make_card(id))
	scene._select_card(scene.hand.size() - 1)
func checks() -> void:
	for reduced in [false, true]:
		var scene = load("res://scenes/attack_preview.tscn").instantiate()
		root.add_child(scene)
		scene.reduced.button_pressed = reduced
		assert(scene.bones == 0)
		give(scene, "bone_stoat")
		scene._choose_lane(7)
		assert(not scene.busy and scene.board[7] == null and scene.bones == 0)
		# Place two squirrels across both rows without granting bones.
		for slot in [0, 4]:
			give(scene, "squirrel")
			scene._choose_lane(slot)
			await idle(scene)
		assert(scene.bones == 0)
		give(scene, "wolf")
		scene._toggle_offering(0, true)
		scene._choose_lane(1)
		assert(not scene.busy and scene.board[0] != null and scene.bones == 0)
		scene._toggle_offering(4, true)
		assert(scene.offerings.size() == 2 and scene.board[0].marked and scene.board[4].marked)
		assert(scene.bones == 0) # Marking is not death.
		scene._choose_lane(1)
		await idle(scene)
		assert(scene.board[1].animal == "WOLF" and scene.board[0] == null and scene.board[4] == null)
		assert(scene.bones == 2 and scene.discard.count("squirrel") == 2)
		# Bone payment consumes the bank, not more creatures.
		give(scene, "bone_stoat")
		scene._toggle_offering(1, true)
		assert(scene.offerings.is_empty())
		scene._choose_lane(7)
		await idle(scene)
		assert(scene.bones == 0 and scene.board[7].cost_type == "bones")
		assert(scene.board[1].animal == "WOLF")
		# Enemy deaths award no bones.
		scene.enemies[1].health = 1
		await scene._strike(scene.board[1], 1)
		assert(scene.enemies[1] == null and scene.bones == 0)
		# Player death in the back row awards one bone.
		var foe = scene._make_card("wolf")
		scene.enemies[3] = foe
		foe.position = scene._slot(3, true)
		await scene._strike(foe, 3, true)
		assert(scene.board[7] == null and scene.bones == 1)
		give(scene, "grave_raven")
		scene._choose_lane(6)
		assert(scene.board[6] == null and scene.bones == 1)
		scene.bones = 6
		give(scene, "carrion_hound")
		scene._choose_lane(1) # Occupied destinations cannot spend bones.
		assert(scene.bones == 6)
		scene._choose_lane(6)
		await idle(scene)
		assert(scene.bones == 0 and scene.board[6].animal == "CARRION HOUND")
		# Undead creatures can themselves be offered for blood.
		give(scene, "fox")
		scene._toggle_offering(6, true)
		scene._choose_lane(4)
		await idle(scene)
		assert(scene.bones == 1 and scene.board[6] == null and scene.board[4].animal == "FOX")
		scene._reset()
		assert(scene.bones == 0)
		scene.queue_free()
		await process_frame
		print("PASS: stacked squirrels, blood commit, bone award/payment/reset, undead sacrifice; reduced = ", reduced)
	quit()
