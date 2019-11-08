Shader "0_Custom/NormalMapping"
{
    Properties
    {
        _Albedo ("Albedo", 2D) = "white" {}
        _Normals ("Normals", 2D) = "white" {}
        _Heights ("Height map", 2D) = "black" {}
        _Height_scale ("Height scale", Range(0, 1)) = 0.1
        [MaterialToggle] _Shadowing("Hard shadows", Float) = 0
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
            #include "Utils.cginc"

            struct v2f {
                float4 vertex : SV_POSITION;
                float3 normal : NORMAL;
                float2 uv : TEXCOORD0;
                float3 view : COLOR0;
                float3 light : COLOR1;
            };

            sampler2D _Albedo, _Normals, _Heights;
			float4 _Albedo_ST, _Normals_ST, _Heights_ST;
            float _Height_scale;
            float _Shadowing;
            
            const static int MAX_LINEAR_STEPS = 40;
            const static int MIN_LINEAR_STEPS = 10;
            const static int BINARY_STEPS = 0; // looks like dynamic step size/count supercedes binary search refining
            const static int SHADOW_SAMPLES = 10;
                
            v2f vert (float4 vertex : POSITION, float3 normal : NORMAL, float4 tangent : TANGENT, float2 uv : TEXCOORD0)
            {
                float3x3 objectToTangent;
                objectToTangent[0] = normalize(tangent);
                objectToTangent[1] = normalize(normal);
                objectToTangent[2] = cross(normalize(normal), normalize(tangent.xyz)) * tangent.w;

                v2f o;
				
                o.vertex = UnityObjectToClipPos(vertex);
				o.uv = uv;
				o.view = -mul(objectToTangent, ObjSpaceViewDir(vertex));
				o.normal = mul(objectToTangent, normal);
				o.light = mul(objectToTangent, normalize(ObjSpaceLightDir(vertex)));
                
                return o;
            }

            float get_height(float2 uv, float2 dx, float2 dy) {
                return tex2Dgrad(_Heights, uv, dx, dy).r;
            }

            float2 parallax_offset(float2 uv, float3 ray, const int STEP_COUNT) {
                const float2 dx = ddx(uv);
                const float2 dy = ddy(uv);
                
                const float step_size = -1.0 / STEP_COUNT;
                const float2 uv_step = step_size * _Height_scale * ray.xz;

                #define n_steps(base, step, count) (base + (step) * (count))
                #define get_offset(x) n_steps(0, uv_step, x)
                #define get_approx(x) n_steps(1.0, step_size, x)
                #define get_actual(x) get_height(uv + get_offset(x), dx, dy)

                for (int i = 0; i < STEP_COUNT && get_approx(i) > get_actual(i); ++i);
                
                float l = -1;
                float r = 0;
                for (int j = 0; j < BINARY_STEPS; ++j) {
                    float m = (l + r) / 2;
                    
                    if (get_approx(i + m) > get_actual(i + m))
                        l = m;
                    else
                        r = m;
                }
                
                float l_delta = get_approx(i + l) - get_actual(i + l);
                float r_delta = get_approx(i + r) - get_actual(i + r);
                return get_offset(i + lerp(l, r, abs(l_delta / (l_delta - r_delta))));

                #undef n_steps
                #undef get_offset
                #undef get_approx
                #undef get_actual
            }

            bool check_bounds(float2 uv) {
                return 0 <= uv.x && uv.x <= 1 && 0 <= uv.y && uv.y <= 1;
            }

            float sample_shadows(float2 uv, float3 ray, const int STEP_COUNT) {
                const float2 dx = ddx(uv);
                const float2 dy = ddy(uv);

                const float h_base = get_height(uv, dx, dy);
                const float step_size = (1.0 - h_base) / STEP_COUNT;
                const float2 uv_step = step_size * _Height_scale * ray.xz;

                #define n_steps(base, step, count) (base + (step) * (count))
                #define get_offset(x) n_steps(0, uv_step, x)
                #define get_approx(x) n_steps(h_base, step_size, x)
                #define get_actual(x) get_height(uv + get_offset(x), dx, dy)
                #define check_end(x) (x < STEP_COUNT && check_bounds(uv + get_offset(x)))

                for (int i = 1; check_end(i); ++i) // so we don't start at <= -EPS
                    if (get_approx(i) <= get_actual(i))
                        return 0.0;

                return 1.0;

                #undef n_steps
                #undef get_offset
                #undef get_approx
                #undef get_actual
                #undef check_end
            }
        
        
            float4 frag (v2f i) : SV_Target
            {
                i.view.xz /= abs(i.view.y);

                const int parallax_step_count = lerp(MAX_LINEAR_STEPS, MIN_LINEAR_STEPS, dot(i.normal, i.view));
                i.uv += parallax_offset(i.uv, -i.view, parallax_step_count);
                if (!check_bounds(i.uv))
                    discard; 

                fixed3 baseColor = tex2D(_Albedo, i.uv).rgb;
    
                float cosLight = dot(UnpackNormal(tex2D(_Normals, i.uv)).xzy * float3(1, 1, -1), i.light);
                float shadow_coefficient = max(0, cosLight);
                if (_Shadowing == 1) {
                    float3 light_ray = i.light;
                    i.light.xz /= abs(i.light.y);

                    shadow_coefficient *= cosLight > 0 
                        ? sample_shadows(i.uv, light_ray, SHADOW_SAMPLES)
                        : 0.0;
                }
                
                return float4(
                    baseColor * _LightColor0 * shadow_coefficient,
                    1.0
                );
            }
            ENDCG
        }
    }
}
