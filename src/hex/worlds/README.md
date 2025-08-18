# Hex Game Worlds

This directory contains different world configurations for the Hex game.

## World Files

- **`test_world.zon`** - Test world with portal hub and systematic test scenarios
- **`game_world.zon`** - Clean production game world (overworld + 6 dungeons)

## World Structure

Each world file contains:
- Complete zone definitions
- Player spawn point
- Portal connections between zones
- Entity placements
- Environmental settings

## Developer Usage

### Quick World Switching

1. **Environment Variable**: `export ZZZ_WORLD=test_world.zon`
2. **Command Line**: `zig build run -- --world test_world.zon`
3. **Default in Code**: Modify `DEFAULT_WORLD` constant in loader.zig
4. **Runtime Menu**: Select world from main menu

### Test World Layout

```
Zone 0 (Test Hub):
    [Spawn] -> [Portal Ring] -> [Test Areas]
              (7 portals hex)    (expandable grid)
    
    Test Units nearby for possession testing:
    - Red hostile unit (goblin faction)
    - Yellow neutral unit  
    - Green friendly unit (kingdom faction)
    - Blue fearful unit (flees from player)
```

### Game World Layout

Clean production world with balanced progression:
- Zone 0: Overworld (large, exploration-focused)
- Zones 1-6: Themed dungeons in hexagonal arrangement

## Adding New Worlds

1. Create new `.zon` file in this directory
2. Follow existing world file structure
3. Update loader.zig if needed for new features
4. Add to menu selection system