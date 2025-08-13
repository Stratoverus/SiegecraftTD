extends Control

# References to UI elements
@onready var skin_grid: GridContainer
@onready var current_skin_label: Label
@onready var profile_name_label: Label

# Game mode constants
const ENDLESS_MODE = preload("res://assets/gameMode/endlessMode.tres")
const NORMAL_MODE = preload("res://assets/gameMode/normalMode.tres")
const EXTRA_HARD_MODE = preload("res://assets/gameMode/extraHardMode.tres")

# Game mode data
var selected_game_mode: Resource = null

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
	
	# Try AAA Fantasy layout first
	if has_node("MainInterface/SettingsPanel/SettingsLayout/SettingsScroll/SettingsGrid/fullscreen"):
		fullscreen_node = $MainInterface/SettingsPanel/SettingsLayout/SettingsScroll/SettingsGrid/fullscreen
		main_vol_node = $MainInterface/SettingsPanel/SettingsLayout/SettingsScroll/SettingsGrid/MasterVolumeContainer/mainVolSlider
		music_vol_node = $MainInterface/SettingsPanel/SettingsLayout/SettingsScroll/SettingsGrid/MusicVolumeContainer/musicVolSlider
		sfx_vol_node = $MainInterface/SettingsPanel/SettingsLayout/SettingsScroll/SettingsGrid/SFXVolumeContainer/sfxVolSlider
		profile_name_label = $HeroProfileCard/ProfileLayout/profileNameLabel
	# Try Elden Ring layout
	elif has_node("CentralLayout/SettingsPanel/SettingsContent/SettingsScrollContainer/SettingsGrid/fullscreen"):
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
	# Try AAA Fantasy layout first
	if has_node("MainInterface/PrimaryMenuPanel/MenuLayout/PrimaryActions/newGame"):
		$MainInterface/PrimaryMenuPanel/MenuLayout/PrimaryActions/newGame.grab_focus()
	# Try Elden Ring layout
	elif has_node("CentralLayout/MainMenuPanel/MenuContent/PrimaryActions/newGame"):
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
		if has_node("HeroProfileCard/ProfileLayout/ProfileRank"):
			$HeroProfileCard/ProfileLayout/ProfileRank.text = rank_title
			$HeroProfileCard.visible = true
		elif has_node("ProfileHeraldry/ProfileFrame/ProfileRank"):
			$ProfileHeraldry/ProfileFrame/ProfileRank.text = rank_title
			$ProfileHeraldry.visible = true
		elif has_node("ProfilePanel/ProfileContent/ProfileRank"):
			$ProfilePanel/ProfileContent/ProfileRank.text = rank_title
			$ProfilePanel.visible = true
		elif has_node("ProfileHeraldry/ProfileContainer/ProfileRank"):
			$ProfileHeraldry/ProfileContainer/ProfileRank.text = rank_title
			$ProfileHeraldry.visible = true
		
		# Update real stats in the profile card
		update_profile_stats()
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
		
		# Set default stats for no profile
		if has_node("HeroProfileCard/ProfileLayout/StatsContainer/PowerLevel"):
			$HeroProfileCard/ProfileLayout/StatsContainer/PowerLevel.text = "🏆 Best Wave: 0"
		if has_node("HeroProfileCard/ProfileLayout/StatsContainer/Experience"):
			$HeroProfileCard/ProfileLayout/StatsContainer/Experience.text = "💀 Kills: 0"

func update_profile_stats():
	"""Update the profile stats display with real data from ProfileManager"""
	if not profile_manager or not profile_manager.has_profile():
		return
	
	var profile_data = profile_manager.get_profile_data()
	var stats = profile_data.get("stats", {})
	
	# Get the real stats
	var highest_wave = stats.get("highest_wave_reached", 0)
	var total_enemies_defeated = stats.get("total_enemies_defeated", 0)
	
	# Update the stat labels if they exist
	if has_node("HeroProfileCard/ProfileLayout/StatsContainer/PowerLevel"):
		$HeroProfileCard/ProfileLayout/StatsContainer/PowerLevel.text = "🏆 Best Wave: %d" % highest_wave
	
	if has_node("HeroProfileCard/ProfileLayout/StatsContainer/Experience"):
		# Format large numbers with commas
		var kills_text = format_number_with_commas(total_enemies_defeated)
		$HeroProfileCard/ProfileLayout/StatsContainer/Experience.text = "💀 Kills: %s" % kills_text

func format_number_with_commas(number: int) -> String:
	"""Format a number with comma separators for readability"""
	var num_str = str(number)
	var result = ""
	var count = 0
	
	# Add commas from right to left
	for i in range(num_str.length() - 1, -1, -1):
		if count > 0 and count % 3 == 0:
			result = "," + result
		result = num_str[i] + result
		count += 1
	
	return result

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
	show_game_mode_selection()

func _on_load_game_pressed() -> void:
	show_load_game_menu()

func _on_settings_pressed() -> void:
	show_settings_menu()

func _on_profile_pressed() -> void:
	# Show a simple submenu with Progress options
	show_progress_submenu()

func show_progress_submenu():
	"""Show a submenu with progress options: Statistics, Achievements, House Skins"""
	var dialog = AcceptDialog.new()
	dialog.title = ""  # Hide the default title since we'll create our own
	dialog.borderless = true
	dialog.unresizable = true
	dialog.size = Vector2(600, 450)  # Much larger size
	
	# Custom title bar with fantasy styling and close button
	var title_container = PanelContainer.new()
	var title_style = StyleBoxFlat.new()
	title_style.bg_color = Color(0.25, 0.18, 0.1, 1.0)  # Darker brown for title bar
	title_style.border_color = Color(0.6, 0.4, 0.2, 1.0)
	title_style.set_border_width_all(2)
	title_style.corner_radius_top_left = 10
	title_style.corner_radius_top_right = 10
	title_container.add_theme_stylebox_override("panel", title_style)
	
	var title_hbox = HBoxContainer.new()
	title_hbox.custom_minimum_size = Vector2(0, 50)  # Taller title bar
	var title_label = Label.new()
	title_label.text = "📊 Progress & Unlocks"
	title_label.add_theme_color_override("font_color", Color(0.9, 0.8, 0.7, 1.0))
	title_label.add_theme_font_size_override("font_size", 24)  # Larger font
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_hbox.add_child(title_label)
	
	var close_button = Button.new()
	close_button.text = "✕"
	close_button.flat = true
	close_button.custom_minimum_size = Vector2(40, 40)
	close_button.add_theme_color_override("font_color", Color(0.9, 0.8, 0.7, 1.0))
	close_button.add_theme_font_size_override("font_size", 20)
	close_button.pressed.connect(dialog.hide)
	title_hbox.add_child(close_button)
	
	title_container.add_child(title_hbox)
	
	# Main content area
	var main_container = PanelContainer.new()
	var main_style = StyleBoxFlat.new()
	main_style.bg_color = Color(0.15, 0.1, 0.06, 1.0)
	main_style.border_color = Color(0.6, 0.4, 0.2, 1.0)
	main_style.set_border_width_all(2)
	main_style.corner_radius_bottom_left = 10
	main_style.corner_radius_bottom_right = 10
	main_container.add_theme_stylebox_override("panel", main_style)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 25)  # More spacing
	
	# Add more spacing at top
	var spacer1 = Control.new()
	spacer1.custom_minimum_size = Vector2(0, 30)
	vbox.add_child(spacer1)
	
	# Statistics button
	var stats_btn = Button.new()
	stats_btn.text = "📈 View Statistics"
	stats_btn.custom_minimum_size = Vector2(500, 70)  # Larger buttons
	_style_fantasy_button(stats_btn)
	stats_btn.pressed.connect(_show_stats_menu.bind(dialog))
	vbox.add_child(stats_btn)
	
	# Achievements button
	var achievements_btn = Button.new()
	achievements_btn.text = "🏆 View Achievements"
	achievements_btn.custom_minimum_size = Vector2(500, 70)
	_style_fantasy_button(achievements_btn)
	achievements_btn.pressed.connect(_show_achievements_menu.bind(dialog))
	vbox.add_child(achievements_btn)
	
	# House Skins button
	var skins_btn = Button.new()
	skins_btn.text = "🏠 House Skins"
	skins_btn.custom_minimum_size = Vector2(500, 70)
	_style_fantasy_button(skins_btn)
	skins_btn.pressed.connect(_show_house_skins_menu.bind(dialog))
	vbox.add_child(skins_btn)
	
	# Add more spacing at bottom
	var spacer2 = Control.new()
	spacer2.custom_minimum_size = Vector2(0, 30)
	vbox.add_child(spacer2)
	
	main_container.add_child(vbox)
	
	# Add containers to dialog
	var dialog_vbox = VBoxContainer.new()
	dialog_vbox.add_child(title_container)
	dialog_vbox.add_child(main_container)
	
	dialog.add_child(dialog_vbox)
	add_child(dialog)
	dialog.popup_centered()
	
	# Focus the first button
	stats_btn.grab_focus()

func _style_fantasy_button(button: Button):
	"""Apply fantasy styling to a button"""
	var btn_style_normal = StyleBoxFlat.new()
	btn_style_normal.bg_color = Color(0.2, 0.15, 0.1, 1.0)
	btn_style_normal.border_color = Color(0.6, 0.4, 0.2, 1.0)
	btn_style_normal.set_border_width_all(2)
	btn_style_normal.corner_radius_top_left = 8
	btn_style_normal.corner_radius_top_right = 8
	btn_style_normal.corner_radius_bottom_left = 8
	btn_style_normal.corner_radius_bottom_right = 8
	
	var btn_style_hover = StyleBoxFlat.new()
	btn_style_hover.bg_color = Color(0.25, 0.2, 0.15, 1.0)
	btn_style_hover.border_color = Color(0.8, 0.6, 0.3, 1.0)
	btn_style_hover.set_border_width_all(2)
	btn_style_hover.corner_radius_top_left = 8
	btn_style_hover.corner_radius_top_right = 8
	btn_style_hover.corner_radius_bottom_left = 8
	btn_style_hover.corner_radius_bottom_right = 8
	
	button.add_theme_stylebox_override("normal", btn_style_normal)
	button.add_theme_stylebox_override("hover", btn_style_hover)
	button.add_theme_stylebox_override("pressed", btn_style_hover)
	button.add_theme_color_override("font_color", Color(0.9, 0.8, 0.7, 1.0))
	button.add_theme_font_size_override("font_size", 20)

