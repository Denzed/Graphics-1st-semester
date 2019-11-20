Shader "Custom/Clouds"
{
    Properties
    {
        _Intensity ("Cloud noise", 3D) = "white" {}
        _Weather ("Weather map", 2D) = "white" {}
    }
    SubShader
    {
        // No culling or depth
        Cull Off ZWrite Off ZTest Always

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "UnityCG.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float4 vertex : SV_POSITION;
                float3 view_dir : TEXCOORD1;
            };

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = v.uv;
                o.view_dir = UnityWorldSpaceViewDir(v.vertex);
                return o;
            }

            sampler3D _Intensity;
            sampler2D _Weather;

            #include "Clouds.cginc"

            fixed4 frag (v2f i) : SV_Target
            {
                return get_clouds(i.vertex, i.view_dir, _Intensity, _Weather);
            }
            ENDCG
        }
    }
}
