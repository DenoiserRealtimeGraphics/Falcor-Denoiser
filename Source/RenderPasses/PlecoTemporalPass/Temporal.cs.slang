cbuffer CB
{
    uint gFrameCount;
};

Texture2D<float4> gInputTexture; //input data
Texture2D<float4> gMotionTexture;   //motion vector
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
    //const uint2 PP00 = dtID.xy;
    //float3 inp = gInputTexture[PP00].rgb;
    //gOutputTexture[PP00] = float4(0.2f * inp + 0.8f * ema(dtID), 1.0f);

    //two by two kernel
    int2 offset[4] = { int2(-1,-1), int2(1,1), int2(-1,1), int2(1,-1) };

    float3 colAvg = gInputTexture[dtID.xy].rgb;
    float3 colDbl = colAvg * colAvg;
    
    for (int i = 0; i < 4; ++i)
    {
        float3 offsetCol = gInputTexture[dtID.xy + offset[i]].rgb;
        colAvg += offsetCol;
        colDbl += offsetCol * offsetCol;
    }

    //0.2 for 1 / (4 offset + 1 tested pixel)
    colAvg *= 0.2f;
    colDbl *= 0.2f;

    float3 kernel = { 0.25f, 0.375f, 0.25f };

    float3 sigma = sqrt(max(0.0f, colDbl - colAvg * colAvg));
    float3 colMin = colAvg - kernel * sigma;
    float3 colMax = colAvg + kernel * sigma;

    float2 motionAvg = gMotionTexture[dtID.xy].xy;
    for (int k = 0; k < 4; ++k)
    {
        float2 offsetMotion = gMotionTexture[dtID.xy + offset[k]].xy;
        if (dot(offsetMotion, offsetMotion) > dot(motionAvg, motionAvg))
        {
            motionAvg = offsetMotion;
        }
    }

    //bilerp
    //  t vals
    float2 t0, t1;
    t0 = motionAvg - (floor(motionAvg - 0.5f) + 0.5f);
    
    //  one lerp per axis
    float3 prevCol = gPrevOutputTexture[dtID.xy].rgb;
    float3 motX = prevCol + float3(t0.x) * (colAvg - prevCol);
    float3 motY = prevCol + float3(t0.y) * (colAvg - prevCol);
    float3 motColAvg = (motX + motY) * 0.5f;
    
    float3 prevColAdjusted = clamp(motColAvg, colMin, colMax);
    //gOutputTexture[dtID.xy] = float4(lerp(prevColAdjusted, colAvg, 0.5f).rgb, 1.0f);
    gOutputTexture[dtID.xy] = float4(0.2f * gInputTexture[dtID.xy].rgb + 0.8f * lerp(prevColAdjusted, colAvg, 0.5f).rgb, 1.0f);
    //gOutputTexture[dtID.xy] = float4(motColAvg, 1.0f);

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
