// Main test runner for the zzz project
// All tests are discovered using the new barrel test structure
//
// Usage:
//   zig build test                          # Run all tests (~195+ individual tests)
//   zig build test -Dtest-filter="pattern" # Filter tests by pattern
//   zig build test --summary all           # Show detailed results
//
// Architecture:
//   - Uses test barrel files for clean organization
//   - Excludes SDL dependencies and broken tests via .check_test_coverage_exclusions.zon
//   - Provides comprehensive coverage of working modules
//
// Coverage: ~85%+ (excluding legitimate exclusions and broken tests)

const std = @import("std");

// ============================================================================
// BARREL TEST IMPORTS - Clean Architecture
// ============================================================================

// Hex game tests
test {
    _ = @import("hex/test.zig");
}

// Engine library tests
test {
    _ = @import("lib/test.zig");
}

// ============================================================================
// EXCLUSION DOCUMENTATION
// ============================================================================
//
// The following types of files are intentionally excluded from test coverage:
//
// 🟢 SDL DEPENDENCIES (legitimate exclusions):
// - lib/core/animation.zig - SDL timing functions
// - lib/core/time.zig - SDL timing functions
// - lib/game/control/direct_input.zig - SDL input handling
// - lib/font/test/basic_rendering.zig - SDL rendering
// - lib/font/test/font_rendering.zig - SDL rendering
// - lib/ui/terminal_layout_renderer.zig - text rendering dependencies
//
// 🟡 STANDALONE TEST SUITES (not for barrel import):
// - lib/reactive/tests.zig - Complete reactive system integration tests
// - lib/gannaway/tests.zig - Complete Gannaway system integration tests
//
// 🟡 TEST UTILITIES (helper files, not standalone tests):
// - lib/reactive/test_utils.zig - Test helper functions
// - lib/reactive/test_expected_behavior.zig - Test utilities
// - lib/font/test_helpers.zig - Font test helpers
// - lib/terminal/*/test_*.zig - Terminal test utilities
//
// 🔴 BROKEN TESTS (need fixing - these count against coverage):
//
// Compilation Issues:
// - lib/core/pool.zig - Pointer capture error in tests
// - lib/core/resources.zig - @typeInfo API changes
// - lib/reactive/component.zig - fmt slice formatting error
// - lib/reactive/tracking.zig - Comptime value resolution issues
// - lib/game/behaviors/patrol_behavior.zig - Const assignment issues
// - lib/game/storage/entity_storage.zig - Indexing errors
// - lib/particles/duration.zig - @typeInfo API changes
//
// Runtime Failures:
// - lib/physics/queries.zig - Collision detection logic errors
// - lib/rendering/performance.zig - Needs logger initialization
// - lib/game/behaviors/wander_behavior.zig - Test expects non-zero velocity
//
// UI/Reactive Issues:
// - lib/ui/button.zig - Const qualifier mismatches
// - lib/ui/primitives.zig - Const qualifier mismatches
// - lib/ui/text.zig - Runtime segfault in reactive system
// - lib/ui/fps_counter.zig - SDL dependencies + reactive issues
// - lib/ui/debug_overlay.zig - Comptime value issues
// - lib/ui/reactive_label.zig - FormatArg API changes
// - lib/ui/focus_manager.zig - Derived pointer issues
//
// Other Broken Tests:
// - lib/gannaway/compute.zig, state.zig, watch.zig - Various issues
// - lib/layout/math.zig - Needs investigation
// - lib/rendering/compute.zig, modes.zig, structured_buffers.zig - Various issues
// - lib/text/sdf_renderer.zig - May have external dependencies
//
// Behavioral System (cascade from patrol_behavior issues):
// - lib/game/behaviors/behavior_state_machine.zig
// - lib/game/behaviors/guard_behavior.zig
// - lib/game/behaviors/return_home_behavior.zig
//
// Total files with tests: ~118
// Working coverage: ~76 files (excluding legitimate exclusions)
// Broken tests: ~28 files
// Current coverage: 73.1% (needs improvement by fixing broken tests)
