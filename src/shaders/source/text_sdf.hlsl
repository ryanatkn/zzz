// Core SDF Text rendering - focused on correctness
// Compile with: dxc -T vs_6_0 -E vs_main text_sdf.hlsl -Fo text_sdf_vs.dxil
// Compile with: dxc -T ps_6_0 -E ps_main text_sdf.hlsl -Fo text_sdf_ps.dxil

// SDF text rendering uniforms  
cbuffer SDFTextUniforms : register(b0, space1) {
    float2 screen_size;      // Screen dimensions for NDC conversion
    float2 text_position;    // Text position in screen coordinates
    float2 text_size;        // Text size in pixels
    float text_color_r;      // Color components split to avoid
    float text_color_g;      // HLSL array packing issues
    float text_color_b;      
    float text_color_a;      // Alpha channel
    
    // SDF-specific parameters
    float sdf_range;         // Distance field range (typically 4.0)
    float smoothing;         // Anti-aliasing smoothing factor
    float time;              // Animation time
    float _padding0, _padding1, _padding2; // Pad to 16-byte alignment
};

// SDF texture atlas with combined sampler
Texture2D<float4> sdf_atlas : register(t0, space2);
SamplerState atlas_sampler : register(s0, space2);

// Vertex shader input (just vertex ID for procedural generation)
struct VertexInput {
    uint vertex_id : SV_VertexID;
};

// Vertex to pixel shader
struct VertexOutput {
    float4 position : SV_Position;
    float2 texcoord : TEXCOORD0;
    float4 color : COLOR0;
};

// Generate textured quad vertices procedurally
VertexOutput vs_main(VertexInput input) {
    VertexOutput output;
    
    // Generate quad corner from vertex ID (6 vertices for 2 triangles)
    float2 quad_corner;
    float2 tex_corner;
    uint tri = input.vertex_id / 3;  // Triangle index (0 or 1)
    uint vert = input.vertex_id % 3; // Vertex in triangle (0, 1, 2)
    
    // First triangle: (0,0), (1,0), (0,1)
    // Second triangle: (0,1), (1,0), (1,1)
    if (tri == 0) {
        if (vert == 0) { quad_corner = float2(0.0, 0.0); tex_corner = float2(0.0, 0.0); } // top-left
        else if (vert == 1) { quad_corner = float2(1.0, 0.0); tex_corner = float2(1.0, 0.0); } // top-right
        else { quad_corner = float2(0.0, 1.0); tex_corner = float2(0.0, 1.0); } // bottom-left
    } else {
        if (vert == 0) { quad_corner = float2(0.0, 1.0); tex_corner = float2(0.0, 1.0); } // bottom-left
        else if (vert == 1) { quad_corner = float2(1.0, 0.0); tex_corner = float2(1.0, 0.0); } // top-right
        else { quad_corner = float2(1.0, 1.0); tex_corner = float2(1.0, 1.0); } // bottom-right
    }
    
    // Calculate screen position: position + corner * size
    float2 screen_pos = text_position + quad_corner * text_size;
    
    // Convert to NDC coordinates
    float2 ndc_pos = float2(
        (screen_pos.x / screen_size.x) * 2.0 - 1.0,  // X: 0->width becomes -1->+1
        -((screen_pos.y / screen_size.y) * 2.0 - 1.0) // Y: 0->height becomes +1->-1 (flip Y)
    );
    
    output.position = float4(ndc_pos, 0.0, 1.0);
    output.texcoord = tex_corner; // Use texture coordinates 0-1 for full texture
    output.color = float4(text_color_r, text_color_g, text_color_b, text_color_a);
    
    return output;
}

float4 ps_main(VertexOutput input) : SV_Target {
    // Sample the SDF atlas texture
    float4 sdf_sample = sdf_atlas.Sample(atlas_sampler, input.texcoord);
    
    // Extract distance from SDF (single channel for now - use red channel)
    float distance = sdf_sample.r - 0.5;
    
    // Scale distance by SDF range for proper anti-aliasing
    float screen_distance = distance * sdf_range;
    
    // Anti-aliased text rendering using smoothstep
    float text_alpha = smoothstep(-smoothing, smoothing, screen_distance);
    
    // Apply text color with calculated alpha
    float4 final_color = float4(input.color.rgb, input.color.a * text_alpha);
    
    // Discard very transparent pixels for performance
    if (final_color.a < 0.01) {
        discard;
    }
    
    return final_color;
}