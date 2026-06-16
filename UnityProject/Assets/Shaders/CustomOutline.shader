Shader "Hidden/Custom/DepthNormalsOutline"
{
    Properties
    {
        [Toggle(_USE_ROBERTS_CROSS)] _UseRobertsCross ("Use Optimized Roberts Cross", Float) = 0
        
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

            #pragma shader_feature_local _USE_ROBERTS_CROSS

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

            float GetDepth(float2 uv)
            {
                return SampleSceneDepth(uv);
            }

            float3 GetNormal(float2 uv)
            {
                return SampleSceneNormals(uv);
            }

            half4 Frag(Varyings input) : SV_Target
            {
                float2 uv = input.texcoord;
                float depthEdge = 0.0;
                float normalEdge = 0.0;

            #if defined(_USE_ROBERTS_CROSS)
                // 1. 将 UV 转换为屏幕像素坐标
                uint2 pixelCoord = uint2(uv * _ScreenSize.xy);
                
                // 【修复】：重命名为 pixelStep，避免与 HLSL 内置的 step() 函数冲突
                uint pixelStep = max(1, (uint)_OutlineThickness);
                
                // 2. Roberts Cross 算子需要的 4 个相邻像素偏移
                uint2 coord00 = pixelCoord;
                uint2 coord11 = pixelCoord + uint2(pixelStep, pixelStep);
                uint2 coord10 = pixelCoord + uint2(pixelStep, 0);
                uint2 coord01 = pixelCoord + uint2(0, pixelStep);

                // 3. 使用 Load 直接读取深度
                float d00 = LoadSceneDepth(coord00);
                float d11 = LoadSceneDepth(coord11);
                float d10 = LoadSceneDepth(coord10);
                float d01 = LoadSceneDepth(coord01);

                float ld00 = LinearEyeDepth(d00, _ZBufferParams);
                float ld11 = LinearEyeDepth(d11, _ZBufferParams);
                float ld10 = LinearEyeDepth(d10, _ZBufferParams);
                float ld01 = LinearEyeDepth(d01, _ZBufferParams);

                // 4. Roberts Cross 深度边缘计算
                float depthDiff = abs(ld00 - ld11) + abs(ld10 - ld01);
                depthEdge = step(_DepthThreshold * ld00, depthDiff); // 这里的 step() 函数现在可以正常工作了

                // 5. Roberts Cross 法线边缘计算
                float3 n00 = LoadSceneNormals(coord00);
                float3 n11 = LoadSceneNormals(coord11);
                float3 n10 = LoadSceneNormals(coord10);
                float3 n01 = LoadSceneNormals(coord01);

                float3 normalDiff = abs(n00 - n11) + abs(n10 - n01);
                normalEdge = step(_NormalThreshold, normalDiff.x + normalDiff.y + normalDiff.z);
            #else
                // 像素偏移量
                float2 texelSize = _ScreenSize.zw * _OutlineThickness;

                // Sobel 3x3 采样点偏移
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
                depthEdge = step(_DepthThreshold * ld0, depthDiff);

                // 法线边缘检测
                float3 n1 = GetNormal(uv_1);
                float3 n2 = GetNormal(uv_2);
                float3 n3 = GetNormal(uv_3);
                float3 n4 = GetNormal(uv_4);

                float3 normalDiff = abs(n1 - n4) + abs(n2 - n3);
                normalEdge = step(_NormalThreshold, normalDiff.x + normalDiff.y + normalDiff.z);

            #endif

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