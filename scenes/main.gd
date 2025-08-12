extends Node2D

# Game state
var gold : int = 300
var health : int = 100
var path_points = []

# Debug counter for health loss tracking
var health_loss_call_count = 0

# Gold feedback system to prevent overlapping
var gold_feedback_positions = []  # Track active gold feedback positions
var gold_feedback_spacing = 25    # Minimum distance between gold feedback texts

# For tower placement
var selected_tower_data : TowerData = null
var placing_tower : bool = false
var tower_preview : Node2D = null

var tower_menu_bg: ColorRect = null
# Track which tower currently has its menu open
var tower_menu_open_for: Node2D = null
var just_opened_tower_menu: bool = false

# Cooldown (in seconds) after opening the TowerMenu before it can be opened again, only for the same tower
var tower_menu_click_cooldown: float = 0.0
var tower_menu_cooldown_for: Node2D = null

# Game mode system
var current_game_mode = null

# Profile stat tracking
var start_time: float = 0.0
var session_play_time: float = 0.0  # Track play time for this session only

# Session-only stats (reset each game)
var session_enemies_killed: int = 0
var session_towers_built: int = 0
var session_gold_earned: int = 0
var session_gold_spent: int = 0
var session_waves_completed: int = 0
var session_starting_health: int = 100
var session_perfect_run: bool = true

var current_wave_number: int = 1
var current_wave_data = null
var wave_timer: float = 0.0
var is_wave_active: bool = false
var is_preparation_phase: bool = false
var enemies_remaining_in_wave: int = 0

# Endless mode specific variables
var endless_survival_time: float = 0.0
var endless_enemies_killed: int = 0
var endless_difficulty_level: int = 1
var endless_next_difficulty_time: float = 60.0  # Scale every 60 seconds

# Wave spawning variables
var current_spawn_group_index: int = 0
var enemies_spawned_in_group: int = 0
var spawn_timer: float = 0.0

# Tooltip system
var tower_tooltip = null
var tooltip_timer: Timer = null
var tooltip_pending_button: Control = null
var tooltip_pending_tower_data: TowerData = null
var tooltip_pending_level: int = 1
var tooltip_pending_is_upgrade: bool = false


func _ready():
	add_to_group("main_game")
	
	# Initialize session stats
	reset_session_stats()
	
	# Track profile stats for starting a new game
	var profile = get_node("/root/ProfileManager")
	if profile:
		profile.update_stat("games_played", 1)
		# Note: This stat will be saved at the next auto-save or victory/defeat screen
		start_time = Time.get_ticks_msec() / 1000.0  # Convert to seconds

func reset_session_stats():
	"""Reset all session statistics for a new game/load
	Note: Session stats are preserved across saves/loads within the same playthrough.
	They only reset when starting a completely new game."""
	session_enemies_killed = 0
	session_towers_built = 0
	session_gold_earned = 0
	session_gold_spent = 0
	session_waves_completed = 0
	session_starting_health = health  # Store starting health
	session_perfect_run = true
	session_play_time = 0.0
	
	load_map("res://scenes/map.tscn")
	update_ui()
	hide_all_grid_overlays()
	$TowerMenu.connect("gui_input", Callable(self, "_on_TowerMenu_gui_input"))
	$CanvasLayer/ui.connect("gui_input", Callable(self, "_on_ui_gui_input"))
	update_tower_button_costs()
	
	# Initialize tooltip system
	setup_tooltip_system()
	
	# Initialize achievement system
	setup_achievement_system()
	
	# Add restart checkpoint button to pause menu
	add_restart_checkpoint_button()
	
	# Check if we should load a saved game
	var game_mode_manager = get_node("/root/GameModeManager")
	var should_load_save = false
	var should_load_checkpoint = false
	var save_slot = -1
	
	if game_mode_manager and game_mode_manager.has_meta("load_save_slot"):
		save_slot = game_mode_manager.get_meta("load_save_slot")
		game_mode_manager.remove_meta("load_save_slot")
		should_load_save = true
	elif game_mode_manager and game_mode_manager.has_meta("load_checkpoint"):
		game_mode_manager.remove_meta("load_checkpoint")
		should_load_checkpoint = true
	
	if should_load_save:
		# Load the saved game
		var save_manager = get_node("/root/SaveManager")
		if save_manager:
			var success = save_manager.load_game(save_slot, self)
			if success:
				# Don't reset session stats when loading a game - they should be restored from save
				# The game state has been loaded, return early
				return
			else:
				# Load failed, continue with normal initialization
				show_notification("Failed to load save!")
	elif should_load_checkpoint:
		# Load the checkpoint save
		var save_manager = get_node("/root/SaveManager")
		if save_manager:
			var success = save_manager.load_checkpoint_save(self)
			if success:
				# Don't reset session stats when loading a checkpoint - they should be restored from save
				# The checkpoint has been loaded, return early
				return
			else:
				# Load failed, continue with normal initialization
				show_notification("Failed to load checkpoint!")
	
	# Initialize game mode system (only if not loaded from save)
	initialize_game_mode()
	
	# Initial UI update for game mode
	if current_game_mode != null:
		update_game_mode_ui()

# Preload fallback game mode
const DEFAULT_GAME_MODE = preload("res://assets/gameMode/normalMode.tres")

# Game mode system functions
func initialize_game_mode():
	# Get the current mode from the singleton
	# Using get_node to access the autoload
	var game_mode_manager = get_node("/root/GameModeManager")
	if game_mode_manager:
		current_game_mode = game_mode_manager.current_mode
	
	if current_game_mode == null:
		current_game_mode = DEFAULT_GAME_MODE
		if game_mode_manager:
			game_mode_manager.current_mode = current_game_mode

	
	# Ensure enemy spawn timer is stopped initially
	$EnemySpawnTimer.stop()
	
	# Start the appropriate game mode
	match current_game_mode.mode_type:
		"endless":
			start_endless_mode()
		"normal", "extra_hard":
			start_wave_mode()
	
	update_ui()

func start_endless_mode():
	current_wave_number = 1
	is_wave_active = false
	is_preparation_phase = true
	wave_timer = 15.0  # 15 second preparation time
	
	# Initialize endless mode stats
	endless_survival_time = 0.0
	endless_enemies_killed = 0
	endless_difficulty_level = 1
	
	# Show preparation notification
	show_notification("Prepare Your Defenses!\nEndless Mode Starting...")

func start_wave_mode():
	current_wave_number = 1
	is_wave_active = false
	is_preparation_phase = true
	
	# Show preparation notification
	show_notification("Prepare Your Defenses!")
	
	# Load first wave
	if current_game_mode.wave_definitions.size() > 0:
		current_wave_data = current_game_mode.wave_definitions[current_wave_number - 1]
		wave_timer = current_wave_data.preparation_time


func start_endless_wave():
	is_wave_active = true
	is_preparation_phase = false
	
	# For endless mode, spawn a variety of enemies with scaling
	spawn_endless_enemies()
	
	# Set timer for next wave
	wave_timer = current_game_mode.endless_wave_interval

func start_endless_continuous_mode():
	"""Start the continuous endless mode after preparation"""
	is_wave_active = true
	is_preparation_phase = false
	
	# Start continuous spawning
	$EnemySpawnTimer.wait_time = get_endless_spawn_interval()
	$EnemySpawnTimer.start()

func get_endless_spawn_interval() -> float:
	"""Get spawn interval based on current difficulty level"""
	# Start with 3 seconds, decrease as difficulty increases
	var base_interval = 3.0
	var reduction_per_level = 0.2
	return max(0.8, base_interval - (endless_difficulty_level - 1) * reduction_per_level)

func get_endless_scaled_health(base_health: int) -> int:
	"""Get scaled health for endless mode based on time-based difficulty"""
	# Start with reduced health in early levels, then scale up
	var health_multiplier = 1.0
	
	if endless_difficulty_level == 1:
		# First minute: 70% health
		health_multiplier = 0.7
	elif endless_difficulty_level == 2:
		# Second minute: 85% health  
		health_multiplier = 0.85
	else:
		# After 2 minutes: scale up by 20% per level
		health_multiplier = 1.0 + (endless_difficulty_level - 3) * 0.2
	
	return int(base_health * health_multiplier)

func spawn_endless_enemies():
	# Simple endless mode implementation - spawn random enemies with scaling
	var enemy_count = 5 + (current_wave_number * 2)  # Increasing enemy count
	var spawn_interval = max(0.5, 2.0 - (current_wave_number * 0.1))  # Decreasing spawn interval
	
	enemies_remaining_in_wave = enemy_count
	
	# Use the enemy spawn timer for spacing
	$EnemySpawnTimer.wait_time = spawn_interval
	$EnemySpawnTimer.start()

func start_wave():
	if current_wave_data == null:
		return
		
	is_wave_active = true
	is_preparation_phase = false
	
	# Reset spawn tracking
	current_spawn_group_index = 0
	enemies_spawned_in_group = 0
	spawn_timer = 0.0
	
	# Calculate total enemies in wave
	enemies_remaining_in_wave = 0
	for spawn_group in current_wave_data.enemy_groups:
		enemies_remaining_in_wave += spawn_group.count
	
	
	# Start spawning immediately (no group delay)
	if current_wave_data.enemy_groups.size() > 0:
		spawn_timer = current_wave_data.spawn_interval

func handle_game_mode_timing(delta):
	if current_game_mode == null:
		return
		
	wave_timer -= delta
	
	if current_game_mode.mode_type == "endless":
		# Endless mode timing
		if is_preparation_phase and wave_timer <= 0:
			# Start endless mode after preparation
			start_endless_continuous_mode()
		elif is_wave_active:
			# Update survival time and difficulty scaling
			endless_survival_time += delta
			
			# Check if it's time to increase difficulty
			if endless_survival_time >= endless_next_difficulty_time:
				endless_difficulty_level += 1
				endless_next_difficulty_time += 60.0  # Next scaling in 60 seconds
				show_notification("Difficulty Increased!\nLevel " + str(endless_difficulty_level))
			
			# Handle continuous enemy spawning
			handle_endless_continuous_spawning(delta)
			
			# Auto-save in endless mode every 2 minutes
			if int(endless_survival_time) % 120 == 0 and endless_survival_time > 0:
				var save_manager = get_node("/root/SaveManager")
				if save_manager:
					# Create checkpoint save (session stats are included automatically)
					save_manager.create_checkpoint_save(self)
	else:
		# Wave-based mode timing
		if is_preparation_phase and wave_timer <= 0:
			start_wave()
		elif is_wave_active:
			# Handle wave spawning
			handle_wave_spawning(delta)
			
			# Check if wave is complete
			if enemies_remaining_in_wave <= 0:
				wave_complete()
	
	# Update UI
	update_game_mode_ui()

func handle_endless_spawning(_delta):
	# Simple spawning logic for endless mode
	pass  # This will be handled by the existing EnemySpawnTimer

func handle_endless_continuous_spawning(_delta):
	"""Handle continuous spawning for endless mode - adjust spawn rate based on difficulty"""
	# Update spawn interval based on current difficulty
	if $EnemySpawnTimer.wait_time != get_endless_spawn_interval():
		$EnemySpawnTimer.wait_time = get_endless_spawn_interval()

func handle_wave_spawning(delta):
	if current_spawn_group_index >= current_wave_data.enemy_groups.size():
		return  # All groups spawned
		
	var current_group = current_wave_data.enemy_groups[current_spawn_group_index]
	
	# Handle spawning within group
	spawn_timer -= delta
	if spawn_timer <= 0 and enemies_spawned_in_group < current_group.count:
		# Spawn enemy using the new system
		spawn_enemy_with_scaling(path_points, current_group.get_enemy_path())
		enemies_spawned_in_group += 1
		spawn_timer = current_wave_data.spawn_interval
		
		# Check if group is complete
		if enemies_spawned_in_group >= current_group.count:
			current_spawn_group_index += 1
			enemies_spawned_in_group = 0
			# No delay - immediately start next group

