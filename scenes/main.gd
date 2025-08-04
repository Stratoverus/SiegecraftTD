extends Node2D

var gold : int = 1000
var health : int = 20
var path_points = []
# For tower placement
var selected_tower_data : TowerData = null
var placing_tower : bool = false
var tower_preview : Node2D = null




func _ready():
	load_map("res://scenes/map.tscn")
	update_ui()


func load_level(level_path):
	# Remove any existing level
	for child in $LevelContainer.get_children():
		child.queue_free()
	# Load and add the new level
	var level = load(level_path).instantiate()
	$LevelContainer.add_child(level)


func build_path(tilemap_ground, tilemap_bridge, start_cell):
	path_points.clear()
	var ordered_cells = order_path_points(tilemap_ground, tilemap_bridge, start_cell)
	var i = 0
	while i < ordered_cells.size():
		var cell = ordered_cells[i]
		var data_bridge = tilemap_bridge.get_cell_tile_data(cell)
		var data_ground = tilemap_ground.get_cell_tile_data(cell)
		var world_pos = null
		# Check for horizontal bridge sequence
		if i + 2 < ordered_cells.size():
			var cell1 = ordered_cells[i]
			var cell2 = ordered_cells[i + 1]
			var cell3 = ordered_cells[i + 2]
			var is_horizontal_bridge = (
				tilemap_bridge.get_cell_tile_data(cell1) and tilemap_bridge.get_cell_tile_data(cell1).get_custom_data("is_path") == true and
				tilemap_bridge.get_cell_tile_data(cell2) and tilemap_bridge.get_cell_tile_data(cell2).get_custom_data("is_path") == true and
				tilemap_bridge.get_cell_tile_data(cell3) and tilemap_bridge.get_cell_tile_data(cell3).get_custom_data("is_path") == true and
				cell1.y == cell2.y and cell2.y == cell3.y and
				cell1.x + 1 == cell2.x and cell2.x + 1 == cell3.x
			)
			if is_horizontal_bridge:
				# Use your exact coordinates for the 3-tile horizontal bridge
				path_points.append(Vector2(36, 16))   # ramp up
				path_points.append(Vector2(156, 16))  # flat
				path_points.append(Vector2(192, 0))   # ramp down
				i += 3
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
		$TowerContainer.add_child(tower)
		spend_gold(cost)

func can_place_tower_at(pos: Vector2) -> bool:
	var tilemap = $LevelContainer/map/tileLayer1
	var cell = tilemap.local_to_map(pos)
	var data = tilemap.get_cell_tile_data(cell)
	return data and data.get_custom_data("can_build") == true

# Example: Call this in _unhandled_input to place the tower
func _unhandled_input(event):
	if placing_tower and event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var mouse_pos = get_global_mouse_position()
		var snapped_pos = get_snapped_position(mouse_pos)
		if can_place_tower_at(mouse_pos):
			add_tower(load(selected_tower_data.scene_path), snapped_pos, selected_tower_data.cost)
		placing_tower = false
		if tower_preview:
			tower_preview.queue_free()
			tower_preview = null

func load_map(map_path):
	# Remove any existing map
	for child in $LevelContainer.get_children():
		child.queue_free()
	# Load and add the map
	var map = load(map_path).instantiate()
	$LevelContainer.add_child(map)
	var start_cell = map.start_cell
	var tilemap_ground = $LevelContainer/map/tileLayer1
	var tilemap_bridge = $LevelContainer/map/tileLayer1/tileLayer2
	build_path(tilemap_ground, tilemap_bridge, start_cell)
	spawn_enemy(path_points)


func on_tower_button_pressed(tower_data: TowerData):
	selected_tower_data = tower_data
	placing_tower = true
	show_tower_preview()

func show_tower_preview():
	print("show_tower_preview called")
	if tower_preview:
		tower_preview.queue_free()
	tower_preview = preload("res://scenes/towers/towerPreview.tscn").instantiate()
	tower_preview.set_tower_data(selected_tower_data)
	add_child(tower_preview)

func _process(delta):
	if placing_tower and tower_preview:
		var mouse_pos = get_global_mouse_position()
		tower_preview.position = get_snapped_position(mouse_pos)
		tower_preview.visible = true


func _on_tower_button_1_pressed() -> void:
	var tower_data = preload("res://assets/towers/tower1/tower1.tres")
	on_tower_button_pressed(tower_data)


func _on_game_menu_pressed() -> void:
	$pauseFade.visible = true


func _on_resume_pressed() -> void:
	$pauseFade.visible = false


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
