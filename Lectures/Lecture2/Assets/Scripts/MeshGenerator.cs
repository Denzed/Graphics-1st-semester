using System;
using System.Collections.Generic;
using UnityEngine;

[RequireComponent(typeof(MeshFilter))]
public class MeshGenerator : MonoBehaviour {
    private struct Triangle {
        public Vector3 a, b, c;
        public Vector3 na, nb, nc;
    };

    private const int FACTOR = 16;

    private Mesh _mesh;
    private MeshFilter _filter;
    
    private ComputeShader _generator;
    private int _marchCubes;
    private ComputeBuffer _cubeVertices;

    private ComputeBuffer _caseToTrianglesCount;
    private ComputeBuffer _caseToEdges;
    
    /// <summary>
    /// Executed by Unity upon object initialization. <see cref="https://docs.unity3d.com/Manual/ExecutionOrder.html"/>
    /// </summary>
    private void Awake() {
        _filter = GetComponent<MeshFilter>();
        _mesh = _filter.mesh = new Mesh();
        _mesh.MarkDynamic();

        List<Vector3> sourceVertices = new List<Vector3> {
            new Vector3(0, 0, 0), // 0
            new Vector3(0, 1, 0), // 1
            new Vector3(1, 1, 0), // 2
            new Vector3(1, 0, 0), // 3
            new Vector3(0, 0, 1), // 4
            new Vector3(0, 1, 1), // 5
            new Vector3(1, 1, 1), // 6
            new Vector3(1, 0, 1), // 7
        };
        _cubeVertices = new ComputeBuffer(8, 3 * 4);
        _cubeVertices.SetData(sourceVertices);

        _generator = Resources.Load<ComputeShader>("GenerateVertices");
        _marchCubes = _generator.FindKernel("marchCubes");

        _caseToTrianglesCount = new ComputeBuffer(256, 4);
        _caseToTrianglesCount.SetData(MarchingCubes.Tables.CaseToTrianglesCount);
        _generator.SetBuffer(_marchCubes, "caseToTrianglesCount", _caseToTrianglesCount);

        int[] caseToVertices = new int[256 * 5 * 3];
        for (uint i = 0; i < 256; i++) {
            for (uint j = 0; j < 5; j++) {
                caseToVertices[3 * (i * 5 + j)    ] = MarchingCubes.Tables.CaseToVertices[i][j].x;
                caseToVertices[3 * (i * 5 + j) + 1] = MarchingCubes.Tables.CaseToVertices[i][j].y;
                caseToVertices[3 * (i * 5 + j) + 2] = MarchingCubes.Tables.CaseToVertices[i][j].z;
            }
        }
        _caseToEdges = new ComputeBuffer(256 * 5, 3 * 4);
        _caseToEdges.SetData(caseToVertices);
        _generator.SetBuffer(_marchCubes, "caseToEdges", _caseToEdges);

        _generator.SetBuffer(_marchCubes, "cubeVertices", _cubeVertices);

        int[] factor = new int[]{ FACTOR, FACTOR, FACTOR };
        _generator.SetInts("SPLIT_FACTOR", factor);
    }

    /// <summary>
    /// Executed by Unity on every first frame <see cref="https://docs.unity3d.com/Manual/ExecutionOrder.html"/>
    /// </summary>
    private void Update() {
        ComputeBuffer outVertices = new ComputeBuffer(
            5 * FACTOR * FACTOR * FACTOR, 
            3 * 6 * 4, 
            ComputeBufferType.Append
        );
        _generator.SetBuffer(_marchCubes, "outTriangles", outVertices);

        uint[] groupSize = new uint[3];
        _generator.GetKernelThreadGroupSizes(_marchCubes, out groupSize[0], out groupSize[1], out groupSize[2]);

        _generator.Dispatch(
            _marchCubes, 
            FACTOR / (int) groupSize[0], 
            FACTOR / (int) groupSize[1], 
            FACTOR / (int) groupSize[2]
        );

        // Here unity automatically assumes that vertices are points and hence will be represented as (x, y, z, 1) in homogenous coordinates
        Triangle[] outTriangles = new Triangle[outVertices.count];
        outVertices.GetData(outTriangles);

        List<Vector3> vertices = new List<Vector3>();
        List<Vector3> normals = new List<Vector3>();
        List<int> triangles = new List<int>();
        for (int i = 0; i < outVertices.count; i++) {
            triangles.AddRange(new List<int> { 3 * i, 3 * i + 1, 3 * i + 2 });
            vertices.AddRange(new List<Vector3> { outTriangles[i].a, outTriangles[i].b, outTriangles[i].c });
            normals.AddRange(new List<Vector3> { outTriangles[i].na, outTriangles[i].nb, outTriangles[i].nc });
        }

        _mesh.Clear(false);
        _mesh.SetVertices(vertices);
        _mesh.SetTriangles(triangles, 0);
        _mesh.SetNormals(normals);

        // Upload mesh data to the GPU
        _mesh.UploadMeshData(false);

        outVertices.Release();
    }
}