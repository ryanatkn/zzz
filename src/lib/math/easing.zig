const std = @import("std");
const math = std.math;

/// Comprehensive easing functions for animations
/// All functions take parameter t in range [0.0, 1.0] and return eased value
pub const Easing = struct {

    // ========================
    // Linear
    // ========================

    /// Linear interpolation (no easing)
    pub fn linear(t: f32) f32 {
        return @max(0.0, @min(1.0, t));
    }

    // ========================
    // Quadratic Easing
    // ========================

    /// Quadratic ease-in (accelerating from zero velocity)
    pub fn quadraticEaseIn(t: f32) f32 {
        const clamped = @max(0.0, @min(1.0, t));
        return clamped * clamped;
    }

    /// Quadratic ease-out (decelerating to zero velocity)
    pub fn quadraticEaseOut(t: f32) f32 {
        const clamped = @max(0.0, @min(1.0, t));
        return 1.0 - (1.0 - clamped) * (1.0 - clamped);
    }

    /// Quadratic ease-in-out
    pub fn quadraticEaseInOut(t: f32) f32 {
        const clamped = @max(0.0, @min(1.0, t));
        if (clamped < 0.5) {
            return 2.0 * clamped * clamped;
        } else {
            const shifted = clamped - 1.0;
            return 1.0 - 2.0 * shifted * shifted;
        }
    }

    // ========================
    // Cubic Easing
    // ========================

    /// Cubic ease-in
    pub fn cubicEaseIn(t: f32) f32 {
        const clamped = @max(0.0, @min(1.0, t));
        return clamped * clamped * clamped;
    }

    /// Cubic ease-out
    pub fn cubicEaseOut(t: f32) f32 {
        const clamped = @max(0.0, @min(1.0, t));
        const inv = 1.0 - clamped;
        return 1.0 - inv * inv * inv;
    }

    /// Cubic ease-in-out (from animated_borders.zig)
    pub fn cubicEaseInOut(t: f32) f32 {
        const clamped = @max(0.0, @min(1.0, t));
        if (clamped < 0.5) {
            return 4.0 * clamped * clamped * clamped;
        } else {
            const shifted = clamped - 1.0;
            return 1.0 + 4.0 * shifted * shifted * shifted;
        }
    }

    // ========================
    // Quartic Easing
    // ========================

    /// Quartic ease-in
    pub fn quarticEaseIn(t: f32) f32 {
        const clamped = @max(0.0, @min(1.0, t));
        return clamped * clamped * clamped * clamped;
    }

    /// Quartic ease-out (from animated_borders.zig)
    pub fn quarticEaseOut(t: f32) f32 {
        const clamped = @max(0.0, @min(1.0, t));
        const inv = 1.0 - clamped;
        return 1.0 - inv * inv * inv * inv;
    }

    /// Quartic ease-in-out
    pub fn quarticEaseInOut(t: f32) f32 {
        const clamped = @max(0.0, @min(1.0, t));
        if (clamped < 0.5) {
            return 8.0 * clamped * clamped * clamped * clamped;
        } else {
            const shifted = clamped - 1.0;
            return 1.0 - 8.0 * shifted * shifted * shifted * shifted;
        }
    }

    // ========================
    // Quintic Easing
    // ========================

    /// Quintic ease-in
    pub fn quinticEaseIn(t: f32) f32 {
        const clamped = @max(0.0, @min(1.0, t));
        return clamped * clamped * clamped * clamped * clamped;
    }

    /// Quintic ease-out
    pub fn quinticEaseOut(t: f32) f32 {
        const clamped = @max(0.0, @min(1.0, t));
        const inv = 1.0 - clamped;
        return 1.0 - inv * inv * inv * inv * inv;
    }

    /// Quintic ease-in-out
    pub fn quinticEaseInOut(t: f32) f32 {
        const clamped = @max(0.0, @min(1.0, t));
        if (clamped < 0.5) {
            return 16.0 * clamped * clamped * clamped * clamped * clamped;
        } else {
            const shifted = clamped - 1.0;
            return 1.0 - 16.0 * shifted * shifted * shifted * shifted * shifted;
        }
    }

    // ========================
    // Sine Easing
    // ========================

    /// Sine ease-in
    pub fn sineEaseIn(t: f32) f32 {
        const clamped = @max(0.0, @min(1.0, t));
        return 1.0 - math.cos(clamped * math.pi / 2.0);
    }

    /// Sine ease-out
    pub fn sineEaseOut(t: f32) f32 {
        const clamped = @max(0.0, @min(1.0, t));
        return math.sin(clamped * math.pi / 2.0);
    }

    /// Sine ease-in-out (from animated_borders.zig)
    pub fn sineEaseInOut(t: f32) f32 {
        const clamped = @max(0.0, @min(1.0, t));
        return 0.5 * (1.0 - math.cos(clamped * math.pi));
    }

    // ========================
    // Circular Easing
    // ========================

    /// Circular ease-in
    pub fn circularEaseIn(t: f32) f32 {
        const clamped = @max(0.0, @min(1.0, t));
        return 1.0 - math.sqrt(1.0 - clamped * clamped);
    }

    /// Circular ease-out
    pub fn circularEaseOut(t: f32) f32 {
        const clamped = @max(0.0, @min(1.0, t));
        const shifted = clamped - 1.0;
        return math.sqrt(1.0 - shifted * shifted);
    }

    /// Circular ease-in-out
    pub fn circularEaseInOut(t: f32) f32 {
        const clamped = @max(0.0, @min(1.0, t));
        if (clamped < 0.5) {
            return 0.5 * (1.0 - math.sqrt(1.0 - 4.0 * clamped * clamped));
        } else {
            const shifted = 2.0 * clamped - 2.0;
            return 0.5 * (math.sqrt(1.0 - shifted * shifted) + 1.0);
        }
    }

    // ========================
    // Exponential Easing
    // ========================

    /// Exponential ease-in
    pub fn exponentialEaseIn(t: f32) f32 {
        const clamped = @max(0.0, @min(1.0, t));
        return if (clamped == 0.0) 0.0 else math.pow(f32, 2.0, 10.0 * (clamped - 1.0));
    }

    /// Exponential ease-out
    pub fn exponentialEaseOut(t: f32) f32 {
        const clamped = @max(0.0, @min(1.0, t));
        return if (clamped == 1.0) 1.0 else 1.0 - math.pow(f32, 2.0, -10.0 * clamped);
    }

    /// Exponential ease-in-out
    pub fn exponentialEaseInOut(t: f32) f32 {
        const clamped = @max(0.0, @min(1.0, t));
        if (clamped == 0.0) return 0.0;
        if (clamped == 1.0) return 1.0;

        if (clamped < 0.5) {
            return 0.5 * math.pow(f32, 2.0, 20.0 * clamped - 10.0);
        } else {
            return 0.5 * (2.0 - math.pow(f32, 2.0, -20.0 * clamped + 10.0));
        }
    }

    // ========================
    // Back Easing (overshoot)
    // ========================

    const BACK_CONSTANT = 1.70158;

    /// Back ease-in (slight pullback before moving forward)
    pub fn backEaseIn(t: f32) f32 {
        const clamped = @max(0.0, @min(1.0, t));
        const c = BACK_CONSTANT + 1.0;
        return c * clamped * clamped * clamped - BACK_CONSTANT * clamped * clamped;
    }

    /// Back ease-out (overshoot then settle)
    pub fn backEaseOut(t: f32) f32 {
        const clamped = @max(0.0, @min(1.0, t));
        const c = BACK_CONSTANT + 1.0;
        const shifted = clamped - 1.0;
        return 1.0 + c * shifted * shifted * shifted + BACK_CONSTANT * shifted * shifted;
    }

    /// Back ease-in-out
    pub fn backEaseInOut(t: f32) f32 {
        const clamped = @max(0.0, @min(1.0, t));
        const c = (BACK_CONSTANT + 1.0) * 1.525;

        if (clamped < 0.5) {
            const doubled = 2.0 * clamped;
            return 0.5 * doubled * doubled * (c * doubled - (c - 1.0));
        } else {
            const shifted = 2.0 * clamped - 2.0;
            return 0.5 * (shifted * shifted * (c * shifted + (c - 1.0)) + 2.0);
        }
    }

    // ========================
    // Elastic Easing (spring effect)
    // ========================

    /// Elastic ease-in
    pub fn elasticEaseIn(t: f32) f32 {
        const clamped = @max(0.0, @min(1.0, t));
        if (clamped == 0.0) return 0.0;
        if (clamped == 1.0) return 1.0;

        const c = (2.0 * math.pi) / 3.0;
        return -math.pow(f32, 2.0, 10.0 * clamped - 10.0) * math.sin((clamped * 10.0 - 10.75) * c);
    }

    /// Elastic ease-out
    pub fn elasticEaseOut(t: f32) f32 {
        const clamped = @max(0.0, @min(1.0, t));
        if (clamped == 0.0) return 0.0;
        if (clamped == 1.0) return 1.0;

        const c = (2.0 * math.pi) / 3.0;
        return math.pow(f32, 2.0, -10.0 * clamped) * math.sin((clamped * 10.0 - 0.75) * c) + 1.0;
    }

    /// Elastic ease-in-out
    pub fn elasticEaseInOut(t: f32) f32 {
        const clamped = @max(0.0, @min(1.0, t));
        if (clamped == 0.0) return 0.0;
        if (clamped == 1.0) return 1.0;

        const c = (2.0 * math.pi) / 4.5;

        if (clamped < 0.5) {
            return -0.5 * math.pow(f32, 2.0, 20.0 * clamped - 10.0) * math.sin((20.0 * clamped - 11.125) * c);
        } else {
            return 0.5 * math.pow(f32, 2.0, -20.0 * clamped + 10.0) * math.sin((20.0 * clamped - 11.125) * c) + 1.0;
        }
    }

    // ========================
    // Bounce Easing
    // ========================

    /// Bounce ease-out (bouncing effect at the end)
    pub fn bounceEaseOut(t: f32) f32 {
        const clamped = @max(0.0, @min(1.0, t));
        const n1 = 7.5625;
        const d1 = 2.75;

        if (clamped < 1.0 / d1) {
            return n1 * clamped * clamped;
        } else if (clamped < 2.0 / d1) {
            const shifted = clamped - 1.5 / d1;
            return n1 * shifted * shifted + 0.75;
        } else if (clamped < 2.5 / d1) {
            const shifted = clamped - 2.25 / d1;
            return n1 * shifted * shifted + 0.9375;
        } else {
            const shifted = clamped - 2.625 / d1;
            return n1 * shifted * shifted + 0.984375;
        }
    }

    /// Bounce ease-in
    pub fn bounceEaseIn(t: f32) f32 {
        const clamped = @max(0.0, @min(1.0, t));
        return 1.0 - bounceEaseOut(1.0 - clamped);
    }

    /// Bounce ease-in-out
    pub fn bounceEaseInOut(t: f32) f32 {
        const clamped = @max(0.0, @min(1.0, t));
        if (clamped < 0.5) {
            return 0.5 * (1.0 - bounceEaseOut(1.0 - 2.0 * clamped));
        } else {
            return 0.5 * (1.0 + bounceEaseOut(2.0 * clamped - 1.0));
        }
    }
};