func _show_stats_menu(parent_dialog: AcceptDialog):
	"""Show statistics menu"""
	parent_dialog.hide()
	
	var stats_dialog = AcceptDialog.new()
	stats_dialog.title = "Player Statistics"
	stats_dialog.size = Vector2(700, 500)
	stats_dialog.position = (get_viewport().size - stats_dialog.size) / 2
	
	# Remove default border
	var empty_style = StyleBoxFlat.new()
	empty_style.set_border_width_all(0)
	empty_style.bg_color = Color.TRANSPARENT
	stats_dialog.add_theme_stylebox_override("panel", empty_style)
	
	# Create custom content panel
	var content_panel = Panel.new()
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.1, 0.08, 0.06, 0.95)
	panel_style.border_color = Color(0.6, 0.4, 0.2, 1.0)
	panel_style.set_border_width_all(3)
	panel_style.corner_radius_top_left = 12
	panel_style.corner_radius_top_right = 12
	panel_style.corner_radius_bottom_left = 12
	panel_style.corner_radius_bottom_right = 12
	content_panel.add_theme_stylebox_override("panel", panel_style)
	content_panel.size = stats_dialog.size
	
	# Main container
	var vbox = VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 20)
	content_panel.add_child(vbox)
	
	# Add padding
	var top_spacer = Control.new()
	top_spacer.custom_minimum_size.y = 30
	vbox.add_child(top_spacer)
	
	# Title
	var title = Label.new()
	title.text = "Tower Defense Statistics"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", Color(0.9, 0.8, 0.7, 1.0))
	title.add_theme_font_size_override("font_size", 28)
	vbox.add_child(title)
	
	# Stats content in two columns with better spacing
	var stats_container = HBoxContainer.new()
	stats_container.add_theme_constant_override("separation", 60)
	stats_container.set_anchors_and_offsets_preset(Control.PRESET_HCENTER_WIDE)
	vbox.add_child(stats_container)
	
	# Add left margin spacer
	var left_spacer = Control.new()
	left_spacer.custom_minimum_size.x = 50
	stats_container.add_child(left_spacer)
	
	# Left column
	var left_column = VBoxContainer.new()
	left_column.add_theme_constant_override("separation", 15)
	left_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stats_container.add_child(left_column)
	
	# Right column
	var right_column = VBoxContainer.new()
	right_column.add_theme_constant_override("separation", 15)
	right_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stats_container.add_child(right_column)
	
	# Add right margin spacer
	var right_spacer = Control.new()
	right_spacer.custom_minimum_size.x = 50
	stats_container.add_child(right_spacer)
	
	# Get current profile stats
	var stats = {}
	if ProfileManager.has_profile():
		stats = ProfileManager.current_profile.get("stats", {})
	
	# Left column stats
	_add_stat_label(left_column, "Games Played:", str(stats.get("games_played", 0)))
	_add_stat_label(left_column, "Highest Wave:", str(stats.get("highest_wave_reached", 0)))
	_add_stat_label(left_column, "Total Enemies Defeated:", str(stats.get("total_enemies_defeated", 0)))
	_add_stat_label(left_column, "Towers Built:", str(stats.get("total_towers_built", 0)))
	_add_stat_label(left_column, "Times Won:", str(stats.get("times_won", 0)))
	_add_stat_label(left_column, "Times Lost:", str(stats.get("times_lost", 0)))
	
	# Right column stats
	_add_stat_label(right_column, "Total Gold Earned:", str(stats.get("total_gold_earned", 0)))
	_add_stat_label(right_column, "Normal Waves Completed:", str(stats.get("total_normal_waves_completed", 0)))
	_add_stat_label(right_column, "Extra Hard Waves:", str(stats.get("total_extra_hard_waves_completed", 0)))
	_add_stat_label(right_column, "Perfect Completions:", str(stats.get("levels_completed_perfect", 0)))
	_add_stat_label(right_column, "Total Waves Survived:", str(stats.get("total_waves_survived", 0)))
	
	# Play time
	var play_time_hours = stats.get("total_play_time", 0.0) / 3600.0
	_add_stat_label(right_column, "Play Time:", "%.1f hours" % play_time_hours)
	
	stats_dialog.add_child(content_panel)
	get_tree().current_scene.add_child(stats_dialog)
	stats_dialog.popup_centered()
	
	# When stats dialog closes, show parent dialog again
	stats_dialog.confirmed.connect(func(): parent_dialog.show())

func _add_stat_label(parent: Node, label_text: String, value_text: String):
	"""Helper to add a stat row"""
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 10)
	
	var label = Label.new()
	label.text = label_text
	label.custom_minimum_size.x = 180
	label.add_theme_color_override("font_color", Color(0.8, 0.7, 0.6, 1.0))
	label.add_theme_font_size_override("font_size", 16)
	hbox.add_child(label)
	
	var value = Label.new()
	value.text = value_text
	value.add_theme_color_override("font_color", Color(0.9, 0.8, 0.7, 1.0))
	value.add_theme_font_size_override("font_size", 16)
	hbox.add_child(value)
	
	parent.add_child(hbox)

func _show_achievements_menu(parent_dialog: AcceptDialog):
	"""Show achievements menu"""
	parent_dialog.hide()
	
	var achievements_dialog = AcceptDialog.new()
	achievements_dialog.title = "Achievements"
	achievements_dialog.size = Vector2(800, 600)
	achievements_dialog.position = (get_viewport().size - achievements_dialog.size) / 2
	
	# Remove default border
	var empty_style = StyleBoxFlat.new()
	empty_style.set_border_width_all(0)
	empty_style.bg_color = Color.TRANSPARENT
	achievements_dialog.add_theme_stylebox_override("panel", empty_style)
	
	# Create custom content panel
	var content_panel = Panel.new()
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.1, 0.08, 0.06, 0.95)
	panel_style.border_color = Color(0.6, 0.4, 0.2, 1.0)
	panel_style.set_border_width_all(3)
	panel_style.corner_radius_top_left = 12
	panel_style.corner_radius_top_right = 12
	panel_style.corner_radius_bottom_left = 12
	panel_style.corner_radius_bottom_right = 12
	content_panel.add_theme_stylebox_override("panel", panel_style)
	content_panel.size = achievements_dialog.size
	
	# Main container
	var vbox = VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 20)
	content_panel.add_child(vbox)
	
	# Add padding
	var top_spacer = Control.new()
	top_spacer.custom_minimum_size.y = 30
	vbox.add_child(top_spacer)
	
	# Title
	var title = Label.new()
	title.text = "Achievements"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", Color(0.9, 0.8, 0.7, 1.0))
	title.add_theme_font_size_override("font_size", 28)
	vbox.add_child(title)
	
	# Scrollable achievements list
	var scroll_container = ScrollContainer.new()
	scroll_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(scroll_container)
	
	# Margin container to center the achievements
	var margin_container = MarginContainer.new()
	margin_container.add_theme_constant_override("margin_left", 30)
	margin_container.add_theme_constant_override("margin_right", 30)
	scroll_container.add_child(margin_container)
	
	var achievements_list = VBoxContainer.new()
	achievements_list.add_theme_constant_override("separation", 10)
	margin_container.add_child(achievements_list)
	
	# Get current profile achievements
	var profile_achievements = {}
	if ProfileManager.has_profile():
		profile_achievements = ProfileManager.current_profile.get("achievements", {})
	
	# Add achievement entries using good version style
	for achievement_id in AchievementManager.achievement_definitions:
		var achievement_data = AchievementManager.achievement_definitions[achievement_id]
		var is_unlocked = profile_achievements.get(achievement_id, false)
		
		_add_achievement_entry_good(achievements_list, achievement_id, achievement_data, is_unlocked)
	
	achievements_dialog.add_child(content_panel)
	get_tree().current_scene.add_child(achievements_dialog)
	achievements_dialog.popup_centered()
	
	# When achievements dialog closes, show parent dialog again
	achievements_dialog.confirmed.connect(func(): parent_dialog.show())

func _add_achievement_entry_good(parent: Node, _achievement_id: String, achievement_data: Dictionary, is_unlocked: bool):
	"""Helper to add an achievement entry using the good layout style"""
	var container = PanelContainer.new()
	container.custom_minimum_size = Vector2(740, 100)
	
	# Style the container based on unlock status (using fantasy colors)
	var style_box = StyleBoxFlat.new()
	if is_unlocked:
		style_box.bg_color = Color(0.2, 0.16, 0.12, 0.8)  # Fantasy brown for unlocked
		style_box.border_color = Color(0.8, 0.6, 0.3, 1.0)  # Gold border
	else:
		style_box.bg_color = Color(0.15, 0.12, 0.09, 0.6)  # Darker brown for locked
		style_box.border_color = Color(0.4, 0.3, 0.2, 0.8)  # Darker border
	
	style_box.set_border_width_all(2)
	style_box.corner_radius_top_left = 8
	style_box.corner_radius_top_right = 8
	style_box.corner_radius_bottom_left = 8
	style_box.corner_radius_bottom_right = 8
	
	container.add_theme_stylebox_override("panel", style_box)
	
	# Main horizontal box with padding
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 15)
	
	# Add margin container for padding inside the achievement box
	var padding_container = MarginContainer.new()
	padding_container.add_theme_constant_override("margin_left", 15)
	padding_container.add_theme_constant_override("margin_right", 15)
	padding_container.add_theme_constant_override("margin_top", 10)
	padding_container.add_theme_constant_override("margin_bottom", 10)
	container.add_child(padding_container)
	
	padding_container.add_child(hbox)
	
	# Left side - Achievement info
	var left_vbox = VBoxContainer.new()
	left_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(left_vbox)
	
	# Achievement name
	var name_label = Label.new()
	name_label.text = achievement_data.get("name", "Unknown Achievement")
	name_label.add_theme_font_size_override("font_size", 18)
	if is_unlocked:
		name_label.add_theme_color_override("font_color", Color(0.9, 0.8, 0.7, 1.0))
	else:
		name_label.add_theme_color_override("font_color", Color(0.7, 0.6, 0.5, 1.0))
	left_vbox.add_child(name_label)
	
	# Achievement description
	var desc_label = Label.new()
	desc_label.text = achievement_data.get("description", "No description available")
	desc_label.add_theme_font_size_override("font_size", 14)
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if is_unlocked:
		desc_label.add_theme_color_override("font_color", Color(0.8, 0.7, 0.6, 1.0))
	else:
		desc_label.add_theme_color_override("font_color", Color(0.6, 0.5, 0.4, 1.0))
	left_vbox.add_child(desc_label)
	
	# Progress tracking (like the good version)
	var progress_info = _get_achievement_progress(_achievement_id, AchievementManager)
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
	
	# Reward info - show actual skin name like the good version
	var reward_label = Label.new()
	var skin_id = achievement_data.get("unlocks_skin", 0)
	if skin_id > 0:
		var skin_name = HouseSkinManager.get_skin_name(skin_id)
		reward_label.text = "Unlocks:\n" + skin_name
	else:
		reward_label.text = "No reward"
	
	reward_label.add_theme_font_size_override("font_size", 10)
	reward_label.add_theme_color_override("font_color", Color(1.0, 0.8, 0.4, 1.0))
	reward_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	reward_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	right_vbox.add_child(reward_label)
	
	parent.add_child(container)

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

