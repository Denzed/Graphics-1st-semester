using System;
using System.Linq;
using System.Collections.Generic;
using Unity.Mathematics;
using UnityEngine;

public class MeshGenerator : MonoBehaviour {
    public uint FACTOR;
    public Material material;

    private uint MAX_ELEMENTS;

    private Mesh _mesh;
    private MeshFilter _filter;
    
    private ComputeShader _generator;
    private int _marchCubes;

    private ComputeBuffer _cubeVertices;
    private ComputeBuffer _caseToEdges;
    private ComputeBuffer _caseToTrianglesCount;

    private ComputeBuffer _outTriangles;
    private ComputeBuffer _outTrianglesCount;
    
    private ComputeBuffer _indirectSizeMarch;

    private void setupMarch() {
        _marchCubes = _generator.FindKernel("marchCubes");

        List<int3> sourceVertices = new List<int3> {
            new int3(0, 0, 0), // 0
            new int3(0, 1, 0), // 1
            new int3(1, 1, 0), // 2
            new int3(1, 0, 0), // 3
            new int3(0, 0, 1), // 4
            new int3(0, 1, 1), // 5
            new int3(1, 1, 1), // 6
            new int3(1, 0, 1), // 7
        };
        _cubeVertices = new ComputeBuffer(8, 3 * 4);
        _cubeVertices.SetData(sourceVertices);

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

        _outTriangles = new ComputeBuffer((int) MAX_ELEMENTS, 6 * 3 * 4);
        _generator.SetBuffer(_marchCubes, "outTriangles", _outTriangles);

        uint[] groupSize = new uint[3];
        _generator.GetKernelThreadGroupSizes(_marchCubes, out groupSize[0], out groupSize[1], out groupSize[2]);
        
        _indirectSizeMarch = new ComputeBuffer(3, 4, ComputeBufferType.IndirectArguments);
        _indirectSizeMarch.SetData(new uint[] {
            (FACTOR + groupSize[0] - 4) / (groupSize[0] - 3),
            (FACTOR + groupSize[1] - 4) / (groupSize[1] - 3),
            1
        });
    }

    private void setupShared() {
        int[] factor = new int[]{ (int) FACTOR, (int) FACTOR, (int) FACTOR };
        _generator.SetInts("SPLIT_FACTOR", factor);
        
        _outTrianglesCount = new ComputeBuffer(4, 4);
        _generator.SetBuffer(_marchCubes, "outTrianglesCount", _outTrianglesCount); 
    }
    
    /// <summary>
    /// Executed by Unity upon object initialization. <see cref="https://docs.unity3d.com/Manual/ExecutionOrder.html"/>
    /// </summary>
    private void Start() {
        MAX_ELEMENTS = 5 * FACTOR * FACTOR * FACTOR;

        _filter = GetComponent<MeshFilter>();
        _mesh = _filter.mesh = new Mesh();
        _mesh.MarkDynamic();
        _mesh.indexFormat = UnityEngine.Rendering.IndexFormat.UInt32;
        
        _mesh.vertices = new Vector3[3 * MAX_ELEMENTS];
        _mesh.SetIndices(
            Enumerable.Range(0, 3 * (int) MAX_ELEMENTS).ToArray(),
            MeshTopology.Triangles,
            0
        );
        _mesh.UploadMeshData(true);

        _generator = Resources.Load<ComputeShader>("GenerateVertices");
        
        setupMarch();
        setupShared();

        material.SetBuffer("triangles", _outTriangles);
        material.SetBuffer("trianglesCount", _outTrianglesCount);
    }

    /// <summary>
    /// Executed by Unity on every first frame <see cref="https://docs.unity3d.com/Manual/ExecutionOrder.html"/>
    /// </summary>
    private void OnRenderObject() {
        _outTrianglesCount.SetData(new int[] { 0, 1, 0, 0 });

        _generator.DispatchIndirect(_marchCubes, _indirectSizeMarch);

        // Here unity automatically assumes that vertices are points and hence will be represented as (x, y, z, 1) in homogenous coordinates
        // int[] nTrianglesData = new int[1];
        // _outTrianglesCount.GetData(nTrianglesData, 0, 0, 1);
        // int nTriangles = nTrianglesData[0];

        // Debug.Log("Total triangles: " + nTriangles);
        
        material.SetPass(0);
        Graphics.DrawMeshNow(_mesh, Vector3.zero, Quaternion.identity);
    }

    private void OnDestroy() {
        _cubeVertices.Release();
        _caseToEdges.Release();
        _caseToTrianglesCount.Release();
        _outTriangles.Release();
        _outTrianglesCount.Release();
        _indirectSizeMarch.Release();
    }
}