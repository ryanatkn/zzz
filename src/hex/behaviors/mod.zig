// Hex Behaviors Module - Public API
//
// This is the main public interface for the hex behavior system.
// Other hex modules should import from this file to access behavior functionality.
//
// The behavior system uses a modular architecture where:
// - Engine (lib/game) provides behavior modules
// - Game (hex) composes behaviors using profiles
// - Each unit owns a BehaviorComposer that manages individual behavior states

// Core types and structures
pub const BehaviorComposer = @import("composer.zig").BehaviorComposer;
pub const BehaviorType = @import("composer.zig").BehaviorType;
pub const ProfileConfigs = @import("profiles.zig").ProfileConfigs;

// Context types
pub const UnitUpdateContext = @import("context.zig").UnitUpdateContext;

// Main functions for behavior system lifecycle
pub const initBehaviorSystem = @import("integration.zig").initBehaviorSystem;
pub const deinitBehaviorSystem = @import("integration.zig").deinitBehaviorSystem;
pub const removeComposer = @import("integration.zig").removeComposer;

// Unit behavior update functions
pub const updateUnit = @import("integration.zig").updateUnit;
pub const evaluateUnitBehavior = @import("integration.zig").evaluateUnitBehavior;
pub const applyBehaviorResult = @import("integration.zig").applyBehaviorResult;
pub const updateUnitWithAggroMod = @import("integration.zig").updateUnitWithAggroMod; // Legacy