func spawn_enemy_with_scaling(enemy_path_points, enemy_data_path: String):
	# Load enemy data
	var enemy_data = load(enemy_data_path) as Resource
	if not enemy_data:
		return
	
	# Apply scaling based on game mode
	var scaled_health
	if current_game_mode.mode_type == "endless":
		# For endless mode, use time-based difficulty scaling
		scaled_health = get_endless_scaled_health(enemy_data.max_health)
	else:
		# For wave modes, use wave-based scaling
		scaled_health = current_game_mode.get_scaled_health(enemy_data.max_health, current_wave_number)
	
	# Spawn enemy with scaling
	spawn_enemy(enemy_path_points, enemy_data_path, scaled_health)

func wave_complete():
	is_wave_active = false
	
	# Track session stats
	session_waves_completed += 1
	
	# Track achievement progress for wave completion
	var achievement_manager = get_node("/root/AchievementManager")
	if achievement_manager:
		var mode_name = current_game_mode.mode_name if current_game_mode else "Unknown"
		achievement_manager.track_wave_survived(current_wave_number, mode_name)
	
	# Track profile stats for wave completion
	var profile_manager = get_node("/root/ProfileManager")
	if profile_manager:
		profile_manager.update_stat("total_waves_survived", 1)
		var current_highest = profile_manager.get_stat("highest_wave_reached")
		if current_wave_number > current_highest:
			profile_manager.set_stat("highest_wave_reached", current_wave_number)
	
	# Note: Endless mode no longer uses wave completion - it's continuous
	if current_game_mode.mode_type != "endless":
		# In wave mode, check if there are more waves
		current_wave_number += 1
		if current_wave_number <= current_game_mode.wave_definitions.size():
			# Load next wave
			current_wave_data = current_game_mode.wave_definitions[current_wave_number - 1]
			is_preparation_phase = true
			wave_timer = current_wave_data.preparation_time
			
			# Show preparation notification
			show_notification("Prepare Your Defenses\nWave " + str(current_wave_number) + " incoming!")
		else:
			# All waves complete - victory!
			print("All waves complete! Victory!")
			victory()
			return
	
	# Create checkpoint save AFTER wave progression is set up
	var save_manager = get_node("/root/SaveManager")
	if save_manager:
		# Create checkpoint save (session stats are included automatically)
		save_manager.create_checkpoint_save(self)
		print("Checkpoint saved after wave ", current_wave_number - 1, " completed, ready for wave ", current_wave_number)

func update_game_mode_ui():
	# Update round/timer display
	if current_game_mode == null:
		return
		
	var round_label = $CanvasLayer/ui/round
	var timer_label = $CanvasLayer/ui/timer
	
	if current_game_mode.mode_type == "endless":
		round_label.text = ""  # Hide the mode text for endless
		if is_preparation_phase:
			timer_label.text = "Prepare: " + str(int(wave_timer)) + "s"
		else:
			# Show survival time and enemies killed
			var minutes = int(endless_survival_time / 60)
			var seconds = int(endless_survival_time) % 60
			timer_label.text = "Time: %02d:%02d | Kills: %d" % [minutes, seconds, endless_enemies_killed]
	else:
		round_label.text = "Round: " + str(current_wave_number) + "/" + str(current_game_mode.wave_definitions.size())
		if is_preparation_phase:
			timer_label.text = "Prepare: " + str(int(wave_timer)) + "s"
		elif is_wave_active:
			timer_label.text = "Enemies: " + str(enemies_remaining_in_wave)
		else:
			timer_label.text = "Complete!"

# Dynamically set the cost label for each tower button in the build menu and update button states
func update_tower_button_costs():
	var tower_paths = [
		"res://assets/towers/tower1/tower1.tres",
		"res://assets/towers/tower2/tower2.tres",
		"res://assets/towers/tower3/tower3.tres",
		"res://assets/towers/tower4/tower4.tres",
		"res://assets/towers/tower5/tower5.tres",
		"res://assets/towers/tower6/tower6.tres",
		"res://assets/towers/tower7/tower7.tres",
		"res://assets/towers/tower8/tower8.tres",
	]
	for i in range(tower_paths.size()):
		var tower_data = load(tower_paths[i])
		var button = $CanvasLayer.get_node("ui/MarginContainer/buildMenu/towerButton%d" % (i+1))
		var tower_cost = tower_data.cost[0]
		var can_afford_tower = can_afford(tower_cost)
		
		# Update cost label
		if button.has_node("towerCost"):
			var cost_label = button.get_node("towerCost")
			cost_label.text = str(tower_cost)
			# Change color based on affordability
			if can_afford_tower:
				cost_label.add_theme_color_override("font_color", Color.WHITE)
			else:
				cost_label.add_theme_color_override("font_color", Color.RED)
		
		# Update button state - disable if can't afford
		button.disabled = not can_afford_tower
		
		# Update button visual appearance
		if can_afford_tower:
			button.modulate = Color.WHITE
		else:
			button.modulate = Color(0.5, 0.5, 0.5, 1.0)  # Grey out the button


func hide_tower_menu_with_bg():
	# Hide tooltip when hiding tower menu
	hide_tooltip()
	
	$TowerMenu.visible = false
	if tower_menu_bg and is_instance_valid(tower_menu_bg):
		tower_menu_bg.queue_free()
		tower_menu_bg = null
	# Hide attack range for the previously selected tower
	if selected_tower and is_instance_valid(selected_tower) and selected_tower.has_method("hide_attack_range"):
		selected_tower.hide_attack_range()
	# Clear selected_tower
	selected_tower = null
	tower_menu_open_for = null


# Notification system
var notification_panel: Panel = null
var notification_label: Label = null
var notification_tween: Tween = null

func show_notification(text: String, duration: float = 3.0):
	"""Show a notification popup centered on the screen"""
	# Remove existing notification if any
	hide_notification()
	
	# Create a panel for the background box
	notification_panel = Panel.new()
	notification_panel.size = Vector2(600, 160)  # Taller for two-line text
	
	# Get screen size and center the panel manually
	var screen_size = get_viewport().get_visible_rect().size
	var panel_center_x = (screen_size.x - notification_panel.size.x) / 2
	var panel_y = 50  # Distance from top
	
	# Position the panel at the calculated center position
	notification_panel.position = Vector2(panel_center_x, panel_y)
	notification_panel.z_index = 100
	
	# Style the panel with black background
	var style_box = StyleBoxFlat.new()
	style_box.bg_color = Color.BLACK
	style_box.border_color = Color.WHITE
	style_box.border_width_left = 2
	style_box.border_width_right = 2
	style_box.border_width_top = 2
	style_box.border_width_bottom = 2
	style_box.corner_radius_top_left = 8
	style_box.corner_radius_top_right = 8
	style_box.corner_radius_bottom_left = 8
	style_box.corner_radius_bottom_right = 8
	notification_panel.add_theme_stylebox_override("panel", style_box)
	
	# Create the notification label
	notification_label = Label.new()
	notification_label.text = text
	notification_label.add_theme_font_size_override("font_size", 36)  # Larger font
	notification_label.add_theme_color_override("font_color", Color.WHITE)  # White text
	notification_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	notification_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	notification_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART  # Enable text wrapping
	notification_label.size = notification_panel.size
	notification_label.position = Vector2.ZERO
	
	# Add label to panel, panel to scene
	notification_panel.add_child(notification_label)
	$CanvasLayer.add_child(notification_panel)
	
	# Create fade in/out animation
	notification_panel.modulate.a = 0.0
	notification_tween = create_tween()
	notification_tween.tween_property(notification_panel, "modulate:a", 1.0, 0.5)
	notification_tween.tween_interval(duration - 1.0)  # Stay visible for most of the duration
	notification_tween.tween_property(notification_panel, "modulate:a", 0.0, 0.5)
	notification_tween.tween_callback(hide_notification)

func hide_notification():
	"""Hide the current notification"""
	if notification_panel and is_instance_valid(notification_panel):
		notification_panel.queue_free()
		notification_panel = null
	if notification_label and is_instance_valid(notification_label):
		notification_label = null
	if notification_tween:
		notification_tween.kill()
		notification_tween = null


func _process(delta):
	if placing_tower and tower_preview:
		var mouse_pos = get_global_mouse_position()
		tower_preview.position = get_snapped_position(mouse_pos)
		tower_preview.visible = true
		tower_preview.queue_redraw()
	# Decrement tower menu click cooldown
	if tower_menu_click_cooldown > 0.0:
		tower_menu_click_cooldown = max(0.0, tower_menu_click_cooldown - delta)
		if tower_menu_click_cooldown == 0.0:
			tower_menu_cooldown_for = null
	
	# Track play time for this session (but don't save continuously)
	session_play_time += delta
	
	# Handle game mode timing
	if current_game_mode != null:
		handle_game_mode_timing(delta)


# Returns true if mouse is over any tower
func is_mouse_over_any_tower(mouse_pos):
	for tower in $TowerContainer.get_children():
		if tower.has_method("get_global_rect") and tower.get_global_rect().has_point(mouse_pos):
			return true
	return false


# Handles UI events for the main UI panel, closes menu if click is outside the TowerMenu
func _on_ui_gui_input(event):
	if $TowerMenu.visible and event is InputEventMouseButton and event.pressed:
		var mouse_pos = get_viewport().get_mouse_position()
		if not is_mouse_over_menu($TowerMenu, mouse_pos):
			hide_tower_menu_with_bg()


# Handles UI events for TowerMenu, closes menu if click is outside
func _on_TowerMenu_gui_input(event):
	if $TowerMenu.visible and event is InputEventMouseButton and event.pressed:
		var mouse_pos = get_viewport().get_mouse_position()
		if not is_mouse_over_menu($TowerMenu, mouse_pos):
			hide_tower_menu_with_bg()


# Returns true if mouse is over any visible part of the menu or its children
func is_mouse_over_menu(node, mouse_pos):
	if node is Control:
		if not node.visible:
			return false
		if node.get_global_rect().has_point(mouse_pos):
			return true
	if node.has_method("get_children"):
		for child in node.get_children():
			if is_mouse_over_menu(child, mouse_pos):
				return true
	return false


func load_level(level_path):
	# Remove any existing level
	for child in $LevelContainer.get_children():
		child.queue_free()
	# Load and add the new level
	var level = load(level_path).instantiate()
	$LevelContainer.add_child(level)


func is_tower_at_position(pos: Vector2) -> bool:
	for tower in $TowerContainer.get_children():
		# Only check actual tower nodes, not construction/destruction animations
		if tower.has_method("attack_target") and not tower.is_being_destroyed and tower.position == pos:
			return true
	return false


