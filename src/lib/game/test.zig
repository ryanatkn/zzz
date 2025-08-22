// Game Library Test Barrel File
//
// This file re-exports all tests from game modules for clean integration
// with the main test suite.

const std = @import("std");

// Working game modules
test {
    _ = @import("behaviors/chase_behavior.zig");
    _ = @import("behaviors/flee_behavior.zig");
    _ = @import("projectiles/bullet_pool.zig");
    _ = @import("zones/zone_manager.zig");

    // Recently fixed modules
    _ = @import("behaviors/patrol_behavior.zig"); // Fixed: Const assignment issues resolved
    _ = @import("behaviors/behavior_state_machine.zig"); // Fixed: patrol_behavior dependency resolved
    _ = @import("behaviors/guard_behavior.zig"); // Fixed: patrol_behavior dependency resolved
    _ = @import("behaviors/return_home_behavior.zig"); // Fixed: patrol_behavior dependency resolved

    // Additional working modules
    _ = @import("behaviors/wander_behavior.zig"); // Working: No runtime failures detected

    // TODO: Complex API design issues
    // _ = @import("storage/entity_storage.zig"); // Complex API design needs refactoring
}

// TODO: The following modules are excluded:
// - control/direct_input.zig: SDL input handling (legitimate exclusion)
