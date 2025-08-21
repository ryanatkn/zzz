// Test compute shader for GPU layout engine exploration
// This shader will test basic compute functionality with SDL3

// Test buffer for compute operations
RWStructuredBuffer<float4> TestBuffer : register(u0);

[numthreads(64, 1, 1)]
void cs_main(uint3 id : SV_DispatchThreadID)
{
    // Simple test: double the values in the buffer
    uint index = id.x;
    float4 value = TestBuffer[index];
    TestBuffer[index] = value * 2.0;
}