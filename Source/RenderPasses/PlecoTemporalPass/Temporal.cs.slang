cbuffer CB
{
    uint gFrameCount;
};

Texture2D<float4> gInputTexture; //input data
RWTexture2D<float4> gPrevOutputTexture; //prior input data CAN BE WRITTEN INTO
RWTexture2D<float4> gOutputTexture; //output data

// 3x3 block of float4s
struct float4Block
{
    float4 m00, m01, m02, m03, m04,
           m10, m11, m12, m13, m14,
           m20, m21, m22, m23, m24,
           m30, m31, m32, m33, m34,
           m40, m41, m42, m43, m44;
};

float3 ema(uint3 dtID)
{
    float3 motionVectorPP = (gInputTexture[dtID.xy] - gPrevOutputTexture[dtID.xy]).rgb;
    return motionVectorPP;
}

void temporalAccumulation(uint3 dtID)
{
    const uint2 PP00 = dtID.xy;
    float3 inp = gInputTexture[PP00].rgb;
    gOutputTexture[PP00] = float4(0.2f * inp + 0.8f * ema(dtID), 1.0f);
    
}

void updatePrevFrame(uint3 dtID)
{
    //prev frame is RW which allows for this
    gPrevOutputTexture[dtID.xy] = gOutputTexture[dtID.xy];
}

[numthreads(16, 16, 1)]
void temporal(uint3 dispatchThreadId : SV_DispatchThreadID)
{
    //make sure we can actually use the previous frame
    if (gFrameCount > 0)
    {
        temporalAccumulation(dispatchThreadId);
    }
    
    updatePrevFrame(dispatchThreadId);

}
