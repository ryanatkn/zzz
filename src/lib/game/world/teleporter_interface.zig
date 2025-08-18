const std = @import("std");
const math = @import("../../math/mod.zig");
const timer = @import("../../core/timer.zig");

const Vec2 = math.Vec2;

/// Generic teleporter/portal interface
/// Games implement this to provide teleportation mechanics
pub const TeleporterInterface = struct {
    /// Configuration for teleporter behavior
    pub const TeleporterConfig = struct {
        cooldown_duration: f32 = 1.0, // Seconds to wait between teleportations
        requires_collision: bool = true, // Whether player must touch teleporter
        auto_activate: bool = true, // Whether teleporter activates automatically on touch
        effect_on_use: bool = true, // Whether to create effects when used
    };

    /// Data about a teleporter destination
    pub const TeleporterDestination = struct {
        zone_index: usize,
        spawn_position: ?Vec2 = null, // Use zone default if null

        pub fn withPosition(zone_index: usize, position: Vec2) TeleporterDestination {
            return .{ .zone_index = zone_index, .spawn_position = position };
        }
    };

    /// Result of attempting to use a teleporter
    pub const TeleporterResult = struct {
        activated: bool,
        destination: ?TeleporterDestination,
        blocked_reason: ?BlockedReason = null,

        pub const BlockedReason = enum {
            cooldown_active,
            no_collision,
            invalid_destination,
            travel_failed,
        };

        pub fn success(destination: TeleporterDestination) TeleporterResult {
            return .{ .activated = true, .destination = destination };
        }

        pub fn blocked(reason: BlockedReason) TeleporterResult {
            return .{ .activated = false, .destination = null, .blocked_reason = reason };
        }
    };

    /// Teleporter entity data - games extend this with their specific components
    pub const TeleporterData = struct {
        entity_id: u32,
        position: Vec2,
        radius: f32,
        destination: TeleporterDestination,
        config: TeleporterConfig,

        pub fn init(entity_id: u32, position: Vec2, radius: f32, destination: TeleporterDestination) TeleporterData {
            return .{
                .entity_id = entity_id,
                .position = position,
                .radius = radius,
                .destination = destination,
                .config = TeleporterConfig{},
            };
        }

        pub fn withConfig(self: TeleporterData, config: TeleporterConfig) TeleporterData {
            var result = self;
            result.config = config;
            return result;
        }
    };

    /// Manages teleporter cooldowns and collision detection
    pub fn TeleporterManager(comptime max_teleporters: usize) type {
        return struct {
            const Self = @This();

            teleporters: [max_teleporters]TeleporterData,
            teleporter_count: usize,
            global_cooldown: timer.Cooldown,

            pub fn init(cooldown_duration: f32) Self {
                return .{
                    .teleporters = undefined,
                    .teleporter_count = 0,
                    .global_cooldown = timer.Cooldown.init(cooldown_duration),
                };
            }

            pub fn addTeleporter(self: *Self, teleporter: TeleporterData) !void {
                if (self.teleporter_count >= max_teleporters) return error.TeleporterManagerFull;
                self.teleporters[self.teleporter_count] = teleporter;
                self.teleporter_count += 1;
            }

            pub fn clear(self: *Self) void {
                self.teleporter_count = 0;
            }

            pub fn update(self: *Self, delta_time: f32) void {
                self.global_cooldown.update(delta_time);
            }

            /// Check if player can use any teleporter at current position
            pub fn checkTeleporterCollision(self: *Self, player_pos: Vec2, player_radius: f32) ?TeleporterResult {
                // Check global cooldown first
                if (!self.global_cooldown.isReady()) {
                    return TeleporterResult.blocked(.cooldown_active);
                }

                // Check each teleporter for collision
                for (self.teleporters[0..self.teleporter_count]) |*teleporter| {
                    if (!teleporter.config.requires_collision) continue;

                    // Simple circle-circle collision
                    const distance_sq = player_pos.sub(teleporter.position).lengthSquared();
                    const collision_radius = player_radius + teleporter.radius;

                    if (distance_sq <= collision_radius * collision_radius) {
                        // Collision detected - activate teleporter if auto-activate is enabled
                        if (teleporter.config.auto_activate) {
                            self.global_cooldown.start();
                            return TeleporterResult.success(teleporter.destination);
                        }
                    }
                }

                return null;
            }

            /// Manually activate a specific teleporter (for click-to-use mechanics)
            pub fn activateTeleporter(self: *Self, teleporter_index: usize) ?TeleporterResult {
                if (teleporter_index >= self.teleporter_count) return TeleporterResult.blocked(.invalid_destination);
                if (!self.global_cooldown.isReady()) return TeleporterResult.blocked(.cooldown_active);

                const teleporter = &self.teleporters[teleporter_index];
                self.global_cooldown.start();
                return TeleporterResult.success(teleporter.destination);
            }

            pub fn isCooldownActive(self: *const Self) bool {
                return !self.global_cooldown.isReady();
            }

            pub fn getCooldownRemaining(self: *const Self) f32 {
                return self.global_cooldown.getRemaining();
            }
        };
    }
};
