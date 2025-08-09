extends Node2D

# Game state
var gold : int = 10000
var health : int = 100
var path_points = []

# Debug counter for health loss tracking
var health_loss_call_count = 0

# Gold feedback system to prevent overlapping
var gold_feedback_positions = []  # Track active gold feedback positions
var gold_feedback_spacing = 25    # Minimum distance between gold feedback texts

# Enemy testing system
var testing_mode = true  # Set to false to disable enemy cycling
var enemy_test_list = [
	"res://assets/Enemies/firebug/firebug.tres",
	"res://assets/Enemies/fireWasp/fireWasp.tres", 
	"res://assets/Enemies/flyingLocust/flyingLocust.tres",
	"res://assets/Enemies/clampBeetle/clampBeetle.tres",
	"res://assets/Enemies/leafbug/leafbug.tres",
	"res://assets/Enemies/voidButterfly/voidButterfly.tres",
	"res://assets/Enemies/scorpion/scorpion.tres",
	"res://assets/Enemies/magmaCrab/magmaCrab.tres"
]
var current_enemy_test_index = 0

# Enemy spawning examples:
# spawn_enemy(path_points)  # Spawns default firebug
# spawn_enemy(path_points, "res://assets/Enemies/orc/orc.tres")  # Spawns orc
# You can easily add new enemy types by creating new .tres files and scenes

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


func _ready():
	add_to_group("main_game")
	load_map("res://scenes/map.tscn")
	update_ui()
	hide_all_grid_overlays()
	$TowerMenu.connect("gui_input", Callable(self, "_on_TowerMenu_gui_input"))
	$CanvasLayer/ui.connect("gui_input", Callable(self, "_on_ui_gui_input"))
	update_tower_button_costs()
	
	# Validate enemy setup in testing mode
	if testing_mode:
		validate_enemy_setup()
		print_testing_instructions()

# Validate that all enemy data and scene files exist
func validate_enemy_setup():
	print("=== ENEMY SETUP VALIDATION ===")
	var valid_enemies = []
	
	for i in range(enemy_test_list.size()):
		var enemy_data_path = enemy_test_list[i]
		print("Checking enemy ", i + 1, ": ", enemy_data_path)
		
		# Check if enemy data file exists
		if not ResourceLoader.exists(enemy_data_path):
			print("  ❌ Enemy data file not found!")
			continue
			
		# Try to load enemy data
		var enemy_data = load(enemy_data_path) as Resource
		if not enemy_data:
			print("  ❌ Failed to load enemy data!")
			continue
			
		# Check if scene file exists
		if not enemy_data.has_method("get") or not enemy_data.scene_path:
			print("  ❌ Enemy data missing scene_path!")
			continue
			
		var scene_path = enemy_data.scene_path
		if not ResourceLoader.exists(scene_path):
			print("  ❌ Enemy scene file not found: ", scene_path)
			continue
			
		print("  ✅ Enemy setup valid - ", enemy_data.enemy_name if enemy_data.enemy_name else "Unknown")
		valid_enemies.append(enemy_data_path)
	
	print("=== VALIDATION COMPLETE ===")
	print("Valid enemies: ", valid_enemies.size(), "/", enemy_test_list.size())
	
	# Update test list to only include valid enemies
	enemy_test_list = valid_enemies
	
	if enemy_test_list.size() == 0:
		print("⚠️  No valid enemies found! Disabling testing mode.")
		testing_mode = false

func print_testing_instructions():
	print("\n🧪 ENEMY TESTING MODE ACTIVE 🧪")
	print("┌─ Controls ────────────────────┐")
	print("│ N - Spawn next enemy manually │")
	print("│ T - Toggle testing mode       │")
	print("│ ESC - Pause game              │")
	print("└───────────────────────────────┘")
	print("📋 Enemies in test queue: ", enemy_test_list.size())
	for i in range(enemy_test_list.size()):
		var enemy_data = load(enemy_test_list[i]) as Resource
		var enemy_name = enemy_data.enemy_name if enemy_data and enemy_data.enemy_name else "Unknown"
		print("  ", i + 1, ". ", enemy_name)
	print("🎯 Current: Will spawn enemy #", current_enemy_test_index + 1)
	print("")

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
		if tower.position == pos:
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
	update_ui()


func earn_gold(amount: int):
	gold += amount
	update_ui()


func take_damage(amount: int):
	print("=== TAKE_DAMAGE CALLED ===")
	print("take_damage called with amount: ", amount)
	print("Call stack: ", get_stack())
	var old_health = health
	health -= amount
	print("Health changed from ", old_health, " to ", health)
	update_ui()
	if health <= 0:
		game_over()
	print("=== END TAKE_DAMAGE ===")

