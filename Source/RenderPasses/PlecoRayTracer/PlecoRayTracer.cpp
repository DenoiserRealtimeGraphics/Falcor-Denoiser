/***************************************************************************
 # Copyright (c) 2020, NVIDIA CORPORATION. All rights reserved.
 #
 # Redistribution and use in source and binary forms, with or without
 # modification, are permitted provided that the following conditions
 # are met:
 #  * Redistributions of source code must retain the above copyright
 #    notice, this list of conditions and the following disclaimer.
 #  * Redistributions in binary form must reproduce the above copyright
 #    notice, this list of conditions and the following disclaimer in the
 #    documentation and/or other materials provided with the distribution.
 #  * Neither the name of NVIDIA CORPORATION nor the names of its
 #    contributors may be used to endorse or promote products derived
 #    from this software without specific prior written permission.
 #
 # THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS "AS IS" AND ANY
 # EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 # IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
 # PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL THE COPYRIGHT OWNER OR
 # CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
 # EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
 # PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
 # PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY
 # OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 # (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
 # OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 **************************************************************************/

// http://cwyman.org/code/dxrTutors/tutors/Tutor4/tutorial04.md.html

#include "PlecoRayTracer.h"
#include "RenderGraph/RenderPassHelpers.h"


namespace
{
    const char kDesc[] = "Insert pass description here";
    const uint32_t kMaxPayloadSizeBytes = 80u;

    const ChannelList kInputChannels =
    {
        { "iWorldPosition",           "gWorldPosition",             "World-space position (xyz) and foreground flag (w)"       },
        //{ "normalW",        "gWorldShadingNormal",        "World-space shading normal (xyz)"                         },
        //{ "tangentW",       "gWorldShadingTangent",       "World-space shading tangent (xyz) and sign (w)", true /* optional */ },
        { "iWorldNormal",    "gWorldFaceNormal",           "Face normal in world space (xyz)",                        },
        //{ kViewDirInput,    "gWorldView",                 "World-space view direction (xyz)", true /* optional */    },
        { "iMaterialDiffuse", "gMaterialDiffuseOpacity",    "Material diffuse color (xyz) and opacity (w)"             },
        { "iMaterialSpecRough",   "gMaterialSpecularRoughness", "Material specular color (xyz) and roughness (w)"          },
        { "iMaterialEmissive",    "gMaterialEmissive",          "Material emissive color (xyz)"                            },
        { "iMaterialExtraParams",      "gMaterialExtraParams",       "Material parameters (IoR, flags etc)"                     },
    };

    const ChannelList kOutputChannels =
    {
        { "oWorldPosition",          "gWsPos",               ""                },
        { "oWorldNormal",          "gWsNorm",               ""                },
        { "oMaterialDiffuse",          "gMatDif",               ""                },
        { "oMaterialSpecRough",          "gMatSpec",               ""                },
        { "oMaterialExtraParams",          "gMatExtra",               ""                },
        { "oMaterialEmissive",          "gMatEmis",               ""                },
        { "oColor",          "gColor",               ""                },
    };
}

// Don't remove this. it's required for hot-reload to function properly
extern "C" __declspec(dllexport) const char* getProjDir()
{
    return PROJECT_DIR;
}

extern "C" __declspec(dllexport) void getPasses(Falcor::RenderPassLibrary & lib)
{
    lib.registerClass("PlecoRayTracer", kDesc, PlecoRayTracer::create);
}

PlecoRayTracer::SharedPtr PlecoRayTracer::create(RenderContext* pRenderContext, const Dictionary& dict)
{
    SharedPtr pPass = SharedPtr(new PlecoRayTracer(dict));
    return pPass;
}

std::string PlecoRayTracer::getDesc() { return kDesc; }

Dictionary PlecoRayTracer::getScriptingDictionary()
{
    return Dictionary{};
}

RenderPassReflection PlecoRayTracer::reflect(const CompileData& compileData)
{
    // Define the required resources here
    RenderPassReflection reflector;
    //reflector.addInput("src");
    addRenderPassInputs(reflector, kInputChannels);
    //reflector.addOutput("dst");
    addRenderPassOutputs(reflector, kOutputChannels);
    return reflector;
}

