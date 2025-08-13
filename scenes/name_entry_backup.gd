extends CenterContainer

@onready var name_input: LineEdit = $VBoxContainer/NameInputContainer/NameInput
@onready var create_button: Button = $VBoxContainer/ButtonContainer/CreateButton
@onready var error_label: Label = $VBoxContainer/ErrorLabel

func _ready():
	# Apply fantasy styling
	apply_fantasy_styling_alternative()
	
	# Focus the name input
	name_input.grab_focus()
	
	# Connect to ProfileManager signals
	var profile_manager = get_node("/root/ProfileManager")
	if profile_manager:
		profile_manager.profile_created.connect(_on_profile_created)

func apply_fantasy_styling_alternative():
	"""Alternative styling approach using ColorRect with custom draw"""
	print("=== STARTING ALTERNATIVE STYLING ===")
	
	# Get the background ColorRect
	var background = get_node("Background")
	print("Found background: ", background, " Type: ", background.get_class())
	
	# Set a dark brown base color
	background.color = Color(0.05, 0.03, 0.02, 1.0)
	
	# Create a custom style for gradient effect using Canvas
	var canvas = CanvasLayer.new()
	add_child(canvas)
	canvas.layer = -10  # Put it behind everything
	
	var control = Control.new()
	control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	canvas.add_child(control)
	
	# Connect custom draw
	control.draw.connect(_draw_gradient_background.bind(control))
	control.queue_redraw()
	
	print("=== ALTERNATIVE STYLING COMPLETE ===")

func _draw_gradient_background(control: Control):
	"""Custom draw function for gradient background"""
	var rect = control.get_rect()
	
	# Create gradient colors
	var colors = PackedColorArray([
		Color(0.05, 0.03, 0.02, 1.0),  # Very dark brown at top
		Color(0.12, 0.08, 0.05, 1.0),  # Medium brown
		Color(0.08, 0.05, 0.03, 1.0),  # Dark brown
		Color(0.04, 0.02, 0.01, 1.0)   # Very dark at bottom
	])
	
	# Draw vertical gradient
	var height_step = rect.size.y / (colors.size() - 1)
	
	for i in range(colors.size() - 1):
		var start_y = i * height_step
		var end_y = (i + 1) * height_step
		var start_color = colors[i]
		var end_color = colors[i + 1]
		
		# Draw gradient segment
		for y in range(int(start_y), int(end_y)):
			var t = float(y - start_y) / float(end_y - start_y)
			var color = start_color.lerp(end_color, t)
			control.draw_rect(Rect2(0, y, rect.size.x, 1), color)

# Rest of the functions remain the same...
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