func lose_health(amount: int):
	"""Called when enemies reach the house"""
	health_loss_call_count += 1
	print("=== LOSE_HEALTH CALLED #", health_loss_call_count, " ===")
	print("Enemy reached the house! Health lost: ", amount, " (Health before: ", health, ")")
	
	# Show damage feedback with actual amount
	show_damage_feedback(amount)
	
	take_damage(amount)
	
	print("Health after damage: ", health)
	print("=== END LOSE_HEALTH #", health_loss_call_count, " ===")

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
		# Store previous values for debugging
		var prev_value = health_bar.value
		
		health_bar.max_value = 100  # Assuming max health is 100
		health_bar.step = 1.0  # Ensure step is 1
		
		# Use call_deferred to ensure the UI updates properly
		health_bar.call_deferred("set_value", health)
		
		print("Health bar update - Health: ", health, ", Prev bar value: ", prev_value, ", New bar value: ", health, ", Step: ", health_bar.step, ", Max: ", health_bar.max_value)
		
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
	
	# Show testing mode status
	if testing_mode:
		var test_info = "TESTING MODE - Press N: Next Enemy, T: Toggle | Enemy " + str(current_enemy_test_index + 1) + "/" + str(enemy_test_list.size())
		# You can add a label to show this info, for now just print it occasionally
		if gold % 100 == 0:  # Print every 100 gold changes to avoid spam
			print("🧪 ", test_info)


func game_over():
	"""Handle game over logic"""
	print("GAME OVER - Player health reached 0!")
	
	# Pause the game
	get_tree().paused = true
	
	# Create and show game over screen
	show_game_over_screen()

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
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")

func _on_quit_pressed():
	"""Quit the game"""
	get_tree().quit()


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
	
	# Testing controls (only in testing mode)
	if testing_mode and event is InputEventKey and event.pressed:
		if event.keycode == KEY_N:  # 'N' for next enemy
			print("Manual spawn: Next enemy")
			spawn_next_test_enemy(path_points)
		elif event.keycode == KEY_T:  # 'T' to toggle testing mode
			testing_mode = !testing_mode
			print("Testing mode: ", "ON" if testing_mode else "OFF")


func load_map(map_path):
	# Remove any existing map
	for child in $LevelContainer.get_children():
		child.queue_free()
	# Load and add the map
	var map = load(map_path).instantiate()
	$LevelContainer.add_child(map)
	# Always hide grid overlay after loading map
	hide_all_grid_overlays()
	var start_cell = map.start_cell
	var tilemap_ground = $LevelContainer/map/tileLayer1
	var tilemap_bridge = $LevelContainer/map/tileLayer1/tileLayer2
	build_path(tilemap_ground, tilemap_bridge, start_cell)
	
	# Spawn the house at the end of the path
	spawn_house()
	
	if testing_mode:
		spawn_next_test_enemy(path_points)
	else:
		spawn_enemy(path_points)

func spawn_house():
	"""Spawn the house at the end of the path"""
	if path_points.size() == 0:
		print("Warning: No path points available for house placement")
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
	
	# Look for HouseBoundary in the current level container
	if $LevelContainer.get_child_count() > 0:
		var map_scene = $LevelContainer.get_child(0)
		var house_boundary = map_scene.get_node_or_null("HouseBoundary")
		if house_boundary and house_boundary is ReferenceRect:
			# Position house at the center of the boundary
			house_position = house_boundary.position + house_boundary.size / 2.0
			print("Positioning house at boundary center: ", house_position)
			print("  Boundary details: pos=", house_boundary.position, " size=", house_boundary.size)
			print("  Path endpoint: ", end_position)
			print("  Difference from path: ", house_position - end_position)
		else:
			print("HouseBoundary not found, using path endpoint: ", end_position)
	
	# Position the house
	house.position = house_position
	
	# Set a random house skin for testing (you can change this later)
	var available_skins = []
	for i in range(1, 21):  # All 20 skins
		available_skins.append("skin" + str(i))
	var random_skin = available_skins[randi() % available_skins.size()]
	house.house_skin = random_skin
	
	# Set the house tile position for targeting exclusions
	var tile_size = 64  # Assuming 64x64 tiles
	var house_tile = Vector2i(int(house_position.x / tile_size), int(house_position.y / tile_size))
	if house.has_method("set_house_tile_position"):
		house.set_house_tile_position(house_tile)
	else:
		print("Warning: House scene missing set_house_tile_position method")
	
	# Add the house to the level container
	$LevelContainer.add_child(house)
	
	print("House spawned at position: ", end_position, " with skin: ", random_skin)


func on_tower_button_pressed(tower_data: TowerData):
	# Check if player can afford the tower before entering placement mode
	if not can_afford(tower_data.cost[0]):
		print("Cannot afford tower! Cost: ", tower_data.cost[0], " Gold: ", gold)
		return
	
	selected_tower_data = tower_data
	placing_tower = true
	show_tower_preview()
	show_all_grid_overlays()

