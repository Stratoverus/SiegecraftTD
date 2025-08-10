# TowerData.gd
extends Resource
class_name TowerData

@export var name: String
@export var description: String
@export var scene_path: String
@export var type: String
@export var weapon_rotates: bool
@export var weapon_offset_from_top: int
@export var projectile_scene: String
@export var projectile_release_frame: int

# Per-level stats and visuals (index 0 = level 1, 1 = level 2, 2 = level 3)
@export var cost: Array[int]
@export var damage: Array[int] 
@export var attack_range: Array[float] 
@export var attack_speed: Array[float]
@export var projectile_speed: Array[float]
@export var icon: Array[Texture]
@export var build_time: Array[float]
@export var splash_radius: Array[float]
