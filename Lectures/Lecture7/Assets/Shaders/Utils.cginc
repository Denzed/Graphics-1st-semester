#define pow2(x)       (x * x)          
#define PI            3.14159265359f
#define TWO_PI        6.28318530718f
#define FOUR_PI       12.56637061436f
#define INV_PI        0.31830988618f
#define INV_TWO_PI    0.15915494309f
#define INV_FOUR_PI   0.07957747155f
#define HALF_PI       1.57079632679f
#define INV_HALF_PI   0.636619772367f
#define SQRT_PI       1.77245385091f
#define INV_SQRT_PI   0.56418958354f
#define SQRT_3        1.73205080757f
#define SQRT_5        2.2360679775f

float4x4 rotationMatrix(float3 rotation) {
    float c = cos(rotation.x);
    float s = sin(rotation.x);
    float4x4 rotateXMatrix = float4x4(
        1, 0,  0, 0,
        0, c, -s, 0,
        0, s,  c, 0,
        0, 0,  0, 1
    );

    c = cos(rotation.y);
    s = sin(rotation.y);
    float4x4 rotateYMatrix = float4x4(
            c, 0, s, 0,
            0, 1, 0, 0,
            -s, 0, c, 0,
            0, 0, 0, 1
    );

    c = cos(rotation.z);
    s = sin(rotation.z);
    float4x4 rotateZMatrix = float4x4(
        c, -s, 0, 0,
        s,  c, 0, 0,
        0,  0, 1, 0,
        0,  0, 0, 1
    );

    return rotateXMatrix * rotateYMatrix * rotateZMatrix;
}

uint Hash(uint s)
{
    s ^= 2747636419u;
    s *= 2654435769u;
    s ^= s >> 16;
    s *= 2654435769u;
    s ^= s >> 16;
    s *= 2654435769u;
    return s;
}

float Random(uint seed)
{
    return float(Hash(seed)) / 4294967295.0; // 2^32-1
}
