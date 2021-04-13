cbuffer CB
{
    uint gFrameCount;
};

Texture2D<float4> gInputTexture; //input data
RWTexture2D<float4> gOutputTexture; //output data

static const bool kGaussianSigma = GAUSSIAN_SIGMA;

// 3x3 block of float4s
struct float4Block
{
    float4 m00, m01, m02, m03, m04,
           m10, m11, m12, m13, m14,
           m20, m21, m22, m23, m24,
           m30, m31, m32, m33, m34,
           m40, m41, m42, m43, m44;
};

float calcGaussian2D(float x, float y, float sigma)
{
    return (1.f / (2.f * 3.14159f * sigma * sigma)) * pow(2.71828f, -(x * x + y * y) / (2.f * sigma * sigma));
}

float calcGaussian1D(float x, float sigma)
{
    return (1.f / (sqrt(2.f * 3.14159f) * sigma)) * pow(2.71828f, -(x * x) / (2.f * sigma * sigma));
}

[numthreads(16, 16, 1)]
void denoise(uint3 dispatchThreadId : SV_DispatchThreadID)
{
    // PIXEL POSITIONS
    //  00 01 02
    //  10 11 12
    //  20 21 22

    // PIXEL POSITIONS
    //  00 01 02 03 04
    //  10 11 12 13 14
    //  20 21 22 23 24
    //  30 31 32 33 34
    //  40 41 42 43 44

    const uint2 PP22 = dispatchThreadId.xy;
    
    const uint2 PP00 = uint2(PP22.x - 2, PP22.y - 2);
    const uint2 PP01 = uint2(PP22.x - 1, PP22.y - 2);
    const uint2 PP02 = uint2(PP22.x, PP22.y - 2);
    const uint2 PP03 = uint2(PP22.x + 1, PP22.y - 2);
    const uint2 PP04 = uint2(PP22.x + 2, PP22.y - 2);

    const uint2 PP10 = uint2(PP22.x - 2, PP22.y - 1);
    const uint2 PP11 = uint2(PP22.x - 1, PP22.y - 1);
    const uint2 PP12 = uint2(PP22.x, PP22.y - 1);
    const uint2 PP13 = uint2(PP22.x + 1, PP22.y - 1);
    const uint2 PP14 = uint2(PP22.x + 2, PP22.y - 1);

    const uint2 PP20 = uint2(PP22.x - 2, PP22.y);
    const uint2 PP21 = uint2(PP22.x - 1, PP22.y);
    const uint2 PP23 = uint2(PP22.x + 1, PP22.y);
    const uint2 PP24 = uint2(PP22.x + 2, PP22.y);
    
    const uint2 PP30 = uint2(PP22.x - 2, PP22.y + 1);
    const uint2 PP31 = uint2(PP22.x - 1, PP22.y + 1);
    const uint2 PP32 = uint2(PP22.x, PP22.y + 1);
    const uint2 PP33 = uint2(PP22.x + 1, PP22.y + 1);
    const uint2 PP34 = uint2(PP22.x + 2, PP22.y + 1);

    const uint2 PP40 = uint2(PP22.x - 2, PP22.y + 2);
    const uint2 PP41 = uint2(PP22.x - 1, PP22.y + 2);
    const uint2 PP42 = uint2(PP22.x, PP22.y + 2);
    const uint2 PP43 = uint2(PP22.x + 1, PP22.y + 2);
    const uint2 PP44 = uint2(PP22.x + 2, PP22.y + 2);

    //Convolutional Filtering
    //--------------------------------------------
    float4Block block =
    {
        gInputTexture[PP00], gInputTexture[PP01], gInputTexture[PP02], gInputTexture[PP03], gInputTexture[PP04],
        gInputTexture[PP10], gInputTexture[PP11], gInputTexture[PP12], gInputTexture[PP13], gInputTexture[PP14],
        gInputTexture[PP20], gInputTexture[PP21], gInputTexture[PP22], gInputTexture[PP23], gInputTexture[PP24],
        gInputTexture[PP30], gInputTexture[PP31], gInputTexture[PP32], gInputTexture[PP33], gInputTexture[PP34],
        gInputTexture[PP40], gInputTexture[PP41], gInputTexture[PP42], gInputTexture[PP43], gInputTexture[PP44],
    };

    const float sigma = 0.5;
    
    //const float kernel[5][5] =
    //{
    //    calcGaussian(-2, -2, sigma), calcGaussian(-1, -2, sigma), calcGaussian(+0, -2, sigma), calcGaussian(+1, -2, sigma), calcGaussian(+2, -2, sigma),
    //    calcGaussian(-2, -1, sigma), calcGaussian(-1, -1, sigma), calcGaussian(+0, -1, sigma), calcGaussian(+1, -1, sigma), calcGaussian(+2, -1, sigma),
    //    calcGaussian(-2, +0, sigma), calcGaussian(-1, +0, sigma), calcGaussian(+0, +0, sigma), calcGaussian(+1, +0, sigma), calcGaussian(+2, +0, sigma),
    //    calcGaussian(-2, -1, sigma), calcGaussian(-1, -1, sigma), calcGaussian(+0, -1, sigma), calcGaussian(+1, -1, sigma), calcGaussian(+2, -1, sigma),
    //    calcGaussian(-2, +2, sigma), calcGaussian(-1, +2, sigma), calcGaussian(+0, +2, sigma), calcGaussian(+1, +2, sigma), calcGaussian(+2, +2, sigma),
    //};
    
    //float kernel[5][5] =
    //{
    //    1, 4, 6, 4, 1,
    //    4, 16, 24, 16, 4,
    //    6, 24, 36, 24, 6,
    //    4, 16, 24, 16, 4,
    //    1, 4, 6, 4, 1
    //};
    //float3x3 edgeDetectionKernel =
    //{
    //    -1, -1, -1
    //    - 1, 8, -1,
    //    -1, -1, -1
    //};
    //float3 filtered = float3(block.m00.r * kernel[0][0] + block.m01.r * kernel[0][1] + block.m02.r * kernel[0][2] + block.m10.r * kernel[1][0] + block.m11.r * kernel[1][1] + block.m12.r * kernel[1][2] + block.m20.r * kernel[2][0] + block.m21.r * kernel[2][1] + block.m22.r * kernel[2][2],
    //                        block.m00.g * kernel[0][0] + block.m01.g * kernel[0][1] + block.m02.g * kernel[0][2] + block.m10.g * kernel[1][0] + block.m11.g * kernel[1][1] + block.m12.g * kernel[1][2] + block.m20.g * kernel[2][0] + block.m21.g * kernel[2][1] + block.m22.g * kernel[2][2],
    //                        block.m00.b * kernel[0][0] + block.m01.b * kernel[0][1] + block.m02.b * kernel[0][2] + block.m10.b * kernel[1][0] + block.m11.b * kernel[1][1] + block.m12.b * kernel[1][2] + block.m20.b * kernel[2][0] + block.m21.b * kernel[2][1] + block.m22.b * kernel[2][2]);
    
    //float4Block filter =
    //{
    //    float4(0.979), float4(0.278), float4(0.940),
    //    float4(0.713), float4(0.048), float4(0.564),
    //    float4(0.604), float4(0.327), float4(0.853)
    //};

    // dot product
    //float3x3 dp =
    //{
    //    dot(block.m00, filter.m00), dot(block.m01, filter.m01), dot(block.m02, filter.m02),
    //    dot(block.m10, filter.m10), dot(block.m11, filter.m11), dot(block.m12, filter.m12),
    //    dot(block.m20, filter.m20), dot(block.m21, filter.m21), dot(block.m22, filter.m22)
    //};

    //float3 denoiseColStart = float3(gInputTexture[PP11].x, gInputTexture[PP11].y, gInputTexture[PP11].z);
    //denoiseColStart = float3(((denoiseColStart.x * dp._m00) + (denoiseColStart.y * dp._m01) + (denoiseColStart.z * dp._m02)),
    //                                ((denoiseColStart.x * dp._m10) + (denoiseColStart.y * dp._m11) + (denoiseColStart.z * dp._m12)),
    //                                ((denoiseColStart.x * dp._m20) + (denoiseColStart.y * dp._m21) + (denoiseColStart.z * dp._m22)));


    // simple left right / up down filter
    //----------------------------------
    //float4 lr = (gInputTexture[PP10] + gInputTexture[PP11] + gInputTexture[PP12]) / 3.0f;
    //float4 ud = (gInputTexture[PP01] + gInputTexture[PP11] + gInputTexture[PP21]) / 3.0f;
    //float4 combo = (lr + ud) / 2.0f;


    // bilateral filter
    float weight00 = calcGaussian1D(length(block.m00.rgb - block.m22.rgb), sigma) * calcGaussian1D(sqrt(8), sigma);
    float weight01 = calcGaussian1D(length(block.m01.rgb - block.m22.rgb), sigma) * calcGaussian1D(sqrt(5), sigma);
    float weight02 = calcGaussian1D(length(block.m02.rgb - block.m22.rgb), sigma) * calcGaussian1D(2.f, sigma);
    float weight03 = calcGaussian1D(length(block.m03.rgb - block.m22.rgb), sigma) * calcGaussian1D(sqrt(5), sigma);
    float weight04 = calcGaussian1D(length(block.m04.rgb - block.m22.rgb), sigma) * calcGaussian1D(sqrt(8), sigma);

    float weight10 = calcGaussian1D(length(block.m10.rgb - block.m22.rgb), sigma) * calcGaussian1D(sqrt(5), sigma);
    float weight11 = calcGaussian1D(length(block.m11.rgb - block.m22.rgb), sigma) * calcGaussian1D(sqrt(2), sigma);
    float weight12 = calcGaussian1D(length(block.m12.rgb - block.m22.rgb), sigma) * calcGaussian1D(1.f, sigma);
    float weight13 = calcGaussian1D(length(block.m13.rgb - block.m22.rgb), sigma) * calcGaussian1D(sqrt(2), sigma);
    float weight14 = calcGaussian1D(length(block.m14.rgb - block.m22.rgb), sigma) * calcGaussian1D(sqrt(5), sigma);

    float weight20 = calcGaussian1D(length(block.m20.rgb - block.m22.rgb), sigma) * calcGaussian1D(2.f, sigma);
    float weight21 = calcGaussian1D(length(block.m21.rgb - block.m22.rgb), sigma) * calcGaussian1D(1.f, sigma);
    float weight22 = calcGaussian1D(length(block.m22.rgb - block.m22.rgb), sigma) * calcGaussian1D(0.f, sigma);
    float weight23 = calcGaussian1D(length(block.m23.rgb - block.m22.rgb), sigma) * calcGaussian1D(1.f, sigma);
    float weight24 = calcGaussian1D(length(block.m24.rgb - block.m22.rgb), sigma) * calcGaussian1D(2.f, sigma);

    float weight30 = calcGaussian1D(length(block.m30.rgb - block.m22.rgb), sigma) * calcGaussian1D(sqrt(5), sigma);
    float weight31 = calcGaussian1D(length(block.m31.rgb - block.m22.rgb), sigma) * calcGaussian1D(sqrt(2), sigma);
    float weight32 = calcGaussian1D(length(block.m32.rgb - block.m22.rgb), sigma) * calcGaussian1D(1.f, sigma);
    float weight33 = calcGaussian1D(length(block.m33.rgb - block.m22.rgb), sigma) * calcGaussian1D(sqrt(2), sigma);
    float weight34 = calcGaussian1D(length(block.m34.rgb - block.m22.rgb), sigma) * calcGaussian1D(sqrt(5), sigma);

    float weight40 = calcGaussian1D(length(block.m40.rgb - block.m22.rgb), sigma) * calcGaussian1D(sqrt(8), sigma);
    float weight41 = calcGaussian1D(length(block.m41.rgb - block.m22.rgb), sigma) * calcGaussian1D(sqrt(5), sigma);
    float weight42 = calcGaussian1D(length(block.m42.rgb - block.m22.rgb), sigma) * calcGaussian1D(2.f, sigma);
    float weight43 = calcGaussian1D(length(block.m43.rgb - block.m22.rgb), sigma) * calcGaussian1D(sqrt(5), sigma);
    float weight44 = calcGaussian1D(length(block.m44.rgb - block.m22.rgb), sigma) * calcGaussian1D(sqrt(8), sigma);
    
    float weight = weight00 + weight01 + weight02 + weight03 + weight04 + 
                   weight10 + weight11 + weight12 + weight13 + weight14 +
                   weight20 + weight21 + weight23 + weight24 +
                   weight30 + weight31 + weight32 + weight33 + weight34 +
                   weight40 + weight41 + weight42 + weight43 + weight44;
    weight = weight <= 0 ? 1.f : weight;

    float3 filter00 = block.m00.rgb * calcGaussian1D(length(block.m00.rgb - block.m22.rgb), sigma) * calcGaussian1D(sqrt(8), sigma);
    float3 filter01 = block.m01.rgb * calcGaussian1D(length(block.m01.rgb - block.m22.rgb), sigma) * calcGaussian1D(sqrt(5), sigma);
    float3 filter02 = block.m02.rgb * calcGaussian1D(length(block.m02.rgb - block.m22.rgb), sigma) * calcGaussian1D(2.f, sigma);
    float3 filter03 = block.m03.rgb * calcGaussian1D(length(block.m03.rgb - block.m22.rgb), sigma) * calcGaussian1D(sqrt(5), sigma);
    float3 filter04 = block.m04.rgb * calcGaussian1D(length(block.m04.rgb - block.m22.rgb), sigma) * calcGaussian1D(sqrt(8), sigma);

    float3 filter10 = block.m10.rgb * calcGaussian1D(length(block.m10.rgb - block.m22.rgb), sigma) * calcGaussian1D(sqrt(5), sigma);
    float3 filter11 = block.m11.rgb * calcGaussian1D(length(block.m11.rgb - block.m22.rgb), sigma) * calcGaussian1D(sqrt(2), sigma);
    float3 filter12 = block.m12.rgb * calcGaussian1D(length(block.m12.rgb - block.m22.rgb), sigma) * calcGaussian1D(1.f, sigma);
    float3 filter13 = block.m13.rgb * calcGaussian1D(length(block.m13.rgb - block.m22.rgb), sigma) * calcGaussian1D(sqrt(2), sigma);
    float3 filter14 = block.m14.rgb * calcGaussian1D(length(block.m14.rgb - block.m22.rgb), sigma) * calcGaussian1D(sqrt(5), sigma);

    float3 filter20 = block.m20.rgb * calcGaussian1D(length(block.m20.rgb - block.m22.rgb), sigma) * calcGaussian1D(2.f, sigma);
    float3 filter21 = block.m21.rgb * calcGaussian1D(length(block.m21.rgb - block.m22.rgb), sigma) * calcGaussian1D(1.f, sigma);
    float3 filter22 = block.m22.rgb * calcGaussian1D(length(block.m22.rgb - block.m22.rgb), sigma) * calcGaussian1D(0.f, sigma);
    float3 filter23 = block.m23.rgb * calcGaussian1D(length(block.m23.rgb - block.m22.rgb), sigma) * calcGaussian1D(1.f, sigma);
    float3 filter24 = block.m24.rgb * calcGaussian1D(length(block.m24.rgb - block.m22.rgb), sigma) * calcGaussian1D(2.f, sigma);

    float3 filter30 = block.m30.rgb * calcGaussian1D(length(block.m30.rgb - block.m22.rgb), sigma) * calcGaussian1D(sqrt(5), sigma);
    float3 filter31 = block.m31.rgb * calcGaussian1D(length(block.m31.rgb - block.m22.rgb), sigma) * calcGaussian1D(sqrt(2), sigma);
    float3 filter32 = block.m32.rgb * calcGaussian1D(length(block.m32.rgb - block.m22.rgb), sigma) * calcGaussian1D(1.f, sigma);
    float3 filter33 = block.m33.rgb * calcGaussian1D(length(block.m33.rgb - block.m22.rgb), sigma) * calcGaussian1D(sqrt(2), sigma);
    float3 filter34 = block.m34.rgb * calcGaussian1D(length(block.m34.rgb - block.m22.rgb), sigma) * calcGaussian1D(sqrt(5), sigma);

    float3 filter40 = block.m40.rgb * calcGaussian1D(length(block.m40.rgb - block.m22.rgb), sigma) * calcGaussian1D(sqrt(8), sigma);
    float3 filter41 = block.m41.rgb * calcGaussian1D(length(block.m41.rgb - block.m22.rgb), sigma) * calcGaussian1D(sqrt(5), sigma);
    float3 filter42 = block.m42.rgb * calcGaussian1D(length(block.m42.rgb - block.m22.rgb), sigma) * calcGaussian1D(2.f, sigma);
    float3 filter43 = block.m43.rgb * calcGaussian1D(length(block.m43.rgb - block.m22.rgb), sigma) * calcGaussian1D(sqrt(5), sigma);
    float3 filter44 = block.m44.rgb * calcGaussian1D(length(block.m44.rgb - block.m22.rgb), sigma) * calcGaussian1D(sqrt(8), sigma);
    
    float3 denoised = filter00 + filter01 + filter02 + filter03 + filter04 +
                   filter10 + filter11 + filter12 + filter13 + filter14 +
                   filter20 + filter21 + filter23 + filter24 +
                   filter30 + filter31 + filter32 + filter33 + filter34 +
                   filter40 + filter41 + filter42 + filter43 + filter44;
    denoised *= (1.f / weight);
    //denoised = /*isnan(denoised) ||*/ denoised == float3(0, 0, 0) ? block.m22.rgb : denoised;
    
    //const float4 pixelCol = combo;
    //const float4 pixelCol = float4(denoiseColStart.x, denoiseColStart.y, denoiseColStart.z, gInputTexture[PP11].w);
    //const float4 pixelCol = gInputTexture[PP11];
    
    gOutputTexture[PP22] = float4(denoised, 1); // just output directly 
}