func build_path(tilemap_ground, tilemap_bridge, start_cell):
	path_points.clear()
	var ordered_cells = order_path_points(tilemap_ground, tilemap_bridge, start_cell)
	var i = 0
	while i < ordered_cells.size():
		var cell = ordered_cells[i]
		var data_bridge = tilemap_bridge.get_cell_tile_data(cell)
		var data_ground = tilemap_ground.get_cell_tile_data(cell)
		var world_pos = null

		# Detect horizontal bridge sequence
		if data_bridge and data_bridge.get_custom_data("is_path") == true:
			# Find length of horizontal bridge
			var bridge_start = i
			var bridge_end = i
			while bridge_end + 1 < ordered_cells.size():
				var next_cell = ordered_cells[bridge_end + 1]
				var next_data = tilemap_bridge.get_cell_tile_data(next_cell)
				if next_data and next_data.get_custom_data("is_path") == true and next_cell.y == cell.y and next_cell.x == ordered_cells[bridge_end].x + 1:
					bridge_end += 1
				else:
					break
			var bridge_len = bridge_end - bridge_start + 1
			if bridge_len > 1:
				var ramp_up_offset = Vector2(36, -18)
				var flat_offset = Vector2(36, -18)
				var ramp_down_offset = Vector2(0, 0) # Try Vector2(0, 0) or tweak as needed
				for j in range(bridge_start, bridge_end + 1):
					var bridge_cell = ordered_cells[j]
					var base_pos = tilemap_bridge.map_to_local(bridge_cell)
					if j == bridge_start:
						path_points.append(base_pos + ramp_up_offset)
					elif j == bridge_end:
						path_points.append(base_pos + ramp_down_offset)
					else:
						path_points.append(base_pos + flat_offset)
				i = bridge_end + 1
				continue

		# Default logic for ground and vertical bridges
		if data_bridge and data_bridge.get_custom_data("is_path") == true:
			world_pos = tilemap_bridge.map_to_local(cell)
		elif data_ground and data_ground.get_custom_data("is_path") == true:
			world_pos = tilemap_ground.map_to_local(cell)
		if world_pos != null:
			path_points.append(world_pos)
		i += 1


# Orders path points from start to finish by walking neighbors
func order_path_points(tilemap_ground, tilemap_bridge, start_cell):
	var ordered = [start_cell]
	var visited = {start_cell: true}
	var current = start_cell
	while true:
		var found = false
		for offset in [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]:
			var neighbor = current + offset
			var data_ground = tilemap_ground.get_cell_tile_data(neighbor)
			var data_bridge = tilemap_bridge.get_cell_tile_data(neighbor)
			var is_path = (data_ground and data_ground.get_custom_data("is_path") == true) or (data_bridge and data_bridge.get_custom_data("is_path") == true)
			if is_path and not visited.has(neighbor):
				ordered.append(neighbor)
				visited[neighbor] = true
				current = neighbor
				found = true
				break
		if not found:
			break
	return ordered


func is_position_on_road_tile(world_position: Vector2) -> bool:
	"""Check if a world position is on a road tile"""
	var tilemap_ground = $LevelContainer/map/tileLayer1
	var tilemap_bridge = null
	if $LevelContainer/map.has_node("tileLayer2"):
		tilemap_bridge = $LevelContainer/map/tileLayer2
	
	# Convert world position to tile coordinates
	var cell_ground = tilemap_ground.local_to_map(world_position)
	var data_ground = tilemap_ground.get_cell_tile_data(cell_ground)
	
	# Check ground layer first
	if data_ground and data_ground.get_custom_data("is_path") == true:
		return true
	
	# Check bridge layer if it exists
	if tilemap_bridge:
		var cell_bridge = tilemap_bridge.local_to_map(world_position)
		var data_bridge = tilemap_bridge.get_cell_tile_data(cell_bridge)
		if data_bridge and data_bridge.get_custom_data("is_path") == true:
			return true
	
	return false


func can_afford(cost: int) -> bool:
	return gold >= cost


func spend_gold(amount: int):
	gold -= amount
	session_gold_spent += amount
	update_ui()
	# Also update tower upgrade UI if tower menu is open
	update_tower_upgrade_ui()


func earn_gold(amount: int):
	gold += amount
	session_gold_earned += amount
	update_ui()
	# Also update tower upgrade UI if tower menu is open
	update_tower_upgrade_ui()
	update_ui()


func take_damage(amount: int):
	health -= amount
	if session_perfect_run and health < session_starting_health:
		session_perfect_run = false
	update_ui()
	if health <= 0:
		game_over()

func lose_health(amount: int):
	"""Called when enemies reach the house"""
	health_loss_call_count += 1
	
	# Apply damage scaling based on game mode
	var scaled_damage = amount
	if current_game_mode != null:
		scaled_damage = current_game_mode.get_scaled_damage(amount)
	
	# Show damage feedback with actual amount
	show_damage_feedback(scaled_damage)
	
	take_damage(scaled_damage)
	
	# Track enemy reaching house for wave completion
	if current_game_mode != null and is_wave_active:
		enemies_remaining_in_wave -= 1

func show_damage_feedback(damage: int):
	"""Show visual feedback when player takes damage"""
	# Find the house position to display damage text above it
	var house_position = Vector2(get_viewport().size.x / 2, 100)  # Default position
	var houses = get_tree().get_nodes_in_group("houses")
	if houses.size() > 0:
		var house = houses[0]
		house_position = house.global_position
		house_position.y -= 50  # Position above the house
	
	# Create a damage indicator label
	var damage_label = Label.new()
	damage_label.text = "-" + str(damage) + " HP"
	damage_label.add_theme_font_size_override("font_size", 24)
	damage_label.add_theme_color_override("font_color", Color.RED)
	damage_label.position = house_position
	damage_label.z_index = 99
	
	# Center the text horizontally
	damage_label.pivot_offset = damage_label.get_theme_font("font").get_string_size(damage_label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, damage_label.get_theme_font_size("font_size")) / 2
	
	add_child(damage_label)  # Add to main scene instead of CanvasLayer for world positioning
	
	# Animate the damage text
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(damage_label, "position:y", damage_label.position.y - 50, 1.0)
	tween.tween_property(damage_label, "modulate:a", 0.0, 1.0)
	tween.connect("finished", func(): damage_label.queue_free())

func show_gold_feedback(gold_earned: int):
	"""Show visual feedback when player gains gold"""
	# Get the gold container position from the UI
	var gold_container = $CanvasLayer/ui/goldContainer
	if not gold_container:
		return
	
	# Get the base position for gold feedback
	var base_position = gold_container.global_position
	base_position.x += gold_container.size.x / 2  # Center horizontally over the container
	base_position.y -= 10  # Position slightly above the container
	
	# Find a position that doesn't overlap with existing gold feedback
	var final_position = find_available_gold_position(base_position)
	
	# Create a gold gain indicator label
	var gold_label = Label.new()
	gold_label.text = "+" + str(gold_earned)
	gold_label.add_theme_font_size_override("font_size", 22)
	gold_label.add_theme_color_override("font_color", Color.GOLD)
	gold_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	gold_label.add_theme_constant_override("shadow_offset_x", 1)
	gold_label.add_theme_constant_override("shadow_offset_y", 1)
	gold_label.position = final_position
	gold_label.z_index = 100
	gold_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	
	# Add to the CanvasLayer to ensure it appears on top of the UI
	$CanvasLayer.add_child(gold_label)
	
	# Register this position as occupied
	gold_feedback_positions.append(final_position)
	
	# Animate the gold text (float up and fade out)
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(gold_label, "position:y", gold_label.position.y - 50, 1.5)
	tween.tween_property(gold_label, "modulate:a", 0.0, 1.5)
	
	# Scale animation for emphasis
	var scale_tween = create_tween()
	scale_tween.tween_property(gold_label, "scale", Vector2(1.2, 1.2), 0.3)
	scale_tween.tween_property(gold_label, "scale", Vector2(1.0, 1.0), 0.3)
	
	# Clean up when finished
	tween.connect("finished", func(): 
		gold_label.queue_free()
		# Remove this position from the occupied list
		gold_feedback_positions.erase(final_position)
	)

func find_available_gold_position(base_position: Vector2) -> Vector2:
	"""Find a position for gold feedback that doesn't overlap with existing ones"""
	var attempt_position = base_position
	var max_attempts = 10
	var attempts = 0
	
	while attempts < max_attempts:
		var position_available = true
		
		# Check if this position is too close to any existing gold feedback
		for existing_pos in gold_feedback_positions:
			if attempt_position.distance_to(existing_pos) < gold_feedback_spacing:
				position_available = false
				break
		
		if position_available:
			return attempt_position
		
		# Try a new position - spread out horizontally and vertically
		var offset_x = randf_range(-40, 40)  # Random horizontal offset
		var offset_y = randf_range(-20, 20)  # Random vertical offset
		attempt_position = base_position + Vector2(offset_x, offset_y)
		attempts += 1
	
	# If we can't find a good position after max attempts, just use the base position
	return base_position


func update_ui():
	# Update your UI elements here (e.g., money/health labels)
	$CanvasLayer/ui/goldContainer/goldLabel.text = str(gold)
	
	# Update tower button states based on current gold
	update_tower_button_costs()
	
	# Update health bar
	var health_bar = $CanvasLayer/ui/HealthBar
	var health_label = $CanvasLayer/ui/HealthBar/Label
	if health_bar:		
		health_bar.max_value = 100  # Assuming max health is 100
		health_bar.step = 1.0  # Ensure step is 1
		
		# Use call_deferred to ensure the UI updates properly
		health_bar.call_deferred("set_value", health)
		
		# Update health label to show current/max health
		if health_label:
			health_label.text = str(health) + "/100"
		
		# Change health bar color based on health level by modifying the fill style
		var health_percentage = float(health) / 100.0
		var fill_style = health_bar.get_theme_stylebox("fill")
		if fill_style:
			var new_style = fill_style.duplicate()
			if health_percentage > 0.6:
				new_style.bg_color = Color.GREEN
			elif health_percentage > 0.3:
				new_style.bg_color = Color.YELLOW
			else:
				new_style.bg_color = Color.RED
			health_bar.add_theme_stylebox_override("fill", new_style)
		else:
			# Fallback to self_modulate if no style found
			if health_percentage > 0.6:
				health_bar.self_modulate = Color.GREEN
			elif health_percentage > 0.3:
				health_bar.self_modulate = Color.YELLOW
			else:
				health_bar.self_modulate = Color.RED

func update_tower_upgrade_ui():
	"""Update the tower upgrade button state when gold changes"""
	if not selected_tower or not $TowerMenu.visible:
		return
		
	var menu = $TowerMenu
	var upgrade_button = menu.get_node("upgradeButton")
	
	if selected_tower.level >= 3:
		# Tower is max level, no changes needed
		return
	
	# Update upgrade button affordability
	var next_level = selected_tower.level + 1
	var upgrade_cost = selected_tower.tower_data.cost[next_level - 1] if selected_tower.tower_data.cost.size() >= next_level else 0
	var can_afford_upgrade = can_afford(upgrade_cost)
	
	upgrade_button.disabled = not can_afford_upgrade
	
	# Update visual appearance
	var upgrade_cost_label = upgrade_button.get_node("upgradeCost") if upgrade_button.has_node("upgradeCost") else null
	if can_afford_upgrade:
		upgrade_button.modulate = Color.WHITE
		if upgrade_cost_label:
			upgrade_cost_label.add_theme_color_override("font_color", Color.WHITE)
	else:
		upgrade_button.modulate = Color(0.5, 0.5, 0.5, 1.0)
		if upgrade_cost_label:
			upgrade_cost_label.add_theme_color_override("font_color", Color.RED)
	
	# Update health bar
	var health_bar = $CanvasLayer/ui/HealthBar
	var health_label = $CanvasLayer/ui/HealthBar/Label
	if health_bar:		
		health_bar.max_value = 100  # Assuming max health is 100
		health_bar.step = 1.0  # Ensure step is 1
		
		# Use call_deferred to ensure the UI updates properly
		health_bar.call_deferred("set_value", health)
		
		# Update health label to show current/max health
		if health_label:
			health_label.text = str(health) + "/100"
		
		# Change health bar color based on health level by modifying the fill style
		var health_percentage = float(health) / 100.0
		var fill_style = health_bar.get_theme_stylebox("fill")
		if fill_style:
			var new_style = fill_style.duplicate()
			if health_percentage > 0.6:
				new_style.bg_color = Color.GREEN
			elif health_percentage > 0.3:
				new_style.bg_color = Color.YELLOW
			else:
				new_style.bg_color = Color.RED
			health_bar.add_theme_stylebox_override("fill", new_style)
		else:
			# Fallback to self_modulate if no style found
			if health_percentage > 0.6:
				health_bar.self_modulate = Color.GREEN
			elif health_percentage > 0.3:
				health_bar.self_modulate = Color.YELLOW
			else:
				health_bar.self_modulate = Color.RED


