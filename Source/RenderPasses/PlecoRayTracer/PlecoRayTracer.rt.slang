// Pleco Ray Tracer slang
// http://cwyman.org/code/dxrTutors/tutors/Tutor4/tutorial04.md.html

#include "Utils/Math/MathConstants.slangh"

//__import Raytracing;
import Scene.Raytracing;
import Utils.Math.MathHelpers;
import Utils.Sampling.SampleGenerator;
import Experimental.Scene.Material.MaterialShading;
import Experimental.Scene.Lights.LightHelpers;

cbuffer OurDataCB
{
    uint gFrameCount;
};

Texture2D<float4> gWorldPosition;
Texture2D<float4> gWorldFaceNormal;
Texture2D<float4> gMaterialDiffuseOpacity;
Texture2D<float4> gMaterialSpecularRoughness;
Texture2D<float4> gMaterialEmissive;
Texture2D<float4> gMaterialExtraParams;

struct SimplePayload
{
    float3 color;
    bool terminated;
    float3 origin;
    float3 direction;
    uint numBounces;
    float throughput;

    SampleGenerator sampleGen;

    static SimplePayload create(SampleGenerator sg)
    {
        SimplePayload payload;
        payload.color = float3(0, 0, 0);
        payload.terminated = false;
        payload.origin = float3(0, 0, 0);
        payload.direction = float3(0, 0, 0);
        payload.numBounces = 0;
        payload.throughput = 1.0f;
        payload.sampleGen = sg;
        return payload;
    }
};

[shader("raygeneration")]
void RayGen()
{
    uint2 dispatchRaysIndex = DispatchRaysIndex().xy;
    uint2 dispatchRaysDimensions = DispatchRaysDimensions().xy;
    
    // Convert our ray index into a ray direction in world space.
    float2 pixelLocation = dispatchRaysIndex + float2(0.5f, 0.5f);
    float2 pixelCenter = pixelLocation / dispatchRaysDimensions;
    float2 ndc = float2(2, -2) * pixelCenter + float2(-1, 1);
    
    float3 rayDir = normalize(ndc.x * gScene.camera.data.cameraU +
                               ndc.y * gScene.camera.data.cameraV +
                                       gScene.camera.data.cameraW);

    //Create sample generator.
    SampleGenerator sg = SampleGenerator.create(dispatchRaysIndex, gFrameCount);
    
    // Initialize a ray structure for our ray tracer
    RayDesc ray;
    ray.TMin = 0.0f;
    ray.TMax = 1e+38f;
    
	// Initialize our ray payload (a per-ray, user-definable structure).
    SimplePayload payload = SimplePayload.create(sg);
    payload.origin = gScene.camera.data.posW;
    payload.direction = rayDir;

    // Trace our ray
    uint maxBounces = 3;
    for (uint i = 0; i < maxBounces && !payload.terminated; i++)
    {
        ray.Origin = payload.origin;
        ray.Direction = payload.direction;
        TraceRay(gRtScene, 0, 0xFF, 0, 1, 0, ray, payload);
    }

    gColor[dispatchRaysIndex] = float4(payload.color, 1.0f);
}

// Our miss shader's variables
cbuffer MissShaderCB
{
    float3 gBgColor;
};

// The output textures.  See bindings in C++ code.
//     -> gMatDif is visible in the miss shader
//     -> All textures are visible in the hit shaders
RWTexture2D<float4> gWsPos, gWsNorm, gMatDif, gMatSpec, gMatExtra, gMatEmis, gColor;

#define isValid(name) (is_valid_##name != 0)
static const bool kUseEmissiveLights = USE_EMISSIVE_LIGHTS;

[shader("miss")]
void Miss(inout SimplePayload payload)
{
    //gMatDif[DispatchRaysIndex().xy] = float4(gBgColor, 1.0f);
    payload.terminated = true;

    
    // Add contribution from env map in this direction.
    if (payload.numBounces > 0)
    {
        float3 envMap = gScene.envMap.eval(payload.direction);
        //payload.color += payload.color * envMap * payload.throughput;
    }
    // Draw env map background
    else
    {
        payload.color = gScene.envMap.eval(payload.direction);
    }
}

