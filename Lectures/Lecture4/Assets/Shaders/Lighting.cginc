#include "Noise.cginc"
#include "Utils.cginc" // rotationMatrix

float F(float3 i, float3 m) {
    float c = dot(i, m);
    float g = pow(nu_t / nu_i, 2) - 1 + pow(c, 2);

    if (g < 0) {
        return 1.0;
    }
    g = sqrt(g);

    return 0.5 * pow((g - c) / (g + c), 2) 
        * (1 + pow(
            (c * (g + c) - 1) / (c * (g - c) + 1),
            2
        ));
}

#ifdef PHONG

float D(float3 m, float3 n) {
    float cosTheta = dot(m, n);
    if (cosTheta > 0) {
        return (alpha_phong + 2) / 2 / PI * pow(cosTheta, alpha_phong);
    } 
    return 0;
}

float a(float3 v, float3 n) {
    return sqrt(0.5 * alpha_phong + 1) / tan(acos(
        dot(v, n)
    ));
}

float theta_m(float x) {
    return acos(pow(x, 1 / (alpha_phong + 2)));
}

float psi_m(float y) {
    return 2 * PI * y;
}

#endif

float G_1(float3 v, float3 m, float3 n) {
    if (dot(v, m) / dot(v, n) > 0) {
        float a_ = a(v, n);

        return a_ < 1.6 
            ? (3.535 * a_ + 2.181 * pow(a_, 2)) / (1 + 2.276 * a_ + 2.577 * pow(a_, 2))
            : 1.0;
    }
    return 0.0;
}

float G(float3 i, float3 o, float3 m, float3 n) {
    return G_1(i, m, n) * G_1(o, m, n); // roughly
}

float f_t(float3 i, float3 o, float3 m, float3 n) {
    float3 h_t = -normalize(nu_i * i + nu_t * o);

    return abs(
        dot(i, h_t) * dot(o, h_t) 
        / dot(i, m) / dot(o, m)
    ) * pow(nu_t, 2) * (1 - F(i, h_t)) * G(i, o, h_t, n) * D(h_t, n)
        / pow(nu_i * dot(i, h_t) + nu_t * dot(0, h_t), 2);
}

float f_r(float3 i, float3 o, float3 m, float3 n) {
    float3 h_r = normalize(sign(dot(i, m)) * (i + o));

    return F(i, h_r) * G(i, o, h_r, n) * D(h_r, n) 
        / abs(4 * dot(i, m) * dot(o, m));
}

float3 f_s(samplerCUBE surround, float3 i, float3 n, int samples) {
    float3 total = 0.0;
    float total_weight = 0.0;

    for (int facet = 1; facet <= samples; ++facet) {
        float theta = theta_m(rand(57.0 * facet));
        float psi = psi_m(rand(179.0 * facet));

        float3 m = mul(rotationMatrix(float3(theta, psi, 0.0)), n);
        float3 o;

        float visibility;
        if (F(i, m) >= reflection_threshold) {
            o = 2 * abs(dot(i, m)) * m - i;
        } else {
            float nu = nu_i / nu_t;
            float c = dot(i, m);

            o = (nu * c - sign(dot(i, n)) * sqrt(1 + nu * (pow(c, 2) - 1))) * m - nu * i;
        }

        float weight = G(i, o, m, n) * abs(dot(i, m) 
            / dot(i, n) / dot(m, n));

        total += weight * o;
        total_weight += weight;
    }

    return texCUBE(surround, total / total_weight);
}