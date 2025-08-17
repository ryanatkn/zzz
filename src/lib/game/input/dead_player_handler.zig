const std = @import("std");
const input_patterns = @import("input_patterns.zig");

const InputPatterns = input_patterns.InputPatterns;
const DeadPlayerPatterns = input_patterns.DeadPlayerPatterns;
const InputType = input_patterns.InputType;

/// Specialized dead player input handler
/// Games can use this to standardize dead player input behavior
pub const DeadPlayerHandler = struct {
    /// Configuration for dead player input
    pub const Config = struct {
        click_respawns: bool = true,
        respawn_key_respawns: bool = true,
        block_other_actions: bool = true,
        allow_menu_access: bool = true,
        allow_quit: bool = true,

        pub fn default() Config {
            return .{};
        }

        pub fn clickOnly() Config {
            return .{
                .click_respawns = true,
                .respawn_key_respawns = false,
            };
        }

        pub fn keyOnly() Config {
            return .{
                .click_respawns = false,
                .respawn_key_respawns = true,
            };
        }
    };

    config: Config,

    pub fn init(config: Config) DeadPlayerHandler {
        return .{ .config = config };
    }

    pub fn initDefault() DeadPlayerHandler {
        return init(Config.default());
    }

    /// Handle input when player is dead
    pub fn handleDeadInput(self: *const DeadPlayerHandler, input_type: InputType) DeadInputResult {
        return switch (input_type) {
            .MouseClick => if (self.config.click_respawns) .Respawn else .Ignore,
            .RespawnKey => if (self.config.respawn_key_respawns) .Respawn else .Ignore,
            .MenuKey => if (self.config.allow_menu_access) .OpenMenu else .Ignore,
            .QuitKey => if (self.config.allow_quit) .Quit else .Ignore,
            else => if (self.config.block_other_actions) .Block else .Ignore,
        };
    }

    /// Check if input should trigger respawn
    pub fn shouldRespawn(self: *const DeadPlayerHandler, input_type: InputType) bool {
        return self.handleDeadInput(input_type) == .Respawn;
    }

    /// Check if input should be blocked
    pub fn shouldBlock(self: *const DeadPlayerHandler, input_type: InputType) bool {
        const result = self.handleDeadInput(input_type);
        return result == .Block or (result == .Ignore and self.config.block_other_actions);
    }
};

/// Result of dead player input handling
pub const DeadInputResult = enum {
    Respawn, // Trigger respawn
    OpenMenu, // Open menu/UI
    Quit, // Quit game
    Block, // Block this input
    Ignore, // Ignore this input (let it through if allowed)
};

/// Common dead player input configurations
pub const DeadPlayerConfigs = struct {
    /// Standard: click and R key both respawn
    pub const STANDARD = DeadPlayerHandler.Config.default();

    /// Click only: only mouse clicks respawn
    pub const CLICK_ONLY = DeadPlayerHandler.Config.clickOnly();

    /// Key only: only R key respawns
    pub const KEY_ONLY = DeadPlayerHandler.Config.keyOnly();

    /// Permissive: allows most actions through even when dead
    pub const PERMISSIVE = DeadPlayerHandler.Config{
        .click_respawns = true,
        .respawn_key_respawns = true,
        .block_other_actions = false,
        .allow_menu_access = true,
        .allow_quit = true,
    };
};
