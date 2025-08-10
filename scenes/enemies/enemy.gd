extends Node2D

# Enemy data resource
@export var enemy_data: Resource = null

# Path and movement
var path: Array = []
var path_index: int = 0
var speed: float = 100.0

# Health system
var max_health: int = 100
var health: int = max_health
var has_scaled_health: bool = false  # Track if health has been scaled

# Health bar settings
var health_bar_width := 32
var health_bar_height := 4
var health_bar_offset := Vector2(0, -32)

var is_dead = false
var has_entered_house = false  # Prevent duplicate house entries
var has_finished_shrinking = false  # Prevent duplicate shrinking finished calls

signal enemy_died(gold)
var gold_worth: int = 5

# Unique identifier for debugging
static var enemy_counter = 0
var enemy_id: int

func _ready():
	add_to_group("enemies")
	
	# Assign unique ID for debugging
	enemy_counter += 1
	enemy_id = enemy_counter
	
	# Initialize from enemy data if provided
	if enemy_data:
		apply_enemy_data()
	
	play_walk_animation()
	set_process(true)

func apply_enemy_data():
	"""Apply stats from the EnemyData resource"""
	if not enemy_data:
		return
		
	# Only reset health if it hasn't been scaled
	if not has_scaled_health:
		max_health = enemy_data.max_health
		health = max_health
	
	speed = enemy_data.speed
	gold_worth = enemy_data.gold_worth
	health_bar_width = enemy_data.health_bar_width
	health_bar_height = enemy_data.health_bar_height
	health_bar_offset = enemy_data.health_bar_offset

# Set enemy data (for dynamic spawning)
func set_enemy_data(data: Resource):
	enemy_data = data
	if is_inside_tree():
		apply_enemy_data()

func set_health(new_health: int):
	"""Set both max_health and current health (for scaling)"""
	max_health = new_health
	health = new_health
	has_scaled_health = true  # Mark that this enemy has scaled health

func is_facing_down(direction: Vector2) -> bool:
	return direction.y > 0.5

func play_walk_animation(direction := Vector2.ZERO):
	if direction == Vector2.ZERO and path_index < path.size():
		direction = (path[path_index] - position).normalized()
	
	# Use enemy data animation names if available, otherwise use defaults
	var walk_anim = "walk"
	var walk_down_anim = "walkDown"
	
	if enemy_data and enemy_data.has_directional_animations:
		walk_anim = enemy_data.walk_animation_name
		walk_down_anim = enemy_data.walk_down_animation_name
	
	if is_facing_down(direction):
		$AnimatedSprite2D.play(walk_down_anim)
	else:
		$AnimatedSprite2D.play(walk_anim)

func _process(delta):
	if is_dead:
		# Even when dead (shrinking), continue moving forward slowly until very close to house
		if path_index < path.size():
			var target = path[path_index]
			var distance_to_target = position.distance_to(target)
			# Only move if we're still reasonably far from the house
			if distance_to_target > 10.0:  # Stop moving when very close
				var direction = (target - position).normalized()
				position += direction * (speed * 0.3) * delta  # Move at 30% speed while shrinking
		return
		
	if path_index < path.size():
		var target = path[path_index]
		var direction = (target - position).normalized()
		position += direction * speed * delta
		if is_facing_down(direction):
			$AnimatedSprite2D.rotation = 0
		else:
			$AnimatedSprite2D.rotation = direction.angle() + PI / 2
			
		# Check if we're close to the target
		var distance_to_target = position.distance_to(target)
		if distance_to_target < 2.0:
			path_index += 1
			
			# Check if we just entered the last tile (final destination)
			if path_index >= path.size() - 1:
				# Continue moving closer to the house before shrinking
				var houses = get_tree().get_nodes_in_group("houses")
				if houses.size() > 0:
					var house = houses[0]
					var distance_to_house = position.distance_to(house.global_position)
					# Start shrinking when we're close to the actual house position
					if distance_to_house < 30.0:
						handle_reached_destination()
						return
				else:
					# No house found, start shrinking immediately
					handle_reached_destination()
					return
			
		# Check if we're approaching the final destination (house)
		if path_index >= path.size() - 2 and distance_to_target < 50.0:
			# Add slight glow effect when approaching house
			modulate = Color(1.2, 1.2, 1.2, 1.0)
			
		play_walk_animation(direction)
		queue_redraw() # Redraw health bar
	else:
		# Enemy has reached the end of the path (backup case)
		handle_reached_destination()


