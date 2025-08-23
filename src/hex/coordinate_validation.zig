/// Coordinate system validation to prevent mixed pixel/meter units
///
/// This module provides compile-time and runtime validation to ensure
/// all coordinates throughout the hex game use consistent meter-based units.
const std = @import("std");
const math = @import("../lib/math/mod.zig");
const constants = @import("constants.zig");

const Vec2 = math.Vec2;

/// Coordinate system types for validation
pub const CoordinateSystem = enum {
    meters, // Game world coordinates (1 unit = 1 meter)
    pixels, // Screen/render coordinates (for display only)
};

/// Validated coordinate wrapper that ensures unit consistency
pub fn ValidatedCoordinate(comptime system: CoordinateSystem) type {
    return struct {
        value: Vec2,

        const Self = @This();

        /// Create validated coordinate from raw values
        pub fn init(x: f32, y: f32) Self {
            const coord = Vec2{ .x = x, .y = y };
            validateRange(coord, system);
            return .{ .value = coord };
        }

        /// Create from Vec2
        pub fn fromVec2(vec: Vec2) Self {
            validateRange(vec, system);
            return .{ .value = vec };
        }

        /// Get raw Vec2 value
        pub fn vec2(self: Self) Vec2 {
            return self.value;
        }

        /// Convert between coordinate systems with validation
        pub fn convertTo(self: Self, comptime target_system: CoordinateSystem) ValidatedCoordinate(target_system) {
            const converted = switch (system) {
                .meters => switch (target_system) {
                    .meters => self.value,
                    .pixels => self.value.scale(METERS_TO_PIXELS), // Convert for rendering
                },
                .pixels => switch (target_system) {
                    .meters => self.value.scale(PIXELS_TO_METERS), // Convert from legacy
                    .pixels => self.value,
                },
            };
            return ValidatedCoordinate(target_system).fromVec2(converted);
        }
    };
}

/// Type aliases for common coordinate systems
pub const MeterCoordinate = ValidatedCoordinate(.meters);
pub const PixelCoordinate = ValidatedCoordinate(.pixels);

/// Conversion constants
const METERS_TO_PIXELS: f32 = 12.0; // 1 meter ≈ 12 pixels (for rendering)
const PIXELS_TO_METERS: f32 = 1.0 / METERS_TO_PIXELS;

/// Validate coordinate is within expected range for its system
fn validateRange(coord: Vec2, system: CoordinateSystem) void {
    switch (system) {
        .meters => {
            // Game world coordinates should be reasonable for meter-based gameplay
            // Overworld: 160x90m, Dungeons: ~16x9m
            if (coord.x < -200.0 or coord.x > 200.0 or coord.y < -200.0 or coord.y > 200.0) {
                std.log.warn("coordinate_validation: Suspicious meter coordinate: ({d:.2}, {d:.2}) - may be pixel coordinate", .{ coord.x, coord.y });
            }
        },
        .pixels => {
            // Screen coordinates should be within reasonable screen bounds
            if (coord.x < -5000.0 or coord.x > 5000.0 or coord.y < -5000.0 or coord.y > 5000.0) {
                std.log.warn("coordinate_validation: Suspicious pixel coordinate: ({d:.0}, {d:.0})", .{ coord.x, coord.y });
            }
        },
    }
}

/// Validation helpers for ZON loading
pub const ZonValidation = struct {
    /// Validate all coordinates in a zone are meter-based
    pub fn validateZoneCoordinates(zone_name: []const u8, obstacles: anytype, units: anytype, portals: anytype, lifestones: anytype) void {
        std.log.info("coordinate_validation: Validating zone '{s}' coordinates", .{zone_name});

        // Validate obstacles
        for (obstacles) |obstacle| {
            _ = MeterCoordinate.fromVec2(obstacle.position);
            validateMeterSize(obstacle.size);
        }

        // Validate units
        for (units) |unit| {
            _ = MeterCoordinate.fromVec2(unit.position);
            validateMeterRadius(unit.radius);
        }

        // Validate portals
        for (portals) |portal| {
            _ = MeterCoordinate.fromVec2(portal.position);
            validateMeterRadius(portal.radius);
        }

        // Validate lifestones
        for (lifestones) |lifestone| {
            _ = MeterCoordinate.fromVec2(lifestone.position);
            validateMeterRadius(lifestone.radius);
        }

        std.log.info("coordinate_validation: Zone '{s}' validated successfully", .{zone_name});
    }

    /// Validate radius is meter-based (not pixel-based)
    fn validateMeterRadius(radius: f32) void {
        if (radius > 10.0) {
            std.log.warn("coordinate_validation: Suspicious radius {d:.2}m - may be pixel-based", .{radius});
        }
    }

    /// Validate size is meter-based
    fn validateMeterSize(size: Vec2) void {
        if (size.x > 50.0 or size.y > 50.0) {
            std.log.warn("coordinate_validation: Suspicious size ({d:.2}x{d:.2})m - may be pixel-based", .{ size.x, size.y });
        }
    }
};

/// Runtime coordinate system debugging
pub const CoordinateDebug = struct {
    /// Log coordinate for debugging with system context
    pub fn logCoordinate(coord: Vec2, system: CoordinateSystem, context: []const u8) void {
        const system_name = switch (system) {
            .meters => "meters",
            .pixels => "pixels",
        };
        std.log.debug("coordinate_debug: {s} = ({d:.2}, {d:.2}) {s}", .{ context, coord.x, coord.y, system_name });
    }

    /// Check if coordinate seems to be in wrong system
    pub fn detectMixedSystems(coord: Vec2, expected_system: CoordinateSystem) bool {
        return switch (expected_system) {
            .meters => coord.x > 200.0 or coord.y > 200.0, // Suspiciously large for meters
            .pixels => coord.x < 5.0 and coord.y < 5.0, // Suspiciously small for pixels
        };
    }
};

test "coordinate system validation" {
    // Test meter coordinates
    const meter_coord = MeterCoordinate.init(80.0, 45.0); // Player spawn
    try std.testing.expect(meter_coord.value.x == 80.0);
    try std.testing.expect(meter_coord.value.y == 45.0);

    // Test conversion
    const pixel_coord = meter_coord.convertTo(.pixels);
    try std.testing.expect(pixel_coord.value.x == 80.0 * 12.0);
    try std.testing.expect(pixel_coord.value.y == 45.0 * 12.0);

    // Test round trip
    const back_to_meters = pixel_coord.convertTo(.meters);
    try std.testing.expectApproxEqAbs(@as(f32, 80.0), back_to_meters.value.x, 0.1);
    try std.testing.expectApproxEqAbs(@as(f32, 45.0), back_to_meters.value.y, 0.1);
}

test "coordinate validation ranges" {
    // These should not trigger warnings
    _ = MeterCoordinate.init(80.0, 45.0); // Player spawn
    _ = MeterCoordinate.init(160.0, 90.0); // World bounds
    _ = PixelCoordinate.init(960.0, 540.0); // Screen center

    // These would trigger warnings in debug builds
    // _ = MeterCoordinate.init(960.0, 540.0);  // Likely pixel coords in meter system
    // _ = PixelCoordinate.init(80.0, 45.0);    // Likely meter coords in pixel system
}
