# TODO: Hex Behaviors Module Refactor

**Status**: 📋 PLANNED - Refactor src/hex/behaviors.zig into modular structure  
**Date**: August 18, 2025  
**Context**: Complete modular behavior system needs better organization

## Current State

### **Single File Implementation**
```
src/hex/behaviors.zig (540 lines)
├── BehaviorComposer struct
├── ProfileConfigs constants  
├── BehaviorType enum
├── 4 behavior evaluation functions
├── Entity ID mapping system
├── Main update function
└── Legacy compatibility layer
```

## Proposed Refactor

### **Target Module Structure**
```
src/hex/behaviors/
├── mod.zig                    # Public API and re-exports
├── composer.zig               # BehaviorComposer struct
├── profiles.zig               # ProfileConfigs and BehaviorType
├── evaluators.zig             # Profile-specific evaluation functions
├── entity_mapping.zig         # Entity ID management
└── integration.zig            # Main update and initialization
```

## Detailed Refactor Plan

### **1. Create Module Directory**
```bash
mkdir -p src/hex/behaviors/
```

### **2. Extract Components**

#### **mod.zig** (Public API)
```zig
// Main public interface - what other hex modules import
pub const BehaviorComposer = @import("composer.zig").BehaviorComposer;
pub const BehaviorType = @import("profiles.zig").BehaviorType;
pub const ProfileConfigs = @import("profiles.zig").ProfileConfigs;

// Main functions
pub const updateUnitWithAggroMod = @import("integration.zig").updateUnitWithAggroMod;
pub const initBehaviorSystem = @import("integration.zig").initBehaviorSystem;
pub const deinitBehaviorSystem = @import("integration.zig").deinitBehaviorSystem;
pub const removeComposer = @import("integration.zig").removeComposer;
```

#### **composer.zig** (BehaviorComposer)
```zig
const std = @import("std");
const Vec2 = @import("../../lib/math/mod.zig").Vec2;
const behaviors_mod = @import("../../lib/game/behaviors/mod.zig");
const BehaviorProfile = @import("../hex_game.zig").BehaviorProfile;

// Import individual behavior modules
const chase_behavior = behaviors_mod.chase_behavior;
const flee_behavior = behaviors_mod.flee_behavior;
const wander_behavior = behaviors_mod.wander_behavior;
const return_home_behavior = behaviors_mod.return_home_behavior;

/// Behavior types for tracking active behavior
pub const BehaviorType = enum {
    idle,
    chasing,
    fleeing,
    wandering,
    returning_home,
};

/// Comprehensive behavior state container for modular system
pub const BehaviorComposer = struct {
    // Individual behavior states
    chase_state: chase_behavior.ChaseState,
    flee_state: flee_behavior.FleeState,
    wander_state: wander_behavior.WanderState,
    
    // Profile and current behavior tracking
    profile: BehaviorProfile,
    current_behavior: BehaviorType,
    
    // ... rest of implementation
};
```

#### **profiles.zig** (Configuration)
```zig
const constants = @import("../constants.zig");
const chase_behavior = @import("../../lib/game/behaviors/mod.zig").chase_behavior;
const flee_behavior = @import("../../lib/game/behaviors/mod.zig").flee_behavior;
const wander_behavior = @import("../../lib/game/behaviors/mod.zig").wander_behavior;
const return_home_behavior = @import("../../lib/game/behaviors/mod.zig").return_home_behavior;

/// Profile-specific behavior configurations
pub const ProfileConfigs = struct {
    // Hostile profile: aggressive chaser
    pub const hostile = struct {
        pub const chase = chase_behavior.ChaseConfig.init(
            constants.UNIT_DETECTION_RADIUS,
            5.0, // min_distance
            150.0, // chase_speed
            0.0, // chase_duration
            1.15, // lose_range_multiplier
        );
        pub const return_home = return_home_behavior.ReturnHomeConfig.init(
            20.0, // home_tolerance
            100.0, // return_speed
        );
    };
    
    // ... other profiles
};
```

#### **evaluators.zig** (Behavior Logic)
```zig
const std = @import("std");
const Vec2 = @import("../../lib/math/mod.zig").Vec2;
const BehaviorComposer = @import("composer.zig").BehaviorComposer;
const BehaviorType = @import("composer.zig").BehaviorType;
const ProfileConfigs = @import("profiles.zig").ProfileConfigs;

/// Result structure for composed behavior evaluation
pub const ComposedBehaviorResult = struct {
    velocity: Vec2,
    active_behavior: BehaviorType,
    behavior_changed: bool = false,
    
    // Events for hex-specific handling
    detected_target: bool = false,
    lost_target: bool = false,
    started_fleeing: bool = false,
    stopped_fleeing: bool = false,
};

/// Context for behavior evaluation
pub const BehaviorContext = struct {
    // ... context fields
};

/// Evaluate behavior for a specific profile using composed modules
pub fn evaluateBehaviorForProfile(composer: *BehaviorComposer, context: BehaviorContext) ComposedBehaviorResult {
    return switch (composer.profile) {
        .hostile => evaluateHostileBehavior(composer, context),
        .fearful => evaluateFearfulBehavior(composer, context),
        .neutral => evaluateNeutralBehavior(composer, context),
        .friendly => evaluateFriendlyBehavior(composer, context),
    };
}

// ... evaluation functions
```

