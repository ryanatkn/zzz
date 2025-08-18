/// Phaseable - can become ethereal/ghostly component
/// Sparse storage - only entities that can phase have this
pub const Phaseable = struct {
    phased: bool = false,
    phase_duration: f32 = 0, // Time remaining in phase state
    max_phase_duration: f32 = 5.0, // Maximum time that can be phased
    phase_immunity_physical: bool = true, // Immune to physical damage while phased
    phase_immunity_magical: bool = false, // Still vulnerable to magic while phased

    pub fn init(max_duration: f32) Phaseable {
        return .{
            .phased = false,
            .phase_duration = 0,
            .max_phase_duration = max_duration,
            .phase_immunity_physical = true,
            .phase_immunity_magical = false,
        };
    }

    pub fn startPhase(self: *Phaseable, duration: f32) void {
        self.phased = true;
        self.phase_duration = @min(duration, self.max_phase_duration);
    }

    pub fn endPhase(self: *Phaseable) void {
        self.phased = false;
        self.phase_duration = 0;
    }

    pub fn update(self: *Phaseable, dt: f32) bool {
        if (!self.phased) return false;
        
        self.phase_duration -= dt;
        if (self.phase_duration <= 0) {
            self.endPhase();
            return true; // Phase ended this frame
        }
        return false;
    }

    pub fn canPassThroughSolids(self: Phaseable) bool {
        return self.phased;
    }

    pub fn isImmuneToPhysical(self: Phaseable) bool {
        return self.phased and self.phase_immunity_physical;
    }
};