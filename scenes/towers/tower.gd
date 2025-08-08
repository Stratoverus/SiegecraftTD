extends Node2D

# Tower stats and attack logic
@export var tower_data: Resource  # Assign your TowerData resource in the editor

var attack_range: float
var attack_speed: float
var damage: int
var attack_cooldown := 0.0
var target = null
var just_placed = true
var is_being_destroyed := false

# Store the last target's position for smarter retargeting
var last_target_position = null

# Variables for frame-based projectile spawning
var pending_projectile_target = null
var projectile_spawned = false

# Variables for rapid-fire towers
var rapid_fire_count = 0
var rapid_fire_max = 0
var current_barrel_angle = 0.0
var rapid_fire_targets = []  # Array to store different targets for each barrel
var is_in_rapid_fire_sequence = false  # Flag to prevent _process from overriding barrel rotation

# Upgrade and sprite logic
@export var level: int = 1
@export var level_regions: Array[Rect2] = []
@export var weapon_offset_from_top: int = 20

# Attack range visualization
var range_indicator: Node2D = null
var is_range_visible: bool = false

# Weapon rotation animation
var target_rotation_tween: Tween = null

func _ready():
	print("[tower] _ready called, level:", level, " tower_data:", tower_data)
	apply_level_stats()
	update_base_sprite()
	update_weapon_animation()
	update_weapon_position()
	
	# Connect to the weapon animation signals for projectile spawning
	if has_node("towerWeapon") and $towerWeapon is AnimatedSprite2D:
		if not $towerWeapon.frame_changed.is_connected(_on_weapon_frame_changed):
			$towerWeapon.frame_changed.connect(_on_weapon_frame_changed)
		if not $towerWeapon.animation_finished.is_connected(_on_weapon_animation_finished):
			$towerWeapon.animation_finished.connect(_on_weapon_animation_finished)
	
	await get_tree().create_timer(0.2).timeout
	just_placed = false

func _process(delta):
	attack_cooldown -= delta
	if not is_valid_target(target):
		# If we had a target, remember its last position for retargeting
		if target and target is Node2D:
			last_target_position = target.global_position
		# Try to find a new target near the last target's position
		if last_target_position:
			target = find_target(last_target_position)
		else:
			target = find_target()
	if target and attack_cooldown <= 0.0:
		attack_target(target)
		attack_cooldown = 1.0 / attack_speed

	# Rotate weapon if needed (but not during rapid fire sequences)
	if target and tower_data.weapon_rotates and not is_in_rapid_fire_sequence:
		if tower_data.type == "rapid" and level > 1:
			point_weapon_at_for_rapid_fire(target.global_position)
		else:
			point_weapon_at(target.global_position)

# --- Attack logic ---
func is_valid_target(enemy):
	return enemy and enemy.is_inside_tree() and enemy.health > 0 and position.distance_to(enemy.position) <= attack_range


# Optionally pass a position to find the closest enemy to that point (default: tower's position)
func find_target(reference_position = null):
	var enemies = get_tree().get_nodes_in_group("enemies")
	var best = null
	var best_dist = INF
	var ref_pos = reference_position if reference_position != null else position
	for enemy in enemies:
		if enemy.health > 0:
			var dist_to_ref = ref_pos.distance_to(enemy.position)
			var dist_to_tower = position.distance_to(enemy.position)
			# Only consider enemies within the tower's own range
			if dist_to_tower <= attack_range and dist_to_ref < best_dist:
				best = enemy
				best_dist = dist_to_ref
	return best


func attack_target(enemy):
	# Store the target for projectile spawning
	pending_projectile_target = enemy
	projectile_spawned = false
	
	# Handle rapid-fire towers (but treat Level 1 rapid towers as normal towers)
	if tower_data.type == "rapid" and level > 1:
		setup_rapid_fire()
		# For rapid towers, rotate to point the first barrel at target
		if tower_data.weapon_rotates:
			point_weapon_at_for_rapid_fire(enemy.global_position)
	
	# Interrupt any current animation and play firing animation
	if has_node("towerWeapon") and $towerWeapon is AnimatedSprite2D:
		# Stop current animation (idle or whatever is playing)
		$towerWeapon.stop()
		
		# Calculate appropriate animation speed
		# Default animation speed is 1.0, only speed up if attack speed is faster
		var animation_speed = max(1.0, attack_speed)
		
		$towerWeapon.speed_scale = animation_speed
		$towerWeapon.play("firingL" + str(level))
		print("[tower] Playing firing animation at speed: ", animation_speed, " (attack_speed: ", attack_speed, ")")
		print("[tower] Animation will ", "speed up" if animation_speed > 1.0 else "play at normal speed")


