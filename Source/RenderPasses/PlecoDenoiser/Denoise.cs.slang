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

void updatePrevFrame(uint3 dtID)
{
    //prev frame is RW which allows for this
    gPrevOutputTexture[dtID.xy] = gOutputTexture[dtID.xy];
}

[numthreads(16, 16, 1)]
void denoise(uint3 dispatchThreadId : SV_DispatchThreadID)
{
    // get inputs
    const uint2 pixelPos = dispatchThreadId.xy;
    const float4 curColor = gInputTexture[pixelPos];
    const float4 motionVec = gInputMotionTexture[pixelPos];

    // weights of motion magnitude and color different magnitude (like bilateral)
    const float motionMagnitude = clamp(length(motionVec.xyz) * 100.f, 0, 1);
    const float colorDifference = clamp(length(gInputTexture[pixelPos].rgb - gPrevOutputTexture[pixelPos].rgb) * 200.f, 0, 1);
    const float invWeight = 1.f - motionMagnitude * colorDifference;

    // scale down all prior texture sum by inverse weight and add current output
    float4 sum = gPrevOutputTextureSum[pixelPos] * invWeight;
    sum += curColor;
    // also scale count so that output it normalized
    gAccumCountTexture[pixelPos] *= invWeight;
    gAccumCountTexture[pixelPos] += 1;

    // final output is weighted average
    float4 output = sum / gAccumCountTexture[pixelPos];
    
    gPrevOutputTextureSum[pixelPos] = sum;
    gOutputTexture[pixelPos] = float4(output.rgb, 1);

    updatePrevFrame(dispatchThreadId);
}
