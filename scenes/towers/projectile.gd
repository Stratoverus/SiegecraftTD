extends Node2D

@export var damage: int = 1
@export var speed: float = 200.0
@export var level: int = 1
var target = null
var target_position = Vector2.ZERO
var validated_target_position = Vector2.ZERO  # Pre-calculated validated position from tower
var is_splash_projectile = false
var splash_radius = 0.0
var has_hit_target = false  # Prevent multiple damage applications


func set_target_position(target_pos: Vector2):
	"""Set the pre-validated target position from the tower's range checking"""
	validated_target_position = target_pos


func launch(enemy):
	target = enemy
	if has_node("projectileAnim"):
		$projectileAnim.play("level" + str(level))
	
	# Use validated position if available, otherwise predict
	if validated_target_position != Vector2.ZERO:
		target_position = validated_target_position
	elif is_splash_projectile and is_instance_valid(target):
		predict_target_position()
	else:
		target_position = target.global_position if is_instance_valid(target) else global_position


func instant_impact():
	# For instant impact projectiles (speed = 0), trigger impact immediately
	
	# Prevent multiple impacts
	if has_hit_target:
		return
	
	if is_splash_projectile:
		create_splash_damage()
		has_hit_target = true
	else:
		# Direct hit damage
		has_hit_target = true
		create_impact_animation()
		if is_instance_valid(target):
			target.take_damage(damage)
	
	# Small delay to ensure impact animation starts before projectile is freed
	await get_tree().create_timer(0.05).timeout
	queue_free()


func predict_target_position():
	if not is_instance_valid(target):
		target_position = global_position
		return
	
	# Calculate time to reach target
	var distance_to_target = global_position.distance_to(target.global_position)
	var time_to_impact = distance_to_target / speed
	
	# For splash projectiles, aim slightly ahead to compensate for the explosion radius
	var prediction_multiplier = 1.2 # Lead target a bit more for splash weapons
	var predicted_time = time_to_impact * prediction_multiplier
	
	# Predict where the enemy will be along their path
	target_position = predict_enemy_position_on_path(target, predicted_time)


func predict_enemy_position_on_path(enemy, time_ahead: float) -> Vector2:
	if not is_instance_valid(enemy) or not "path" in enemy or not "path_index" in enemy or not "speed" in enemy:
		return enemy.global_position if is_instance_valid(enemy) else global_position
	
	var enemy_path = enemy.path
	var current_index = enemy.path_index
	var enemy_speed = enemy.speed
	var current_pos = enemy.global_position
	
	# If enemy has no more path points, return current position
	if current_index >= enemy_path.size():
		return current_pos
	
	# Calculate how far the enemy will travel in the given time
	var distance_to_travel = enemy_speed * time_ahead
	var predicted_pos = current_pos
	var remaining_distance = distance_to_travel
	var path_idx = current_index
	
	# Walk along the path for the predicted distance
	while remaining_distance > 0 and path_idx < enemy_path.size():
		var target_point = enemy_path[path_idx]
		var distance_to_next = predicted_pos.distance_to(target_point)
		
		if distance_to_next <= remaining_distance:
			# Enemy will reach this path point and continue
			predicted_pos = target_point
			remaining_distance -= distance_to_next
			path_idx += 1
		else:
			# Enemy will be somewhere between current position and next path point
			var direction = (target_point - predicted_pos).normalized()
			predicted_pos += direction * remaining_distance
			remaining_distance = 0
	
	return predicted_pos

func _process(delta):
	# Skip movement if speed is 0 (instant impact projectiles)
	if speed == 0:
		return
	
	# Skip if we already hit the target
	if has_hit_target:
		return
	
	# For splash projectiles, move toward predicted position instead of tracking target
	if is_splash_projectile:
		var to_target = target_position - global_position
		var distance = to_target.length()
		if distance < speed * delta:
			# Reached target position, explode
			create_splash_damage()
			# Small delay to ensure impact animation starts before projectile is freed
			await get_tree().create_timer(0.05).timeout
			queue_free()
			return
		var direction = to_target.normalized()
		global_position += direction * speed * delta
		rotation = direction.angle() + PI / 2
	else:
		# Original homing behavior for non-splash projectiles
		if not is_instance_valid(target):
			queue_free()
			return
		var to_target = target.global_position - global_position
		var distance = to_target.length()
		if distance < speed * delta:
			# Create impact animation for direct hit
			create_impact_animation()
			has_hit_target = true
			target.take_damage(damage)
			# Small delay to ensure impact animation starts before projectile is freed
			await get_tree().create_timer(0.05).timeout
			queue_free()
			return
		var direction = to_target.normalized()
		global_position += direction * speed * delta
		rotation = direction.angle() + PI / 2


