Shader "0_Custom/NormalMapping"
{
    Properties
    {
        _Albedo ("Albedo", 2D) = "white" {}
        _Normals ("Normals", 2D) = "white" {}
        _Heights ("Height map", 2D) = "black" {}
        _Height_scale ("Height scale", Range(0, 1)) = 0.1
        _Limit_offset_bias ("Limit offset bias", Range(0, 1)) = 0
        [MaterialToggle] _SelfShadowing("Lazy self shadow", Float) = 0
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

            struct v2f {
                float4 vertex : SV_POSITION;
                float3 normal : NORMAL;
                float2 uv : TEXCOORD0;
                float3 pos : COLOR0;
                float3 view : COLOR1;
                float3 light : COLOR2;
            };

            float _Limit_offset_bias;

            v2f vert (float4 vertex : POSITION, float3 normal : NORMAL, float4 tangent : TANGENT, float2 uv : TEXCOORD0)
            {
                float3x3 objToTangent;
				objToTangent[0] = tangent.xyz;
				objToTangent[1] = cross(normal, tangent.xyz) * tangent.w;
				objToTangent[2] = normal;

                v2f o;
                o.vertex = UnityObjectToClipPos(vertex);
                o.normal = mul(objToTangent, normal);
                o.uv = uv;
                o.pos = 0;
                o.view = mul(objToTangent, -ObjSpaceViewDir(vertex));
                o.light = normalize(mul(objToTangent, ObjSpaceLightDir(vertex)));
                
                return o;
            }

            sampler2D _Albedo, _Normals, _Heights;
			float4 _Albedo_ST, _Normals_ST, _Heights_ST;
            float _Height_scale;
            float _SelfShadowing;
            
            const static int LINEAR_STEPS = 8;
            const static int BINARY_STEPS = 16;

            float get_height(float2 uv) {
                float2 heights_uv = TRANSFORM_TEX(uv, _Heights);
                return tex2Dgrad(_Heights, heights_uv, ddx(heights_uv), ddy(heights_uv)).r;
            }
  
            float2 march_ray(float2 uv, float3 ray, float h_base, float h_finish) {
                const float step_size = (h_base - h_finish) / (LINEAR_STEPS - 1);
                const float2 uv_step = step_size * _Height_scale * ray;

                float2 offset = 0;
                float approx_height = h_base;
                float actual_height = get_height(uv + offset);

                for (int i = 0; approx_height > actual_height && i < LINEAR_STEPS; ++i) {
                    offset -= uv_step;
                    approx_height -= step_size;
                    actual_height = get_height(uv + offset);
                }
                
                float l = 1;
                float r = 0;
                for (int j = 0; j < BINARY_STEPS; ++j) {
                    float m = (l + r) / 2;
                    float m_approx_height = approx_height + step_size * m;
                    float m_actual_height = get_height(uv + offset + uv_step * m);

                    if (m_approx_height > m_actual_height)
                        l = m;
                    else
                        r = m;
                }
                
                float l_delta = approx_height + l * step_size - get_height(uv + offset + uv_step * l);
                float r_delta = approx_height + r * step_size - get_height(uv + offset + uv_step * r);
                return offset + uv_step * lerp(l, r, abs(l_delta / (l_delta - r_delta)));
            }
        
            float4 frag (v2f i) : SV_Target
            {
                if (_Limit_offset_bias > 0) 
                    i.view.xy /= abs(i.view.z) + _Limit_offset_bias;

                i.uv += march_ray(i.uv, normalize(i.pos - i.view), 1.0, 0.0);
                if (i.uv.x > 1.0 || i.uv.y > 1.0 || i.uv.x < 0.0 || i.uv.y < 0.0)
                    discard; 

                bool self_shadowing = _SelfShadowing * length(march_ray(i.uv, -i.light, get_height(i.uv), 1.0)) > 0.001;
                if (self_shadowing)
                    return 0;

                half3 normal = UnpackNormal(tex2D(_Normals, TRANSFORM_TEX(i.uv, _Normals)));

                fixed3 baseColor = tex2D(_Albedo, TRANSFORM_TEX(i.uv, _Albedo)).rgb;
                
                float cosTheta = max(0, dot(normal, i.light));
                half3 diffuse = cosTheta * _LightColor0;

                return float4(
                    baseColor * diffuse,
                    1.0
                );
            }
            ENDCG
        }
    }
}
