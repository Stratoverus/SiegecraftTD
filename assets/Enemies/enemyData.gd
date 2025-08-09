# EnemyData.gd
extends Resource
class_name EnemyData

@export var scene_path: String
@export var enemy_name: String
@export var enemy_type: String  # e.g., "ground", "flying", "boss"

# Basic stats
@export var max_health: int = 100
@export var speed: float = 100.0
@export var gold_worth: int = 5

# Visual settings
@export var health_bar_width: int = 32
@export var health_bar_height: int = 4
@export var health_bar_offset: Vector2 = Vector2(0, -32)

# Animation settings
@export var has_directional_animations: bool = true  # Whether enemy has separate animations for different directions
@export var walk_animation_name: String = "walk"
@export var walk_down_animation_name: String = "walkDown"
@export var idle_animation_name: String = "idle"
@export var idle_down_animation_name: String = "idleDown"
@export var die_animation_name: String = "die"
@export var die_down_animation_name: String = "dieDown"

# Special abilities (for future expansion)
@export var special_abilities: Array[String] = []
@export var resistances: Array[String] = []  # e.g., ["fire", "ice"]
