/// Game engine systems barrel export

// Core ECS modules
pub const ecs = @import("ecs.zig");
pub const world = @import("world.zig");
pub const zone = @import("zone.zig");
pub const game = @import("game.zig");
pub const entity = @import("entity.zig");
pub const entity_transfer = @import("entity_transfer.zig");
pub const components = @import("components.zig");
pub const component_registry = @import("component_registry.zig");
pub const archetype_storage = @import("archetype_storage.zig");
pub const storage = @import("storage.zig");
pub const pools = @import("pools.zig");

// Event system
pub const events = @import("events/system.zig");
pub const event_types = @import("events/types.zig");
pub const event_listener = @import("events/listener.zig");

// Persistence
pub const save_state = @import("persistence/save_state.zig");
pub const save_manager = @import("persistence/manager.zig");
pub const persistence_storage = @import("persistence/storage.zig");

// State management
pub const state_manager = @import("state/manager.zig");
pub const cache = @import("state/cache.zig");
pub const tracker = @import("state/tracker.zig");

// Control systems
pub const control = @import("control/mod.zig");

// Projectiles
pub const bullet_pool = @import("projectiles/bullet_pool.zig");

// Convenience re-exports
pub const World = world.World;
pub const Zone = zone.Zone;
pub const ZoneMetadata = zone.ZoneMetadata;
pub const Game = game.Game;
pub const EntityId = entity.EntityId;
pub const EntityAllocator = entity.EntityAllocator;
pub const TransferData = entity_transfer.TransferData;
pub const TransferResult = entity_transfer.TransferResult;
pub const EntityTransfer = entity_transfer.EntityTransfer;

pub const EventSystem = events.EventSystem;
pub const GameEvents = event_types.GameEvents;
pub const EventListener = event_listener.EventListener;

pub const SaveState = save_state.SaveState;
pub const SaveManager = save_manager.SaveManager;
pub const Storage = persistence_storage.Storage;

pub const StateManager = state_manager.StateManager;
pub const Cache = cache.Cache;
pub const ProgressTracker = tracker.ProgressTracker;
