extends Resource
class_name CreatureDefinition
## Editor-facing base definition. Runtime cards never modify this Resource.
@export var id: String = ""
@export var display_name: String = ""
@export var attack: int = 0
@export var health: int = 1
@export var cost: int = 0
@export_enum("blood", "bones") var cost_type: String = "blood"
@export_enum("none", "canine", "avian", "hooved", "insect", "reptile") var tribe: String = "none"
@export var sacrificable: bool = true
@export var sigils: PackedStringArray = []
@export var artwork: Texture2D
@export_multiline var role: String = ""