# Helper methods for projectile trajectory prediction
func get_velocity() -> Vector2:
	if is_dead or path_index >= path.size():
		return Vector2.ZERO
	var target = path[path_index]
	var direction = (target - position).normalized()
	return direction * speed


func get_direction() -> Vector2:
	if is_dead or path_index >= path.size():
		return Vector2.ZERO
	var target = path[path_index]
	return (target - position).normalized()


func get_speed() -> float:
	return speed if not is_dead else 0.0


# Call this to deal damage to the enemy
func take_damage(amount: int):
	if is_dead:
		return
	health = max(health - amount, 0)
	
	# Show damage number above enemy
	show_damage_number(amount)
	
	if health == 0:
		die()
	queue_redraw()

func show_damage_number(damage: int):
	"""Show small, fast damage number above the enemy"""
	# Performance optimization disabled for testing
	# var enemies = get_tree().get_nodes_in_group("enemies")
	# if enemies.size() > 15:  # If more than 15 enemies, only show every 3rd damage number
	#	if randi() % 3 != 0:
	#		return
	
	# Create damage number label
	var damage_label = Label.new()
	damage_label.text = str(damage)
	damage_label.add_theme_font_size_override("font_size", 14)  # Even smaller font
	damage_label.add_theme_color_override("font_color", Color.WHITE)
	damage_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	damage_label.add_theme_constant_override("shadow_offset_x", 1)
	damage_label.add_theme_constant_override("shadow_offset_y", 1)
	
	# Position above the enemy with slight random offset to avoid overlapping
	var damage_position = global_position
	damage_position.y -= 35  # Slightly closer to enemy
	damage_position.x += randf_range(-12, 12)  # Smaller random horizontal offset
	damage_label.position = damage_position
	damage_label.z_index = 200  # Higher than other elements
	damage_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	
	# Add to the main scene (not CanvasLayer) for world positioning
	get_tree().current_scene.add_child(damage_label)
	
	# Very fast animation - minimal movement, quick fade
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(damage_label, "position:y", damage_label.position.y - 15, 0.5)  # Even faster (0.5s), less movement
	tween.tween_property(damage_label, "modulate:a", 0.0, 0.5)
	
	# Very subtle scale animation 
	var scale_tween = create_tween()
	scale_tween.tween_property(damage_label, "scale", Vector2(1.05, 1.05), 0.1)  # Very small scale change
	scale_tween.tween_property(damage_label, "scale", Vector2(1.0, 1.0), 0.1)
	
	# Clean up when finished
	tween.connect("finished", func(): 
		damage_label.queue_free()
	)

func die():
	if is_dead:
		return
	is_dead = true
	emit_signal("enemy_died", gold_worth)
	var last_direction = Vector2.ZERO
	if path_index < path.size():
		last_direction = (path[path_index] - position).normalized()
	
	# Use enemy data animation names if available, otherwise use defaults
	var die_anim = "die"
	var die_down_anim = "dieDown"
	
	if enemy_data and enemy_data.has_directional_animations:
		die_anim = enemy_data.die_animation_name
		die_down_anim = enemy_data.die_down_animation_name
	
	if is_facing_down(last_direction):
		$AnimatedSprite2D.play(die_down_anim)
		$AnimatedSprite2D.rotation = 0
	else:
		$AnimatedSprite2D.play(die_anim)
		$AnimatedSprite2D.rotation = last_direction.angle() + PI / 2
	
	# Disconnect first to avoid duplicate connections
	if $AnimatedSprite2D.is_connected("animation_finished", Callable(self, "_on_death_animation_finished")):
		$AnimatedSprite2D.disconnect("animation_finished", Callable(self, "_on_death_animation_finished"))
	$AnimatedSprite2D.connect("animation_finished", Callable(self, "_on_death_animation_finished"))

