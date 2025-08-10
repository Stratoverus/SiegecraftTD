extends Node2D
var mode: String = "build" # "build" or "destroy"
# The PackedScene for the tower to build
var tower_scene: PackedScene
# The position to place the tower
var tower_position: Vector2
# The build time in seconds
var build_time: float = 3.0
# The parent node to add the tower to
var tower_parent: Node = null

var progress_bar: ProgressBar = null

# Internal state
var elapsed: float = 0.0
var stage: int = 0
var stages = ["build1", "build1transition", "build2", "build2transition", "build3", "build3transition"]
var frame_tracking_enabled = false
var waiting_for_animation = false  # Track if we're waiting for an animation to finish

func _ready():
	# Always set z_index so lower towers are in front
	z_index = int(position.y)
	if has_node("towerAnimations"):
		var anim = $towerAnimations
		anim.visible = true
		# Ensure animation plays at normal speed for builds, slower for transitions
		anim.speed_scale = 1.0  # Normal speed for all animations initially
		if mode == "destroy":
			anim.play("destruction")
			anim.frame = 0
			# Ensure destruction animation doesn't loop
			if anim.sprite_frames.has_animation("destruction"):
				anim.sprite_frames.set_animation_loop("destruction", false)
			if anim is AnimatedSprite2D:
				anim.connect("animation_finished", Callable(self, "_on_animation_finished"))
			set_process(false)
		else:
			anim.play(stages[0])
			anim.frame = 0
			if anim is AnimatedSprite2D:
				anim.connect("animation_finished", Callable(self, "_on_animation_finished"))
			set_process(true)
	
	# Only create progress bar for building mode, not destruction
	if mode == "build":
		var bar_scene = preload("res://scenes/towers/towerConstruction/BuildProgressBar.tscn")
		var bar_instance = bar_scene.instantiate()
		bar_instance.position = Vector2(0, -96) # Adjust as needed
		add_child(bar_instance)
		progress_bar = bar_instance.get_node("ProgressBar")
		progress_bar.max_value = 100.0  # Use percentage instead of time
		progress_bar.value = 0.0
	



func _process(delta):
	if mode == "destroy":
		return
	if build_time <= 0.0:
		build_time = 3.0
	elapsed += delta
	var percent = elapsed / build_time
	
	# Don't advance stages if we're waiting for an animation to finish
	if waiting_for_animation:
		if progress_bar:
			var progress_percent = (elapsed / build_time) * 100.0
			progress_bar.value = clamp(progress_percent, 0.0, 100.0)
		return
	
	# Time-based triggers for major stages only
	if stage == 0 and percent >= 0.33:
		_next_stage() # build1transition (will set waiting_for_animation = true)
	elif stage == 2 and percent >= 0.66:
		_next_stage() # build2transition (will set waiting_for_animation = true)
	elif stage == 4 and percent >= 1.0:
		_next_stage() # build3transition (will set waiting_for_animation = true)
		
	if progress_bar:
		# Calculate percentage and update smoothly
		var progress_percent = (elapsed / build_time) * 100.0
		progress_bar.value = clamp(progress_percent, 0.0, 100.0)
		if elapsed >= build_time:
			progress_bar.queue_free()
			progress_bar = null

func _next_stage():
	stage += 1
	if stage < stages.size():
		if has_node("towerAnimations"):
			var anim = $towerAnimations
			var current_animation = stages[stage]
			anim.visible = true
			
			# Different speed for transition vs regular animations
			if current_animation.ends_with("transition"):
				# Normal speed for transition animations since they won't be interrupted
				anim.speed_scale = 1.0  
			else:
				# Normal speed for build animations
				anim.speed_scale = 1.0
			
			anim.play(current_animation)
			anim.frame = 0
			
			# For transition animations, let's also check frame count and enable tracking
			if current_animation.ends_with("transition"):
				frame_tracking_enabled = true  # Enable frame tracking for transitions
				waiting_for_animation = true   # Wait for this animation to finish
			else:
				frame_tracking_enabled = false  # Disable for regular builds
				waiting_for_animation = false  # Don't wait for build animations
		# When build3transition starts, reveal the tower
		if stages[stage] == "build3transition" and tower_scene and tower_parent:
			var tower = tower_scene.instantiate()
			tower.position = tower_position
			tower.z_index = int(tower.position.y)
			# Pass upgrade_level if set
			if has_meta("upgrade_level"):
				tower.level = get_meta("upgrade_level")
			# Pass upgrade_tower_data if set
			if has_meta("upgrade_tower_data"):
				tower.tower_data = get_meta("upgrade_tower_data")
			# Pass initial_tower_data if set (for initial placement)
			if has_meta("initial_tower_data"):
				tower.tower_data = get_meta("initial_tower_data")
			tower_parent.add_child(tower)


func _on_animation_finished():
	var finished_animation = $towerAnimations.animation if has_node("towerAnimations") else "unknown"
	frame_tracking_enabled = false  # Stop tracking when animation finishes
	
	# Handle destruction animation
	if mode == "destroy" and finished_animation == "destruction":
		queue_free()  # Clean up the destruction animation node
		return
	
	# If a transition animation finished, advance to the next stage
	if finished_animation.ends_with("transition"):
		waiting_for_animation = false  # No longer waiting
		if finished_animation == "build3transition":
			# Final animation, clean up
			queue_free()
		else:
			# Advance to the next build stage
			_next_stage()  # Advance to the next build stage
	# For regular build animations, we don't auto-advance (time-based triggers handle it)
