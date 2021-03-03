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
#include "PlecoRayTracer.h"
#include "RenderGraph/RenderPassHelpers.h"


namespace
{
    const char kDesc[] = "Insert pass description here";

    const char kViewDirInput[] = "viewW";

    const ChannelList kInputChannels =
    {
        { "posW",           "gWorldPosition",             "World-space position (xyz) and foreground flag (w)"       },
        //{ "normalW",        "gWorldShadingNormal",        "World-space shading normal (xyz)"                         },
        //{ "tangentW",       "gWorldShadingTangent",       "World-space shading tangent (xyz) and sign (w)", true /* optional */ },
        { "faceNormalW",    "gWorldFaceNormal",           "Face normal in world space (xyz)",                        },
        //{ kViewDirInput,    "gWorldView",                 "World-space view direction (xyz)", true /* optional */    },
        { "mtlDiffOpacity", "gMaterialDiffuseOpacity",    "Material diffuse color (xyz) and opacity (w)"             },
        { "mtlSpecRough",   "gMaterialSpecularRoughness", "Material specular color (xyz) and roughness (w)"          },
        //{ "mtlEmissive",    "gMaterialEmissive",          "Material emissive color (xyz)"                            },
        { "mtlParams",      "gMaterialExtraParams",       "Material parameters (IoR, flags etc)"                     },
    };

    const ChannelList kOutputChannels =
    {
        { "color",          "gOutputColor",               "Output color (sum of direct and indirect)"                },
    };
}

// Don't remove this. it's required for hot-reload to function properly
extern "C" __declspec(dllexport) const char* getProjDir()
{
    return PROJECT_DIR;
}

extern "C" __declspec(dllexport) void getPasses(Falcor::RenderPassLibrary& lib)
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
    return Dictionary();
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
    // renderData holds the requested resources
    // auto& pTexture = renderData["src"]->asTexture();
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
    mpProgram = RtProgram::create(progDesc);

    // Create a sample generator.
    mpSampleGenerator = SampleGenerator::create(SAMPLE_GENERATOR_UNIFORM);
    assert(mpSampleGenerator);
}
