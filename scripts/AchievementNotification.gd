extends Control
class_name AchievementNotification

# Achievement notification popup with queuing support

@onready var background = $Background
@onready var title_label = $Background/VBox/Title
@onready var description_label = $Background/VBox/Description
@onready var skin_label = $Background/VBox/SkinUnlocked

var tween: Tween
var notification_queue: Array = []
var is_showing: bool = false
var current_timer: Timer  # Track the current notification's timer

signal notification_finished

func _ready():
	# Ensure notifications continue to work even when game is paused
	process_mode = Node.PROCESS_MODE_ALWAYS
	print("AchievementNotification: Ready, process_mode set to ALWAYS")
	
	# Style the background with a nice gray background
	if background:
		print("AchievementNotification: Background node found, type: ", background.get_class())
		
		# Check what type of node the background is and style accordingly
		if background is Panel:
			# Create a StyleBoxFlat for Panel
			var style_box = StyleBoxFlat.new()
			style_box.bg_color = Color(0.2, 0.2, 0.2, 0.9)  # Dark gray with slight transparency
			style_box.border_color = Color(0.4, 0.4, 0.4, 1.0)  # Lighter gray border
			style_box.border_width_left = 2
			style_box.border_width_right = 2
			style_box.border_width_top = 2
			style_box.border_width_bottom = 2
			style_box.corner_radius_top_left = 8
			style_box.corner_radius_top_right = 8
			style_box.corner_radius_bottom_left = 8
			style_box.corner_radius_bottom_right = 8
			style_box.content_margin_left = 12
			style_box.content_margin_right = 12
			style_box.content_margin_top = 8
			style_box.content_margin_bottom = 8
			background.add_theme_stylebox_override("panel", style_box)
			print("AchievementNotification: Applied Panel styling")
		elif background is Control:
			# For generic Control nodes, we need to use a different approach
			background.modulate = Color(0.2, 0.2, 0.2, 0.9)
			print("AchievementNotification: Applied Control modulate color")
		else:
			print("AchievementNotification: Unknown background node type: ", background.get_class())
	else:
		print("AchievementNotification: No background node found")
	
	# Apply background styling directly to this notification panel
	print("AchievementNotification: Applying styling to self, type: ", self.get_class())
	
	# Simple approach: Just set a background color on the background node
	if background:
		print("AchievementNotification: Found background node, type: ", background.get_class())
		# Try to make the background visible with a simple color
		background.modulate = Color.WHITE  # Make sure it's not transparent
		
		# Add a simple colored background using the Control's background
		if background is Control:
			# Try setting a theme override for background color
			background.add_theme_color_override("font_color", Color.WHITE)
			# Create a simple StyleBox for any Control
			var style_box = StyleBoxFlat.new()
			style_box.bg_color = Color(0.3, 0.3, 0.3, 0.9)  # Lighter gray for visibility
			if background is Panel:
				background.add_theme_stylebox_override("panel", style_box)
				print("AchievementNotification: Applied StyleBox to Panel background")
			else:
				print("AchievementNotification: Background is Control but not Panel: ", background.get_class())
	else:
		print("AchievementNotification: No background node found")
	
	# Don't add the fallback ColorRect - it's causing text visibility issues
	# _add_fallback_background()
	
	# Style the text labels to be bright and visible
	if title_label:
		title_label.add_theme_color_override("font_color", Color.WHITE)
		title_label.z_index = 1  # Ensure text is above background
	
	if description_label:
		description_label.add_theme_color_override("font_color", Color.WHITE)
		description_label.z_index = 1  # Ensure text is above background
	
	if skin_label:
		skin_label.add_theme_color_override("font_color", Color.YELLOW)  # Gold color for skin unlocks
		skin_label.z_index = 1  # Ensure text is above background

func _add_fallback_background():
	"""Add a ColorRect as a background if the Panel styling doesn't work"""
	# Create a ColorRect for background
	var bg_rect = ColorRect.new()
	bg_rect.color = Color(0.2, 0.2, 0.2, 0.8)  # Dark gray with some transparency
	bg_rect.name = "FallbackBackground"
	bg_rect.z_index = -1  # Ensure it's behind other elements
	
	# Make it fill the entire notification area
	bg_rect.anchor_left = 0
	bg_rect.anchor_top = 0
	bg_rect.anchor_right = 1
	bg_rect.anchor_bottom = 1
	bg_rect.offset_left = 0
	bg_rect.offset_top = 0
	bg_rect.offset_right = 0
	bg_rect.offset_bottom = 0
	
	# Add it as the first child (behind other elements)
	add_child(bg_rect)
	move_child(bg_rect, 0)
	
	print("AchievementNotification: Added fallback ColorRect background")

