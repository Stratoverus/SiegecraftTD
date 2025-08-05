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
	var can_place = false
	var main = get_tree().current_scene
	if main:
		if main.has_method("can_place_tower_at"):
			can_place = main.can_place_tower_at(global_position)
	var color = Color(0,1,0,0.3) if can_place else Color(1,0,0,0.3)
	draw_circle(Vector2.ZERO, range, color)
