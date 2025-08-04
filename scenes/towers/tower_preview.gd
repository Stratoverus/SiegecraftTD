extends Node2D
var range = 0.0

func set_tower_data(tower_data):
	$Sprite2D.texture = tower_data.icon
	range = tower_data.range
	queue_redraw()
	var sprite = $Sprite2D
	var texture_height = sprite.texture.get_height()
	var cell_height = 64
	sprite.offset.y = -(texture_height / 2) + (cell_height / 2)

func _draw():
	draw_circle(Vector2.ZERO, range, Color(0,1,0,0.3))