func _add_achievement_entry(parent: Node, achievement_data: Dictionary, is_unlocked: bool):
	"""Helper to add an achievement entry"""
	var achievement_panel = Panel.new()
	
	# Panel styling based on unlock status
	var achievement_style = StyleBoxFlat.new()
	if is_unlocked:
		achievement_style.bg_color = Color(0.2, 0.16, 0.12, 0.8)
		achievement_style.border_color = Color(0.8, 0.6, 0.3, 1.0)
	else:
		achievement_style.bg_color = Color(0.15, 0.12, 0.09, 0.6)
		achievement_style.border_color = Color(0.4, 0.3, 0.2, 0.8)
	
	achievement_style.set_border_width_all(1)
	achievement_style.corner_radius_top_left = 6
	achievement_style.corner_radius_top_right = 6
	achievement_style.corner_radius_bottom_left = 6
	achievement_style.corner_radius_bottom_right = 6
	achievement_panel.add_theme_stylebox_override("panel", achievement_style)
	achievement_panel.custom_minimum_size.y = 70
	
	# Content container
	var hbox = HBoxContainer.new()
	hbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hbox.add_theme_constant_override("separation", 15)
	achievement_panel.add_child(hbox)
	
	# Status indicator (icon placeholder)
	var status_label = Label.new()
	if is_unlocked:
		status_label.text = "✓"
		status_label.add_theme_color_override("font_color", Color(0.2, 0.8, 0.2, 1.0))
	else:
		status_label.text = "○"
		status_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6, 1.0))
	status_label.add_theme_font_size_override("font_size", 24)
	status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	status_label.custom_minimum_size.x = 40
	hbox.add_child(status_label)
	
	# Achievement details
	var details_vbox = VBoxContainer.new()
	details_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(details_vbox)
	
	# Achievement name
	var name_label = Label.new()
	name_label.text = achievement_data.get("name", "Unknown Achievement")
	if is_unlocked:
		name_label.add_theme_color_override("font_color", Color(0.9, 0.8, 0.7, 1.0))
	else:
		name_label.add_theme_color_override("font_color", Color(0.7, 0.6, 0.5, 1.0))
	name_label.add_theme_font_size_override("font_size", 18)
	details_vbox.add_child(name_label)
	
	# Achievement description
	var desc_label = Label.new()
	desc_label.text = achievement_data.get("description", "No description available")
	if is_unlocked:
		desc_label.add_theme_color_override("font_color", Color(0.8, 0.7, 0.6, 1.0))
	else:
		desc_label.add_theme_color_override("font_color", Color(0.6, 0.5, 0.4, 1.0))
	desc_label.add_theme_font_size_override("font_size", 14)
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	details_vbox.add_child(desc_label)
	
	# Skin unlock info
	var skin_id = achievement_data.get("unlocks_skin", 0)
	if skin_id > 0:
		var skin_label = Label.new()
		skin_label.text = "Unlocks House Skin #%d" % skin_id
		if is_unlocked:
			skin_label.add_theme_color_override("font_color", Color(0.9, 0.7, 0.3, 1.0))
		else:
			skin_label.add_theme_color_override("font_color", Color(0.6, 0.5, 0.2, 1.0))
		skin_label.add_theme_font_size_override("font_size", 12)
		details_vbox.add_child(skin_label)
	
	parent.add_child(achievement_panel)

func _show_house_skins_menu(parent_dialog: AcceptDialog):
	"""Show house skins menu with grid layout"""
	parent_dialog.hide()
	
	var skins_dialog = AcceptDialog.new()
	skins_dialog.title = "House Skins"
	skins_dialog.size = Vector2(800, 600)
	skins_dialog.position = (get_viewport().size - skins_dialog.size) / 2
	
	# Remove default border
	var empty_style = StyleBoxFlat.new()
	empty_style.set_border_width_all(0)
	empty_style.bg_color = Color.TRANSPARENT
	skins_dialog.add_theme_stylebox_override("panel", empty_style)
	
	# Create custom content panel
	var content_panel = Panel.new()
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.1, 0.08, 0.06, 0.95)
	panel_style.border_color = Color(0.6, 0.4, 0.2, 1.0)
	panel_style.set_border_width_all(3)
	panel_style.corner_radius_top_left = 12
	panel_style.corner_radius_top_right = 12
	panel_style.corner_radius_bottom_left = 12
	panel_style.corner_radius_bottom_right = 12
	content_panel.add_theme_stylebox_override("panel", panel_style)
	content_panel.size = skins_dialog.size
	
	# Main container
	var vbox = VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 20)
	content_panel.add_child(vbox)
	
	# Add padding
	var top_spacer = Control.new()
	top_spacer.custom_minimum_size.y = 30
	vbox.add_child(top_spacer)
	
	# Title
	var title = Label.new()
	title.text = "House Skins Collection"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", Color(0.9, 0.8, 0.7, 1.0))
	title.add_theme_font_size_override("font_size", 28)
	vbox.add_child(title)
	
	# Current selection info
	var current_label = Label.new()
	if ProfileManager.has_profile():
		var current_skin_id = ProfileManager.current_profile.get("selected_skin_id", 1)
		var skin_name = HouseSkinManager.get_skin_name(current_skin_id)
		current_label.text = "Currently Selected: " + skin_name
	else:
		current_label.text = "Currently Selected: Classic Cottage"
	current_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	current_label.add_theme_color_override("font_color", Color(0.8, 0.7, 0.6, 1.0))
	current_label.add_theme_font_size_override("font_size", 16)
	vbox.add_child(current_label)
	
	# Scrollable skins grid
	var scroll_container = ScrollContainer.new()
	scroll_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll_container.custom_minimum_size = Vector2(650, 400)
	scroll_container.size_flags_horizontal = Control.SIZE_SHRINK_CENTER  # Center and shrink to content
	scroll_container.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(scroll_container)
	
	# Grid container for skins (4 columns like the good version)
	var skins_grid = GridContainer.new()
	skins_grid.columns = 4
	skins_grid.add_theme_constant_override("h_separation", 20)
	skins_grid.add_theme_constant_override("v_separation", 15)
	scroll_container.add_child(skins_grid)
	
	# Get unlocked skins from profile
	var unlocked_skins = []
	if ProfileManager.has_profile():
		unlocked_skins = ProfileManager.current_profile.get("unlocked_skins", [1])
	else:
		unlocked_skins = [1]  # Only default skin unlocked
	
	# Ensure skin 1 is always in the unlocked list
	if not (1 in unlocked_skins):
		unlocked_skins.append(1)
	
	# Add skin entries using grid layout
	for skin_id in HouseSkinManager.skin_data:
		var skin_data = HouseSkinManager.skin_data[skin_id]
		var is_unlocked = skin_id in unlocked_skins
		var is_selected = false
		if ProfileManager.has_profile():
			is_selected = (skin_id == ProfileManager.current_profile.get("selected_skin_id", 1))
		else:
			is_selected = (skin_id == 1)
		
		_add_skin_grid_entry(skins_grid, skin_id, skin_data, is_unlocked, is_selected, skins_dialog, current_label)
	
	skins_dialog.add_child(content_panel)
	get_tree().current_scene.add_child(skins_dialog)
	skins_dialog.popup_centered()
	
	# When skins dialog closes, show parent dialog again
	skins_dialog.confirmed.connect(func(): parent_dialog.show())

func _add_skin_grid_entry(parent: Node, skin_id: int, _skin_data: Dictionary, is_unlocked: bool, is_selected: bool, dialog: AcceptDialog, current_label: Label):
	"""Helper to add a skin entry in grid format like the good version"""
	# Create a container for the button with background
	var button_container = Control.new()
	button_container.custom_minimum_size = Vector2(150, 190)
	
	# Create text label above the house image
	var text_label = Label.new()
	text_label.anchor_left = 0.0
	text_label.anchor_right = 1.0
	text_label.anchor_top = 0.0
	text_label.anchor_bottom = 0.0
	text_label.offset_bottom = 35
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
	skin_button.offset_top = 35
	skin_button.custom_minimum_size = Vector2(150, 155)
	
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
	
	# Get skin info - use the actual skin name from HouseSkinManager
	var skin_name = HouseSkinManager.get_skin_name(skin_id)
	
	# Set different opacity for locked vs unlocked house images
	if house_texture:
		var texture_rect = skin_button.get_child(0) as TextureRect
		if is_unlocked:
			texture_rect.modulate = Color(1, 1, 1, 0.6)  # Much more visible for unlocked
		else:
			texture_rect.modulate = Color(1, 1, 1, 0.2)  # Faded for locked
	
	# Style the button to look like a proper button with fantasy theme
	var button_style = StyleBoxFlat.new()
	button_style.bg_color = Color(0.2, 0.15, 0.1, 0.8)  # Fantasy brown background
	button_style.corner_radius_top_left = 8
	button_style.corner_radius_top_right = 8
	button_style.corner_radius_bottom_left = 8
	button_style.corner_radius_bottom_right = 8
	button_style.set_border_width_all(2)
	button_style.border_color = Color(0.4, 0.3, 0.2, 1.0)  # Brown border
	skin_button.add_theme_stylebox_override("normal", button_style)
	
	# Different button styles for different states
	var hover_style = button_style.duplicate()
	hover_style.bg_color = Color(0.25, 0.2, 0.15, 0.8)  # Lighter on hover
	hover_style.border_color = Color(0.6, 0.4, 0.2, 1.0)
	skin_button.add_theme_stylebox_override("hover", hover_style)
	
	if is_unlocked:
		# Set text for unlocked skins
		text_label.text = skin_name
		text_label.add_theme_color_override("font_color", Color.WHITE)
		skin_button.disabled = false
		
		# Highlight selected skin
		if is_selected:
			# Gold styling for selected skin
			var selected_style = button_style.duplicate()
			selected_style.border_color = Color.GREEN  # Keep green like the good version
			selected_style.set_border_width_all(3)
			selected_style.bg_color = Color(0.1, 0.3, 0.1, 0.8)  # Green tint like good version
			skin_button.add_theme_stylebox_override("normal", selected_style)
			text_label.add_theme_color_override("font_color", Color.GREEN)
			
		# Connect to selection function
		skin_button.pressed.connect(_on_skin_grid_selected.bind(skin_id, dialog, current_label))
	else:
		# Set text for locked skins
		text_label.text = "LOCKED\n" + skin_name
		text_label.add_theme_color_override("font_color", Color.GRAY)
		skin_button.disabled = true
		
		# Darker styling for locked skins
		var locked_style = button_style.duplicate()
		locked_style.bg_color = Color(0.1, 0.08, 0.06, 0.8)  # Darker background
		locked_style.border_color = Color(0.3, 0.2, 0.15, 1.0)  # Darker border
		skin_button.add_theme_stylebox_override("normal", locked_style)
		skin_button.add_theme_stylebox_override("disabled", locked_style)
	
	# Create a tooltip with skin description
	skin_button.tooltip_text = HouseSkinManager.get_skin_description(skin_id)
	
	# Add button to container, then container to grid
	button_container.add_child(skin_button)
	parent.add_child(button_container)

