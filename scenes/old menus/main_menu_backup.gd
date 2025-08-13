extends Control

# References to UI elements
@onready var skin_grid: GridContainer
@onready var current_skin_label: Label
@onready var profile_name_label: Label

func _ready() -> void:
	# Check if this is a first-time user
	var profile_manager = get_node("/root/ProfileManager")
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
	$CenterContainer/MainMenuPanel/MainButtons/newGame.grab_focus()
	$CenterContainer/SettingsPanel/SettingsMenu/fullscreen.button_pressed = true if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN else false
	$CenterContainer/SettingsPanel/SettingsMenu/mainVolSlider.value = db_to_linear(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Master")))
	$CenterContainer/SettingsPanel/SettingsMenu/musicVolSlider.value = db_to_linear(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("MUSIC")))
	$CenterContainer/SettingsPanel/SettingsMenu/sfxVolSlider.value = db_to_linear(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("SFX")))
	
	# Get references to UI elements
	skin_grid = $CenterContainer/HouseSkinsPanel/HouseSkinsMenu/ScrollContainer/skinGrid
	current_skin_label = $CenterContainer/HouseSkinsPanel/HouseSkinsMenu/currentSkinLabel
	profile_name_label = $ProfileDisplay/ProfileContainer/profileNameLabel
	
	# Configure the skin grid for better spacing
	skin_grid.columns = 4  # 4 columns to spread out the 20 skins nicely
	skin_grid.add_theme_constant_override("h_separation", 20)  # Horizontal spacing
	skin_grid.add_theme_constant_override("v_separation", 15)  # Vertical spacing
	
	# Configure the scroll container to reduce excessive spacing
	var scroll_container = $CenterContainer/HouseSkinsPanel/HouseSkinsMenu/ScrollContainer
	scroll_container.custom_minimum_size = Vector2(650, 400)  # Reduce width to minimize gap
	scroll_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll_container.size_flags_horizontal = Control.SIZE_SHRINK_CENTER  # Center and shrink to content
	scroll_container.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED  # Disable horizontal scrollbar
	
	# Connect to skin change signal
	var house_skin_manager = get_node("/root/HouseSkinManager")
	if house_skin_manager:
		house_skin_manager.skin_changed.connect(_on_skin_changed)
	
	# Connect to profile loaded signal to refresh UI when profiles change
	var profile_manager = get_node("/root/ProfileManager")
	if profile_manager:
		profile_manager.profile_loaded.connect(_on_profile_loaded)
	
	# Update profile display
	update_profile_display()
	_update_current_skin_display()

func update_profile_display():
	"""Update the profile name display"""
	var profile_manager = get_node("/root/ProfileManager")
	if profile_manager and profile_manager.has_profile():
		var profile_name = profile_manager.profile_name
		profile_name_label.text = profile_name
		# Ensure the ProfileDisplay is visible
		$ProfileDisplay.visible = true
	else:
		profile_name_label.text = "No Profile"
		$ProfileDisplay.visible = true

func _on_change_name_pressed() -> void:
	"""Handle change profile button - show profile selection"""
	show_profile_selection_dialog()

func show_profile_selection_dialog():
	"""Show dialog to select, create, or delete profiles"""
	var dialog = AcceptDialog.new()
	dialog.title = "Profile Management"
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	vbox.custom_minimum_size = Vector2(480, 350)
	
	# Title
	var title_label = Label.new()
	title_label.text = "Select Profile:"
	title_label.add_theme_font_size_override("font_size", 20)
	vbox.add_child(title_label)
	
	# Profile list
	var scroll = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(460, 180)
	var profile_list = VBoxContainer.new()
	scroll.add_child(profile_list)
	vbox.add_child(scroll)
	
	# Get all profiles
	var profile_manager = get_node("/root/ProfileManager")
	var all_profiles = profile_manager.get_all_profiles()
	var current_profile_name = profile_manager.profile_name
	
	# Add profile buttons
	for profile_name in all_profiles:
		var hbox = HBoxContainer.new()
		
		var profile_btn = Button.new()
		profile_btn.text = profile_name
		if profile_name == current_profile_name:
			profile_btn.text += " (Current)"
			profile_btn.disabled = true
		else:
			profile_btn.pressed.connect(_on_profile_selected.bind(profile_name, dialog))
		profile_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hbox.add_child(profile_btn)
		
		# Reset button for current profile OR Delete button for others
		if profile_name == current_profile_name:
			var reset_btn = Button.new()
			reset_btn.text = "Reset"
			reset_btn.modulate = Color.ORANGE  # Make it visually distinct
			reset_btn.pressed.connect(_on_profile_reset.bind(profile_name, dialog))
			hbox.add_child(reset_btn)
		elif all_profiles.size() > 1:
			var delete_btn = Button.new()
			delete_btn.text = "Delete"
			delete_btn.pressed.connect(_on_profile_delete.bind(profile_name, dialog))
			hbox.add_child(delete_btn)
		
		profile_list.add_child(hbox)
	
	# Create new profile section
	var separator = HSeparator.new()
	vbox.add_child(separator)
	
	var new_profile_label = Label.new()
	new_profile_label.text = "Create New Profile:"
	vbox.add_child(new_profile_label)
	
	var new_profile_hbox = HBoxContainer.new()
	var new_name_edit = LineEdit.new()
	new_name_edit.placeholder_text = "Enter new profile name..."
	new_name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	new_profile_hbox.add_child(new_name_edit)
	
	var create_btn = Button.new()
	create_btn.text = "Create"
	create_btn.pressed.connect(_on_create_profile.bind(new_name_edit, dialog))
	new_profile_hbox.add_child(create_btn)
	
	vbox.add_child(new_profile_hbox)
	
	dialog.add_child(vbox)
	add_child(dialog)
	dialog.popup_centered()