func game_over():
	"""Handle game over logic"""
	
	# Track profile stats for loss
	var profile = get_node("/root/ProfileManager")
	if profile:
		profile.update_stat("times_lost", 1)
		# Track play time for this session only
		profile.add_play_time(session_play_time)
		# Save stats to disk (this is one of the allowed save times)
		profile.save_profile_stats()
	
	# Pause the game
	get_tree().paused = true
	
	# Create and show game over screen
	show_game_over_screen()

func victory():
	"""Handle victory logic"""
	
	print("=== VICTORY ACHIEVED ===")
	print("Session Stats:")
	print("  Waves Completed: ", session_waves_completed)
	print("  Enemies Killed: ", session_enemies_killed)
	print("  Towers Built: ", session_towers_built)
	print("  Gold Earned: ", session_gold_earned)
	print("  Gold Spent: ", session_gold_spent)
	print("  Perfect Run: ", session_perfect_run)
	print("  Play Time: ", session_play_time, " seconds")
	
	# Track profile stats for victory
	var profile = get_node("/root/ProfileManager")
	if profile:
		profile.update_stat("times_won", 1)
		# Track play time for this session only
		profile.add_play_time(session_play_time)
		# Save stats to disk (this is one of the allowed save times)
		profile.save_profile_stats()
	
	# Track achievement progress for level completion
	var achievement_mgr = get_node("/root/AchievementManager")
	if achievement_mgr:
		var perfect_run = (health == 100)  # Perfect if no health lost (starts at 100)
		var mode_name = ""
		if current_game_mode:
			mode_name = current_game_mode.mode_name
		achievement_mgr.track_level_completed(perfect_run, mode_name)
		
		# Track total waves completed for this mode
		if current_game_mode and current_game_mode.mode_type != "endless":
			achievement_mgr.track_mode_waves_completed(current_wave_number, mode_name)
	
	# Pause the game
	get_tree().paused = true
	
	# Create and show victory screen
	show_victory_screen()

func show_game_over_screen():
	"""Display the game over screen with options"""
	# Create a semi-transparent overlay
	var overlay = ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.7)  # Semi-transparent black
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP  # Block input to underlying UI
	
	# Create game over panel
	var panel = Panel.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(400, 300)
	panel.position = Vector2(-200, -150)  # Center the panel
	
	# Create vertical box container for layout
	var vbox = VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 20)
	
	# Game Over title
	var title = Label.new()
	title.text = "GAME OVER"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 32)
	title.add_theme_color_override("font_color", Color.RED)
	
	# Stats label
	var stats = Label.new()
	stats.text = "Your defenses have fallen!\nGold Earned: " + str(gold)
	stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats.add_theme_font_size_override("font_size", 16)
	
	# Restart button
	var restart_btn = Button.new()
	restart_btn.text = "Restart Game"
	restart_btn.custom_minimum_size = Vector2(200, 50)
	restart_btn.connect("pressed", Callable(self, "_on_restart_pressed"))
	
	# Main menu button
	var menu_btn = Button.new()
	menu_btn.text = "Main Menu"
	menu_btn.custom_minimum_size = Vector2(200, 50)
	menu_btn.connect("pressed", Callable(self, "_on_main_menu_pressed"))
	
	# Quit button
	var quit_btn = Button.new()
	quit_btn.text = "Quit Game"
	quit_btn.custom_minimum_size = Vector2(200, 50)
	quit_btn.connect("pressed", Callable(self, "_on_quit_pressed"))
	
	# Add spacers for centering buttons
	var spacer1 = Control.new()
	spacer1.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var spacer2 = Control.new()
	spacer2.size_flags_vertical = Control.SIZE_EXPAND_FILL
	
	# Add elements to layout
	vbox.add_child(spacer1)
	vbox.add_child(title)
	vbox.add_child(stats)
	vbox.add_child(restart_btn)
	vbox.add_child(menu_btn)
	vbox.add_child(quit_btn)
	vbox.add_child(spacer2)
	
	panel.add_child(vbox)
	overlay.add_child(panel)
	
	# Add to scene with high z-index
	$CanvasLayer.add_child(overlay)
	overlay.z_index = 100

func _on_restart_pressed():
	"""Restart the current level"""
	get_tree().paused = false
	get_tree().reload_current_scene()

func _on_main_menu_pressed():
	"""Return to main menu"""
	print("Main menu button pressed!")
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")

func _on_quit_pressed():
	"""Quit the game"""
	print("Quit button pressed!")
	get_tree().quit()

func show_victory_screen():
	"""Display the victory screen with options"""
	# Create a semi-transparent overlay
	var overlay = ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.7)  # Semi-transparent black
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP  # Block input to underlying UI
	overlay.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	
	# Create victory panel
	var panel = Panel.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(500, 400)
	panel.position = Vector2(-250, -200)  # Center the panel
	panel.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	
	# Create vertical box container for layout
	var vbox = VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 15)
	vbox.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	
	# Victory title
	var title = Label.new()
	title.text = "VICTORY!"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 32)
	title.add_theme_color_override("font_color", Color.GREEN)
	
	# Basic victory message
	var victory_msg = Label.new()
	var mode_name = current_game_mode.mode_name if current_game_mode else "Unknown"
	var perfect_text = " (Perfect Run!)" if session_perfect_run else ""
	victory_msg.text = "You successfully defended against all waves!\nMode: %s%s" % [mode_name, perfect_text]
	victory_msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	victory_msg.add_theme_font_size_override("font_size", 16)
	
	# Quick stats summary
	var quick_stats = Label.new()
	var minutes = int(session_play_time / 60)
	var seconds = int(session_play_time) % 60
	quick_stats.text = "Time: %02d:%02d | Waves: %d | Final Gold: %d | Health: %d" % [minutes, seconds, session_waves_completed, gold, health]
	quick_stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	quick_stats.add_theme_font_size_override("font_size", 14)
	
	# View Detailed Stats button
	var stats_btn = Button.new()
	stats_btn.text = "View Detailed Stats"
	stats_btn.custom_minimum_size = Vector2(200, 50)
	stats_btn.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	stats_btn.connect("pressed", Callable(self, "_on_view_stats_pressed"))
	
	# Main menu button
	var menu_btn = Button.new()
	menu_btn.text = "Return to Main Menu"
	menu_btn.custom_minimum_size = Vector2(200, 50)
	menu_btn.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	menu_btn.connect("pressed", Callable(self, "_on_main_menu_pressed"))
	
	# Quit button
	var quit_btn = Button.new()
	quit_btn.text = "Quit Game"
	quit_btn.custom_minimum_size = Vector2(200, 50)
	quit_btn.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	quit_btn.connect("pressed", Callable(self, "_on_quit_pressed"))
	
	# Add spacers for centering buttons
	var spacer1 = Control.new()
	spacer1.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var spacer2 = Control.new()
	spacer2.size_flags_vertical = Control.SIZE_EXPAND_FILL
	
	# Add elements to layout
	vbox.add_child(spacer1)
	vbox.add_child(title)
	vbox.add_child(victory_msg)
	vbox.add_child(quick_stats)
	vbox.add_child(stats_btn)
	vbox.add_child(menu_btn)
	vbox.add_child(quit_btn)
	vbox.add_child(spacer2)
	
	panel.add_child(vbox)
	overlay.add_child(panel)
	
	# Add to scene with high z-index
	$CanvasLayer.add_child(overlay)
	overlay.z_index = 100

func _on_victory_continue_pressed():
	"""Continue playing after victory"""
	get_tree().paused = false
	if current_game_mode.mode_type == "endless":
		# For endless mode, just continue the current game
		pass
	else:
		# For other modes, restart the level
		get_tree().reload_current_scene()

func _on_view_stats_pressed():
	"""Show detailed session stats popup"""
	print("View stats button pressed!")
	# Create a new overlay for the stats popup
	var stats_overlay = ColorRect.new()
	stats_overlay.color = Color(0, 0, 0, 0.8)  # Darker overlay
	stats_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stats_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	stats_overlay.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	
	# Create stats panel
	var stats_panel = Panel.new()
	stats_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	stats_panel.custom_minimum_size = Vector2(600, 500)
	stats_panel.position = Vector2(-300, -250)
	stats_panel.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	
	# Create scroll container for stats
	var scroll = ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.add_theme_constant_override("margin_left", 20)
	scroll.add_theme_constant_override("margin_right", 20)
	scroll.add_theme_constant_override("margin_top", 20)
	scroll.add_theme_constant_override("margin_bottom", 60)
	
	# Create vertical box for stats content
	var stats_vbox = VBoxContainer.new()
	stats_vbox.add_theme_constant_override("separation", 10)
	
	# Stats title
	var stats_title = Label.new()
	stats_title.text = "Session Statistics"
	stats_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats_title.add_theme_font_size_override("font_size", 24)
	stats_title.add_theme_color_override("font_color", Color.CYAN)
	
	# Game info section
	var game_info = Label.new()
	var mode_name = current_game_mode.mode_name if current_game_mode else "Unknown"
	var minutes = int(session_play_time / 60)
	var seconds = int(session_play_time) % 60
	game_info.text = "=== GAME INFORMATION ===\nMode: %s\nPlay Time: %02d:%02d\nPerfect Run: %s" % [
		mode_name, 
		minutes, 
		seconds, 
		"Yes" if session_perfect_run else "No"
	]
	game_info.add_theme_font_size_override("font_size", 16)
	
	# Combat stats section
	var combat_stats = Label.new()
	combat_stats.text = "\n=== COMBAT STATISTICS ===\nWaves Completed: %d\nEnemies Defeated: %d\nTowers Built: %d" % [
		session_waves_completed,
		session_enemies_killed,
		session_towers_built
	]
	combat_stats.add_theme_font_size_override("font_size", 16)
	
	# Economic stats section
	var economic_stats = Label.new()
	var net_gold = session_gold_earned - session_gold_spent
	economic_stats.text = "\n=== ECONOMIC STATISTICS ===\nGold Earned: %d\nGold Spent: %d\nNet Gold: %d\nEnding Gold: %d" % [
		session_gold_earned,
		session_gold_spent,
		net_gold,
		gold
	]
	economic_stats.add_theme_font_size_override("font_size", 16)
	
	# Defensive stats section
	var defensive_stats = Label.new()
	var damage_taken = session_starting_health - health
	defensive_stats.text = "\n=== DEFENSIVE STATISTICS ===\nStarting Health: %d\nDamage Taken: %d\nHealth Remaining: %d\nSurvival Rate: %.1f%%" % [
		session_starting_health,
		damage_taken,
		health,
		(float(health) / float(session_starting_health)) * 100.0
	]
	defensive_stats.add_theme_font_size_override("font_size", 16)
	
	# Performance ratings
	var performance = Label.new()
	var rating = get_performance_rating()
	performance.text = "\n=== PERFORMANCE RATING ===\nOverall Grade: %s" % rating
	performance.add_theme_font_size_override("font_size", 16)
	performance.add_theme_color_override("font_color", get_rating_color(rating))
	
	# Close button
	var close_btn = Button.new()
	close_btn.text = "Close"
	close_btn.custom_minimum_size = Vector2(150, 40)
	close_btn.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	close_btn.position = Vector2(-170, -50)
	close_btn.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	close_btn.connect("pressed", Callable(self, "_on_close_stats_pressed").bind(stats_overlay))
	
	# Add all elements
	stats_vbox.add_child(stats_title)
	stats_vbox.add_child(game_info)
	stats_vbox.add_child(combat_stats)
	stats_vbox.add_child(economic_stats)
	stats_vbox.add_child(defensive_stats)
	stats_vbox.add_child(performance)
	
	scroll.add_child(stats_vbox)
	stats_panel.add_child(scroll)
	stats_panel.add_child(close_btn)
	stats_overlay.add_child(stats_panel)
	
	# Add to scene with even higher z-index
	$CanvasLayer.add_child(stats_overlay)
	stats_overlay.z_index = 110

