# TowerData.gd
extends Resource
class_name TowerData


@export var scene_path: String
@export var icon: Texture
@export var cost: int
@export var type: String
@export var weapon_rotates: bool
@export var weapon_offset_from_top: int

# Per-level stats and visuals (index 0 = level 1, 1 = level 2, 2 = level 3)
@export var damage: Array[int] 
@export var attack_range: Array[float] 
@export var attack_speed: Array[float]
@export var weapon_sprites: Array[Texture]
@export var projectile_animations: Array[Resource]
@export var level_regions: Array[Rect2]