func _on_profile_selected(profile_name: String, dialog: AcceptDialog):
	"""Handle profile selection"""
	var profile_manager = get_node("/root/ProfileManager")
	if profile_manager.switch_profile(profile_name):
		update_profile_display()
		# Update profile menu if it's currently visible
		if $CenterContainer/ProfileMenu.visible:
			_populate_profile_menu()
		dialog.queue_free()
	else:
		print("Failed to switch to profile: ", profile_name)

func _on_profile_delete(profile_name: String, dialog: AcceptDialog):
	"""Handle profile deletion"""
	# Close the main dialog first to prevent exclusive child issue
	dialog.hide()
	
	var confirm_dialog = ConfirmationDialog.new()
	confirm_dialog.dialog_text = "Are you sure you want to delete profile '" + profile_name + "'?\nThis action cannot be undone."
	confirm_dialog.confirmed.connect(_delete_profile_confirmed.bind(profile_name, dialog, confirm_dialog))
	confirm_dialog.canceled.connect(_delete_profile_canceled.bind(dialog, confirm_dialog))
	
	# Create a simple border style
	var style_box = StyleBoxFlat.new()
	style_box.border_color = Color.WHITE
	style_box.set_border_width_all(2)
	style_box.bg_color = Color(0.2, 0.2, 0.2, 0.9)
	confirm_dialog.add_theme_stylebox_override("panel", style_box)
	
	add_child(confirm_dialog)
	confirm_dialog.popup_centered()

func _delete_profile_confirmed(profile_name: String, main_dialog: AcceptDialog, confirm_dialog: ConfirmationDialog):
	"""Confirm profile deletion"""
	var profile_manager = get_node("/root/ProfileManager")
	if profile_manager.delete_profile(profile_name):
		print("Profile deleted: ", profile_name)
		# Clean up dialogs and refresh
		confirm_dialog.queue_free()
		main_dialog.queue_free()
		show_profile_selection_dialog()
	else:
		# Clean up dialogs properly and show main dialog again if deletion failed
		confirm_dialog.hide()  # Immediately remove exclusive child status
		confirm_dialog.queue_free()
		main_dialog.show()

func _delete_profile_canceled(main_dialog: AcceptDialog, confirm_dialog: ConfirmationDialog):
	"""Handle profile deletion cancel"""
	# Hide confirm dialog immediately to remove exclusive child status
	confirm_dialog.hide()
	confirm_dialog.queue_free()
	main_dialog.show()

func _on_profile_reset(profile_name: String, dialog: AcceptDialog):
	"""Handle profile reset"""
	# Close the main dialog first to prevent exclusive child issue
	dialog.hide()
	
	var confirm_dialog = ConfirmationDialog.new()
	confirm_dialog.dialog_text = "Are you sure you want to reset profile '" + profile_name + "'?\n\nThis will:\n• Delete all save games\n• Reset all stats to zero\n• Reset unlocked skins to default\n\nThis action cannot be undone."
	confirm_dialog.confirmed.connect(_reset_profile_confirmed.bind(profile_name, dialog, confirm_dialog))
	confirm_dialog.canceled.connect(_reset_profile_canceled.bind(dialog, confirm_dialog))
	
	# Create a simple border style without border
	var style_box = StyleBoxFlat.new()
	style_box.set_border_width_all(0)  # No border
	style_box.bg_color = Color(0.2, 0.2, 0.2, 0.9)
	confirm_dialog.add_theme_stylebox_override("panel", style_box)
	
	# Remove any default styling that might cause yellow borders
	var empty_style = StyleBoxEmpty.new()
	confirm_dialog.add_theme_stylebox_override("label_frame", empty_style)
	confirm_dialog.add_theme_stylebox_override("content_frame", empty_style)
	confirm_dialog.add_theme_stylebox_override("frame", empty_style)
	
	add_child(confirm_dialog)
	confirm_dialog.popup_centered()

