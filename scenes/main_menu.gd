extends Node2D


func _ready() -> void:
	$CenterContainer/MainButtons/newGame.grab_focus()
	$CenterContainer/SettingsMenu/fullscreen.button_pressed = true if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN else false
	$CenterContainer/SettingsMenu/mainVolSlider.value = db_to_linear(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Master")))
	$CenterContainer/SettingsMenu/musicVolSlider.value = db_to_linear(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("MUSIC")))
	$CenterContainer/SettingsMenu/sfxVolSlider.value = db_to_linear(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("SFX")))
	

func _on_new_game_pressed() -> void:
	get_tree().change_scene_to_file(str("res://scenes/main.tscn")) 


func _on_load_game_pressed() -> void:
	$CenterContainer/MainButtons.visible = false
	$CenterContainer/LoadMenu.visible = true
	$CenterContainer/LoadMenu/back.grab_focus()


func _on_settings_pressed() -> void:
	$CenterContainer/SettingsMenu.visible = true
	$CenterContainer/MainButtons.visible = false
	$CenterContainer/SettingsMenu/back.grab_focus()


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
