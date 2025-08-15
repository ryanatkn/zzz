const std = @import("std");
const components = @import("components.zig");

/// Component registry that defines all component types and their storage strategies
/// Provides comptime generation of storage and utility functions
pub const ComponentRegistry = struct {
    pub const ComponentType = enum {
        // Dense components (most entities have these)
        transform,
        health,
        movement,
        visual,

        // Sparse components (few entities have these)
        unit,
        combat,
        effects,
        player_input,
        projectile,
        terrain,
        awakeable,
        interactable,
    };

    pub const StorageStrategy = enum {
        dense,  // SOA storage for components most entities have
        sparse, // HashMap storage for components few entities have
    };

    pub const ComponentInfo = struct {
        type: type,
        strategy: StorageStrategy,
        name: []const u8,
    };

    /// Complete registry of all component types
    pub const COMPONENTS = std.EnumArray(ComponentType, ComponentInfo).init(.{
        .transform = .{ .type = components.Transform, .strategy = .dense, .name = "transform" },
        .health = .{ .type = components.Health, .strategy = .dense, .name = "health" },
        .movement = .{ .type = components.Movement, .strategy = .dense, .name = "movement" },
        .visual = .{ .type = components.Visual, .strategy = .dense, .name = "visual" },
        .unit = .{ .type = components.Unit, .strategy = .sparse, .name = "unit" },
        .combat = .{ .type = components.Combat, .strategy = .sparse, .name = "combat" },
        .effects = .{ .type = components.Effects, .strategy = .sparse, .name = "effects" },
        .player_input = .{ .type = components.PlayerInput, .strategy = .sparse, .name = "player_input" },
        .projectile = .{ .type = components.Projectile, .strategy = .sparse, .name = "projectile" },
        .terrain = .{ .type = components.Terrain, .strategy = .sparse, .name = "terrain" },
        .awakeable = .{ .type = components.Awakeable, .strategy = .sparse, .name = "awakeable" },
        .interactable = .{ .type = components.Interactable, .strategy = .sparse, .name = "interactable" },
    });

    /// Get component info by type
    pub fn getInfo(comptime component_type: ComponentType) ComponentInfo {
        return COMPONENTS.get(component_type);
    }

    /// Check if component should use dense storage
    pub fn isDense(comptime component_type: ComponentType) bool {
        return getInfo(component_type).strategy == .dense;
    }

    /// Get the component data type
    pub fn getType(comptime component_type: ComponentType) type {
        return getInfo(component_type).type;
    }

    /// Get all dense component types
    pub fn getDenseTypes() []const ComponentType {
        comptime {
            var dense_types: []const ComponentType = &.{};
            for (std.enums.values(ComponentType)) |component_type| {
                if (isDense(component_type)) {
                    dense_types = dense_types ++ &[_]ComponentType{component_type};
                }
            }
            return dense_types;
        }
    }

    /// Get all sparse component types
    pub fn getSparseTypes() []const ComponentType {
        comptime {
            var sparse_types: []const ComponentType = &.{};
            for (std.enums.values(ComponentType)) |component_type| {
                if (!isDense(component_type)) {
                    sparse_types = sparse_types ++ &[_]ComponentType{component_type};
                }
            }
            return sparse_types;
        }
    }
};