func _reset_profile_confirmed(profile_name: String, main_dialog: AcceptDialog, confirm_dialog: ConfirmationDialog):
	"""Confirm profile reset"""
	var profile_manager = get_node("/root/ProfileManager")
	if profile_manager.reset_current_profile():
		print("Profile reset: ", profile_name)
		# Update the UI to reflect changes
		update_profile_display()
		# Update skins menu if visible
		if $CenterContainer/HouseSkinsPanel.visible:
			_populate_house_skins_menu()
		# Update achievements menu if visible
		if $CenterContainer/AchievementsPanel.visible:
			_populate_achievements_menu()
		# Clean up dialogs and refresh
		confirm_dialog.queue_free()
		main_dialog.queue_free()
		# Show a success message
		var success_dialog = AcceptDialog.new()
		success_dialog.dialog_text = "Profile '" + profile_name + "' has been reset successfully!"
		add_child(success_dialog)
		success_dialog.popup_centered()
		success_dialog.confirmed.connect(success_dialog.queue_free)
	else:
		# Clean up dialogs properly and show main dialog again if reset failed
		confirm_dialog.hide()  # Immediately remove exclusive child status
		confirm_dialog.queue_free()
		main_dialog.show()
		# Show error message
		var error_dialog = AcceptDialog.new()
		error_dialog.dialog_text = "Failed to reset profile. Please try again."
		add_child(error_dialog)
		error_dialog.popup_centered()
		error_dialog.confirmed.connect(error_dialog.queue_free)

func _reset_profile_canceled(main_dialog: AcceptDialog, confirm_dialog: ConfirmationDialog):
	"""Handle profile reset cancel"""
	# Hide confirm dialog immediately to remove exclusive child status
	confirm_dialog.hide()
	confirm_dialog.queue_free()
	main_dialog.show()

func _on_create_profile(name_edit: LineEdit, dialog: AcceptDialog):
	"""Handle creating new profile"""
	var new_name = name_edit.text.strip_edges()
	if new_name == "":
		return
	
	var profile_manager = get_node("/root/ProfileManager")
	if profile_manager.change_profile_name(new_name):
		update_profile_display()
		dialog.queue_free()
	else:
		# Show error - name already exists
		var error_dialog = AcceptDialog.new()
		error_dialog.dialog_text = "Profile name '" + new_name + "' already exists. Please choose a different name."
		add_child(error_dialog)
		error_dialog.popup_centered()
		error_dialog.confirmed.connect(error_dialog.queue_free)
	

# Game mode data
var selected_game_mode: Resource = null

func _on_new_game_pressed() -> void:
	$CenterContainer/MainMenuPanel.visible = false
	$CenterContainer/GameModePanel.visible = true
	$CenterContainer/GameModePanel/GameModeMenu/normal.grab_focus() 


func _on_load_game_pressed() -> void:
	$CenterContainer/MainMenuPanel.visible = false
	$CenterContainer/LoadPanel.visible = true
	_populate_continue_button()
	$CenterContainer/LoadPanel/LoadMenu/back.grab_focus()


func _populate_continue_button():
	"""Populate the continue button with checkpoint save info"""
	var save_manager = get_node("/root/SaveManager")
	if not save_manager:
		return
	
	# Get reference to the continue button
	var checkpoint_button = $CenterContainer/LoadPanel/LoadMenu/loadCheckpoint
	
	# Update checkpoint button
	if save_manager.has_checkpoint_save():
		var checkpoint_info = save_manager.get_checkpoint_file_info()
		var game_mode = checkpoint_info.get("game_mode", "Unknown")
		var wave_number = checkpoint_info.get("wave_number", 1)
		
		checkpoint_button.text = "CONTINUE (%s - Wave %d)" % [game_mode, wave_number]
		checkpoint_button.disabled = false
		checkpoint_button.modulate = Color.WHITE
		print("Checkpoint save available: Wave ", wave_number, " - ", game_mode)
	else:
		checkpoint_button.text = "CONTINUE (NO CHECKPOINT)"
		checkpoint_button.disabled = true
		checkpoint_button.modulate = Color(0.5, 0.5, 0.5, 1.0)


