extends Node2D

# Game state
var gold : int = 10000
var health : int = 20
var path_points = []

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

# Dynamically set the cost label for each tower button in the build menu
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
		if button.has_node("towerCost"):
			var cost_label = button.get_node("towerCost")
			cost_label.text = str(tower_data.cost[0])


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


func can_afford(cost: int) -> bool:
	return gold >= cost


func spend_gold(amount: int):
	gold -= amount
	update_ui()


func earn_gold(amount: int):
	gold += amount
	update_ui()


func take_damage(amount: int):
	health -= amount
	update_ui()
	if health <= 0:
		game_over()


func update_ui():
	# Update your UI elements here (e.g., money/health labels)
	$CanvasLayer/ui/goldContainer/goldLabel.text = str(gold)
	
	# Show testing mode status
	if testing_mode:
		var test_info = "TESTING MODE - Press N: Next Enemy, T: Toggle | Enemy " + str(current_enemy_test_index + 1) + "/" + str(enemy_test_list.size())
		# You can add a label to show this info, for now just print it occasionally
		if gold % 100 == 0:  # Print every 100 gold changes to avoid spam
			print("🧪 ", test_info)


func game_over():
	# Handle game over logic here
	pass


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
	if testing_mode:
		spawn_next_test_enemy(path_points)
	else:
		spawn_enemy(path_points)


func on_tower_button_pressed(tower_data: TowerData):
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