func _on_skin_grid_selected(skin_id: int, dialog: AcceptDialog, current_label: Label):
	"""Handle skin selection from grid"""
	if ProfileManager.has_profile():
		ProfileManager.current_profile["selected_skin_id"] = skin_id
		ProfileManager.save_profile()
		
		# Also update HouseSkinManager to keep it in sync
		var skin_manager = get_node("/root/HouseSkinManager")
		if skin_manager:
			skin_manager.set_selected_skin(skin_id)
		
		# Update the current selection label
		var skin_name = HouseSkinManager.get_skin_name(skin_id)
		current_label.text = "Currently Selected: " + skin_name
		
		# Close and reopen dialog to refresh the display
		dialog.hide()
		_show_house_skins_menu.call_deferred(dialog)
		
		print("Selected house skin: " + skin_name)

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

func _add_skin_entry(parent: Node, skin_id: int, skin_data: Dictionary, is_unlocked: bool, is_selected: bool, dialog: AcceptDialog, current_label: Label):
	"""Helper to add a skin entry"""
	var skin_panel = Panel.new()
	
	# Panel styling based on unlock/selection status
	var skin_style = StyleBoxFlat.new()
	if is_selected:
		skin_style.bg_color = Color(0.25, 0.2, 0.15, 0.9)
		skin_style.border_color = Color(1.0, 0.8, 0.4, 1.0)
		skin_style.set_border_width_all(3)
	elif is_unlocked:
		skin_style.bg_color = Color(0.2, 0.16, 0.12, 0.8)
		skin_style.border_color = Color(0.8, 0.6, 0.3, 1.0)
		skin_style.set_border_width_all(2)
	else:
		skin_style.bg_color = Color(0.15, 0.12, 0.09, 0.6)
		skin_style.border_color = Color(0.4, 0.3, 0.2, 0.8)
		skin_style.set_border_width_all(1)
	
	skin_style.corner_radius_top_left = 8
	skin_style.corner_radius_top_right = 8
	skin_style.corner_radius_bottom_left = 8
	skin_style.corner_radius_bottom_right = 8
	skin_panel.add_theme_stylebox_override("panel", skin_style)
	skin_panel.custom_minimum_size.y = 80
	
	# Content container
	var hbox = HBoxContainer.new()
	hbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hbox.add_theme_constant_override("separation", 15)
	skin_panel.add_child(hbox)
	
	# Status/Selection indicator
	var status_label = Label.new()
	if is_selected:
		status_label.text = "★"
		status_label.add_theme_color_override("font_color", Color(1.0, 0.8, 0.2, 1.0))
	elif is_unlocked:
		status_label.text = "✓"
		status_label.add_theme_color_override("font_color", Color(0.2, 0.8, 0.2, 1.0))
	else:
		status_label.text = "🔒"
		status_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6, 1.0))
	status_label.add_theme_font_size_override("font_size", 28)
	status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	status_label.custom_minimum_size.x = 50
	hbox.add_child(status_label)
	
	# Skin details
	var details_vbox = VBoxContainer.new()
	details_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(details_vbox)
	
	# Skin name
	var name_label = Label.new()
	name_label.text = skin_data.get("name", "Unknown Skin")
	if is_unlocked:
		name_label.add_theme_color_override("font_color", Color(0.9, 0.8, 0.7, 1.0))
	else:
		name_label.add_theme_color_override("font_color", Color(0.7, 0.6, 0.5, 1.0))
	name_label.add_theme_font_size_override("font_size", 18)
	details_vbox.add_child(name_label)
	
	# Skin description
	var desc_label = Label.new()
	desc_label.text = skin_data.get("description", "No description available")
	if is_unlocked:
		desc_label.add_theme_color_override("font_color", Color(0.8, 0.7, 0.6, 1.0))
	else:
		desc_label.add_theme_color_override("font_color", Color(0.6, 0.5, 0.4, 1.0))
	desc_label.add_theme_font_size_override("font_size", 14)
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	details_vbox.add_child(desc_label)
	
	# Select button (if unlocked and not already selected)
	if is_unlocked and not is_selected:
		var select_button = Button.new()
		select_button.text = "Select"
		select_button.custom_minimum_size.x = 120
		select_button.custom_minimum_size.y = 40
		_style_fantasy_button(select_button)
		
		# Connect button to selection logic
		select_button.pressed.connect(func(): _select_house_skin(skin_id, dialog, current_label))
		hbox.add_child(select_button)
	elif is_selected:
		var selected_label = Label.new()
		selected_label.text = "SELECTED"
		selected_label.add_theme_color_override("font_color", Color(1.0, 0.8, 0.2, 1.0))
		selected_label.add_theme_font_size_override("font_size", 14)
		selected_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		selected_label.custom_minimum_size.x = 120
		hbox.add_child(selected_label)
	
	parent.add_child(skin_panel)

func _select_house_skin(skin_id: int, dialog: AcceptDialog, current_label: Label):
	"""Handle house skin selection"""
	if ProfileManager.has_profile():
		ProfileManager.current_profile["selected_skin_id"] = skin_id
		ProfileManager.save_profile()
		
		# Update the current selection label
		var skin_name = HouseSkinManager.skin_data.get(skin_id, {}).get("name", "Unknown")
		current_label.text = "Currently Selected: " + skin_name
		
		# Close and reopen dialog to refresh the display
		dialog.hide()
		_show_house_skins_menu.call_deferred(dialog)
		
		print("Selected house skin: " + skin_name)

func _on_credits_pressed() -> void:
	"""Show credits menu"""
	show_credits_menu()

func show_credits_menu():
	"""Display credits dialog"""
	var dialog = AcceptDialog.new()
	dialog.title = "Credits"
	dialog.size = Vector2(500, 300)
	dialog.get_ok_button().text = "Back"
	
	# Add credits content
	var credits_text = RichTextLabel.new()
	credits_text.custom_minimum_size = Vector2(450, 200)
	credits_text.bbcode_enabled = true
	credits_text.text = """[center][color=#FFD700][font_size=24]SiegecraftTD[/font_size][/color]

[color=#DEB887]Programming:[/color]
[color=#F5DEB3]Keith Eberhard[/color]

[color=#DEB887]Music:[/color]
[color=#F5DEB3]Matthew Pablo[/color][/center]"""
	
	dialog.add_child(credits_text)
	
	# Apply dialog styling
	_apply_fantasy_dialog_style(dialog)
	
	add_child(dialog)
	dialog.popup_centered()
	dialog.get_ok_button().grab_focus()

func _on_start_game_pressed() -> void:
	"""Show game mode selection menu"""
	show_game_mode_selection()

func _on_continue_pressed() -> void:
	"""Show load game menu with continue options"""
	show_load_game_menu()

func show_load_game_menu():
	"""Display load game dialog with continue options"""
	var dialog = AcceptDialog.new()
	dialog.title = "Load Game"
	dialog.size = Vector2(600, 300)
	dialog.get_ok_button().visible = false  # Hide the default OK button
	
	# Create main container with proper spacing
	var main_container = VBoxContainer.new()
	main_container.add_theme_constant_override("separation", 30)
	main_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	main_container.custom_minimum_size = Vector2(550, 250)
	dialog.add_child(main_container)
	
	# Add title
	var title_label = Label.new()
	title_label.text = "Continue Your Adventure"
	title_label.add_theme_font_size_override("font_size", 24)
	title_label.add_theme_color_override("font_color", Color(0.9, 0.7, 0.3, 1.0))
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	main_container.add_child(title_label)
	
	# Add spacer
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 20)
	main_container.add_child(spacer)
	
	# Continue/Checkpoint button
	var continue_btn = Button.new()
	continue_btn.add_theme_font_size_override("font_size", 18)
	continue_btn.custom_minimum_size = Vector2(400, 60)
	_style_fantasy_button(continue_btn)
	
	# Check for checkpoint save
	var save_manager = get_node("/root/SaveManager")
	if save_manager and save_manager.has_checkpoint_save():
		var checkpoint_info = save_manager.get_checkpoint_file_info()
		var game_mode = checkpoint_info.get("game_mode", "Unknown")
		var wave_number = checkpoint_info.get("wave_number", 1)
		continue_btn.text = "CONTINUE (%s - Wave %d)" % [game_mode, wave_number]
		continue_btn.disabled = false
		continue_btn.modulate = Color.WHITE
		continue_btn.pressed.connect(_load_checkpoint_game.bind(dialog))
	else:
		continue_btn.text = "CONTINUE (NO CHECKPOINT)"
		continue_btn.disabled = true
		continue_btn.modulate = Color(0.5, 0.5, 0.5, 1.0)
	
	# Center the continue button
	var button_container = CenterContainer.new()
	button_container.add_child(continue_btn)
	main_container.add_child(button_container)
	
	# Add another spacer
	var spacer2 = Control.new()
	spacer2.custom_minimum_size = Vector2(0, 30)
	main_container.add_child(spacer2)
	
	# Back button
	var back_btn = Button.new()
	back_btn.text = "Back"
	back_btn.add_theme_font_size_override("font_size", 16)
	back_btn.custom_minimum_size = Vector2(200, 50)
	_style_fantasy_button(back_btn)
	back_btn.pressed.connect(dialog.hide)
	
	# Center the back button
	var back_container = CenterContainer.new()
	back_container.add_child(back_btn)
	main_container.add_child(back_container)
	
	# Apply dialog styling
	_apply_fantasy_dialog_style(dialog)
	
	add_child(dialog)
	dialog.popup_centered()
	if continue_btn.disabled:
		back_btn.grab_focus()
	else:
		continue_btn.grab_focus()

