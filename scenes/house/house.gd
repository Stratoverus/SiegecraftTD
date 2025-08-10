extends Node2D
class_name House

# Signal for when an enemy reaches the house
signal enemy_reached_house(enemy)

# House configuration
@export var house_skin: String = "skin1"  # For skin selection
@export var house_size: Vector2i = Vector2i(1, 1)  # Tile size for collision detection
@export var animation_resource: Resource = null  # For modular animation support
@export var detection_range: float = 128.0  # Range to detect approaching enemies
@export var house_scale_multiplier: float = 1.5  # Increased base scale

# Testing variables for skin cycling
@export var enable_skin_testing: bool = false
@export var auto_cycle_skins: bool = false  # Automatically cycle through skins for testing
@export var skin_cycle_delay: float = 2.0  # Seconds between skin changes
var current_skin_index: int = 1  # Current skin number (1-20)
var cycle_timer: float = 0.0

# Internal tracking
var enemies_inside: Array[Node2D] = []
var enemies_nearby: Array[Node2D] = []
var house_tile_position: Vector2i
var house_direction: Vector2 = Vector2.DOWN  # Direction house is facing
var door_state: String = "closed"  # "closed", "opening", "open", "closing"
var open_hold_frame: int = 8  # Frame to hold when door is open
var animation_timer: Timer

func _ready():
	add_to_group("houses")
	
	# Set house skin from HouseSkinManager
	var house_skin_manager = get_node("/root/HouseSkinManager")
	if house_skin_manager:
		var selected_skin_id = house_skin_manager.get_selected_skin()
		house_skin = "skin" + str(selected_skin_id)
		current_skin_index = selected_skin_id
	else:
		# Fallback if HouseSkinManager isn't available
		house_skin = "skin1"
		current_skin_index = 1
	
	# Connect to main game for health reduction
	connect_to_main_game()
	
	# Set up animation timer for door control
	animation_timer = Timer.new()
	add_child(animation_timer)
	animation_timer.wait_time = 0.1
	animation_timer.connect("timeout", _on_animation_timer_timeout)
	
	# Determine house direction based on path (this must come first)
	determine_house_direction()
	
	# Set up the animated sprite
	setup_house_animation()
	
	# Scale and position the house to fit the available space
	scale_house_to_fit()
	
	# Start with door closed (first frame)
	if $AnimatedSprite2D.sprite_frames and $AnimatedSprite2D.sprite_frames.has_animation(house_skin):
		$AnimatedSprite2D.play(house_skin)
		$AnimatedSprite2D.pause()
		$AnimatedSprite2D.frame = 0
		door_state = "closed"

func _process(delta):
	# Check for nearby enemies
	check_nearby_enemies()
	
	# Update door state based on nearby enemies
	update_door_state()
	
	# Handle skin testing
	if enable_skin_testing:
		handle_skin_testing(delta)

func handle_skin_testing(delta):
	"""Handle skin cycling for testing purposes"""
	# Auto-cycle through skins
	if auto_cycle_skins:
		cycle_timer += delta
		if cycle_timer >= skin_cycle_delay:
			cycle_timer = 0.0
			cycle_to_next_skin()
	
	# Manual skin cycling with keyboard
	if Input.is_action_just_pressed("ui_right") or Input.is_action_just_pressed("ui_accept"):
		cycle_to_next_skin()
	elif Input.is_action_just_pressed("ui_left"):
		cycle_to_previous_skin()

func cycle_to_next_skin():
	"""Cycle to the next house skin"""
	current_skin_index += 1
	if current_skin_index > 20:
		current_skin_index = 1
	update_house_skin()

func cycle_to_previous_skin():
	"""Cycle to the previous house skin"""
	current_skin_index -= 1
	if current_skin_index < 1:
		current_skin_index = 20
	update_house_skin()

