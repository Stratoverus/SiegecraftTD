extends Node2D

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
	$CenterContainer/MainButtons/newGame.grab_focus()
	$CenterContainer/SettingsMenu/fullscreen.button_pressed = true if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN else false
	$CenterContainer/SettingsMenu/mainVolSlider.value = db_to_linear(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Master")))
	$CenterContainer/SettingsMenu/musicVolSlider.value = db_to_linear(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("MUSIC")))
	$CenterContainer/SettingsMenu/sfxVolSlider.value = db_to_linear(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("SFX")))
	
	# Get references to UI elements
	skin_grid = $CenterContainer/HouseSkinsMenu/ScrollContainer/skinGrid
	current_skin_label = $CenterContainer/HouseSkinsMenu/currentSkinLabel
	profile_name_label = $ProfileDisplay/profileNameLabel
	
	# Configure the skin grid for better spacing
	skin_grid.columns = 4  # 4 columns to spread out the 20 skins nicely
	skin_grid.add_theme_constant_override("h_separation", 20)  # Horizontal spacing
	skin_grid.add_theme_constant_override("v_separation", 15)  # Vertical spacing
	
	# Configure the scroll container to reduce excessive spacing
	var scroll_container = $CenterContainer/HouseSkinsMenu/ScrollContainer
	scroll_container.custom_minimum_size = Vector2(650, 400)  # Reduce width to minimize gap
	scroll_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll_container.size_flags_horizontal = Control.SIZE_SHRINK_CENTER  # Center and shrink to content
	scroll_container.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED  # Disable horizontal scrollbar
	
	# Connect to skin change signal
	var house_skin_manager = get_node("/root/HouseSkinManager")
	if house_skin_manager:
		house_skin_manager.skin_changed.connect(_on_skin_changed)
	
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
		
		# Delete button (only if not current and more than 1 profile)
		if profile_name != current_profile_name and all_profiles.size() > 1:
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
		# Show the main dialog again if deletion failed
		main_dialog.show()
		confirm_dialog.queue_free()

func _delete_profile_canceled(main_dialog: AcceptDialog, confirm_dialog: ConfirmationDialog):
	"""Handle profile deletion cancel"""
	# Show the main dialog again
	main_dialog.show()
	confirm_dialog.queue_free()

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
	$CenterContainer/MainButtons.visible = false
	$CenterContainer/GameModeMenu.visible = true
	$CenterContainer/GameModeMenu/normal.grab_focus() 


func _on_load_game_pressed() -> void:
	$CenterContainer/MainButtons.visible = false
	$CenterContainer/LoadMenu.visible = true
	_populate_continue_button()
	$CenterContainer/LoadMenu/back.grab_focus()


func _populate_continue_button():
	"""Populate the continue button with checkpoint save info"""
	var save_manager = get_node("/root/SaveManager")
	if not save_manager:
		return
	
	# Get reference to the continue button
	var checkpoint_button = $CenterContainer/LoadMenu/loadCheckpoint
	
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
	$CenterContainer/SettingsMenu.visible = true
	$CenterContainer/MainButtons.visible = false
	$CenterContainer/SettingsMenu/back.grab_focus()

func _on_profile_pressed() -> void:
	$CenterContainer/ProfileMenu.visible = true
	$CenterContainer/MainButtons.visible = false
	_populate_profile_menu()
	$CenterContainer/ProfileMenu/MenuButtons/viewStatsButton.grab_focus()

func _populate_profile_menu():
	"""Populate the profile menu with profile name"""
	var profile_manager = get_node("/root/ProfileManager")
	if profile_manager and profile_manager.has_profile():
		# Update profile name
		$CenterContainer/ProfileMenu/profileNameLabel.text = "Profile: " + profile_manager.profile_name

func _on_view_stats_pressed() -> void:
	"""Show the statistics menu"""
	$CenterContainer/ProfileMenu.visible = false
	$CenterContainer/StatsMenu.visible = true
	_populate_stats_menu()
	$CenterContainer/StatsMenu/back.grab_focus()