func _on_death_animation_finished():
	# Only fade out if the finished animation is 'die' or 'dieDown' (or their custom equivalents)
	var die_anim = "die"
	var die_down_anim = "dieDown"
	
	if enemy_data and enemy_data.has_directional_animations:
		die_anim = enemy_data.die_animation_name
		die_down_anim = enemy_data.die_down_animation_name
	
	if $AnimatedSprite2D.animation == die_anim or $AnimatedSprite2D.animation == die_down_anim:
		if $AnimatedSprite2D.is_connected("animation_finished", Callable(self, "_on_death_animation_finished")):
			$AnimatedSprite2D.disconnect("animation_finished", Callable(self, "_on_death_animation_finished"))
		var tween = create_tween()
		tween.tween_property(self, "modulate:a", 0.0, 0.5)
		tween.connect("finished", Callable(self, "_on_fade_out_finished"))

func _on_fade_out_finished():
	queue_free()

func handle_reached_destination():
	"""Called when enemy reaches the end of the path (the house)"""
	if is_dead or has_entered_house:
		return
		
	has_entered_house = true
	
	# Start shrinking animation to simulate going through the door
	start_shrinking_animation()

func start_shrinking_animation():
	"""Animate the enemy shrinking as they enter the house"""
	if is_dead:
		return
		
	is_dead = true  # Prevent further movement and damage
	
	# Reset any glow effect from approaching
	modulate = Color.WHITE
	
	# Create shrinking tween (faster animation)
	var shrink_tween = create_tween()
	shrink_tween.set_parallel(true)  # Allow multiple properties to animate together
	
	# Shrink the sprite to simulate going through the door (faster: 0.8 seconds instead of 1.5)
	shrink_tween.tween_property($AnimatedSprite2D, "scale", Vector2(0.1, 0.1), 0.8)
	shrink_tween.tween_property($AnimatedSprite2D, "modulate:a", 0.2, 0.8)  # Fade significantly
	
	# Very slight upward movement to simulate entering the door (reduced to 2 pixels)
	shrink_tween.tween_property(self, "position:y", position.y - -15, 0.8)
	
	# When shrinking is complete, handle the health reduction
	shrink_tween.connect("finished", Callable(self, "_on_shrinking_finished"))

func _on_shrinking_finished():
	"""Called when the shrinking animation completes"""
	if has_finished_shrinking:
		return
		
	has_finished_shrinking = true
	
	# Find the house and let it handle the enemy entering
	var houses = get_tree().get_nodes_in_group("houses")
	if houses.size() > 0:
		var house = houses[0]  # Assume one house for now
		house.enemy_enters_house(self)
	else:
		# Fallback if no house found - damage player directly
		var main_game = get_tree().get_first_node_in_group("main_game")
		if main_game and main_game.has_method("lose_health"):
			main_game.lose_health(1)
		queue_free()

# Draw the health bar above the enemy
func _draw():
	if is_dead or health == 0:
		return
	if health < max_health:
		var bar_pos = health_bar_offset - Vector2(health_bar_width / 2.0, 0)
		var green_width = int(health_bar_width * (float(health) / float(max_health)))
		var red_width = health_bar_width - green_width
		# Draw green part
		if green_width > 0:
			draw_rect(Rect2(bar_pos, Vector2(green_width, health_bar_height)), Color(0,1,0))
		# Draw red part
		if red_width > 0:
			draw_rect(Rect2(bar_pos + Vector2(green_width,0), Vector2(red_width, health_bar_height)), Color(1,0,0))