func _load_checkpoint_game(load_dialog):
	"""Load the checkpoint save and transition to main scene"""
	var save_manager = get_node("/root/SaveManager")
	if not save_manager:
		_show_error_dialog("Error", "Save system not available")
		return
	
	# Store the load flag for the main scene
	var game_mode_manager = get_node("/root/GameModeManager")
	if game_mode_manager:
		game_mode_manager.should_load_checkpoint = true
	
	load_dialog.hide()
	get_tree().change_scene_to_file("res://scenes/main.tscn")

func show_game_mode_selection():
	"""Display game mode selection dialog"""
	var dialog = AcceptDialog.new()
	dialog.title = "Select Game Mode"
	dialog.size = Vector2(600, 450)
	dialog.get_ok_button().visible = false  # Hide the default OK button
	
	# Create main container
	var main_container = VBoxContainer.new()
	main_container.add_theme_constant_override("separation", 20)
	main_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	main_container.custom_minimum_size = Vector2(550, 400)
	dialog.add_child(main_container)
	
	# Add title
	var title_label = Label.new()
	title_label.text = "Choose Your Challenge"
	title_label.add_theme_font_size_override("font_size", 24)
	title_label.add_theme_color_override("font_color", Color(0.9, 0.7, 0.3, 1.0))
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	main_container.add_child(title_label)
	
	# Add spacer
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 20)
	main_container.add_child(spacer)
	
	# Create button container
	var button_container = VBoxContainer.new()
	button_container.add_theme_constant_override("separation", 15)
	main_container.add_child(button_container)
	
	# Normal mode button
	var normal_btn = Button.new()
	normal_btn.text = "Normal Mode"
	normal_btn.add_theme_font_size_override("font_size", 18)
	normal_btn.custom_minimum_size = Vector2(300, 60)
	_style_fantasy_button(normal_btn)
	normal_btn.pressed.connect(_on_normal_mode_selected.bind(dialog))
	
	var normal_container = CenterContainer.new()
	normal_container.add_child(normal_btn)
	button_container.add_child(normal_container)
	
	# Extra Hard mode button
	var extra_hard_btn = Button.new()
	extra_hard_btn.text = "Extra Hard Mode"
	extra_hard_btn.add_theme_font_size_override("font_size", 18)
	extra_hard_btn.custom_minimum_size = Vector2(300, 60)
	_style_fantasy_button(extra_hard_btn)
	extra_hard_btn.pressed.connect(_on_extra_hard_mode_selected.bind(dialog))
	
	var extra_hard_container = CenterContainer.new()
	extra_hard_container.add_child(extra_hard_btn)
	button_container.add_child(extra_hard_container)
	
	# Endless mode button
	var endless_btn = Button.new()
	endless_btn.text = "Endless Mode"
	endless_btn.add_theme_font_size_override("font_size", 18)
	endless_btn.custom_minimum_size = Vector2(300, 60)
	_style_fantasy_button(endless_btn)
	endless_btn.pressed.connect(_on_endless_mode_selected.bind(dialog))
	
	var endless_container = CenterContainer.new()
	endless_container.add_child(endless_btn)
	button_container.add_child(endless_container)
	
	# Add spacer
	var spacer2 = Control.new()
	spacer2.custom_minimum_size = Vector2(0, 30)
	main_container.add_child(spacer2)
	
	# Back button
	var back_btn = Button.new()
	back_btn.text = "Back"
	back_btn.add_theme_font_size_override("font_size", 16)
	back_btn.custom_minimum_size = Vector2(200, 50)
	_style_fantasy_button(back_btn)
	back_btn.pressed.connect(dialog.hide)
	
	var back_container = CenterContainer.new()
	back_container.add_child(back_btn)
	main_container.add_child(back_container)
	
	# Apply dialog styling
	_apply_fantasy_dialog_style(dialog)
	
	add_child(dialog)
	dialog.popup_centered()
	normal_btn.grab_focus()

func _on_normal_mode_selected(dialog):
	"""Handle normal mode selection"""
	selected_game_mode = NORMAL_MODE
	dialog.hide()
	start_game()

func _on_extra_hard_mode_selected(dialog):
	"""Handle extra hard mode selection"""
	selected_game_mode = EXTRA_HARD_MODE
	dialog.hide()
	start_game()

func _on_endless_mode_selected(dialog):
	"""Handle endless mode selection"""
	selected_game_mode = ENDLESS_MODE
	dialog.hide()
	start_game()

func start_game():
	"""Start the game with selected mode"""
	# Store the selected game mode in the singleton
	var game_mode_manager = get_node("/root/GameModeManager")
	if game_mode_manager:
		game_mode_manager.current_mode = selected_game_mode
	
	# Use call_deferred to change scene to avoid input handling timing issues
	call_deferred("_change_to_game_scene")

func _change_to_game_scene():
	"""Deferred scene change to avoid input timing issues"""
	get_tree().change_scene_to_file("res://scenes/main.tscn")

func _apply_fantasy_dialog_style(dialog: AcceptDialog):
	"""Apply fantasy styling to dialog"""
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.08, 0.05, 0.95)  # Dark brown background
	style.border_color = Color(0.8, 0.6, 0.3, 1.0)  # Gold border
	style.set_border_width_all(3)
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_left = 12
	style.corner_radius_bottom_right = 12
	dialog.add_theme_stylebox_override("panel", style)
	
	# Style the title bar
	var title_style = StyleBoxFlat.new()
	title_style.bg_color = Color(0.25, 0.15, 0.08, 1.0)  # Darker brown for title bar
	title_style.border_color = Color(0.8, 0.6, 0.3, 1.0)  # Gold border
	title_style.set_border_width_all(2)
	title_style.corner_radius_top_left = 8
	title_style.corner_radius_top_right = 8
	title_style.corner_radius_bottom_left = 0
	title_style.corner_radius_bottom_right = 0
	dialog.add_theme_stylebox_override("title_panel", title_style)
	
	dialog.add_theme_color_override("font_color", Color(0.9, 0.8, 0.6, 1.0))  # Light golden text
	dialog.add_theme_color_override("title_color", Color(1.0, 0.85, 0.4, 1.0))  # Golden title
	dialog.add_theme_font_size_override("font_size", 14)
	dialog.add_theme_font_size_override("title_font_size", 16)

func _show_error_dialog(title: String, message: String):
	"""Show an error dialog with fantasy styling"""
	var error_dialog = AcceptDialog.new()
	error_dialog.title = title
	error_dialog.dialog_text = message
	
	# Style the error dialog
	var error_style = StyleBoxFlat.new()
	error_style.bg_color = Color(0.15, 0.08, 0.08, 0.95)  # Dark red background
	error_style.border_color = Color(0.8, 0.3, 0.3, 1.0)  # Red border
	error_style.set_border_width_all(3)
	error_style.corner_radius_top_left = 8
	error_style.corner_radius_top_right = 8
	error_style.corner_radius_bottom_left = 8
	error_style.corner_radius_bottom_right = 8
	error_dialog.add_theme_stylebox_override("panel", error_style)
	
	# Style the title bar
	var title_style = StyleBoxFlat.new()
	title_style.bg_color = Color(0.25, 0.12, 0.12, 1.0)  # Darker red for title bar
	title_style.border_color = Color(0.8, 0.3, 0.3, 1.0)  # Red border
	title_style.set_border_width_all(2)
	title_style.corner_radius_top_left = 8
	title_style.corner_radius_top_right = 8
	title_style.corner_radius_bottom_left = 0
	title_style.corner_radius_bottom_right = 0
	error_dialog.add_theme_stylebox_override("title_panel", title_style)
	
	error_dialog.add_theme_color_override("font_color", Color(1.0, 0.7, 0.7, 1.0))  # Light red text
	error_dialog.add_theme_color_override("title_color", Color(1.0, 0.6, 0.6, 1.0))  # Light red title
	error_dialog.add_theme_font_size_override("font_size", 14)
	error_dialog.add_theme_font_size_override("title_font_size", 16)
	
	add_child(error_dialog)
	error_dialog.popup_centered()
	error_dialog.confirmed.connect(error_dialog.queue_free)

func load_checkpoint_game():
	"""Load the checkpoint save and transition to main scene"""
	var save_manager = get_node("/root/SaveManager")
	if not save_manager:
		_show_error_dialog("Error", "Save system not available")
		return
	
	# Check if checkpoint exists
	if not save_manager.has_checkpoint_save():
		_show_error_dialog("No Checkpoint", "No saved game found to continue")
		return
	
	# Store the load flag for the main scene
	var game_mode_manager = get_node("/root/GameModeManager")
	if game_mode_manager:
		game_mode_manager.should_load_checkpoint = true
	
	get_tree().change_scene_to_file("res://scenes/main.tscn")

func _on_quit_pressed() -> void:
	get_tree().quit()

func _on_change_name_pressed() -> void:
	"""Handle change profile button - show profile selection"""
	show_profile_selection_dialog()

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
	if has_node("MainInterface/SettingsPanel"):
		$MainInterface/PrimaryMenuPanel.visible = false
		$MainInterface/NewsAndUpdates.visible = false
		$MainInterface/SettingsPanel.visible = true
	elif has_node("CentralLayout/SettingsPanel"):
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
	if has_node("MainInterface/SettingsPanel"):
		$MainInterface/SettingsPanel.visible = false
		$MainInterface/PrimaryMenuPanel.visible = true
		$MainInterface/NewsAndUpdates.visible = true
	elif has_node("CentralLayout/SettingsPanel"):
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

func _on_leaderboard_pressed() -> void:
	"""Handle leaderboard button"""
	print("Opening leaderboard...")
	# Could open leaderboard scene here

func _on_community_pressed() -> void:
	"""Handle community button"""
	print("Opening community features...")
	# Could open community/guild features here

# Profile and skin handlers
func _on_profile_loaded(_profile_name = null):
	"""Called when a profile is loaded"""
	update_medieval_profile_display()

func _on_skin_changed(_skin_id = null):
	"""Called when house skin changes"""
	# Will implement later for medieval theme if needed
	pass

