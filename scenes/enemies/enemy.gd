extends Node2D


# Path and movement
var path: Array = []
var path_index: int = 0
@export var speed: float = 100.0

# Health system
@export var max_health: int = 10
var health: int = max_health

# Health bar settings
var health_bar_width := 32
var health_bar_height := 4
var health_bar_offset := Vector2(0, -32)

func _ready():
	play_walk_animation()
	set_process(true)

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
		queue_redraw() # Redraw health bar


# Call this to deal damage to the enemy
func take_damage(amount: int):
	health = max(health - amount, 0)
	if health == 0:
		die()
	queue_redraw()

func die():
	queue_free()

# Draw the health bar above the enemy
func _draw():
	if health < max_health:
		var bar_pos = health_bar_offset
		var green_width = int(health_bar_width * (float(health) / float(max_health)))
		var red_width = health_bar_width - green_width
		# Draw green part
		if green_width > 0:
			draw_rect(Rect2(bar_pos, Vector2(green_width, health_bar_height)), Color(0,1,0))
		# Draw red part
		if red_width > 0:
			draw_rect(Rect2(bar_pos + Vector2(green_width,0), Vector2(red_width, health_bar_height)), Color(1,0,0))
