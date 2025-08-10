class_name GameModeData
extends Resource

@export var mode_name: String = ""
@export var mode_type: String = "" # "endless", "normal", or "extra_hard"

# Scaling settings for all modes
@export var health_multiplier: float = 1.0
@export var damage_multiplier: float = 1.0
@export var gold_multiplier: float = 1.0

# Endless mode specific settings
@export var endless_scaling_factor: float = 1.1  # How much harder each wave gets
@export var endless_wave_interval: float = 30.0  # Seconds between waves

# Normal/Extra Hard mode settings - simplified wave definitions
@export var wave_definitions: Array[WaveDefinition] = []
@export var break_between_waves: float = 10.0  # Seconds between waves

# Function to get scaled enemy health
func get_scaled_health(base_health: int, wave_number: int = 1) -> int:
	var scaled_health = base_health * health_multiplier
	
	if mode_type == "endless":
		# Apply exponential scaling for endless mode
		scaled_health *= pow(endless_scaling_factor, wave_number - 1)
	
	return int(scaled_health)

# Function to get scaled damage to house
func get_scaled_damage(base_damage: int) -> int:
	return int(base_damage * damage_multiplier)

# Function to get scaled gold reward
func get_scaled_gold(base_gold: int) -> int:
	return int(base_gold * gold_multiplier)
