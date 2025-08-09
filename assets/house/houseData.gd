extends Resource
class_name HouseData

# House skin configuration data
@export var skin_name: String = ""
@export var scale_multiplier: float = 1.0
@export var width_preference: float = 1.0  # How much to prioritize width vs height
@export var height_preference: float = 1.0
@export var offset_x: float = 0.0  # Fine-tune positioning
@export var offset_y: float = 0.0
@export var rotation_offset: float = 0.0  # Additional rotation if needed

# Optional custom available space for this skin
@export var custom_available_width: float = 0.0  # 0 means use default
@export var custom_available_height: float = 0.0  # 0 means use default
