Shader "0_Custom/Cook-Torrance"
{
    Properties
    {
        surround ("Surround", Cube) = "white" {}
        samples ("Samples", Int) = 10
        roughness ("Roughness", Float) = 0.1
        nu ("IOR", Float) = 1.1
        metallic ("Metallicity", Float) = 0.5
        ownColor ("Material color", Color) = (1, 1, 1, 1)
        gamma ("Gamma correction", Float) = 2.2
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

            v2f vert (appdata v)
            {
                v2f o;
                o.clip = UnityObjectToClipPos(v.vertex);
                o.pos = mul(UNITY_MATRIX_M, v.vertex);
                o.normal = UnityObjectToWorldNormal(v.normal);
                return o;
            }

            samplerCUBE surround;
            int samples;
            float nu;
            float roughness;
            float metallic;
            float4 ownColor;
            float gamma;

            const static float PI = 3.14159265359;
            
            #define GGX
            #include "Lighting.cginc"

            fixed4 frag (v2f i) : SV_Target
            {
                float3 normal = normalize(i.normal);
                float3 viewDirection = normalize(_WorldSpaceCameraPos - i.pos.xyz);

                float3 specular;
                float3 kS;
                CookTorrance(surround, viewDirection, normal, samples, specular, kS);

                float3 diffuse = ownColor.rgb * texCUBE(surround, normal).rgb;
                float3 kD = (1 - kS) * (1 - metallic);

                float3 result = kD * diffuse + specular;

                return float4(fix_gamma(result), 1.0);
            }
            ENDCG
        }
    }
}
