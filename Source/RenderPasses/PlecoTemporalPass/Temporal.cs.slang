cbuffer CB
{
    uint gFrameCount;
};

Texture2D<float4> gInputTexture; //input data
Texture2D<float4> gInputMotionTexture;
RWTexture2D<float4> gPrevOutputTexture; //prior input data CAN BE WRITTEN INTO
RWTexture2D<float4> gOutputTexture; //output data
RWTexture2D<float4> gPrevOutputTextureSum;
RWTexture2D<float> gAccumCountTexture;

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

[numthreads(16, 16, 1)]
void accumulate(uint3 dispatchThreadId : SV_DispatchThreadID)
{
    const uint2 pixelPos = dispatchThreadId.xy;
    const float4 curColor = gInputTexture[pixelPos];
    const float4 motionVec = gInputMotionTexture[pixelPos];
    const float motionMagnitude = clamp(length(motionVec.xyz) * 1000.f, 0.f, 1.f);
    const float invMotionMagnitude = 1.f - motionMagnitude;
    
    //const float motionEffect = pow(motionMagnitude, 0.1f);
    //const float inverseMotionEffect = 1.f - motionEffect;

    //gPrevOutputTextureSum[pixelPos] *= inverseMotionEffect;
    //gAccumCountTexture[pixelPos] += inverseMotionEffect;

    gAccumCountTexture[pixelPos] *= invMotionMagnitude;
    gAccumCountTexture[pixelPos] += 1;
    
    float4 sum = gPrevOutputTextureSum[pixelPos] * invMotionMagnitude + curColor;
    float4 output = sum / gAccumCountTexture[pixelPos];
    
    gPrevOutputTextureSum[pixelPos] = sum;
    gOutputTexture[pixelPos] = float4(output.rgb, 1);

    updatePrevFrame(dispatchThreadId);

    //gOutputTexture[pixelPos] = float4(motion, motion, motion, 1.f);
}
