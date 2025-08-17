const std = @import("std");
const math = @import("../../math/mod.zig");
const colors = @import("../../core/colors.zig");

const Vec2 = math.Vec2;
const Color = colors.Color;

/// Generic zone interface that games can implement
pub fn ZoneManager(comptime ZoneType: type, comptime max_zones: usize) type {
    return struct {
        const Self = @This();
        
        zones: [max_zones]ZoneType,
        current_zone_index: usize,
        
        pub fn init() Self {
            return .{
                .zones = undefined, // Game must initialize zones
                .current_zone_index = 0,
            };
        }
        
        pub fn getCurrentZone(self: *Self) *ZoneType {
            return &self.zones[self.current_zone_index];
        }
        
        pub fn getCurrentZoneConst(self: *const Self) *const ZoneType {
            return &self.zones[self.current_zone_index];
        }
        
        pub fn getZone(self: *Self, index: usize) *ZoneType {
            if (index >= max_zones) @panic("Zone index out of bounds");
            return &self.zones[index];
        }
        
        pub fn getZoneConst(self: *const Self, index: usize) *const ZoneType {
            if (index >= max_zones) @panic("Zone index out of bounds");
            return &self.zones[index];
        }
        
        pub fn travelToZone(self: *Self, zone_index: usize, _: Vec2) !void {
            if (zone_index >= max_zones) return error.InvalidZoneIndex;
            self.current_zone_index = zone_index;
            
            // Game-specific zone entry logic should be implemented by caller
        }
        
        pub fn getCurrentZoneIndex(self: *const Self) usize {
            return self.current_zone_index;
        }
        
        pub fn getZoneCount(_: *const Self) usize {
            return max_zones;
        }
    };
}

/// Common zone metadata interface
pub const ZoneMetadata = struct {
    spawn_pos: Vec2,
    background_color: Color,
    camera_scale: f32,
    
    pub fn init(spawn_pos: Vec2, background_color: Color, camera_scale: f32) ZoneMetadata {
        return .{
            .spawn_pos = spawn_pos,
            .background_color = background_color,
            .camera_scale = camera_scale,
        };
    }
};

/// Zone travel result for feedback to game systems
pub const ZoneTravelResult = struct {
    success: bool,
    previous_zone: usize,
    new_zone: usize,
    spawn_pos: Vec2,
    
    pub fn createSuccess(prev_zone: usize, new_zone: usize, spawn_pos: Vec2) ZoneTravelResult {
        return .{
            .success = true,
            .previous_zone = prev_zone,
            .new_zone = new_zone,
            .spawn_pos = spawn_pos,
        };
    }
    
    pub fn createFailure(prev_zone: usize, attempted_zone: usize) ZoneTravelResult {
        return .{
            .success = false,
            .previous_zone = prev_zone,
            .new_zone = attempted_zone,
            .spawn_pos = Vec2.ZERO,
        };
    }
};

/// Camera mode enum for zones
pub const CameraMode = enum {
    fixed,    // Camera stays in fixed position (overworld)
    follow,   // Camera follows player (dungeons)
    manual,   // Manual camera control
};

/// Generic zone configuration interface
pub fn ZoneConfig(comptime ZoneTypeEnum: type) type {
    return struct {
        zone_type: ZoneTypeEnum,
        camera_mode: CameraMode,
        metadata: ZoneMetadata,
        
        pub fn init(zone_type: ZoneTypeEnum, camera_mode: CameraMode, metadata: ZoneMetadata) @This() {
            return .{
                .zone_type = zone_type,
                .camera_mode = camera_mode,
                .metadata = metadata,
            };
        }
    };
}

test "zone manager basic operations" {
    const TestZone = struct {
        value: i32,
        
        pub fn init(value: i32) @This() {
            return .{ .value = value };
        }
    };
    
    var manager = ZoneManager(TestZone, 3).init();
    manager.zones[0] = TestZone.init(10);
    manager.zones[1] = TestZone.init(20);
    manager.zones[2] = TestZone.init(30);
    
    try std.testing.expect(manager.getCurrentZone().value == 10);
    try manager.travelToZone(1, Vec2.ZERO);
    try std.testing.expect(manager.getCurrentZone().value == 20);
    try std.testing.expect(manager.getCurrentZoneIndex() == 1);
}