func update_house_skin():
	"""Update the house to use the new skin"""
	var new_skin = "skin" + str(current_skin_index)
	house_skin = new_skin
	
	# Update the animation
	if $AnimatedSprite2D.sprite_frames and $AnimatedSprite2D.sprite_frames.has_animation(house_skin):
		var was_playing = $AnimatedSprite2D.is_playing()
		var current_frame = $AnimatedSprite2D.frame
		
		$AnimatedSprite2D.play(house_skin)
		if not was_playing:
			$AnimatedSprite2D.pause()
			$AnimatedSprite2D.frame = current_frame
		
		# Re-apply scaling and positioning for new skin
		scale_house_to_fit()


func determine_house_direction():
	"""Determine which direction the house should face based on the path"""
	# Get the path from the main game
	var main_game = get_tree().get_first_node_in_group("main_game")
	if not main_game or not main_game.path_points or main_game.path_points.size() < 2:
		house_direction = Vector2.DOWN  # Default direction
		return
	
	# Get the last two points of the path to determine approach direction
	var path_points = main_game.path_points
	var last_point = path_points[-1]
	var second_last_point = path_points[-2]
	
	# Direction enemies come from (opposite of their movement direction)
	var enemy_approach_direction = (second_last_point - last_point).normalized()
	
	# House should face the approach direction
	house_direction = enemy_approach_direction
	
	# Apply rotation to the house based on direction
	apply_house_rotation()

func apply_house_rotation():
	"""Rotate the house to face the correct direction"""
	# House should face towards where enemies are coming FROM
	# If enemies come from bottom (house_direction = (0, 1)), house should face down (rotation = 0)
	# If enemies come from top (house_direction = (0, -1)), house should face up (rotation = PI)
	# If enemies come from left (house_direction = (-1, 0)), house should face left (rotation = -PI/2)
	# If enemies come from right (house_direction = (1, 0)), house should face right (rotation = PI/2)
	
	# Convert direction to rotation (house faces the direction enemies come from)
	if abs(house_direction.x) > abs(house_direction.y):
		# Horizontal movement
		if house_direction.x > 0:
			rotation = PI / 2  # Face right (enemies from right)
		else:
			rotation = -PI / 2  # Face left (enemies from left)
	else:
		# Vertical movement  
		if house_direction.y > 0:
			rotation = 0  # Face down (enemies from bottom) - default sprite orientation
		else:
			rotation = PI  # Face up (enemies from top)
func get_skin_dimensions(skin_name: String) -> Vector2:
	"""Get the visual content dimensions for a specific house skin"""
	# Use the content dimensions from the door measurement system for consistency
	var door_info = get_skin_door_measurements(skin_name)
	var result = Vector2(door_info.content_width, door_info.content_height)
	return result

func get_skin_door_measurements(skin_name: String) -> Dictionary:
	"""Get precise door measurements for each house skin - always uses automatic analysis"""
	
	# Always use automatic analysis - no hardcoded values
	return get_analyzed_door_measurements(skin_name)

func get_analyzed_door_measurements(skin_name: String) -> Dictionary:
	"""Get door measurements using automatic sprite analysis"""
	
	# Load the analyzer script
	var analyzer_script = preload("res://scripts/house_sprite_analyzer.gd")
	
	# Run analysis for all skins (cached)
	if not has_meta("analyzed_measurements"):
		var measurements = analyzer_script.analyze_house_sprites_from_node(self)
		set_meta("analyzed_measurements", measurements)
	
	var all_measurements = get_meta("analyzed_measurements")
	var result = all_measurements.get(skin_name, {"door_center_x": 75, "door_bottom_y": 140, "content_width": 105, "content_height": 105})
	
	return result

