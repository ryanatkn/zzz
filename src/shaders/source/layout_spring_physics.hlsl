// GPU Layout Engine - Spring Physics Compute Shader
// Physics-based animations for smooth layout transitions

// UI Element structure
struct UIElement {
    float2 position;      // Current position
    float2 size;          // Current size
    float4 padding;       // Top, Right, Bottom, Left
    float4 margin;        // Top, Right, Bottom, Left  
    uint parent_index;    // Index of parent element (0xFFFFFFFF for root)
    uint layout_mode;     // 0=absolute, 1=relative, 2=flex
    uint constraints;     // Packed constraint flags
    uint dirty_flags;     // Bitfield for dirty tracking
};

// Spring state for physics simulation
struct SpringState {
    float2 velocity;      // Current velocity
    float2 target_pos;    // Target position
    float stiffness;      // Spring constant
    float damping;        // Damping factor
    float mass;           // Element mass (affects inertia)
    float rest_time;      // Time at rest (for stopping condition)
};

// Input/Output buffers
RWStructuredBuffer<UIElement> Elements : register(u0);
RWStructuredBuffer<SpringState> Springs : register(u1);

// Frame constants
cbuffer FrameData : register(b0) {
    float2 viewport_size;
    uint element_count;
    float delta_time;           // Time since last frame
    float global_stiffness;     // Global spring stiffness multiplier
    float global_damping;       // Global damping multiplier
    uint animation_flags;       // Animation control flags
}

// Physics constants
static const float MIN_VELOCITY = 0.1;      // Velocity threshold for stopping
static const float REST_THRESHOLD = 0.5;    // Distance threshold for rest
static const float MAX_VELOCITY = 1000.0;   // Maximum velocity cap
static const float MIN_MASS = 0.1;          // Minimum mass to prevent division by zero

// Spring physics simulation
float2 ComputeSpringForce(float2 current, float2 target, float2 velocity, SpringState spring) {
    // Calculate spring force: F = -k * displacement
    float2 displacement = current - target;
    float2 spring_force = -spring.stiffness * global_stiffness * displacement;
    
    // Calculate damping force: F = -c * velocity
    float2 damping_force = -spring.damping * global_damping * velocity;
    
    // Total force
    return spring_force + damping_force;
}

bool IsAtRest(float2 current, float2 target, float2 velocity, float threshold) {
    float distance = length(current - target);
    float speed = length(velocity);
    return distance < threshold && speed < MIN_VELOCITY;
}

// Main spring physics entry point
[numthreads(64, 1, 1)]
void cs_main(uint3 id : SV_DispatchThreadID) {
    if (id.x >= element_count) return;
    
    UIElement elem = Elements[id.x];
    SpringState spring = Springs[id.x];
    
    // Skip if spring animation is disabled for this element
    if ((elem.dirty_flags & 8) == 0) return; // Check spring dirty flag
    
    // Ensure minimum mass
    spring.mass = max(spring.mass, MIN_MASS);
    
    // Compute forces for position
    float2 pos_force = ComputeSpringForce(elem.position, spring.target_pos, spring.velocity, spring);
    
    // Size springs disabled for simplified 32-byte SpringState
    // Size animation could be handled with separate target tracking
    
    // Update velocity using Verlet integration: v = v + (F/m) * dt
    spring.velocity += (pos_force / spring.mass) * delta_time;
    
    // Cap velocity to prevent instability
    float speed = length(spring.velocity);
    if (speed > MAX_VELOCITY) {
        spring.velocity = (spring.velocity / speed) * MAX_VELOCITY;
    }
    
    // Update position: p = p + v * dt
    elem.position += spring.velocity * delta_time;
    
    // Check if at rest (position only now)
    bool pos_at_rest = IsAtRest(elem.position, spring.target_pos, spring.velocity, REST_THRESHOLD);
    
    if (pos_at_rest) {
        spring.rest_time += delta_time;
        
        // If rested long enough, snap to target and stop
        if (spring.rest_time > 0.1) { // 100ms rest time
            elem.position = spring.target_pos;
            spring.velocity = float2(0, 0);
            elem.dirty_flags &= ~8u; // Clear spring dirty flag
        }
    } else {
        spring.rest_time = 0.0;
    }
    
    // Write back results
    Elements[id.x] = elem;
    Springs[id.x] = spring;
}

// Entry point for setting spring targets (called after layout calculation)
[numthreads(64, 1, 1)]
void cs_set_targets(uint3 id : SV_DispatchThreadID) {
    if (id.x >= element_count) return;
    
    UIElement elem = Elements[id.x];
    SpringState spring = Springs[id.x];
    
    // Only update targets if element layout has changed
    if ((elem.dirty_flags & 1) == 0) return; // Check layout dirty flag
    
    // Set new targets from computed layout
    spring.target_pos = elem.position;
    
    // Initialize spring properties if not set
    if (spring.stiffness <= 0.0) {
        spring.stiffness = 10.0; // Default stiffness
        spring.damping = 2.0;    // Default damping
        spring.mass = 1.0;       // Default mass
    }
    
    // Enable spring animation
    elem.dirty_flags |= 8u; // Set spring dirty flag
    
    // Clear layout dirty flag since we've processed the change
    elem.dirty_flags &= ~1u;
    
    Elements[id.x] = elem;
    Springs[id.x] = spring;
}

// Entry point for configuring spring properties
[numthreads(64, 1, 1)]
void cs_configure_springs(uint3 id : SV_DispatchThreadID) {
    if (id.x >= element_count) return;
    
    UIElement elem = Elements[id.x];
    SpringState spring = Springs[id.x];
    
    // Configure spring properties based on element properties
    float element_size = length(elem.size);
    
    // Larger elements are "heavier" and move slower
    spring.mass = 1.0 + (element_size / 100.0);
    
    // Elements with children are stiffer (more resistant to change)
    bool has_children = false;
    for (uint i = 0; i < element_count; i++) {
        if (i != id.x && Elements[i].parent_index == id.x) {
            has_children = true;
            break;
        }
    }
    
    if (has_children) {
        spring.stiffness *= 1.5;
        spring.damping *= 1.2;
    }
    
    // Root elements are more stable
    if (elem.parent_index == 0xFFFFFFFF) {
        spring.stiffness *= 2.0;
        spring.damping *= 1.5;
    }
    
    Springs[id.x] = spring;
}

// Entry point for collision detection and response
[numthreads(64, 1, 1)]
void cs_collision(uint3 id : SV_DispatchThreadID) {
    if (id.x >= element_count) return;
    
    UIElement elem = Elements[id.x];
    SpringState spring = Springs[id.x];
    
    // Simple collision with viewport bounds
    if (elem.position.x < 0) {
        elem.position.x = 0;
        spring.velocity.x = -spring.velocity.x * 0.5; // Bounce with energy loss
    }
    if (elem.position.y < 0) {
        elem.position.y = 0;
        spring.velocity.y = -spring.velocity.y * 0.5;
    }
    if (elem.position.x + elem.size.x > viewport_size.x) {
        elem.position.x = viewport_size.x - elem.size.x;
        spring.velocity.x = -spring.velocity.x * 0.5;
    }
    if (elem.position.y + elem.size.y > viewport_size.y) {
        elem.position.y = viewport_size.y - elem.size.y;
        spring.velocity.y = -spring.velocity.y * 0.5;
    }
    
    Elements[id.x] = elem;
    Springs[id.x] = spring;
}