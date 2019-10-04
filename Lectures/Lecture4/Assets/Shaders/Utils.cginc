float4x4 rotationMatrix(float3 rotation) {
    float c = cos(rotation.x);
    float s = sin(rotation.y);
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

