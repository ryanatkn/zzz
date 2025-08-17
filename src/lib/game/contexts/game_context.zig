/// Unified game context that combines all subsystem contexts
/// This provides a single parameter for complex game functions
const std = @import("std");
const UpdateContext = @import("update_context.zig").UpdateContext;
const InputContext = @import("input_context.zig").InputContext;
const GraphicsContext = @import("graphics_context.zig").GraphicsContext;
const PhysicsContext = @import("physics_context.zig").PhysicsContext;

/// Unified game context for passing all required state to game systems
/// This is a generic base that games can extend with their specific state
pub fn GameContext(comptime GameStateType: type, comptime GameWorldType: type, comptime CameraType: type) type {
    return struct {
        const Self = @This();
        
        // Core contexts
        update: UpdateContext,
        input: InputContext,
        graphics: GraphicsContext,
        physics: PhysicsContext,
        
        // Game-specific references (optional, can be null)
        game_state: ?*GameStateType,
        game_world: ?*GameWorldType,
        camera: ?*const CameraType,
        
        pub fn init(
            update_ctx: UpdateContext,
            input_ctx: InputContext,
            graphics_ctx: GraphicsContext,
            physics_ctx: PhysicsContext,
        ) Self {
            return .{
                .update = update_ctx,
                .input = input_ctx,
                .graphics = graphics_ctx,
                .physics = physics_ctx,
                .game_state = null,
                .game_world = null,
                .camera = null,
            };
        }
        
        pub fn withGameState(self: Self, game_state: *GameStateType) Self {
            var result = self;
            result.game_state = game_state;
            return result;
        }
        
        pub fn withGameWorld(self: Self, game_world: *GameWorldType) Self {
            var result = self;
            result.game_world = game_world;
            return result;
        }
        
        pub fn withCamera(self: Self, camera: *const CameraType) Self {
            var result = self;
            result.camera = camera;
            return result;
        }
        
        /// Get effective delta time from update context
        pub fn deltaTime(self: Self) f32 {
            return self.update.effectiveDeltaTime();
        }
        
        /// Check if game is paused
        pub fn isPaused(self: Self) bool {
            return self.update.is_paused;
        }
        
        /// Get frame allocator
        pub fn frameAllocator(self: Self) std.mem.Allocator {
            return self.update.frame_allocator;
        }
        
        /// Get frame number
        pub fn frameNumber(self: Self) u64 {
            return self.update.frame_number;
        }
    };
}

/// Simple game context without specific game types (for generic systems)
pub const SimpleGameContext = struct {
    update: UpdateContext,
    input: InputContext,
    graphics: GraphicsContext,
    physics: PhysicsContext,
    
    pub fn init(
        update_ctx: UpdateContext,
        input_ctx: InputContext,
        graphics_ctx: GraphicsContext,
        physics_ctx: PhysicsContext,
    ) SimpleGameContext {
        return .{
            .update = update_ctx,
            .input = input_ctx,
            .graphics = graphics_ctx,
            .physics = physics_ctx,
        };
    }
    
    /// Get effective delta time from update context
    pub fn deltaTime(self: SimpleGameContext) f32 {
        return self.update.effectiveDeltaTime();
    }
    
    /// Check if game is paused
    pub fn isPaused(self: SimpleGameContext) bool {
        return self.update.is_paused;
    }
    
    /// Get frame allocator
    pub fn frameAllocator(self: SimpleGameContext) std.mem.Allocator {
        return self.update.frame_allocator;
    }
    
    /// Get frame number
    pub fn frameNumber(self: SimpleGameContext) u64 {
        return self.update.frame_number;
    }
};

/// Context utilities that work with any game context type
pub const GameContextUtils = struct {
    /// Extract update context from any game context
    pub fn getUpdateContext(context: anytype) UpdateContext {
        return context.update;
    }
    
    /// Extract input context from any game context
    pub fn getInputContext(context: anytype) InputContext {
        return context.input;
    }
    
    /// Extract graphics context from any game context
    pub fn getGraphicsContext(context: anytype) GraphicsContext {
        return context.graphics;
    }
    
    /// Extract physics context from any game context
    pub fn getPhysicsContext(context: anytype) PhysicsContext {
        return context.physics;
    }
    
    /// Get delta time from any game context
    pub fn deltaTime(context: anytype) f32 {
        return context.deltaTime();
    }
    
    /// Check if paused from any game context
    pub fn isPaused(context: anytype) bool {
        return context.isPaused();
    }
};