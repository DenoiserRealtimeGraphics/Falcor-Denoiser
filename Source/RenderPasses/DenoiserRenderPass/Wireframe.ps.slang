cbuffer PerFrameCB
{
    float4 gColor;
};

float4 main() : SV_TARGET
{
    return gColor;
}