func load_checkpoint_game():
	"""Load the checkpoint save and transition to main scene"""
	var save_manager = get_node("/root/SaveManager")
	if not save_manager:
		return
	
	# Store the load flag for the main scene
	var game_mode_manager = get_node("/root/GameModeManager")
	if game_mode_manager:
		game_mode_manager.set_meta("load_checkpoint", true)  # Use checkpoint flag instead of save slot
	
	get_tree().change_scene_to_file("res://scenes/main.tscn")


func _on_load_checkpoint_pressed() -> void:
	"""Load the checkpoint save"""
	load_checkpoint_game()


func _on_settings_pressed() -> void:
	$CenterContainer/SettingsPanel.visible = true
	$CenterContainer/MainMenuPanel.visible = false
	$CenterContainer/SettingsPanel/SettingsMenu/back.grab_focus()

func _on_profile_pressed() -> void:
	$CenterContainer/ProfilePanel.visible = true
	$CenterContainer/MainMenuPanel.visible = false
	_populate_profile_menu()
	$CenterContainer/ProfilePanel/ProfileMenu/MenuButtons/viewStatsButton.grab_focus()

func _populate_profile_menu():
	"""Populate the profile menu with profile name"""
	var profile_manager = get_node("/root/ProfileManager")
	if profile_manager and profile_manager.has_profile():
		# Update profile name
		$CenterContainer/ProfilePanel/ProfileMenu/profileNameLabel.text = "Profile: " + profile_manager.profile_name

func _on_view_stats_pressed() -> void:
	"""Show the statistics menu"""
	$CenterContainer/ProfilePanel.visible = false
	$CenterContainer/StatsPanel.visible = true
	_populate_stats_menu()
	$CenterContainer/StatsPanel/StatsMenu/back.grab_focus()

func _populate_stats_menu():
	"""Populate the statistics menu with profile stats"""
	var profile_manager = get_node("/root/ProfileManager")
	if profile_manager and profile_manager.has_profile():
		var profile_data = profile_manager.get_profile_data()
		var stats = profile_data.get("stats", {})
		
		# Update stat labels
		$CenterContainer/StatsPanel/StatsMenu/StatsContainer/gamesPlayedValue.text = str(int(stats.get("games_played", 0)))
		$CenterContainer/StatsPanel/StatsMenu/StatsContainer/timesWonValue.text = str(int(stats.get("times_won", 0)))
		$CenterContainer/StatsPanel/StatsMenu/StatsContainer/timesLostValue.text = str(int(stats.get("times_lost", 0)))
		$CenterContainer/StatsPanel/StatsMenu/StatsContainer/wavesValue.text = str(int(stats.get("total_waves_survived", 0)))
		$CenterContainer/StatsPanel/StatsMenu/StatsContainer/enemiesValue.text = str(int(stats.get("total_enemies_defeated", 0)))
		$CenterContainer/StatsPanel/StatsMenu/StatsContainer/towersValue.text = str(int(stats.get("total_towers_built", 0)))
		$CenterContainer/StatsPanel/StatsMenu/StatsContainer/highestWaveValue.text = str(int(stats.get("highest_wave_reached", 0))) + " (Endless)"
		$CenterContainer/StatsPanel/StatsMenu/StatsContainer/goldEarnedValue.text = str(int(stats.get("total_gold_earned", 0)))
		$CenterContainer/StatsPanel/StatsMenu/StatsContainer/playTimeValue.text = profile_manager.get_formatted_play_time()
		
		# Add new wave completion stats if UI elements exist
		if has_node("CenterContainer/StatsPanel/StatsMenu/StatsContainer/normalWavesValue"):
			$CenterContainer/StatsPanel/StatsMenu/StatsContainer/normalWavesValue.text = str(int(stats.get("total_normal_waves_completed", 0)))
		if has_node("CenterContainer/StatsPanel/StatsMenu/StatsContainer/extraHardWavesValue"):
			$CenterContainer/StatsPanel/StatsMenu/StatsContainer/extraHardWavesValue.text = str(int(stats.get("total_extra_hard_waves_completed", 0)))

func _on_achievements_pressed() -> void:
	"""Show the achievements menu"""
	$CenterContainer/ProfilePanel.visible = false
	$CenterContainer/AchievementsPanel.visible = true
	_populate_achievements_menu()
	$CenterContainer/AchievementsPanel/AchievementsMenu/back.grab_focus()

