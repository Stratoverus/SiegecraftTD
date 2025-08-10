# TowerTooltip.gd
extends Panel
class_name TowerTooltip

@onready var tower_name_label = $VBoxContainer/TowerName
@onready var tower_type_label = $VBoxContainer/TowerType
@onready var cost_label = $VBoxContainer/Cost
@onready var damage_label = $VBoxContainer/StatsContainer/Damage
@onready var attack_speed_label = $VBoxContainer/StatsContainer/AttackSpeed
@onready var range_label = $VBoxContainer/StatsContainer/Range
@onready var build_time_label = $VBoxContainer/StatsContainer/BuildTime
@onready var description_label = $VBoxContainer/Description

# Tower descriptions for different tower types
var tower_descriptions = {
	"tower1": "A basic archer tower that fires arrows at enemies. Good starting defense with decent range.",
	"tower2": "A cannon tower that deals high damage but fires slowly. Effective against armored enemies.",
	"tower3": "A magic tower that shoots energy bolts. Bypasses some enemy defenses.",
	"tower4": "An explosive tower that deals area damage. Great for groups of enemies.",
	"tower5": "A rapid-fire tower with high attack speed but lower damage per shot.",
	"tower6": "A frost tower that slows enemies while dealing damage.",
	"tower7": "A lightning tower that can chain attacks between nearby enemies.",
	"tower8": "An ultimate tower with powerful attacks and special abilities."
}

func setup_tooltip(tower_data: TowerData, level: int = 1, is_upgrade: bool = false):
	"""Setup the tooltip with tower information"""
	if not tower_data:
		return
	
	# Clamp level to valid range
	level = clamp(level, 1, 3)
	var array_index = level - 1
	
	# Use tower name from data, fallback to path-based name if not set
	var tower_name = tower_data.name if tower_data.name != "" else get_tower_name_from_path(tower_data.scene_path)
	tower_name_label.text = tower_name + " (Level " + str(level) + ")"
	
	# Set tower type
	tower_type_label.text = "Type: " + tower_data.type.capitalize()
	
	# Set cost
	if is_upgrade:
		cost_label.text = "Upgrade Cost: " + str(tower_data.cost[array_index]) + " Gold"
	else:
		cost_label.text = "Build Cost: " + str(tower_data.cost[array_index]) + " Gold"
	
	# Set stats
	damage_label.text = "Damage: " + str(tower_data.damage[array_index])
	attack_speed_label.text = "Attack Speed: " + str(tower_data.attack_speed[array_index])
	range_label.text = "Range: " + str(int(tower_data.attack_range[array_index]))
	
	# Set build time
	if tower_data.build_time.size() > array_index:
		build_time_label.text = "Build Time: " + str(tower_data.build_time[array_index]) + "s"
	else:
		build_time_label.text = "Build Time: 2.0s"  # Default fallback
	
	# Set description from tower data, fallback to dictionary if not set
	var description_text = ""
	if tower_data.description != "":
		description_text = tower_data.description
	else:
		# Fallback to dictionary for towers that don't have description set yet
		var tower_key = get_tower_key_from_path(tower_data.scene_path)
		if tower_descriptions.has(tower_key):
			description_text = tower_descriptions[tower_key]
		else:
			description_text = "A powerful tower."
	
	description_label.text = description_text
	
	# Add upgrade improvements if this is an upgrade
	if is_upgrade and level > 1:
		var prev_level = level - 1
		var prev_index = prev_level - 1
		var improvements = []
		
		if tower_data.damage[array_index] > tower_data.damage[prev_index]:
			improvements.append("[color=green]+" + str(tower_data.damage[array_index] - tower_data.damage[prev_index]) + " Damage[/color]")
		
		if tower_data.attack_speed[array_index] > tower_data.attack_speed[prev_index]:
			var speed_diff = tower_data.attack_speed[array_index] - tower_data.attack_speed[prev_index]
			improvements.append("[color=cyan]+" + str(speed_diff) + " Attack Speed[/color]")
		
		if tower_data.attack_range[array_index] > tower_data.attack_range[prev_index]:
			var range_diff = tower_data.attack_range[array_index] - tower_data.attack_range[prev_index]
			improvements.append("[color=blue]+" + str(int(range_diff)) + " Range[/color]")
		
		if improvements.size() > 0:
			description_label.text += "\n\n[b]Improvements:[/b]\n" + "\n".join(improvements)
	
	# Calculate dynamic size after content is set
	calculate_dynamic_size()

