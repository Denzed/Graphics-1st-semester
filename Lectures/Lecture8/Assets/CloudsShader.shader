Shader "Custom/Clouds"
{
    Properties
    {
        _Intensity ("Cloud noise", 3D) = "white" {}
        _Weather ("Weather map", 2D) = "white" {}
        _MinHeight ("Min height", Range(0, 1)) = 0
        _MaxHeight ("Max height", Range(0, 1)) = 1
        _StepCount ("Step count", Int) = 10
    }
    SubShader
    {
        Tags {"Queue"="Transparent" "IgnoreProjector"="True" "RenderType"="Transparent"}
        Blend SrcAlpha OneMinusSrcAlpha
        ColorMask RGB
        Cull Off Lighting Off ZWrite Off
        
        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "UnityCG.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
            };

            struct v2f
            {
                float4 vertex : SV_POSITION;
                float3 view_dir : TEXCOORD1;
                float3 world_pos : TEXCOORD2;
            };

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.view_dir = -UnityWorldSpaceViewDir(v.vertex);
                o.world_pos = mul(unity_ObjectToWorld, v.vertex);
                return o;
            }

            sampler3D _Intensity;
            sampler2D _Weather;

            int _StepCount;

            float _MinHeight, _MaxHeight;

            #include "Clouds.cginc"

            fixed4 frag (v2f i) : SV_Target
            {
                return get_clouds(
                    i.world_pos,
                    i.view_dir, 
                    _Intensity, _Weather, _StepCount,
                    _MinHeight, _MaxHeight
                );
            }
            ENDCG
        }
    }
}
