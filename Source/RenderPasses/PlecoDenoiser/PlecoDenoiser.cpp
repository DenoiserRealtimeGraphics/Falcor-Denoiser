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
#include "PlecoDenoiser.h"
#include "RenderGraph/RenderPassHelpers.h"

namespace
{
    const char kDesc[] = "Insert pass description here";

    const char kShaderFile[] = "RenderPasses/PlecoDenoiser/Denoise.cs.slang";
    const char kInputChannel[] = "Input_Color";
    const char kInputMotionChannel[] = "Input_MotionVector";
    const char kOutputChannel[] = "Output_Color";
    const char kOutputSumChannel[] = "Output_Sum";
    const char kAccumCountChannel[] = "Accum_Count";
}

// Don't remove this. it's required for hot-reload to function properly
extern "C" __declspec(dllexport) const char* getProjDir()
{
    return PROJECT_DIR;
}

extern "C" __declspec(dllexport) void getPasses(Falcor::RenderPassLibrary& lib)
{
    lib.registerClass("PlecoDenoiser", kDesc, PlecoDenoiser::create);
}

PlecoDenoiser::PlecoDenoiser(const Dictionary& dict)
{
    mpProgram = ComputeProgram::createFromFile(kShaderFile, "denoise", Program::DefineList(), Shader::CompilerFlags::TreatWarningsAsErrors);
    mpProgram->addDefine("GAUSSIAN_SIGMA", std::to_string(mGaussianSigma));
    mpVars = ComputeVars::create(mpProgram->getReflector());
    mpState = ComputeState::create();
}


PlecoDenoiser::SharedPtr PlecoDenoiser::create(RenderContext* pRenderContext, const Dictionary& dict)
{
    SharedPtr pPass = SharedPtr(new PlecoDenoiser(dict));
    return pPass;
}

std::string PlecoDenoiser::getDesc() { return kDesc; }

Dictionary PlecoDenoiser::getScriptingDictionary()
{
    return Dictionary();
}

RenderPassReflection PlecoDenoiser::reflect(const CompileData& compileData)
{
    // Define the required resources here
    RenderPassReflection reflector;
    reflector.addOutput(kOutputChannel, "Output from Pleco Denoiser").bindFlags(ResourceBindFlags::RenderTarget | ResourceBindFlags::UnorderedAccess | ResourceBindFlags::ShaderResource).format(ResourceFormat::RGBA32Float);
    reflector.addOutput(kOutputSumChannel, "Output Sum from Pleco Denoiser").bindFlags(ResourceBindFlags::RenderTarget | ResourceBindFlags::UnorderedAccess | ResourceBindFlags::ShaderResource).format(ResourceFormat::RGBA32Float);
    reflector.addOutput(kAccumCountChannel, "Accum Count").bindFlags(ResourceBindFlags::RenderTarget | ResourceBindFlags::UnorderedAccess | ResourceBindFlags::ShaderResource).format(ResourceFormat::RGBA32Float);
    reflector.addInput(kInputChannel, "Input from Pleco Ray Tracer").bindFlags(ResourceBindFlags::ShaderResource);
    reflector.addInput(kInputMotionChannel, "Motion Input").bindFlags(ResourceBindFlags::ShaderResource);
    return reflector;
}

void PlecoDenoiser::execute(RenderContext* pRenderContext, const RenderData& renderData)
{
    // Update refresh flag if options that affect the output have changed.
    auto& dict = renderData.getDictionary();
    if (mOptionsChanged)
    {
        auto flags = dict.getValue(kRenderPassRefreshFlags, RenderPassRefreshFlags::None);
        dict[Falcor::kRenderPassRefreshFlags] = flags | Falcor::RenderPassRefreshFlags::RenderOptionsChanged;
        mOptionsChanged = false;
    }

    // renderData holds the requested resources
    // auto& pTexture = renderData["src"]->asTexture();

    InternalDictionary& dictionary = renderData.getDictionary();

    if (mpScene)
    {
        Scene::UpdateFlags sceneUpdateFlags = mpScene->getUpdates();

        //check on if the camera has moved (might be useful)
        if (is_set(sceneUpdateFlags, Scene::UpdateFlags::CameraPropertiesChanged))
        {
            if ((mpScene->getCamera()->getChanges() &
                ~(Camera::Changes::Jitter | Camera::Changes::History)) != Camera::Changes::None)
            {
                //we have significant camera movement
            }
        }
    }

    mpProgram->addDefine("GAUSSIAN_SIGMA", std::to_string(mGaussianSigma));

    //input buffer
    Texture::SharedPtr inputBuffer = renderData[kInputChannel]->asTexture();
    assert(inputBuffer);

    //input motion buffer
    Texture::SharedPtr inputMotionBuffer = renderData[kInputMotionChannel]->asTexture();
    assert(inputMotionBuffer);

    //output buffer
    Texture::SharedPtr outputBuffer = renderData[kOutputChannel]->asTexture();
    assert(outputBuffer);

    //output sum buffer
    Texture::SharedPtr outputSumBuffer = renderData[kOutputSumChannel]->asTexture();
    assert(outputSumBuffer);

    //output sum buffer
    Texture::SharedPtr accumCountBuffer = renderData[kAccumCountChannel]->asTexture();
    assert(accumCountBuffer);

    //assign variables in shader CBs
    mpVars["CB"]["gFrameCount"] = ++mFrameCount;

    //bind textures
    mpVars["gInputTexture"] = inputBuffer;
    mpVars["gInputMotionTexture"] = inputMotionBuffer;
    mpVars["gOutputTexture"] = outputBuffer;
    mpVars["gPrevOutputTextureSum"] = outputSumBuffer;
    mpVars["gAccumCountTexture"] = accumCountBuffer;
    //prior frame info
    mpVars["gPrevOutputTexture"] = mpPrevFrame;

    //make sure program is okay and set it
    assert(mpProgram);
    mpState->setProgram(mpProgram);

    //for computer shader, threads accounted for in size of uint3 for dims
    uint3 numberOfGroups = div_round_up(uint3(inputBuffer->getWidth(), inputBuffer->getHeight(), 1u), mpProgram->getReflector()->getThreadGroupSize());
    pRenderContext->dispatch(mpState.get(), mpVars.get(), numberOfGroups);
}

void PlecoDenoiser::setScene(RenderContext* pRenderContext, const Scene::SharedPtr& pScene)
{
    mpScene = pScene;
    mFrameCount = 0;
}

void PlecoDenoiser::renderUI(Gui::Widgets& widget)
{
    bool dirty = false;

    dirty |= widget.var("Gaussian Sigma", mGaussianSigma, 0.f, 9999.f);

    if(dirty)
    {
        mOptionsChanged = true;
    }
}