func show_profile_selection_dialog():
	"""Show dialog to select, create, or delete profiles"""
	var dialog = AcceptDialog.new()
	dialog.title = ""  # Hide the default title since we'll create our own
	dialog.unresizable = false
	dialog.borderless = true  # Remove the OS window frame completely
	dialog.always_on_top = true
	
	# Style the dialog with fantasy theme
	var dialog_style = StyleBoxFlat.new()
	dialog_style.bg_color = Color(0.15, 0.1, 0.05, 0.95)  # Dark brown background
	dialog_style.border_color = Color(0.8, 0.6, 0.3, 1.0)  # Gold border
	dialog_style.set_border_width_all(3)
	dialog_style.corner_radius_top_left = 8
	dialog_style.corner_radius_top_right = 8
	dialog_style.corner_radius_bottom_left = 8
	dialog_style.corner_radius_bottom_right = 8
	dialog.add_theme_stylebox_override("panel", dialog_style)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 15)
	vbox.custom_minimum_size = Vector2(520, 480)  # Made taller for custom close button
	
	# Custom title bar with fantasy styling and close button
	var title_container = PanelContainer.new()
	var title_style = StyleBoxFlat.new()
	title_style.bg_color = Color(0.25, 0.18, 0.1, 1.0)  # Darker brown for title bar
	title_style.border_color = Color(0.8, 0.6, 0.3, 1.0)  # Gold border
	title_style.set_border_width_all(2)
	title_style.corner_radius_top_left = 5
	title_style.corner_radius_top_right = 5
	title_style.corner_radius_bottom_left = 0
	title_style.corner_radius_bottom_right = 0
	title_container.add_theme_stylebox_override("panel", title_style)
	title_container.custom_minimum_size.y = 40
	
	var title_hbox = HBoxContainer.new()
	title_hbox.add_theme_constant_override("separation", 10)
	
	var title_label = Label.new()
	title_label.text = "⚔️ PROFILE MANAGEMENT ⚔️"
	title_label.add_theme_font_size_override("font_size", 18)
	title_label.add_theme_color_override("font_color", Color(0.9, 0.7, 0.4, 1.0))  # Gold text
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_hbox.add_child(title_label)
	
	# Custom close button
	var close_btn = Button.new()
	close_btn.text = "✖"
	close_btn.custom_minimum_size = Vector2(30, 30)
	close_btn.pressed.connect(dialog.queue_free)
	
	# Style the close button
	var close_style_normal = StyleBoxFlat.new()
	close_style_normal.bg_color = Color(0.4, 0.2, 0.2, 1.0)  # Dark red
	close_style_normal.border_color = Color(0.6, 0.3, 0.3, 1.0)  # Red border
	close_style_normal.set_border_width_all(1)
	close_style_normal.corner_radius_top_left = 4
	close_style_normal.corner_radius_top_right = 4
	close_style_normal.corner_radius_bottom_left = 4
	close_style_normal.corner_radius_bottom_right = 4
	
	var close_style_hover = StyleBoxFlat.new()
	close_style_hover.bg_color = Color(0.6, 0.3, 0.3, 1.0)  # Lighter red
	close_style_hover.border_color = Color(0.8, 0.4, 0.4, 1.0)  # Bright red border
	close_style_hover.set_border_width_all(1)
	close_style_hover.corner_radius_top_left = 4
	close_style_hover.corner_radius_top_right = 4
	close_style_hover.corner_radius_bottom_left = 4
	close_style_hover.corner_radius_bottom_right = 4
	
	close_btn.add_theme_stylebox_override("normal", close_style_normal)
	close_btn.add_theme_stylebox_override("hover", close_style_hover)
	close_btn.add_theme_stylebox_override("pressed", close_style_hover)
	close_btn.add_theme_color_override("font_color", Color(1.0, 0.8, 0.8, 1.0))
	close_btn.add_theme_color_override("font_hover_color", Color(1.0, 0.9, 0.9, 1.0))
	
	title_hbox.add_child(close_btn)
	title_container.add_child(title_hbox)
	vbox.add_child(title_container)
	
	# Profile list section - wrap in margin container for padding
	var section_label_margin = MarginContainer.new()
	section_label_margin.add_theme_constant_override("margin_left", 15)
	section_label_margin.add_theme_constant_override("margin_right", 15)
	section_label_margin.add_theme_constant_override("margin_top", 5)
	section_label_margin.add_theme_constant_override("margin_bottom", 5)
	
	var section_label = Label.new()
	section_label.text = "Select Profile:"
	section_label.add_theme_font_size_override("font_size", 16)
	section_label.add_theme_color_override("font_color", Color(0.8, 0.6, 0.3, 1.0))  # Gold text
	section_label_margin.add_child(section_label)
	vbox.add_child(section_label_margin)
	
	# Profile list with styling
	var scroll = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(480, 280)  # Increased from 200 to 280 to use bottom space
	
	# Style the scroll container
	var scroll_style = StyleBoxFlat.new()
	scroll_style.bg_color = Color(0.1, 0.07, 0.04, 0.8)  # Darker brown
	scroll_style.border_color = Color(0.6, 0.4, 0.2, 1.0)  # Darker gold border
	scroll_style.set_border_width_all(2)
	scroll_style.corner_radius_top_left = 5
	scroll_style.corner_radius_top_right = 5
	scroll_style.corner_radius_bottom_left = 5
	scroll_style.corner_radius_bottom_right = 5
	scroll.add_theme_stylebox_override("panel", scroll_style)
	
	var profile_list = VBoxContainer.new()
	profile_list.add_theme_constant_override("separation", 8)
	scroll.add_child(profile_list)
	vbox.add_child(scroll)
	
	# Get all profiles
	var all_profiles = profile_manager.get_all_profiles()
	var current_profile_name = profile_manager.profile_name
	
	# Add profile buttons with fantasy styling
	for profile_name in all_profiles:
		# Create margin container for padding around each profile row
		var margin_container = MarginContainer.new()
		margin_container.add_theme_constant_override("margin_left", 15)
		margin_container.add_theme_constant_override("margin_right", 15)
		margin_container.add_theme_constant_override("margin_top", 3)
		margin_container.add_theme_constant_override("margin_bottom", 3)
		
		var hbox = HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 10)
		
		var profile_btn = Button.new()
		profile_btn.text = profile_name
		profile_btn.custom_minimum_size = Vector2(200, 45)  # Better minimum size
		
		# Style the profile button
		var btn_style_normal = StyleBoxFlat.new()
		var btn_style_hover = StyleBoxFlat.new()
		var btn_style_disabled = StyleBoxFlat.new()
		
		if profile_name == current_profile_name:
			profile_btn.text += " ⭐ (Current)"
			profile_btn.disabled = true
			
			# Disabled/current profile styling - gold theme
			btn_style_disabled.bg_color = Color(0.3, 0.25, 0.15, 1.0)  # Dark gold
			btn_style_disabled.border_color = Color(0.8, 0.6, 0.3, 1.0)  # Gold border
			btn_style_disabled.set_border_width_all(2)
			btn_style_disabled.corner_radius_top_left = 5
			btn_style_disabled.corner_radius_top_right = 5
			btn_style_disabled.corner_radius_bottom_left = 5
			btn_style_disabled.corner_radius_bottom_right = 5
			profile_btn.add_theme_stylebox_override("disabled", btn_style_disabled)
			profile_btn.add_theme_color_override("font_disabled_color", Color(0.9, 0.7, 0.4, 1.0))
		else:
			profile_btn.pressed.connect(_on_profile_selected.bind(profile_name, dialog))
			
			# Normal button styling - brown theme
			btn_style_normal.bg_color = Color(0.2, 0.15, 0.1, 1.0)  # Dark brown
			btn_style_normal.border_color = Color(0.6, 0.4, 0.2, 1.0)  # Medium brown border
			btn_style_normal.set_border_width_all(2)
			btn_style_normal.corner_radius_top_left = 5
			btn_style_normal.corner_radius_top_right = 5
			btn_style_normal.corner_radius_bottom_left = 5
			btn_style_normal.corner_radius_bottom_right = 5
			
			# Hover styling - lighter brown
			btn_style_hover.bg_color = Color(0.25, 0.2, 0.15, 1.0)  # Lighter brown
			btn_style_hover.border_color = Color(0.8, 0.6, 0.3, 1.0)  # Gold border on hover
			btn_style_hover.set_border_width_all(2)
			btn_style_hover.corner_radius_top_left = 5
			btn_style_hover.corner_radius_top_right = 5
			btn_style_hover.corner_radius_bottom_left = 5
			btn_style_hover.corner_radius_bottom_right = 5
			
			profile_btn.add_theme_stylebox_override("normal", btn_style_normal)
			profile_btn.add_theme_stylebox_override("hover", btn_style_hover)
			profile_btn.add_theme_stylebox_override("pressed", btn_style_hover)
			profile_btn.add_theme_color_override("font_color", Color(0.9, 0.8, 0.7, 1.0))  # Light brown text
			profile_btn.add_theme_color_override("font_hover_color", Color(0.95, 0.85, 0.75, 1.0))  # Lighter on hover
		
		profile_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		profile_btn.custom_minimum_size.y = 40
		hbox.add_child(profile_btn)
		
		# Reset button for current profile OR Delete button for others
		if profile_name == current_profile_name:
			var reset_btn = Button.new()
			reset_btn.text = "🔄 Reset"
			reset_btn.custom_minimum_size = Vector2(80, 40)
			reset_btn.pressed.connect(_on_profile_reset.bind(profile_name, dialog))
			
			# Reset button styling - orange/red theme
			var reset_style_normal = StyleBoxFlat.new()
			reset_style_normal.bg_color = Color(0.4, 0.2, 0.1, 1.0)  # Dark orange-brown
			reset_style_normal.border_color = Color(0.8, 0.4, 0.2, 1.0)  # Orange border
			reset_style_normal.set_border_width_all(2)
			reset_style_normal.corner_radius_top_left = 5
			reset_style_normal.corner_radius_top_right = 5
			reset_style_normal.corner_radius_bottom_left = 5
			reset_style_normal.corner_radius_bottom_right = 5
			
			var reset_style_hover = StyleBoxFlat.new()
			reset_style_hover.bg_color = Color(0.5, 0.25, 0.15, 1.0)  # Lighter orange-brown
			reset_style_hover.border_color = Color(1.0, 0.5, 0.3, 1.0)  # Bright orange border
			reset_style_hover.set_border_width_all(2)
			reset_style_hover.corner_radius_top_left = 5
			reset_style_hover.corner_radius_top_right = 5
			reset_style_hover.corner_radius_bottom_left = 5
			reset_style_hover.corner_radius_bottom_right = 5
			
			reset_btn.add_theme_stylebox_override("normal", reset_style_normal)
			reset_btn.add_theme_stylebox_override("hover", reset_style_hover)
			reset_btn.add_theme_stylebox_override("pressed", reset_style_hover)
			reset_btn.add_theme_color_override("font_color", Color(1.0, 0.8, 0.6, 1.0))  # Light orange text
			reset_btn.add_theme_color_override("font_hover_color", Color(1.0, 0.9, 0.7, 1.0))
			
			hbox.add_child(reset_btn)
		elif all_profiles.size() > 1:
			var delete_btn = Button.new()
			delete_btn.text = "🗑️ Delete"
			delete_btn.custom_minimum_size = Vector2(80, 40)
			delete_btn.pressed.connect(_on_profile_delete.bind(profile_name, dialog))
			
			# Delete button styling - red theme
			var delete_style_normal = StyleBoxFlat.new()
			delete_style_normal.bg_color = Color(0.3, 0.1, 0.1, 1.0)  # Dark red-brown
			delete_style_normal.border_color = Color(0.6, 0.2, 0.2, 1.0)  # Red border
			delete_style_normal.set_border_width_all(2)
			delete_style_normal.corner_radius_top_left = 5
			delete_style_normal.corner_radius_top_right = 5
			delete_style_normal.corner_radius_bottom_left = 5
			delete_style_normal.corner_radius_bottom_right = 5
			
			var delete_style_hover = StyleBoxFlat.new()
			delete_style_hover.bg_color = Color(0.4, 0.15, 0.15, 1.0)  # Lighter red-brown
			delete_style_hover.border_color = Color(0.8, 0.3, 0.3, 1.0)  # Bright red border
			delete_style_hover.set_border_width_all(2)
			delete_style_hover.corner_radius_top_left = 5
			delete_style_hover.corner_radius_top_right = 5
			delete_style_hover.corner_radius_bottom_left = 5
			delete_style_hover.corner_radius_bottom_right = 5
			
			delete_btn.add_theme_stylebox_override("normal", delete_style_normal)
			delete_btn.add_theme_stylebox_override("hover", delete_style_hover)
			delete_btn.add_theme_stylebox_override("pressed", delete_style_hover)
			delete_btn.add_theme_color_override("font_color", Color(1.0, 0.7, 0.7, 1.0))  # Light red text
			delete_btn.add_theme_color_override("font_hover_color", Color(1.0, 0.8, 0.8, 1.0))
			
			hbox.add_child(delete_btn)
		
		# Add hbox to margin container, then margin container to profile list
		margin_container.add_child(hbox)
		profile_list.add_child(margin_container)
	
	# Create new profile section with fantasy styling
	var separator = HSeparator.new()
	var sep_style = StyleBoxFlat.new()
	sep_style.bg_color = Color(0.6, 0.4, 0.2, 1.0)  # Gold separator
	sep_style.content_margin_top = 1
	sep_style.content_margin_bottom = 1
	separator.add_theme_stylebox_override("separator", sep_style)
	vbox.add_child(separator)
	
	# Create margin container for the new profile label
	var label_margin = MarginContainer.new()
	label_margin.add_theme_constant_override("margin_left", 15)
	label_margin.add_theme_constant_override("margin_right", 15)
	label_margin.add_theme_constant_override("margin_top", 5)
	label_margin.add_theme_constant_override("margin_bottom", 5)
	
	var new_profile_label = Label.new()
	new_profile_label.text = "⚒️ Create New Profile:"
	new_profile_label.add_theme_font_size_override("font_size", 16)
	new_profile_label.add_theme_color_override("font_color", Color(0.8, 0.6, 0.3, 1.0))  # Gold text
	label_margin.add_child(new_profile_label)
	vbox.add_child(label_margin)
	
	# Create margin container for the new profile input section
	var input_margin = MarginContainer.new()
	input_margin.add_theme_constant_override("margin_left", 15)
	input_margin.add_theme_constant_override("margin_right", 15)
	input_margin.add_theme_constant_override("margin_top", 5)
	input_margin.add_theme_constant_override("margin_bottom", 15)
	
	var new_profile_hbox = HBoxContainer.new()
	new_profile_hbox.add_theme_constant_override("separation", 10)
	
	var new_name_edit = LineEdit.new()
	new_name_edit.placeholder_text = "Enter new profile name..."
	new_name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	new_name_edit.custom_minimum_size.y = 40
	
	# Style the line edit
	var edit_style_normal = StyleBoxFlat.new()
	edit_style_normal.bg_color = Color(0.1, 0.07, 0.04, 1.0)  # Dark brown background
	edit_style_normal.border_color = Color(0.6, 0.4, 0.2, 1.0)  # Brown border
	edit_style_normal.set_border_width_all(2)
	edit_style_normal.corner_radius_top_left = 5
	edit_style_normal.corner_radius_top_right = 5
	edit_style_normal.corner_radius_bottom_left = 5
	edit_style_normal.corner_radius_bottom_right = 5
	
	var edit_style_focus = StyleBoxFlat.new()
	edit_style_focus.bg_color = Color(0.12, 0.09, 0.06, 1.0)  # Slightly lighter brown
	edit_style_focus.border_color = Color(0.8, 0.6, 0.3, 1.0)  # Gold border when focused
	edit_style_focus.set_border_width_all(2)
	edit_style_focus.corner_radius_top_left = 5
	edit_style_focus.corner_radius_top_right = 5
	edit_style_focus.corner_radius_bottom_left = 5
	edit_style_focus.corner_radius_bottom_right = 5
	
	new_name_edit.add_theme_stylebox_override("normal", edit_style_normal)
	new_name_edit.add_theme_stylebox_override("focus", edit_style_focus)
	new_name_edit.add_theme_color_override("font_color", Color(0.9, 0.8, 0.7, 1.0))  # Light brown text
	new_name_edit.add_theme_color_override("font_placeholder_color", Color(0.6, 0.5, 0.4, 1.0))  # Darker placeholder
	
	new_profile_hbox.add_child(new_name_edit)
	
	var create_btn = Button.new()
	create_btn.text = "⚔️ Create"
	create_btn.custom_minimum_size = Vector2(100, 40)
	create_btn.pressed.connect(_on_create_profile.bind(new_name_edit, dialog))
	
	# Style the create button - green theme
	var create_style_normal = StyleBoxFlat.new()
	create_style_normal.bg_color = Color(0.15, 0.3, 0.1, 1.0)  # Dark green-brown
	create_style_normal.border_color = Color(0.3, 0.6, 0.2, 1.0)  # Green border
	create_style_normal.set_border_width_all(2)
	create_style_normal.corner_radius_top_left = 5
	create_style_normal.corner_radius_top_right = 5
	create_style_normal.corner_radius_bottom_left = 5
	create_style_normal.corner_radius_bottom_right = 5
	
	var create_style_hover = StyleBoxFlat.new()
	create_style_hover.bg_color = Color(0.2, 0.4, 0.15, 1.0)  # Lighter green-brown
	create_style_hover.border_color = Color(0.4, 0.8, 0.3, 1.0)  # Bright green border
	create_style_hover.set_border_width_all(2)
	create_style_hover.corner_radius_top_left = 5
	create_style_hover.corner_radius_top_right = 5
	create_style_hover.corner_radius_bottom_left = 5
	create_style_hover.corner_radius_bottom_right = 5
	
	create_btn.add_theme_stylebox_override("normal", create_style_normal)
	create_btn.add_theme_stylebox_override("hover", create_style_hover)
	create_btn.add_theme_stylebox_override("pressed", create_style_hover)
	create_btn.add_theme_color_override("font_color", Color(0.8, 1.0, 0.7, 1.0))  # Light green text
	create_btn.add_theme_color_override("font_hover_color", Color(0.9, 1.0, 0.8, 1.0))
	
	new_profile_hbox.add_child(create_btn)
	
	# Add hbox to margin container, then margin container to vbox
	input_margin.add_child(new_profile_hbox)
	vbox.add_child(input_margin)
	
	dialog.add_child(vbox)
	add_child(dialog)
	
	# Hide the default OK button since we have our own close button
	dialog.get_ok_button().visible = false
	
	dialog.popup_centered()

