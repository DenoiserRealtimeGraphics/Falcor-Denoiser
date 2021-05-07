# Pleco Denoiser in Falcor 4.3
Adam Clarke, Colton Soneson

We explore solutions to lower the hardware cost of ray tracing in discrete, realtime simulations, while retaining its visual fidelity through the utilization of a denoising algorithm. We converge on Pleco Denoiser, a rudimentary, sample-based denoiser which incorporates the primary methods upon which topical state-of-the-art ray tracing denoisers are built. Pleco Denoiser performs a weighted average between the accumulation of previous ray traced outputs, scaled by the inverse pixel motion and inverse photometric difference, and the current ray traced output. We find that Pleco Denoiser does not significantly increase runtime overhead, but that the visual fidelity of its output, measured both objectively and subjectively, does not surpass the visual fidelity of noisy 1 spp ray traced output.

Instructions
1. Install dependencies accoring to https://github.com/NVIDIAGameWorks/Falcor
2. Open Falcor.sln in VS2019
3. Set Mogwai as Startup Project
4. Build & Run
5. File -> Load Scene -> Media/*.pyscene
6. File -> Load Script -> Source/RenderPasses/PlecoRayTracer/Data/PlecoRayTracerToPlecoDenoiser_Split.py
