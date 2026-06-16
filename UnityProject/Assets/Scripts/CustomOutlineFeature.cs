using UnityEngine;
using UnityEngine.Rendering.Universal;

public class CustomOutlineFeature : ScriptableRendererFeature
{
    [System.Serializable]
    public class OutlineSettings
    {
        public Material outlineMaterial = null;
        public RenderPassEvent renderPassEvent = RenderPassEvent.AfterRenderingSkybox;
    }

    public OutlineSettings settings = new OutlineSettings();
    private CustomOutlinePass m_OutlinePass;

    public override void Create()
    {
        if (settings.outlineMaterial == null) return;

        m_OutlinePass = new CustomOutlinePass(settings.outlineMaterial)
        {
            renderPassEvent = settings.renderPassEvent
        };
    }

    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
    {
        if (settings.outlineMaterial == null)
        {
            Debug.LogWarning("描边材质未赋值！");
            return;
        }

        // 显式请求 Depth 和 Normal，防止移动端将其 Discard
        m_OutlinePass.ConfigureInput(ScriptableRenderPassInput.Depth | ScriptableRenderPassInput.Normal);

        // 注入管线
        renderer.EnqueuePass(m_OutlinePass);
    }

    public override void SetupRenderPasses(ScriptableRenderer renderer, in RenderingData renderingData)
    {
        if (m_OutlinePass != null)
        {
            // 为 Pass 设置当前相机的 Color Target
            m_OutlinePass.Setup(renderer.cameraColorTargetHandle);
        }
    }
}