from falcor import *

def render_graph_DefaultRenderGraph():
    g = RenderGraph('DefaultRenderGraph')
    loadRenderPassLibrary('BSDFViewer.dll')
    loadRenderPassLibrary('AccumulatePass.dll')
    loadRenderPassLibrary('TemporalDelayPass.dll')
    loadRenderPassLibrary('Antialiasing.dll')
    loadRenderPassLibrary('SSAO.dll')
    loadRenderPassLibrary('DenoiserRenderPass.dll')
    loadRenderPassLibrary('BlitPass.dll')
    loadRenderPassLibrary('CSM.dll')
    loadRenderPassLibrary('DebugPasses.dll')
    loadRenderPassLibrary('DepthPass.dll')
    loadRenderPassLibrary('ErrorMeasurePass.dll')
    loadRenderPassLibrary('WhittedRayTracer.dll')
    loadRenderPassLibrary('ForwardLightingPass.dll')
    loadRenderPassLibrary('GBuffer.dll')
    loadRenderPassLibrary('ImageLoader.dll')
    loadRenderPassLibrary('MegakernelPathTracer.dll')
    loadRenderPassLibrary('MinimalPathTracer.dll')
    loadRenderPassLibrary('PlecoBilateralPass.dll')
    loadRenderPassLibrary('PassLibraryTemplate.dll')
    loadRenderPassLibrary('PixelInspectorPass.dll')
    loadRenderPassLibrary('PlecoDenoiser.dll')
    loadRenderPassLibrary('PlecoRayTracer.dll')
    loadRenderPassLibrary('PlecoTemporalPass.dll')
    loadRenderPassLibrary('SceneDebugger.dll')
    loadRenderPassLibrary('SkyBox.dll')
    loadRenderPassLibrary('SVGFPass.dll')
    loadRenderPassLibrary('ToneMapper.dll')
    loadRenderPassLibrary('Utils.dll')
    SideBySidePass = createPass('SideBySidePass', {'splitLocation': 0.5, 'showTextLabels': False, 'leftLabel': 'Left side', 'rightLabel': 'Right side'})
    g.addPass(SideBySidePass, 'SideBySidePass')
    PlecoTemporalPass = createPass('PlecoTemporalPass')
    g.addPass(PlecoTemporalPass, 'PlecoTemporalPass')
    GBufferRT = createPass('GBufferRT', {'samplePattern': SamplePattern.Center, 'sampleCount': 16, 'disableAlphaTest': False, 'adjustShadingNormals': True, 'forceCullMode': False, 'cull': CullMode.CullBack, 'texLOD': LODMode.UseMip0})
    g.addPass(GBufferRT, 'GBufferRT')
    PlecoRayTracer = createPass('PlecoRayTracer')
    g.addPass(PlecoRayTracer, 'PlecoRayTracer')
    g.addEdge('GBufferRT.posW', 'PlecoRayTracer.iWorldPosition')
    g.addEdge('GBufferRT.normW', 'PlecoRayTracer.iWorldNormal')
    g.addEdge('GBufferRT.diffuseOpacity', 'PlecoRayTracer.iMaterialDiffuse')
    g.addEdge('GBufferRT.specRough', 'PlecoRayTracer.iMaterialSpecRough')
    g.addEdge('GBufferRT.emissive', 'PlecoRayTracer.iMaterialEmissive')
    g.addEdge('GBufferRT.matlExtra', 'PlecoRayTracer.iMaterialExtraParams')
    g.addEdge('PlecoRayTracer.oColor', 'PlecoTemporalPass.Input_From_PlecoRT')
    g.addEdge('GBufferRT.mvec', 'PlecoTemporalPass.From_RTBuffer')
    g.addEdge('PlecoTemporalPass.Output_From_PD', 'SideBySidePass.leftInput')
    g.addEdge('PlecoRayTracer.oColor', 'SideBySidePass.rightInput')
    g.markOutput('SideBySidePass.output')
    return g

DefaultRenderGraph = render_graph_DefaultRenderGraph()
try: m.addGraph(DefaultRenderGraph)
except NameError: None