void PlecoRayTracer::execute(RenderContext* pRenderContext, const RenderData& renderData)
{
    // get and clear output channels
    Texture::SharedPtr pWsPos = renderData["oWorldPosition"]->asTexture();
    pRenderContext->clearTexture(pWsPos.get());
    Texture::SharedPtr pWsNorm = renderData["oWorldNormal"]->asTexture();
    pRenderContext->clearTexture(pWsNorm.get());
    Texture::SharedPtr pMatDif = renderData["oMaterialDiffuse"]->asTexture();
    pRenderContext->clearTexture(pMatDif.get());
    Texture::SharedPtr pMatSpec = renderData["oMaterialSpecRough"]->asTexture();
    pRenderContext->clearTexture(pMatSpec.get());
    Texture::SharedPtr pMatExtra = renderData["oMaterialExtraParams"]->asTexture();
    pRenderContext->clearTexture(pMatExtra.get());
    Texture::SharedPtr pMatEmis = renderData["oMaterialEmissive"]->asTexture();
    pRenderContext->clearTexture(pMatEmis.get());

    Texture::SharedPtr pColor = renderData["oColor"]->asTexture();
    pRenderContext->clearTexture(pColor.get());
    //Texture* pMatEmit = renderData["Emissive"]->asTexture().get();
    //pRenderContext->clearTexture(pMatEmit);

    // For optional I/O resources, set 'is_valid_<name>' defines to inform the program of which ones it can access.
    // TODO: This should be moved to a more general mechanism using Slang.
    mpProgram->addDefines(getValidResourceDefines(kInputChannels, renderData));
    mpProgram->addDefines(getValidResourceDefines(kOutputChannels, renderData));
    mpProgram->addDefine("USE_EMISSIVE_LIGHTS", mpScene->useEmissiveLights() ? "1" : "0");   //access emissive lights in the scene


    // prepare vars
    if (!mpVars)
    {
        assert(mpScene);
        assert(mpProgram);

        // Configure program.
        mpProgram->addDefines(mpSampleGenerator->getDefines());

        // Create program variables for the current program/scene.
        // This may trigger shader compilation. If it fails, throw an exception to abort rendering.
        mpVars = RtProgramVars::create(mpProgram, mpScene);

        // Bind utility classes into shared data.
        ShaderVar pGlobalVars = mpVars->getRootVar();
        bool success = mpSampleGenerator->setShaderData(pGlobalVars);
        if (!success) throw std::exception("Failed to bind sample generator");
    }
    assert(mpVars);

    // Request the light collection if emissive lights are enabled.
    if (mpScene->getRenderSettings().useEmissiveLights)
    {
        mpScene->getLightCollection(pRenderContext);
    }

    // set miss shader constants
    //const EntryPointGroupVars::SharedPtr missVars = mpVars->getMissVars(0);
    //assert(missVars);
    //missVars["MissShaderCB"]["gBgColor"] = mBgColor;
    mpVars["MissShaderCB"]["gBgColor"] = mBgColor;
    mpVars["OurDataCB"]["gFrameCount"] = mFrameCount;
    //missVars["gMatDiff"] = pMatDif;

    // bind input textures
    mpVars["gWorldPosition"] = renderData["iWorldPosition"]->asTexture();
    mpVars["gWorldFaceNormal"] = renderData["iWorldNormal"]->asTexture();
    mpVars["gMaterialDiffuseOpacity"] = renderData["iMaterialDiffuse"]->asTexture();
    mpVars["gMaterialSpecularRoughness"] = renderData["iMaterialSpecRough"]->asTexture();
    mpVars["gMaterialExtraParams"] = renderData["iMaterialExtraParams"]->asTexture();

    // bind output textures
    mpVars["gWsPos"] = pWsPos;
    mpVars["gWsNorm"] = pWsNorm;
    mpVars["gMatDif"] = pMatDif;
    mpVars["gMatSpec"] = pMatSpec;
    mpVars["gMatExtra"] = pMatExtra;
    mpVars["gMatEmis"] = pMatEmis;
    mpVars["gColor"] = pColor;

    // Get dimensions of ray dispatch. TODO: figure this out
    const uint2 targetDim = renderData.getDefaultTextureDims();
    assert(targetDim.x > 0 && targetDim.y > 0);

    // Launch our ray tracing
    mpScene->raytrace(pRenderContext, mpProgram.get(), mpVars, uint3(targetDim, 1));

    ++mFrameCount;
}

void PlecoRayTracer::renderUI(Gui::Widgets& widget)
{
}

void PlecoRayTracer::setScene(RenderContext* pRenderContext, const Scene::SharedPtr& pScene)
{
    // clear data from previous scene
    mpVars = nullptr;
    mFrameCount = 0;

    mpScene = pScene;
    if (pScene)
    {
        mpProgram->addDefines(pScene->getSceneDefines());
    }
}

PlecoRayTracer::PlecoRayTracer(const Dictionary& dict)
{
    RtProgram::Desc progDesc;
    // add more libraries to split into multiple files
    progDesc.addShaderLibrary("RenderPasses/PlecoRayTracer/PlecoRayTracer.rt.slang");
    progDesc.setRayGen("RayGen");
    progDesc.addHitGroup(0, "ClosestHit", "AnyHit");
    progDesc.addMiss(0, "Miss");
    mpProgram = RtProgram::create(progDesc, kMaxPayloadSizeBytes);

    // Create a sample generator.
    mpSampleGenerator = SampleGenerator::create(SAMPLE_GENERATOR_UNIFORM);
    assert(mpSampleGenerator);
}
