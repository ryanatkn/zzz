/// Layout algorithm selection and performance analysis utilities
const std = @import("std");

/// Layout algorithm selector
pub const LayoutAlgorithm = enum {
    block,
    flex,
    grid,
    absolute,
    relative,
    sticky,

    /// Get display name for algorithm
    pub fn displayName(self: LayoutAlgorithm) []const u8 {
        return switch (self) {
            .block => "Block Layout",
            .flex => "Flexbox Layout",
            .grid => "CSS Grid Layout",
            .absolute => "Absolute Positioning",
            .relative => "Relative Positioning",
            .sticky => "Sticky Positioning",
        };
    }

    /// Check if algorithm supports wrapping
    pub fn supportsWrapping(self: LayoutAlgorithm) bool {
        return switch (self) {
            .flex, .grid => true,
            .block, .absolute, .relative, .sticky => false,
        };
    }

    /// Check if algorithm is container-based
    pub fn isContainerBased(self: LayoutAlgorithm) bool {
        return switch (self) {
            .block, .flex, .grid => true,
            .absolute, .relative, .sticky => false,
        };
    }

    /// Get complexity rating (1-5, where 5 is most complex)
    pub fn getComplexity(self: LayoutAlgorithm) u8 {
        return switch (self) {
            .block => 2,
            .flex => 4,
            .grid => 5,
            .absolute => 3,
            .relative => 1,
            .sticky => 3,
        };
    }
};

/// Algorithm recommendation system
pub const AlgorithmRecommender = struct {
    /// Recommend layout algorithm based on requirements
    pub fn recommend(requirements: LayoutRequirements) LayoutAlgorithm {
        // If explicit positioning is needed
        if (requirements.needs_explicit_positioning) {
            if (requirements.needs_scroll_awareness) {
                return .sticky;
            } else if (requirements.needs_relative_positioning) {
                return .relative;
            } else {
                return .absolute;
            }
        }

        // If 2D grid layout is needed
        if (requirements.needs_2d_layout) {
            return .grid;
        }

        // If flexible 1D layout is needed
        if (requirements.needs_flexible_sizing or requirements.needs_space_distribution) {
            return .flex;
        }

        // Default to block layout
        return .block;
    }

    /// Layout requirements specification
    pub const LayoutRequirements = struct {
        /// Needs explicit positioning (absolute/relative/sticky)
        needs_explicit_positioning: bool = false,
        /// Needs relative positioning specifically
        needs_relative_positioning: bool = false,
        /// Needs scroll-aware positioning
        needs_scroll_awareness: bool = false,
        /// Needs 2D grid-like layout
        needs_2d_layout: bool = false,
        /// Needs flexible sizing (grow/shrink)
        needs_flexible_sizing: bool = false,
        /// Needs space distribution control
        needs_space_distribution: bool = false,
        /// Number of elements to layout
        element_count: usize = 0,
        /// Performance priority (1-5)
        performance_priority: u8 = 3,
    };
};

/// Performance characteristics of layout algorithms
pub const AlgorithmPerformance = struct {
    /// Time complexity
    time_complexity: Complexity,
    /// Space complexity
    space_complexity: Complexity,
    /// Typical performance for different element counts
    performance_profile: PerformanceProfile,

    pub const Complexity = enum {
        constant, // O(1)
        linear, // O(n)
        log_linear, // O(n log n)
        quadratic, // O(n²)
        exponential, // O(2^n)

        pub fn toString(self: Complexity) []const u8 {
            return switch (self) {
                .constant => "O(1)",
                .linear => "O(n)",
                .log_linear => "O(n log n)",
                .quadratic => "O(n²)",
                .exponential => "O(2^n)",
            };
        }
    };

    pub const PerformanceProfile = struct {
        /// Performance rating for small element counts (< 10)
        small_count_rating: u8, // 1-5 scale
        /// Performance rating for medium element counts (10-100)
        medium_count_rating: u8,
        /// Performance rating for large element counts (> 100)
        large_count_rating: u8,

        /// Get rating for given element count
        pub fn getRating(self: PerformanceProfile, element_count: usize) u8 {
            if (element_count < 10) {
                return self.small_count_rating;
            } else if (element_count < 100) {
                return self.medium_count_rating;
            } else {
                return self.large_count_rating;
            }
        }
    };

    /// Get performance characteristics for a layout algorithm
    pub fn getForAlgorithm(algorithm: LayoutAlgorithm) AlgorithmPerformance {
        return switch (algorithm) {
            .block => AlgorithmPerformance{
                .time_complexity = .linear,
                .space_complexity = .linear,
                .performance_profile = .{
                    .small_count_rating = 5,
                    .medium_count_rating = 5,
                    .large_count_rating = 4,
                },
            },
            .flex => AlgorithmPerformance{
                .time_complexity = .linear,
                .space_complexity = .linear,
                .performance_profile = .{
                    .small_count_rating = 4,
                    .medium_count_rating = 4,
                    .large_count_rating = 3,
                },
            },
            .grid => AlgorithmPerformance{
                .time_complexity = .quadratic, // Can be quadratic for complex grids
                .space_complexity = .linear,
                .performance_profile = .{
                    .small_count_rating = 3,
                    .medium_count_rating = 3,
                    .large_count_rating = 2,
                },
            },
            .absolute => AlgorithmPerformance{
                .time_complexity = .log_linear, // Due to z-index sorting
                .space_complexity = .linear,
                .performance_profile = .{
                    .small_count_rating = 5,
                    .medium_count_rating = 4,
                    .large_count_rating = 3,
                },
            },
            .relative => AlgorithmPerformance{
                .time_complexity = .linear,
                .space_complexity = .linear,
                .performance_profile = .{
                    .small_count_rating = 5,
                    .medium_count_rating = 5,
                    .large_count_rating = 5,
                },
            },
            .sticky => AlgorithmPerformance{
                .time_complexity = .linear,
                .space_complexity = .linear,
                .performance_profile = .{
                    .small_count_rating = 4,
                    .medium_count_rating = 4,
                    .large_count_rating = 4,
                },
            },
        };
    }
};

