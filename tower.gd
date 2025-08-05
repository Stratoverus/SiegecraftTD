extends Node2D

# Tower stats and attack logic
@export var tower_data: Resource  # Assign your TowerData resource in the editor
var range: float
var attack_speed: float
var damage: int
var attack_cooldown := 0.0
var target = null

# Upgrade and sprite logic
@export var level: int = 1
@export var level_regions: Array[Rect2] = []
@export var weapon_offset_from_top: int = 20

func _ready():
	range = tower_data.range
	attack_speed = tower_data.attack_speed
	damage = tower_data.damage
	update_base_sprite()
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
	return enemy and enemy.is_inside_tree() and enemy.health > 0 and position.distance_to(enemy.position) <= range

func find_target():
	var enemies = get_tree().get_nodes_in_group("enemies")
	var best = null
	var best_dist = INF
	for enemy in enemies:
		if enemy.health > 0:
			var dist = position.distance_to(enemy.position)
			if dist <= range and dist < best_dist:
				best = enemy
				best_dist = dist
	return best

func attack_target(enemy):
	print("[Tower] Calling take_damage on:", enemy)
	enemy.take_damage(damage)

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