func show_tower_preview():
	print("show_tower_preview called")
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
	if $pauseFade.visible:
		$pauseFade.visible = false
		get_tree().paused = false
	else:
		$pauseFade.visible = true
		get_tree().paused = true
	if $TowerMenu.visible:
		var mouse_pos = get_viewport().get_mouse_position()
		if not is_mouse_over_menu($TowerMenu, mouse_pos):
			hide_tower_menu_with_bg()


func _on_resume_pressed() -> void:
	$pauseFade.visible = false
	get_tree().paused = false


func _on_quit_desktop_pressed() -> void:
	get_tree().quit()


#for tower placement, get position
func get_snapped_position(mouse_pos: Vector2) -> Vector2:
	var tilemap = $LevelContainer/map/tileLayer1
	var cell = tilemap.local_to_map(mouse_pos)
	return tilemap.map_to_local(cell)


#testing enemy spawns
func spawn_enemy(enemy_path_points, enemy_data_path: String = "res://assets/Enemies/firebug/firebug.tres"):
	# Load the enemy data
	var enemy_data = load(enemy_data_path) as Resource
	if not enemy_data:
		print("❌ Failed to load enemy data: ", enemy_data_path)
		return
	
	# Get scene path from enemy data
	var scene_path = ""
	if enemy_data.has_method("get"):
		scene_path = enemy_data.scene_path
	
	if scene_path == "":
		print("❌ Enemy data missing scene_path: ", enemy_data_path)
		return
	
	# Load the enemy scene from the data
	var enemy_scene = load(scene_path)
	if not enemy_scene:
		print("❌ Failed to load enemy scene: ", scene_path)
		return
		
	var enemy = enemy_scene.instantiate()
	if not enemy:
		print("❌ Failed to instantiate enemy scene: ", scene_path)
		return
	
	# Set the enemy data
	if enemy.has_method("set_enemy_data"):
		enemy.set_enemy_data(enemy_data)
	else:
		print("⚠️  Enemy scene missing set_enemy_data method: ", scene_path)
	
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
	enemy.position = random_path[0] + spawn_offset
	enemy.path = random_path
	$EnemyContainer.add_child(enemy)
	
	if enemy.has_method("play_walk_animation"):
		enemy.play_walk_animation()
	
	if enemy.has_signal("enemy_died"):
		enemy.connect("enemy_died", Callable(self, "_on_enemy_died"))
	
	print("✅ Successfully spawned enemy: ", enemy_data.enemy_name if enemy_data.enemy_name else "Unknown")

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
	if testing_mode:
		spawn_next_test_enemy(path_points)
	else:
		spawn_enemy(path_points)

# Testing function that cycles through all enemy types
func spawn_next_test_enemy(enemy_path_points):
	if enemy_test_list.size() == 0:
		print("No valid enemies in test list!")
		return
		
	if current_enemy_test_index >= enemy_test_list.size():
		current_enemy_test_index = 0  # Reset to beginning
		print("🔄 Cycling back to first enemy")
	
	var enemy_data_path = enemy_test_list[current_enemy_test_index]
	
	# Load enemy data for debugging info
	var enemy_data = load(enemy_data_path) as Resource
	var enemy_name = "Unknown"
	if enemy_data and enemy_data.has_method("get"):
		enemy_name = enemy_data.enemy_name if enemy_data.enemy_name else "Unknown"
	
	print("🐛 Testing enemy ", current_enemy_test_index + 1, "/", enemy_test_list.size(), ": ", enemy_name, " (", enemy_data_path, ")")
	
	spawn_enemy(enemy_path_points, enemy_data_path)
	current_enemy_test_index += 1


func _on_enemy_died(gold_earned):
	earn_gold(gold_earned)
	show_gold_feedback(gold_earned)


func hide_all_grid_overlays():
	for child in $LevelContainer.get_children():
		if child.has_node("gridOverlay"):
			print("Hiding gridOverlay in:", child)
			child.get_node("gridOverlay").visible = false


func show_all_grid_overlays():
	for child in $LevelContainer.get_children():
		if child.has_node("gridOverlay"):
			print("Showing gridOverlay in:", child)
			child.get_node("gridOverlay").visible = true


func show_tower_menu(tower):
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
			print("BG updated, menu rect: ", menu.get_rect(), " bg rect: ", bg.get_rect())
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
	print("Upgrade button pressed!")
	print("selected_tower:", selected_tower)
	if not selected_tower or not is_instance_valid(selected_tower):
		print("selected_tower is invalid or null!")
		return
	print("selected_tower.level:", selected_tower.level)
	if selected_tower.level < 3:
		var next_level = selected_tower.level + 1
		var upgrade_cost = selected_tower.tower_data.cost[next_level - 1] if selected_tower.tower_data.cost.size() >= next_level else null
		print("next_level:", next_level, "upgrade_cost:", upgrade_cost)
		if upgrade_cost != null and can_afford(upgrade_cost):
			print("Upgrading tower!")
			spend_gold(upgrade_cost)
			selected_tower.upgrade()
			hide_tower_menu_with_bg()
			await get_tree().process_frame
