class_name EnemyGroup
extends Resource

# Use enemy type names instead of full paths for simplicity
@export_enum("firebug", "fireWasp", "flyingLocust", "clampBeetle", "leafbug", "voidButterfly", "scorpion", "magmaCrab") var enemy_type: String = "firebug"
@export var count: int = 1
@export var spawn_delay: float = 0.0  # Additional delay before spawning this group

# Convert enemy type to resource path
func get_enemy_path() -> String:
	match enemy_type:
		"firebug":
			return "res://assets/Enemies/firebug/firebug.tres"
		"fireWasp":
			return "res://assets/Enemies/fireWasp/fireWasp.tres"
		"flyingLocust":
			return "res://assets/Enemies/flyingLocust/flyingLocust.tres"
		"clampBeetle":
			return "res://assets/Enemies/clampBeetle/clampBeetle.tres"
		"leafbug":
			return "res://assets/Enemies/leafbug/leafbug.tres"
		"voidButterfly":
			return "res://assets/Enemies/voidButterfly/voidButterfly.tres"
		"scorpion":
			return "res://assets/Enemies/scorpion/scorpion.tres"
		"magmaCrab":
			return "res://assets/Enemies/magmaCrab/magmaCrab.tres"
		_:
			return "res://assets/Enemies/firebug/firebug.tres"  # Fallback
