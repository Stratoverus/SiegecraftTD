extends Node2D

@export var cell_size: Vector2 = Vector2(64, 64)
@export var grid_color: Color = Color(1, 1, 1, 0.2) # semi-transparent white
@export var grid_size: Vector2 = Vector2(1920, 1080) # adjust to your map size
@export var start_cell: Vector2i = Vector2i(0, 0)

func _draw():
	for x in range(0, int(grid_size.x) + 1, int(cell_size.x)):
		draw_line(Vector2(x, 0), Vector2(x, grid_size.y), grid_color)
	for y in range(0, int(grid_size.y) + 1, int(cell_size.y)):
		draw_line(Vector2(0, y), Vector2(grid_size.x, y), grid_color)

func _ready():
	queue_redraw()
