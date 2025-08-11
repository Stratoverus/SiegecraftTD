extends Node

# Singleton for managing house skin selection
# Available as HouseSkinManager autoload

signal skin_changed(new_skin_id: int)

# Currently selected skin (default is skin1)
var selected_skin_id: int = 1

# Save file path
const SAVE_FILE_PATH = "user://house_skin.save"

# Skin names and descriptions
var skin_data: Dictionary = {
	1: {"name": "Classic Cottage", "description": "The traditional starting home"},
	2: {"name": "Victory Manor", "description": "Unlocked by completing your first level"},
	3: {"name": "Wave Rider House", "description": "Unlocked by surviving 50 waves"},
	4: {"name": "Tower Builder's Den", "description": "Unlocked by building 100 towers"},
	5: {"name": "Slayer's Sanctuary", "description": "Unlocked by defeating 1000 enemies"},
	6: {"name": "Perfect Palace", "description": "Unlocked by completing a level without damage"},
	7: {"name": "Economist's Estate", "description": "Unlocked by saving 5000 gold"},
	8: {"name": "Speed Runner's Shack", "description": "Unlocked by speed running normal mode"},
	9: {"name": "Survivalist Stronghold", "description": "Unlocked by surviving 100 waves"},
	10: {"name": "Master's Mansion", "description": "Unlocked by fully upgrading 10 towers"},
	11: {"name": "Golden Villa", "description": "Unlocked by accumulating 10000 gold"},
	12: {"name": "Wave Crusher Castle", "description": "Unlocked by surviving 200 waves"},
	13: {"name": "Genius Headquarters", "description": "Unlocked by completing extra hard mode"},
	14: {"name": "Destroyer's Domain", "description": "Unlocked by defeating 5000 enemies"},
	15: {"name": "Treasure Hunter's Hall", "description": "Unlocked by earning 50000 gold total"},
	16: {"name": "Champion's Citadel", "description": "Unlocked by surviving 500 waves"},
	17: {"name": "Tycoon's Tower", "description": "Unlocked by building 500 towers total"},
	18: {"name": "Ultimate Fortress", "description": "Unlocked by perfect runs on all modes"},
	19: {"name": "Apocalypse Bunker", "description": "Unlocked by surviving 1000 waves"},
	20: {"name": "Legendary Landmark", "description": "Unlocked by defeating 10000 enemies"}
}

func _ready():
	load_selected_skin()

func set_selected_skin(skin_id: int):
	"""Set the selected house skin"""
	var achievement_manager = get_node("/root/AchievementManager")
	if achievement_manager and achievement_manager.is_skin_unlocked(skin_id):
		selected_skin_id = skin_id
		skin_changed.emit(skin_id)
		save_selected_skin()
		sync_to_profile()  # Sync to profile
		print("House skin changed to: " + get_skin_name(skin_id))
	else:
		print("Skin " + str(skin_id) + " is not unlocked!")

func get_selected_skin() -> int:
	"""Get the currently selected skin ID"""
	return selected_skin_id

func get_skin_name(skin_id: int) -> String:
	"""Get the display name for a skin"""
	return skin_data.get(skin_id, {}).get("name", "Unknown Skin")

func get_skin_description(skin_id: int) -> String:
	"""Get the description for a skin"""
	return skin_data.get(skin_id, {}).get("description", "No description available")

func get_skin_animation_name(skin_id: int) -> String:
	"""Get the animation name for a skin (for use with AnimatedSprite2D)"""
	return "skin" + str(skin_id)

func get_available_skins() -> Array[int]:
	"""Get all available (unlocked) skins"""
	var available_skins: Array[int] = []
	var achievement_manager = get_node("/root/AchievementManager")
	for skin_id in range(1, 21):
		if achievement_manager and achievement_manager.is_skin_unlocked(skin_id):
			available_skins.append(skin_id)
	return available_skins

func get_all_skins() -> Array[int]:
	"""Get all skins (including locked ones)"""
	var all_skins: Array[int] = []
	for skin_id in range(1, 21):
		all_skins.append(skin_id)
	return all_skins

func save_selected_skin():
	"""Save the selected skin to file"""
	var save_data = {
		"selected_skin_id": selected_skin_id
	}
	
	var file = FileAccess.open(SAVE_FILE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(save_data))
		file.close()

func load_selected_skin():
	"""Load the selected skin from file"""
	if FileAccess.file_exists(SAVE_FILE_PATH):
		var file = FileAccess.open(SAVE_FILE_PATH, FileAccess.READ)
		if file:
			var json_string = file.get_as_text()
			file.close()
			
			var json = JSON.new()
			var parse_result = json.parse(json_string)
			
			if parse_result == OK:
				var save_data = json.data
				var loaded_skin = save_data.get("selected_skin_id", 1)
				
				# Verify the skin is still unlocked (in case save data is corrupted)
				var achievement_manager = get_node("/root/AchievementManager")
				if achievement_manager and achievement_manager.is_skin_unlocked(loaded_skin):
					selected_skin_id = loaded_skin
				else:
					selected_skin_id = 1  # Fallback to default
			else:
				print("Error parsing house skin save file")
				selected_skin_id = 1
	else:
		selected_skin_id = 1  # Default skin

# Profile system integration methods
func load_from_profile(profile_selected_skin: int):
	"""Load skin selection from a profile"""
	# Verify the skin is still unlocked
	var achievement_manager = get_node("/root/AchievementManager")
	if achievement_manager and achievement_manager.is_skin_unlocked(profile_selected_skin):
		selected_skin_id = profile_selected_skin
	else:
		selected_skin_id = 1  # Fallback to default
	
	# Emit signal to update UI
	skin_changed.emit(selected_skin_id)

func sync_to_profile():
	"""Sync current skin selection to profile"""
	var profile_manager = get_node("/root/ProfileManager")
	if profile_manager:
		profile_manager.sync_from_subsystems()
