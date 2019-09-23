Shader "TrianglesFromBuffer"
{
    Properties
    {
        _Color ("Color", Color) = (1,1,1,1)
        _MainTex ("Albedo (RGB)", 2D) = "white" {}
        _Glossiness ("Smoothness", Range(0,1)) = 0.5
        _Metallic ("Metallic", Range(0,1)) = 0.0
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

            struct Triangle {
                float3 vn[3][2];
            };

            StructuredBuffer<Triangle> triangles;
            StructuredBuffer<uint> trianglesCount;

            struct v2f
            {
                float4 pos : SV_POSITION;
                float2 uv : TEXCOORD0;
                fixed3 normal : NORMAL;
            };

            v2f vert (uint pid : SV_VertexID) {
                v2f v;

                if (pid >= trianglesCount[0] * 3) {
                    v.pos = float4(-2, -2, -2, 1);
                } else {
                    Triangle tr = triangles[pid / 3];

                    v.pos = UnityObjectToClipPos(tr.vn[pid % 3][0]);
                    v.uv = float2(0.5, 0.5);
                    v.normal = UnityObjectToWorldNormal(tr.vn[pid % 3][1]);
                }

                return v;
            }

            sampler2D _MainTex;

            fixed4 frag (v2f i) : SV_Target
            {
                half nl = max(0, dot(i.normal, _WorldSpaceLightPos0.xyz));
                half3 light = nl * _LightColor0;
                light += ShadeSH9(half4(i.normal,1));
                
                fixed4 col = tex2D(_MainTex, i.uv);
                col.rgb *= light;
                return col;
            }
            ENDCG
        }
    }
    FallBack "Diffuse"
}
