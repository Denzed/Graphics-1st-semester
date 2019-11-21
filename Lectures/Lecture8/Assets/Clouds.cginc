float get_intensity(sampler3D intensity, float3 pos) {
    float res = 0;
    float weight = 0.5;
    float total_weight = 0;

    for (int i = 0; i < 4; ++i) {
        res += tex3D(intensity, pos * 0.1 + _Time[i] * 0.005)[i] * weight;
        total_weight += weight;
        weight /= 2;
    }

    return res / total_weight;
}

float get_weather(sampler2D weather_map, float2 pos) {
    pos *= 0.3;
    float4 weather = tex2D(weather_map, pos);
    return smoothstep(
        0, 1, 
        sin(pos.x) * sin(pos.y) //saturate(weather.r - 0.5)
    );
}

float4 get_clouds(
    float3 pos, float3 ray, 
    sampler3D intensity, sampler2D weather_map, 
    const int STEPS, const float MIN_HEIGHT, const float MAX_HEIGHT
) {
    const float3 step = ray / (1.0 - pos.y) * abs(ray.y) / STEPS;

    float4 res = 0;
    float weight = 0;
    for (int i = 0; i < STEPS; ++i) {
        float coef = 
            saturate((pos.y - MIN_HEIGHT) / (MAX_HEIGHT - MIN_HEIGHT))
            *
            get_weather(weather_map, pos.xz);
        float4 cur = coef * get_intensity(intensity, pos);
        
        //res += coef * cur;
        weight += coef;
        res.rgb = lerp(res.rgb, cur.rgb, cur.a);
        res.a += (1 - res.a) * cur.a;

        pos += step;
    }
    return res / max(1, weight);
}