func setup_rapid_fire():
	# Set up rapid fire based on level
	match level:
		1:
			rapid_fire_max = 1
		2:
			rapid_fire_max = 2
		3:
			rapid_fire_max = 4
	
	rapid_fire_count = 0
	current_barrel_angle = 0.0
	is_in_rapid_fire_sequence = true  # Prevent _process from overriding barrel rotation
	
	# Find multiple targets for rapid fire
	rapid_fire_targets = find_multiple_targets(rapid_fire_max)


func find_multiple_targets(max_targets: int) -> Array:
	var enemies = get_tree().get_nodes_in_group("enemies")
	var valid_targets = []
	
	# Find all enemies within range
	for enemy in enemies:
		if enemy.health > 0 and position.distance_to(enemy.position) <= attack_range:
			valid_targets.append(enemy)
	
	# Sort by distance (closest first)
	valid_targets.sort_custom(func(a, b): return position.distance_to(a.position) < position.distance_to(b.position))
	
	# Prepare target array
	var targets = []
	
	if valid_targets.size() >= max_targets:
		# Enough enemies: take the closest ones
		for i in range(max_targets):
			targets.append(valid_targets[i])
	else:
		# Not enough enemies: spread the volleys evenly
		var enemy_count = valid_targets.size()
		if enemy_count == 0:
			# No enemies, use the original target
			for i in range(max_targets):
				targets.append(pending_projectile_target)
		else:
			# Distribute shots among available enemies
			for i in range(max_targets):
				var target_index = i % enemy_count  # Cycle through available enemies
				targets.append(valid_targets[target_index])
	
	return targets


func point_weapon_at_for_rapid_fire(target_position: Vector2) -> void:
	if has_node("towerWeapon"):
		var weapon_sprite = $towerWeapon
		var weapon_global_pos = weapon_sprite.get_global_position()
		var angle_to_target = weapon_global_pos.angle_to_point(target_position)
		
		# For rapid-fire towers, calculate which barrel should face the target
		if tower_data.type == "rapid":
			# Align the weapon so that the current barrel points at the target
			# The barrel positions are at 0°, 90°, 180°, 270° relative to weapon rotation
			var barrel_offset = current_barrel_angle * PI / 180.0
			weapon_sprite.rotation = angle_to_target + PI / 2 - barrel_offset
		else:
			weapon_sprite.rotation = angle_to_target + PI / 2


# Handle frame-based projectile spawning
func _on_weapon_frame_changed():
	if has_node("towerWeapon") and $towerWeapon is AnimatedSprite2D:
		var current_frame = $towerWeapon.frame
		
		# Handle rapid-fire towers with multiple release frames (but treat Level 1 as normal)
		if tower_data.type == "rapid" and level > 1:
			handle_rapid_fire_frame(current_frame)
		else:
			# Standard single projectile spawning (including Level 1 rapid towers)
			var release_frame = tower_data.projectile_release_frame
			if current_frame == release_frame and pending_projectile_target and not projectile_spawned:
				print("[tower] Spawning projectile at frame ", current_frame, " (release frame: ", release_frame, ")")
				spawn_projectile(pending_projectile_target)
				projectile_spawned = true


