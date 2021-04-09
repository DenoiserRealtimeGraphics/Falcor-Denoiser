cbuffer CB
{
    uint gFrameCount;
};

Texture2D<float4> gInputTexture;        //input data
RWTexture2D<float4> gOutputTexture;     //output data

[numthreads(16, 16, 1)]
void denoise(uint3 dispatchThreadId : SV_DispatchThreadID)
{
    const uint2 positionOfPixel = dispatchThreadId.xy;
    const float4 pixelCol = gInputTexture[positionOfPixel];
    gOutputTexture[positionOfPixel] = pixelCol;                 // just output directly 
}
