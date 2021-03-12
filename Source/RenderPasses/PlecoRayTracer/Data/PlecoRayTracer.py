from falcor import *

def render_graph_DefaultRenderGraph():
    g = RenderGraph('DefaultRenderGraph')
    loadRenderPassLibrary('SceneDebugger.dll')
    loadRenderPassLibrary('BSDFViewer.dll')
    loadRenderPassLibrary('AccumulatePass.dll')
    loadRenderPassLibrary('DepthPass.dll')
    loadRenderPassLibrary('Antialiasing.dll')
    loadRenderPassLibrary('ImageLoader.dll')
    loadRenderPassLibrary('DenoiserRenderPass.dll')
    loadRenderPassLibrary('BlitPass.dll')
    loadRenderPassLibrary('DebugPasses.dll')
    loadRenderPassLibrary('CSM.dll')
    loadRenderPassLibrary('ErrorMeasurePass.dll')
    loadRenderPassLibrary('ForwardLightingPass.dll')
    loadRenderPassLibrary('GBuffer.dll')
    loadRenderPassLibrary('MegakernelPathTracer.dll')
    loadRenderPassLibrary('MinimalPathTracer.dll')
    loadRenderPassLibrary('PassLibraryTemplate.dll')
    loadRenderPassLibrary('PixelInspectorPass.dll')
    loadRenderPassLibrary('PlecoRayTracer.dll')
    loadRenderPassLibrary('SSAO.dll')
    loadRenderPassLibrary('SkyBox.dll')
    loadRenderPassLibrary('SVGFPass.dll')
    loadRenderPassLibrary('TemporalDelayPass.dll')
    loadRenderPassLibrary('ToneMapper.dll')
    loadRenderPassLibrary('Utils.dll')
    loadRenderPassLibrary('WhittedRayTracer.dll')
    GBufferRT = createPass('GBufferRT', {'samplePattern': SamplePattern.Center, 'sampleCount': 16, 'disableAlphaTest': False, 'adjustShadingNormals': True, 'forceCullMode': False, 'cull': CullMode.CullBack, 'texLOD': LODMode.UseMip0})
    g.addPass(GBufferRT, 'GBufferRT')
    PlecoRayTracer = createPass('PlecoRayTracer')
    g.addPass(PlecoRayTracer, 'PlecoRayTracer')
    g.addEdge('GBufferRT.posW', 'PlecoRayTracer.WorldPosition')
    g.addEdge('GBufferRT.normW', 'PlecoRayTracer.WorldNormal')
    g.addEdge('GBufferRT.diffuseOpacity', 'PlecoRayTracer.MaterialDiffuse')
    g.addEdge('GBufferRT.specRough', 'PlecoRayTracer.MaterialSpecRough')
    g.addEdge('GBufferRT.matlExtra', 'PlecoRayTracer.MaterialExtraParams')
    g.markOutput('PlecoRayTracer.WorldPosition')
    return g

DefaultRenderGraph = render_graph_DefaultRenderGraph()
try: m.addGraph(DefaultRenderGraph)
except NameError: None