func get_performance_rating() -> String:
	"""Calculate performance rating based on session stats"""
	var score = 0
	
	# Perfect run bonus
	if session_perfect_run:
		score += 30
	
	# Health remaining bonus (scaled)
	score += int((float(health) / float(session_starting_health)) * 25)
	
	# Efficiency bonus (enemies killed per tower)
	if session_towers_built > 0:
		var efficiency = float(session_enemies_killed) / float(session_towers_built)
		if efficiency >= 50:
			score += 20
		elif efficiency >= 30:
			score += 15
		elif efficiency >= 20:
			score += 10
		elif efficiency >= 10:
			score += 5
	
	# Economic bonus (net positive gold)
	if session_gold_earned > session_gold_spent:
		score += 15
	
	# Time bonus (for completing quickly - less than 10 minutes)
	if session_play_time < 600:  # 10 minutes
		score += 10
	
	# Return letter grade
	if score >= 85:
		return "S"
	elif score >= 75:
		return "A"
	elif score >= 65:
		return "B"
	elif score >= 50:
		return "C"
	elif score >= 35:
		return "D"
	else:
		return "F"

func get_rating_color(rating: String) -> Color:
	"""Get color for performance rating"""
	match rating:
		"S":
			return Color.GOLD
		"A":
			return Color.GREEN
		"B":
			return Color.CYAN
		"C":
			return Color.YELLOW
		"D":
			return Color.ORANGE
		"F":
			return Color.RED
		_:
			return Color.WHITE

func _on_close_stats_pressed(stats_overlay: Control):
	"""Close the stats popup"""
	print("Close stats button pressed!")
	stats_overlay.queue_free()


# Call this to place a tower of the selected type and cost
func add_tower(tower_scene: PackedScene, tower_position: Vector2, cost: int):
	if can_afford(cost):
		var build_scene = preload("res://scenes/towers/towerConstruction/towerBuild.tscn")
		var build_instance = build_scene.instantiate()
		build_instance.tower_scene = tower_scene
		build_instance.tower_position = tower_position
		build_instance.build_time = selected_tower_data.build_time[0] # or use correct level if needed
		build_instance.tower_parent = $TowerContainer
		build_instance.position = tower_position
		build_instance.set_meta("initial_tower_data", selected_tower_data)
		$TowerContainer.add_child(build_instance)
		spend_gold(cost)
		
		# Track session stats
		session_towers_built += 1
		
		# Track achievement and profile stats through AchievementManager
		var achievement_manager = get_node("/root/AchievementManager")
		if achievement_manager:
			achievement_manager.track_tower_built()

func can_place_tower_at(pos: Vector2) -> bool:
	var tilemap = $LevelContainer/map/tileLayer1
	var cell = tilemap.local_to_map(pos)
	
	# Check if there's already a tower at this position
	if is_tower_at_position(tilemap.map_to_local(cell)):
		return false
	
	# Get all tile layers to check
	var tile_layers = []
	tile_layers.append(tilemap) # tileLayer1
	if tilemap.has_node("tileLayer2"):
		tile_layers.append(tilemap.get_node("tileLayer2"))
		if tilemap.get_node("tileLayer2").has_node("tileLayer3"):
			tile_layers.append(tilemap.get_node("tileLayer2").get_node("tileLayer3"))
	
	var can_build = false
	
	# Check each layer - if ANY layer says cannot build, return false
	for layer in tile_layers:
		var layer_data = layer.get_cell_tile_data(cell)
		if layer_data:
			var layer_can_build = layer_data.get_custom_data("can_build")
			if layer_can_build == true:
				can_build = true
			elif layer_can_build == false:
				# If any layer explicitly says cannot build, override everything
				return false
	
	return can_build


func is_mouse_over_ui(node, mouse_pos):
	if node is Control:
		if not node.visible:
			return false
		if node.get_global_rect().has_point(mouse_pos):
			return true
	if node.has_method("get_children"):
		for child in node.get_children():
			if is_mouse_over_ui(child, mouse_pos):
				return true
	return false


# This handles some right clicking and such.
func _unhandled_input(event):
	# Always reset just_opened_tower_menu at the start of any input event
	var was_just_opened = just_opened_tower_menu
	just_opened_tower_menu = false

	# Cancel tower placement on right-click
	if placing_tower and event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		placing_tower = false
		hide_all_grid_overlays()
		if tower_preview:
			tower_preview.queue_free()
			tower_preview = null
		return
	# Place tower on left-click
	if placing_tower and event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var mouse_pos = get_global_mouse_position()
		var snapped_pos = get_snapped_position(mouse_pos)
		if can_place_tower_at(mouse_pos):
			add_tower(load(selected_tower_data.scene_path), snapped_pos, selected_tower_data.cost[0])
			# Only stop placing if shift is NOT held
			if not event.shift_pressed:
				placing_tower = false
				hide_all_grid_overlays()
				if tower_preview:
					tower_preview.queue_free()
					tower_preview = null
		return
	# Close tower menu if visible and click is outside any visible part of the menu or its children
	if $TowerMenu.visible and event is InputEventMouseButton and event.pressed:
		if was_just_opened:
			return
		var mouse_pos = get_viewport().get_mouse_position()
		# Don't hide if mouse is over any tower
		if not is_mouse_over_menu($TowerMenu, mouse_pos) and not is_mouse_over_any_tower(mouse_pos):
			hide_tower_menu_with_bg()
	# Handle ESC for pause menu
	if event is InputEventKey and event.keycode == KEY_ESCAPE and event.pressed:
		if $pauseFade.visible:
			$pauseFade.visible = false
			get_tree().paused = false
		else:
			$pauseFade.visible = true
			get_tree().paused = true
	
	# Test achievement notification (T key) - for development testing
	if event is InputEventKey and event.keycode == KEY_T and event.pressed:
		var achievement_manager = get_node("/root/AchievementManager")
		if achievement_manager:
			# Show test notification WITHOUT actually unlocking the achievement
			achievement_manager.test_achievement_notification("first_victory")
	
	# Test multiple achievements (Y key) - for testing queuing
	if event is InputEventKey and event.keycode == KEY_Y and event.pressed:
		var achievement_manager = get_node("/root/AchievementManager")
		if achievement_manager:
			# Show multiple test notifications with proper timing for queue testing
			achievement_manager.test_multiple_notifications()


func load_map(map_path):
	print("Loading map from: ", map_path)
	# Remove any existing map
	for child in $LevelContainer.get_children():
		print("Removing existing child: ", child.name, " (", child.get_class(), ")")
		child.queue_free()
	
	# Load and add the map
	var map_scene = load(map_path)
	if not map_scene:
		print("Error: Could not load map scene from ", map_path)
		return
		
	var map = map_scene.instantiate()
	if not map:
		print("Error: Could not instantiate map from ", map_path)
		return
	
	# Ensure the map has the correct name so it can be found as LevelContainer/map
	map.name = "map"
	print("Adding map to LevelContainer with name: ", map.name)
	$LevelContainer.add_child(map)
	
	print("Map loaded, checking structure...")
	print("  - Map node: ", map.name, " (", map.get_class(), ")")
	print("  - Map children: ", map.get_children().size())
	for child in map.get_children():
		print("    - ", child.name, " (", child.get_class(), ")")
	
	# Always hide grid overlay after loading map
	hide_all_grid_overlays()
	
	# Get start cell and build path
	var start_cell = map.start_cell if "start_cell" in map else Vector2i(0, 0)
	print("Start cell: ", start_cell)
	
	# Check if we can find the tilemap layers
	if map.has_node("tileLayer1"):
		var tilemap_ground = map.get_node("tileLayer1")
		var tilemap_bridge = tilemap_ground.get_node("tileLayer2") if tilemap_ground.has_node("tileLayer2") else null
		print("Building path with tilemap_ground: ", tilemap_ground.name)
		build_path(tilemap_ground, tilemap_bridge, start_cell)
		print("Path built, path_points size: ", path_points.size())
	else:
		print("Error: tileLayer1 not found in map")
	
	# Spawn the house at the end of the path
	spawn_house()
	
	# Enemy spawning is now handled by the wave system

func spawn_house():
	"""Spawn the house at the end of the path"""
	if path_points.size() == 0:
		return
	
	# Remove any existing houses
	var existing_houses = get_tree().get_nodes_in_group("houses")
	for house in existing_houses:
		house.queue_free()
	
	# Load and instantiate the house
	var house_scene = preload("res://scenes/house/house.tscn")
	var house = house_scene.instantiate()
	
	# Try to find the HouseBoundary to position the house properly
	var end_position = path_points[-1]
	var house_position = end_position  # Default fallback
	
	# NOTE: HouseBoundary system is deprecated - only exists in map_old.tscn
	# Modern maps should use tiles marked with "is_house" custom data
	# For now, we'll use the path endpoint as the house position
	
	# Position the house
	house.position = house_position
	
	# Set house skin from HouseSkinManager (or default to skin1)
	var selected_skin_id = 1  # Default fallback
	var house_skin_manager = get_node("/root/HouseSkinManager")
	if house_skin_manager:
		selected_skin_id = house_skin_manager.get_selected_skin()
	house.house_skin = "skin" + str(selected_skin_id)
	
	# Set the house tile position for targeting exclusions
	var tilemap = $LevelContainer/map/tileLayer1
	var house_tile = tilemap.local_to_map(house_position)
	if house.has_method("set_house_tile_position"):
		house.set_house_tile_position(house_tile)

	# Add the house to the level container
	$LevelContainer.add_child(house)

func _ensure_path_after_load():
	"""Ensure path is properly built after loading a save game"""
	print("=== _ensure_path_after_load called ===")
	print("Current path_points size: ", path_points.size())
	
	# Debug: Check what nodes exist
	print("Checking node structure:")
	print("  - Has LevelContainer: ", has_node("LevelContainer"))
	if has_node("LevelContainer"):
		var level_container = get_node("LevelContainer")
		print("  - LevelContainer children count: ", level_container.get_child_count())
		for i in range(level_container.get_child_count()):
			var child = level_container.get_child(i)
			print("    - Child ", i, ": ", child.name, " (", child.get_class(), ")")
		
		print("  - Has LevelContainer/map: ", has_node("LevelContainer/map"))
		if has_node("LevelContainer/map"):
			var map_node = get_node("LevelContainer/map")
			print("  - Map node: ", map_node.name, " (", map_node.get_class(), ")")
			print("  - Map has tileLayer1: ", map_node.has_node("tileLayer1"))
			if map_node.has_node("tileLayer1"):
				print("  - Map has start_cell: ", "start_cell" in map_node)
	
	# If path_points is still empty after loading, try to rebuild it
	if path_points.size() == 0:
		print("Path points empty after load, attempting to rebuild...")
		if has_node("LevelContainer/map"):
			var map_node = get_node("LevelContainer/map")
			if map_node.has_node("tileLayer1"):
				var tilemap_ground = map_node.get_node("tileLayer1")
				var tilemap_bridge = tilemap_ground.get_node("tileLayer2") if tilemap_ground.has_node("tileLayer2") else null
				var start_cell = map_node.start_cell if "start_cell" in map_node else Vector2i(0, 0)
				print("Calling build_path with start_cell: ", start_cell)
				build_path(tilemap_ground, tilemap_bridge, start_cell)
				print("After build_path, path_points size: ", path_points.size())
			else:
				print("Error: tileLayer1 not found in loaded map")
		else:
			print("Error: map node not found after load")
	else:
		print("Path points already available, size: ", path_points.size())
	
	print("=== _ensure_path_after_load complete ===")


