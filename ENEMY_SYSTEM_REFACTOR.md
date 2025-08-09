# Enemy System Refactor

## Overview
The enemy system has been refactored to use a data-driven approach similar to the tower system, making it easy to add new enemy types without code changes.

## Architecture

### 1. EnemyData Resource (`assets/Enemies/enemyData.gd`)
- Defines stats and properties for each enemy type
- Includes health, speed, gold worth, animations, and special abilities
- Similar to TowerData but for enemies

### 2. Generic Enemy Script (`scenes/enemies/enemy.gd`)
- Now works with any EnemyData resource
- No longer hardcoded to specific enemy types
- Handles animations dynamically based on enemy data

### 3. Enemy Scene Files
- `firebug.tscn` - Specific scene for firebug enemy
- `enemy.gd` - Generic script attached to all enemy scenes

## Files Created/Modified

### New Files:
- `assets/Enemies/enemyData.gd` - Enemy data resource script
- `assets/Enemies/firebug/firebug.tres` - Firebug enemy data
- `scenes/enemies/firebug.tscn` - Firebug-specific scene
- `scenes/enemies/EnemyManager.gd` - Optional manager for waves and enemy types
- `assets/Enemies/examples/orc.tres` - Example of additional enemy type

### Modified Files:
- `scenes/enemies/enemy.gd` - Made generic to work with any enemy data
- `scenes/main.gd` - Updated spawning system to use enemy data

## How to Add New Enemies

### 1. Create Enemy Data Resource
Create a new `.tres` file (e.g., `assets/Enemies/orc/orc.tres`):
```gdscript
[gd_resource type="Resource" script_class="EnemyData" load_steps=2 format=3]

[ext_resource type="Script" path="res://assets/Enemies/enemyData.gd" id="1_orc"]

[resource]
script = ExtResource("1_orc")
scene_path = "res://scenes/enemies/orc.tscn"
enemy_name = "Orc Warrior"
enemy_type = "ground"
max_health = 200
speed = 80.0
gold_worth = 10
# ... other properties
```

### 2. Create Enemy Scene
Create a new scene file (e.g., `scenes/enemies/orc.tscn`):
- Add Node2D as root
- Add AnimatedSprite2D child with your orc animations
- Attach the generic `enemy.gd` script
- Set up animations: walk, walkDown, die, dieDown, idle, idleDown

### 3. Use in Game
```gdscript
# Spawn specific enemy type
spawn_enemy(path_points, "res://assets/Enemies/orc/orc.tres")

# Or use the EnemyManager
var enemy_manager = EnemyManager.new()
enemy_manager.add_enemy_type("orc", "res://assets/Enemies/orc/orc.tres")
```

## Benefits

1. **Easy Addition**: New enemies only require creating data and scene files
2. **No Code Changes**: Generic enemy script works with all enemy types
3. **Consistent Architecture**: Matches tower system design
4. **Maintainable**: Centralized enemy properties in data resources
5. **Extensible**: Easy to add new properties and abilities

## Animation Requirements

Each enemy scene should have these animations in its AnimatedSprite2D:
- `walk` - Moving horizontally/other directions
- `walkDown` - Moving downward (optional if has_directional_animations = false)
- `die` - Death animation for horizontal/other directions
- `dieDown` - Death animation for downward direction (optional)
- `idle` - Idle animation (optional)
- `idleDown` - Idle animation for downward direction (optional)

## Future Enhancements

- Wave management system with different enemy types per wave
- Special abilities system (armor, flying, regeneration, etc.)
- Resistance system (fire resistance, ice resistance, etc.)
- Boss enemies with special mechanics
- Enemy variations (different colors/stats of same base enemy)