#### **entity_mapping.zig** (ID Management)
```zig
const std = @import("std");
const Unit = @import("../hex_game.zig").Unit;

/// Entity ID counter for behavior composer mapping
var next_entity_id: u32 = 1;
var entity_id_map: std.HashMap(usize, u32, std.hash_map.AutoContext(usize), std.hash_map.default_max_load_percentage) = undefined;

/// Initialize entity ID mapping system
pub fn initEntityIDMapping(allocator: std.mem.Allocator) void {
    entity_id_map = std.HashMap(usize, u32, std.hash_map.AutoContext(usize), std.hash_map.default_max_load_percentage).init(allocator);
}

/// Cleanup entity ID mapping system
pub fn deinitEntityIDMapping() void {
    entity_id_map.deinit();
}

/// Get or assign a stable entity ID for a unit pointer
pub fn getEntityID(unit_ptr: *Unit) u32 {
    // ... implementation
}
```

#### **integration.zig** (Main Interface)
```zig
const std = @import("std");
const math = @import("../../lib/math/mod.zig");
const frame = @import("../../lib/core/frame.zig");
const constants = @import("../constants.zig");
const hex_game_mod = @import("../hex_game.zig");

const BehaviorComposer = @import("composer.zig").BehaviorComposer;
const evaluators = @import("evaluators.zig");
const entity_mapping = @import("entity_mapping.zig");

// ... storage and main functions
```

### **3. Migration Strategy**

#### **Phase 1: Create Module Structure**
1. Create `src/hex/behaviors/` directory
2. Create individual module files with proper exports
3. Move code sections to appropriate modules
4. Ensure each module compiles independently

#### **Phase 2: Update Imports**
1. Update `src/hex/main.zig` to import from `behaviors/mod.zig`
2. Update any other hex modules that import behaviors
3. Test compilation after each import change

#### **Phase 3: Validation**
1. Run full test suite to ensure functionality unchanged
2. Test game launch and behavior verification
3. Performance validation (should remain 6-7ms frame times)

#### **Phase 4: Cleanup**
1. Remove old `src/hex/behaviors.zig` file
2. Update documentation to reference new module structure
3. Add module-level documentation to each file

### **4. Benefits of Refactor**

#### **Code Organization**
- **Focused modules**: Each file has a single, clear responsibility
- **Easier navigation**: Find specific functionality quickly
- **Better encapsulation**: Clear public vs internal APIs

#### **Maintainability**
- **Modular testing**: Test individual components separately
- **Reduced coupling**: Changes isolated to specific modules
- **Clear dependencies**: Import structure shows relationships

#### **Extensibility**
- **Easy additions**: New behavior profiles just add to profiles.zig
- **Plugin-style**: New evaluators can be added without touching core
- **Future growth**: Room for additional behavior features

### **5. Integration Points**

#### **Import Changes Required**
```zig
// Before
const behaviors = @import("behaviors.zig");

// After  
const behaviors = @import("behaviors/mod.zig");
```

#### **API Compatibility**
All public functions remain identical:
- `behaviors.updateUnitWithAggroMod()`
- `behaviors.initBehaviorSystem()`
- `behaviors.deinitBehaviorSystem()`
- `behaviors.removeComposer()`

## Risk Assessment

### **Low Risk Factors**
- ✅ **Pure refactor**: No logic changes, only organization
- ✅ **Identical API**: Public interface remains unchanged  
- ✅ **Incremental**: Can be done step-by-step with validation
- ✅ **Tested code**: Existing functionality already validated

### **Mitigation Strategies**
- **Backup**: Keep original behaviors.zig until validation complete
- **Compilation checks**: Ensure each module compiles independently
- **Test coverage**: Run full test suite after each phase
- **Performance validation**: Confirm no regression in frame times

## Success Criteria

### **Functionality**
- ✅ All 4 behavior profiles work identically (hostile, fearful, neutral, friendly)
- ✅ Entity ID mapping functions correctly
- ✅ Behavior composer initialization/cleanup works
- ✅ Performance maintained (6-7ms frame times)

### **Code Quality**
- ✅ Clear module separation with focused responsibilities
- ✅ Clean import dependencies between modules
- ✅ Public API unchanged for backward compatibility
- ✅ Each module independently compilable and testable

### **Documentation**
- ✅ Module-level documentation explaining purpose
- ✅ Clear examples of how to extend each module
- ✅ Updated architecture documentation

## Estimated Effort

**Time**: 2-3 hours  
**Complexity**: Medium (organizational, not algorithmic)  
**Risk**: Low (pure refactor with extensive testing)

## Final State

After refactor, the behavior system will have:
- **5 focused modules** instead of 1 monolithic file
- **Clear separation of concerns** with defined responsibilities  
- **Better extensibility** for future behavior additions
- **Identical functionality** with zero behavioral changes
- **Same performance** characteristics (6-7ms frame times)

This refactor will serve as a **reference implementation** for how to properly organize modular game systems while maintaining excellent performance and clean architecture.

---

**Implementation Plan**: Ready for execution  
**Prerequisites**: Current behavior system fully functional  
**Next Step**: Create module directory and begin Phase 1  
**Validation**: Extensive testing at each phase to ensure zero regressions