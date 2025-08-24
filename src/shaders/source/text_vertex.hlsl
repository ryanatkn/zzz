// Vertex-based text rendering using actual glyph geometry
// Accepts vertex positions from triangulated glyph data instead of procedural generation
// Compile with: dxc -T vs_6_0 -E vs_main text_vertex.hlsl -Fo text_vertex_vs.dxil
// Compile with: dxc -T ps_6_0 -E ps_main text_vertex.hlsl -Fo text_vertex_ps.dxil

// Text rendering uniforms (same as old text_buffer.hlsl for compatibility)
cbuffer TextUniforms : register(b0, space1) {
    float2 screen_size;      // Screen dimensions for NDC conversion
    float2 glyph_position;   // Glyph position in screen coordinates  
    float2 glyph_size;       // Glyph size in pixels (may be used for scaling)
    float text_color_r;      // Color components split to avoid
    float text_color_g;      // HLSL array packing issues
    float text_color_b;      
    float text_color_a;      // Alpha channel
    float _padding;          // 16-byte alignment padding
};

// Vertex shader input - actual vertex positions from triangulated glyph
struct VertexInput {
    float2 position : POSITION; // Glyph-space position from triangulation
};

// Vertex to pixel shader
struct VertexOutput {
    float4 position : SV_Position;
    float2 glyph_pos : TEXCOORD0;   // Position in glyph space for coverage
    float4 color : COLOR0;          // Text color
};

// Transform vertex from glyph space to screen space
VertexOutput vs_main(VertexInput input) {
    VertexOutput output;
    
    // Transform glyph-space position to screen space
    // input.position is already scaled to pixel coordinates by the GlyphExtractor
    // glyph_position is the anchor point in screen coordinates
    // Apply Y-flip since glyph coordinates are Y-up, screen coordinates are Y-down
    float2 glyph_pos_flipped = float2(input.position.x, -input.position.y);
    float2 screen_pos = glyph_position + glyph_pos_flipped;
    
    // Convert screen position to NDC
    float2 ndc_pos = float2(
        (screen_pos.x / screen_size.x) * 2.0 - 1.0,  // X: 0->width becomes -1->+1
        -((screen_pos.y / screen_size.y) * 2.0 - 1.0) // Y: 0->height becomes +1->-1 (flip Y)
    );
    
    output.position = float4(ndc_pos, 0.0, 1.0);
    output.glyph_pos = input.position; // Pass glyph-space position for coverage
    output.color = float4(text_color_r, text_color_g, text_color_b, text_color_a);
    
    return output;
}

float4 ps_main(VertexOutput input) : SV_Target {
    // For triangulated glyphs, we have actual geometry coverage
    // The fragment is inside the character shape by definition
    float coverage = 1.0;
    
    // Apply coverage to alpha
    float4 final_color = input.color;
    final_color.a *= coverage;
    return final_color;
}