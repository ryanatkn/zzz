const std = @import("std");
const EntityId = @import("entity.zig").EntityId;
const World = @import("world.zig").World;
const Zone = @import("zone.zig").Zone;
const components = @import("components.zig");

/// Portal system for zone transitions
pub const PortalSystem = struct {
    cooldown: f32,
    cooldown_duration: f32,
    allocator: std.mem.Allocator,

    /// Portal activation callback
    pub const ActivationCallback = *const fn (
        portal_entity: EntityId,
        traveler_entity: EntityId,
        destination_zone: u8,
        context: ?*anyopaque,
    ) anyerror!void;

    pub fn init(allocator: std.mem.Allocator, cooldown_duration: f32) PortalSystem {
        return .{
            .cooldown = 0,
            .cooldown_duration = cooldown_duration,
            .allocator = allocator,
        };
    }

    /// Update portal cooldown
    pub fn update(self: *PortalSystem, delta_time: f32) void {
        if (self.cooldown > 0) {
            self.cooldown = @max(0, self.cooldown - delta_time);
        }
    }

    /// Check if portal activation is allowed
    pub fn canActivate(self: *const PortalSystem) bool {
        return self.cooldown <= 0;
    }

    /// Activate a portal
    pub fn activate(self: *PortalSystem) void {
        self.cooldown = self.cooldown_duration;
    }

    /// Check portal collisions for an entity
    pub fn checkPortalCollisions(
        self: *PortalSystem,
        zone: *const Zone,
        entity: EntityId,
        entity_pos: components.Vec2,
        entity_radius: f32,
        callback: ActivationCallback,
        context: ?*anyopaque,
    ) !bool {
        // Skip if on cooldown
        if (!self.canActivate()) {
            return false;
        }

        // Iterate through all portals in the zone
        var portal_iter = @constCast(&zone.world.portals).entityIterator();
        while (portal_iter.next()) |portal_id| {
            // Get portal components
            const portal_transform = zone.world.portals.getComponent(portal_id, .transform) orelse continue;
            const portal_interactable = zone.world.portals.getComponent(portal_id, .interactable) orelse continue;
            
            // Check if portal has a destination
            const destination_zone = portal_interactable.destination_zone orelse continue;

            // Check collision
            if (checkCircleCollision(
                entity_pos,
                entity_radius,
                portal_transform.pos,
                portal_transform.radius,
            )) {
                // Portal collision detected!
                self.activate();
                
                // Call the activation callback
                try callback(portal_id, entity, destination_zone, context);
                
                return true;
            }
        }

        return false;
    }

    /// Helper function for circle collision
    fn checkCircleCollision(
        pos1: components.Vec2,
        radius1: f32,
        pos2: components.Vec2,
        radius2: f32,
    ) bool {
        const dx = pos1.x - pos2.x;
        const dy = pos1.y - pos2.y;
        const distance_squared = dx * dx + dy * dy;
        const combined_radius = radius1 + radius2;
        return distance_squared <= combined_radius * combined_radius;
    }
};

/// Portal collision result
pub const PortalCollision = struct {
    portal_entity: EntityId,
    destination_zone: u8,
    portal_pos: components.Vec2,
};

/// Find all portal collisions for an entity (without activation)
pub fn findPortalCollisions(
    zone: *const Zone,
    entity_pos: components.Vec2,
    entity_radius: f32,
    allocator: std.mem.Allocator,
) !std.ArrayList(PortalCollision) {
    var collisions = std.ArrayList(PortalCollision).init(allocator);
    errdefer collisions.deinit();

    var portal_iter = @constCast(&zone.world.portals).entityIterator();
    while (portal_iter.next()) |portal_id| {
        const portal_transform = zone.world.portals.getComponent(portal_id, .transform) orelse continue;
        const portal_interactable = zone.world.portals.getComponent(portal_id, .interactable) orelse continue;
        const destination_zone = portal_interactable.destination_zone orelse continue;

        if (PortalSystem.checkCircleCollision(
            entity_pos,
            entity_radius,
            portal_transform.pos,
            portal_transform.radius,
        )) {
            try collisions.append(.{
                .portal_entity = portal_id,
                .destination_zone = destination_zone,
                .portal_pos = portal_transform.pos,
            });
        }
    }

    return collisions;
}