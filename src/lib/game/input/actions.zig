const std = @import("std");
const c = @import("../../platform/sdl.zig");

/// Standard game actions - games can extend or map differently
pub const GameAction = enum {
    // Movement actions
    MoveUp,
    MoveDown,
    MoveLeft,
    MoveRight,
    
    // Combat actions
    PrimaryAttack,    // Usually left-click
    SecondaryAttack,  // Usually right-click
    
    // Spell/ability actions
    CastSpell,
    SelectSpell1,
    SelectSpell2,
    SelectSpell3,
    SelectSpell4,
    SelectSpell5,
    SelectSpell6,
    SelectSpell7,
    SelectSpell8,
    
    // System actions
    TogglePause,
    ToggleMenu,
    Respawn,
    ResetZone,
    ResetGame,
    Quit,
    
    // Camera actions
    ZoomIn,
    ZoomOut,
    
    // Debug/Special actions
    ToggleAI,
    ToggleHUD,
    
    None,
};

/// Action priority for conflict resolution
pub const ActionPriority = enum(u8) {
    System = 0,   // Quit, pause, menu - always highest
    Respawn = 1,  // Respawn when dead
    Combat = 2,   // Shooting, spells
    Movement = 3, // Movement controls
    UI = 4,       // HUD, menus
    Debug = 5,    // Debug commands
    
    pub fn canOverride(self: ActionPriority, other: ActionPriority) bool {
        return @intFromEnum(self) <= @intFromEnum(other);
    }
};

/// Game state context for action filtering
pub const ActionContext = struct {
    player_alive: bool = true,
    game_paused: bool = false,
    menu_open: bool = false,
    has_focus: bool = true,
    
    pub fn init() ActionContext {
        return .{};
    }
    
    pub fn withPlayerState(self: ActionContext, alive: bool) ActionContext {
        var ctx = self;
        ctx.player_alive = alive;
        return ctx;
    }
    
    pub fn withMenuState(self: ActionContext, menu_open: bool) ActionContext {
        var ctx = self;
        ctx.menu_open = menu_open;
        return ctx;
    }
    
    pub fn withPauseState(self: ActionContext, paused: bool) ActionContext {
        var ctx = self;
        ctx.game_paused = paused;
        return ctx;
    }
    
    /// Check if an action should be allowed in the current context
    pub fn shouldAllowAction(self: ActionContext, action: GameAction, priority: ActionPriority) bool {
        _ = action; // Action filtering logic can be added later
        // System actions always allowed
        if (priority == .System) return true;
        
        // Block all actions when no focus
        if (!self.has_focus) return false;
        
        // Block lower priority actions when menu is open
        if (self.menu_open and priority != .UI) return false;
        
        // Dead player can only perform respawn actions
        if (!self.player_alive and priority != .Respawn and priority != .System) return false;
        
        // Paused game blocks most actions except system and UI
        if (self.game_paused and priority != .System and priority != .UI) return false;
        
        return true;
    }
};

/// Map SDL scancode to game action
pub fn mapScancodeToAction(scancode: u32) GameAction {
    return switch (scancode) {
        // Movement
        c.sdl.SDL_SCANCODE_W => .MoveUp,
        c.sdl.SDL_SCANCODE_S => .MoveDown,
        c.sdl.SDL_SCANCODE_A => .MoveLeft,
        c.sdl.SDL_SCANCODE_D => .MoveRight,
        
        // Spells (1-4, Q, E, R, F pattern)
        c.sdl.SDL_SCANCODE_1 => .SelectSpell1,
        c.sdl.SDL_SCANCODE_2 => .SelectSpell2,
        c.sdl.SDL_SCANCODE_3 => .SelectSpell3,
        c.sdl.SDL_SCANCODE_4 => .SelectSpell4,
        c.sdl.SDL_SCANCODE_Q => .SelectSpell5,
        c.sdl.SDL_SCANCODE_E => .SelectSpell6,
        c.sdl.SDL_SCANCODE_R => .SelectSpell7,
        c.sdl.SDL_SCANCODE_F => .SelectSpell8,
        
        // System
        c.sdl.SDL_SCANCODE_SPACE => .TogglePause,
        c.sdl.SDL_SCANCODE_GRAVE => .ToggleMenu, // Backtick
        c.sdl.SDL_SCANCODE_ESCAPE => .Quit,
        c.sdl.SDL_SCANCODE_L => .Respawn, // L for Lifestone respawn
        c.sdl.SDL_SCANCODE_T => .ResetZone,
        c.sdl.SDL_SCANCODE_Y => .ResetGame,
        c.sdl.SDL_SCANCODE_G => .ToggleAI,
        
        else => .None,
    };
}