func _on_profile_selected(profile_name: String, dialog: AcceptDialog):
	"""Handle profile selection"""
	if profile_manager.switch_profile(profile_name):
		update_profile_display()
		dialog.queue_free()
	else:
		print("Failed to switch to profile: ", profile_name)

func _on_profile_delete(profile_name: String, dialog: AcceptDialog):
	"""Handle profile deletion"""
	# Close the main dialog first to prevent exclusive child issue
	dialog.hide()
	
	var confirm_dialog = ConfirmationDialog.new()
	confirm_dialog.dialog_text = "⚠️ Are you sure you want to delete profile '" + profile_name + "'?\n\nThis action cannot be undone and will permanently remove all data associated with this profile."
	confirm_dialog.confirmed.connect(_delete_profile_confirmed.bind(profile_name, dialog, confirm_dialog))
	confirm_dialog.canceled.connect(_delete_profile_canceled.bind(dialog, confirm_dialog))
	
	# Style the confirmation dialog with fantasy theme
	var confirm_style = StyleBoxFlat.new()
	confirm_style.bg_color = Color(0.12, 0.08, 0.05, 0.95)  # Dark brown background
	confirm_style.border_color = Color(0.8, 0.3, 0.3, 1.0)  # Red border for warning
	confirm_style.set_border_width_all(3)
	confirm_style.corner_radius_top_left = 8
	confirm_style.corner_radius_top_right = 8
	confirm_style.corner_radius_bottom_left = 8
	confirm_style.corner_radius_bottom_right = 8
	confirm_dialog.add_theme_stylebox_override("panel", confirm_style)
	
	# Style the title bar
	var title_style = StyleBoxFlat.new()
	title_style.bg_color = Color(0.25, 0.15, 0.1, 1.0)  # Darker brown for title bar
	title_style.border_color = Color(0.8, 0.3, 0.3, 1.0)  # Red border for warning
	title_style.set_border_width_all(2)
	title_style.corner_radius_top_left = 8
	title_style.corner_radius_top_right = 8
	title_style.corner_radius_bottom_left = 0
	title_style.corner_radius_bottom_right = 0
	confirm_dialog.add_theme_stylebox_override("title_panel", title_style)
	
	# Style the dialog text and title
	confirm_dialog.add_theme_color_override("font_color", Color(1.0, 0.8, 0.7, 1.0))  # Light text
	confirm_dialog.add_theme_color_override("title_color", Color(1.0, 0.7, 0.7, 1.0))  # Light red title
	confirm_dialog.add_theme_font_size_override("font_size", 14)
	confirm_dialog.add_theme_font_size_override("title_font_size", 16)
	
	add_child(confirm_dialog)
	confirm_dialog.popup_centered()

