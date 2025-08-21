const std = @import("std");

/// Measurement quality assessment levels
pub const MeasurementQuality = enum { excellent, good, fair, poor };

/// Statistical analysis module for benchmark data quality assessment
pub const StatisticalAnalysis = struct {
    /// Outlier detection configuration
    pub const OutlierConfig = struct {
        /// Multiplier for IQR-based outlier detection (default 1.5)
        iqr_multiplier: f64 = 1.5,
        /// Minimum sample size required for outlier detection
        min_sample_size: usize = 10,
        /// Enable outlier detection
        enabled: bool = true,
    };

    /// Result of outlier analysis
    pub const OutlierResult = struct {
        outlier_count: usize,
        outlier_indices: []usize,
        cleaned_mean: f64,
        cleaned_std_dev: f64,
        q1: f64,
        q3: f64,
        iqr: f64,
        lower_fence: f64,
        upper_fence: f64,
    };

    /// Enhanced statistics with outlier information
    pub const EnhancedStats = struct {
        count: usize,
        mean: f64,
        std_dev: f64,
        min: f64,
        max: f64,
        median: f64,
        q1: f64,
        q3: f64,
        iqr: f64,
        outliers: OutlierResult,
        coefficient_of_variation: f64, // std_dev / mean
        measurement_quality: MeasurementQuality,
    };

    allocator: std.mem.Allocator,
    config: OutlierConfig,

    pub fn init(allocator: std.mem.Allocator, config: OutlierConfig) StatisticalAnalysis {
        return StatisticalAnalysis{
            .allocator = allocator,
            .config = config,
        };
    }

    /// Calculate enhanced statistics with outlier detection
    pub fn analyzeData(self: *StatisticalAnalysis, data: []const f64) !EnhancedStats {
        if (data.len == 0) {
            return error.EmptyDataSet;
        }

        // Create sorted copy for percentile calculations
        const sorted_data = try self.allocator.alloc(f64, data.len);
        defer self.allocator.free(sorted_data);
        @memcpy(sorted_data, data);
        std.mem.sort(f64, sorted_data, {}, comptime std.sort.asc(f64));

        // Basic statistics
        const mean = calculateMean(data);
        const std_dev = calculateStdDev(data, mean);
        const min = sorted_data[0];
        const max = sorted_data[sorted_data.len - 1];
        
        // Percentiles
        const median = calculatePercentile(sorted_data, 0.5);
        const q1 = calculatePercentile(sorted_data, 0.25);
        const q3 = calculatePercentile(sorted_data, 0.75);
        const iqr = q3 - q1;

        // Outlier detection
        const outliers = if (self.config.enabled and data.len >= self.config.min_sample_size)
            try self.detectOutliers(data, q1, q3, iqr)
        else
            OutlierResult{
                .outlier_count = 0,
                .outlier_indices = &[_]usize{},
                .cleaned_mean = mean,
                .cleaned_std_dev = std_dev,
                .q1 = q1,
                .q3 = q3,
                .iqr = iqr,
                .lower_fence = q1 - self.config.iqr_multiplier * iqr,
                .upper_fence = q3 + self.config.iqr_multiplier * iqr,
            };

        // Coefficient of variation and quality assessment
        const cv = if (mean != 0) @abs(std_dev / mean) else 0;
        const quality = assessMeasurementQuality(cv, outliers.outlier_count, data.len);

        return EnhancedStats{
            .count = data.len,
            .mean = mean,
            .std_dev = std_dev,
            .min = min,
            .max = max,
            .median = median,
            .q1 = q1,
            .q3 = q3,
            .iqr = iqr,
            .outliers = outliers,
            .coefficient_of_variation = cv,
            .measurement_quality = quality,
        };
    }

    /// Detect outliers using IQR method
    fn detectOutliers(self: *StatisticalAnalysis, data: []const f64, q1: f64, q3: f64, iqr: f64) !OutlierResult {
        const lower_fence = q1 - self.config.iqr_multiplier * iqr;
        const upper_fence = q3 + self.config.iqr_multiplier * iqr;

        var outlier_indices = std.ArrayList(usize).init(self.allocator);
        defer outlier_indices.deinit();

        var clean_values = std.ArrayList(f64).init(self.allocator);
        defer clean_values.deinit();

        for (data, 0..) |value, i| {
            if (value < lower_fence or value > upper_fence) {
                try outlier_indices.append(i);
            } else {
                try clean_values.append(value);
            }
        }

        // Calculate cleaned statistics
        const cleaned_mean = if (clean_values.items.len > 0) calculateMean(clean_values.items) else 0;
        const cleaned_std_dev = if (clean_values.items.len > 0) calculateStdDev(clean_values.items, cleaned_mean) else 0;

        const outlier_indices_owned = try outlier_indices.toOwnedSlice();

        return OutlierResult{
            .outlier_count = outlier_indices_owned.len,
            .outlier_indices = outlier_indices_owned,
            .cleaned_mean = cleaned_mean,
            .cleaned_std_dev = cleaned_std_dev,
            .q1 = q1,
            .q3 = q3,
            .iqr = iqr,
            .lower_fence = lower_fence,
            .upper_fence = upper_fence,
        };
    }

    /// Free memory allocated for outlier indices
    pub fn freeOutlierResult(self: *StatisticalAnalysis, result: *OutlierResult) void {
        if (result.outlier_indices.len > 0) {
            self.allocator.free(result.outlier_indices);
        }
    }

    /// Calculate mean of dataset
    fn calculateMean(data: []const f64) f64 {
        var sum: f64 = 0;
        for (data) |value| {
            sum += value;
        }
        return sum / @as(f64, @floatFromInt(data.len));
    }

    /// Calculate standard deviation
    fn calculateStdDev(data: []const f64, mean: f64) f64 {
        if (data.len <= 1) return 0;
        
        var variance_sum: f64 = 0;
        for (data) |value| {
            const diff = value - mean;
            variance_sum += diff * diff;
        }
        return @sqrt(variance_sum / @as(f64, @floatFromInt(data.len)));
    }

    /// Calculate percentile (0.0 to 1.0)
    fn calculatePercentile(sorted_data: []const f64, percentile: f64) f64 {
        if (sorted_data.len == 0) return 0;
        if (sorted_data.len == 1) return sorted_data[0];

        const index = percentile * @as(f64, @floatFromInt(sorted_data.len - 1));
        const lower_index = @as(usize, @intFromFloat(@floor(index)));
        const upper_index = @min(lower_index + 1, sorted_data.len - 1);
        
        if (lower_index == upper_index) {
            return sorted_data[lower_index];
        }
        
        const fraction = index - @floor(index);
        return sorted_data[lower_index] * (1.0 - fraction) + sorted_data[upper_index] * fraction;
    }

    /// Assess measurement quality based on coefficient of variation and outliers
    fn assessMeasurementQuality(cv: f64, outlier_count: usize, total_count: usize) MeasurementQuality {
        const outlier_ratio = @as(f64, @floatFromInt(outlier_count)) / @as(f64, @floatFromInt(total_count));
        
        // Excellent: Low CV, very few outliers
        if (cv < 0.05 and outlier_ratio < 0.05) {
            return .excellent;
        }
        // Good: Moderate CV, few outliers
        else if (cv < 0.15 and outlier_ratio < 0.10) {
            return .good;
        }
        // Fair: Higher CV or moderate outliers
        else if (cv < 0.25 and outlier_ratio < 0.20) {
            return .fair;
        }
        // Poor: High CV or many outliers
        else {
            return .poor;
        }
    }
};