func on_tower_button_pressed(tower_data: TowerData):
	# Hide tooltip when entering placement mode
	hide_tooltip()
	
	# Check if player can afford the tower before entering placement mode
	if not can_afford(tower_data.cost[0]):
		return
	
	selected_tower_data = tower_data
	placing_tower = true
	show_tower_preview()
	show_all_grid_overlays()

func show_tower_preview():
	if tower_preview:
		tower_preview.queue_free()
	tower_preview = preload("res://scenes/towers/towerPreview.tscn").instantiate()
	tower_preview.set_tower_data(selected_tower_data)
	tower_preview.z_index = 99 # Ensure preview is always in front
	add_child(tower_preview)


func _on_tower_button_1_pressed() -> void:
	var tower_data = preload("res://assets/towers/tower1/tower1.tres")
	on_tower_button_pressed(tower_data)
	if $TowerMenu.visible:
		var mouse_pos = get_viewport().get_mouse_position()
		if not is_mouse_over_menu($TowerMenu, mouse_pos):
			hide_tower_menu_with_bg()


func _on_tower_button_2_pressed() -> void:
	var tower_data = preload("res://assets/towers/tower2/tower2.tres")
	on_tower_button_pressed(tower_data)
	if $TowerMenu.visible:
		var mouse_pos = get_viewport().get_mouse_position()
		if not is_mouse_over_menu($TowerMenu, mouse_pos):
			hide_tower_menu_with_bg()


func _on_tower_button_3_pressed() -> void:
	var tower_data = preload("res://assets/towers/tower3/tower3.tres")
	on_tower_button_pressed(tower_data)
	if $TowerMenu.visible:
		var mouse_pos = get_viewport().get_mouse_position()
		if not is_mouse_over_menu($TowerMenu, mouse_pos):
			hide_tower_menu_with_bg()


func _on_tower_button_4_pressed() -> void:
	var tower_data = preload("res://assets/towers/tower4/tower4.tres")
	on_tower_button_pressed(tower_data)
	if $TowerMenu.visible:
		var mouse_pos = get_viewport().get_mouse_position()
		if not is_mouse_over_menu($TowerMenu, mouse_pos):
			hide_tower_menu_with_bg()


func _on_tower_button_5_pressed() -> void:
	var tower_data = preload("res://assets/towers/tower5/tower5.tres")
	on_tower_button_pressed(tower_data)
	if $TowerMenu.visible:
		var mouse_pos = get_viewport().get_mouse_position()
		if not is_mouse_over_menu($TowerMenu, mouse_pos):
			hide_tower_menu_with_bg()


func _on_tower_button_6_pressed() -> void:
	var tower_data = preload("res://assets/towers/tower6/tower6.tres")
	on_tower_button_pressed(tower_data)
	if $TowerMenu.visible:
		var mouse_pos = get_viewport().get_mouse_position()
		if not is_mouse_over_menu($TowerMenu, mouse_pos):
			hide_tower_menu_with_bg()


func _on_tower_button_7_pressed() -> void:
	var tower_data = preload("res://assets/towers/tower7/tower7.tres")
	on_tower_button_pressed(tower_data)
	if $TowerMenu.visible:
		var mouse_pos = get_viewport().get_mouse_position()
		if not is_mouse_over_menu($TowerMenu, mouse_pos):
			hide_tower_menu_with_bg()


func _on_tower_button_8_pressed() -> void:
	var tower_data = preload("res://assets/towers/tower8/tower8.tres")
	on_tower_button_pressed(tower_data)
	if $TowerMenu.visible:
		var mouse_pos = get_viewport().get_mouse_position()
		if not is_mouse_over_menu($TowerMenu, mouse_pos):
			hide_tower_menu_with_bg()


func _on_game_menu_pressed() -> void:
	if $CanvasLayer/pauseFade.visible:
		$CanvasLayer/pauseFade.visible = false
		get_tree().paused = false
	else:
		# Reset to main pause menu when opening
		$CanvasLayer/pauseFade/centerContainer/gameMenuPanel.visible = true
		$CanvasLayer/pauseFade/centerContainer/settingsMenuPanel.visible = false
		_apply_pause_menu_styling()
		$CanvasLayer/pauseFade.visible = true
		get_tree().paused = true
	if $TowerMenu.visible:
		var mouse_pos = get_viewport().get_mouse_position()
		if not is_mouse_over_menu($TowerMenu, mouse_pos):
			hide_tower_menu_with_bg()


func _on_resume_pressed() -> void:
	$CanvasLayer/pauseFade.visible = false
	get_tree().paused = false


func _on_pause_settings_pressed() -> void:
	"""Show the pause menu settings"""
	$CanvasLayer/pauseFade/centerContainer/gameMenuPanel.visible = false
	$CanvasLayer/pauseFade/centerContainer/settingsMenuPanel.visible = true
	_apply_pause_menu_styling()
	_setup_pause_settings_values()


func _on_pause_settings_back_pressed() -> void:
	"""Go back from pause settings to main pause menu"""
	$CanvasLayer/pauseFade/centerContainer/settingsMenuPanel.visible = false
	$CanvasLayer/pauseFade/centerContainer/gameMenuPanel.visible = true
	_apply_pause_menu_styling()


func _apply_pause_menu_styling() -> void:
	"""Apply styled backgrounds to pause menu panels"""
	# Style the main game menu panel
	if $CanvasLayer/pauseFade/centerContainer/gameMenuPanel.visible:
		var style_box = StyleBoxFlat.new()
		style_box.bg_color = Color(0.05, 0.1, 0.15, 0.95)  # Dark blue-gray like notifications
		style_box.border_color = Color(0.3, 0.6, 1.0, 0.8)  # Blue border like notifications
		style_box.border_width_left = 3
		style_box.border_width_right = 3
		style_box.border_width_top = 3
		style_box.border_width_bottom = 3
		style_box.corner_radius_top_left = 12
		style_box.corner_radius_top_right = 12
		style_box.corner_radius_bottom_left = 12
		style_box.corner_radius_bottom_right = 12
		$CanvasLayer/pauseFade/centerContainer/gameMenuPanel.add_theme_stylebox_override("panel", style_box)
	
	# Style the settings menu panel
	if $CanvasLayer/pauseFade/centerContainer/settingsMenuPanel.visible:
		var style_box = StyleBoxFlat.new()
		style_box.bg_color = Color(0.05, 0.1, 0.15, 0.95)  # Dark blue-gray like notifications
		style_box.border_color = Color(0.3, 0.6, 1.0, 0.8)  # Blue border like notifications
		style_box.border_width_left = 3
		style_box.border_width_right = 3
		style_box.border_width_top = 3
		style_box.border_width_bottom = 3
		style_box.corner_radius_top_left = 12
		style_box.corner_radius_top_right = 12
		style_box.corner_radius_bottom_left = 12
		style_box.corner_radius_bottom_right = 12
		$CanvasLayer/pauseFade/centerContainer/settingsMenuPanel.add_theme_stylebox_override("panel", style_box)


func _setup_pause_settings_values() -> void:
	"""Initialize pause menu settings values to match current settings"""
	# Set fullscreen checkbox
	$CanvasLayer/pauseFade/centerContainer/settingsMenuPanel/settingsMenu/fullscreen.button_pressed = true if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN else false
	
	# Set volume sliders to current values
	$CanvasLayer/pauseFade/centerContainer/settingsMenuPanel/settingsMenu/mainVolSlider.value = db_to_linear(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Master")))
	$CanvasLayer/pauseFade/centerContainer/settingsMenuPanel/settingsMenu/musicVolSlider.value = db_to_linear(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("MUSIC")))
	$CanvasLayer/pauseFade/centerContainer/settingsMenuPanel/settingsMenu/sfxVolSlider.value = db_to_linear(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("SFX")))


func _on_pause_fullscreen_toggled(toggled_on: bool) -> void:
	"""Handle fullscreen toggle from pause menu"""
	if toggled_on:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MAXIMIZED)


func _on_pause_main_vol_slider_value_changed(value: float) -> void:
	"""Handle main volume change from pause menu"""
	AudioServer.set_bus_volume_linear(AudioServer.get_bus_index("Master"), value)


func _on_pause_music_vol_slider_value_changed(value: float) -> void:
	"""Handle music volume change from pause menu"""
	AudioServer.set_bus_volume_linear(AudioServer.get_bus_index("MUSIC"), value)


func _on_pause_sfx_vol_slider_value_changed(value: float) -> void:
	"""Handle SFX volume change from pause menu"""
	AudioServer.set_bus_volume_linear(AudioServer.get_bus_index("SFX"), value)


func _on_quit_desktop_pressed() -> void:
	# Save current session stats before quitting
	save_session_stats()
	show_notification("Game Auto-Saved!")
	# Small delay to show the notification
	await get_tree().create_timer(1.0).timeout
	get_tree().quit()


func _on_quit_menu_pressed() -> void:
	# Save current session stats before returning to menu
	save_session_stats()
	# Unpause the game and return to main menu
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")

func add_restart_checkpoint_button():
	"""Add restart checkpoint button to pause menu"""
	if not has_node("pauseFade/gameMenu"):
		return
		
	var game_menu = $pauseFade/gameMenu
	
	# Check if button already exists
	for child in game_menu.get_children():
		if child.name == "RestartCheckpointButton":
			return  # Already added
	
	# Create the restart checkpoint button
	var restart_btn = Button.new()
	restart_btn.name = "RestartCheckpointButton"
	restart_btn.text = "Restart Checkpoint"
	
	# Since it's in a VBoxContainer, just add it and let the container handle positioning
	restart_btn.pressed.connect(_on_restart_checkpoint_pressed)
	
	# Add it before the quit buttons (after settings if it exists)
	var settings_index = -1
	for i in range(game_menu.get_child_count()):
		var child = game_menu.get_child(i)
		if child.name == "settings":
			settings_index = i
			break
	
	if settings_index >= 0:
		game_menu.add_child(restart_btn)
		game_menu.move_child(restart_btn, settings_index + 1)
	else:
		game_menu.add_child(restart_btn)

func _on_restart_checkpoint_pressed() -> void:
	# Restart from the checkpoint save like the Continue button in main menu
	var save_manager = get_node("/root/SaveManager")
	if not save_manager:
		print("No save manager available")
		show_notification("Failed to restart!")
		return
	
	# Unpause the game first
	get_tree().paused = false
	
	# Store the load flag for the main scene (same as Continue button)
	var game_mode_manager = get_node("/root/GameModeManager")
	if game_mode_manager:
		game_mode_manager.set_meta("load_checkpoint", true)
	
	# Transition to main scene (it will auto-load checkpoint in _ready)
	get_tree().change_scene_to_file("res://scenes/main.tscn")