func _populate_achievements_menu():
	"""Populate the achievements menu with actual achievements and progress"""
	var achievements_list = $CenterContainer/AchievementsPanel/AchievementsMenu/ScrollContainer/achievementsList
	
	# Clear existing children
	for child in achievements_list.get_children():
		child.queue_free()
	
	var achievement_manager = get_node("/root/AchievementManager")
	if not achievement_manager:
		var error_label = Label.new()
		error_label.text = "Achievement Manager not found!"
		error_label.add_theme_color_override("font_color", Color.RED)
		achievements_list.add_child(error_label)
		return
	
	# Create achievement entries
	for achievement_id in achievement_manager.achievement_definitions:
		var achievement_data = achievement_manager.achievement_definitions[achievement_id]
		var is_unlocked = achievement_manager.is_achievement_unlocked(achievement_id)
		
		# Create container for this achievement
		var achievement_container = _create_achievement_entry(achievement_id, achievement_data, is_unlocked, achievement_manager)
		achievements_list.add_child(achievement_container)

func _create_achievement_entry(achievement_id: String, achievement_data: Dictionary, is_unlocked: bool, achievement_manager) -> Control:
	"""Create a UI entry for a single achievement"""
	var container = PanelContainer.new()
	container.custom_minimum_size = Vector2(600, 100)
	
	# Style the container based on unlock status
	var style_box = StyleBoxFlat.new()
	if is_unlocked:
		style_box.bg_color = Color(0.2, 0.4, 0.2, 0.8)  # Green tint for unlocked
		style_box.border_color = Color(0.4, 0.8, 0.4, 1.0)
	else:
		style_box.bg_color = Color(0.2, 0.2, 0.2, 0.8)  # Gray for locked
		style_box.border_color = Color(0.4, 0.4, 0.4, 1.0)
	
	style_box.border_width_left = 2
	style_box.border_width_right = 2
	style_box.border_width_top = 2
	style_box.border_width_bottom = 2
	style_box.corner_radius_top_left = 8
	style_box.corner_radius_top_right = 8
	style_box.corner_radius_bottom_left = 8
	style_box.corner_radius_bottom_right = 8
	
	container.add_theme_stylebox_override("panel", style_box)
	
	# Main horizontal box
	var hbox = HBoxContainer.new()
	container.add_child(hbox)
	
	# Left side - Achievement info
	var left_vbox = VBoxContainer.new()
	left_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(left_vbox)
	
	# Achievement name
	var name_label = Label.new()
	name_label.text = achievement_data.name
	name_label.add_theme_font_size_override("font_size", 18)
	if is_unlocked:
		name_label.add_theme_color_override("font_color", Color(0.8, 1.0, 0.8, 1.0))
	else:
		name_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7, 1.0))
	left_vbox.add_child(name_label)
	
	# Achievement description
	var desc_label = Label.new()
	desc_label.text = achievement_data.description
	desc_label.add_theme_font_size_override("font_size", 14)
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if is_unlocked:
		desc_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9, 1.0))
	else:
		desc_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6, 1.0))
	left_vbox.add_child(desc_label)
	
	# Progress tracking
	var progress_info = _get_achievement_progress(achievement_id, achievement_manager)
	if progress_info != "":
		var progress_label = Label.new()
		progress_label.text = progress_info
		progress_label.add_theme_font_size_override("font_size", 12)
		progress_label.add_theme_color_override("font_color", Color(0.8, 0.8, 1.0, 1.0))
		left_vbox.add_child(progress_label)
	
	# Right side - Status and reward
	var right_vbox = VBoxContainer.new()
	right_vbox.custom_minimum_size = Vector2(150, 0)
	hbox.add_child(right_vbox)
	
	# Status
	var status_label = Label.new()
	if is_unlocked:
		status_label.text = "✓ UNLOCKED"
		status_label.add_theme_color_override("font_color", Color(0.4, 1.0, 0.4, 1.0))
	else:
		status_label.text = "LOCKED"
		status_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8, 1.0))
	status_label.add_theme_font_size_override("font_size", 12)
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	right_vbox.add_child(status_label)
	
	# Reward info
	var reward_label = Label.new()
	var skin_id = achievement_data.get("unlocks_skin", -1)
	if skin_id > 0:
		var house_skin_manager = get_node("/root/HouseSkinManager")
		if house_skin_manager:
			var skin_name = house_skin_manager.get_skin_name(skin_id)
			reward_label.text = "Unlocks:\n" + skin_name
		else:
			reward_label.text = "Unlocks:\nHouse Skin " + str(skin_id)
	else:
		reward_label.text = "No reward"
	
	reward_label.add_theme_font_size_override("font_size", 10)
	reward_label.add_theme_color_override("font_color", Color(1.0, 0.8, 0.4, 1.0))
	reward_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	reward_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	right_vbox.add_child(reward_label)
	
	return container