/// Archetype definitions for common entity patterns
pub const ArchetypeRegistry = struct {
    pub const ArchetypeType = enum {
        player,
        unit,
        projectile,
        obstacle,
        lifestone,
        portal,
    };

    pub const ArchetypeInfo = struct {
        required_components: []const ComponentRegistry.ComponentType,
        optional_components: []const ComponentRegistry.ComponentType,
        name: []const u8,
    };

    /// Complete registry of all archetype patterns
    pub const ARCHETYPES = std.EnumArray(ArchetypeType, ArchetypeInfo).init(.{
        .player = .{
            .required_components = &.{ .transform, .health, .movement, .visual, .player_input, .combat },
            .optional_components = &.{ .effects },
            .name = "player",
        },
        .unit = .{
            .required_components = &.{ .transform, .health, .visual, .unit },
            .optional_components = &.{ .movement, .combat, .effects },
            .name = "unit",
        },
        .projectile = .{
            .required_components = &.{ .transform, .visual, .projectile, .combat },
            .optional_components = &.{ .interactable },
            .name = "projectile",
        },
        .obstacle = .{
            .required_components = &.{ .transform, .visual, .terrain },
            .optional_components = &.{ .awakeable },
            .name = "obstacle",
        },
        .lifestone = .{
            .required_components = &.{ .transform, .visual, .terrain, .interactable },
            .optional_components = &.{},
            .name = "lifestone",
        },
        .portal = .{
            .required_components = &.{ .transform, .visual, .terrain, .interactable },
            .optional_components = &.{},
            .name = "portal",
        },
    });

    /// Get archetype info by type
    pub fn getInfo(comptime archetype_type: ArchetypeType) ArchetypeInfo {
        return ARCHETYPES.get(archetype_type);
    }

    /// Get all required component types for an archetype
    pub fn getRequiredComponents(comptime archetype_type: ArchetypeType) []const ComponentRegistry.ComponentType {
        return getInfo(archetype_type).required_components;
    }

    /// Get all optional component types for an archetype
    pub fn getOptionalComponents(comptime archetype_type: ArchetypeType) []const ComponentRegistry.ComponentType {
        return getInfo(archetype_type).optional_components;
    }

    /// Check if component is required for archetype
    pub fn isRequired(comptime archetype_type: ArchetypeType, comptime component_type: ComponentRegistry.ComponentType) bool {
        const required = getRequiredComponents(archetype_type);
        for (required) |req_component| {
            if (req_component == component_type) return true;
        }
        return false;
    }

    /// Check if component is optional for archetype
    pub fn isOptional(comptime archetype_type: ArchetypeType, comptime component_type: ComponentRegistry.ComponentType) bool {
        const optional = getOptionalComponents(archetype_type);
        for (optional) |opt_component| {
            if (opt_component == component_type) return true;
        }
        return false;
    }

    /// Check if component is part of archetype (required or optional)
    pub fn hasComponent(comptime archetype_type: ArchetypeType, comptime component_type: ComponentRegistry.ComponentType) bool {
        return isRequired(archetype_type, component_type) or isOptional(archetype_type, component_type);
    }
};

test "component registry basic operations" {
    // Test component type retrieval
    const transform_info = ComponentRegistry.getInfo(.transform);
    try std.testing.expect(transform_info.type == components.Transform);
    try std.testing.expect(transform_info.strategy == .dense);

    const unit_info = ComponentRegistry.getInfo(.unit);
    try std.testing.expect(unit_info.type == components.Unit);
    try std.testing.expect(unit_info.strategy == .sparse);

    // Test dense/sparse categorization
    try std.testing.expect(ComponentRegistry.isDense(.transform));
    try std.testing.expect(!ComponentRegistry.isDense(.unit));

    // Test type lists
    const dense_types = ComponentRegistry.getDenseTypes();
    const sparse_types = ComponentRegistry.getSparseTypes();
    try std.testing.expect(dense_types.len > 0);
    try std.testing.expect(sparse_types.len > 0);
    try std.testing.expect(dense_types.len + sparse_types.len == std.enums.values(ComponentRegistry.ComponentType).len);
}

test "archetype registry operations" {
    // Test player archetype
    const player_info = ArchetypeRegistry.getInfo(.player);
    try std.testing.expect(player_info.required_components.len > 0);

    // Test component membership
    try std.testing.expect(ArchetypeRegistry.isRequired(.player, .transform));
    try std.testing.expect(ArchetypeRegistry.isRequired(.player, .player_input));
    try std.testing.expect(!ArchetypeRegistry.isRequired(.player, .terrain));

    try std.testing.expect(ArchetypeRegistry.hasComponent(.player, .transform));
    try std.testing.expect(ArchetypeRegistry.hasComponent(.player, .effects)); // optional
    try std.testing.expect(!ArchetypeRegistry.hasComponent(.player, .terrain));

    // Test unit archetype
    try std.testing.expect(ArchetypeRegistry.isRequired(.unit, .unit));
    try std.testing.expect(ArchetypeRegistry.isOptional(.unit, .movement));
}