extends CenterContainer

@onready var name_input: LineEdit = $VBoxContainer/NameInputContainer/NameInput
@onready var create_button: Button = $VBoxContainer/ButtonContainer/CreateButton
@onready var error_label: Label = $VBoxContainer/ErrorLabel

func _ready():
	# Apply fantasy styling
	apply_fantasy_styling()
	
	# Focus the name input
	name_input.grab_focus()
	
	# Connect to ProfileManager signals
	var profile_manager = get_node("/root/ProfileManager")
	if profile_manager:
		profile_manager.profile_created.connect(_on_profile_created)

func apply_fantasy_styling():
	"""Apply fantasy styling to UI elements"""
	print("=== STARTING FANTASY STYLING ===")
	
	# Background is now handled by the scene's GradientTexture2D resource
	# No need to create it programmatically
	print("Background gradient is set via scene resources")
	
	print("=== FANTASY STYLING COMPLETE ===")
	# Style the name input field
	var input_style_normal = StyleBoxFlat.new()
	input_style_normal.bg_color = Color(0.12, 0.08, 0.05, 1.0)  # Dark brown background
	input_style_normal.border_color = Color(0.6, 0.4, 0.2, 1.0)  # Brown border
	input_style_normal.set_border_width_all(3)
	input_style_normal.corner_radius_top_left = 8
	input_style_normal.corner_radius_top_right = 8
	input_style_normal.corner_radius_bottom_left = 8
	input_style_normal.corner_radius_bottom_right = 8
	
	var input_style_focus = StyleBoxFlat.new()
	input_style_focus.bg_color = Color(0.15, 0.1, 0.06, 1.0)  # Slightly lighter brown when focused
	input_style_focus.border_color = Color(0.8, 0.6, 0.3, 1.0)  # Gold border when focused
	input_style_focus.set_border_width_all(3)
	input_style_focus.corner_radius_top_left = 8
	input_style_focus.corner_radius_top_right = 8
	input_style_focus.corner_radius_bottom_left = 8
	input_style_focus.corner_radius_bottom_right = 8
	
	name_input.add_theme_stylebox_override("normal", input_style_normal)
	name_input.add_theme_stylebox_override("focus", input_style_focus)
	name_input.add_theme_color_override("font_color", Color(0.9, 0.8, 0.7, 1.0))  # Light brown text
	name_input.add_theme_color_override("font_placeholder_color", Color(0.6, 0.5, 0.4, 1.0))  # Darker placeholder
	
	# Style the create button
	var btn_style_normal = StyleBoxFlat.new()
	btn_style_normal.bg_color = Color(0.2, 0.15, 0.1, 1.0)  # Dark brown background
	btn_style_normal.border_color = Color(0.6, 0.4, 0.2, 1.0)  # Brown border
	btn_style_normal.set_border_width_all(3)
	btn_style_normal.corner_radius_top_left = 8
	btn_style_normal.corner_radius_top_right = 8
	btn_style_normal.corner_radius_bottom_left = 8
	btn_style_normal.corner_radius_bottom_right = 8
	
	var btn_style_hover = StyleBoxFlat.new()
	btn_style_hover.bg_color = Color(0.25, 0.2, 0.15, 1.0)  # Lighter brown on hover
	btn_style_hover.border_color = Color(0.8, 0.6, 0.3, 1.0)  # Gold border on hover
	btn_style_hover.set_border_width_all(3)
	btn_style_hover.corner_radius_top_left = 8
	btn_style_hover.corner_radius_top_right = 8
	btn_style_hover.corner_radius_bottom_left = 8
	btn_style_hover.corner_radius_bottom_right = 8
	
	var btn_style_pressed = StyleBoxFlat.new()
	btn_style_pressed.bg_color = Color(0.3, 0.25, 0.2, 1.0)  # Even lighter when pressed
	btn_style_pressed.border_color = Color(0.9, 0.7, 0.4, 1.0)  # Bright gold when pressed
	btn_style_pressed.set_border_width_all(3)
	btn_style_pressed.corner_radius_top_left = 8
	btn_style_pressed.corner_radius_top_right = 8
	btn_style_pressed.corner_radius_bottom_left = 8
	btn_style_pressed.corner_radius_bottom_right = 8
	
	var btn_style_disabled = StyleBoxFlat.new()
	btn_style_disabled.bg_color = Color(0.15, 0.12, 0.08, 1.0)  # Darker when disabled
	btn_style_disabled.border_color = Color(0.4, 0.3, 0.2, 1.0)  # Darker border when disabled
	btn_style_disabled.set_border_width_all(2)
	btn_style_disabled.corner_radius_top_left = 8
	btn_style_disabled.corner_radius_top_right = 8
	btn_style_disabled.corner_radius_bottom_left = 8
	btn_style_disabled.corner_radius_bottom_right = 8
	
	create_button.add_theme_stylebox_override("normal", btn_style_normal)
	create_button.add_theme_stylebox_override("hover", btn_style_hover)
	create_button.add_theme_stylebox_override("pressed", btn_style_pressed)
	create_button.add_theme_stylebox_override("disabled", btn_style_disabled)
	create_button.add_theme_color_override("font_color", Color(0.9, 0.8, 0.7, 1.0))  # Light brown text
	create_button.add_theme_color_override("font_hover_color", Color(0.95, 0.85, 0.75, 1.0))  # Lighter on hover
	create_button.add_theme_color_override("font_disabled_color", Color(0.5, 0.4, 0.3, 1.0))  # Darker when disabled

func _on_name_input_text_submitted(_text: String):
	"""Handle text submitted via Enter key"""
	_create_profile()

func _on_create_button_pressed():
	"""Handle create button pressed"""
	_create_profile()

func _create_profile():
	"""Attempt to create a profile with the entered name"""
	var entered_name = name_input.text.strip_edges()
	
	# Validate name
	if entered_name == "":
		show_error("⚔️ A hero must have a name!")
		return
	
	if entered_name.length() < 2:
		show_error("🛡️ Your name must be at least 2 characters, brave one!")
		return
	
	if entered_name.length() > 30:
		show_error("📜 Your name is too long for the ancient scrolls!")
		return
	
	# Check for invalid characters
	var invalid_chars = ["<", ">", ":", "\"", "/", "\\", "|", "?", "*"]
	for character in invalid_chars:
		if entered_name.contains(character):
			show_error("⚡ Your name contains forbidden runes!")
			return
	
	# Clear any previous error
	error_label.text = " "
	
	# Disable input while creating
	name_input.editable = false
	create_button.disabled = true
	create_button.text = "⚡ Forging Legend..."
	
	# Create the profile
	var profile_manager = get_node("/root/ProfileManager")
	if profile_manager:
		var success = profile_manager.create_profile(entered_name)
		if not success:
			show_error("💀 The ancient magic failed to forge your legend!")
			# Re-enable input
			name_input.editable = true
			create_button.disabled = false
			create_button.text = "⚔️ Begin Adventure"

func _on_profile_created(_profile_name: String):
	"""Handle successful profile creation"""
	# Transition to main menu
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")

func show_error(message: String):
	"""Display an error message"""
	error_label.text = message
	
	# Re-enable input
	name_input.editable = true
	create_button.disabled = false
	create_button.text = "⚔️ Begin Adventure"
	
	# Refocus input
	name_input.grab_focus()