func _get_achievement_progress(achievement_id: String, achievement_manager) -> String:
	"""Get progress information for an achievement"""
	match achievement_id:
		"first_victory":
			var modes_completed = achievement_manager.get_game_modes_completed().size()
			return "Game modes completed: %d/1" % modes_completed
		
		"wave_master":
			var waves = achievement_manager.get_highest_wave_survived()
			return "Highest wave: %d/50" % waves
		
		"survivalist":
			var waves = achievement_manager.get_highest_wave_survived()
			return "Highest wave: %d/100" % waves
		
		"wave_crusher":
			var waves = achievement_manager.get_highest_wave_survived()
			return "Highest wave: %d/200" % waves
		
		"endurance_champion":
			var waves = achievement_manager.get_highest_wave_survived()
			return "Highest wave: %d/500" % waves
		
		"apocalypse_survivor":
			var waves = achievement_manager.get_highest_wave_survived()
			return "Highest wave: %d/1000" % waves
		
		"tower_enthusiast":
			var towers = achievement_manager.get_total_towers_built()
			return "Towers built: %d/100" % towers
		
		"building_tycoon":
			var towers = achievement_manager.get_total_towers_built()
			return "Towers built: %d/500" % towers
		
		"enemy_slayer":
			var enemies = achievement_manager.get_total_enemies_defeated()
			return "Enemies defeated: %d/1000" % enemies
		
		"mass_destroyer":
			var enemies = achievement_manager.get_total_enemies_defeated()
			return "Enemies defeated: %d/5000" % enemies
		
		"legendary_commander":
			var enemies = achievement_manager.get_total_enemies_defeated()
			return "Enemies defeated: %d/10000" % enemies
		
		"perfectionist":
			var perfect = achievement_manager.get_levels_completed_perfect()
			return "Perfect completions: %d/1" % perfect
		
		"strategic_genius":
			var completed_extra_hard = "Extra Hard" in achievement_manager.get_game_modes_completed()
			return "Extra Hard completed: %s" % ("Yes" if completed_extra_hard else "No")
		
		"treasure_hunter":
			var gold = achievement_manager.get_total_gold_earned()
			return "Total gold earned: %d/50000" % gold
		
		"economist", "gold_hoarder":
			# These require tracking current game gold, which isn't implemented yet
			return "Progress tracking not available"
		
		"speed_runner", "tower_master", "ultimate_defender":
			# These require additional tracking not yet implemented
			return "Progress tracking not available"
		
		_:
			return ""

func _on_house_skins_pressed() -> void:
	"""Show the house skins menu"""
	$CenterContainer/ProfilePanel.visible = false
	$CenterContainer/HouseSkinsPanel.visible = true
	_populate_house_skins_menu()
	$CenterContainer/HouseSkinsPanel/HouseSkinsMenu/back.grab_focus()

func _populate_house_skins_menu():
	"""Populate the house skins menu"""
	_update_current_skin_display()
	_populate_skin_grid()

func _on_credits_pressed() -> void:
	$CenterContainer/CreditsPanel.visible = true
	$CenterContainer/MainMenuPanel.visible = false
	$CenterContainer/CreditsPanel/CreditsMenu/back.grab_focus()


func _on_quit_pressed() -> void:
	get_tree().quit() 


func _on_back_pressed() -> void:
	# Handle sub-menu navigation
	if $CenterContainer/StatsPanel.visible:
		$CenterContainer/StatsPanel.visible = false
		$CenterContainer/ProfilePanel.visible = true
		$CenterContainer/ProfilePanel/ProfileMenu/MenuButtons/viewStatsButton.grab_focus()
		return
	
	if $CenterContainer/AchievementsPanel.visible:
		$CenterContainer/AchievementsPanel.visible = false
		$CenterContainer/ProfilePanel.visible = true
		$CenterContainer/ProfilePanel/ProfileMenu/MenuButtons/achievementsButton.grab_focus()
		return
	
	if $CenterContainer/HouseSkinsPanel.visible:
		$CenterContainer/HouseSkinsPanel.visible = false
		$CenterContainer/ProfilePanel.visible = true
		$CenterContainer/ProfilePanel/ProfileMenu/MenuButtons/houseSkinsButton.grab_focus()
		return
	
	# Handle main menu navigation
	$CenterContainer/MainMenuPanel.visible = true
	if $CenterContainer/LoadPanel.visible:
		$CenterContainer/LoadPanel.visible = false
		$CenterContainer/MainMenuPanel/MainButtons/loadGame.grab_focus()
	
	if $CenterContainer/CreditsPanel.visible:
		$CenterContainer/CreditsPanel.visible = false
		$CenterContainer/MainMenuPanel/MainButtons/credits.grab_focus()
		
	if $CenterContainer/SettingsPanel.visible:
		$CenterContainer/SettingsPanel.visible = false
		$CenterContainer/MainMenuPanel/MainButtons/settings.grab_focus()
		
	if $CenterContainer/ProfilePanel.visible:
		$CenterContainer/ProfilePanel.visible = false
		$CenterContainer/MainMenuPanel/MainButtons/profile.grab_focus()
		
	if $CenterContainer/GameModePanel.visible:
		$CenterContainer/GameModePanel.visible = false
		$CenterContainer/MainMenuPanel/MainButtons/newGame.grab_focus()


