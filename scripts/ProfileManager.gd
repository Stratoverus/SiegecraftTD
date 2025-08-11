extends Node

# Singleton for managing player profiles
# Available as ProfileManager autoload

signal profile_created(profile_name: String)
signal profile_loaded(profile_name: String)

# Current profile data
var current_profile: Dictionary = {}
var profile_name: String = ""

# Save file paths
const PROFILES_DIR = "user://profiles/"
const CURRENT_PROFILE_FILE = "user://current_profile.save"

# Profile data structure
var default_profile_data: Dictionary = {
	"name": "",
	"created_date": "",
	"last_played": "",
	"total_play_time": 0.0,
	"achievements": {},
	"unlocked_skins": [1],  # skin1 always unlocked
	"selected_skin_id": 1,
	"stats": {
		"games_played": 0,
		"total_waves_survived": 0,
		"total_enemies_defeated": 0,
		"total_towers_built": 0,
		"highest_wave_reached": 0,
		"total_gold_earned": 0,
		"times_lost": 0,
		"times_won": 0
	}
}

func _ready():
	# Ensure profiles directory exists
	if not DirAccess.dir_exists_absolute(PROFILES_DIR):
		DirAccess.open("user://").make_dir_recursive("profiles")
	
	# Load current profile if it exists
	load_current_profile()

func has_profile() -> bool:
	"""Check if a profile exists"""
	return profile_name != "" and current_profile.has("name")

func is_first_time_user() -> bool:
	"""Check if this is the first time the user is running the game"""
	# Check if there are any profiles at all
	var all_profiles = get_all_profiles()
	return all_profiles.size() == 0

func create_profile(profile_name_input: String) -> bool:
	"""Create a new profile with the given name"""
	if profile_name_input.strip_edges() == "":
		return false
	
	# Clean the name for file system compatibility
	var clean_name = clean_profile_name(profile_name_input)
	if clean_name == "":
		return false
	
	# Create profile data
	current_profile = default_profile_data.duplicate(true)
	current_profile["name"] = profile_name_input
	current_profile["created_date"] = Time.get_datetime_string_from_system()
	current_profile["last_played"] = Time.get_datetime_string_from_system()
	
	profile_name = profile_name_input
	
	# Save the profile
	save_profile()
	save_current_profile_reference()
	
	# Initialize subsystems with new profile
	initialize_subsystems()
	
	profile_created.emit(profile_name_input)
	return true

func save_profile() -> bool:
	"""Save the current profile to disk"""
	if profile_name == "":
		return false
	
	var clean_name = clean_profile_name(profile_name)
	var file_path = PROFILES_DIR + clean_name + ".profile"
	
	# Update last played time
	current_profile["last_played"] = Time.get_datetime_string_from_system()
	
	var file = FileAccess.open(file_path, FileAccess.WRITE)
	if not file:
		print("Failed to save profile: ", profile_name)
		return false
	
	file.store_string(JSON.stringify(current_profile))
	file.close()
	
	print("Profile saved: ", profile_name)
	return true

func load_profile(profile_name_input: String) -> bool:
	"""Load a profile by name"""
	var clean_name = clean_profile_name(profile_name_input)
	var file_path = PROFILES_DIR + clean_name + ".profile"
	
	if not FileAccess.file_exists(file_path):
		return false
	
	var file = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		return false
	
	var json_string = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var parse_result = json.parse(json_string)
	
	if parse_result != OK:
		return false
	
	current_profile = json.data
	profile_name = current_profile.get("name", profile_name_input)
	
	# Save as current profile
	save_current_profile_reference()
	
	# Initialize subsystems with loaded profile
	initialize_subsystems()
	
	profile_loaded.emit(profile_name)
	return true

func save_current_profile_reference():
	"""Save reference to the current profile"""
	var file = FileAccess.open(CURRENT_PROFILE_FILE, FileAccess.WRITE)
	if file:
		var data = {"current_profile": profile_name}
		file.store_string(JSON.stringify(data))
		file.close()

func load_current_profile():
	"""Load the current profile reference and profile data"""
	if not FileAccess.file_exists(CURRENT_PROFILE_FILE):
		return
	
	var file = FileAccess.open(CURRENT_PROFILE_FILE, FileAccess.READ)
	if not file:
		return
	
	var json_string = file.get_as_text()
	file.close()
	
	var json = JSON.new()
	var parse_result = json.parse(json_string)
	
	if parse_result != OK:
		return
	
	var data = json.data
	var last_profile = data.get("current_profile", "")
	
	if last_profile != "":
		load_profile(last_profile)

func change_profile_name(new_name: String) -> bool:
	"""Change current profile name and create a new separate profile"""
	if new_name.strip_edges() == "" or profile_name == "":
		return false
	
	var clean_new_name = clean_profile_name(new_name)
	if clean_new_name == "":
		return false
	
	# Check if new name already exists
	if profile_exists(new_name):
		print("Profile name already exists: ", new_name)
		return false
	
	# Create a completely new profile with the new name
	create_profile(new_name)
	return true

