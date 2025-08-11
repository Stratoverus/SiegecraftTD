extends Node

# Singleton for managing achievements and unlockable house skins
# Available as AchievementManager autoload

signal achievement_unlocked(achievement_id: String)
signal skin_unlocked(skin_id: int)

# Achievement data structure
var achievements: Dictionary = {}
var unlocked_skins: Array[int] = [1]  # skin1 is always unlocked

# Save/load file path
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

# Tracking variables for achievements
var total_enemies_defeated: int = 0
var total_towers_built: int = 0
var total_gold_earned: int = 0
var highest_wave_survived: int = 0
var levels_completed_perfect: int = 0
var game_modes_completed: Array[String] = []

func _ready():
	load_achievements()

func unlock_achievement(achievement_id: String):
	"""Unlock an achievement and its associated skin"""
	if achievement_id in achievement_definitions and not achievements.get(achievement_id, false):
		achievements[achievement_id] = true
		var achievement_data = achievement_definitions[achievement_id]
		
		print("Achievement Unlocked: " + achievement_data.name + " - " + achievement_data.description)
		achievement_unlocked.emit(achievement_id)
		
		# Unlock the associated skin
		var skin_to_unlock = achievement_data.unlocks_skin
		if skin_to_unlock not in unlocked_skins:
			unlocked_skins.append(skin_to_unlock)
			skin_unlocked.emit(skin_to_unlock)
			print("Skin " + str(skin_to_unlock) + " unlocked!")
		
		save_achievements()

func is_achievement_unlocked(achievement_id: String) -> bool:
	"""Check if an achievement is unlocked"""
	return achievements.get(achievement_id, false)

func is_skin_unlocked(skin_id: int) -> bool:
	"""Check if a skin is unlocked"""
	return skin_id in unlocked_skins

func get_unlocked_skins() -> Array[int]:
	"""Get all unlocked skins"""
	return unlocked_skins.duplicate()

func track_enemy_defeated():
	"""Track an enemy defeat for achievements"""
	total_enemies_defeated += 1
	
	# Check for enemy-related achievements
	if total_enemies_defeated >= 1000 and not is_achievement_unlocked("enemy_slayer"):
		unlock_achievement("enemy_slayer")
	elif total_enemies_defeated >= 5000 and not is_achievement_unlocked("mass_destroyer"):
		unlock_achievement("mass_destroyer")
	elif total_enemies_defeated >= 10000 and not is_achievement_unlocked("legendary_commander"):
		unlock_achievement("legendary_commander")

func track_tower_built():
	"""Track a tower build for achievements"""
	total_towers_built += 1
	
	# Check for tower-related achievements
	if total_towers_built >= 100 and not is_achievement_unlocked("tower_enthusiast"):
		unlock_achievement("tower_enthusiast")
	elif total_towers_built >= 500 and not is_achievement_unlocked("building_tycoon"):
		unlock_achievement("building_tycoon")

func track_gold_earned(amount: int):
	"""Track gold earned for achievements"""
	total_gold_earned += amount

func track_wave_survived(wave: int):
	"""Track wave survival for achievements"""
	if wave > highest_wave_survived:
		highest_wave_survived = wave
		
		# Check for wave-related achievements
		if highest_wave_survived >= 50 and not is_achievement_unlocked("wave_master"):
			unlock_achievement("wave_master")
		elif highest_wave_survived >= 100 and not is_achievement_unlocked("survivalist"):
			unlock_achievement("survivalist")
		elif highest_wave_survived >= 200 and not is_achievement_unlocked("wave_crusher"):
			unlock_achievement("wave_crusher")
		elif highest_wave_survived >= 500 and not is_achievement_unlocked("endurance_champion"):
			unlock_achievement("endurance_champion")
		elif highest_wave_survived >= 1000 and not is_achievement_unlocked("apocalypse_survivor"):
			unlock_achievement("apocalypse_survivor")