# Preload game mode resources to avoid loading issues
const ENDLESS_MODE = preload("res://assets/gameMode/endlessMode.tres")
const NORMAL_MODE = preload("res://assets/gameMode/normalMode.tres")
const EXTRA_HARD_MODE = preload("res://assets/gameMode/extraHardMode.tres")

# Game mode selection functions
func _on_endless_pressed() -> void:
	selected_game_mode = ENDLESS_MODE
	start_game()

func _on_normal_pressed() -> void:
	selected_game_mode = NORMAL_MODE
	start_game()

func _on_extra_hard_pressed() -> void:
	selected_game_mode = EXTRA_HARD_MODE
	start_game()

func start_game() -> void:
	# Store the selected game mode in the singleton
	var game_mode_manager = get_node("/root/GameModeManager")
	if game_mode_manager:
		game_mode_manager.current_mode = selected_game_mode
	get_tree().change_scene_to_file("res://scenes/main.tscn")


func _on_fullscreen_toggled(toggled_on: bool) -> void:
	if toggled_on:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MAXIMIZED)


func _on_main_vol_slider_value_changed(value: float) -> void:
	AudioServer.set_bus_volume_linear(AudioServer.get_bus_index("Master"), value)

func _on_music_vol_slider_value_changed(value: float) -> void:
	AudioServer.set_bus_volume_linear(AudioServer.get_bus_index("MUSIC"), value)

func _on_sfx_vol_slider_value_changed(value: float) -> void:
	AudioServer.set_bus_volume_linear(AudioServer.get_bus_index("SFX"), value)

# House Skins Management Functions

func _populate_skin_grid():
	"""Populate the skin grid with all available skins"""
	# Clear existing children
	for child in skin_grid.get_children():
		child.queue_free()
	
	# Get manager references
	var house_skin_manager = get_node("/root/HouseSkinManager")
	var achievement_manager = get_node("/root/AchievementManager")
	
	if not house_skin_manager or not achievement_manager:
		return
	
	# Add skin buttons for all 20 skins
	for skin_id in range(1, 21):
		# Create a container for the button with background
		var button_container = Control.new()
		button_container.custom_minimum_size = Vector2(150, 190)  # Slightly taller to accommodate longer text
		
		# Create text label above the house image
		var text_label = Label.new()
		text_label.anchor_left = 0.0
		text_label.anchor_right = 1.0
		text_label.anchor_top = 0.0
		text_label.anchor_bottom = 0.0
		text_label.offset_bottom = 35  # Increased height for text area (was 25)
		text_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		text_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		text_label.add_theme_font_size_override("font_size", 11)
		text_label.add_theme_color_override("font_outline_color", Color.BLACK)
		text_label.add_theme_constant_override("outline_size", 2)
		button_container.add_child(text_label)
		
		# Create the actual button with house background
		var skin_button = Button.new()
		skin_button.anchor_left = 0.0
		skin_button.anchor_right = 1.0
		skin_button.anchor_top = 0.0
		skin_button.anchor_bottom = 1.0
		skin_button.offset_top = 35  # Start below the text label (was 25)
		skin_button.custom_minimum_size = Vector2(150, 155)  # House image area
		
		# Create background TextureRect for house image
		var house_texture = get_house_texture_for_skin(skin_id)
		if house_texture:
			var texture_rect = TextureRect.new()
			texture_rect.texture = house_texture
			texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			texture_rect.anchor_right = 1.0
			texture_rect.anchor_bottom = 1.0
			texture_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE  # Let clicks pass through
			skin_button.add_child(texture_rect)
		
		# Get skin info
		var skin_name = house_skin_manager.get_skin_name(skin_id)
		var is_unlocked = achievement_manager.is_skin_unlocked(skin_id)
		var is_selected = house_skin_manager.get_selected_skin() == skin_id
		
		# Set different opacity for locked vs unlocked house images
		if house_texture:
			var texture_rect = skin_button.get_child(0) as TextureRect
			if is_unlocked:
				texture_rect.modulate = Color(1, 1, 1, 0.6)  # Much more visible for unlocked
			else:
				texture_rect.modulate = Color(1, 1, 1, 0.2)  # Faded for locked
		
		# Style the button to look like a proper button
		var button_style = StyleBoxFlat.new()
		button_style.bg_color = Color(0.2, 0.2, 0.2, 0.8)  # Dark semi-transparent background
		button_style.set_corner_radius_all(8)
		button_style.set_border_width_all(2)
		button_style.border_color = Color(0.4, 0.4, 0.4, 1.0)  # Gray border
		skin_button.add_theme_stylebox_override("normal", button_style)
		
		# Different button styles for different states
		var hover_style = button_style.duplicate()
		hover_style.bg_color = Color(0.3, 0.3, 0.3, 0.8)  # Lighter on hover
		hover_style.border_color = Color(0.6, 0.6, 0.6, 1.0)
		skin_button.add_theme_stylebox_override("hover", hover_style)
		
		if is_unlocked:
			# Set text for unlocked skins
			text_label.text = skin_name
			text_label.add_theme_color_override("font_color", Color.WHITE)
			skin_button.disabled = false
			
			# Highlight selected skin
			if is_selected:
				# Green styling for selected skin
				var selected_style = button_style.duplicate()
				selected_style.border_color = Color.GREEN
				selected_style.set_border_width_all(3)
				selected_style.bg_color = Color(0.1, 0.3, 0.1, 0.8)  # Green tint
				skin_button.add_theme_stylebox_override("normal", selected_style)
				text_label.add_theme_color_override("font_color", Color.GREEN)
				
			# Connect to selection function
			skin_button.pressed.connect(_on_skin_selected.bind(skin_id))
		else:
			# Set text for locked skins
			text_label.text = "LOCKED\n" + skin_name
			text_label.add_theme_color_override("font_color", Color.GRAY)
			skin_button.disabled = true
			
			# Darker styling for locked skins
			var locked_style = button_style.duplicate()
			locked_style.bg_color = Color(0.1, 0.1, 0.1, 0.8)  # Darker background
			locked_style.border_color = Color(0.3, 0.3, 0.3, 1.0)  # Darker border
			skin_button.add_theme_stylebox_override("normal", locked_style)
			skin_button.add_theme_stylebox_override("disabled", locked_style)
		
		# Create a tooltip with skin description
		skin_button.tooltip_text = house_skin_manager.get_skin_description(skin_id)
		
		# Add button to container, then container to grid
		button_container.add_child(skin_button)
		skin_grid.add_child(button_container)