func scale_house_to_fit():
	"""Scale the house to fit the available tile space"""
	# New tile-based approach: find house tiles with is_house custom data
	var house_tiles = find_house_tiles()
	var tile_area = calculate_house_tile_area(house_tiles)
	
	if house_tiles.is_empty():
		tile_area = {"position": Vector2.ZERO, "size": Vector2(160.0, 110.0)}
	
	var available_width = tile_area.size.x
	var available_height = tile_area.size.y
	var tile_center_position = tile_area.position
	
	# Get skin-specific scale multiplier
	var scale_multiplier = house_scale_multiplier
	
	# Get actual sprite dimensions for this specific skin
	var skin_dimensions = get_skin_dimensions(house_skin)
	var sprite_width = skin_dimensions.x
	var sprite_height = skin_dimensions.y
	
	# Calculate scaling to fit tile area with constraints
	# For positioning, use the full tile area, but for scaling, respect the 2-tile width constraint
	var scale_x = available_width / sprite_width   # Can use full tile width for scaling calculation
	var scale_y = available_height / sprite_height
	
	# Use the smaller scale factor to ensure it fits within both dimensions
	var base_scale = min(scale_x, scale_y)
	
	# Apply margin and skin-specific multipliers
	var margin_factor = 0.85  # Keep some margin for visual clarity
	var tile_scale = base_scale * margin_factor
	
	# Apply skin-specific scaling with a maximum limit
	var max_scale_limit = 1.5  # Prevent houses from becoming too large
	var final_scale = min(tile_scale * scale_multiplier, max_scale_limit)
	
	# Apply the scaling to the AnimatedSprite2D
	$AnimatedSprite2D.scale = Vector2(final_scale, final_scale)
	
	# Position the house sprite relative to the tile area
	position_house_for_tiles(tile_center_position, Vector2(available_width, available_height))
	
	# Update collision shape to match the actual tile area (not constrained)
	if $Area2D/CollisionShape2D.shape is RectangleShape2D:
		var collision_shape = $Area2D/CollisionShape2D.shape as RectangleShape2D
		collision_shape.size = Vector2(available_width, available_height)

func find_house_tiles() -> Array:
	"""Find all tiles marked with is_house custom data"""
	var house_tiles = []
	
	# Access the tilemap through the main scene
	var main_scene = get_tree().get_first_node_in_group("main_game")
	if not main_scene:
		return house_tiles
	
	var tilemap = main_scene.get_node_or_null("LevelContainer/map/tileLayer1")
	if not tilemap:
		return house_tiles
	
	# Get the used cells and check each one for is_house custom data
	var used_cells = tilemap.get_used_cells()
	for cell in used_cells:
		var tile_data = tilemap.get_cell_tile_data(cell)
		if tile_data and tile_data.get_custom_data("is_house") == true:
			house_tiles.append(cell)
	
	return house_tiles

func calculate_house_tile_area(house_tiles: Array) -> Dictionary:
	"""Calculate the world position and size of the house tile area"""
	if house_tiles.is_empty():
		return {"position": Vector2.ZERO, "size": Vector2(160.0, 110.0)}
	
	# Access the tilemap to convert tile coordinates to world coordinates
	var main_scene = get_tree().get_first_node_in_group("main_game")
	var tilemap = main_scene.get_node("LevelContainer/map/tileLayer1")
	
	# Find the bounding box of house tiles
	var min_x = house_tiles[0].x
	var max_x = house_tiles[0].x
	var min_y = house_tiles[0].y
	var max_y = house_tiles[0].y
	
	for tile in house_tiles:
		min_x = min(min_x, tile.x)
		max_x = max(max_x, tile.x)
		min_y = min(min_y, tile.y)
		max_y = max(max_y, tile.y)
	
	# Calculate tile area dimensions
	var tile_width = max_x - min_x + 1
	var tile_height = max_y - min_y + 1
	var tile_size = 80.0  # Standard Godot tile size
	
	# Calculate center position in world coordinates
	var center_tile = Vector2((min_x + max_x) / 2.0, (min_y + max_y) / 2.0)
	var center_world = tilemap.map_to_local(center_tile)
	
	# Calculate total area size
	var area_size = Vector2(tile_width * tile_size, tile_height * tile_size)
	
	return {"position": center_world, "size": area_size}