func save_session_stats():
	"""Save current session statistics to profile (only called on save/victory/defeat)"""
	var profile_manager = get_node("/root/ProfileManager")
	if profile_manager:
		# Save current session play time
		profile_manager.add_play_time(session_play_time)
		
		# Reset session timer for next session
		session_play_time = 0.0
		
		# Explicitly save the profile stats to disk
		profile_manager.save_profile_stats()
		
		print("Session stats saved to profile")


#for tower placement, get position
func get_snapped_position(mouse_pos: Vector2) -> Vector2:
	var tilemap = $LevelContainer/map/tileLayer1
	var cell = tilemap.local_to_map(mouse_pos)
	return tilemap.map_to_local(cell)


#testing enemy spawns
func spawn_enemy(enemy_path_points, enemy_data_path: String = "res://assets/Enemies/firebug/firebug.tres", override_health: int = -1):
	# Safety check: ensure we have valid path points
	if enemy_path_points.size() == 0:
		print("Error: Cannot spawn enemy - path_points is empty")
		print("Current path_points size: ", path_points.size())
		# Try to rebuild path if main path_points is also empty
		if path_points.size() == 0:
			print("Main path_points is also empty, attempting to rebuild...")
			if $LevelContainer.has_node("map"):
				var map_node = $LevelContainer/map
				if map_node.has_node("tileLayer1"):
					var tilemap_ground = $LevelContainer/map/tileLayer1
					var tilemap_bridge = $LevelContainer/map/tileLayer1/tileLayer2 if tilemap_ground.has_node("tileLayer2") else null
					var start_cell = map_node.start_cell if "start_cell" in map_node else Vector2i(0, 0)
					build_path(tilemap_ground, tilemap_bridge, start_cell)
					print("Rebuilt path_points, new size: ", path_points.size())
					# Use the rebuilt path_points
					enemy_path_points = path_points
				else:
					print("Error: Could not rebuild path - tileLayer1 missing")
					return
			else:
				print("Error: Could not rebuild path - map node missing")
				return
		else:
			# Use the main path_points as fallback
			enemy_path_points = path_points
			print("Using main path_points as fallback, size: ", enemy_path_points.size())
		
		# Final check after attempting to fix
		if enemy_path_points.size() == 0:
			print("Error: Still no valid path_points available, cannot spawn enemy")
			return
	
	# Load the enemy data
	var enemy_data = load(enemy_data_path) as Resource
	if not enemy_data:
		return
	
	# Get scene path from enemy data
	var scene_path = ""
	if enemy_data.has_method("get"):
		scene_path = enemy_data.scene_path
	
	if scene_path == "":
		return
	
	# Load the enemy scene from the data
	var enemy_scene = load(scene_path)
	if not enemy_scene:
		return
		
	var enemy = enemy_scene.instantiate()
	if not enemy:
		return
	
	# Set the enemy data
	if enemy.has_method("set_enemy_data"):
		enemy.set_enemy_data(enemy_data)
	
	# Apply health scaling if provided
	if override_health > 0 and enemy.has_method("set_health"):
		enemy.set_health(override_health)
	elif override_health > 0 and "health" in enemy:
		enemy.health = override_health
	
	var spawn_offset = Vector2.ZERO
	if enemy_path_points.size() > 1:
		var direction = (enemy_path_points[1] - enemy_path_points[0]).normalized()
		spawn_offset = -direction * 100 # 100 pixels off-screen (adjust as needed)
	# Create a randomized path
	var random_path = []
	var tile_random_range = 12 # pixels, adjust for how much randomness you want
	for i in range(enemy_path_points.size()):
		var pt = enemy_path_points[i]
		# Don't randomize first or last point (optional)
		if i != 0 and i != enemy_path_points.size() - 1:
			var offset = Vector2(randf_range(-tile_random_range, tile_random_range), randf_range(-tile_random_range, tile_random_range))
			pt += offset
		random_path.append(pt)
	
	# Final safety check before accessing random_path[0]
	if random_path.size() == 0:
		print("Error: random_path is empty after generation, cannot spawn enemy")
		return
		
	enemy.position = random_path[0] + spawn_offset
	enemy.path = random_path
	$EnemyContainer.add_child(enemy)
	
	if enemy.has_method("play_walk_animation"):
		enemy.play_walk_animation()
	
	if enemy.has_signal("enemy_died"):
		enemy.connect("enemy_died", Callable(self, "_on_enemy_died"))

# Example: Spawn different enemy types randomly
func spawn_random_enemy(enemy_path_points):
	var enemy_types = [
		"res://assets/Enemies/firebug/firebug.tres",
		# Add more enemy types here as you create them:
		# "res://assets/Enemies/orc/orc.tres",
		# "res://assets/Enemies/dragon/dragon.tres",
	]
	var random_type = enemy_types[randi() % enemy_types.size()]
	spawn_enemy(enemy_path_points, random_type)

# Example: Spawn enemies based on wave number
func spawn_enemy_for_wave(enemy_path_points, wave_number: int):
	var enemy_type = "res://assets/Enemies/firebug/firebug.tres"  # default
	
	# Define different enemies for different waves
	if wave_number <= 3:
		enemy_type = "res://assets/Enemies/firebug/firebug.tres"
	elif wave_number <= 6:
		# Mix of firebugs and stronger enemies
		var types = ["res://assets/Enemies/firebug/firebug.tres"]
		# Add: "res://assets/Enemies/orc/orc.tres" when you create it
		enemy_type = types[randi() % types.size()]
	# Add more wave logic here
	
	spawn_enemy(enemy_path_points, enemy_type)


func _on_enemy_spawn_timer_timeout():
	if current_game_mode != null and current_game_mode.mode_type == "endless" and is_wave_active:
		# Spawn enemy for endless mode (continuous spawning)
		spawn_endless_enemy()
		# No need to track enemies_remaining_in_wave for endless mode - it's continuous
	else:
		$EnemySpawnTimer.stop()

func spawn_endless_enemy():
	# Define enemy types by difficulty tiers
	var easy_enemies = [
		"res://assets/Enemies/firebug/firebug.tres",
		"res://assets/Enemies/clampBeetle/clampBeetle.tres"
		
	]
	var medium_enemies = [
		"res://assets/Enemies/fireWasp/fireWasp.tres",
		"res://assets/Enemies/scorpion/scorpion.tres",
		"res://assets/Enemies/magmaCrab/magmaCrab.tres"
	]
	var hard_enemies = [
		"res://assets/Enemies/voidButterfly/voidButterfly.tres",
		"res://assets/Enemies/flyingLocust/flyingLocust.tres",
		"res://assets/Enemies/leafbug/leafbug.tres"
	]
	
	# Choose enemy pool based on difficulty level
	var available_enemies = []
	if endless_difficulty_level <= 2:
		# Levels 1-2: Only easy enemies
		available_enemies = easy_enemies.duplicate()
	elif endless_difficulty_level <= 4:
		# Levels 3-4: Easy and medium enemies
		available_enemies = easy_enemies.duplicate()
		available_enemies.append_array(medium_enemies)
	else:
		# Level 5+: All enemy types
		available_enemies = easy_enemies.duplicate()
		available_enemies.append_array(medium_enemies)
		available_enemies.append_array(hard_enemies)
	
	var random_enemy = available_enemies[randi() % available_enemies.size()]
	spawn_enemy_with_scaling(path_points, random_enemy)

# Testing functions removed - now using game mode system

func _on_enemy_died(gold_earned):
	# Apply gold scaling based on game mode
	var scaled_gold = gold_earned
	if current_game_mode != null:
		scaled_gold = current_game_mode.get_scaled_gold(gold_earned)
	
	earn_gold(scaled_gold)
	show_gold_feedback(scaled_gold)
	
	# Track session stats
	session_enemies_killed += 1
	
	# Track achievement and profile stats through AchievementManager
	var achievement_manager = get_node("/root/AchievementManager")
	if achievement_manager:
		achievement_manager.track_enemy_defeated()
		achievement_manager.track_gold_earned(scaled_gold)
	
	# Track enemies killed in endless mode
	if current_game_mode != null and current_game_mode.mode_type == "endless":
		endless_enemies_killed += 1
	
	# Track enemies for wave completion
	if current_game_mode != null and is_wave_active:
		enemies_remaining_in_wave -= 1


func hide_all_grid_overlays():
	for child in $LevelContainer.get_children():
		if child.has_node("gridOverlay"):
			child.get_node("gridOverlay").visible = false


func show_all_grid_overlays():
	for child in $LevelContainer.get_children():
		if child.has_node("gridOverlay"):
			child.get_node("gridOverlay").visible = true


func show_tower_menu(tower):
	# Hide tooltip when opening tower menu
	hide_tooltip()
	
	if placing_tower:
		return
	# If the menu is already open for this tower, do nothing
	if tower_menu_open_for == tower and $TowerMenu.visible:
		return
	# Prevent opening if cooldown is active for this tower
	if tower_menu_click_cooldown > 0.0 and tower_menu_cooldown_for == tower:
		return
	# Always close the menu and remove background before opening a new one
	hide_tower_menu_with_bg()
	just_opened_tower_menu = true
	tower_menu_click_cooldown = 0.15 # 150ms cooldown
	tower_menu_cooldown_for = tower
	var menu = $TowerMenu
	var tower_pos = tower.global_position
	menu.custom_minimum_size = Vector2(200, 120) # Adjust as needed
	
	# Check if menu would go off the right edge of the screen
	var screen_size = get_viewport().get_visible_rect().size
	var menu_width = menu.custom_minimum_size.x
	var offset_right = Vector2(40, -40) # Default offset to the right
	var offset_left = Vector2(-menu_width - 40, -40) # Offset to the left
	
	# If the menu would go off-screen on the right, position it on the left
	if tower_pos.x + offset_right.x + menu_width > screen_size.x:
		menu.position = tower_pos + offset_left
	else:
		menu.position = tower_pos + offset_right
	var parent = menu.get_parent()
	# Remove previous background if it exists
	if tower_menu_bg and is_instance_valid(tower_menu_bg):
		tower_menu_bg.queue_free()
		tower_menu_bg = null
	# Create and add the custom background as a sibling
	var bg = ColorRect.new()
	bg.name = "CustomTowerMenuBackground"
	bg.color = Color(0.2, 0.2, 0.2, 0.7) # Dark grey, semi-transparent
	bg.z_index = 99
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(bg)
	parent.move_child(bg, parent.get_child_count() - 1) # Ensure it's on top
	tower_menu_bg = bg
	menu.visible = true
	var attack_value = tower.tower_data.damage[tower.level - 1]
	var attack_speed = tower.tower_data.attack_speed[tower.level - 1]
	menu.get_node("TowerStats/attackLabel").text = "Attack: " + str(attack_value)
	menu.get_node("TowerStats/attackSpeedLabel").text = "Attack Speed: " + str(attack_speed)
	selected_tower = tower
	tower_menu_open_for = tower
	
	# Show attack range for the selected tower
	if tower.has_method("show_attack_range"):
		tower.show_attack_range()

	# Hide upgrade button and show 'Max level' label if tower is max level
	var upgrade_button = menu.get_node("upgradeButton")
	var max_level_label = null
	if menu.has_node("maxLevelLabel"):
		max_level_label = menu.get_node("maxLevelLabel")
	else:
		max_level_label = Label.new()
		max_level_label.name = "maxLevelLabel"
		max_level_label.text = "Max level"
		max_level_label.visible = false
		# Place the label at the same position and size as the upgrade button
		max_level_label.position = upgrade_button.position
		max_level_label.size = upgrade_button.size if upgrade_button.has_method("size") else Vector2(120, 32)
		max_level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		max_level_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		menu.add_child(max_level_label)
		var upgrade_index = menu.get_children().find(upgrade_button)
		if upgrade_index != -1:
			menu.move_child(max_level_label, upgrade_index)

	# Add or update upgrade cost label
	var upgrade_cost_label = null
	if upgrade_button.has_node("upgradeCost"):
		upgrade_cost_label = upgrade_button.get_node("upgradeCost")
	else:
		upgrade_cost_label = Label.new()
		upgrade_cost_label.name = "upgradeCost"
		upgrade_cost_label.anchors_preset = Control.PRESET_TOP_RIGHT
		upgrade_cost_label.anchor_left = 1.0
		upgrade_cost_label.anchor_right = 1.0
		upgrade_cost_label.offset_left = -40.0
		upgrade_cost_label.offset_bottom = 23.0
		upgrade_cost_label.grow_horizontal = Control.GROW_DIRECTION_BEGIN
		upgrade_cost_label.add_theme_font_size_override("font_size", 12)
		upgrade_cost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		upgrade_button.add_child(upgrade_cost_label)

	if tower.level >= 3:
		upgrade_button.visible = false
		max_level_label.visible = true
		max_level_label.position = upgrade_button.position
		max_level_label.size = upgrade_button.size if upgrade_button.has_method("size") else Vector2(120, 32)
	else:
		upgrade_button.visible = true
		max_level_label.visible = false
		# Update upgrade cost text
		var next_level = tower.level + 1
		var upgrade_cost = tower.tower_data.cost[next_level - 1] if tower.tower_data.cost.size() >= next_level else 0
		upgrade_cost_label.text = str(upgrade_cost)
		
		# Check if player can afford the upgrade
		var can_afford_upgrade = can_afford(upgrade_cost)
		upgrade_button.disabled = not can_afford_upgrade
		
		# Update upgrade button visual appearance based on affordability
		if can_afford_upgrade:
			upgrade_button.modulate = Color.WHITE
			upgrade_cost_label.add_theme_color_override("font_color", Color.WHITE)
		else:
			upgrade_button.modulate = Color(0.5, 0.5, 0.5, 1.0)  # Grey out the button
			upgrade_cost_label.add_theme_color_override("font_color", Color.RED)

	await get_tree().process_frame
	# Only update if both menu and bg are still valid
	if is_instance_valid(menu) and is_instance_valid(bg):
		if menu.visible and bg.get_parent() == parent:
			bg.position = menu.position
			bg.size = menu.size
		else:
			if is_instance_valid(bg):
				bg.queue_free()
			if tower_menu_bg == bg:
				tower_menu_bg = null


