extends CenterContainer

@onready var name_input: LineEdit = $VBoxContainer/NameInputContainer/NameInput
@onready var create_button: Button = $VBoxContainer/ButtonContainer/CreateButton
@onready var error_label: Label = $VBoxContainer/ErrorLabel

func _ready():
	# Focus the name input
	name_input.grab_focus()
	
	# Connect to ProfileManager signals
	var profile_manager = get_node("/root/ProfileManager")
	if profile_manager:
		profile_manager.profile_created.connect(_on_profile_created)

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
		show_error("Please enter a name")
		return
	
	if entered_name.length() < 2:
		show_error("Name must be at least 2 characters long")
		return
	
	if entered_name.length() > 30:
		show_error("Name must be 30 characters or less")
		return
	
	# Check for invalid characters
	var invalid_chars = ["<", ">", ":", "\"", "/", "\\", "|", "?", "*"]
	for character in invalid_chars:
		if entered_name.contains(character):
			show_error("Name contains invalid characters")
			return
	
	# Clear any previous error
	error_label.text = " "
	
	# Disable input while creating
	name_input.editable = false
	create_button.disabled = true
	create_button.text = "Creating..."
	
	# Create the profile
	var profile_manager = get_node("/root/ProfileManager")
	if profile_manager:
		var success = profile_manager.create_profile(entered_name)
		if not success:
			show_error("Failed to create profile")
			# Re-enable input
			name_input.editable = true
			create_button.disabled = false
			create_button.text = "Create Profile"

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
	create_button.text = "Create Profile"
	
	# Refocus input
	name_input.grab_focus()
