using System;
using System.Linq;
using System.Collections.Generic;
using System.Reflection;
using Unity.Mathematics;
using UnityEngine;

public class MeshGenerator : MonoBehaviour {
    public int FACTOR;
    public int STEPS;
    public int OCTAVE_COUNT;
    public Material material;

    private bool isIndirectAvailable = 
        typeof(Graphics).GetMethod(
            "DrawProceduralIndirectNow", 
            BindingFlags.Static
        ) != null;

    private int MAX_ELEMENTS;
    private int STEP_SIZE;
    
    private ComputeShader _generator;
    private int _marchCubes;

    private ComputeBuffer _cubeVertices;
    private ComputeBuffer _caseToEdges;
    private ComputeBuffer _caseToTrianglesCount;

    private ComputeBuffer _outPoints;
    private ComputeBuffer _outPointsCount;
    
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

        _outPoints = new ComputeBuffer(3 * MAX_ELEMENTS, 2 * 3 * 4);
        _generator.SetBuffer(_marchCubes, "outPoints", _outPoints);

        uint[] groupSize = new uint[3];
        _generator.GetKernelThreadGroupSizes(_marchCubes, out groupSize[0], out groupSize[1], out groupSize[2]);
        
        _indirectSizeMarch = new ComputeBuffer(3, 4, ComputeBufferType.IndirectArguments);
        _indirectSizeMarch.SetData(new uint[] {
            (uint) (FACTOR + groupSize[0] - 1) / groupSize[0],
            (uint) (FACTOR + groupSize[1] - 1) / groupSize[1],
            (uint) (((uint) FACTOR + groupSize[2] - 1) / groupSize[2] + (uint) STEPS - 1) / (uint) STEPS
        });
        
        _outPointsCount = new ComputeBuffer(4, 4);
        _generator.SetBuffer(_marchCubes, "outPointsCount", _outPointsCount); 
    }

    private void setupShared() {
        _generator.SetInts(
            "SPLIT_FACTOR", 
            new int[]{ FACTOR, FACTOR, FACTOR }
        );
        
        _generator.SetInt("OCTAVE_COUNT", OCTAVE_COUNT);
    }
    
    /// <summary>
    /// Executed by Unity upon object initialization. <see cref="https://docs.unity3d.com/Manual/ExecutionOrder.html"/>
    /// </summary>
    private void Start() {
        MAX_ELEMENTS = 5 * FACTOR * FACTOR * (FACTOR / STEPS);
        
        _generator = Resources.Load<ComputeShader>("GenerateVertices");
        
        setupMarch();
        setupShared();

        material.SetBuffer("points", _outPoints);

        // generate surface
        int generateTexture = _generator.FindKernel("generateTexture");

        int MAX_DIMENSION = Math.Max(FACTOR / 2, 1);

        RenderTextureDescriptor desc = new RenderTextureDescriptor(
            MAX_DIMENSION, MAX_DIMENSION, RenderTextureFormat.ARGBFloat
        );
        desc.enableRandomWrite = true;
        desc.dimension = UnityEngine.Rendering.TextureDimension.Tex3D;
        desc.volumeDepth = MAX_DIMENSION;

        RenderTexture surfaceTexture = new RenderTexture(desc);
        surfaceTexture.Create();

        _generator.SetTexture(generateTexture, "outSurfaceTexture", surfaceTexture);
        _generator.Dispatch(generateTexture, desc.width, desc.height, desc.volumeDepth);
        
        _generator.SetTexture(_marchCubes, "surfaceTexture", surfaceTexture);
    }

    /// <summary>
    /// Executed by Unity on every first frame <see cref="https://docs.unity3d.com/Manual/ExecutionOrder.html"/>
    /// </summary>
    private void OnRenderObject() {
        material.SetMatrix("vertexTransform", gameObject.transform.localToWorldMatrix);
        
        material.SetFloat("TIME", Time.time / 10.0f);
        _generator.SetFloat("TIME", Time.time / 10.0f);
        
        for (int step = 0; step < STEPS; step++) {
            _outPointsCount.SetData(new int[] { 0, 1, 0, 0 });
            
            _generator.SetInt("LAYER_OFFSET", (FACTOR / STEPS) * step);
            
            _generator.DispatchIndirect(_marchCubes, _indirectSizeMarch);

            material.SetPass(0);
            if (isIndirectAvailable) {
                Graphics.DrawProceduralIndirectNow(MeshTopology.Triangles, _outPointsCount, 0);
            } else {
                int[] nPointsData = new int[1];
                _outPointsCount.GetData(nPointsData, 0, 0, 1);
                int nPoints = nPointsData[0];
                
                Graphics.DrawProceduralNow(MeshTopology.Triangles, nPoints, 1);    
            }
        }
    }

    private void OnDestroy() {
        _cubeVertices.Release();
        _caseToEdges.Release();
        _caseToTrianglesCount.Release();
        _outPoints.Release();
        _outPointsCount.Release();
        _indirectSizeMarch.Release();
    }
}