func _apply_background_styling():
	"""Apply background styling to the notification using ColorRect like tower menu"""
	print("AchievementNotification: Applying background styling")
	
	# Remove any existing background
	var existing_bg = get_node_or_null("NotificationBackground")
	if existing_bg:
		existing_bg.queue_free()
	
	# Create a ColorRect background like the tower menu does
	var bg = ColorRect.new()
	bg.name = "NotificationBackground"
	bg.color = Color(0.2, 0.2, 0.2, 0.8)  # Dark gray, semi-transparent like tower menu
	bg.z_index = -1  # Behind other content
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# Make it cover the entire notification
	bg.anchor_left = 0.0
	bg.anchor_top = 0.0
	bg.anchor_right = 1.0
	bg.anchor_bottom = 1.0
	bg.offset_left = 0.0
	bg.offset_top = 0.0
	bg.offset_right = 0.0
	bg.offset_bottom = 0.0
	
	# Add as first child so it's behind everything
	add_child(bg)
	move_child(bg, 0)
	
	print("AchievementNotification: Added ColorRect background like tower menu")
	
	# Style the text labels to be bright and visible
	if title_label:
		title_label.add_theme_color_override("font_color", Color.WHITE)
	
	if description_label:
		description_label.add_theme_color_override("font_color", Color.WHITE)
	
	if skin_label:
		skin_label.add_theme_color_override("font_color", Color.YELLOW)  # Gold color for skin unlocks

func _on_backup_timer_timeout():
	"""Backup timer in case tween fails to complete"""
	print("AchievementNotification: Backup timer triggered - tween may have failed")
	if is_showing:
		print("AchievementNotification: Forcing notification completion")
		visible = false
		is_showing = false
		if current_timer:
			current_timer.queue_free()
			current_timer = null
		notification_finished.emit()
		_show_next_notification()

func show_achievement(achievement_name: String, achievement_description: String, unlocked_skin_id: int = -1):
	"""Queue an achievement unlock notification"""
	var notification_data = {
		"name": achievement_name,
		"description": achievement_description,
		"skin_id": unlocked_skin_id
	}
	
	notification_queue.append(notification_data)
	print("AchievementNotification: Queued notification for: ", achievement_name, " (Queue size: ", notification_queue.size(), ")")
	
	# If not currently showing, start showing notifications
	if not is_showing:
		print("AchievementNotification: Starting to show notifications")
		_show_next_notification()
	else:
		print("AchievementNotification: Already showing notification, added to queue")

func _show_next_notification():
	"""Show the next notification in the queue"""
	if notification_queue.is_empty():
		print("AchievementNotification: Queue empty, stopping notifications")
		is_showing = false
		return
	
	is_showing = true
	var data = notification_queue.pop_front()
	print("AchievementNotification: Showing notification for: ", data.name, " (Remaining in queue: ", notification_queue.size(), ")")
	
	title_label.text = "Achievement Unlocked!"
	description_label.text = data.name + "\n" + data.description
	
	if data.skin_id > 0:
		skin_label.text = "New House Skin Unlocked: " + HouseSkinManager.get_skin_name(data.skin_id)
		skin_label.visible = true
	else:
		skin_label.visible = false
	
	# Apply background styling every time we show a notification
	_apply_background_styling()
	
	# Start position - off screen to the left
	var end_pos = Vector2(20, position.y)  # Fixed position - 20 pixels from left edge
	position.x = -size.x - 50  # Start completely off screen
	print("AchievementNotification: Set start position to: ", position.x, " end position will be: ", end_pos.x)
	
	# Make visible and reset alpha
	modulate.a = 1.0
	visible = true
	print("AchievementNotification: Set visible=true, alpha=", modulate.a, " for: ", data.name)
	
	if tween:
		tween.kill()
	
	tween = create_tween()
	tween.set_process_mode(Tween.TWEEN_PROCESS_IDLE)  # Continue during pause
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_QUART)
	
	# Add a finished signal to detect if tween gets killed
	tween.finished.connect(func(): print("AchievementNotification: Tween finished signal for: ", data.name))
	
	print("AchievementNotification: Starting tween animation for: ", data.name)
	
	# Create unique backup timer for this notification
	if current_timer:
		current_timer.queue_free()
	
	current_timer = Timer.new()
	current_timer.wait_time = 3.0  # Shorter timeout to match shorter display time
	current_timer.one_shot = true
	current_timer.process_mode = Node.PROCESS_MODE_ALWAYS
	current_timer.timeout.connect(_on_backup_timer_timeout)
	add_child(current_timer)
	current_timer.start()
	print("AchievementNotification: Backup timer started for: ", data.name)
	
	# Slide in from the left
	tween.tween_property(self, "position:x", end_pos.x, 0.4)
	print("AchievementNotification: Tween step 1 - slide in to position: ", end_pos.x)
	
	# Hold for 2 seconds (shorter display time)
	tween.tween_interval(2.0)
	print("AchievementNotification: Tween step 2 - hold for 2 seconds")
	
	# Slide out to the left
	tween.tween_property(self, "position:x", -size.x - 50, 0.3)
	print("AchievementNotification: Tween step 3 - slide out to position: ", -size.x - 50)
	
	# Hide and show next notification
	tween.tween_callback(func(): 
		print("AchievementNotification: Tween callback executed for: ", data.name)
		print("AchievementNotification: Final position: ", position.x, " visible: ", visible, " alpha: ", modulate.a)
		if current_timer:
			current_timer.stop()  # Cancel backup timer since tween completed
			current_timer.queue_free()
			current_timer = null
		print("AchievementNotification: Notification finished, checking for next...")
		visible = false
		notification_finished.emit()
		_show_next_notification()
	)
