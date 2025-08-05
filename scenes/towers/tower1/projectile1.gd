extends Node2D

@export var damage: int = 1
var target = null
var speed: float = 800.0

func launch(enemy):
	target = enemy
	if has_node("projectileAnim"):
		$projectileAnim.play("default")

func _process(delta):
	if not is_instance_valid(target):
		queue_free()
		return
	var to_target = target.global_position - global_position
	var distance = to_target.length()
	if distance < speed * delta:
		target.take_damage(damage)
		queue_free()
		return
	var direction = to_target.normalized()
	global_position += direction * speed * delta
	rotation = direction.angle() + PI / 2