func _on_delete_button_pressed() -> void:
	# Show confirmation popup for tower deletion
	show_delete_confirmation()


# --- Confirmation Popup Logic ---
var selected_tower = null


func show_delete_confirmation():
	if not has_node("DeleteConfirmPopup"):
		var popup = ConfirmationDialog.new()
		popup.name = "DeleteConfirmPopup"
		popup.dialog_text = "Are you sure you want to delete this tower? No refund will be given."
		# Remove the default cancel button and add custom Yes/No buttons
		popup.get_ok_button().text = "Yes"
		popup.get_cancel_button().hide() # Hide the default cancel button
		popup.add_button("No", true, "no")
		popup.connect("confirmed", Callable(self, "_on_delete_confirmed"))
		popup.connect("custom_action", Callable(self, "_on_delete_no_pressed"))
		add_child(popup)
	get_node("DeleteConfirmPopup").popup_centered()


func _on_delete_confirmed():
	if selected_tower:
		selected_tower.destroy()
		selected_tower = null
	hide_tower_menu_with_bg()


func _on_delete_no_pressed(action):
	if action == "no":
		$TowerMenu.visible = true
		get_node("DeleteConfirmPopup").hide()


func _on_upgrade_button_pressed() -> void:
	if not selected_tower or not is_instance_valid(selected_tower):
		return
	if selected_tower.level < 3:
		var next_level = selected_tower.level + 1
		var upgrade_cost = selected_tower.tower_data.cost[next_level - 1] if selected_tower.tower_data.cost.size() >= next_level else null
		if upgrade_cost != null and can_afford(upgrade_cost):
			spend_gold(upgrade_cost)
			selected_tower.upgrade()
			hide_tower_menu_with_bg()
			await get_tree().process_frame

# === Tooltip System ===

func setup_tooltip_system():
	"""Initialize the tooltip system"""
	# Create tooltip instance
	var tooltip_scene = preload("res://scenes/ui/TowerTooltip.tscn")
	tower_tooltip = tooltip_scene.instantiate()
	# Add tooltip to CanvasLayer to ensure it's above UI elements
	$CanvasLayer.add_child(tower_tooltip)
	
	# Create tooltip timer
	tooltip_timer = Timer.new()
	tooltip_timer.wait_time = 1.0
	tooltip_timer.one_shot = true
	tooltip_timer.timeout.connect(_on_tooltip_timer_timeout)
	add_child(tooltip_timer)
	
	# Connect hover events to tower buttons
	setup_tower_button_tooltips()
	
	# Connect hover events to upgrade button
	setup_upgrade_button_tooltip()

func setup_tower_button_tooltips():
	"""Setup tooltip events for all tower build buttons"""
	var tower_paths = [
		"res://assets/towers/tower1/tower1.tres",
		"res://assets/towers/tower2/tower2.tres",
		"res://assets/towers/tower3/tower3.tres",
		"res://assets/towers/tower4/tower4.tres",
		"res://assets/towers/tower5/tower5.tres",
		"res://assets/towers/tower6/tower6.tres",
		"res://assets/towers/tower7/tower7.tres",
		"res://assets/towers/tower8/tower8.tres",
	]
	
	for i in range(tower_paths.size()):
		var button = $CanvasLayer.get_node("ui/MarginContainer/buildMenu/towerButton%d" % (i+1))
		var tower_data = load(tower_paths[i])
		
		# Connect mouse enter and exit events
		button.mouse_entered.connect(_on_tower_button_mouse_entered.bind(button, tower_data, 1, false))
		button.mouse_exited.connect(_on_tower_button_mouse_exited)

func setup_upgrade_button_tooltip():
	"""Setup tooltip events for the upgrade button"""
	var upgrade_button = $TowerMenu.get_node("upgradeButton")
	upgrade_button.mouse_entered.connect(_on_upgrade_button_mouse_entered)
	upgrade_button.mouse_exited.connect(_on_upgrade_button_mouse_exited)

func _on_tower_button_mouse_entered(button: Control, tower_data: TowerData, level: int, is_upgrade: bool):
	"""Handle mouse entering a tower button"""
	# Cancel any existing tooltip timer
	tooltip_timer.stop()
	
	# Store pending tooltip info
	tooltip_pending_button = button
	tooltip_pending_tower_data = tower_data
	tooltip_pending_level = level
	tooltip_pending_is_upgrade = is_upgrade
	
	# Start tooltip timer
	tooltip_timer.start()

func _on_tower_button_mouse_exited():
	"""Handle mouse exiting a tower button"""
	# Cancel tooltip timer and hide tooltip
	tooltip_timer.stop()
	hide_tooltip()

func _on_upgrade_button_mouse_entered():
	"""Handle mouse entering the upgrade button"""
	if not selected_tower or not is_instance_valid(selected_tower):
		return
	
	if selected_tower.level >= 3:
		return  # No tooltip for max level towers
	
	# Cancel any existing tooltip timer
	tooltip_timer.stop()
	
	# Store pending tooltip info for upgrade
	tooltip_pending_button = $TowerMenu.get_node("upgradeButton")
	tooltip_pending_tower_data = selected_tower.tower_data
	tooltip_pending_level = selected_tower.level + 1
	tooltip_pending_is_upgrade = true
	
	# Start tooltip timer
	tooltip_timer.start()

func _on_upgrade_button_mouse_exited():
	"""Handle mouse exiting the upgrade button"""
	# Cancel tooltip timer and hide tooltip
	tooltip_timer.stop()
	hide_tooltip()

func _on_tooltip_timer_timeout():
	"""Show tooltip after timer expires"""
	if tooltip_pending_button and tooltip_pending_tower_data:
		show_tooltip()

func show_tooltip():
	"""Display the tooltip at the appropriate position"""
	if not tower_tooltip or not tooltip_pending_button or not tooltip_pending_tower_data:
		return
	
	# Make sure tooltip is hidden during setup
	tower_tooltip.visible = false
	
	# Calculate button position first
	var button_global_pos = tooltip_pending_button.global_position
	var button_size = tooltip_pending_button.size
	var viewport_size = get_viewport().get_visible_rect().size
	
	# Setup tooltip content (this will calculate dynamic size)
	tower_tooltip.setup_tooltip(tooltip_pending_tower_data, tooltip_pending_level, tooltip_pending_is_upgrade)
	
	# Wait for size calculation to complete fully
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	
	# Get the calculated tooltip size
	var tooltip_size = tower_tooltip.size if tower_tooltip.size.x > 0 else tower_tooltip.custom_minimum_size
	
	# Try to position tooltip to the right of the button first
	var tooltip_pos = Vector2(button_global_pos.x + button_size.x + 10, button_global_pos.y)
	
	# If it would go off the right edge, position to the left instead
	if tooltip_pos.x + tooltip_size.x > viewport_size.x:
		tooltip_pos.x = button_global_pos.x - tooltip_size.x - 10
	
	# If it would go off the bottom, adjust vertically
	if tooltip_pos.y + tooltip_size.y > viewport_size.y:
		tooltip_pos.y = button_global_pos.y + button_size.y - tooltip_size.y
	
	# Now show tooltip at calculated position (only show after everything is ready)
	tower_tooltip.show_at_position(tooltip_pos)

func hide_tooltip():
	"""Hide the tooltip"""
	if tower_tooltip:
		tower_tooltip.hide_tooltip()

# === Achievement System ===

func setup_achievement_system():
	"""Initialize the achievement system"""
	# Connect to achievement signals
	var achievement_manager = get_node("/root/AchievementManager")
	if achievement_manager:
		achievement_manager.achievement_unlocked.connect(_on_achievement_unlocked)
		achievement_manager.skin_unlocked.connect(_on_skin_unlocked)

func _on_achievement_unlocked(achievement_id: String):
	"""Handle achievement unlocked"""
	print("Main: _on_achievement_unlocked called for: ", achievement_id)
	var achievement_manager = get_node("/root/AchievementManager")
	if achievement_manager:
		var achievement_data = achievement_manager.achievement_definitions.get(achievement_id, {})
		var achievement_name = achievement_data.get("name", "Unknown Achievement")
		var achievement_description = achievement_data.get("description", "")
		var unlocked_skin = achievement_data.get("unlocks_skin", -1)
		
		print("Main: Showing notification for: ", achievement_name)
		show_achievement_notification(achievement_name, achievement_description, unlocked_skin)
	else:
		print("Main: No achievement manager found")

func _on_skin_unlocked(skin_id: int):
	"""Handle skin unlocked"""
	print("Skin " + str(skin_id) + " unlocked!")

func show_achievement_notification(achievement_name: String, description: String, skin_id: int = -1):
	"""Show an achievement notification"""
	print("Main: show_achievement_notification called for: ", achievement_name)
	var achievement_popup = $CanvasLayer/AchievementNotification
	if achievement_popup:
		print("Main: Found achievement popup, calling show_achievement")
		achievement_popup.show_achievement(achievement_name, description, skin_id)
	else:
		print("Main: Achievement popup not found at $CanvasLayer/AchievementNotification")