func calculate_dynamic_size():
	"""Calculate the optimal size for the tooltip based on content"""
	# Force multiple layout updates to get accurate text sizes
	await get_tree().process_frame
	
	# Get the container that holds all content
	var container = $VBoxContainer
	
	# Force the container to update its layout
	container.force_update_transform()
	await get_tree().process_frame
	
	# Calculate required width based on content
	var max_width = 220.0  # Reasonable minimum width
	
	# Simple estimation based on text content
	for child in container.get_children():
		if child is Label:
			var label = child as Label
			if label.text.length() > 0:
				# Simple character-based width estimation
				var estimated_width = label.text.length() * 8 + 40  # 8 pixels per character + padding
				max_width = max(max_width, estimated_width)
		elif child is RichTextLabel:
			var rich_label = child as RichTextLabel
			# Estimate based on text length (remove BBCode tags manually)
			var text_content = rich_label.text
			# Simple BBCode tag removal
			text_content = text_content.replace("[b]", "").replace("[/b]", "")
			text_content = text_content.replace("[color=green]", "").replace("[color=cyan]", "").replace("[color=blue]", "").replace("[/color]", "")
			var estimated_width = min(350.0, max(250.0, text_content.length() * 6))
			max_width = max(max_width, estimated_width)
	
	# Force container update
	container.force_update_transform()
	await get_tree().process_frame
	
	# Get the total height needed - use a reasonable estimate
	var estimated_height = 120 + (container.get_child_count() * 20)  # Base height + per-item height
	
	# Set the new size with padding
	var new_size = Vector2(
		clamp(max_width, 250, 400),  # Reasonable width bounds
		clamp(estimated_height, 120, 300)  # Reasonable height bounds
	)
	
	# Set both custom_minimum_size and size
	custom_minimum_size = new_size
	size = new_size

func get_tower_name_from_path(path: String) -> String:
	"""Extract tower name from scene path"""
	if "tower1" in path:
		return "Archer Tower"
	elif "tower2" in path:
		return "Cannon Tower"
	elif "tower3" in path:
		return "Magic Tower"
	elif "tower4" in path:
		return "Explosive Tower"
	elif "tower5" in path:
		return "Rapid Tower"
	elif "tower6" in path:
		return "Frost Tower"
	elif "tower7" in path:
		return "Lightning Tower"
	elif "tower8" in path:
		return "Ultimate Tower"
	else:
		return "Tower"

func get_tower_key_from_path(path: String) -> String:
	"""Extract tower key for descriptions"""
	if "tower1" in path:
		return "tower1"
	elif "tower2" in path:
		return "tower2"
	elif "tower3" in path:
		return "tower3"
	elif "tower4" in path:
		return "tower4"
	elif "tower5" in path:
		return "tower5"
	elif "tower6" in path:
		return "tower6"
	elif "tower7" in path:
		return "tower7"
	elif "tower8" in path:
		return "tower8"
	else:
		return "unknown"

func show_at_position(pos: Vector2):
	"""Show tooltip at specified position, adjusting for screen boundaries"""
	var viewport_size = get_viewport().get_visible_rect().size
	
	# Get the actual tooltip size (now dynamic)
	var tooltip_size = size if size.x > 0 else custom_minimum_size
	
	# Start with the requested position
	var adjusted_pos = pos
	
	# Check horizontal boundaries and adjust
	if adjusted_pos.x + tooltip_size.x > viewport_size.x:
		# Would overflow to the right, position to the left instead
		adjusted_pos.x = pos.x - tooltip_size.x - 10
		# Make sure it doesn't go off the left edge
		if adjusted_pos.x < 0:
			adjusted_pos.x = 10
	
	# Check vertical boundaries and adjust
	if adjusted_pos.y + tooltip_size.y > viewport_size.y:
		# Would overflow to the bottom, move it up
		adjusted_pos.y = viewport_size.y - tooltip_size.y - 10
		# Make sure it doesn't go off the top edge
		if adjusted_pos.y < 0:
			adjusted_pos.y = 10
	
	# Make sure tooltip stays within screen bounds
	adjusted_pos.x = clamp(adjusted_pos.x, 10, viewport_size.x - tooltip_size.x - 10)
	adjusted_pos.y = clamp(adjusted_pos.y, 10, viewport_size.y - tooltip_size.y - 10)
	
	# Set final position and show
	position = adjusted_pos
	modulate = Color.WHITE  # Ensure full opacity
	visible = true

func hide_tooltip():
	"""Hide the tooltip"""
	visible = false
