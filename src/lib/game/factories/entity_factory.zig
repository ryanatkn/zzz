const std = @import("std");
const math = @import("../../math/mod.zig");
const colors = @import("../../core/colors.zig");
const components = @import("../components.zig");

const Vec2 = math.Vec2;
const Color = colors.Color;

/// Generic entity factory patterns for common entity creation
/// Games can use these patterns or extend them for game-specific entities
pub const EntityFactory = struct {
    /// Configuration for projectile creation
    pub const ProjectileConfig = struct {
        position: Vec2,
        radius: f32,
        velocity: Vec2,
        lifetime: f32,
        damage: f32,
        color: Color,
        
        pub fn bullet(position: Vec2, velocity: Vec2, damage: f32) ProjectileConfig {
            return .{
                .position = position,
                .radius = 3.0, // Small bullet
                .velocity = velocity,
                .lifetime = 4.0, // 4 second lifetime
                .damage = damage,
                .color = .{ .r = 255, .g = 255, .b = 0, .a = 255 }, // Yellow
            };
        }
        
        pub fn withCustom(position: Vec2, velocity: Vec2, radius: f32, lifetime: f32, damage: f32, color: Color) ProjectileConfig {
            return .{
                .position = position,
                .radius = radius,
                .velocity = velocity,
                .lifetime = lifetime,
                .damage = damage,
                .color = color,
            };
        }
    };
    
    /// Configuration for interactive entity creation (portals, lifestones, etc.)
    pub const InteractiveConfig = struct {
        position: Vec2,
        radius: f32,
        interaction_type: components.Interactable.InteractionType,
        color: Color,
        terrain_type: components.Terrain.TerrainType = .altar,
        destination_zone: ?usize = null,
        attuned: bool = false,
        
        pub fn portal(position: Vec2, radius: f32, destination_zone: usize, color: Color) InteractiveConfig {
            return .{
                .position = position,
                .radius = radius,
                .interaction_type = .transformable,
                .color = color,
                .terrain_type = .altar,
                .destination_zone = destination_zone,
                .attuned = false,
            };
        }
        
        pub fn lifestone(position: Vec2, radius: f32, color: Color) InteractiveConfig {
            return .{
                .position = position,
                .radius = radius,
                .interaction_type = .transformable, // Lifestones use transformable interaction
                .color = color,
                .terrain_type = .altar,
                .destination_zone = null,
                .attuned = false,
            };
        }
    };
    
    /// Configuration for player creation
    pub const PlayerConfig = struct {
        position: Vec2,
        radius: f32,
        health_max: f32,
        speed: f32,
        color: Color,
        
        pub fn defaultPlayer(position: Vec2, radius: f32) PlayerConfig {
            return .{
                .position = position,
                .radius = radius,
                .health_max = 100,
                .speed = 200.0, // Default player speed
                .color = .{ .r = 0, .g = 255, .b = 0, .a = 255 }, // Green
            };
        }
    };
    
    /// Configuration for unit creation
    pub const UnitConfig = struct {
        position: Vec2,
        radius: f32,
        health_max: f32,
        behavior_type: enum { idle, aggressive, defensive },
        color: Color,
        
        pub fn defaultUnit(position: Vec2, radius: f32) UnitConfig {
            return .{
                .position = position,
                .radius = radius,
                .health_max = 50,
                .behavior_type = .idle,
                .color = .{ .r = 255, .g = 100, .b = 100, .a = 255 }, // Red
            };
        }
    };
    
    /// Configuration for terrain/obstacle creation
    pub const TerrainConfig = struct {
        position: Vec2,
        size: Vec2,
        terrain_type: components.Terrain.TerrainType,
        color: Color,
        solid: bool = true,
        
        pub fn wall(position: Vec2, size: Vec2, color: Color) TerrainConfig {
            return .{
                .position = position,
                .size = size,
                .terrain_type = .wall,
                .color = color,
                .solid = true,
            };
        }
        
        pub fn pit(position: Vec2, size: Vec2, color: Color) TerrainConfig {
            return .{
                .position = position,
                .size = size,
                .terrain_type = .pit,
                .color = color,
                .solid = false, // Pits don't block movement, they kill
            };
        }
    };
    
    /// Component builders for consistent entity creation
    pub const ComponentBuilders = struct {
        /// Build player components from config
        pub fn buildPlayerComponents(config: PlayerConfig) struct {
            transform: components.Transform,
            health: components.Health,
            player_input: components.PlayerInput,
            visual: components.Visual,
            movement: components.Movement,
        } {
            return .{
                .transform = components.Transform.init(config.position, config.radius),
                .health = components.Health.init(config.health_max),
                .player_input = components.PlayerInput.init(0),
                .visual = components.Visual.init(config.color),
                .movement = components.Movement.init(config.speed),
            };
        }
        
        /// Build unit components from config (generic - games specify their unit type)
        pub fn buildBaseUnitComponents(config: UnitConfig) struct {
            transform: components.Transform,
            health: components.Health,
            visual: components.Visual,
        } {
            return .{
                .transform = components.Transform.init(config.position, config.radius),
                .health = components.Health.init(config.health_max),
                .visual = components.Visual.init(config.color),
            };
        }
        
        /// Build projectile components from config
        pub fn buildProjectileComponents(config: ProjectileConfig, entity_id: u32) struct {
            transform: components.Transform,
            projectile: components.Projectile,
            visual: components.Visual,
        } {
            var transform = components.Transform.init(config.position, config.radius);
            transform.vel = config.velocity;
            return .{
                .transform = transform,
                .projectile = components.Projectile.init(entity_id, config.lifetime),
                .visual = components.Visual.init(config.color),
            };
        }
        
        /// Build interactive entity components from config
        pub fn buildInteractiveComponents(config: InteractiveConfig) struct {
            transform: components.Transform,
            visual: components.Visual,
            terrain: components.Terrain,
            interactable: components.Interactable,
        } {
            var interactable = components.Interactable.init(config.interaction_type);
            interactable.destination_zone = config.destination_zone;
            interactable.attuned = config.attuned;
            
            return .{
                .transform = components.Transform.init(config.position, config.radius),
                .visual = components.Visual.init(config.color),
                .terrain = components.Terrain.init(config.terrain_type, Vec2{ .x = config.radius * 2, .y = config.radius * 2 }),
                .interactable = interactable,
            };
        }
        
        /// Build terrain/obstacle components from config
        pub fn buildTerrainComponents(config: TerrainConfig) struct {
            transform: components.Transform,
            terrain: components.Terrain,
            visual: components.Visual,
        } {
            var terrain = components.Terrain.init(config.terrain_type, config.size);
            terrain.solid = config.solid;
            
            return .{
                .transform = components.Transform.init(config.position, 0), // Terrain uses size, not radius
                .terrain = terrain,
                .visual = components.Visual.init(config.color),
            };
        }
    };
};