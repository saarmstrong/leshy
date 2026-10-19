extends RefCounted
const DEFINITIONS = {
	"worthy_sacrifice": {"name": "Worthy Sacrifice", "description": "Provides 3 blood when offered. Excess blood is lost."},
	"many_lives": {"name": "Many Lives", "description": "Survives being offered, granting blood but no death bones. Its occupied slot stays occupied."},
	"unkillable": {"name": "Unkillable", "description": "Returns to your hand at full health after dying, keeping its upgrades. A combat wipeout still ends the battle."},
	"bone_king": {"name": "Bone King", "description": "Your creature grants 4 bones instead of 1 when it dies or is sacrificed."},
	"airborne": {"name": "Airborne", "description": "Flies over blockers unless they have Mighty Leap."},
	"mighty_leap": {"name": "Mighty Leap", "description": "Blocks Airborne attackers."},
	"waterborne": {"name": "Waterborne", "description": "Submerges during enemy attacks; those attacks hit the balance instead."},
	"stinky": {"name": "Stinky", "description": "Reduces an opposing attack in this lane by 1, to a minimum of zero."},
	"sharp_quills": {"name": "Sharp Quills", "description": "Retaliates for 1 damage when struck, even by a lethal hit."},
	"touch_of_death": {"name": "Touch of Death", "description": "Any positive damage this creature deals to a creature is lethal."},
}
static func describe(sigils: PackedStringArray) -> String:
	var lines := PackedStringArray()
	for id in sigils:
		if DEFINITIONS.has(id):
			lines.append(DEFINITIONS[id].name + ": " + DEFINITIONS[id].description)
	return "\n".join(lines)
static func names(sigils: PackedStringArray) -> String:
	var result := PackedStringArray()
	for id in sigils:
		if DEFINITIONS.has(id):
			result.append(DEFINITIONS[id].name)
	return " · ".join(result)