func handle_rapid_fire_frame(current_frame: int):
	if rapid_fire_count >= rapid_fire_max or rapid_fire_targets.size() == 0:
		return
	
	var base_frame = tower_data.projectile_release_frame  # This should be 4 for tower7
	var should_fire = false
	var should_rotate_next = false  # For Level 3, pre-rotate for the NEXT shot
	
	# Determine which frames should fire and rotate based on level and current frame
	match level:
		1:
			# Level 1: Fire only at frame 4
			should_fire = (current_frame == base_frame)
		2:
			# Level 2: Fire at frames 4 and 5
			should_fire = (current_frame == base_frame or current_frame == base_frame + 1)
		3:
			# Level 3: Fire at frames 4, 5, 6, 7
			should_fire = (current_frame >= base_frame and current_frame <= base_frame + 3)
			# Pre-rotate for next barrel while current barrel is firing
			should_rotate_next = (current_frame >= base_frame and current_frame <= base_frame + 2)
	
	# Handle current shot firing
	if should_fire and rapid_fire_count < rapid_fire_max:
		var current_target = rapid_fire_targets[rapid_fire_count]
		print("[tower] Rapid fire: spawning projectile ", rapid_fire_count + 1, " of ", rapid_fire_max, " at frame ", current_frame, " targeting: ", current_target)
		
		# For Level 1 and 2, rotate at firing time
		if level == 1 or level == 2:
			calculate_barrel_position_for_shot()
			animate_barrel_rotation_to_target_immediate(current_target)
		# For Level 3, rotation should already be ready from previous frame
		
		# Spawn projectile at current target
		spawn_projectile(current_target)
		rapid_fire_count += 1
	
	# Handle Level 3 pre-rotation for NEXT shot (after current shot fires)
	if level == 3 and should_rotate_next and rapid_fire_count < rapid_fire_max:
		# Pre-rotate for the next shot that will fire on the next frame
		var next_target_index = rapid_fire_count
		if next_target_index < rapid_fire_targets.size():
			var next_target = rapid_fire_targets[next_target_index]
			print("[tower] Level 3: Pre-rotating for upcoming shot ", next_target_index + 1, " at frame ", current_frame)
			# Calculate what the next barrel position will be
			var temp_count = rapid_fire_count
			calculate_barrel_position_for_shot()
			rapid_fire_count = temp_count  # Restore the count since we're just pre-calculating
			animate_barrel_rotation_to_target_immediate(next_target)


func rotate_to_current_target(target_enemy):
	# Rotate weapon to point current barrel at the target enemy
	if is_instance_valid(target_enemy) and has_node("towerWeapon"):
		var weapon_sprite = $towerWeapon
		var weapon_global_pos = weapon_sprite.get_global_position()
		var angle_to_target = weapon_global_pos.angle_to_point(target_enemy.global_position)
		
		# Calculate rotation needed to point current barrel at target
		var barrel_offset = deg_to_rad(current_barrel_angle)
		weapon_sprite.rotation = angle_to_target + PI / 2 - barrel_offset
		
		print("[tower] Rotating to barrel ", rapid_fire_count + 1, " (angle: ", current_barrel_angle, "°) to target enemy at ", target_enemy.global_position)


func animate_barrel_rotation_to_target(target_enemy):
	# Animate weapon rotation to point current barrel at the target enemy with visible motion
	if is_instance_valid(target_enemy) and has_node("towerWeapon"):
		var weapon_sprite = $towerWeapon
		var weapon_global_pos = weapon_sprite.get_global_position()
		var angle_to_target = weapon_global_pos.angle_to_point(target_enemy.global_position)
		
		# Calculate rotation needed to point current barrel at target
		var barrel_offset = deg_to_rad(current_barrel_angle)
		var target_rotation = angle_to_target + PI / 2 - barrel_offset
		
		print("[tower] Animating barrel ", rapid_fire_count + 1, " (angle: ", current_barrel_angle, "°) to target enemy at ", target_enemy.global_position)
		print("[tower] Current rotation: ", rad_to_deg(weapon_sprite.rotation), "° -> Target rotation: ", rad_to_deg(target_rotation), "°")
		
		# Create a tween for smooth rotation
		var tween = create_tween()
		tween.tween_property(weapon_sprite, "rotation", target_rotation, 0.15)  # 150ms rotation
		await tween.finished


