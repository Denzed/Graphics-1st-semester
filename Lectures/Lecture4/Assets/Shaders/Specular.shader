Shader "0_Custom/Specular"
{
    Properties
    {
        _BaseColor ("Color", Color) = (0, 0, 0, 1)
        _AmbientColor ("Ambient Color", Color) = (0, 0, 0, 1)
        _Shininess ("Shininess", Float) = 1
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
            float4 _BaseColor;
            float _Shininess;

            v2f vert (appdata v)
            {
                v2f o;
                o.clip = UnityObjectToClipPos(v.vertex);
                o.pos = mul(UNITY_MATRIX_M, v.vertex);
                o.normal = UnityObjectToWorldNormal(v.normal);
                return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                float3 normal = normalize(i.normal);
                half cosTheta = max(0, dot(normal, _WorldSpaceLightPos0.xyz));
                half3 diffuse = cosTheta * _LightColor0;
                
                float3 viewDirection = normalize(_WorldSpaceCameraPos - i.pos.xyz);
                float cosAlpha = max(0.0, dot(reflect(-_WorldSpaceLightPos0.xyz, normal), viewDirection));
                half3 specular = pow(cosAlpha, _Shininess) * _LightColor0;
                
                return half4(_BaseColor.rgb * (diffuse + _AmbientColor.rgb + specular), 1);
            }
            ENDCG
        }
    }
}
