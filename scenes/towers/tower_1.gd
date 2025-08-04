extends Node2D

@export var level: int = 1
@export var level_regions: Array[Rect2] = []
@export var weapon_offset_from_top: int = 20 # pixels below top of the base sprite

func _ready():
	update_base_sprite()
	update_weapon_position()

func upgrade():
	if level < level_regions.size():
		level += 1
		update_base_sprite()

func update_base_sprite():
	var sprite = $towerBase
	sprite.region_enabled = true
	sprite.region_rect = level_regions[level - 1]
	var region_height = sprite.region_rect.size.y
	var cell_height = 64 # or get from your TileMap if variable
	sprite.offset.y = -(region_height / 2) + (cell_height / 2)

func update_weapon_position():
	var base_sprite = $towerBase
	var weapon_sprite = $towerWeapon
	if base_sprite and weapon_sprite:
		var top_y = base_sprite.position.y - base_sprite.region_rect.size.y / 2 if base_sprite.region_enabled else base_sprite.position.y - base_sprite.texture.get_height() / 2
		weapon_sprite.position.y = top_y + weapon_offset_from_top
		weapon_sprite.position.x = base_sprite.position.x # center horizontally (optional)
