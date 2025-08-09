extends Resource
class_name HouseDataCollection

# Collection of house data for all 20 skins (indexed 0-19)
@export var house_data_list: Array[Resource] = []

func _init():
	"""Initialize with default data for all 20 skins"""
	if house_data_list.is_empty():
		_initialize_default_data()

func _initialize_default_data():
	"""Create default data for all 20 house skins"""
	house_data_list.clear()
	
	# Create data for all 20 skins with reasonable defaults
	for i in range(20):
		var house_data = load("res://assets/house/defaultHouseData.tres").duplicate(true)
		house_data.scale_multiplier = 1.0  # Start with base scale
		house_data_list.append(house_data)

func get_house_data(skin_index: int) -> Resource:
	"""Get house data for a specific skin index (0-19)"""
	if skin_index >= 0 and skin_index < house_data_list.size():
		return house_data_list[skin_index]
	
	# Return default if index is out of range
	return load("res://assets/house/defaultHouseData.tres")

func set_house_data(skin_index: int, data: Resource):
	"""Set house data for a specific skin"""
	if skin_index >= 0 and skin_index < 20:
		# Ensure we have enough slots
		while house_data_list.size() <= skin_index:
			var default_data = load("res://assets/house/defaultHouseData.tres").duplicate(true)
			house_data_list.append(default_data)
		
		house_data_list[skin_index] = data