func animate_barrel_rotation_to_target_immediate(target_enemy):
	# Immediately rotate weapon to point current barrel at the target enemy with visual feedback
	if is_instance_valid(target_enemy) and has_node("towerWeapon"):
		var weapon_sprite = $towerWeapon
		var weapon_global_pos = weapon_sprite.get_global_position()
		var angle_to_target = weapon_global_pos.angle_to_point(target_enemy.global_position)
		
		# Store the previous rotation for debugging
		var previous_rotation = weapon_sprite.rotation
		
		# Calculate rotation needed to point current barrel at target
		var barrel_offset = deg_to_rad(current_barrel_angle)
		var target_rotation = angle_to_target + PI / 2 - barrel_offset
		
		print("[tower] =================")
		print("[tower] BARREL ROTATION: Barrel ", rapid_fire_count + 1, " of ", rapid_fire_max, " (angle: ", current_barrel_angle, "°)")
		print("[tower] Previous rotation: ", rad_to_deg(previous_rotation), "°")
		print("[tower] Target rotation: ", rad_to_deg(target_rotation), "°")
		print("[tower] Rotation change: ", rad_to_deg(target_rotation - previous_rotation), "°")
		print("[tower] Barrel offset: ", rad_to_deg(barrel_offset), "°")
		print("[tower] is_in_rapid_fire_sequence: ", is_in_rapid_fire_sequence)
		
		# For Level 2, ensure we always see a dramatic rotation between barrels
		if level == 2 and rapid_fire_count == 1:
			# Force a 180° rotation for the second barrel regardless of target position
			var forced_rotation = previous_rotation + PI  # Add 180 degrees
			print("[tower] Level 2: Forcing 180° rotation for barrel 2")
			print("[tower] Forced rotation: ", rad_to_deg(forced_rotation), "°")
			target_rotation = forced_rotation
		
		print("[tower] Final target rotation: ", rad_to_deg(target_rotation), "°")
		print("[tower] =================")
		
		# For Level 2, animate the rotation smoothly instead of instant
		if level == 2 and rapid_fire_count == 1:
			# Smooth 180° rotation for Level 2 barrel 2 - start immediately, don't wait for projectile
			var tween = create_tween()
			tween.tween_property(weapon_sprite, "rotation", target_rotation, 0.15)  # Faster 150ms rotation
			# Don't await - let the rotation happen while projectile fires
		else:
			# Apply the rotation immediately for other levels
			weapon_sprite.rotation = target_rotation
			
			# Make the rotation even more visible with a bigger overshoot for Level 3
			if level == 3 and abs(target_rotation - previous_rotation) > 0.1:
				# Create a dramatic visual "snap" by overshooting and coming back
				var overshoot_amount = 45.0  # 45 degree overshoot for more visibility
				var overshoot = target_rotation + deg_to_rad(overshoot_amount)
				var tween = create_tween()
				tween.tween_property(weapon_sprite, "rotation", overshoot, 0.1)
				tween.tween_property(weapon_sprite, "rotation", target_rotation, 0.1)
		
		# Double-check that rotation is applied
		await get_tree().process_frame
		print("[tower] Final weapon rotation after frame: ", rad_to_deg(weapon_sprite.rotation), "°")


func calculate_barrel_position_for_shot():
	# Calculate which barrel is firing based on current shot and level
	if level == 1:
		# Level 1: single barrel at top (0°)
		current_barrel_angle = 0.0
	elif level == 2:
		# Level 2: 2 barrels - top (0°) then bottom (180°)
		match rapid_fire_count:
			0:
				current_barrel_angle = 0.0    # Top barrel first
			1:
				current_barrel_angle = 180.0  # Bottom barrel second
	elif level == 3:
		# Level 3: 4 barrels - top (0°), right (90°), bottom (180°), left (270°)
		match rapid_fire_count:
			0:
				current_barrel_angle = 0.0    # Top barrel first
			1:
				current_barrel_angle = 90.0   # Right barrel second
			2:
				current_barrel_angle = 180.0  # Bottom barrel third
			3:
				current_barrel_angle = 270.0  # Left barrel fourth


