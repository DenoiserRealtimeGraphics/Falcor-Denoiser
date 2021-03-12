// Pleco Ray Tracer slang
// http://cwyman.org/code/dxrTutors/tutors/Tutor4/tutorial04.md.html

#include "Utils/Math/MathConstants.slangh"

//__import Raytracing;
import Scene.Raytracing;
import Utils.Math.MathHelpers;
import Utils.Sampling.SampleGenerator;
import Experimental.Scene.Material.MaterialShading;
import Experimental.Scene.Lights.LightHelpers;

// A dummy payload for this simple ray; never used
struct SimplePayload
{
    bool dummyValue;
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

    // Initialize a ray structure for our ray tracer
    RayDesc ray = { gScene.camera.data.posW, 0.0f, rayDir, 1e+38f };

	// Initialize our ray payload (a per-ray, user-definable structure).
    SimplePayload payload = { false };

    // Trace our ray
    TraceRay(gRtScene, RAY_FLAG_NONE, 0xFF, 0, 1, 0, ray, payload);
}

// Our miss shader's variables
cbuffer MissShaderCB
{
    float3 gBgColor;
};

// The output textures.  See bindings in C++ code.
//     -> gMatDif is visible in the miss shader
//     -> All textures are visible in the hit shaders
RWTexture2D<float4> gWsPos, gWsNorm, gMatDif, gMatSpec, gMatExtra;

[shader("miss")]
void Miss(inout SimplePayload payload)
{
    gMatDif[DispatchRaysIndex().xy] = float4(gBgColor, 1.0f);
}



[shader("anyhit")]
void AnyHit(uniform HitShaderParams hitParams, inout SimplePayload payload, BuiltInTriangleIntersectionAttributes attributes : SV_IntersectionAttributes)
{
     // Alpha test for non-opaque geometry.
    VertexData v = getVertexData(hitParams, PrimitiveIndex(), attributes);
    const uint materialID = gScene.getMaterialID(hitParams.getGlobalHitID());
    if (alphaTest(v, gScene.materials[materialID], gScene.materialResources[materialID], 0.f))
    {
        IgnoreHit();
    }
}

[shader("closesthit")]
void ClosestHit(uniform HitShaderParams hitParams, inout SimplePayload payload, BuiltInTriangleIntersectionAttributes attributes : SV_IntersectionAttributes)
{
	// Which pixel spawned our ray?
    uint2 idx = DispatchRaysIndex().xy;

    // Evaluate Falcor's material parameters at the hit point.
    // TODO: Implement texLOD to enable texture filtering in prepareShadingData().
    VertexData v = getVertexData(hitParams, PrimitiveIndex(), attributes);
    const uint materialID = gScene.getMaterialID(hitParams.getGlobalHitID());
    ShadingData shadeData = prepareShadingData(v, materialID, gScene.materials[materialID], gScene.materialResources[materialID], -WorldRayDirection(), 0.f);

	// Save out our G-buffer values to the specified output textures
	gWsPos[idx] = float4(shadeData.posW, 1.f);
	gWsNorm[idx] = float4(shadeData.N, length(shadeData.posW - gScene.camera.data.posW));
	gMatDif[idx] = float4(shadeData.diffuse, shadeData.opacity);
	gMatSpec[idx] = float4(shadeData.specular, shadeData.linearRoughness);
	gMatExtra[idx] = float4(shadeData.IoR, 
                            shadeData.doubleSided ? 1.f : 0.f, 
                            0.f, 0.f);
}
