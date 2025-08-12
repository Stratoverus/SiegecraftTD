extends Node

# Singleton for managing achievements and unlockable house skins
# Available as AchievementManager autoload

signal achievement_unlocked(achievement_id: String)
signal skin_unlocked(skin_id: int)

# Note: Achievement and skin data is now stored in ProfileManager, not here

# Save/load file path (legacy - achievements now saved with profiles)
const SAVE_FILE_PATH = "user://achievements.save"

# Achievement definitions with their corresponding skin unlocks
var achievement_definitions: Dictionary = {
	"first_victory": {
		"name": "First Victory",
		"description": "Complete your first level",
		"unlocks_skin": 2,
		"unlocked": false
	},
	"wave_master": {
		"name": "Wave Master", 
		"description": "Survive 50 waves in endless mode",
		"unlocks_skin": 3,
		"unlocked": false
	},
	"tower_enthusiast": {
		"name": "Tower Enthusiast",
		"description": "Build 100 towers total",
		"unlocks_skin": 4,
		"unlocked": false
	},
	"enemy_slayer": {
		"name": "Enemy Slayer",
		"description": "Defeat 1000 enemies",
		"unlocks_skin": 5,
		"unlocked": false
	},
	"perfectionist": {
		"name": "Perfectionist",
		"description": "Complete a level without losing any health",
		"unlocks_skin": 6,
		"unlocked": false
	},
	"economist": {
		"name": "Economist",
		"description": "Save 5000 gold",
		"unlocks_skin": 7,
		"unlocked": false
	},
	"speed_runner": {
		"name": "Speed Runner",
		"description": "Complete normal mode in under 10 minutes",
		"unlocks_skin": 8,
		"unlocked": false
	},
	"survivalist": {
		"name": "Survivalist",
		"description": "Survive 100 waves in endless mode",
		"unlocks_skin": 9,
		"unlocked": false
	},
	"tower_master": {
		"name": "Tower Master",
		"description": "Fully upgrade 10 towers in one game",
		"unlocks_skin": 10,
		"unlocked": false
	},
	"gold_hoarder": {
		"name": "Gold Hoarder",
		"description": "Accumulate 10000 gold in one game",
		"unlocks_skin": 11,
		"unlocked": false
	},
	"wave_crusher": {
		"name": "Wave Crusher",
		"description": "Survive 200 waves in endless mode",
		"unlocks_skin": 12,
		"unlocked": false
	},
	"strategic_genius": {
		"name": "Strategic Genius",
		"description": "Complete extra hard mode",
		"unlocks_skin": 13,
		"unlocked": false
	},
	"mass_destroyer": {
		"name": "Mass Destroyer",
		"description": "Defeat 5000 enemies",
		"unlocks_skin": 14,
		"unlocked": false
	},
	"treasure_hunter": {
		"name": "Treasure Hunter",
		"description": "Earn 50000 gold total across all games",
		"unlocks_skin": 15,
		"unlocked": false
	},
	"endurance_champion": {
		"name": "Endurance Champion",
		"description": "Survive 500 waves in endless mode",
		"unlocks_skin": 16,
		"unlocked": false
	},
	"building_tycoon": {
		"name": "Building Tycoon",
		"description": "Build 500 towers total",
		"unlocks_skin": 17,
		"unlocked": false
	},
	"ultimate_defender": {
		"name": "Ultimate Defender",
		"description": "Complete all game modes without losing health",
		"unlocks_skin": 18,
		"unlocked": false
	},
	"apocalypse_survivor": {
		"name": "Apocalypse Survivor",
		"description": "Survive 1000 waves in endless mode",
		"unlocks_skin": 19,
		"unlocked": false
	},
	"legendary_commander": {
		"name": "Legendary Commander",
		"description": "Defeat 10000 enemies total",
		"unlocks_skin": 20,
		"unlocked": false
	}
}

# Tracking variables for achievements - now using ProfileManager as single source of truth
# These getter functions access the real stats from ProfileManager

func get_total_enemies_defeated() -> int:
	var profile_manager = get_node("/root/ProfileManager")
	return profile_manager.get_stat("total_enemies_defeated") if profile_manager else 0

func get_total_towers_built() -> int:
	var profile_manager = get_node("/root/ProfileManager")
	return profile_manager.get_stat("total_towers_built") if profile_manager else 0

