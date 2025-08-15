/// Game engine systems barrel export
pub const events = @import("events/system.zig");
pub const event_types = @import("events/types.zig");
pub const event_listener = @import("events/listener.zig");

pub const save_state = @import("persistence/save_state.zig");
pub const save_manager = @import("persistence/manager.zig");
pub const storage = @import("persistence/storage.zig");

pub const state_manager = @import("state/manager.zig");
pub const cache = @import("state/cache.zig");
pub const tracker = @import("state/tracker.zig");

// Convenience re-exports
pub const EventSystem = events.EventSystem;
pub const GameEvents = event_types.GameEvents;
pub const EventListener = event_listener.EventListener;

pub const SaveState = save_state.SaveState;
pub const SaveManager = save_manager.SaveManager;
pub const Storage = storage.Storage;

pub const StateManager = state_manager.StateManager;
pub const Cache = cache.Cache;
pub const ProgressTracker = tracker.ProgressTracker;