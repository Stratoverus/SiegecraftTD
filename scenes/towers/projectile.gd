extends Node2D

@export var damage: int = 1
@export var speed: float = 200.0
@export var level: int = 1
var target = null


func launch(enemy):
	target = enemy
	if has_node("projectileAnim"):
		$projectileAnim.play("level" + str(level))

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