// Tests
test "statistical analysis basic functionality" {
    const testing = std.testing;
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var analyzer = StatisticalAnalysis.init(allocator, StatisticalAnalysis.OutlierConfig{});
    
    // Test with clean data (no outliers)
    const clean_data = [_]f64{ 10.0, 10.1, 10.2, 9.9, 9.8, 10.3, 10.0, 9.7, 10.4, 10.1 };
    var stats = try analyzer.analyzeData(&clean_data);
    defer analyzer.freeOutlierResult(&stats.outliers);
    
    try testing.expect(stats.count == 10);
    try testing.expect(stats.outliers.outlier_count == 0);
    try testing.expect(stats.measurement_quality == .excellent);
}

test "outlier detection" {
    const testing = std.testing;
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var analyzer = StatisticalAnalysis.init(allocator, StatisticalAnalysis.OutlierConfig{});
    
    // Test with outliers
    const outlier_data = [_]f64{ 10.0, 10.1, 10.2, 9.9, 100.0, 10.3, 10.0, 9.7, 10.4, 0.1 };
    var stats = try analyzer.analyzeData(&outlier_data);
    defer analyzer.freeOutlierResult(&stats.outliers);
    
    try testing.expect(stats.outliers.outlier_count == 2); // 100.0 and 0.1 should be outliers
    try testing.expect(stats.measurement_quality != .excellent);
}