[shader("anyhit")]
void AnyHit(uniform HitShaderParams hitParams, inout SimplePayload payload, BuiltInTriangleIntersectionAttributes attributes)
{
     // Alpha test for non-opaque geometry.
    VertexData v = getVertexData(hitParams, PrimitiveIndex(), attributes);
    const uint materialID = gScene.getMaterialID(hitParams.getGlobalHitID());

    //ExplicitLodTextureSampler lodSampler = { 0 }; // Specify the tex lod/mip to use here
    //float4 baseColor = sampleTexture(gScene.materialResources[materialID].baseColor, gScene.materialResources[materialID].samplerState,
	//	v.texC, gScene.materials[materialID].baseColor, 1, lodSampler);

 //   bool test = (baseColor.a < gScene.materials[materialID].alphaThreshold);
    bool test = false;
    //if (alphaTest(v, gScene.materials[materialID], gScene.materialResources[materialID], 0.f))
    //{
    //    IgnoreHit();
    //}

    if (test)
    {
        IgnoreHit();
    }

}

[shader("closesthit")]
void ClosestHit(uniform HitShaderParams hitParams, inout SimplePayload payload, BuiltInTriangleIntersectionAttributes attributes)
{
	// Which pixel spawned our ray?
    uint2 idx = DispatchRaysIndex().xy;

    // Evaluate Falcor's material parameters at the hit point.
    // TODO: Implement texLOD to enable texture filtering in prepareShadingData().
    VertexData v = getVertexData(hitParams, PrimitiveIndex(), attributes);
    const uint materialID = gScene.getMaterialID(hitParams.getGlobalHitID());
    ShadingData shadeData = prepareShadingData(v, materialID, gScene.materials[materialID], gScene.materialResources[materialID], -WorldRayDirection(), 0.f);

	// Save out our G-buffer values to the specified output textures
    if(payload.numBounces == 0)
    {
        gWsPos[idx] = float4(shadeData.posW, 1.f);
        gWsNorm[idx] = float4(shadeData.N, length(shadeData.posW - gScene.camera.data.posW));
        gMatDif[idx] = float4(shadeData.diffuse, shadeData.opacity);
        gMatSpec[idx] = float4(shadeData.specular, shadeData.linearRoughness);
        gMatExtra[idx] = float4(shadeData.IoR,
                            shadeData.doubleSided ? 1.f : 0.f,
                            0.f, 0.f);
        gMatEmis[idx] = float4(shadeData.emissive, 1.f);
    }

    const uint lightCount = gScene.getLightCount();
    if (lightCount > 0)
    {
        // pick one of the light sources randomly
        const uint lightIndex = min(uint(sampleNext1D(payload.sampleGen) * lightCount), lightCount - 1);
        // sample light source
        LightData light = gScene.getLight(lightIndex);

        float3 L = -light.dirW;
        float3 N = shadeData.N;
        float3 V = -payload.direction;

        // diffuse
        float3 baseCol = shadeData.diffuse + shadeData.specular;
        float diffuseProduct = clamp(dot(N, L), 0, 1);
        float3 diffuseCol = baseCol * shadeData.opacity * diffuseProduct;

        // specular
        float3 R = 2.f * diffuseProduct * N - L;
        R = normalize(R);
        float specularProduct = pow(clamp(dot(R, V), 0, 1), 32.f);
        float3 specularLight = light.intensity * shadeData.linearRoughness * specularProduct;
        diffuseCol *= (1.f - specularProduct);
        float3 emissiveLight = shadeData.emissive * specularProduct;

        // total
        payload.color += (diffuseCol + specularLight + emissiveLight) * payload.throughput;
    }

    payload.throughput *= 0.0f;
    
    // new origin
    float3 prevOrigin = payload.origin;
    payload.origin = shadeData.computeNewRayOrigin();
    // Generate scatter ray as cosine-weighted direction over the hemisphere.
    float pdf = 0.f;
    float2 u = sampleNext2D(payload.sampleGen);
    float3 wi = sample_cosine_hemisphere_concentric(u, pdf);
    wi = fromLocal(wi, shadeData);
    payload.direction = wi;

    payload.numBounces++;
}
