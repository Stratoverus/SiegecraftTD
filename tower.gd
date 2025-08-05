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
@export var weapon_offset_from_top: int = 20

func _ready():
	apply_level_stats()
	update_base_sprite()
	update_weapon_sprite()
	update_weapon_position()

func _process(delta):
	attack_cooldown -= delta
	if not is_valid_target(target):
		target = find_target()
		if target:
			print("[Tower] New target acquired:", target)
	if target and attack_cooldown <= 0.0:
		print("[Tower] Attacking target:", target, "for", damage, "damage")
		attack_target(target)
		attack_cooldown = 1.0 / attack_speed

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
	print("[Tower] Calling take_damage on:", enemy)
	enemy.take_damage(damage)

# --- Upgrade and sprite logic ---
func upgrade():
	if level < 3:
		level += 1
		apply_level_stats()
		update_base_sprite()
		update_weapon_sprite()
		update_weapon_position()
		# Optionally update projectile animation here if needed

func update_base_sprite():
	if has_node("towerBase"):
		var sprite = $towerBase
		if tower_data.level_regions.size() >= level:
			sprite.region_enabled = true
			sprite.region_rect = tower_data.level_regions[level - 1]
			var region_height = sprite.region_rect.size.y
			var cell_height = 64
			sprite.offset.y = -(region_height / 2) + (cell_height / 2)
func update_weapon_sprite():
	if has_node("towerWeapon") and tower_data.weapon_sprites.size() >= level:
		$"towerWeapon".texture = tower_data.weapon_sprites[level - 1]

func update_projectile_animation():
	# Implement this if your projectile node/scene supports animation changes
	# Example: $"Projectile".animation = tower_data.projectile_animations[level - 1]
	pass

func apply_level_stats():
	# Set stats for the current level (arrays are 0-indexed, level is 1-indexed)
	damage = tower_data.damage[level - 1]
	attack_range = tower_data.attack_range[level - 1]
	attack_speed = tower_data.attack_speed[level - 1]

func update_weapon_position():
	if has_node("towerBase") and has_node("towerWeapon"):
		var base_sprite = $towerBase
		var weapon_sprite = $towerWeapon
		var top_y = base_sprite.position.y - base_sprite.region_rect.size.y / 2 if base_sprite.region_enabled else base_sprite.position.y - base_sprite.texture.get_height() / 2
		weapon_sprite.position.y = top_y + weapon_offset_from_top
		weapon_sprite.position.x = base_sprite.position.x