func _delete_profile_confirmed(profile_name: String, main_dialog: AcceptDialog, confirm_dialog: ConfirmationDialog):
	"""Confirm profile deletion"""
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
	confirm_dialog.dialog_text = "⚠️ Are you sure you want to reset profile '" + profile_name + "'?\n\n🗡️ This will:\n• Delete all save games\n• Reset all stats to zero\n• Reset unlocked skins to default\n• Clear all achievements\n\n⚔️ This action cannot be undone!"
	confirm_dialog.confirmed.connect(_reset_profile_confirmed.bind(profile_name, dialog, confirm_dialog))
	confirm_dialog.canceled.connect(_reset_profile_canceled.bind(dialog, confirm_dialog))
	
	# Style the reset confirmation dialog with fantasy theme
	var confirm_style = StyleBoxFlat.new()
	confirm_style.bg_color = Color(0.12, 0.08, 0.05, 0.95)  # Dark brown background
	confirm_style.border_color = Color(0.8, 0.5, 0.2, 1.0)  # Orange border for warning
	confirm_style.set_border_width_all(3)
	confirm_style.corner_radius_top_left = 8
	confirm_style.corner_radius_top_right = 8
	confirm_style.corner_radius_bottom_left = 8
	confirm_style.corner_radius_bottom_right = 8
	confirm_dialog.add_theme_stylebox_override("panel", confirm_style)
	
	# Style the title bar
	var title_style = StyleBoxFlat.new()
	title_style.bg_color = Color(0.25, 0.18, 0.1, 1.0)  # Darker brown for title bar
	title_style.border_color = Color(0.8, 0.5, 0.2, 1.0)  # Orange border for warning
	title_style.set_border_width_all(2)
	title_style.corner_radius_top_left = 8
	title_style.corner_radius_top_right = 8
	title_style.corner_radius_bottom_left = 0
	title_style.corner_radius_bottom_right = 0
	confirm_dialog.add_theme_stylebox_override("title_panel", title_style)
	
	# Style the dialog text and title
	confirm_dialog.add_theme_color_override("font_color", Color(1.0, 0.8, 0.7, 1.0))  # Light text
	confirm_dialog.add_theme_color_override("title_color", Color(1.0, 0.8, 0.6, 1.0))  # Light orange title
	confirm_dialog.add_theme_font_size_override("font_size", 14)
	confirm_dialog.add_theme_font_size_override("title_font_size", 16)
	
	add_child(confirm_dialog)
	confirm_dialog.popup_centered()

func _reset_profile_confirmed(profile_name: String, main_dialog: AcceptDialog, confirm_dialog: ConfirmationDialog):
	"""Confirm profile reset"""
	if profile_manager.reset_current_profile():
		print("Profile reset: ", profile_name)
		# Update the UI to reflect changes
		update_profile_display()
		# Clean up dialogs and refresh
		confirm_dialog.queue_free()
		main_dialog.queue_free()
		# Show a success message with fantasy styling
		var success_dialog = AcceptDialog.new()
		success_dialog.dialog_text = "✅ Profile '" + profile_name + "' has been reset successfully!\n\n⚔️ Your adventure begins anew, brave warrior!"
		
		# Style the success dialog
		var success_style = StyleBoxFlat.new()
		success_style.bg_color = Color(0.1, 0.15, 0.08, 0.95)  # Dark green background
		success_style.border_color = Color(0.4, 0.8, 0.3, 1.0)  # Green border
		success_style.set_border_width_all(3)
		success_style.corner_radius_top_left = 8
		success_style.corner_radius_top_right = 8
		success_style.corner_radius_bottom_left = 8
		success_style.corner_radius_bottom_right = 8
		success_dialog.add_theme_stylebox_override("panel", success_style)
		
		# Style the title bar
		var title_style = StyleBoxFlat.new()
		title_style.bg_color = Color(0.15, 0.25, 0.12, 1.0)  # Darker green for title bar
		title_style.border_color = Color(0.4, 0.8, 0.3, 1.0)  # Green border
		title_style.set_border_width_all(2)
		title_style.corner_radius_top_left = 8
		title_style.corner_radius_top_right = 8
		title_style.corner_radius_bottom_left = 0
		title_style.corner_radius_bottom_right = 0
		success_dialog.add_theme_stylebox_override("title_panel", title_style)
		
		success_dialog.add_theme_color_override("font_color", Color(0.8, 1.0, 0.7, 1.0))  # Light green text
		success_dialog.add_theme_color_override("title_color", Color(0.7, 1.0, 0.6, 1.0))  # Light green title
		success_dialog.add_theme_font_size_override("font_size", 14)
		success_dialog.add_theme_font_size_override("title_font_size", 16)
		
		add_child(success_dialog)
		success_dialog.popup_centered()
		success_dialog.confirmed.connect(success_dialog.queue_free)
	else:
		# Clean up dialogs properly and show main dialog again if reset failed
		confirm_dialog.hide()  # Immediately remove exclusive child status
		confirm_dialog.queue_free()
		main_dialog.show()
		# Show error message with fantasy styling
		var error_dialog = AcceptDialog.new()
		error_dialog.dialog_text = "❌ Failed to reset profile. Please try again.\n\n⚔️ The ancient magic seems to be resisting..."
		
		# Style the error dialog
		var error_style = StyleBoxFlat.new()
		error_style.bg_color = Color(0.15, 0.08, 0.08, 0.95)  # Dark red background
		error_style.border_color = Color(0.8, 0.3, 0.3, 1.0)  # Red border
		error_style.set_border_width_all(3)
		error_style.corner_radius_top_left = 8
		error_style.corner_radius_top_right = 8
		error_style.corner_radius_bottom_left = 8
		error_style.corner_radius_bottom_right = 8
		error_dialog.add_theme_stylebox_override("panel", error_style)
		
		# Style the title bar
		var title_style = StyleBoxFlat.new()
		title_style.bg_color = Color(0.25, 0.12, 0.12, 1.0)  # Darker red for title bar
		title_style.border_color = Color(0.8, 0.3, 0.3, 1.0)  # Red border
		title_style.set_border_width_all(2)
		title_style.corner_radius_top_left = 8
		title_style.corner_radius_top_right = 8
		title_style.corner_radius_bottom_left = 0
		title_style.corner_radius_bottom_right = 0
		error_dialog.add_theme_stylebox_override("title_panel", title_style)
		
		error_dialog.add_theme_color_override("font_color", Color(1.0, 0.7, 0.7, 1.0))  # Light red text
		error_dialog.add_theme_color_override("title_color", Color(1.0, 0.6, 0.6, 1.0))  # Light red title
		error_dialog.add_theme_font_size_override("font_size", 14)
		error_dialog.add_theme_font_size_override("title_font_size", 16)
		
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
	
	if profile_manager.change_profile_name(new_name):
		update_profile_display()
		dialog.queue_free()
		
		# Wait a frame before showing success dialog to avoid exclusive child conflicts
		await get_tree().process_frame
		
		# Show success message with fantasy styling
		var success_dialog = AcceptDialog.new()
		success_dialog.dialog_text = "🎉 New profile '" + new_name + "' created successfully!\n\n⚔️ Welcome to the realm, " + new_name + "!"
		
		# Style the success dialog
		var success_style = StyleBoxFlat.new()
		success_style.bg_color = Color(0.1, 0.15, 0.08, 0.95)  # Dark green background
		success_style.border_color = Color(0.4, 0.8, 0.3, 1.0)  # Green border
		success_style.set_border_width_all(3)
		success_style.corner_radius_top_left = 8
		success_style.corner_radius_top_right = 8
		success_style.corner_radius_bottom_left = 8
		success_style.corner_radius_bottom_right = 8
		success_dialog.add_theme_stylebox_override("panel", success_style)
		
		# Style the title bar
		var title_style = StyleBoxFlat.new()
		title_style.bg_color = Color(0.15, 0.25, 0.12, 1.0)  # Darker green for title bar
		title_style.border_color = Color(0.4, 0.8, 0.3, 1.0)  # Green border
		title_style.set_border_width_all(2)
		title_style.corner_radius_top_left = 8
		title_style.corner_radius_top_right = 8
		title_style.corner_radius_bottom_left = 0
		title_style.corner_radius_bottom_right = 0
		success_dialog.add_theme_stylebox_override("title_panel", title_style)
		
		success_dialog.add_theme_color_override("font_color", Color(0.8, 1.0, 0.7, 1.0))  # Light green text
		success_dialog.add_theme_color_override("title_color", Color(0.7, 1.0, 0.6, 1.0))  # Light green title
		success_dialog.add_theme_font_size_override("font_size", 14)
		success_dialog.add_theme_font_size_override("title_font_size", 16)
		
		add_child(success_dialog)
		success_dialog.popup_centered()
		success_dialog.confirmed.connect(success_dialog.queue_free)
	else:
		# Wait a frame before showing error dialog to avoid exclusive child conflicts
		await get_tree().process_frame
		
		# Show error message with fantasy styling
		var error_dialog = AcceptDialog.new()
		error_dialog.dialog_text = "❌ Failed to create profile.\n\n⚔️ This name might already exist in the realm, or the ancient scrolls are full!"
		
		# Style the error dialog
		var error_style = StyleBoxFlat.new()
		error_style.bg_color = Color(0.15, 0.08, 0.08, 0.95)  # Dark red background
		error_style.border_color = Color(0.8, 0.3, 0.3, 1.0)  # Red border
		error_style.set_border_width_all(3)
		error_style.corner_radius_top_left = 8
		error_style.corner_radius_top_right = 8
		error_style.corner_radius_bottom_left = 8
		error_style.corner_radius_bottom_right = 8
		error_dialog.add_theme_stylebox_override("panel", error_style)
		
		# Style the title bar
		var title_style = StyleBoxFlat.new()
		title_style.bg_color = Color(0.25, 0.12, 0.12, 1.0)  # Darker red for title bar
		title_style.border_color = Color(0.8, 0.3, 0.3, 1.0)  # Red border
		title_style.set_border_width_all(2)
		title_style.corner_radius_top_left = 8
		title_style.corner_radius_top_right = 8
		title_style.corner_radius_bottom_left = 0
		title_style.corner_radius_bottom_right = 0
		error_dialog.add_theme_stylebox_override("title_panel", title_style)
		
		error_dialog.add_theme_color_override("font_color", Color(1.0, 0.7, 0.7, 1.0))  # Light red text
		error_dialog.add_theme_color_override("title_color", Color(1.0, 0.6, 0.6, 1.0))  # Light red title
		error_dialog.add_theme_font_size_override("font_size", 14)
		error_dialog.add_theme_font_size_override("title_font_size", 16)
		
		add_child(error_dialog)
		error_dialog.popup_centered()
		error_dialog.confirmed.connect(error_dialog.queue_free)
