extends Node2D

var money : int = 100
var health : int = 20

func _ready():
	load_map("res://scenes/map.tscn")

func load_level(level_path):
	# Remove any existing level
	for child in $LevelContainer.get_children():
		child.queue_free()
	# Load and add the new level
	var level = load(level_path).instantiate()
	$LevelContainer.add_child(level)

func can_afford(cost: int) -> bool:
	return money >= cost

func spend_money(amount: int):
	money -= amount
	update_ui()

func earn_money(amount: int):
	money += amount
	update_ui()

func take_damage(amount: int):
	health -= amount
	update_ui()
	if health <= 0:
		game_over()

func update_ui():
	# Update your UI elements here (e.g., money/health labels)
	pass

func game_over():
	# Handle game over logic here
	pass

func add_tower(tower_scene_path: String, position: Vector2, cost: int):
	if can_afford(cost):
		var tower = load(tower_scene_path).instantiate()
		tower.position = position
		$TowerContainer.add_child(tower)
		spend_money(cost)

func load_map(map_path):
	# Remove any existing map
	for child in $LevelContainer.get_children():
		child.queue_free()
	# Load and add the map
	var map = load(map_path).instantiate()
	$LevelContainer.add_child(map)
