extends RefCounted
## Shared immutable card definitions. Copy values into individual battle cards.
const DEFINITIONS = {
	"ashen_stag": preload("res://resources/cards/ashen_stag.tres"),
	"ember_fox": preload("res://resources/cards/ember_fox.tres"),
	"revenant_raven": preload("res://resources/cards/revenant_raven.tres"),
	"ossuary_hound": preload("res://resources/cards/ossuary_hound.tres"),

	"squirrel": preload("res://resources/cards/squirrel.tres"),
	"hare": preload("res://resources/cards/hare.tres"),
	"fox": preload("res://resources/cards/fox.tres"),
	"raven": preload("res://resources/cards/raven.tres"),
	"stag": preload("res://resources/cards/stag.tres"),
	"wolf": preload("res://resources/cards/wolf.tres"),
	"bone_stoat": preload("res://resources/cards/bone_stoat.tres"),
	"grave_raven": preload("res://resources/cards/grave_raven.tres"),
	"carrion_hound": preload("res://resources/cards/carrion_hound.tres")
}

static func find(id: String) -> Resource:
	assert(DEFINITIONS.has(id), "Unknown card ID: " + id)
	return DEFINITIONS[id]

static func ids() -> Array:
	return DEFINITIONS.keys()

static func contains(id: String) -> bool:
	return DEFINITIONS.has(id)

static func validation_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	for id in DEFINITIONS:
		var definition: Resource = DEFINITIONS[id]
		if definition.id != id or definition.display_name.is_empty():
			errors.append("Invalid identity: " + id)
		if definition.attack < 0 or definition.health <= 0 or definition.cost < 0:
			errors.append("Invalid stats: " + id)
		if definition.cost_type not in ["blood", "bones"]:
			errors.append("Invalid cost type: " + id)
		if definition.tribe not in ["none", "canine", "avian", "hooved", "insect", "reptile"]:
			errors.append("Invalid tribe: " + id)
		for sigil in definition.sigils:
			if not preload("res://scripts/sigil_library.gd").DEFINITIONS.has(sigil):
				errors.append("Unknown sigil: " + id + ":" + sigil)
		if definition.artwork == null:
			errors.append("Missing art: " + id)
	return errors