/// Easing function type for generic use
pub const EasingFunction = fn (f32) f32;

/// Apply easing function to interpolate between two values
pub fn applyEasing(easing_fn: EasingFunction, start: f32, end: f32, t: f32) f32 {
    const eased_t = easing_fn(t);
    return start + (end - start) * eased_t;
}

/// Apply easing with custom range for t parameter
pub fn applyEasingRange(easing_fn: EasingFunction, start: f32, end: f32, t: f32, t_min: f32, t_max: f32) f32 {
    const normalized_t = (t - t_min) / (t_max - t_min);
    return applyEasing(easing_fn, start, end, normalized_t);
}

test "easing functions basic properties" {
    // Test that all easing functions return 0.0 at t=0.0 and 1.0 at t=1.0
    const functions = [_]EasingFunction{
        Easing.linear,
        Easing.quadraticEaseIn,
        Easing.quadraticEaseOut,
        Easing.quadraticEaseInOut,
        Easing.cubicEaseIn,
        Easing.cubicEaseOut,
        Easing.cubicEaseInOut,
        Easing.quarticEaseIn,
        Easing.quarticEaseOut,
        Easing.quarticEaseInOut,
        Easing.sineEaseIn,
        Easing.sineEaseOut,
        Easing.sineEaseInOut,
        Easing.circularEaseIn,
        Easing.circularEaseOut,
        Easing.circularEaseInOut,
        Easing.bounceEaseIn,
        Easing.bounceEaseOut,
        Easing.bounceEaseInOut,
    };

    for (functions) |func| {
        const start_value = func(0.0);
        const end_value = func(1.0);

        try std.testing.expectApproxEqAbs(@as(f32, 0.0), start_value, 0.001);
        try std.testing.expectApproxEqAbs(@as(f32, 1.0), end_value, 0.001);
    }
}

test "easing functions are monotonic (mostly)" {
    // Test that easing functions generally increase (with some exceptions for back/elastic)
    const monotonic_functions = [_]EasingFunction{
        Easing.linear,
        Easing.quadraticEaseIn,
        Easing.quadraticEaseOut,
        Easing.cubicEaseIn,
        Easing.cubicEaseOut,
        Easing.sineEaseIn,
        Easing.sineEaseOut,
        Easing.sineEaseInOut,
    };

    for (monotonic_functions) |func| {
        var prev = func(0.0);
        var t: f32 = 0.1;
        while (t <= 1.0) : (t += 0.1) {
            const current = func(t);
            try std.testing.expect(current >= prev);
            prev = current;
        }
    }
}

test "applyEasing function" {
    const result = applyEasing(Easing.linear, 10.0, 20.0, 0.5);
    try std.testing.expectApproxEqAbs(@as(f32, 15.0), result, 0.001);

    const quad_result = applyEasing(Easing.quadraticEaseIn, 0.0, 100.0, 0.5);
    try std.testing.expectApproxEqAbs(@as(f32, 25.0), quad_result, 0.001); // 0.5^2 * 100 = 25
}