func get_total_gold_earned() -> int:
	var profile_manager = get_node("/root/ProfileManager")
	return profile_manager.get_stat("total_gold_earned") if profile_manager else 0

func get_highest_wave_survived() -> int:
	var profile_manager = get_node("/root/ProfileManager")
	return profile_manager.get_stat("highest_wave_reached") if profile_manager else 0

func get_total_normal_waves_completed() -> int:
	var profile_manager = get_node("/root/ProfileManager")
	return profile_manager.get_stat("total_normal_waves_completed") if profile_manager else 0

func get_total_extra_hard_waves_completed() -> int:
	var profile_manager = get_node("/root/ProfileManager")
	return profile_manager.get_stat("total_extra_hard_waves_completed") if profile_manager else 0

func get_levels_completed_perfect() -> int:
	var profile_manager = get_node("/root/ProfileManager")
	return profile_manager.get_stat("levels_completed_perfect") if profile_manager else 0

func get_game_modes_completed() -> Array:
	var profile_manager = get_node("/root/ProfileManager")
	if profile_manager and profile_manager.current_profile.has("stats"):
		return profile_manager.current_profile["stats"].get("game_modes_completed", [])
	return []

func _ready():
	# Don't auto-load achievements anymore - they should come from the profile system
	# load_achievements()
	print("AchievementManager: Ready. Waiting for profile to load achievements.")

func unlock_achievement(achievement_id: String, notify_ui: bool = false):
	"""Unlock an achievement and its associated skin in the current profile"""
	if achievement_id not in achievement_definitions:
		print("Warning: Unknown achievement ID: ", achievement_id)
		return
		
	var profile_manager = get_node("/root/ProfileManager")
	if not profile_manager:
		print("Warning: No ProfileManager found")
		return
		
	# Ensure profile has achievements dictionary
	if not profile_manager.current_profile.has("achievements"):
		profile_manager.current_profile["achievements"] = {}
	
	# Check if already unlocked
	if profile_manager.current_profile["achievements"].get(achievement_id, false):
		return  # Already unlocked
		
	# Unlock the achievement in the profile
	profile_manager.current_profile["achievements"][achievement_id] = true
	var achievement_data = achievement_definitions[achievement_id]
	
	print("Achievement Unlocked: " + achievement_data.name + " - " + achievement_data.description)
	
	# Only emit signal if explicitly requested (during save checks)
	if notify_ui:
		achievement_unlocked.emit(achievement_id)
	
	# Unlock the associated skin in the profile
	var skin_to_unlock = achievement_data.unlocks_skin
	if not profile_manager.current_profile.has("unlocked_skins"):
		profile_manager.current_profile["unlocked_skins"] = [1]
	
	if skin_to_unlock not in profile_manager.current_profile["unlocked_skins"]:
		profile_manager.current_profile["unlocked_skins"].append(skin_to_unlock)
		skin_unlocked.emit(skin_to_unlock)
		print("Skin Unlocked: ", skin_to_unlock)
	
	# Save the profile to persist achievement unlock
	profile_manager.save_profile()

func is_achievement_unlocked(achievement_id: String) -> bool:
	"""Check if an achievement is unlocked from the current profile"""
	var profile_manager = get_node("/root/ProfileManager")
	if profile_manager and profile_manager.current_profile.has("achievements"):
		var result = profile_manager.current_profile["achievements"].get(achievement_id, false)
		if achievement_id == "first_victory":  # Debug just one achievement to avoid spam
			print("AchievementManager: Checking if ", achievement_id, " is unlocked. Result: ", result, " (profile achievements: ", profile_manager.current_profile["achievements"], ")")
		return result
	else:
		print("Warning: No profile manager or achievements data found")
		return false

func test_achievement_notification(achievement_id: String = "first_victory"):
	"""Show achievement notification for testing WITHOUT actually unlocking the achievement"""
	if achievement_id in achievement_definitions:
		print("Testing achievement notification for: ", achievement_id)
		achievement_unlocked.emit(achievement_id)
	else:
		print("Achievement ID not found: ", achievement_id)

func test_multiple_notifications():
	"""Show multiple achievement notifications for testing the queuing system"""
	print("Testing multiple achievement notifications...")
	# Use a timer to space out the emissions slightly
	test_achievement_notification("first_victory")
	
	# Add small delays to test queuing
	var timer1 = Timer.new()
	timer1.wait_time = 0.1
	timer1.one_shot = true
	add_child(timer1)
	timer1.timeout.connect(func(): test_achievement_notification("tower_enthusiast"))
	timer1.start()
	
	var timer2 = Timer.new()
	timer2.wait_time = 0.2
	timer2.one_shot = true
	add_child(timer2)
	timer2.timeout.connect(func(): test_achievement_notification("wave_master"))
	timer2.start()

