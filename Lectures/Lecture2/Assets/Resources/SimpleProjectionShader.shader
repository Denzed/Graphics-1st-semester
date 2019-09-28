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

            struct VertexData {
                float4 pos : POSITION;
                float3 uvw : TEXCOORD;
                float3 normal : NORMAL;
            };

            struct Triangle {
                VertexData v[3];
            };

            StructuredBuffer<Triangle> triangles;
            StructuredBuffer<uint> trianglesCount;

            VertexData vert (uint pid : SV_VertexID) {
                VertexData outV;

                if (pid >= trianglesCount[0] * 3) {
                    outV.pos = float4(-2, -2, -2, 1);
                } else {
                    outV = triangles[pid / 3].v[pid % 3];
                    
                    outV.pos = UnityObjectToClipPos(outV.pos);
                    outV.normal = UnityObjectToWorldNormal(outV.normal);
                }

                return outV;
            }

            sampler2D _xTex, _yTex, _zTex;

            fixed4 frag (VertexData i) : SV_Target
            {
                half nl = max(0, dot(i.normal, _WorldSpaceLightPos0.xyz));
                half3 light = nl * _LightColor0;
                light += ShadeSH9(half4(i.normal,1));
                
                fixed4 col = fixed4(tex2DtriplanarBlend(_xTex, _yTex, _zTex, i.uvw, i.normal), 1.0);
                col.rgb *= light;
                return col;
            }
            ENDCG
        }
    }
    FallBack "Diffuse"
}
