Shader "0_Custom/NormalMapping"
{
    Properties
    {
        _Albedo ("Albedo", 2D) = "white" {}
        _Normals ("Normals", 2D) = "white" {}
        _Heights ("Height map", 2D) = "black" {}
        _Height_scale ("Height scale", Range(0, 1)) = 0.1
        _Limit_offset_bias ("Limit offset bias", Float) = 0
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
                o.pos = 0; // zero in tangent space?
                o.view = -mul(objToTangent, ObjSpaceViewDir(vertex));
                o.light = mul(objToTangent, ObjSpaceLightDir(vertex));

                if (_Limit_offset_bias > 0) 
                    o.view.xy /= o.view.z + _Limit_offset_bias;
                
                return o;
            }

            sampler2D _Albedo, _Normals, _Heights;
			float4 _Albedo_ST, _Normals_ST, _Heights_ST;
            float _Height_scale;
            const static int STEPS = 10;

            float get_height(float2 uv) {
                float2 heights_uv = TRANSFORM_TEX(uv, _Heights);
                return 1 - tex2Dgrad(_Heights, heights_uv, ddx(heights_uv), ddy(heights_uv)).r;
            }
  
            float2 parallax_mapping(float2 uv, float3 view_dir) {
                const float step_size = 2.0 / STEPS;
                const float2 uv_step = step_size * _Height_scale * view_dir;

                float2 prev_offset = 0;
                float2 offset = 0;
                float prev_approx_height = 1;
                float approx_height = 2;
                float prev_actual_height = 0;
                float actual_height = get_height(uv);

                for (int i = 0; approx_height > actual_height && i < STEPS; ++i) {
                    prev_offset = offset;
                    offset -= uv_step;

                    prev_approx_height = approx_height;
                    approx_height -= step_size;

                    prev_actual_height = actual_height;
                    actual_height = get_height(uv + offset);
                }	
                
                float prev_delta = prev_approx_height - prev_actual_height;
	            float delta = actual_height - approx_height;
                return lerp(prev_offset, offset, prev_delta / (prev_delta + delta));
            }
        
            fixed4 frag (v2f i) : SV_Target
            {
                float2 offset = parallax_mapping(i.uv, -normalize(i.view - i.pos));
                // if (mapped_uv.x > 1.0 || mapped_uv.y > 1.0 || mapped_uv.x < 0.0 || mapped_uv.y < 0.0)
                    // discard; 

                half3 worldNormal = normalize(i.normal + UnpackNormal(tex2D(_Normals, TRANSFORM_TEX(i.uv + offset, _Normals))));

                fixed3 baseColor = tex2D(_Albedo, TRANSFORM_TEX(i.uv + offset, _Albedo)).rgb;
                
                half cosTheta = max(0, dot(worldNormal, i.light));
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
