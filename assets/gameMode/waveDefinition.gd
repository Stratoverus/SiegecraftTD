class_name WaveDefinition
extends Resource

@export var wave_number: int = 1
@export var is_boss_wave: bool = false
@export var preparation_time: float = 10.0  # Time before wave starts
@export var spawn_interval: float = 1.0  # Time between individual enemy spawns

# Simple enemy spawn definitions - just specify enemy type and count
@export var enemy_groups: Array[EnemyGroup] = []
