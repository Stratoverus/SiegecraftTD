extends Node2D

# References to skin UI elements
@onready var skin_grid: GridContainer
@onready var current_skin_label: Label

func _ready() -> void:
	$CenterContainer/MainButtons/newGame.grab_focus()
	$CenterContainer/SettingsMenu/fullscreen.button_pressed = true if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN else false
	$CenterContainer/SettingsMenu/mainVolSlider.value = db_to_linear(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Master")))
	$CenterContainer/SettingsMenu/musicVolSlider.value = db_to_linear(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("MUSIC")))
	$CenterContainer/SettingsMenu/sfxVolSlider.value = db_to_linear(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("SFX")))
	
	# Get references to house skin UI elements
	skin_grid = $CenterContainer/HouseSkinsMenu/ScrollContainer/skinGrid
	current_skin_label = $CenterContainer/HouseSkinsMenu/currentSkinLabel
	
	# Connect to skin change signal
	var house_skin_manager = get_node("/root/HouseSkinManager")
	if house_skin_manager:
		house_skin_manager.skin_changed.connect(_on_skin_changed)
	
	# Update current skin display
	_update_current_skin_display()
	

# Game mode data
var selected_game_mode: Resource = null

func _on_new_game_pressed() -> void:
	$CenterContainer/MainButtons.visible = false
	$CenterContainer/GameModeMenu.visible = true
	$CenterContainer/GameModeMenu/normal.grab_focus() 


func _on_load_game_pressed() -> void:
	$CenterContainer/MainButtons.visible = false
	$CenterContainer/LoadMenu.visible = true
	_populate_save_slots()
	$CenterContainer/LoadMenu/back.grab_focus()


func _populate_save_slots():
	"""Populate the load menu with available save slots"""
	var save_manager = get_node("/root/SaveManager")
	if not save_manager:
		return
	
	# Get references to the buttons
	var checkpoint_button = $CenterContainer/LoadMenu/loadCheckpoint
	var slot1_button = $CenterContainer/LoadMenu/loadSlot1
	var slot2_button = $CenterContainer/LoadMenu/loadSlot2
	var slot3_button = $CenterContainer/LoadMenu/loadSlot3
	
	# Update checkpoint button
	if save_manager.has_checkpoint_save():
		var checkpoint_info = save_manager.get_save_file_info(0)
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
	
	# Update save slot buttons
	var slot_buttons = [slot1_button, slot2_button, slot3_button]
	for i in range(3):
		var slot_num = i + 1
		var button = slot_buttons[i]
		
		if save_manager.save_file_exists(slot_num):
			var save_info = save_manager.get_save_file_info(slot_num)
			var game_mode = save_info.get("game_mode", "Unknown")
			var wave_number = save_info.get("wave_number", 1)
			var gold = save_info.get("gold", 0)
			
			button.text = "SLOT %d: %s - Wave %d (%d Gold)" % [slot_num, game_mode, wave_number, gold]
			button.disabled = false
			button.modulate = Color.WHITE
			print("Save slot ", slot_num, ": Wave ", wave_number, " - ", game_mode)
		else:
			button.text = "SLOT %d: EMPTY" % slot_num
			button.disabled = true
			button.modulate = Color(0.5, 0.5, 0.5, 1.0)


func load_saved_game(slot: int = -1):
	"""Load a saved game and transition to main scene"""
	var save_manager = get_node("/root/SaveManager")
	if not save_manager:
		return
	
	# Store which save slot to load in a singleton for the main scene to pick up
	if slot == -1:
		# Load checkpoint if available, otherwise slot 1
		if save_manager.has_checkpoint_save():
			slot = 0
		else:
			slot = 1
	
	# Store the load flag for the main scene
	var game_mode_manager = get_node("/root/GameModeManager")
	if game_mode_manager:
		game_mode_manager.set_meta("load_save_slot", slot)
	
	get_tree().change_scene_to_file("res://scenes/main.tscn")


func _on_load_checkpoint_pressed() -> void:
	"""Load the checkpoint save"""
	load_saved_game(0)


func _on_load_slot_1_pressed() -> void:
	"""Load save slot 1"""
	load_saved_game(1)


func _on_load_slot_2_pressed() -> void:
	"""Load save slot 2"""
	load_saved_game(2)


func _on_load_slot_3_pressed() -> void:
	"""Load save slot 3"""
	load_saved_game(3)


func _on_settings_pressed() -> void:
	$CenterContainer/SettingsMenu.visible = true
	$CenterContainer/MainButtons.visible = false
	$CenterContainer/SettingsMenu/back.grab_focus()

func _on_house_skins_pressed() -> void:
	$CenterContainer/HouseSkinsMenu.visible = true
	$CenterContainer/MainButtons.visible = false
	_populate_skin_grid()
	$CenterContainer/HouseSkinsMenu/back.grab_focus()

func _on_credits_pressed() -> void:
	$CenterContainer/CreditsMenu.visible = true
	$CenterContainer/MainButtons.visible = false
	$CenterContainer/CreditsMenu/back.grab_focus()


func _on_quit_pressed() -> void:
	get_tree().quit() 


func _on_back_pressed() -> void:
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
		
	if $CenterContainer/HouseSkinsMenu.visible:
		$CenterContainer/HouseSkinsMenu.visible = false
		$CenterContainer/MainButtons/houseSkins.grab_focus()
		
	if $CenterContainer/GameModeMenu.visible:
		$CenterContainer/GameModeMenu.visible = false
		$CenterContainer/MainButtons/newGame.grab_focus()


# Preload game mode resources to avoid loading issues
const ENDLESS_MODE = preload("res://assets/gameMode/endlessMode.tres")
const NORMAL_MODE = preload("res://assets/gameMode/normalModeComplete.tres")
const EXTRA_HARD_MODE = preload("res://assets/gameMode/extraHardModeComplete.tres")

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
		var skin_button = Button.new()
		skin_button.custom_minimum_size = Vector2(180, 120)
		
		# Get skin info
		var skin_name = house_skin_manager.get_skin_name(skin_id)
		var is_unlocked = achievement_manager.is_skin_unlocked(skin_id)
		var is_selected = house_skin_manager.get_selected_skin() == skin_id
		
		# Set button text and appearance
		if is_unlocked:
			skin_button.text = skin_name
			skin_button.disabled = false
			
			# Highlight selected skin
			if is_selected:
				skin_button.modulate = Color.GREEN
			else:
				skin_button.modulate = Color.WHITE
				
			# Connect to selection function
			skin_button.pressed.connect(_on_skin_selected.bind(skin_id))
		else:
			skin_button.text = "LOCKED\n" + skin_name
			skin_button.disabled = true
			skin_button.modulate = Color.GRAY
		
		# Create a tooltip with skin description
		skin_button.tooltip_text = house_skin_manager.get_skin_description(skin_id)
		
		skin_grid.add_child(skin_button)

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