/// Map mouse button to game action
pub fn mapMouseButtonToAction(button: u8) GameAction {
    return switch (button) {
        c.sdl.SDL_BUTTON_LEFT => .PrimaryAttack,
        c.sdl.SDL_BUTTON_RIGHT => .SecondaryAttack,
        else => .None,
    };
}

/// Map mouse wheel to game action
pub fn mapMouseWheelToAction(wheel_y: f32) GameAction {
    if (wheel_y > 0) return .ZoomIn;
    if (wheel_y < 0) return .ZoomOut;
    return .None;
}

/// Get priority level for an action
pub fn getActionPriority(action: GameAction) ActionPriority {
    return switch (action) {
        .Quit, .ToggleMenu, .TogglePause => .System,
        .Respawn => .Respawn,
        .PrimaryAttack, .SecondaryAttack, .CastSpell => .Combat,
        .SelectSpell1, .SelectSpell2, .SelectSpell3, .SelectSpell4,
        .SelectSpell5, .SelectSpell6, .SelectSpell7, .SelectSpell8 => .Combat,
        .MoveUp, .MoveDown, .MoveLeft, .MoveRight => .Movement,
        .ZoomIn, .ZoomOut => .UI,
        .ToggleHUD => .UI,
        .ResetZone, .ResetGame, .ToggleAI => .Debug,
        .None => .UI,
    };
}

/// Check if action is a movement action
pub fn isMovementAction(action: GameAction) bool {
    return switch (action) {
        .MoveUp, .MoveDown, .MoveLeft, .MoveRight => true,
        else => false,
    };
}

/// Check if action is a spell selection action
pub fn isSpellSelectionAction(action: GameAction) bool {
    return switch (action) {
        .SelectSpell1, .SelectSpell2, .SelectSpell3, .SelectSpell4,
        .SelectSpell5, .SelectSpell6, .SelectSpell7, .SelectSpell8 => true,
        else => false,
    };
}

/// Get spell slot number from spell selection action (0-7)
pub fn getSpellSlotFromAction(action: GameAction) ?u8 {
    return switch (action) {
        .SelectSpell1 => 0,
        .SelectSpell2 => 1,
        .SelectSpell3 => 2,
        .SelectSpell4 => 3,
        .SelectSpell5 => 4,
        .SelectSpell6 => 5,
        .SelectSpell7 => 6,
        .SelectSpell8 => 7,
        else => null,
    };
}

/// Action result after processing
pub const ActionResult = enum {
    Handled,           // Action was processed successfully
    Blocked,           // Action was blocked by context (dead, paused, etc.)
    NotMapped,         // Input doesn't map to any action
    NotImplemented,    // Action exists but game doesn't handle it
};

/// Process an action within a given context
pub fn processAction(action: GameAction, context: ActionContext) ActionResult {
    if (action == .None) return .NotMapped;
    
    const priority = getActionPriority(action);
    if (!context.shouldAllowAction(action, priority)) {
        return .Blocked;
    }
    
    // Action is allowed - game-specific handler will implement
    return .Handled;
}