// GPU Layout Engine - Constraint Solver Compute Shader
// Iterative constraint satisfaction for complex layouts

// UI Element structure
struct UIElement {
    float2 position;      // Computed absolute position
    float2 size;          // Computed size after constraints
    float4 padding;       // Top, Right, Bottom, Left
    float4 margin;        // Top, Right, Bottom, Left  
    uint parent_index;    // Index of parent element (0xFFFFFFFF for root)
    uint layout_mode;     // 0=absolute, 1=relative, 2=flex
    uint constraints;     // Packed constraint flags
    uint dirty_flags;     // Bitfield for dirty tracking
};

// Constraint structure for advanced layout rules
struct LayoutConstraint {
    float min_width;      // Minimum width
    float max_width;      // Maximum width
    float min_height;     // Minimum height
    float max_height;     // Maximum height
    float aspect_ratio;   // Target aspect ratio (0 = none)
    uint anchor_flags;    // Anchor point constraints
    uint priority;        // Resolution priority (higher = more important)
    uint constraint_type; // Type of constraint (size, position, etc.)
};

// Input/Output buffers
RWStructuredBuffer<UIElement> Elements : register(u0);
StructuredBuffer<LayoutConstraint> Constraints : register(t0);

// Frame constants
cbuffer FrameData : register(b0) {
    float2 viewport_size;
    uint element_count;
    uint iteration_count;      // Current iteration of constraint solving
    float relaxation_factor;   // Relaxation factor for iterative solving
    uint max_iterations;       // Maximum iterations before giving up
}

// Constraint solving helpers
float2 ApplyConstraint(float2 current_value, LayoutConstraint constraint, uint constraint_type) {
    switch (constraint_type) {
        case 0: // Size constraint
            return float2(
                clamp(current_value.x, constraint.min_width, constraint.max_width),
                clamp(current_value.y, constraint.min_height, constraint.max_height)
            );
        case 1: // Aspect ratio constraint
            if (constraint.aspect_ratio > 0) {
                float target_height = current_value.x / constraint.aspect_ratio;
                return float2(current_value.x, target_height);
            }
            return current_value;
        default:
            return current_value;
    }
}

bool ShouldProcessConstraint(uint priority, uint iteration) {
    // Process higher priority constraints first
    // Priority 0 = every iteration, Priority 1 = every 2nd, etc.
    return (iteration % (priority + 1)) == 0;
}

// Main constraint solver entry point
[numthreads(64, 1, 1)]
void cs_main(uint3 id : SV_DispatchThreadID) {
    if (id.x >= element_count) return;
    
    UIElement elem = Elements[id.x];
    LayoutConstraint constraint = Constraints[id.x];
    
    // Skip if element is not dirty or constraint is not active
    if ((elem.dirty_flags & 4) == 0) return; // Check constraint dirty flag
    
    // Only process constraints based on priority and iteration
    if (!ShouldProcessConstraint(constraint.priority, iteration_count)) return;
    
    float2 original_size = elem.size;
    float2 original_position = elem.position;
    
    // Apply size constraints
    elem.size = ApplyConstraint(elem.size, constraint, 0);
    
    // Apply aspect ratio constraints
    if (constraint.aspect_ratio > 0.0) {
        elem.size = ApplyConstraint(elem.size, constraint, 1);
    }
    
    // Apply anchor constraints (simplified)
    if (constraint.anchor_flags != 0) {
        UIElement parent;
        if (elem.parent_index != 0xFFFFFFFF && elem.parent_index < element_count) {
            parent = Elements[elem.parent_index];
            
            // Center horizontally
            if (constraint.anchor_flags & 1) {
                elem.position.x = parent.position.x + 
                    (parent.size.x - elem.size.x) * 0.5;
            }
            
            // Center vertically  
            if (constraint.anchor_flags & 2) {
                elem.position.y = parent.position.y + 
                    (parent.size.y - elem.size.y) * 0.5;
            }
            
            // Anchor to right
            if (constraint.anchor_flags & 4) {
                elem.position.x = parent.position.x + parent.size.x - elem.size.x;
            }
            
            // Anchor to bottom
            if (constraint.anchor_flags & 8) {
                elem.position.y = parent.position.y + parent.size.y - elem.size.y;
            }
        }
    }
    
    // Apply relaxation to smooth convergence
    elem.size = lerp(original_size, elem.size, relaxation_factor);
    elem.position = lerp(original_position, elem.position, relaxation_factor);
    
    // Clear constraint dirty flag if converged
    float size_change = length(elem.size - original_size);
    float pos_change = length(elem.position - original_position);
    
    if (size_change < 0.01 && pos_change < 0.01) {
        elem.dirty_flags &= ~4u; // Clear constraint dirty flag
    }
    
    Elements[id.x] = elem;
}

// Alternative entry point for priority-based solving
[numthreads(64, 1, 1)]  
void cs_priority_solve(uint3 id : SV_DispatchThreadID) {
    if (id.x >= element_count) return;
    
    UIElement elem = Elements[id.x];
    LayoutConstraint constraint = Constraints[id.x];
    
    // Only process high priority constraints in this pass
    if (constraint.priority < 2) return;
    
    // Apply critical constraints immediately
    elem.size = ApplyConstraint(elem.size, constraint, 0);
    
    // Force apply aspect ratio for high priority elements
    if (constraint.aspect_ratio > 0.0 && constraint.priority >= 3) {
        float new_height = elem.size.x / constraint.aspect_ratio;
        elem.size.y = new_height;
    }
    
    Elements[id.x] = elem;
}

// Validation pass to ensure constraints are satisfied
[numthreads(64, 1, 1)]
void cs_validate(uint3 id : SV_DispatchThreadID) {
    if (id.x >= element_count) return;
    
    UIElement elem = Elements[id.x];
    LayoutConstraint constraint = Constraints[id.x];
    
    // Check if constraints are violated
    bool size_valid = elem.size.x >= constraint.min_width && 
                     elem.size.x <= constraint.max_width &&
                     elem.size.y >= constraint.min_height && 
                     elem.size.y <= constraint.max_height;
                     
    bool aspect_valid = true;
    if (constraint.aspect_ratio > 0.0) {
        float current_aspect = elem.size.x / max(elem.size.y, 0.001);
        aspect_valid = abs(current_aspect - constraint.aspect_ratio) < 0.1;
    }
    
    // Set error flags if constraints violated
    if (!size_valid || !aspect_valid) {
        elem.dirty_flags |= 16u; // Set constraint violation flag
    } else {
        elem.dirty_flags &= ~16u; // Clear violation flag
    }
    
    Elements[id.x] = elem;
}