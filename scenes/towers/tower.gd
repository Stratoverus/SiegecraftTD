
extends Node2D

# Tower stats and attack logic
@export var tower_data: Resource  # Assign your TowerData resource in the editor

var attack_range: float
var attack_speed: float
var damage: int
var attack_cooldown := 0.0
var target = null
var just_placed = true

# Store the last target's position for smarter retargeting
var last_target_position = null

# Upgrade and sprite logic
@export var level: int = 1
@export var level_regions: Array[Rect2] = []
@export var weapon_offset_from_top: int = 20

func _ready():
	apply_level_stats()
	update_base_sprite()
	update_weapon_animation()
	update_weapon_position()
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

	# Rotate weapon if needed
	if target and tower_data.weapon_rotates:
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
	# Play firing animation and scale speed with attack speed
	if has_node("towerWeapon") and $towerWeapon is AnimatedSprite2D:
		$towerWeapon.speed_scale = attack_speed
		$towerWeapon.play("firingL" + str(level))

	# Instance and launch projectile
	var projectile_scene = load(tower_data.projectile_scene)
	var projectile = projectile_scene.instantiate()
	projectile.global_position = $towerWeapon.get_global_position() if has_node("towerWeapon") else global_position
	projectile.damage = damage
	projectile.speed = tower_data.projectile_speed[level - 1]
	projectile.target = enemy
	projectile.level = level # Ensure projectile anim matches tower level
	projectile.z_index = 1000
	get_tree().current_scene.add_child(projectile)
	if projectile.has_method("launch"):
		projectile.launch(enemy)

# --- Upgrade and sprite logic ---
func upgrade():
	if level < 3:
		level += 1
		apply_level_stats()
		update_base_sprite()
		update_weapon_position()
		# Always update weapon animation to correct idle/ready frame for new level
		if has_node("towerWeapon"):
			var weapon_node = $towerWeapon
			var anim_name = "firingL" + str(level)
			if weapon_node.has_method("play"):
				weapon_node.play(anim_name)
				weapon_node.stop() # Show first frame of new animation, not playing
			elif weapon_node.has_method("set_frame"):
				weapon_node.set_frame(level - 1)


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
		weapon_sprite.rotation = angle + PI / 2


func update_weapon_animation():
	if has_node("towerWeapon"):
		var anim_name = "level%d" % level
		var weapon_node = $towerWeapon
		if weapon_node.has_method("level" + str(level)):
			weapon_node.play(anim_name)


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
