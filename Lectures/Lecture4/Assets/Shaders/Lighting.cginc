#include "Noise.cginc"
#include "Utils.cginc" // rotationMatrix

float F(float cosTheta, float3 F0) {
    return F0 + (1 - F0) * pow(1 - cosTheta, 5);
}

#ifdef GGX

float theta_m(float x) {
    return atan(roughness * sqrt(x / (1 - x)));
}

float psi_m(float y) {
    return 2 * PI * y;
}

float G_1(float3 v, float3 m, float3 n) {
    float v_m = saturate(dot(v, m));
    if (v_m / saturate(dot(v, n)) > 0) {
        return 2 / (1.0 + sqrt(1.0 + pow(roughness, 2.0) * (1 - pow(v_m, 2)) / pow(v_m, 2)));
    }
    return 0.0;
}

#endif

float G(float3 i, float3 o, float3 m, float3 n) {
    return G_1(i, m, n) * G_1(o, m, n); // roughly
}

void CookTorrance(
    samplerCUBE surround, float3 i, float3 n, int samples, 
    out float3 specular, out float3 kS
) {
    specular = 0.0;
    kS = 0.0;

    if (samples == 0) {
        return;
    }
    
    const float3 F0 = lerp(
        pow(abs((1.0 - nu) / (1.0 + nu)), 2), 
        ownColor.rgb, 
        metallic
    );

    for (int index = 1; index <= samples; ++index) {
        float3 o = mul(rotationMatrix(float3( 
            theta_m(rand(57.0 * index)),
            psi_m(rand(179.0 * index)),
            0.0
        ) * roughness), n);
        
        float cosTheta = saturate(dot(o, n));
        float sinTheta = sqrt(1.0 - pow(cosTheta, 2.0));
        float3 h_r = normalize(i + o);

        float3 fresnel = F(saturate(dot(h_r, o)), F0);
        float partial_geometry = G(i, o, h_r, n);
        float denominator = saturate(4 * saturate(dot(n, i)) * saturate(dot(h_r, n)) + 0.05);

        kS += fresnel;
        specular += texCUBE(surround, o).rgb * fresnel * partial_geometry * sinTheta / denominator;
    }

    kS = saturate(kS / samples);
    specular /= samples;
}