func rotate_to_next_barrel():
	# Rotate weapon to point next barrel at target if we have more shots
	if pending_projectile_target and is_instance_valid(pending_projectile_target):
		if level == 2:
			current_barrel_angle = ((rapid_fire_count) % 2) * 180.0
		elif level == 3:
			current_barrel_angle = ((rapid_fire_count) % 4) * 90.0
		
		point_weapon_at_for_rapid_fire(pending_projectile_target.global_position)


# Clear pending projectile when animation finishes
func _on_weapon_animation_finished():
	pending_projectile_target = null
	projectile_spawned = false
	# Reset rapid fire counters and flag
	rapid_fire_count = 0
	rapid_fire_max = 0
	rapid_fire_targets.clear()
	is_in_rapid_fire_sequence = false  # Allow normal weapon rotation again
	
	# Return to idle animation if no enemies are detected
	if not target or not is_valid_target(target):
		return_to_idle_animation()


func spawn_projectile(enemy):
	# Instance and launch projectile
	var projectile_scene = load(tower_data.projectile_scene)
	var projectile = projectile_scene.instantiate()
	
	# Calculate projectile spawn position
	var spawn_position = global_position
	if has_node("towerWeapon"):
		spawn_position = $towerWeapon.get_global_position()
	
	# Check if this is an instant impact projectile (speed = 0)
	var projectile_speed = tower_data.projectile_speed[level - 1]
	if projectile_speed == 0:
		# Instant impact - spawn directly at target location
		if is_instance_valid(enemy):
			spawn_position = enemy.global_position
		print("[tower] Spawning instant impact projectile at target location: ", spawn_position)
	else:
		# Normal projectile - spawn from weapon
		print("[tower] Spawning normal projectile from weapon at: ", spawn_position)
	
	projectile.global_position = spawn_position
	projectile.damage = damage
	projectile.speed = projectile_speed
	projectile.target = enemy
	projectile.level = level # Ensure projectile anim matches tower level
	projectile.z_index = 1000
	
	# Set up splash damage if this tower has splash type
	if tower_data.type == "splash" or tower_data.type == "special":
		projectile.is_splash_projectile = true
		projectile.splash_radius = tower_data.splash_radius[level - 1]
		print("[tower] Setting up splash projectile with radius: ", projectile.splash_radius)
	
	get_tree().current_scene.add_child(projectile)
	
	# Handle launching based on projectile speed
	if projectile_speed == 0:
		# Instant impact - trigger impact immediately without movement
		if projectile.has_method("instant_impact"):
			projectile.instant_impact()
		elif projectile.has_method("launch"):
			# Fallback: launch but it should immediately impact
			projectile.launch(enemy)
	else:
		# Normal projectile movement
		if projectile.has_method("launch"):
			projectile.launch(enemy)

# --- Upgrade and sprite logic ---
func upgrade():
	if level < 3:
		level += 1
		apply_level_stats()
		# Hide attack range if visible
		hide_attack_range()
		# Hide current tower visuals
		if has_node("towerBase"):
			$towerBase.visible = false
		if has_node("towerWeapon"):
			$towerWeapon.visible = false
		# Close tower menu and clear reference if open for this tower
		var main = get_tree().current_scene
		if main.tower_menu_open_for == self:
			main.hide_tower_menu_with_bg()
			main.tower_menu_open_for = null
		# Always add build animation to $TowerContainer for visibility
		var build_scene = preload("res://scenes/towers/towerConstruction/towerBuild.tscn")
		var build_instance = build_scene.instantiate()
		build_instance.mode = "build"
		build_instance.position = global_position
		build_instance.z_index = int(build_instance.position.y)
		print("[tower.gd] upgrade: tower_data =", tower_data, "scene_path =", tower_data.scene_path)
		build_instance.tower_scene = load(tower_data.scene_path) # Use the same scene path for upgraded tower
		print("[tower.gd] Setting tower_scene to:", tower_data.scene_path)
		build_instance.tower_position = global_position
		# Find the persistent TowerContainer node
		var tower_container = null
		if main.has_node("TowerContainer"):
			tower_container = main.get_node("TowerContainer")
		else:
			tower_container = get_parent() # fallback
		build_instance.tower_parent = tower_container
		build_instance.build_time = tower_data.build_time[level - 1] if tower_data.build_time.size() >= level else 3.0
		build_instance.set_meta("upgrade_level", level)
		build_instance.set_meta("upgrade_tower_data", tower_data)
		tower_container.add_child(build_instance)
		queue_free()