func _populate_stats_menu():
	"""Populate the statistics menu with profile stats"""
	var profile_manager = get_node("/root/ProfileManager")
	if profile_manager and profile_manager.has_profile():
		var profile_data = profile_manager.get_profile_data()
		var stats = profile_data.get("stats", {})
		
		# Update stat labels
		$CenterContainer/StatsMenu/StatsContainer/gamesPlayedValue.text = str(int(stats.get("games_played", 0)))
		$CenterContainer/StatsMenu/StatsContainer/timesWonValue.text = str(int(stats.get("times_won", 0)))
		$CenterContainer/StatsMenu/StatsContainer/timesLostValue.text = str(int(stats.get("times_lost", 0)))
		$CenterContainer/StatsMenu/StatsContainer/wavesValue.text = str(int(stats.get("total_waves_survived", 0)))
		$CenterContainer/StatsMenu/StatsContainer/enemiesValue.text = str(int(stats.get("total_enemies_defeated", 0)))
		$CenterContainer/StatsMenu/StatsContainer/towersValue.text = str(int(stats.get("total_towers_built", 0)))
		$CenterContainer/StatsMenu/StatsContainer/highestWaveValue.text = str(int(stats.get("highest_wave_reached", 0)))
		$CenterContainer/StatsMenu/StatsContainer/goldEarnedValue.text = str(int(stats.get("total_gold_earned", 0)))
		$CenterContainer/StatsMenu/StatsContainer/playTimeValue.text = profile_manager.get_formatted_play_time()

func _on_achievements_pressed() -> void:
	"""Show the achievements menu"""
	$CenterContainer/ProfileMenu.visible = false
	$CenterContainer/AchievementsMenu.visible = true
	_populate_achievements_menu()
	$CenterContainer/AchievementsMenu/back.grab_focus()

func _populate_achievements_menu():
	"""Populate the achievements menu"""
	# TODO: Populate with actual achievements
	var achievements_list = $CenterContainer/AchievementsMenu/ScrollContainer/achievementsList
	
	# Clear existing children
	for child in achievements_list.get_children():
		child.queue_free()
	
	# Add placeholder text for now
	var label = Label.new()
	label.text = "Achievements system integration coming soon!"
	label.add_theme_font_size_override("font_size", 24)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	achievements_list.add_child(label)

func _on_house_skins_pressed() -> void:
	"""Show the house skins menu"""
	$CenterContainer/ProfileMenu.visible = false
	$CenterContainer/HouseSkinsMenu.visible = true
	_populate_house_skins_menu()
	$CenterContainer/HouseSkinsMenu/back.grab_focus()

func _populate_house_skins_menu():
	"""Populate the house skins menu"""
	_update_current_skin_display()
	_populate_skin_grid()

func _on_credits_pressed() -> void:
	$CenterContainer/CreditsMenu.visible = true
	$CenterContainer/MainButtons.visible = false
	$CenterContainer/CreditsMenu/back.grab_focus()


func _on_quit_pressed() -> void:
	get_tree().quit() 


func _on_back_pressed() -> void:
	# Handle sub-menu navigation
	if $CenterContainer/StatsMenu.visible:
		$CenterContainer/StatsMenu.visible = false
		$CenterContainer/ProfileMenu.visible = true
		$CenterContainer/ProfileMenu/MenuButtons/viewStatsButton.grab_focus()
		return
	
	if $CenterContainer/AchievementsMenu.visible:
		$CenterContainer/AchievementsMenu.visible = false
		$CenterContainer/ProfileMenu.visible = true
		$CenterContainer/ProfileMenu/MenuButtons/achievementsButton.grab_focus()
		return
	
	if $CenterContainer/HouseSkinsMenu.visible:
		$CenterContainer/HouseSkinsMenu.visible = false
		$CenterContainer/ProfileMenu.visible = true
		$CenterContainer/ProfileMenu/MenuButtons/houseSkinsButton.grab_focus()
		return
	
	# Handle main menu navigation
	$CenterContainer/MainButtons.visible = true
	if $CenterContainer/LoadMenu.visible:
		$CenterContainer/LoadMenu.visible = false
		$CenterContainer/MainButtons/loadGame.grab_focus()
	
	if $CenterContainer/CreditsMenu.visible:
		$CenterContainer/CreditsMenu.visible = false
		$CenterContainer/MainButtons/credits.grab_focus()
		
	if $CenterContainer/SettingsMenu.visible:
		$CenterContainer/SettingsMenu.visible = false
		$CenterContainer/MainButtons/settings.grab_focus()
		
	if $CenterContainer/ProfileMenu.visible:
		$CenterContainer/ProfileMenu.visible = false
		$CenterContainer/MainButtons/profile.grab_focus()
		
	if $CenterContainer/GameModeMenu.visible:
		$CenterContainer/GameModeMenu.visible = false
		$CenterContainer/MainButtons/newGame.grab_focus()


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
