// GPU Layout Engine - Box Model Compute Shader
// Calculates CSS-like box model layout entirely on GPU

// UI Element structure matching Zig extern struct
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

// Constraint structure for sizing rules
struct Constraint {
    float min_width;
    float max_width;
    float min_height;
    float max_height;
};

// Input/Output buffers
RWStructuredBuffer<UIElement> Elements : register(u0);
StructuredBuffer<Constraint> Constraints : register(t0);

// Frame constants
cbuffer FrameData : register(b0) {
    float2 viewport_size;
    uint element_count;
    uint pass_type; // 0=measure, 1=arrange
}

// Helper functions
float2 ApplyConstraints(float2 size, Constraint constraint) {
    return float2(
        clamp(size.x, constraint.min_width, constraint.max_width),
        clamp(size.y, constraint.min_height, constraint.max_height)
    );
}

float2 GetContentBox(UIElement elem) {
    float2 content_size = elem.size;
    content_size.x -= elem.padding.y + elem.padding.w; // right + left
    content_size.y -= elem.padding.x + elem.padding.z; // top + bottom
    return max(content_size, float2(0, 0));
}

float2 GetBorderBox(UIElement elem) {
    return elem.size;
}

float2 GetMarginBox(UIElement elem) {
    float2 margin_size = elem.size;
    margin_size.x += elem.margin.y + elem.margin.w; // right + left
    margin_size.y += elem.margin.x + elem.margin.z; // top + bottom
    return margin_size;
}

// Main compute shader entry point
[numthreads(64, 1, 1)]
void cs_main(uint3 id : SV_DispatchThreadID) {
    if (id.x >= element_count) return;
    
    UIElement elem = Elements[id.x];
    
    // Skip if not dirty
    if ((elem.dirty_flags & 1) == 0) return;
    
    // Get parent element (if exists)
    UIElement parent;
    float2 available_space = viewport_size;
    float2 parent_offset = float2(0, 0);
    
    if (elem.parent_index != 0xFFFFFFFF && elem.parent_index < element_count) {
        parent = Elements[elem.parent_index];
        available_space = GetContentBox(parent);
        parent_offset = parent.position;
        parent_offset.x += parent.padding.w; // left padding
        parent_offset.y += parent.padding.x; // top padding
    }
    
    // Apply constraints to size
    Constraint constraint = Constraints[id.x];
    elem.size = ApplyConstraints(elem.size, constraint);
    
    // Calculate position based on layout mode
    switch (elem.layout_mode) {
        case 0: // absolute
            elem.position = elem.position; // Use specified position
            break;
            
        case 1: // relative
            elem.position = parent_offset + elem.position;
            break;
            
        case 2: // flex (simplified)
            // This would normally involve multi-pass calculation
            // For now, just stack vertically
            if (elem.parent_index != 0xFFFFFFFF) {
                // Find previous sibling (simplified)
                float y_offset = 0;
                for (uint i = 0; i < id.x; i++) {
                    UIElement sibling = Elements[i];
                    if (sibling.parent_index == elem.parent_index) {
                        y_offset += GetMarginBox(sibling).y;
                    }
                }
                elem.position = parent_offset + float2(elem.margin.w, y_offset + elem.margin.x);
            }
            break;
    }
    
    // Clear dirty flag
    elem.dirty_flags &= ~1u;
    
    // Write back result
    Elements[id.x] = elem;
}

// Entry point for measure pass
[numthreads(64, 1, 1)]
void cs_measure(uint3 id : SV_DispatchThreadID) {
    if (id.x >= element_count) return;
    
    UIElement elem = Elements[id.x];
    
    // Skip if not dirty
    if ((elem.dirty_flags & 2) == 0) return; // Check measure dirty flag
    
    // Measure content based on children (simplified)
    float2 content_size = float2(0, 0);
    
    // Sum up children sizes (simplified)
    for (uint i = 0; i < element_count; i++) {
        UIElement child = Elements[i];
        if (child.parent_index == id.x) {
            float2 child_margin_box = GetMarginBox(child);
            content_size.x = max(content_size.x, child_margin_box.x);
            content_size.y += child_margin_box.y;
        }
    }
    
    // Add padding
    content_size.x += elem.padding.y + elem.padding.w;
    content_size.y += elem.padding.x + elem.padding.z;
    
    // Apply constraints
    Constraint constraint = Constraints[id.x];
    elem.size = ApplyConstraints(content_size, constraint);
    
    // Clear measure dirty flag
    elem.dirty_flags &= ~2u;
    
    Elements[id.x] = elem;
}

// Entry point for spring physics animation
[numthreads(64, 1, 1)]
void cs_spring_physics(uint3 id : SV_DispatchThreadID) {
    if (id.x >= element_count) return;
    
    UIElement elem = Elements[id.x];
    
    // Spring physics for smooth transitions
    // This is a simplified version - real implementation would need:
    // - Velocity buffer
    // - Spring constants
    // - Damping factors
    // - Target positions
    
    const float spring_strength = 0.1;
    const float damping = 0.9;
    
    // For now, just lerp towards target (stored in margin for demo)
    float2 target = float2(elem.margin.x, elem.margin.y);
    float2 current = elem.position;
    
    elem.position = lerp(current, target, spring_strength);
    
    Elements[id.x] = elem;
}