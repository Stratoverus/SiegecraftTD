extends Control

# References to UI elements
@onready var skin_grid: GridContainer
@onready var current_skin_label: Label
@onready var profile_name_label: Label

# Medieval theme variables
var rank_thresholds = [
	{"waves": 0, "title": "Tarnished Wanderer"},
	{"waves": 10, "title": "Tower Novice"},
	{"waves": 25, "title": "Siege Apprentice"},
	{"waves": 50, "title": "Fortress Guardian"},
	{"waves": 100, "title": "Lord of Towers"},
	{"waves": 200, "title": "Elden Defender"},
	{"waves": 500, "title": "Demigod of Defense"},
	{"waves": 1000, "title": "Elden Lord of Towers"}
]

# Manager references
var house_skin_manager
var profile_manager

func _ready() -> void:
	# Check if this is a first-time user
	profile_manager = get_node("/root/ProfileManager")
	if profile_manager and profile_manager.is_first_time_user():
		# First time user - go to name entry
		get_tree().change_scene_to_file("res://scenes/name_entry.tscn")
		return
	
	# If no profile is loaded but profiles exist, show profile selection
	if profile_manager and not profile_manager.has_profile():
		var all_profiles = profile_manager.get_all_profiles()
		if all_profiles.size() > 0:
			# Load the first available profile
			profile_manager.switch_profile(all_profiles[0])
	
	# Set up the main menu normally
	setup_main_menu()

func setup_main_menu():
	"""Set up the main menu UI"""
	# Use call_deferred to ensure all nodes are ready
	call_deferred("_set_initial_focus")
	
	# Handle both layouts - check which one exists
	var fullscreen_node = null
	var main_vol_node = null
	var music_vol_node = null
	var sfx_vol_node = null
	
	# Try Elden Ring layout first
	if has_node("CentralLayout/SettingsPanel/SettingsContent/SettingsScrollContainer/SettingsGrid/fullscreen"):
		fullscreen_node = $CentralLayout/SettingsPanel/SettingsContent/SettingsScrollContainer/SettingsGrid/fullscreen
		main_vol_node = $CentralLayout/SettingsPanel/SettingsContent/SettingsScrollContainer/SettingsGrid/MasterVolumeSection/mainVolSlider
		music_vol_node = $CentralLayout/SettingsPanel/SettingsContent/SettingsScrollContainer/SettingsGrid/MusicVolumeSection/musicVolSlider
		sfx_vol_node = $CentralLayout/SettingsPanel/SettingsContent/SettingsScrollContainer/SettingsGrid/SFXVolumeSection/sfxVolSlider
		profile_name_label = $ProfileHeraldry/ProfileFrame/profileNameLabel
	# Try AAA layout
	elif has_node("MainContainer/SettingsPanel/SettingsContent/SettingsGrid/fullscreen"):
		fullscreen_node = $MainContainer/SettingsPanel/SettingsContent/SettingsGrid/fullscreen
		main_vol_node = $MainContainer/SettingsPanel/SettingsContent/SettingsGrid/MasterVolumeContainer/mainVolSlider
		music_vol_node = $MainContainer/SettingsPanel/SettingsContent/SettingsGrid/MusicVolumeContainer/musicVolSlider
		sfx_vol_node = $MainContainer/SettingsPanel/SettingsContent/SettingsGrid/SFXVolumeContainer/sfxVolSlider
		profile_name_label = $ProfilePanel/ProfileContent/profileNameLabel
	# Try simple layout
	elif has_node("CenterContainer/SettingsScroll/SettingsMenu/fullscreen"):
		fullscreen_node = $CenterContainer/SettingsScroll/SettingsMenu/fullscreen
		main_vol_node = $CenterContainer/SettingsScroll/SettingsMenu/mainVolSlider
		music_vol_node = $CenterContainer/SettingsScroll/SettingsMenu/musicVolSlider
		sfx_vol_node = $CenterContainer/SettingsScroll/SettingsMenu/sfxVolSlider
		profile_name_label = $ProfileHeraldry/ProfileContainer/profileNameLabel
	
	# Set up settings if nodes exist
	if fullscreen_node:
		fullscreen_node.button_pressed = true if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN else false
	if main_vol_node:
		main_vol_node.value = db_to_linear(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Master")))
	if music_vol_node:
		music_vol_node.value = db_to_linear(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("MUSIC")))
	if sfx_vol_node:
		sfx_vol_node.value = db_to_linear(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("SFX")))
	
	# Connect to skin change signal
	house_skin_manager = get_node("/root/HouseSkinManager")
	if house_skin_manager:
		house_skin_manager.skin_changed.connect(_on_skin_changed)
	
	# Connect to profile loaded signal to refresh UI when profiles change
	if profile_manager:
		profile_manager.profile_loaded.connect(_on_profile_loaded)
	
	# Update profile display with theming
	update_medieval_profile_display()

func _set_initial_focus():
	"""Set the initial focus after the scene is fully loaded"""
	# Try Elden Ring layout first
	if has_node("CentralLayout/MainMenuPanel/MenuContent/PrimaryActions/newGame"):
		$CentralLayout/MainMenuPanel/MenuContent/PrimaryActions/newGame.grab_focus()
	# Try AAA layout
	elif has_node("MainContainer/LeftPanel/MainMenuContent/MainButtons/newGame"):
		$MainContainer/LeftPanel/MainMenuContent/MainButtons/newGame.grab_focus()
	# Try simple layout
	elif has_node("CenterContainer/MainMenuScroll/MainMenuContent/MainButtons/newGame"):
		$CenterContainer/MainMenuScroll/MainMenuContent/MainButtons/newGame.grab_focus()
	else:
		print("Warning: Could not find newGame button to focus")

