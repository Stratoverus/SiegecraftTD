# House Scaling Configuration
# Edit these values to adjust the scale for each house skin
# 
# Available space: 160x110 pixels
# Base sprite size: 150x151 pixels
# Default scale calculation: min(160/150, 110/151) ≈ 0.73
# 
# Scale multiplier values:
# - 1.0 = default calculated scale
# - 1.5 = 50% larger 
# - 2.0 = 200% (double size)
# - 0.8 = 80% (smaller)

extends Resource
class_name HouseScaleConfig

# Scale multipliers for each skin (skin1 through skin20)
# Adjust these values to make individual houses fit better
@export var skin_scales: Dictionary = {
	"skin1": 1.0,
	"skin2": 1.0,
	"skin3": 1.0,
	"skin4": 1.0,
	"skin5": 1.0,
	"skin6": 1.0,
	"skin7": 1.0,
	"skin8": 1.0,
	"skin9": 1.0,
	"skin10": 1.0,
	"skin11": 1.0,
	"skin12": 1.0,
	"skin13": 1.0,
	"skin14": 1.0,
	"skin15": 1.0,
	"skin16": 1.0,
	"skin17": 1.0,
	"skin18": 1.0,
	"skin19": 1.0,
	"skin20": 1.0
}

func get_scale_for_skin(skin_name: String) -> float:
	"""Get the scale multiplier for a specific skin"""
	if skin_scales.has(skin_name):
		return skin_scales[skin_name]
	return 1.0  # Default scale

func set_scale_for_skin(skin_name: String, scale: float):
	"""Set the scale multiplier for a specific skin"""
	skin_scales[skin_name] = scale
