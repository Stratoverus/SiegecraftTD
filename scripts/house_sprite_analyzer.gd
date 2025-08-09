extends Node

# Automatic house sprite analyzer for precise door measurements
# This script analyzes each house sprite to find the door center and content bounds

class_name HouseSpriteAnalyzer

static func analyze_house_sprites_from_node(house_node: Node) -> Dictionary:
	"""Analyze all house sprite frames from an existing house node"""
	
	var measurements = {}
	
	# Get the sprite frames from the house's AnimatedSprite2D
	var animated_sprite = house_node.get_node("AnimatedSprite2D")
	if not animated_sprite:
		return measurements
	
	var sprite_frames = animated_sprite.sprite_frames
	if not sprite_frames:
		return measurements
	
	# Analyze each skin (skin1 through skin20)
	for skin_index in range(1, 21):
		var skin_name = "skin" + str(skin_index)
		
		if not sprite_frames.has_animation(skin_name):
			continue
		
		# Get the first frame (door closed) for measurement
		var texture = sprite_frames.get_frame_texture(skin_name, 0)
		if not texture:
			continue
		
		# Analyze this sprite
		var analysis = analyze_sprite_texture(texture, skin_name)
		measurements[skin_name] = analysis
	
	return measurements

static func analyze_sprite_texture(texture: Texture2D, _skin_name: String) -> Dictionary:
	"""Analyze a single sprite texture to find door location and content bounds"""
	
	# Get the image data
	var image = texture.get_image()
	var width = image.get_width()
	var height = image.get_height()
	
	# Find content bounds (non-transparent area)
	var content_bounds = find_content_bounds(image)
	
	# Door is simply at the bottom center of the content area
	var door_center_x = content_bounds.position.x + content_bounds.size.x / 2.0
	var door_bottom_y = content_bounds.position.y + content_bounds.size.y  # Bottom of content
	
	return {
		"door_center_x": door_center_x,
		"door_bottom_y": door_bottom_y,
		"content_width": content_bounds.size.x,
		"content_height": content_bounds.size.y,
		"content_left": content_bounds.position.x,
		"content_top": content_bounds.position.y,
		"sprite_width": width,
		"sprite_height": height
	}

static func find_content_bounds(image: Image) -> Rect2:
	"""Find the bounding box of non-transparent pixels"""
	
	var width = image.get_width()
	var height = image.get_height()
	
	# Find bounds of non-transparent content
	var min_x = width
	var max_x = -1
	var min_y = height
	var max_y = -1
	
	for y in range(height):
		for x in range(width):
			var pixel = image.get_pixel(x, y)
			if pixel.a > 0.1:  # Non-transparent pixel
				min_x = min(min_x, x)
				max_x = max(max_x, x)
				min_y = min(min_y, y)
				max_y = max(max_y, y)
	
	if max_x == -1:  # No content found
		return Rect2(0, 0, width, height)
	
	return Rect2(min_x, min_y, max_x - min_x + 1, max_y - min_y + 1)

# Test function that can be called to run the analysis
static func run_analysis_from_node(house_node: Node):
	"""Run the analysis from a house node and return results"""
	return analyze_house_sprites_from_node(house_node)
