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
	print("[tower_build] _ready called, mode:", mode, " position:", position)
	if has_node("towerAnimations"):
		var anim = $towerAnimations
		print("[tower_build] towerAnimations node found, visible:", anim.visible)
		print("[tower_build] Current speed_scale:", anim.speed_scale)
		anim.visible = true
		# Ensure animation plays at normal speed for builds, slower for transitions
		anim.speed_scale = 1.0  # Normal speed for all animations initially
		if mode == "destroy":
			print("[tower_build] Playing destruction animation")
			anim.play("destruction")
			anim.frame = 0
			if anim is AnimatedSprite2D:
				anim.connect("animation_finished", Callable(self, "_on_animation_finished"))
			set_process(false)
		else:
			print("[tower_build] Playing build animation:", stages[0])
			anim.play(stages[0])
			anim.frame = 0
			if anim is AnimatedSprite2D:
				anim.connect("animation_finished", Callable(self, "_on_animation_finished"))
				# Connect frame change for debugging transitions
				if not anim.frame_changed.is_connected(_on_frame_changed):
					anim.frame_changed.connect(_on_frame_changed)
			set_process(true)
	else:
		print("[tower_build] towerAnimations node NOT found!")
	
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
	print("[tower_build] _next_stage called, stage:", stage, " animation:", stages[stage] if stage < stages.size() else "none")
	if stage < stages.size():
		if has_node("towerAnimations"):
			var anim = $towerAnimations
			var current_animation = stages[stage]
			print("[tower_build] Playing animation:", current_animation)
			print("[tower_build] Animation speed_scale before:", anim.speed_scale)
			print("[tower_build] Animation frame before:", anim.frame)
			print("[tower_build] Is animation playing before:", anim.is_playing())
			anim.visible = true
			
			# Different speed for transition vs regular animations
			if current_animation.ends_with("transition"):
				# Normal speed for transition animations since they won't be interrupted
				anim.speed_scale = 1.0  
				print("[tower_build] Setting TRANSITION animation speed to 1.0")
			else:
				# Normal speed for build animations
				anim.speed_scale = 1.0
				print("[tower_build] Setting BUILD animation speed to 1.0")
			
			anim.play(current_animation)
			anim.frame = 0
			print("[tower_build] Animation speed_scale after:", anim.speed_scale)
			print("[tower_build] Animation frame after:", anim.frame)
			print("[tower_build] Is animation playing after:", anim.is_playing())
			
			# For transition animations, let's also check frame count and enable tracking
			if current_animation.ends_with("transition"):
				var frame_count = anim.sprite_frames.get_frame_count(current_animation)
				print("[tower_build] Transition animation '", current_animation, "' has ", frame_count, " frames")
				frame_tracking_enabled = true  # Enable frame tracking for transitions
				waiting_for_animation = true   # Wait for this animation to finish
			else:
				frame_tracking_enabled = false  # Disable for regular builds
				waiting_for_animation = false  # Don't wait for build animations
		else:
			print("[tower_build] towerAnimations node NOT found in _next_stage!")
		# When build3transition starts, reveal the tower
		if stages[stage] == "build3transition" and tower_scene and tower_parent:
			print("[tower_build] Instantiating upgraded tower at position:", tower_position)
			if tower_scene.has_method("resource_path"):
				print("[tower_build] tower_scene resource path:", tower_scene.resource_path)
			else:
				print("[tower_build] tower_scene does not have resource_path property.")
			var tower = tower_scene.instantiate()
			tower.position = tower_position
			tower.z_index = int(tower.position.y)
			# Pass upgrade_level if set
			if has_meta("upgrade_level"):
				tower.level = get_meta("upgrade_level")
				print("[tower_build] Passing upgrade_level:", tower.level)
			# Pass upgrade_tower_data if set
			if has_meta("upgrade_tower_data"):
				tower.tower_data = get_meta("upgrade_tower_data")
				print("[tower_build] Passing upgrade_tower_data")
			# Pass initial_tower_data if set (for initial placement)
			if has_meta("initial_tower_data"):
				tower.tower_data = get_meta("initial_tower_data")
				print("[tower_build] Passing initial_tower_data")
			tower_parent.add_child(tower)
			# Debug: print when the new tower is ready
			if tower.has_method("connect"):
				tower.connect("ready", Callable(self, "_on_new_tower_ready"))

func _on_new_tower_ready():
	print("[tower_build] New tower _ready called.")

func _on_frame_changed():
	if frame_tracking_enabled and has_node("towerAnimations"):
		var anim = $towerAnimations
		var current_animation = anim.animation
		var current_frame = anim.frame
		var frame_count = anim.sprite_frames.get_frame_count(current_animation)
		print("[tower_build] Frame changed - Animation: ", current_animation, " Frame: ", current_frame, "/", frame_count)

func _on_animation_finished():
	var finished_animation = $towerAnimations.animation if has_node("towerAnimations") else "unknown"
	print("[tower_build] Animation finished:", finished_animation)
	frame_tracking_enabled = false  # Stop tracking when animation finishes
	
	# If a transition animation finished, advance to the next stage
	if finished_animation.ends_with("transition"):
		waiting_for_animation = false  # No longer waiting
		if finished_animation == "build3transition":
			# Final animation, clean up
			print("[tower_build] Final transition finished, cleaning up")
			queue_free()
		else:
			# Advance to the next build stage
			print("[tower_build] Transition finished, advancing to next stage")
			_next_stage()  # Advance to the next build stage
	# For regular build animations, we don't auto-advance (time-based triggers handle it)
