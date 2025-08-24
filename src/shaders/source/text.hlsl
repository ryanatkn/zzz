// Text rendering with texture atlas support
// Compile with: dxc -T vs_6_0 -E vs_main text.hlsl -Fo text_vs.dxil
// Compile with: dxc -T ps_6_0 -E ps_main text.hlsl -Fo text_ps.dxil

// Font texture atlas with combined sampler (fragment shader only)
Texture2D<float4> font_atlas : register(t0, space2);
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

// Text rendering uniforms (vertex shader only - colors passed through VertexOutput)
cbuffer TextUniforms : register(b0, space1) {
    float2 uv_min;           // Atlas UV coordinates - top-left
    float2 uv_max;           // Atlas UV coordinates - bottom-right
    float2 screen_size;      // Screen dimensions for NDC conversion
    float2 glyph_position;   // Glyph position in screen coordinates (matches Zig TextUniforms)
    float2 glyph_size;       // Glyph size in pixels (matches Zig TextUniforms)
    float text_color_r;      // Color components split to avoid
    float text_color_g;      // HLSL array packing issues
    float text_color_b;      
    float text_color_a;      // Alpha channel
    float2 _padding;         // Padding for 64-byte alignment
    // Total: 64 bytes (16-byte aligned, proper HLSL cbuffer size)
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
    float2 screen_pos = glyph_position + quad_corner * glyph_size;
    
    // Convert to NDC coordinates
    float2 ndc_pos = float2(
        (screen_pos.x / screen_size.x) * 2.0 - 1.0,  // X: 0->width becomes -1->+1
        -((screen_pos.y / screen_size.y) * 2.0 - 1.0) // Y: 0->height becomes +1->-1 (flip Y)
    );
    
    output.position = float4(ndc_pos, 0.0, 1.0);
    
    // Interpolate texture coordinates between uv_min and uv_max based on quad corner
    output.texcoord = uv_min + tex_corner * (uv_max - uv_min);
    
    output.color = float4(text_color_r, text_color_g, text_color_b, text_color_a);
    
    return output;
}

float4 ps_main(VertexOutput input) : SV_Target {
    // Sample the font atlas texture
    float4 atlas_sample = font_atlas.Sample(atlas_sampler, input.texcoord);
    
    // STANDARD: Use alpha channel for coverage (industry standard approach)
    float coverage = atlas_sample.a;
    
    // Apply text color with coverage
    float4 final_color = input.color;
    final_color.a *= coverage;
    
    // Discard very transparent pixels for performance
    if (final_color.a < 0.01) {
        discard;
    }
    
    return final_color;
}