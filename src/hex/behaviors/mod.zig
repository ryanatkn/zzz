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

// Main functions for behavior system lifecycle
pub const initBehaviorSystem = @import("integration.zig").initBehaviorSystem;
pub const deinitBehaviorSystem = @import("integration.zig").deinitBehaviorSystem;
pub const removeComposer = @import("integration.zig").removeComposer;

// Primary update function for unit behavior
pub const updateUnitWithAggroMod = @import("integration.zig").updateUnitWithAggroMod;