func create_splash_damage():
	# Prevent multiple splash damage applications
	if has_hit_target:
		return
		
	# Validate that impact location is on road tile
	var main_scene = get_tree().current_scene
	if main_scene.has_method("is_position_on_road_tile"):
		var is_on_road = main_scene.is_position_on_road_tile(global_position)
		if not is_on_road:
			has_hit_target = true
			return
	
	has_hit_target = true
	
	# Create impact animation first
	create_impact_animation()
	
	# Find all enemies within splash radius
	var enemies = get_tree().get_nodes_in_group("enemies")
	for enemy in enemies:
		if is_instance_valid(enemy) and enemy.has_method("take_damage"):
			var distance_to_enemy = global_position.distance_to(enemy.global_position)
			if distance_to_enemy <= splash_radius:
				# Calculate damage falloff: 100% at center, 50% at edge
				var damage_multiplier = 1.0 - (distance_to_enemy / splash_radius) * 0.5
				var splash_damage = int(damage * damage_multiplier)
				enemy.take_damage(splash_damage)



func create_impact_animation():
	var anim_node = $projectileAnim
	var impact_anim_name = ""
	
	# First, get all available animation names to understand what we have
	var all_animations = anim_node.sprite_frames.get_animation_names()
	
	# Count how many impact animations are available
	var impact_animations = []
	for anim_name in all_animations:
		if anim_name.begins_with("impact") or anim_name.begins_with("explosion"):
			impact_animations.append(anim_name)
	
	
	# If there's only one impact animation, use it for all levels
	if impact_animations.size() == 1:
		impact_anim_name = impact_animations[0]
	else:
		# Multiple impact animations available - try to find level-specific one
		var possible_names = [
			"impact" + str(level),
			"impactL" + str(level), 
			"explosion" + str(level),
			"explosionL" + str(level),
			"impact",
			"explosion"
		]
		
		for anim_name in possible_names:
			if anim_node.sprite_frames.has_animation(anim_name):
				impact_anim_name = anim_name
				break
	
	if impact_anim_name != "":
		# Create a separate node for the impact animation so it persists after projectile is freed
		var impact_instance = AnimatedSprite2D.new()
		impact_instance.sprite_frames = anim_node.sprite_frames
		
		# For direct hits, position at target location; for splash, position at explosion point
		if is_splash_projectile:
			impact_instance.position = global_position
		else:
			# For direct hits, position at the target if it's still valid
			if is_instance_valid(target):
				impact_instance.position = target.global_position
			else:
				impact_instance.position = global_position
		
		impact_instance.z_index = z_index + 1  # Ensure impact appears above projectile
		
		# Scale the impact animation for splash towers to match splash radius
		if is_splash_projectile and splash_radius > 0:
			# Get the actual size of the impact animation frame
			var anim_frame = anim_node.sprite_frames.get_frame_texture(impact_anim_name, 0)
			if anim_frame:
				var frame_size = anim_frame.get_size()
				# Use the smaller dimension to ensure the animation fits within the splash radius
				var frame_radius = min(frame_size.x, frame_size.y) / 2.0
				
				# Calculate scale to make animation diameter match splash diameter
				var scale_factor = (splash_radius * 2.0) / (frame_radius * 2.0)  # splash diameter / frame diameter
				
				# Apply reasonable bounds
				scale_factor = clamp(scale_factor, 0.3, 8.0)
				impact_instance.scale = Vector2(scale_factor, scale_factor)
			else:
				# Fallback to simple ratio method if we can't get frame size
				var scale_factor = splash_radius / 32.0  # Assume 64px default frame size
				scale_factor = clamp(scale_factor, 0.5, 4.0)
				impact_instance.scale = Vector2(scale_factor, scale_factor)
		
		get_tree().current_scene.add_child(impact_instance)
		impact_instance.play(impact_anim_name)
		
		# Remove the impact animation when it finishes
		impact_instance.animation_finished.connect(func(): impact_instance.queue_free())