func update_profile_display():
	"""Update the profile name display - calls medieval version for compatibility"""
	update_medieval_profile_display()

func update_medieval_profile_display():
	"""Update the profile name display with theming and rank"""
	if profile_manager and profile_manager.has_profile():
		var profile_name = profile_manager.profile_name
		if profile_name_label:
			profile_name_label.text = profile_name
		
		# Calculate and display rank based on achievements
		var rank_title = get_medieval_rank()
		
		# Update rank display - check which layout we're using
		if has_node("ProfileHeraldry/ProfileFrame/ProfileRank"):
			$ProfileHeraldry/ProfileFrame/ProfileRank.text = rank_title
			$ProfileHeraldry.visible = true
		elif has_node("ProfilePanel/ProfileContent/ProfileRank"):
			$ProfilePanel/ProfileContent/ProfileRank.text = rank_title
			$ProfilePanel.visible = true
		elif has_node("ProfileHeraldry/ProfileContainer/ProfileRank"):
			$ProfileHeraldry/ProfileContainer/ProfileRank.text = rank_title
			$ProfileHeraldry.visible = true
	else:
		if profile_name_label:
			profile_name_label.text = "Commander"
		
		# Set default rank display
		if has_node("ProfileHeraldry/ProfileFrame/ProfileRank"):
			$ProfileHeraldry/ProfileFrame/ProfileRank.text = "Tarnished Wanderer"
			$ProfileHeraldry.visible = true
		elif has_node("ProfilePanel/ProfileContent/ProfileRank"):
			$ProfilePanel/ProfileContent/ProfileRank.text = "Recruit"
			$ProfilePanel.visible = true
		elif has_node("ProfileHeraldry/ProfileContainer/ProfileRank"):
			$ProfileHeraldry/ProfileContainer/ProfileRank.text = "Visitor to the Realm"
			$ProfileHeraldry.visible = true

func get_medieval_rank() -> String:
	"""Calculate medieval rank based on player achievements"""
	if not profile_manager or not profile_manager.has_profile():
		return "Visitor to the Realm"
	
	var profile_data = profile_manager.get_profile_data()
	var stats = profile_data.get("stats", {})
	var highest_wave = stats.get("highest_wave_reached", 0)
	
	# Find appropriate rank based on highest wave achieved
	var current_rank = "Peasant Defender"
	for rank_data in rank_thresholds:
		if highest_wave >= rank_data.waves:
			current_rank = rank_data.title
		else:
			break
	
	return current_rank

# Button signal handlers
func _on_new_game_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/map.tscn")

func _on_load_game_pressed() -> void:
	print("Load game functionality not implemented yet")

func _on_settings_pressed() -> void:
	show_settings_menu()

func _on_profile_pressed() -> void:
	print("Profile functionality not implemented yet")

func _on_credits_pressed() -> void:
	print("Credits functionality not implemented yet")

func _on_quit_pressed() -> void:
	get_tree().quit()

func _on_change_name_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/name_entry.tscn")

func _on_back_pressed() -> void:
	hide_settings_menu()

# Settings handlers
func _on_fullscreen_toggled(button_pressed: bool) -> void:
	if button_pressed:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)

func _on_main_vol_slider_value_changed(value: float) -> void:
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Master"), linear_to_db(value))

func _on_music_vol_slider_value_changed(value: float) -> void:
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("MUSIC"), linear_to_db(value))

func _on_sfx_vol_slider_value_changed(value: float) -> void:
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("SFX"), linear_to_db(value))

# Menu navigation
func show_settings_menu():
	# Check which layout we're using
	if has_node("CentralLayout/SettingsPanel"):
		$CentralLayout/MainMenuPanel.visible = false
		$CentralLayout/SettingsPanel.visible = true
	elif has_node("MainContainer/SettingsPanel"):
		$MainContainer/LeftPanel.visible = false
		$MainContainer/RightPanel.visible = false
		$MainContainer/SettingsPanel.visible = true
	elif has_node("CenterContainer/SettingsScroll"):
		$CenterContainer/MainMenuScroll.visible = false
		$CenterContainer/SettingsScroll.visible = true

func hide_settings_menu():
	# Check which layout we're using
	if has_node("CentralLayout/SettingsPanel"):
		$CentralLayout/SettingsPanel.visible = false
		$CentralLayout/MainMenuPanel.visible = true
	elif has_node("MainContainer/SettingsPanel"):
		$MainContainer/SettingsPanel.visible = false
		$MainContainer/LeftPanel.visible = true
		$MainContainer/RightPanel.visible = true
	elif has_node("CenterContainer/SettingsScroll"):
		$CenterContainer/SettingsScroll.visible = false
		$CenterContainer/MainMenuScroll.visible = true

func _on_apply_pressed() -> void:
	"""Handle apply button in settings - AAA layout only"""
	print("Settings applied!")
	# Could add save settings functionality here

# Profile and skin handlers
func _on_profile_loaded():
	"""Called when a profile is loaded"""
	update_medieval_profile_display()

func _on_skin_changed():
	"""Called when house skin changes"""
	# Will implement later for medieval theme if needed
	pass
