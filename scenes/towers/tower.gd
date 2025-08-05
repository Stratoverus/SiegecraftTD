extends Node2D

# Tower stats and attack logic
@export var tower_data: Resource  # Assign your TowerData resource in the editor
var attack_range: float
var attack_speed: float
var damage: int
var attack_cooldown := 0.0
var target = null

# Upgrade and sprite logic
@export var level: int = 1
@export var level_regions: Array[Rect2] = []
@export var weapon_offset_from_top: int = 20

func _ready():
	attack_range = tower_data.attaci_range
	attack_speed = tower_data.attack_speed
	damage = tower_data.damage
	update_base_sprite()
	update_weapon_position()

func _process(delta):
	attack_cooldown -= delta
	if not is_valid_target(target):
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

func find_target():
	var enemies = get_tree().get_nodes_in_group("enemies")
	var best = null
	var best_dist = INF
	for enemy in enemies:
		if enemy.health > 0:
			var dist = position.distance_to(enemy.position)
			if dist <= attack_range and dist < best_dist:
				best = enemy
				best_dist = dist
	return best


func attack_target(enemy):
	# Play firing animation and scale speed with attack speed
	if has_node("towerWeapon") and $towerWeapon is AnimatedSprite2D:
		$towerWeapon.speed_scale = attack_speed
		$towerWeapon.play("firing")

	# Instance and launch projectile
	var projectile_scene = preload("res://scenes/towers/tower1/projectile1.tscn")
	var projectile = projectile_scene.instantiate()
	projectile.global_position = $towerWeapon.get_global_position() if has_node("towerWeapon") else global_position
	projectile.damage = damage
	projectile.target = enemy
	projectile.z_index = 1000
	get_tree().current_scene.add_child(projectile)
	if projectile.has_method("launch"):
		projectile.launch(enemy)

# --- Upgrade and sprite logic ---
func upgrade():
	if level < level_regions.size():
		level += 1
		update_base_sprite()

func update_base_sprite():
	if has_node("towerBase"):
		var sprite = $towerBase
		sprite.region_enabled = true
		sprite.region_rect = level_regions[level - 1]
		var region_height = sprite.region_rect.size.y
		var cell_height = 64
		sprite.offset.y = -(region_height / 2) + (cell_height / 2)

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
