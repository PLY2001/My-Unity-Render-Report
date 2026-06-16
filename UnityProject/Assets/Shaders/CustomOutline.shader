Shader "Hidden/Custom/DepthNormalsOutline"
{
    Properties
    {
        _OutlineColor ("Outline Color", Color) = (0, 0, 0, 1)
        _OutlineThickness ("Outline Thickness", Range(0.5, 5.0)) = 1.0
        _DepthThreshold ("Depth Threshold", Range(0.01, 100.0)) = 1.0
        _NormalThreshold ("Normal Threshold", Range(0.01, 1.0)) = 0.5
    }
    
    SubShader
    {
        Tags { "RenderPipeline" = "UniversalPipeline" }
        Cull Off ZWrite Off ZTest Always

        Pass
        {
            Name "SobelOutline"

            HLSLPROGRAM
            #pragma vertex Vert
            #pragma fragment Frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareDepthTexture.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareNormalsTexture.hlsl"
            #include "Packages/com.unity.render-pipelines.core/Runtime/Utilities/Blit.hlsl"

            CBUFFER_START(UnityPerMaterial)
                float4 _OutlineColor;
                float _OutlineThickness;
                float _DepthThreshold;
                float _NormalThreshold;
            CBUFFER_END

            // 采样深度
            float GetDepth(float2 uv)
            {
                return SampleSceneDepth(uv);
            }

            // 采样法线
            float3 GetNormal(float2 uv)
            {
                return SampleSceneNormals(uv);
            }

            half4 Frag(Varyings input) : SV_Target
            {
                float2 uv = input.texcoord;
                
                // 像素偏移量
                float2 texelSize = _ScreenSize.zw * _OutlineThickness;

                // Sobel 3x3 采样点偏移，使用十字对角采样提高性能
                float2 uv_1 = uv + float2(-1, 1) * texelSize;
                float2 uv_2 = uv + float2(1, 1) * texelSize;
                float2 uv_3 = uv + float2(-1, -1) * texelSize;
                float2 uv_4 = uv + float2(1, -1) * texelSize;

                // 深度边缘检测
                float d0 = GetDepth(uv);
                float d1 = GetDepth(uv_1);
                float d2 = GetDepth(uv_2);
                float d3 = GetDepth(uv_3);
                float d4 = GetDepth(uv_4);

                float ld0 = LinearEyeDepth(d0, _ZBufferParams);
                float ld1 = LinearEyeDepth(d1, _ZBufferParams);
                float ld2 = LinearEyeDepth(d2, _ZBufferParams);
                float ld3 = LinearEyeDepth(d3, _ZBufferParams);
                float ld4 = LinearEyeDepth(d4, _ZBufferParams);

                float depthDiff = abs(ld1 - ld4) + abs(ld2 - ld3);
                // 动态阈值：距离相机越远，阈值越大，防止远处物体出现“脏边”
                float depthEdge = step(_DepthThreshold * ld0, depthDiff);

                // 法线边缘检测
                float3 n1 = GetNormal(uv_1);
                float3 n2 = GetNormal(uv_2);
                float3 n3 = GetNormal(uv_3);
                float3 n4 = GetNormal(uv_4);

                float3 normalDiff = abs(n1 - n4) + abs(n2 - n3);
                float normalEdge = step(_NormalThreshold, normalDiff.x + normalDiff.y + normalDiff.z);

                // 任意一个检测出边缘，即判定为边缘
                float edgeWeight = saturate(depthEdge + normalEdge);

                // _BlitTexture 是 Blitter API 自动绑定的源图像
                half4 sourceColor = SAMPLE_TEXTURE2D(_BlitTexture, sampler_LinearClamp, uv);
                
                // 根据边缘权重插值原图与描边颜色
                return lerp(sourceColor, _OutlineColor, edgeWeight);
            }
            ENDHLSL
        }
    }
}