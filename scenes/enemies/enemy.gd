extends Node2D

var path: Array = []
var path_index: int = 0
@export var speed: float = 100.0

func _ready():
	play_walk_animation()

func play_walk_animation():
	$AnimatedSprite2D.play("walk")

func _process(delta):
	if path_index < path.size():
		var target = path[path_index]
		var direction = (target - position).normalized()
		position += direction * speed * delta
		$AnimatedSprite2D.rotation = direction.angle() + PI / 2
		if position.distance_to(target) < 2.0:
			path_index += 1
