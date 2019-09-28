uniform const float _HeightmapBlending = 1.0;

// Whiteout blend
fixed3 tex2DtriplanarBlend(sampler2D xTex, sampler2D yTex, sampler2D zTex, float3 uvw, float3 normal) {
    fixed3 colorX = tex2D(xTex, uvw.yz).xyz;
    fixed3 colorY = tex2D(yTex, uvw.xz).xyz;
    fixed3 colorZ = tex2D(zTex, uvw.xy * 10).xyz; // grass is too rough

    // Height Map Triplanar Blend
    float3 blend = pow(abs(normal.xyz), 16.0);
    blend /= dot(blend, float3(1,1,1));
    
    // Height value from each plane's texture. This is usually
    // packed in to another texture or (less optimally) as a separate 
    // texture.
    float3 heights = float3(0.0, 0.0, uvw.z) + (blend * 3.0);
    
    // _HeightmapBlending is a value between 0.01 and 1.0
    float height_start = 0.0;
    float3 h = max(heights - height_start, float3(0,0,0));
    blend = h / dot(h, float3(1,1,1));

    // Swizzle tangent colors to match world orientation and triblend
    return colorX * blend.x + colorY * blend.y + colorZ * blend.z;
}