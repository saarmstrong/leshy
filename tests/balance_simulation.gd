extends SceneTree
const SIM = preload("res://scripts/battle_simulation.gd")
func _initialize() -> void:
	var report := {"samples_per_group": 300, "note": "Simple bots; encounter regression probe, not human win rates. Starter deck without map upgrades; no items or bosses yet.", "groups": []}
	for level in range(3):
		for careful in [true, false]:
			var group := {"level": level, "policy": "careful" if careful else "reckless", "wins": 0, "losses": 0, "timeouts": 0, "rounds_total": 0, "early_losses": 0, "bone_attacks": {}, "bone_blocks": {}, "plays": {}, "losing_seeds": [], "timeout_seeds": []}
			for seed_value in range(300):
				var result: Dictionary = SIM.new().run_seed(seed_value, level, careful)
				group["wins" if result.result == "win" else ("losses" if result.result == "loss" else "timeouts")] += 1
				group.rounds_total += result.rounds
				if result.result == "timeout":
					group.timeout_seeds.append(seed_value)
				if result.result == "loss":
					group.losing_seeds.append(seed_value)
					if result.rounds <= 2:
						group.early_losses += 1
				for key in ["bone_attacks", "bone_blocks", "plays"]:
					for id in result[key]:
						group[key][id] = group[key].get(id, 0) + result[key][id]
			group.win_rate = group.wins / 300.0
			group.mean_rounds = group.rounds_total / 300.0
			report.groups.append(group)
			print("BALANCE level=%d policy=%s win=%.1f%% mean_rounds=%.2f early_losses=%d" % [level, group.policy, group.win_rate * 100, group.mean_rounds, group.early_losses])


	# Seed replay is exact; broad guardrail prevents a trivial opening regression.
	assert(SIM.new().run_seed(37, 0) == SIM.new().run_seed(37, 0))

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://reports"))
	var file := FileAccess.open("res://reports/balance-latest.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t") + "\n")
	# Broad alarms for this exact bot, seed corpus and unupgraded starter deck.
	# Review design changes before intentionally changing these bands.
	for group in report.groups:
		assert(group.timeouts == 0, "Stalled policy seed recorded in reports/balance-latest.json")
		assert(group.wins > 0 and group.losses > 0)
	assert(report.groups[0].win_rate >= 0.60 and report.groups[0].win_rate <= 0.99)
	for index in [2, 4]:
		assert(report.groups[index].win_rate >= 0.25 and report.groups[index].win_rate <= 0.90)
		assert(report.groups[index].win_rate >= report.groups[index + 1].win_rate + 0.15)
		assert(report.groups[index].early_losses <= 40)
	assert(report.groups[0].bone_attacks.get("bone_stoat", 0) > 0)
	assert(report.groups[0].bone_attacks.get("grave_raven", 0) > 0)
	print("PASS: 1,200 seeded encounters, deterministic replay, no stalls, difficulty and bone-use guardrails")
	quit()