func update_base_sprite():
	if has_node("towerBase"):
		var sprite = $towerBase
		# Remove any duplicate base sprites (keep only the first one found)
		var found = false
		for child in get_children():
			if child.name == "towerBase":
				if not found and child == sprite:
					found = true
				elif child != sprite:
					child.queue_free()
		sprite.region_enabled = true
		sprite.region_rect = level_regions[level - 1]
		var region_height = float(sprite.region_rect.size.y)
		var cell_height = 64.0
		var y_offset = -(region_height / 2.0) + (cell_height / 2.0)
		sprite.offset.y = y_offset
		# Apply the same offset to Area2D so collision matches sprite
		if sprite.has_node("Area2D"):
			sprite.get_node("Area2D").position.y = y_offset


func update_weapon_position():
	if has_node("towerBase") and has_node("towerWeapon"):
		var base_sprite = $towerBase
		var weapon_sprite = $towerWeapon
		var top_y = base_sprite.position.y - base_sprite.region_rect.size.y / 2 if base_sprite.region_enabled else base_sprite.position.y - base_sprite.texture.get_height() / 2
		weapon_sprite.position.y = top_y + weapon_offset_from_top
		weapon_sprite.position.x = base_sprite.position.x


# Rotates the weapon to point at the given target position (in global coordinates)
func point_weapon_at(target_position: Vector2) -> void:
	if has_node("towerWeapon"):
		var weapon_sprite = $towerWeapon
		var weapon_global_pos = weapon_sprite.get_global_position()
		var angle = weapon_global_pos.angle_to_point(target_position)
		var target_rotation = angle + PI / 2
		
		# Stop any existing rotation tween
		if target_rotation_tween:
			target_rotation_tween.kill()
		
		# Calculate the shortest rotation path
		var current_rotation = weapon_sprite.rotation
		var rotation_difference = target_rotation - current_rotation
		
		# Normalize rotation difference to [-PI, PI] for shortest path
		while rotation_difference > PI:
			rotation_difference -= 2 * PI
		while rotation_difference < -PI:
			rotation_difference += 2 * PI
		
		var final_rotation = current_rotation + rotation_difference
		
		# Only animate if there's a significant rotation needed
		if abs(rotation_difference) > 0.05:  # About 3 degrees
			target_rotation_tween = create_tween()
			target_rotation_tween.tween_property(weapon_sprite, "rotation", final_rotation, 0.2)  # 200ms rotation
			print("[tower] Smoothly rotating weapon from ", rad_to_deg(current_rotation), "° to ", rad_to_deg(final_rotation), "°")
		else:
			# Small rotation, just snap to it
			weapon_sprite.rotation = final_rotation


func update_weapon_animation():
	if has_node("towerWeapon"):
		var weapon_node = $towerWeapon
		
		if weapon_node is AnimatedSprite2D and weapon_node.sprite_frames:
			var available_animations = weapon_node.sprite_frames.get_animation_names()
			print("[tower] Available weapon animations: ", available_animations)
			
			# First, try to find the idle animation for current level
			var idle_anim_name = "idleL" + str(level)
			
			if weapon_node.sprite_frames.has_animation(idle_anim_name):
				# Play idle animation if it exists
				weapon_node.play(idle_anim_name)
				print("[tower] Playing idle animation: ", idle_anim_name, " for level ", level)
			else:
				# No idle animation - use first frame of firing animation
				var firing_anim_name = "firingL" + str(level)
				if weapon_node.sprite_frames.has_animation(firing_anim_name):
					weapon_node.play(firing_anim_name)
					weapon_node.pause()  # Pause on first frame
					weapon_node.frame = 0  # Ensure we're on frame 0
					print("[tower] No idle animation found, using first frame of firing animation: ", firing_anim_name, " for level ", level)
				else:
					print("[tower] ERROR: Neither idle nor firing animation found for level ", level)
		
		# Ensure both animation signals are connected after weapon updates
		if weapon_node is AnimatedSprite2D:
			if not weapon_node.frame_changed.is_connected(_on_weapon_frame_changed):
				weapon_node.frame_changed.connect(_on_weapon_frame_changed)
			if not weapon_node.animation_finished.is_connected(_on_weapon_animation_finished):
				weapon_node.animation_finished.connect(_on_weapon_animation_finished)


