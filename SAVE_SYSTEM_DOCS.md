# Save System Documentation

## Overview
The save system allows players to save their progress at the end of each wave (checkpoint system) and manually save/load their game. This integrates with the achievement system to preserve all progress.

## Key Features

### Automatic Checkpoint Saves
- **When**: Automatically saves when a wave is completed
- **Location**: Saved as slot 0 (checkpoint)
- **Restoration**: When loaded, player starts at the beginning of the next wave
- **Example**: Complete wave 3 → Save created → Load game → Start at beginning of wave 4

### Manual Save/Load
- **Quick Save**: Press F5 to save to slot 1
- **Quick Load**: Press F9 to load from slot 1 (or checkpoint if no manual save)
- **Pause Menu**: Save/Load options available in pause menu
- **Multiple Slots**: Support for 3 save slots plus checkpoint

### What Gets Saved
- **Game State**: Current wave, gold, health, preparation/active state
- **Game Mode**: Current mode (Normal, Extra Hard, Endless) with all settings
- **Towers**: All tower positions, levels, and upgrade states
- **Endless Mode**: Survival time, difficulty level, enemies killed
- **Achievements**: Integrated with existing achievement system
- **House Skin**: Current selected house skin

## Usage

### For Players
1. **Automatic Saving**: Play normally - game saves after each wave completion
2. **Manual Saving**: 
   - Press F5 for quick save
   - Or pause game (ESC) and use Save Game button
3. **Loading**:
   - Press F9 for quick load
   - Or use Load Game from main menu
   - Or use Load Game from pause menu

### Loading Priority
1. Manual save (slot 1) if it exists
2. Checkpoint save if no manual save
3. New game if no saves exist

## Technical Implementation

### Save Data Structure
```json
{
  "save_version": 1,
  "timestamp": "2025-01-09T12:34:56",
  "gold": 2500,
  "health": 85,
  "current_wave_number": 5,
  "game_mode_name": "Normal",
  "game_mode_type": "normal",
  "towers": [
    {
      "position": {"x": 192, "y": 256},
      "level": 2,
      "tower_data_path": "res://assets/towers/tower1/tower1.tres"
    }
  ],
  "endless_survival_time": 0.0,
  "endless_difficulty_level": 1
}
```

### Files
- **SaveManager.gd**: Main save/load logic singleton
- **Save Files**: Stored in user://game_save_slot_X.save
- **Checkpoint**: user://game_save_slot_0.save

### Integration Points
- **main.gd**: Wave completion triggers checkpoint save
- **main_menu.gd**: Load game menu functionality
- **AchievementManager**: Preserves achievement progress
- **HouseSkinManager**: Preserves selected house skin

## Endless Mode Special Handling
- **Auto-save**: Every 2 minutes during survival
- **Continuous State**: Saves current difficulty level and enemy spawning state
- **No Wave Checkpoints**: Uses time-based checkpoints instead

## Error Handling
- Save file corruption detection
- Version compatibility checking
- Graceful fallback to new game if load fails
- User notifications for save/load status

## Future Enhancements
- Multiple save slots with preview information
- Save file management (delete, rename)
- Export/import save files
- Cloud save integration
- Save game screenshots/previews

## File Locations
- **Windows**: `%APPDATA%/Godot/app_userdata/SiegecraftTD/`
- **macOS**: `~/Library/Application Support/Godot/app_userdata/SiegecraftTD/`
- **Linux**: `~/.local/share/godot/app_userdata/SiegecraftTD/`

## Troubleshooting
- **Save not working**: Check file permissions in user data directory
- **Load fails**: Delete corrupted save files to reset
- **Missing progress**: Ensure achievements are saved separately and reload
- **Wrong wave loaded**: Checkpoint system loads next wave, not current wave