func clean_profile_name(input_name: String) -> String:
	"""Clean profile name for file system compatibility"""
	var clean = input_name.strip_edges()
	# Remove invalid characters for file names
	var invalid_chars = ["<", ">", ":", "\"", "/", "\\", "|", "?", "*"]
	for character in invalid_chars:
		clean = clean.replace(character, "_")
	
	# Limit length
	if clean.length() > 50:
		clean = clean.substr(0, 50)
	
	return clean

func update_stat(stat_name: String, value: int):
	"""Update a profile statistic"""
	if not current_profile.has("stats"):
		current_profile["stats"] = default_profile_data["stats"].duplicate()
	
	if current_profile["stats"].has(stat_name):
		current_profile["stats"][stat_name] += value
		save_profile()

func set_stat(stat_name: String, value: int):
	"""Set a profile statistic to a specific value"""
	if not current_profile.has("stats"):
		current_profile["stats"] = default_profile_data["stats"].duplicate()
	
	current_profile["stats"][stat_name] = value
	save_profile()

func get_stat(stat_name: String) -> int:
	"""Get a profile statistic"""
	if not current_profile.has("stats"):
		return 0
	
	return current_profile["stats"].get(stat_name, 0)

func get_profile_data() -> Dictionary:
	"""Get the current profile data"""
	return current_profile

func initialize_subsystems():
	"""Initialize other game systems with profile data"""
	# Initialize achievement manager with profile achievements
	var achievement_manager = get_node("/root/AchievementManager")
	if achievement_manager:
		var achievements = current_profile.get("achievements", {})
		var unlocked_skins = current_profile.get("unlocked_skins", [1])
		achievement_manager.load_from_profile(achievements, unlocked_skins)
	
	# Initialize house skin manager with profile skin selection
	var house_skin_manager = get_node("/root/HouseSkinManager")
	if house_skin_manager:
		var selected_skin = current_profile.get("selected_skin_id", 1)
		house_skin_manager.load_from_profile(selected_skin)

func sync_from_subsystems():
	"""Sync profile data from other game systems"""
	# Sync achievements
	var achievement_manager = get_node("/root/AchievementManager")
	if achievement_manager:
		current_profile["achievements"] = achievement_manager.achievements
		current_profile["unlocked_skins"] = achievement_manager.unlocked_skins
	
	# Sync house skin selection
	var house_skin_manager = get_node("/root/HouseSkinManager")
	if house_skin_manager:
		current_profile["selected_skin_id"] = house_skin_manager.selected_skin_id
	
	save_profile()

func get_formatted_play_time() -> String:
	"""Get formatted total play time"""
	var total_time = current_profile.get("total_play_time", 0.0)
	var hours = int(total_time / 3600)
	var minutes = int((int(total_time) % 3600) / 60.0)
	
	if hours > 0:
		return "%d hours, %d minutes" % [hours, minutes]
	else:
		return "%d minutes" % minutes

func add_play_time(seconds: float):
	"""Add to the total play time (event-based saving only)"""
	current_profile["total_play_time"] = current_profile.get("total_play_time", 0.0) + seconds
	# Note: Only saves when explicitly called via save_profile()

# Multi-profile management functions
func get_all_profiles() -> Array[String]:
	"""Get list of all available profile names"""
	var profiles: Array[String] = []
	var dir = DirAccess.open(PROFILES_DIR)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if file_name.ends_with(".profile"):
				var profile_name_clean = file_name.replace(".profile", "")
				var actual_name = unclean_profile_name(profile_name_clean)
				profiles.append(actual_name)
			file_name = dir.get_next()
		dir.list_dir_end()
	return profiles

func switch_profile(new_profile_name: String) -> bool:
	"""Switch to a different existing profile"""
	var clean_name = clean_profile_name(new_profile_name)
	var file_path = PROFILES_DIR + clean_name + ".profile"
	
	if not FileAccess.file_exists(file_path):
		print("Profile not found: ", new_profile_name)
		return false
	
	# Save current profile before switching
	if has_profile():
		save_profile()
	
	# Load the new profile
	return load_profile(new_profile_name)

func delete_profile(profile_to_delete: String) -> bool:
	"""Delete a profile (cannot delete if it's the only one or currently active)"""
	var all_profiles = get_all_profiles()
	
	# Cannot delete if it's the only profile
	if all_profiles.size() <= 1:
		print("Cannot delete the only profile")
		return false
	
	# Cannot delete currently active profile
	if profile_to_delete == profile_name:
		print("Cannot delete currently active profile")
		return false
	
	var clean_name = clean_profile_name(profile_to_delete)
	var file_path = PROFILES_DIR + clean_name + ".profile"
	
	if FileAccess.file_exists(file_path):
		DirAccess.remove_absolute(file_path)
		print("Deleted profile: ", profile_to_delete)
		return true
	else:
		print("Profile file not found: ", profile_to_delete)
		return false

func profile_exists(check_name: String) -> bool:
	"""Check if a profile with the given name exists"""
	var clean_name = clean_profile_name(check_name)
	var file_path = PROFILES_DIR + clean_name + ".profile"
	return FileAccess.file_exists(file_path)

func unclean_profile_name(clean_name: String) -> String:
	"""Convert a clean file name back to display name"""
	# This is a simple reverse of clean_profile_name
	# For now, just replace underscores with spaces
	return clean_name.replace("_", " ")
