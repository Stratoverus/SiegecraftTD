# Game Mode System Documentation

## Overview
The game mode system allows for three different gameplay experiences:
- **Endless Mode**: Continuous waves with scaling difficulty
- **Normal Mode**: Predefined wave sequence with boss fights
- **Extra Hard Mode**: Same as normal but with doubled enemy health and house damage

## ✅ Fixed Issues
- **Null Instance Error**: Fixed the error where `mode_name` was accessed on a null object
- **Consolidated Wave Management**: All waves are now defined in single .tres files instead of separate files per wave

## 📁 File Structure

### Core Classes
- `gameModeData.gd` - Main game mode configuration
- `waveDefinition.gd` - Individual wave properties
- `enemyGroup.gd` - Enemy spawn groups within waves

### Game Mode Files
- `normalModeComplete.tres` - Complete normal mode with 5 sample waves
- `extraHardModeComplete.tres` - Extra hard version with 2x health/damage multipliers
- `endlessMode.tres` - Endless mode configuration

## 🎮 How to Add More Waves

### Option 1: Edit .tres files directly in Godot
1. Open `normalModeComplete.tres` in the inspector
2. Expand "Wave Definitions" array
3. Add new WaveDefinition resources
4. For each wave, add EnemyGroup resources

### Option 2: Copy and modify existing patterns
You can duplicate the existing SubResource sections in the .tres files and modify:
- Wave numbers
- Enemy types (firebug, fireWasp, flyingLocust, clampBeetle, leafbug, voidButterfly, scorpion, magmaCrab)
- Enemy counts
- Spawn delays
- Preparation times

### Option 3: Use the WaveGenerator tool
The `WaveGenerator.gd` script can help generate wave definitions programmatically.

## 🎯 Enemy Types Available
- `firebug` - Basic ground enemy
- `fireWasp` - Flying enemy
- `flyingLocust` - Fast flying enemy
- `clampBeetle` - Armored ground enemy
- `leafbug` - Basic ground enemy variant
- `voidButterfly` - Special flying enemy
- `scorpion` - Strong ground enemy
- `magmaCrab` - Boss-tier enemy

## 📊 Scaling System
- **Normal Mode**: No scaling (1.0x health, 1.0x damage, 1.0x gold)
- **Extra Hard Mode**: 2.0x health, 2.0x damage, 1.0x gold
- **Endless Mode**: Exponential scaling with 1.15x multiplier per wave

## 🔧 Customization

### Difficulty Scaling
Edit the multipliers in the .tres files:
```
health_multiplier = 2.0  # Double enemy health
damage_multiplier = 2.0  # Double damage to house
gold_multiplier = 1.0    # Same gold rewards
```

### Wave Timing
- `preparation_time` - Seconds before wave starts
- `spawn_interval` - Seconds between individual enemy spawns
- `break_between_waves` - Seconds between waves

### Endless Mode Scaling
- `endless_scaling_factor` - Multiplier applied each wave (1.15 = 15% harder)
- `endless_wave_interval` - Seconds between waves

## 💡 Tips for Creating 50 Waves

1. **Progressive Difficulty**: Start with 3-5 enemies in wave 1, gradually increase
2. **Boss Waves**: Every 5th or 10th wave should be a boss wave
3. **Enemy Variety**: Introduce new enemy types every few waves
4. **Multiple Groups**: Later waves should have multiple enemy groups with delays
5. **Copy-Paste Pattern**: Use the existing wave structure as a template

## 🚀 Quick Start for 50 Waves

To quickly create 50 waves, you can:
1. Copy the existing 5-wave pattern 10 times
2. Adjust wave numbers (1-50)
3. Gradually increase enemy counts and variety
4. Make every 10th wave a boss wave
5. Decrease preparation times for later waves to increase pace

The system is designed to be flexible and easy to extend!
