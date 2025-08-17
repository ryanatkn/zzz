const std = @import("std");

/// Generic input handling patterns for games
/// Games implement specific key mappings and actions
pub const InputPatterns = struct {
    /// Standard player states that affect input handling
    pub const PlayerState = enum {
        Alive,
        Dead,
        Respawning,
        Paused,
        InMenu,
    };

    /// Generic action priority system
    pub const ActionPriority = enum(u8) {
        System = 0,     // Quit, pause, menu toggle - always highest priority
        Respawn = 1,    // Respawn actions when dead
        Combat = 2,     // Shooting, spells when alive
        Movement = 3,   // Movement controls
        UI = 4,         // HUD, inventory, etc.

        pub fn canOverride(self: ActionPriority, other: ActionPriority) bool {
            return @intFromEnum(self) <= @intFromEnum(other);
        }
    };

    /// Generic input context for decision making
    pub const InputContext = struct {
        player_state: PlayerState,
        menu_open: bool = false,
        has_focus: bool = true,
        
        pub fn init(player_state: PlayerState) InputContext {
            return .{ .player_state = player_state };
        }
        
        pub fn withMenu(self: InputContext, menu_open: bool) InputContext {
            var ctx = self;
            ctx.menu_open = menu_open;
            return ctx;
        }
        
        pub fn shouldBlockGameInput(self: InputContext) bool {
            return self.menu_open or !self.has_focus;
        }
        
        pub fn allowsAction(self: InputContext, priority: ActionPriority) bool {
            // System actions always allowed
            if (priority == .System) return true;
            
            // Block lower priority actions when menu is open
            if (self.menu_open and priority != .UI) return false;
            
            // Block all actions when no focus
            if (!self.has_focus) return false;
            
            // Dead player can only respawn
            if (self.player_state == .Dead and priority != .Respawn) return false;
            
            return true;
        }
    };
};

/// Dead player input handling patterns
pub const DeadPlayerPatterns = struct {
    /// Standard dead player actions
    pub const DeadPlayerAction = enum {
        Respawn,
        OpenMenu,
        Quit,
        None,
    };

    /// Determine what action dead player input should trigger
    pub fn getDeadPlayerAction(input_type: InputType) DeadPlayerAction {
        return switch (input_type) {
            .MouseClick, .RespawnKey => .Respawn,
            .MenuKey => .OpenMenu,
            .QuitKey => .Quit,
            else => .None,
        };
    }

    /// Check if input should trigger respawn when dead
    pub fn shouldRespawn(input_type: InputType) bool {
        return getDeadPlayerAction(input_type) == .Respawn;
    }
};

/// Common input types for pattern matching
pub const InputType = enum {
    MouseClick,
    RespawnKey,
    MenuKey,
    QuitKey,
    MovementKey,
    CombatKey,
    SpellKey,
    SystemKey,
    Unknown,
};

/// Action mapping patterns
pub const ActionMappingPatterns = struct {
    /// Generic action result
    pub const ActionResult = enum {
        Handled,
        NotHandled,
        BlockedByState,
        BlockedByPriority,
    };

    /// Map input to action based on context
    pub fn mapInputToAction(input_type: InputType, context: InputPatterns.InputContext) ActionResult {
        const priority = getInputPriority(input_type);
        
        if (!context.allowsAction(priority)) {
            return if (priority == .System) .BlockedByState else .BlockedByPriority;
        }
        
        // Special handling for dead player
        if (context.player_state == .Dead) {
            return if (DeadPlayerPatterns.shouldRespawn(input_type)) .Handled else .NotHandled;
        }
        
        return .Handled;
    }

    /// Get priority level for input type
    pub fn getInputPriority(input_type: InputType) InputPatterns.ActionPriority {
        return switch (input_type) {
            .QuitKey, .MenuKey => .System,
            .RespawnKey => .Respawn,
            .MouseClick, .CombatKey, .SpellKey => .Combat,
            .MovementKey => .Movement,
            else => .UI,
        };
    }
};

/// Key combination patterns
pub const KeyCombinationPatterns = struct {
    /// Standard modifier keys
    pub const Modifiers = packed struct {
        ctrl: bool = false,
        shift: bool = false,
        alt: bool = false,
        
        pub fn none() Modifiers {
            return .{};
        }
        
        pub fn withCtrl() Modifiers {
            return .{ .ctrl = true };
        }
        
        pub fn withShift() Modifiers {
            return .{ .shift = true };
        }
        
        pub fn withCtrlShift() Modifiers {
            return .{ .ctrl = true, .shift = true };
        }
        
        pub fn matches(self: Modifiers, other: Modifiers) bool {
            return std.meta.eql(self, other);
        }
    };

    /// Check for specific key combinations
    pub fn isWalkModifier(modifiers: Modifiers) bool {
        return modifiers.shift and !modifiers.ctrl;
    }
    
    pub fn isSelfCastModifier(modifiers: Modifiers) bool {
        return modifiers.ctrl and !modifiers.shift;
    }
};