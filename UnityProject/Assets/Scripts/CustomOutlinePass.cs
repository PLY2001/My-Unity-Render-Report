using UnityEngine;
using UnityEngine.Rendering.Universal;
using UnityEngine.Rendering;

public class CustomOutlinePass : ScriptableRenderPass
{
    private Material m_OutlineMaterial;
    private RTHandle m_CameraColorTarget;
    private RTHandle m_TemporaryColorTexture;

    public CustomOutlinePass(Material mat)
    {
        m_OutlineMaterial = mat;
        // 渲染时机：与天空盒绘制完毕之后
        renderPassEvent = RenderPassEvent.AfterRenderingSkybox;
    }

    public void Setup(RTHandle colorTarget)
    {
        m_CameraColorTarget = colorTarget;
    }

    public override void OnCameraSetup(CommandBuffer cmd, ref RenderingData renderingData)
    {
        // 申请一张全屏的临时 RT
        RenderTextureDescriptor desc = renderingData.cameraData.cameraTargetDescriptor;
        desc.depthBufferBits = 0; // 颜色缓冲无需深度
        RenderingUtils.ReAllocateIfNeeded(ref m_TemporaryColorTexture, desc, FilterMode.Bilinear, TextureWrapMode.Clamp, name: "_TempOutlineTexture");
    }

    public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
    {
        if (m_OutlineMaterial == null || m_CameraColorTarget == null) return;

        CommandBuffer cmd = CommandBufferPool.Get("CustomOutlinePass");

        // 执行屏幕空间后处理：原图 -> (Shader 描边运算) -> 临时 RT -> 原图
        Blitter.BlitCameraTexture(cmd, m_CameraColorTarget, m_TemporaryColorTexture, m_OutlineMaterial, 0);
        Blitter.BlitCameraTexture(cmd, m_TemporaryColorTexture, m_CameraColorTarget);

        context.ExecuteCommandBuffer(cmd);
        CommandBufferPool.Release(cmd);
    }

    public void Dispose()
    {
        if (m_TemporaryColorTexture != null)
        {
            m_TemporaryColorTexture.Release();
            m_TemporaryColorTexture = null;
        }
    }
}
