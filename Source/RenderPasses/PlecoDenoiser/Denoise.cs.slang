cbuffer CB
{
    uint gFrameCount;
};

Texture2D<float4> gInputTexture;        //input data
RWTexture2D<float4> gOutputTexture;     //output data

// 3x3 block of float4s
struct float4Block
{
    float4 m00, m01, m02, m10, m11, m12, m20, m21, m22;
};

[numthreads(16, 16, 1)]
void denoise(uint3 dispatchThreadId : SV_DispatchThreadID)
{
    // PIXEL POSITIONS
    //  00 01 02
    //  10 11 12
    //  20 21 22

    const uint2 PP11 = dispatchThreadId.xy;
    
    const uint2 PP00 = uint2(PP11.x - 1, PP11.y - 1);
    const uint2 PP01 = uint2(PP11.x, PP11.y - 1);
    const uint2 PP02 = uint2(PP11.x + 1, PP11.y - 1);
    
    const uint2 PP10 = uint2(PP11.x - 1, PP11.y);
    const uint2 PP12 = uint2(PP11.x + 1, PP11.y);
    
    const uint2 PP20 = uint2(PP11.x - 1, PP11.y + 1);
    const uint2 PP21 = uint2(PP11.x, PP11.y + 1);
    const uint2 PP22 = uint2(PP11.x + 1, PP11.y + 1);

    //Convolutional Filtering
    //--------------------------------------------
    float4Block block =
    {
        gInputTexture[PP00], gInputTexture[PP01], gInputTexture[PP02],
        gInputTexture[PP10], gInputTexture[PP11], gInputTexture[PP12],
        gInputTexture[PP20], gInputTexture[PP21], gInputTexture[PP22]
    };

    float3x3 kernel =
    {
        1.f / 16.f, 2.f / 16.f, 1.f / 16.f,
        2.f / 16.f, 4.f / 16.f, 2.f / 16.f,
        1.f / 16.f, 2.f / 16.f, 1.f / 16.f
    };
    float3 filtered = float3(block.m00.r * kernel[0][0] + block.m01.r * kernel[0][1] + block.m02.r * kernel[0][2] + block.m10.r * kernel[1][0] + block.m11.r * kernel[1][1] + block.m12.r * kernel[1][2] + block.m20.r * kernel[2][0] + block.m21.r * kernel[2][1] + block.m22.r * kernel[2][2],
                            block.m00.g * kernel[0][0] + block.m01.g * kernel[0][1] + block.m02.g * kernel[0][2] + block.m10.g * kernel[1][0] + block.m11.g * kernel[1][1] + block.m12.g * kernel[1][2] + block.m20.g * kernel[2][0] + block.m21.g * kernel[2][1] + block.m22.g * kernel[2][2],
                            block.m00.b * kernel[0][0] + block.m01.b * kernel[0][1] + block.m02.b * kernel[0][2] + block.m10.b * kernel[1][0] + block.m11.b * kernel[1][1] + block.m12.b * kernel[1][2] + block.m20.b * kernel[2][0] + block.m21.b * kernel[2][1] + block.m22.b * kernel[2][2]);
    
    float4Block filter =
    {
        float4(0.979), float4(0.278), float4(0.940),
        float4(0.713), float4(0.048), float4(0.564),
        float4(0.604), float4(0.327), float4(0.853)
    };

    // dot product
    float3x3 dp =
    {
        dot(block.m00, filter.m00), dot(block.m01, filter.m01), dot(block.m02, filter.m02),
        dot(block.m10, filter.m10), dot(block.m11, filter.m11), dot(block.m12, filter.m12),
        dot(block.m20, filter.m20), dot(block.m21, filter.m21), dot(block.m22, filter.m22)
    };

    float3 denoiseColStart = float3(gInputTexture[PP11].x, gInputTexture[PP11].y, gInputTexture[PP11].z);
    denoiseColStart = float3(((denoiseColStart.x * dp._m00) + (denoiseColStart.y * dp._m01) + (denoiseColStart.z * dp._m02)),
                                    ((denoiseColStart.x * dp._m10) + (denoiseColStart.y * dp._m11) + (denoiseColStart.z * dp._m12)),
                                    ((denoiseColStart.x * dp._m20) + (denoiseColStart.y * dp._m21) + (denoiseColStart.z * dp._m22)));


    // simple left right / up down filter
    //----------------------------------
    float4 lr = (gInputTexture[PP10] + gInputTexture[PP11] + gInputTexture[PP12]) / 3.0f;
    float4 ud = (gInputTexture[PP01] + gInputTexture[PP11] + gInputTexture[PP21]) / 3.0f;
    float4 combo = (lr + ud) / 2.0f;

    
    //const float4 pixelCol = combo;
    //const float4 pixelCol = float4(denoiseColStart.x, denoiseColStart.y, denoiseColStart.z, gInputTexture[PP11].w);
    //const float4 pixelCol = gInputTexture[PP11];
    
    gOutputTexture[PP11] = float4(filtered.rgb, 1); // just output directly 
}
