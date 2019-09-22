using System;
using System.Linq;
using System.Collections.Generic;
using UnityEngine;

[RequireComponent(typeof(MeshFilter))]
public class MeshGenerator : MonoBehaviour {
    private const int FACTOR = 64;

    private Mesh _mesh;
    private MeshFilter _filter;
    
    private ComputeShader _generator;
    private int _marchCubes;
    private int _mapCubeCases;
    private ComputeBuffer _cubeVertices;

    private ComputeBuffer _cubeCaseIds;
    private ComputeBuffer _cubeCaseIdsCount;

    private ComputeBuffer _caseToTrianglesCount;
    private ComputeBuffer _caseToEdges;

    private ComputeBuffer _outTrianglesCount;
    private ComputeBuffer _outVertices;
    private ComputeBuffer _outIndices;
    private ComputeBuffer _outNormals;
    
    /// <summary>
    /// Executed by Unity upon object initialization. <see cref="https://docs.unity3d.com/Manual/ExecutionOrder.html"/>
    /// </summary>
    private void Awake() {
        _filter = GetComponent<MeshFilter>();
        _mesh = _filter.mesh = new Mesh();
        _mesh.MarkDynamic();
        _mesh.indexFormat = UnityEngine.Rendering.IndexFormat.UInt32;

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

        _outTrianglesCount = new ComputeBuffer(1, 4);
        _generator.SetBuffer(_marchCubes, "outTrianglesCount", _outTrianglesCount);

        _outVertices = new ComputeBuffer(15 * FACTOR * FACTOR * FACTOR, 3 * 4);
        _generator.SetBuffer(_marchCubes, "outVertices", _outVertices);

        _outIndices = new ComputeBuffer(15 * FACTOR * FACTOR * FACTOR, 4);
        _generator.SetBuffer(_marchCubes, "outIndices", _outIndices);

        _outNormals = new ComputeBuffer(15 * FACTOR * FACTOR * FACTOR, 3 * 4);
        _generator.SetBuffer(_marchCubes, "outNormals", _outNormals);
        
        _mapCubeCases = _generator.FindKernel("mapCubeCases");

        _generator.SetBuffer(_mapCubeCases, "cubeVertices", _cubeVertices);

        _cubeCaseIds = new ComputeBuffer(FACTOR * FACTOR * FACTOR, 4 * 4);
        _generator.SetBuffer(_mapCubeCases, "outCaseIds", _cubeCaseIds);
        _generator.SetBuffer(_marchCubes, "inCaseIds", _cubeCaseIds);

        _cubeCaseIdsCount = new ComputeBuffer(1, 4);
        _generator.SetBuffer(_mapCubeCases, "caseIdsCount", _cubeCaseIdsCount);
        _generator.SetBuffer(_marchCubes, "caseIdsCount", _cubeCaseIdsCount);
    }

    /// <summary>
    /// Executed by Unity on every first frame <see cref="https://docs.unity3d.com/Manual/ExecutionOrder.html"/>
    /// </summary>
    private void Update() {
        _outTrianglesCount.SetData(new int[] {0});
        _cubeCaseIdsCount.SetData(new int[] {0});

        uint[,] groupSizes = new uint[2, 3];
        _generator.GetKernelThreadGroupSizes(_mapCubeCases, out groupSizes[0, 0], out groupSizes[0, 1], out groupSizes[0, 2]);
        _generator.GetKernelThreadGroupSizes(_marchCubes, out groupSizes[1, 0], out groupSizes[1, 1], out groupSizes[1, 2]);

        for (int cubeCase = 0; cubeCase < 256; cubeCase++) {
            _generator.SetInt("inCubeCase", cubeCase);
            
            _generator.Dispatch(
                _mapCubeCases,  
                FACTOR / (int) groupSizes[0, 0], 
                FACTOR / (int) groupSizes[0, 1], 
                FACTOR / (int) groupSizes[0, 2]
            );
        }

        int[] nCaseIdsData = new int[1];
        _cubeCaseIdsCount.GetData(nCaseIdsData, 0, 0, 1);
        int nCaseIds = nCaseIdsData[0];
        
        if (nCaseIds > 0) {
            _generator.Dispatch(
                _marchCubes, 
                (nCaseIds - 1 + (int) groupSizes[1, 0]) / (int) groupSizes[1, 0], 
                1, 
                1
            );
        }

        // Here unity automatically assumes that vertices are points and hence will be represented as (x, y, z, 1) in homogenous coordinates
        int[] nTrianglesData = new int[1];
        _outTrianglesCount.GetData(nTrianglesData, 0, 0, 1);
        int nVertex = 3 * nTrianglesData[0];

        // Debug.Log("Total triangles: " + nTriangles[0]);

        Vector3[] vertices = new Vector3[nVertex];
        _outVertices.GetData(vertices, 0, 0, nVertex);

        int[] indices = new int[nVertex];
        _outIndices.GetData(indices, 0, 0, nVertex);

        Vector3[] normals = new Vector3[nVertex];
        _outNormals.GetData(normals, 0, 0, nVertex);

        _mesh.Clear(false);
        _mesh.vertices = vertices;
        _mesh.triangles = indices;
        _mesh.normals = normals;

        // Upload mesh data to the GPU
        _mesh.UploadMeshData(false);
    }
}