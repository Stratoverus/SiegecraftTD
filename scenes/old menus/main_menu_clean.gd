extends Control

# References to UI elements
@onready var skin_grid: GridContainer
@onready var current_skin_label: Label
@onready var profile_name_label: Label

# Medieval theme variables
var rank_thresholds = [
	{"waves": 0, "title": "Peasant Defender"},
	{"waves": 10, "title": "Village Guard"},
	{"waves": 25, "title": "Castle Defender"},
	{"waves": 50, "title": "Tower Commander"},
	{"waves": 100, "title": "Lord/Lady Protector"},
	{"waves": 200, "title": "Master of Siege"},
	{"waves": 500, "title": "Legendary Guardian"},
	{"waves": 1000, "title": "Immortal Defender"}
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
	$CenterContainer/MainMenuScroll/MainMenuContent/MainButtons/newGame.grab_focus()
	$CenterContainer/SettingsScroll/SettingsMenu/SettingsGrid/fullscreen.button_pressed = true if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN else false
	$CenterContainer/SettingsScroll/SettingsMenu/SettingsGrid/mainVolSlider.value = db_to_linear(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Master")))
	$CenterContainer/SettingsScroll/SettingsMenu/SettingsGrid/musicVolSlider.value = db_to_linear(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("MUSIC")))
	$CenterContainer/SettingsScroll/SettingsMenu/SettingsGrid/sfxVolSlider.value = db_to_linear(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("SFX")))
	
	# Get references to UI elements
	profile_name_label = $ProfileHeraldry/ProfileContainer/profileNameLabel
	
	# Connect to skin change signal
	house_skin_manager = get_node("/root/HouseSkinManager")
	if house_skin_manager:
		house_skin_manager.skin_changed.connect(_on_skin_changed)
	
	# Connect to profile loaded signal to refresh UI when profiles change
	if profile_manager:
		profile_manager.profile_loaded.connect(_on_profile_loaded)
	
	# Update profile display with medieval theming
	update_medieval_profile_display()

func update_medieval_profile_display():
	"""Update the profile name display with medieval theming and rank"""
	if profile_manager and profile_manager.has_profile():
		var profile_name = profile_manager.profile_name
		profile_name_label.text = profile_name
		
		# Calculate and display medieval rank based on achievements
		var rank_title = get_medieval_rank()
		$ProfileHeraldry/ProfileContainer/ProfileRank.text = rank_title
		
		# Ensure the ProfileHeraldry is visible
		$ProfileHeraldry.visible = true
	else:
		profile_name_label.text = "Unknown Noble"
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
	$CenterContainer/MainMenuScroll.visible = false
	$CenterContainer/SettingsScroll.visible = true

func hide_settings_menu():
	$CenterContainer/SettingsScroll.visible = false
	$CenterContainer/MainMenuScroll.visible = true

# Profile and skin handlers
func _on_profile_loaded():
	"""Called when a profile is loaded"""
	update_medieval_profile_display()

func _on_skin_changed():
	"""Called when house skin changes"""
	# Will implement later for medieval theme if needed
	pass