/// Layout algorithm comparison utility
pub const AlgorithmComparator = struct {
    /// Compare algorithms based on requirements
    pub fn compare(
        algorithm_a: LayoutAlgorithm,
        algorithm_b: LayoutAlgorithm,
        requirements: AlgorithmRecommender.LayoutRequirements,
    ) ComparisonResult {
        const perf_a = AlgorithmPerformance.getForAlgorithm(algorithm_a);
        const perf_b = AlgorithmPerformance.getForAlgorithm(algorithm_b);

        const rating_a = perf_a.performance_profile.getRating(requirements.element_count);
        const rating_b = perf_b.performance_profile.getRating(requirements.element_count);

        var score_a: i32 = @intCast(rating_a);
        var score_b: i32 = @intCast(rating_b);

        // Adjust scores based on requirements
        if (requirements.performance_priority >= 4) {
            // High performance priority - favor simpler algorithms
            score_a += @intCast(5 - algorithm_a.getComplexity());
            score_b += @intCast(5 - algorithm_b.getComplexity());
        }

        return ComparisonResult{
            .preferred = if (score_a > score_b) algorithm_a else algorithm_b,
            .score_difference = @abs(score_a - score_b),
            .performance_rating_a = rating_a,
            .performance_rating_b = rating_b,
        };
    }

    pub const ComparisonResult = struct {
        preferred: LayoutAlgorithm,
        score_difference: u32,
        performance_rating_a: u8,
        performance_rating_b: u8,

        /// Check if there's a clear preference
        pub fn hasClearPreference(self: ComparisonResult) bool {
            return self.score_difference >= 2;
        }
    };
};

// Tests
test "algorithm recommendation" {
    const testing = std.testing;

    // Test explicit positioning recommendation
    const abs_requirements = AlgorithmRecommender.LayoutRequirements{
        .needs_explicit_positioning = true,
    };
    try testing.expect(AlgorithmRecommender.recommend(abs_requirements) == .absolute);

    // Test 2D layout recommendation
    const grid_requirements = AlgorithmRecommender.LayoutRequirements{
        .needs_2d_layout = true,
    };
    try testing.expect(AlgorithmRecommender.recommend(grid_requirements) == .grid);

    // Test flexible sizing recommendation
    const flex_requirements = AlgorithmRecommender.LayoutRequirements{
        .needs_flexible_sizing = true,
    };
    try testing.expect(AlgorithmRecommender.recommend(flex_requirements) == .flex);

    // Test default recommendation
    const default_requirements = AlgorithmRecommender.LayoutRequirements{};
    try testing.expect(AlgorithmRecommender.recommend(default_requirements) == .block);
}

test "algorithm performance characteristics" {
    const testing = std.testing;

    const block_perf = AlgorithmPerformance.getForAlgorithm(.block);
    try testing.expect(block_perf.time_complexity == .linear);
    try testing.expect(block_perf.performance_profile.getRating(5) == 5); // Small count
    try testing.expect(block_perf.performance_profile.getRating(50) == 5); // Medium count

    const grid_perf = AlgorithmPerformance.getForAlgorithm(.grid);
    try testing.expect(grid_perf.time_complexity == .quadratic);
    try testing.expect(grid_perf.performance_profile.getRating(5) == 3); // Lower rating due to complexity
}

test "algorithm comparison" {
    const testing = std.testing;

    const requirements = AlgorithmRecommender.LayoutRequirements{
        .element_count = 5,
        .performance_priority = 5,
    };

    const comparison = AlgorithmComparator.compare(.block, .grid, requirements);
    try testing.expect(comparison.preferred == .block); // Block should be preferred for high performance priority
    try testing.expect(comparison.hasClearPreference()); // Should be a clear preference
}