func _on_skin_selected(skin_id: int):
	"""Handle skin selection"""
	var house_skin_manager = get_node("/root/HouseSkinManager")
	if house_skin_manager:
		house_skin_manager.set_selected_skin(skin_id)
	_update_current_skin_display()
	_populate_skin_grid()  # Refresh to update highlighting

func _on_skin_changed(_new_skin_id: int):
	"""Handle when skin is changed from elsewhere"""
	_update_current_skin_display()

func _on_profile_loaded(profile_name: String):
	"""Handle profile loaded - refresh all UI that depends on profile data"""
	print("Profile loaded in main menu: ", profile_name)
	update_profile_display()
	_update_current_skin_display()
	
	# Refresh menus if they're currently visible
	if $CenterContainer/HouseSkinsPanel.visible:
		_populate_house_skins_menu()
	if $CenterContainer/AchievementsPanel.visible:
		_populate_achievements_menu()

func _update_current_skin_display():
	"""Update the current skin display label"""
	var house_skin_manager = get_node("/root/HouseSkinManager")
	if house_skin_manager:
		var current_skin = house_skin_manager.get_selected_skin()
		var skin_name = house_skin_manager.get_skin_name(current_skin)
		current_skin_label.text = "Current: " + skin_name

func get_house_texture_for_skin(skin_id: int) -> Texture2D:
	"""Get the house texture for a specific skin from the sprite sheet"""
	# Load the house sprite sheet
	var sprite_sheet_path = "res://assets/house/Houses Sprite Sheet.png"
	if not ResourceLoader.exists(sprite_sheet_path):
		return null
	
	var sprite_sheet = load(sprite_sheet_path) as Texture2D
	if not sprite_sheet:
		return null
	
	# Create AtlasTexture for the specific skin
	# Each house skin has its own row (20 rows total)
	# We want the first frame (first column) of each row
	# Each frame is 150x151 pixels
	var atlas_texture = AtlasTexture.new()
	atlas_texture.atlas = sprite_sheet
	
	# Calculate position in sprite sheet
	# skin1 = row 0, skin2 = row 1, etc.
	# Always use column 0 (first frame of each animation)
	var row = skin_id - 1  # skin1 is row 0, skin2 is row 1, etc.
	var col = 0  # Always use first frame
	
	var x = col * 150  # Will always be 0 since col = 0
	var y = row * 151  # Each row is 151 pixels high
	
	atlas_texture.region = Rect2(x, y, 150, 151)
	
	return atlas_texture
