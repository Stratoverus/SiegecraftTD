extends Node2D


# Path and movement
var path: Array = []
var path_index: int = 0
@export var speed: float = 100

# Health system
@export var max_health: int = 100
var health: int = max_health

# Health bar settings
var health_bar_width := 32
var health_bar_height := 4
var health_bar_offset := Vector2(0, -32)

var is_dead = false

signal enemy_died(gold)
@export var gold_worth: int = 5

func _ready():
	add_to_group("enemies")
	play_walk_animation()
	set_process(true)

func is_facing_down(direction: Vector2) -> bool:
	return direction.y > 0.5

func play_walk_animation(direction := Vector2.ZERO):
	if direction == Vector2.ZERO and path_index < path.size():
		direction = (path[path_index] - position).normalized()
	if is_facing_down(direction):
		$AnimatedSprite2D.play("walkDown")
	else:
		$AnimatedSprite2D.play("walk")

func _process(delta):
	if is_dead:
		return
	if path_index < path.size():
		var target = path[path_index]
		var direction = (target - position).normalized()
		position += direction * speed * delta
		if is_facing_down(direction):
			$AnimatedSprite2D.rotation = 0
		else:
			$AnimatedSprite2D.rotation = direction.angle() + PI / 2
		if position.distance_to(target) < 2.0:
			path_index += 1
		play_walk_animation(direction)
		queue_redraw() # Redraw health bar


# Helper methods for projectile trajectory prediction
func get_velocity() -> Vector2:
	if is_dead or path_index >= path.size():
		return Vector2.ZERO
	var target = path[path_index]
	var direction = (target - position).normalized()
	return direction * speed


func get_direction() -> Vector2:
	if is_dead or path_index >= path.size():
		return Vector2.ZERO
	var target = path[path_index]
	return (target - position).normalized()


func get_speed() -> float:
	return speed if not is_dead else 0.0


# Call this to deal damage to the enemy
func take_damage(amount: int):
	if is_dead:
		return
	health = max(health - amount, 0)
	if health == 0:
		die()
	queue_redraw()

func die():
	if is_dead:
		return
	is_dead = true
	emit_signal("enemy_died", gold_worth)
	var last_direction = Vector2.ZERO
	if path_index < path.size():
		last_direction = (path[path_index] - position).normalized()
	if is_facing_down(last_direction):
		$AnimatedSprite2D.play("dieDown")
		$AnimatedSprite2D.rotation = 0
	else:
		$AnimatedSprite2D.play("die")
		$AnimatedSprite2D.rotation = last_direction.angle() + PI / 2
	# Disconnect first to avoid duplicate connections
	if $AnimatedSprite2D.is_connected("animation_finished", Callable(self, "_on_death_animation_finished")):
		$AnimatedSprite2D.disconnect("animation_finished", Callable(self, "_on_death_animation_finished"))
	$AnimatedSprite2D.connect("animation_finished", Callable(self, "_on_death_animation_finished"))

func _on_death_animation_finished():
	# Only fade out if the finished animation is 'die' or 'dieDown'
	if $AnimatedSprite2D.animation == "die" or $AnimatedSprite2D.animation == "dieDown":
		if $AnimatedSprite2D.is_connected("animation_finished", Callable(self, "_on_death_animation_finished")):
			$AnimatedSprite2D.disconnect("animation_finished", Callable(self, "_on_death_animation_finished"))
		var tween = create_tween()
		tween.tween_property(self, "modulate:a", 0.0, 0.5)
		tween.connect("finished", Callable(self, "_on_fade_out_finished"))

func _on_fade_out_finished():
	queue_free()

# Draw the health bar above the enemy
func _draw():
	if is_dead or health == 0:
		return
	if health < max_health:
		var bar_pos = health_bar_offset - Vector2(health_bar_width / 2, 0)
		var green_width = int(health_bar_width * (float(health) / float(max_health)))
		var red_width = health_bar_width - green_width
		# Draw green part
		if green_width > 0:
			draw_rect(Rect2(bar_pos, Vector2(green_width, health_bar_height)), Color(0,1,0))
		# Draw red part
		if red_width > 0:
			draw_rect(Rect2(bar_pos + Vector2(green_width,0), Vector2(red_width, health_bar_height)), Color(1,0,0))