func is_skin_unlocked(skin_id: int) -> bool:
	"""Check if a skin is unlocked in the current profile"""
	var profile_manager = get_node("/root/ProfileManager")
	if profile_manager and profile_manager.current_profile.has("unlocked_skins"):
		return skin_id in profile_manager.current_profile["unlocked_skins"]
	else:
		# Default to just skin 1 being unlocked if no profile data
		return skin_id == 1

func get_unlocked_skins() -> Array[int]:
	"""Get all unlocked skins from the current profile"""
	var profile_manager = get_node("/root/ProfileManager")
	if profile_manager and profile_manager.current_profile.has("unlocked_skins"):
		return profile_manager.current_profile["unlocked_skins"].duplicate()
	else:
		# Default to just skin 1 if no profile data
		return [1]

func track_enemy_defeated():
	"""Track an enemy defeat for achievements - delegates to ProfileManager"""
	var profile_manager = get_node("/root/ProfileManager")
	if profile_manager:
		profile_manager.update_stat("total_enemies_defeated", 1)
		print("Enemy defeated! Total: ", profile_manager.get_stat("total_enemies_defeated"))

func track_tower_built():
	"""Track a tower build for achievements - delegates to ProfileManager"""
	var profile_manager = get_node("/root/ProfileManager")
	if profile_manager:
		profile_manager.update_stat("total_towers_built", 1)
		print("Tower built! Total: ", profile_manager.get_stat("total_towers_built"))

func track_gold_earned(amount: int):
	"""Track gold earned for achievements - delegates to ProfileManager"""
	var profile_manager = get_node("/root/ProfileManager")
	if profile_manager:
		profile_manager.update_stat("total_gold_earned", amount)
		print("Gold earned: ", amount, ". Total: ", profile_manager.get_stat("total_gold_earned"))

func track_wave_survived(wave: int, mode_name: String = ""):
	"""Track wave survival for achievements - delegates to ProfileManager"""
	var profile_manager = get_node("/root/ProfileManager")
	if profile_manager:
		# Only track highest wave for endless mode
		if mode_name.to_lower() == "endless":
			var current_highest = profile_manager.get_stat("highest_wave_reached")
			if wave > current_highest:
				profile_manager.set_stat("highest_wave_reached", wave)
				print("New highest wave (endless): ", wave)

func track_mode_waves_completed(wave: int, mode_name: String):
	"""Track waves completed for specific modes"""
	var profile_manager = get_node("/root/ProfileManager")
	if not profile_manager:
		return
		
	match mode_name.to_lower():
		"normal":
			profile_manager.update_stat("total_normal_waves_completed", wave)
			print("Normal mode waves completed: ", wave)
		"extra hard", "extrahard":
			profile_manager.update_stat("total_extra_hard_waves_completed", wave)
			print("Extra hard mode waves completed: ", wave)
		_:
			print("Unknown mode for wave tracking: ", mode_name)

func track_level_completed(perfect: bool = false, mode_name: String = ""):
	"""Track level completion for achievements - delegates to ProfileManager"""
	var profile_manager = get_node("/root/ProfileManager")
	if not profile_manager:
		return
		
	if perfect:
		profile_manager.update_stat("levels_completed_perfect", 1)
		print("Perfect level completed! Total perfect: ", profile_manager.get_stat("levels_completed_perfect"))
	
	if mode_name != "":
		var current_modes = get_game_modes_completed()
		if mode_name not in current_modes:
			current_modes.append(mode_name)
			# Update the profile directly since game_modes_completed is an array
			if profile_manager.current_profile.has("stats"):
				profile_manager.current_profile["stats"]["game_modes_completed"] = current_modes
			print("Game mode completed: ", mode_name, ". Total modes: ", current_modes.size())

