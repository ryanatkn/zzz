// Text rendering with texture atlas support
// Compile with: dxc -T vs_6_0 -E vs_main text.hlsl -Fo text_vs.dxil
// Compile with: dxc -T ps_6_0 -E ps_main text.hlsl -Fo text_ps.dxil

// Per-frame uniforms
cbuffer FrameUniforms : register(b0) {
    float2 screen_size;
    float4 camera_transform; // [offset_x, offset_y, zoom, rotation]
    float time;
    float _padding;
};

// Font texture atlas
Texture2D<float4> font_atlas : register(t0);
SamplerState atlas_sampler : register(s0);

// Vertex shader input
struct VertexInput {
    float2 position : POSITION0;
    float2 texcoord : TEXCOORD0;
    float4 color : COLOR0;
};

// Vertex to pixel shader
struct VertexOutput {
    float4 position : SV_Position;
    float2 texcoord : TEXCOORD0;
    float4 color : COLOR0;
};

VertexOutput vs_main(VertexInput input) {
    VertexOutput output;
    
    // Transform position to screen space
    float2 world_pos = input.position;
    
    // Transform through camera (text is usually in screen space, not world space)
    // For HUD text, we might want to skip camera transform
    // world_pos = (world_pos - camera_transform.xy) * camera_transform.z;
    // world_pos += screen_size * 0.5;
    
    // Convert to NDC
    output.position = float4(
        (world_pos.x / screen_size.x) * 2.0 - 1.0,
        1.0 - (world_pos.y / screen_size.y) * 2.0,
        0.0,
        1.0
    );
    
    output.texcoord = input.texcoord;
    output.color = input.color;
    
    return output;
}

float4 ps_main(VertexOutput input) : SV_Target {
    // Sample the font atlas texture
    float4 atlas_sample = font_atlas.Sample(atlas_sampler, input.texcoord);
    
    // For TTF fonts, typically use the alpha channel for coverage
    // The atlas might be grayscale or RGBA depending on font type
    float coverage = atlas_sample.a;
    
    // Apply text color with atlas coverage
    float4 final_color = input.color;
    final_color.a *= coverage;
    
    return final_color;
}