func position_house_for_tiles(tile_center: Vector2, tile_size: Vector2):
	"""Position the house sprite so the door center is exactly at the center-bottom of the 2x3 tile grid"""
	
	# Get precise door measurements for this skin
	var door_info = get_skin_door_measurements(house_skin)
	var sprite_scale = $AnimatedSprite2D.scale.x
	
	# Calculate the target position for the door center
	# 2x3 tiles = 2*64 = 128 pixels wide, so center is at 64 pixels (96px mark as you mentioned)
	var tile_grid_width = 128.0  # 2 tiles * 64 pixels each
	var _tile_grid_center_x = tile_grid_width / 2.0  # 64 pixels from left edge (unused but for reference)
	
	# Get the actual tile boundaries for precise positioning
	var house_tiles = find_house_tiles()
	if house_tiles.is_empty():
		position = tile_center
		$AnimatedSprite2D.position = Vector2.ZERO
		return
	
	# Access tilemap for precise calculations
	var main_scene = get_tree().get_first_node_in_group("main_game")
	var tilemap = main_scene.get_node("LevelContainer/map/tileLayer1")
	
	# Find tile boundaries
	var min_x = house_tiles[0].x
	var max_x = house_tiles[0].x
	var min_y = house_tiles[0].y
	var max_y = house_tiles[0].y
	
	for tile_pos in house_tiles:
		min_x = min(min_x, tile_pos.x)
		max_x = max(max_x, tile_pos.x)
		min_y = min(min_y, tile_pos.y)
		max_y = max(max_y, tile_pos.y)
	
	# Calculate the exact center-bottom point of the tile grid
	var tile_grid_center_world = tilemap.map_to_local(Vector2((min_x + max_x) / 2.0, max_y))
	var tile_grid_bottom_world = tile_grid_center_world.y + (tilemap.tile_set.tile_size.y / 2.0)
	
	# Calculate where the house node needs to be positioned
	# We want: door_center_in_world = tile_grid_center_x_world
	# We want: door_bottom_in_world = tile_grid_bottom_world
	
	# Door center position in scaled sprite coordinates
	var scaled_door_center_x = door_info.door_center_x * sprite_scale
	var scaled_door_bottom_y = door_info.door_bottom_y * sprite_scale
	
	# Standard sprite frame size (150x151)
	var sprite_frame_center_x = 75.0 * sprite_scale  # Center of 150px frame
	var sprite_frame_center_y = 75.5 * sprite_scale  # Center of 151px frame
	
	# Calculate how far the door center is from sprite frame center
	var door_offset_from_center_x = scaled_door_center_x - sprite_frame_center_x
	var door_offset_from_center_y = scaled_door_bottom_y - sprite_frame_center_y
	
	# Position house node so that when sprite is applied, door ends up at target location
	var target_house_x = tile_grid_center_world.x - door_offset_from_center_x
	var target_house_y = tile_grid_bottom_world - door_offset_from_center_y
	
	# Set positions
	position = Vector2(target_house_x, target_house_y)
	$AnimatedSprite2D.position = Vector2.ZERO  # No sprite offset needed - house node positioned precisely

func check_nearby_enemies():
	"""Check for enemies within detection range"""
	enemies_nearby.clear()
	var enemies = get_tree().get_nodes_in_group("enemies")
	
	for enemy in enemies:
		if enemy.health > 0 and position.distance_to(enemy.position) <= detection_range:
			enemies_nearby.append(enemy)

func update_door_state():
	"""Update door animation based on nearby enemies"""
	var has_nearby_enemies = enemies_nearby.size() > 0
	
	match door_state:
		"closed":
			if has_nearby_enemies:
				start_opening_door()
		"opening":
			# Door continues opening automatically
			pass
		"open":
			if not has_nearby_enemies:
				start_closing_door()
		"closing":
			if has_nearby_enemies:
				start_opening_door()

func start_opening_door():
	"""Start opening the door animation"""
	door_state = "opening"
	$AnimatedSprite2D.play(house_skin)
	
	# Connect to animation frame changed to stop at open frame
	if not $AnimatedSprite2D.is_connected("frame_changed", _on_door_frame_changed):
		$AnimatedSprite2D.connect("frame_changed", _on_door_frame_changed)

func start_closing_door():
	"""Start closing the door animation"""
	door_state = "closing"
	# Start a timer before closing (small delay)
	animation_timer.wait_time = 1.0  # 1 second delay before closing
	animation_timer.start()