func check_all_achievements_on_save():
	"""Check all achievements when saving and notify for newly unlocked ones"""
	var newly_unlocked = []
	
	# Get current stats from ProfileManager
	var total_enemies_defeated = get_total_enemies_defeated()
	var total_towers_built = get_total_towers_built()
	var total_gold_earned = get_total_gold_earned()
	var highest_wave_survived = get_highest_wave_survived()
	var _levels_completed_perfect = get_levels_completed_perfect()
	var game_modes_completed = get_game_modes_completed()
	
	print("AchievementManager: Checking achievements with stats:")
	print("  - Enemies defeated: ", total_enemies_defeated)
	print("  - Towers built: ", total_towers_built)
	print("  - Highest wave: ", highest_wave_survived)
	print("  - Game modes completed: ", game_modes_completed)
	
	# Tower-related achievements
	print("  - Checking tower_enthusiast: ", total_towers_built, " >= 100? ", (total_towers_built >= 100), " already unlocked? ", is_achievement_unlocked("tower_enthusiast"))
	if total_towers_built >= 100 and not is_achievement_unlocked("tower_enthusiast"):
		unlock_achievement("tower_enthusiast", true)
		newly_unlocked.append("tower_enthusiast")
	
	# Wave survival achievements  
	print("  - Checking wave_master: ", highest_wave_survived, " >= 50? ", (highest_wave_survived >= 50), " already unlocked? ", is_achievement_unlocked("wave_master"))
	if highest_wave_survived >= 50 and not is_achievement_unlocked("wave_master"):
		unlock_achievement("wave_master", true)
		newly_unlocked.append("wave_master")
	
	# Game mode achievements
	print("  - Checking first_victory: ", game_modes_completed.size(), " >= 1? ", (game_modes_completed.size() >= 1), " already unlocked? ", is_achievement_unlocked("first_victory"))
	if game_modes_completed.size() >= 1 and not is_achievement_unlocked("first_victory"):
		unlock_achievement("first_victory", true)
		newly_unlocked.append("first_victory")
	
	if "Extra Hard" in game_modes_completed and not is_achievement_unlocked("strategic_genius"):
		unlock_achievement("strategic_genius", true)
		newly_unlocked.append("strategic_genius")
	
	# Gold achievements
	if total_gold_earned >= 50000 and not is_achievement_unlocked("treasure_hunter"):
		unlock_achievement("treasure_hunter", true)
		newly_unlocked.append("treasure_hunter")
	
	# Note: achievement_unlocked signal is emitted from unlock_achievement when notify_ui=true
	for achievement_id in newly_unlocked:
		print("Achievement unlocked during save: ", achievement_id)
	
	return newly_unlocked.size() > 0

func save_achievements():
	"""Save achievements to file - DEPRECATED: achievements now saved through ProfileManager"""
	# Note: Achievements are now saved as part of the profile system
	# This function is kept for compatibility but does nothing
	print("AchievementManager: save_achievements() called - achievements now saved via ProfileManager")

func clear_legacy_save_file():
	"""Remove the legacy achievement save file to prevent conflicts"""
	if FileAccess.file_exists(SAVE_FILE_PATH):
		DirAccess.remove_absolute(SAVE_FILE_PATH)
		print("AchievementManager: Removed legacy save file: ", SAVE_FILE_PATH)

func load_achievements():
	"""Load achievements from file - DEPRECATED: achievements now loaded through ProfileManager"""
	print("AchievementManager: load_achievements() called - achievements now loaded through ProfileManager")
	# Legacy function kept for compatibility - does nothing now

func reset_achievements():
	"""Reset all achievements - now handled via ProfileManager reset"""
	print("AchievementManager: reset_achievements() called - achievements now reset via ProfileManager.reset_current_profile()")
	
	# Achievement resets are now handled by ProfileManager.reset_current_profile()
	# This function is kept for compatibility but does nothing

# Profile system integration methods (legacy - achievements now accessed directly from ProfileManager)
func load_from_profile(_profile_achievements: Dictionary, _profile_unlocked_skins: Array, _profile_stats: Dictionary = {}):
	"""Legacy function - achievements now loaded directly from ProfileManager"""
	print("AchievementManager: load_from_profile() called - achievements now loaded directly from ProfileManager")

func sync_to_profile():
	"""Legacy function - achievements now sync automatically via ProfileManager"""
	print("AchievementManager: sync_to_profile() called - achievements now sync automatically via ProfileManager")

func _on_achievement_unlocked(_achievement_id: String):
	"""Handle achievement unlocked - no longer needed as ProfileManager handles sync"""
	pass

func _on_skin_unlocked(_skin_id: int):
	"""Handle skin unlocked - no longer needed as ProfileManager handles sync"""
	pass
