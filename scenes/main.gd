extends Node2D

var gold : int = 1000
var health : int = 20
var path_points = []
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


func hide_tower_menu_with_bg():
	$TowerMenu.visible = false
	if tower_menu_bg and is_instance_valid(tower_menu_bg):
		tower_menu_bg.queue_free()
		tower_menu_bg = null
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


func game_over():
	# Handle game over logic here
	pass


# Call this to place a tower of the selected type and cost
func add_tower(tower_scene: PackedScene, tower_position: Vector2, cost: int):
	if can_afford(cost):
		var tower = tower_scene.instantiate()
		tower.position = tower_position
		tower.z_index = int(tower_position.y)
		tower.tower_data = selected_tower_data
		$TowerContainer.add_child(tower)
		spend_gold(cost)

func can_place_tower_at(pos: Vector2) -> bool:
	var tilemap = $LevelContainer/map/tileLayer1
	var cell = tilemap.local_to_map(pos)
	var data = tilemap.get_cell_tile_data(cell)
	return data and data.get_custom_data("can_build") == true and not is_tower_at_position(tilemap.map_to_local(cell))


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
	if $TowerMenu.visible:
		var mouse_pos = get_viewport().get_mouse_position()
		if not is_mouse_over_menu($TowerMenu, mouse_pos):
			hide_tower_menu_with_bg()


func _on_tower_button_3_pressed() -> void:
	if $TowerMenu.visible:
		var mouse_pos = get_viewport().get_mouse_position()
		if not is_mouse_over_menu($TowerMenu, mouse_pos):
			hide_tower_menu_with_bg()


func _on_tower_button_4_pressed() -> void:
	if $TowerMenu.visible:
		var mouse_pos = get_viewport().get_mouse_position()
		if not is_mouse_over_menu($TowerMenu, mouse_pos):
			hide_tower_menu_with_bg()


func _on_tower_button_5_pressed() -> void:
	if $TowerMenu.visible:
		var mouse_pos = get_viewport().get_mouse_position()
		if not is_mouse_over_menu($TowerMenu, mouse_pos):
			hide_tower_menu_with_bg()


func _on_tower_button_6_pressed() -> void:
	if $TowerMenu.visible:
		var mouse_pos = get_viewport().get_mouse_position()
		if not is_mouse_over_menu($TowerMenu, mouse_pos):
			hide_tower_menu_with_bg()


func _on_tower_button_7_pressed() -> void:
	if $TowerMenu.visible:
		var mouse_pos = get_viewport().get_mouse_position()
		if not is_mouse_over_menu($TowerMenu, mouse_pos):
			hide_tower_menu_with_bg()


func _on_tower_button_8_pressed() -> void:
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


#testing enymy spawns
func spawn_enemy(path_points):
	var enemy_scene = preload("res://scenes/enemies/enemy.tscn")
	var enemy = enemy_scene.instantiate()
	enemy.position = path_points[0]
	enemy.path = path_points
	$EnemyContainer.add_child(enemy)
	enemy.play_walk_animation()
	enemy.connect("enemy_died", Callable(self, "_on_enemy_died"))


func _on_enemy_spawn_timer_timeout():
	spawn_enemy(path_points)


func _on_enemy_died(gold):
	earn_gold(gold)


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
	menu.position = tower_pos + Vector2(40, -40) # Offset as needed
	menu.custom_minimum_size = Vector2(200, 120) # Adjust as needed
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
	tower_to_delete = tower
	tower_menu_open_for = tower
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
var tower_to_delete = null


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
	if tower_to_delete:
		tower_to_delete.queue_free()
		tower_to_delete = null
	hide_tower_menu_with_bg()


func _on_delete_no_pressed(action):
	if action == "no":
		$TowerMenu.visible = true
		get_node("DeleteConfirmPopup").hide()


func _on_upgrade_button_pressed() -> void:
	# Upgrade the selected tower if possible and affordable
	if tower_to_delete and tower_to_delete.level < 3:
		var next_level = tower_to_delete.level + 1
		var upgrade_cost = tower_to_delete.tower_data.cost[next_level - 1] if tower_to_delete.tower_data.cost.size() >= next_level else null
		if upgrade_cost != null and can_afford(upgrade_cost):
			spend_gold(upgrade_cost)
			tower_to_delete.upgrade()
			hide_tower_menu_with_bg()
			await get_tree().process_frame
			show_tower_menu(tower_to_delete)
