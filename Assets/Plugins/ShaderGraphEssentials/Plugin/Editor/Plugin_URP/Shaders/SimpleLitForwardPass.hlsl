﻿void BuildInputData(Varyings input, float3 normal, out InputData inputData)
{
    inputData.positionWS = input.positionWS;
#ifdef _NORMALMAP

     #if _NORMAL_DROPOFF_TS
        // IMPORTANT! If we ever support Flip on double sided materials ensure bitangent and tangent are NOT flipped.
        float crossSign = (input.tangentWS.w > 0.0 ? 1.0 : -1.0) * GetOddNegativeScale();
        float3 bitangent = crossSign * cross(input.normalWS.xyz, input.tangentWS.xyz);
        inputData.normalWS = TransformTangentToWorld(normal, half3x3(input.tangentWS.xyz, bitangent, input.normalWS.xyz));
    #elif _NORMAL_DROPOFF_OS
        inputData.normalWS = TransformObjectToWorldNormal(normal);
    #elif _NORMAL_DROPOFF_WS
        inputData.normalWS = normal;
    #endif

#else
    inputData.normalWS = input.normalWS;
#endif
    inputData.normalWS = NormalizeNormalPerPixel(inputData.normalWS);
    inputData.viewDirectionWS = SafeNormalize(input.viewDirectionWS);
    
    #if defined(MAIN_LIGHT_CALCULATE_SHADOWS)
        inputData.shadowCoord = TransformWorldToShadowCoord(inputData.positionWS);
    #else
        inputData.shadowCoord = float4(0, 0, 0, 0);
    #endif
    
    inputData.fogCoord = input.fogFactorAndVertexLight.x;
    inputData.vertexLighting = input.fogFactorAndVertexLight.yzw;
    inputData.bakedGI = SAMPLE_GI(input.lightmapUV, input.sh, inputData.normalWS);
}

    PackedVaryings vert(Attributes input)
{
    Varyings output = (Varyings)0;
    output = BuildVaryings(input);
    PackedVaryings packedOutput = (PackedVaryings)0;
    packedOutput = PackVaryings(output);
    return packedOutput;
}

half4 frag(PackedVaryings packedInput) : SV_TARGET 
{    
    Varyings unpacked = UnpackVaryings(packedInput);
    UNITY_SETUP_INSTANCE_ID(unpacked);
    UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(unpacked);

    SurfaceDescriptionInputs surfaceDescriptionInputs = BuildSurfaceDescriptionInputs(unpacked);
    SurfaceDescription surfaceDescription = SurfaceDescriptionFunction(surfaceDescriptionInputs);

    #if _AlphaClip
        clip(surfaceDescription.Alpha - surfaceDescription.AlphaClipThreshold);
    #endif

    InputData inputData;
    BuildInputData(unpacked, surfaceDescription.Normal, inputData);
    
    // from SampleSpecularSmoothness in SimpleLitInput.hlsl
	float glossinessFromSmoothness = exp2(10 * surfaceDescription.Smoothness + 1);

    half4 color = UniversalFragmentBlinnPhong(
			inputData,
			surfaceDescription.Albedo,
			half4(surfaceDescription.Specular, glossinessFromSmoothness),
			glossinessFromSmoothness,
			surfaceDescription.Emission,
			surfaceDescription.Alpha);


    color.rgb = MixFog(color.rgb, inputData.fogCoord); 
    return color;
}
