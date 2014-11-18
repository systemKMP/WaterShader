Shader "Custom/Water" {
	Properties {
      _Color ("Diffuse Material Color", Color) = (1,1,1,1) 
      _SpecColor ("Specular Material Color", Color) = (1,1,1,1) 
      _Shininess ("Shininess", Float) = 10
	  _NormalMapA ("Normal map A", 2D) = "bump" {}
	  _FlowSpeedA ("Flow Speed A", float) = 1.0
	  _InvertSpeedA ("Invert Speed A", float) = 1.0
	  _NormalMapB ("Normal map B", 2D) = "bump" {}
	  _FlowSpeedB ("Flow Speed B", float) = 1.0
	  _InvertSpeedB ("Invert Speed B", float) = 1.0
	  _WaveDirections ("4 Wave Directions", Vector) = (1,1,1,1)
	  _WaveAmplitudes ("4 Wave amplitude", Vector) = (1,1,1,1)
	  _WaveSpeeds ("4 Wave speeds", Vector) = (1,1,1,1)
	  _WaveFreqs ("4 Wave frequencies", Vector) = (1,1,1,1)
   }
   SubShader {
      Pass {	
         Tags { "LightMode" = "ForwardBase" } 
            // pass for ambient light and first light source
 
         CGPROGRAM
// Upgrade NOTE: excluded shader from OpenGL ES 2.0 because it uses non-square matrices
#pragma exclude_renderers gles
 
         #pragma vertex vert  
         #pragma fragment frag 
 
         #include "UnityCG.cginc"
         uniform float4 _LightColor0; 
            // color of light source (from "Lighting.cginc")
 
         // User-specified properties
         uniform float4 _Color; 
         uniform float4 _SpecColor; 
         uniform float _Shininess;
		 uniform float4 _WaveDirections;
		 uniform float4 _WaveAmplitudes;
		 uniform float4 _WaveSpeeds;
		 uniform float4 _WaveFreqs;

		 uniform sampler2D _NormalMapA;	
         uniform float4 _NormalMapA_ST;
		 uniform float _FlowSpeedA;
		 uniform float _InvertSpeedA;

		 uniform sampler2D _NormalMapB;	
         uniform float4 _NormalMapB_ST;
		 uniform float _FlowSpeedB;
		 uniform float _InvertSpeedB;

 
         struct vertexInput {
            float4 vertex : POSITION;
			float4 texcoord : TEXCOORD0;
            float3 normal : NORMAL;
			float4 tangent : TANGENT;
         };
         struct vertexOutput {
            float4 pos : SV_POSITION;
            float4 posWorld : TEXCOORD0;
			float4 tex : TEXCOORD1;
            float3 normalDir : TEXCOORD2;
			float3 tangentDir : TEXCOORD3;
			float3 binormalDir : TEXCOORD4;

         };
 
         vertexOutput vert(vertexInput input) 
         {
            vertexOutput output;
            
            output.posWorld = mul(_Object2World, input.vertex);
            
            float4 workaround_cos_waveAlternatorPredef = cos(_WaveDirections);
            float4 workaround_sin_waveAlternatorPredef = sin(_WaveDirections);
            float4x2 waveDirections = float4x2(workaround_cos_waveAlternatorPredef, workaround_sin_waveAlternatorPredef);
            float2x4 waveDirectionsTranspose = transpose(waveDirections);
            
            float4 waveDirDotPos = float4(
				dot(waveDirections[0], output.posWorld.xz),
				dot(waveDirections[1], output.posWorld.xz),
				dot(waveDirections[2], output.posWorld.xz),
				dot(waveDirections[3], output.posWorld.xz));
			
			float4 waveTime = _Time.w * _WaveSpeeds;
			float2 direction = normalize(float2(1,1));
			
			float4 heightVec = _WaveAmplitudes * sin(waveDirDotPos * _WaveFreqs + waveTime);
			float4 dXVec = _WaveFreqs * waveDirectionsTranspose[0] * _WaveAmplitudes * cos(waveDirDotPos * _WaveFreqs + waveTime);
			float4 dZVec = _WaveFreqs * waveDirectionsTranspose[1] * _WaveAmplitudes * cos(waveDirDotPos * _WaveFreqs + waveTime);
			
			float height = heightVec.x + heightVec.y + heightVec.z + heightVec.w;
			float dX = dXVec.x + dXVec.y + dXVec.z + dXVec.w;
			float dZ = dZVec.x + dZVec.y + dZVec.z + dZVec.w;
			
			float3 newNormal = normalize(float3(-dX, 1, -dZ));
			
			output.posWorld.y += height;
			output.pos = mul(UNITY_MATRIX_MVP, mul(_World2Object, output.posWorld));
			
			output.normalDir = newNormal;
			output.tangentDir = normalize(float3(0, dZ, 1));
			output.binormalDir = normalize(float3(0, dX, 1));
			
            output.tex = input.texcoord;
            
            return output;
         }
 
          float4 frag(vertexOutput input) : COLOR
         {
            // in principle we have to normalize tangentWorld,
            // binormalWorld, and normalWorld again; however, the 
            // potential problems are small since we use this 
            // matrix only to compute "normalDirection", 
            // which we normalize anyways
 			
            float4 encodedNormalA = tex2D(_NormalMapA, 
               (_NormalMapA_ST.xy * input.tex.xy + _NormalMapA_ST.zw) +( float2(_Time.y, _Time.y)*_FlowSpeedA));

            float4 encodedNormalB = tex2D(_NormalMapB, 
               (_NormalMapB_ST.xy * input.tex.xy + _NormalMapB_ST.zw) +( float2(_Time.y, -_Time.y)*_FlowSpeedB));



            float3 localCoordsA = float3(2.0 * encodedNormalA.a - 1.0, 
                2.0 * encodedNormalA.g - 1.0, 0.0);


            float3 localCoordsB = float3(2.0 * encodedNormalB.a - 1.0, 
                2.0 * encodedNormalB.g - 1.0, 0.0);

			//localCoords.x = 
			//localCoords.y = cos(_Time.y * _InvertSpeedA) * localCoords.y;

			float3 localCoords = float3(0,0,0);

			localCoords.x = (localCoordsA.x + localCoordsB.x)/2;
			localCoords.y = (localCoordsA.y + localCoordsB.y)/2;

			//localCoords.x = sin(_Time.y * _InvertSpeedA) * localCoordsA.x - sin(_Time.y * _InvertSpeedB) * localCoordsB.x;
			//localCoords.y = sin(_Time.y * _InvertSpeedA) * localCoordsA.y - sin(_Time.y * _InvertSpeedB) * localCoordsB.y;

            localCoords.z = sqrt(1.0 - dot(localCoords, localCoords));


               // approximation without sqrt:  localCoords.z = 
               // 1.0 - 0.5 * dot(localCoords, localCoords);
 
            float3x3 local2WorldTranspose = float3x3(
               input.tangentDir, 
               input.binormalDir, 
               input.normalDir);
            float3 normalDirection = 
               normalize(mul(localCoords, local2WorldTranspose));
 
            float3 viewDirection = normalize(
               _WorldSpaceCameraPos - input.posWorld.xyz);
            float3 lightDirection;
            float attenuation;
 
            if (0.0 == _WorldSpaceLightPos0.w) // directional light?
            {
               attenuation = 1.0; // no attenuation
               lightDirection = normalize(_WorldSpaceLightPos0.xyz);
            } 
            else // point or spot light
            {
               float3 vertexToLightSource = 
                  _WorldSpaceLightPos0.xyz - input.posWorld.xyz;
               float distance = length(vertexToLightSource);
               attenuation = 1.0 / distance; // linear attenuation 
               lightDirection = normalize(vertexToLightSource);
            }
 
            float3 ambientLighting = 
               UNITY_LIGHTMODEL_AMBIENT.rgb * _Color.rgb;
 
            float3 diffuseReflection = 
               attenuation * _LightColor0.rgb * _Color.rgb
               * max(0.0, dot(normalDirection, lightDirection));
 
            float3 specularReflection;
            if (dot(normalDirection, lightDirection) < 0.0) 
               // light source on the wrong side?
            {
               specularReflection = float3(0.0, 0.0, 0.0); 
                  // no specular reflection
            }
            else // light source on the right side
            {
               specularReflection = attenuation * _LightColor0.rgb 
                  * _SpecColor.rgb * pow(max(0.0, dot(
                  reflect(-lightDirection, normalDirection), 
                  viewDirection)), _Shininess);
            }

            return float4(ambientLighting + diffuseReflection 
               + specularReflection, 1.0);
         }
 
         ENDCG
      }
 
//      Pass {	
//         Tags { "LightMode" = "ForwardAdd" } 
//            // pass for additional light sources
//         Blend One One // additive blending 
// 
//         CGPROGRAM
// 
//         #pragma vertex vert  
//         #pragma fragment frag 
// 
//         #include "UnityCG.cginc"
//         uniform float4 _LightColor0; 
//            // color of light source (from "Lighting.cginc")
// 
//         // User-specified properties
//         uniform float4 _Color; 
//         uniform float4 _SpecColor; 
//         uniform float _Shininess;
// 
//         struct vertexInput {
//            float4 vertex : POSITION;
//            float3 normal : NORMAL;
//         };
//         struct vertexOutput {
//            float4 pos : SV_POSITION;
//            float4 posWorld : TEXCOORD0;
//            float3 normalDir : TEXCOORD1;
//         };
// 
//         vertexOutput vert(vertexInput input) 
//         {
//            vertexOutput output;
// 
//            float4x4 modelMatrix = _Object2World;
//            float4x4 modelMatrixInverse = _World2Object; 
//               // multiplication with unity_Scale.w is unnecessary 
//               // because we normalize transformed vectors
// 
//            output.posWorld = mul(modelMatrix, input.vertex);
//            output.normalDir = normalize(
//               mul(float4(input.normal, 0.0), modelMatrixInverse).xyz);
//            output.pos = mul(UNITY_MATRIX_MVP, input.vertex);
//            return output;
//         }
// 
//         float4 frag(vertexOutput input) : COLOR
//         {
//            float3 normalDirection = normalize(input.normalDir);
// 
//            float3 viewDirection = normalize(
//               _WorldSpaceCameraPos - input.posWorld.xyz);
//            float3 lightDirection;
//            float attenuation;
// 
//            if (0.0 == _WorldSpaceLightPos0.w) // directional light?
//            {
//               attenuation = 1.0; // no attenuation
//               lightDirection = normalize(_WorldSpaceLightPos0.xyz);
//            } 
//            else // point or spot light
//            {
//               float3 vertexToLightSource = 
//                  _WorldSpaceLightPos0.xyz - input.posWorld.xyz;
//               float distance = length(vertexToLightSource);
//               attenuation = 1.0 / distance; // linear attenuation 
//               lightDirection = normalize(vertexToLightSource);
//            }
// 
//            float3 diffuseReflection = 
//               attenuation * _LightColor0.rgb * _Color.rgb
//               * max(0.0, dot(normalDirection, lightDirection));
// 
//            float3 specularReflection;
//            if (dot(normalDirection, lightDirection) < 0.0) 
//               // light source on the wrong side?
//            {
//               specularReflection = float3(0.0, 0.0, 0.0); 
//                  // no specular reflection
//            }
//            else // light source on the right side
//            {
//               specularReflection = attenuation * _LightColor0.rgb 
//                  * _SpecColor.rgb * pow(max(0.0, dot(
//                  reflect(-lightDirection, normalDirection), 
//                  viewDirection)), _Shininess);
//            }
// 
//            return float4(diffuseReflection 
//               + specularReflection, 1.0);
//               // no ambient lighting in this pass
//         }
// 
//         ENDCG
//      }
   }
   // The definition of a fallback shader should be commented out 
   // during development:
   // Fallback "Specular"
}