func _on_animation_timer_timeout():
	"""Handle animation timer timeout"""
	if door_state == "closing":
		# Start playing animation backwards
		play_animation_backwards()

func play_animation_backwards():
	"""Play the door closing animation by going backwards through frames"""
	var current_frame = $AnimatedSprite2D.frame
	if current_frame > 0:
		$AnimatedSprite2D.frame = current_frame - 1
		animation_timer.wait_time = 0.1  # Speed of closing
		animation_timer.start()
	else:
		# Door is now closed
		door_state = "closed"
		$AnimatedSprite2D.pause()

func _on_door_frame_changed():
	"""Handle door animation frame changes"""
	if door_state == "opening" and $AnimatedSprite2D.frame >= open_hold_frame:
		# Door is now open, pause at this frame
		door_state = "open"
		$AnimatedSprite2D.pause()
		$AnimatedSprite2D.frame = open_hold_frame
		
		# Disconnect frame changed signal
		if $AnimatedSprite2D.is_connected("frame_changed", _on_door_frame_changed):
			$AnimatedSprite2D.disconnect("frame_changed", _on_door_frame_changed)

func connect_to_main_game():
	"""Connect the house to the main game for health reduction"""
	var main_game = get_tree().get_first_node_in_group("main_game")
	if main_game:
		enemy_reached_house.connect(func(_enemy): main_game.lose_health(1))

func setup_house_animation():
	"""Set up the house animation system"""
	if animation_resource:
		apply_animation_resource()

func apply_animation_resource():
	"""Apply animation resource for modular house designs"""
	if not animation_resource:
		return
	# This will be expanded when we implement the animation resource system

func set_house_tile_position(tile_pos: Vector2i):
	"""Set which tile this house occupies for targeting exclusions"""
	house_tile_position = tile_pos

func is_enemy_on_house_tile(enemy_position: Vector2) -> bool:
	"""Check if an enemy position is on the house tile"""
	# Convert world position to tile position (assuming 64x64 tiles)
	var tile_size = 64
	var enemy_tile = Vector2i(int(enemy_position.x / tile_size), int(enemy_position.y / tile_size))
	
	# Check if enemy is within the house's tile area
	for x in range(house_size.x):
		for y in range(house_size.y):
			if enemy_tile == house_tile_position + Vector2i(x, y):
				return true
	return false

func enemy_enters_house(enemy: Node2D):
	"""Called when an enemy reaches the house"""
	if enemy in enemies_inside:
		return  # Enemy already inside
	enemies_inside.append(enemy)
	
	# Signal that an enemy has reached the house (this will trigger health reduction via connected signal)
	enemy_reached_house.emit(enemy)
	
	# Remove enemy from the game after a short delay
	var timer = Timer.new()
	add_child(timer)
	timer.wait_time = 0.9  # Slightly longer than shrinking animation (0.8s)
	timer.one_shot = true
	timer.connect("timeout", func(): 
		if enemy and is_instance_valid(enemy):
			enemy.queue_free()
		if enemy in enemies_inside:
			enemies_inside.erase(enemy)
		timer.queue_free()
	)
	timer.start()

func get_house_tiles() -> Array[Vector2i]:
	"""Get all tile positions occupied by this house"""
	var tiles: Array[Vector2i] = []
	for x in range(house_size.x):
		for y in range(house_size.y):
			tiles.append(house_tile_position + Vector2i(x, y))
	return tiles

func set_house_skin(skin_name: String):
	"""Set the visual skin of the house"""
	house_skin = skin_name
	
	# Update the animation to use the new skin
	if $AnimatedSprite2D.sprite_frames and $AnimatedSprite2D.sprite_frames.has_animation(skin_name):
		var current_frame = $AnimatedSprite2D.frame
		$AnimatedSprite2D.play(skin_name)
		$AnimatedSprite2D.pause()
		$AnimatedSprite2D.frame = current_frame  # Maintain current door state

func get_house_skin() -> String:
	"""Get the current house skin"""
	return house_skin
