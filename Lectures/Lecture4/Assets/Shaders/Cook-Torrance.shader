Shader "0_Custom/Cook-Torrance"
{
    Properties
    {
        _SurroundColor ("Surround", Cube) = "white" {}
        _Rays ("Ray count", Int) = 10
        alpha_phong ("α Phong", Float) = 48
        nu_i ("η Atmospheric", Float) = 1.0
        nu_t ("η Surface", Float) = 1.5
        reflection_threshold ("Reflection threshold", Float) = 0.07
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        LOD 100

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "UnityCG.cginc"
            #include "UnityLightingCommon.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                fixed3 normal : NORMAL;
            };

            struct v2f
            {
                float4 clip : SV_POSITION;
                float4 pos : TEXCOORD1;
                fixed3 normal : NORMAL;
            };

            float4 _AmbientColor;
            samplerCUBE _SurroundColor;
            float4 _BaseColor;
            float _Shininess;
            int _Rays;

            v2f vert (appdata v)
            {
                v2f o;
                o.clip = UnityObjectToClipPos(v.vertex);
                o.pos = mul(UNITY_MATRIX_M, v.vertex);
                o.normal = UnityObjectToWorldNormal(v.normal);
                return o;
            }

            float nu_i;
            float nu_t = 1.5;
            float alpha_phong;
            float reflection_threshold;
            const static float PI = 3.14159265359;
            
            #define PHONG
            #include "Lighting.cginc"
            #undef PHONG

            fixed4 frag (v2f i) : SV_Target
            {
                float3 normal = normalize(i.normal);
                float3 viewDirection = normalize(_WorldSpaceCameraPos - i.pos.xyz);
                
                return float4(
                    f_s(_SurroundColor, viewDirection, normal, _Rays),
                    1.0
                );
            }
            ENDCG
        }
    }
}