func track_level_completed(perfect: bool = false, mode_name: String = ""):
	"""Track level completion for achievements"""
	if perfect:
		levels_completed_perfect += 1
		if levels_completed_perfect >= 1 and not is_achievement_unlocked("perfectionist"):
			unlock_achievement("perfectionist")
	
	if mode_name != "" and mode_name not in game_modes_completed:
		game_modes_completed.append(mode_name)
		
		# Check for first victory
		if game_modes_completed.size() == 1 and not is_achievement_unlocked("first_victory"):
			unlock_achievement("first_victory")
		
		# Check for specific mode completions
		if mode_name == "extra_hard" and not is_achievement_unlocked("strategic_genius"):
			unlock_achievement("strategic_genius")

func save_achievements():
	"""Save achievements to file"""
	var save_data = {
		"achievements": achievements,
		"unlocked_skins": unlocked_skins,
		"total_enemies_defeated": total_enemies_defeated,
		"total_towers_built": total_towers_built,
		"total_gold_earned": total_gold_earned,
		"highest_wave_survived": highest_wave_survived,
		"levels_completed_perfect": levels_completed_perfect,
		"game_modes_completed": game_modes_completed
	}
	
	var file = FileAccess.open(SAVE_FILE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(save_data))
		file.close()

func load_achievements():
	"""Load achievements from file"""
	if FileAccess.file_exists(SAVE_FILE_PATH):
		var file = FileAccess.open(SAVE_FILE_PATH, FileAccess.READ)
		if file:
			var json_string = file.get_as_text()
			file.close()
			
			var json = JSON.new()
			var parse_result = json.parse(json_string)
			
			if parse_result == OK:
				var save_data = json.data
				achievements = save_data.get("achievements", {})
				
				# Convert unlocked_skins array properly
				var loaded_skins = save_data.get("unlocked_skins", [1])
				unlocked_skins.clear()
				for skin_id in loaded_skins:
					unlocked_skins.append(skin_id as int)
				
				total_enemies_defeated = save_data.get("total_enemies_defeated", 0)
				total_towers_built = save_data.get("total_towers_built", 0)
				total_gold_earned = save_data.get("total_gold_earned", 0)
				highest_wave_survived = save_data.get("highest_wave_survived", 0)
				levels_completed_perfect = save_data.get("levels_completed_perfect", 0)
				
				# Convert game_modes_completed array properly
				var loaded_modes = save_data.get("game_modes_completed", [])
				game_modes_completed.clear()
				for mode_name in loaded_modes:
					game_modes_completed.append(mode_name as String)
			else:
				print("Error parsing achievements save file")
				reset_achievements()
	else:
		reset_achievements()

func reset_achievements():
	"""Reset all achievements (for testing purposes)"""
	achievements.clear()
	unlocked_skins = [1]  # Always keep skin1 unlocked
	total_enemies_defeated = 0
	total_towers_built = 0
	total_gold_earned = 0
	highest_wave_survived = 0
	levels_completed_perfect = 0
	game_modes_completed.clear()
	save_achievements()

# Profile system integration methods
func load_from_profile(profile_achievements: Dictionary, profile_unlocked_skins: Array):
	"""Load achievement data from a profile"""
	achievements = profile_achievements
	
	# Convert the generic Array to Array[int] properly
	unlocked_skins.clear()
	for skin_id in profile_unlocked_skins:
		unlocked_skins.append(skin_id as int)
	
	# Ensure skin1 is always unlocked
	if not unlocked_skins.has(1):
		unlocked_skins.append(1)

func sync_to_profile():
	"""Sync current achievement data to profile"""
	var profile_manager = get_node("/root/ProfileManager")
	if profile_manager:
		profile_manager.sync_from_subsystems()

func _on_achievement_unlocked(_achievement_id: String):
	"""Handle achievement unlocked - sync to profile"""
	sync_to_profile()

func _on_skin_unlocked(_skin_id: int):
	"""Handle skin unlocked - sync to profile"""
	sync_to_profile()