func return_to_idle_animation():
	if has_node("towerWeapon"):
		var weapon_node = $towerWeapon
		
		if weapon_node is AnimatedSprite2D and weapon_node.sprite_frames:
			# First, try to find the idle animation for current level
			var idle_anim_name = "idleL" + str(level)
			
			if weapon_node.sprite_frames.has_animation(idle_anim_name):
				# Play idle animation if it exists
				weapon_node.play(idle_anim_name)
				print("[tower] Returning to idle animation: ", idle_anim_name, " for level ", level)
			else:
				# No idle animation - use first frame of firing animation
				var firing_anim_name = "firingL" + str(level)
				if weapon_node.sprite_frames.has_animation(firing_anim_name):
					weapon_node.play(firing_anim_name)
					weapon_node.pause()  # Pause on first frame
					weapon_node.frame = 0  # Ensure we're on frame 0
					print("[tower] No idle animation, returning to first frame of firing animation: ", firing_anim_name, " for level ", level)


# Attack range visualization methods
func show_attack_range():
	if range_indicator:
		hide_attack_range()
	
	range_indicator = Node2D.new()
	range_indicator.name = "RangeIndicator"
	range_indicator.z_index = -1  # Draw behind the tower
	add_child(range_indicator)
	is_range_visible = true
	queue_redraw()


func hide_attack_range():
	if range_indicator and is_instance_valid(range_indicator):
		range_indicator.queue_free()
		range_indicator = null
	is_range_visible = false
	queue_redraw()


func _draw():
	if is_range_visible and attack_range > 0:
		# Draw attack range circle
		var circle_color = Color(1.0, 1.0, 1.0, 0.3)  # Semi-transparent white
		var border_color = Color(1.0, 1.0, 1.0, 0.8)  # More opaque white border
		
		# Draw filled circle
		draw_circle(Vector2.ZERO, attack_range, circle_color)
		
		# Draw border circle
		draw_arc(Vector2.ZERO, attack_range, 0, TAU, 64, border_color, 2.0)


func apply_level_stats():
	# Set stats for the current level (arrays are 0-indexed, level is 1-indexed)
	damage = tower_data.damage[level - 1]
	attack_range = tower_data.attack_range[level - 1]
	attack_speed = tower_data.attack_speed[level - 1]


func _input_event(viewport, event, shape_idx):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var main = get_tree().current_scene
		var menu_visible = main.get_node("TowerMenu").visible
		if main.tower_menu_open_for != self or not menu_visible:
			main.show_tower_menu(self)


func _on_area_2d_input_event(viewport: Node, event: InputEvent, shape_idx: int) -> void:
	if just_placed:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var main = get_tree().current_scene
		var menu_visible = main.get_node("TowerMenu").visible
		if main.tower_menu_open_for != self or not menu_visible:
			main.show_tower_menu(self)

func destroy():
	if is_being_destroyed:
		return
	is_being_destroyed = true
	# Hide attack range if visible
	hide_attack_range()
	# Hide base and weapon
	if has_node("towerBase"):
		$towerBase.visible = false
	if has_node("towerWeapon"):
		$towerWeapon.visible = false
	# Instance destruction scene at this position
	var destruction_scene = preload("res://scenes/towers/towerConstruction/towerBuild.tscn")
	var destruction_instance = destruction_scene.instantiate()
	destruction_instance.mode = "destroy" # <--- Set destruction mode!
	destruction_instance.position = global_position
	if get_parent():
		get_parent().add_child(destruction_instance)
	queue_free()


func _on_destruction_animation_finished():
	queue_free()
