Shader "TrianglesFromBuffer"
{
    Properties
    {
        _Color ("Color", Color) = (1,1,1,1)
        _Glossiness ("Smoothness", Range(0,1)) = 0.5
        _Metallic ("Metallic", Range(0,1)) = 0.0
        _xTex ("Ox Tex", 2D) = "white" {}
        _yTex ("Oy Tex", 2D) = "white" {}
        _zTex ("Oz Tex", 2D) = "white" {}
    }
    SubShader
    {
        Pass
        {
            // indicate that our pass is the "base" pass in forward
            // rendering pipeline. It gets ambient and main directional
            // light data set up; light direction in _WorldSpaceLightPos0
            // and color in _LightColor0
            Tags {"LightMode"="ForwardBase"}
        
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "UnityCG.cginc" // for UnityObjectToWorldNormal
            #include "UnityLightingCommon.cginc" // for _LightColor0
            #include "Triplanar.cginc" // for triplanar texture mapping
            #include "UnityShaderVariables.cginc"  // for time

            struct VertexData {
                float3 pos, normal;
            };

            struct Triangle {
                VertexData v[3];
            };
            
            struct VertexDataV2F {
                float4 pos : POSITION;
                float3 uvw : TEXCOORD;
                float3 worldNormal : NORMAL0;
                float3 normal : NORMAL1;
            };

            StructuredBuffer<Triangle> triangles;
            StructuredBuffer<uint> trianglesCount;

            const uniform float4x4 vertexTransform;

            VertexDataV2F vert (uint pid : SV_VertexID) {
                VertexDataV2F outV;

                if (pid >= trianglesCount[0] * 3) {
                    outV.pos = float4(-2, -2, -2, 1);
                } else {
                    outV.uvw = triangles[pid / 3].v[pid % 3].pos + float3(_SinTime.xy, 0);
                    outV.pos = UnityObjectToClipPos(mul(
                        vertexTransform,
                        triangles[pid / 3].v[pid % 3].pos
                    ));
                    outV.normal = triangles[pid / 3].v[pid % 3].normal;
                    outV.worldNormal = UnityObjectToWorldNormal(outV.normal);
                }

                return outV;
            }
            sampler2D _xTex, _yTex, _zTex;

            fixed4 frag (VertexDataV2F i) : SV_Target
            {
                half nl = max(0, dot(i.worldNormal, _WorldSpaceLightPos0.xyz));
                half3 light = nl * _LightColor0;
                light += ShadeSH9(half4(i.worldNormal,1));
                
                fixed4 col = fixed4(tex2DtriplanarBlend(_xTex, _yTex, _zTex, i.uvw, i.normal), 1.0);
                col.rgb *= light;
                return col;
            }
            ENDCG
        }
    }
    FallBack "Diffuse"
}
