	Shader "Custom/Water" {
	Properties {
		_Color ("Diffuse Material Color", Color) = (1,1,1,1) 
		_SpecColor ("Specular Material Color", Color) = (1,1,1,1) 
		_Shininess ("Shininess", Float) = 10
		_MainTex ("Water texture", 2D) = "black" {}
		_BubbleTex ("Bubble texture", 2D) = "black" {}
		_BubbleMinIntes ("bubble min alt", float) = 1.0
		_BubbleMaxIntes ("bubble max alt", float) = 2.0
		_NormalMapA ("Normal map A", 2D) = "bump" {}
		_FlowSpeedA ("Flow Speed A", float) = 1.0
		_NormalMapB ("Normal map B", 2D) = "bump" {}
		_FlowSpeedB ("Flow Speed B", float) = 1.0
		_WaveDirections ("4 Wave Directions (range: 0 - 2*pi)", Vector) = (1,1,1,1)
		_WaveAmplitudes ("4 Wave Amplitude (range: 0 - 1)", Vector) = (1,1,1,1)
		_WaveAmplitudeMultiplier ("Amplitude multiplier (range: 0 - 4)", float) = 1.0
		_WaveSpeeds ("4 Wave Speeds", Vector) = (1,1,1,1)
		_WaveFreqs ("4 Wave Frequencies", Vector) = (1,1,1,1)
	}
	SubShader {
		Pass {	
			Tags { "LightMode" = "ForwardBase" } 
			
			CGPROGRAM
			// Upgrade NOTE: excluded shader from OpenGL ES 2.0 because it uses non-square matrices
			#pragma exclude_renderers gles
			
			#pragma vertex vert  
			#pragma fragment frag 
			
			uniform float4 _LightColor0; 
			
			uniform float4 _Color; 
			uniform float4 _SpecColor; 
			uniform float _Shininess;
			uniform float4 _WaveDirections;
			uniform float4 _WaveAmplitudes;
			uniform float _WaveAmplitudeMultiplier;
			uniform float4 _WaveSpeeds;
			uniform float4 _WaveFreqs;
			
			uniform sampler2D _MainTex;
			uniform float4 _MainTex_ST;
			
			uniform sampler2D _BubbleTex;
			uniform float4 _BubbleTex_ST;
			uniform float _BubbleMinIntes;		
			uniform float _BubbleMaxIntes;
			
			uniform sampler2D _NormalMapA;	
			uniform float4 _NormalMapA_ST;
			uniform float _FlowSpeedA;
			
			uniform sampler2D _NormalMapB;	
			uniform float4 _NormalMapB_ST;
			uniform float _FlowSpeedB;
			
			
			struct vertexInput {
				float4 vertex : POSITION;
				float4 texcoord : TEXCOORD0;
				float3 normal : NORMAL;
				float4 tangent : TANGENT;
			};
			struct vertexOutput {
				float4 pos : SV_POSITION;
				float4 posLocal : TEXCOORD5;
				float4 posWorld : TEXCOORD0;
				float4 tex : TEXCOORD1;
				float3 normalDir : TEXCOORD2;
				float3 tangentDir : TEXCOORD3;
				float3 binormalDir : TEXCOORD4;
			};
			
			vertexOutput vert(vertexInput input) 
			{
				vertexOutput output;
				
				// World position of the vertex


				output.posWorld = mul(_Object2World, input.vertex);
				
				// Clamp input values to avoid extreem values
				_WaveDirections = fmod(_WaveDirections, 2*3.14159);
				_WaveAmplitudes = clamp(_WaveAmplitudes, 0, 1);
				_WaveAmplitudeMultiplier = clamp(_WaveAmplitudeMultiplier, 0, 4);
				
				// Calculate direction vectors for the 4 waves
				float4 waveDirSin = cos(_WaveDirections);
				float4 waveDirCos = sin(_WaveDirections);

				float2x4 waveDirectionsInv = float2x4(waveDirCos, waveDirSin);
				float4x2 waveDirections = transpose(waveDirectionsInv);

				// Dot product between each direction vector and the vertex's position vector
				float4 waveDirDotPos = float4(
					dot(waveDirections[0], output.posWorld.xz),
					dot(waveDirections[1], output.posWorld.xz),
					dot(waveDirections[2], output.posWorld.xz),
					dot(waveDirections[3], output.posWorld.xz));
				
				// Where is the wave at the current point in time?...
				float4 waveTime = _Time.w * _WaveSpeeds;
				
				// Calculate the height of each wave at the vertex's position at this point in time
				// Formula: A_i * sin( dot(D_i, P) * w + t * S )
				// A = amplitude  -  D = wave direction  -  P = vertex pos.(x,z)  -  w = frequency  -  t = time  -  S = speed  -  i = wave index
				float4 heightVec = _WaveAmplitudeMultiplier * _WaveAmplitudes * sin(waveDirDotPos * _WaveFreqs + waveTime);
				// Calculate the derivative of the height with respect to the x-pos and z-pos (used to find the normal, bi-normal, tangent of the wave at this vertex)
				
				float4 initCalc = _WaveFreqs  * _WaveAmplitudeMultiplier * _WaveAmplitudes * cos(waveDirDotPos * _WaveFreqs + waveTime);

				float4 dXVec =  waveDirectionsInv[0] * initCalc;
				float4 dZVec = waveDirectionsInv[1] * initCalc;
				
				// Sum of the heights and derivative coordinates
				float height = heightVec.x + heightVec.y + heightVec.z + heightVec.w;
				float dX = dXVec.x + dXVec.y + dXVec.z + dXVec.w;
				float dZ = dZVec.x + dZVec.y + dZVec.z + dZVec.w;
				
				// Position of the vertex should now be shifted by the height calculated
				output.posWorld.y += height;

				output.posLocal = mul(_World2Object, output.posWorld);
				output.pos = mul(UNITY_MATRIX_VP, output.posWorld);
				
				//output.pos = mul(UNITY_MATRIX_P, (UNITY_MATRIX_V, output.posWorld));
				
				// Output the normals and tangent
				output.normalDir = normalize(float3(-dX, 1, -dZ));
				output.tangentDir = normalize(float3(0, dZ, 1));
				output.binormalDir = normalize(float3(1, dX, 0));
				
				output.tex = input.texcoord;

				
				
				return output;
			}
			
			float4 frag(vertexOutput input) : COLOR
			{
				// We map the normal maps with the scale and offset. The unity_scale is used to make sure the normal maps are mapped accordingly no matter the objects scale

				float4 encodedNormalA = tex2D(_NormalMapA, 
					(_NormalMapA_ST.xy * input.tex.xy / unity_Scale.w + _NormalMapA_ST.zw) +( float2(_Time.y, _Time.y)*_FlowSpeedA));
				
				float4 encodedNormalB = tex2D(_NormalMapB, 
					(_NormalMapB_ST.xy * input.tex.xy / unity_Scale.w + _NormalMapB_ST.zw) +( float2(_Time.y, -_Time.y)*_FlowSpeedB));
				
				float3 localCoordsA = float3(2.0 * encodedNormalA.a - 1.0, 
					2.0 * encodedNormalA.g - 1.0, 0.0);
				
				float3 localCoordsB = float3(2.0 * encodedNormalB.a - 1.0, 
					2.0 * encodedNormalB.g - 1.0, 0.0);
				
				// Blending of normal maps

				float3 localCoords = float3(0,0,0);
				localCoords.x = (localCoordsA.x + localCoordsB.x)/2;
				localCoords.y = (localCoordsA.y + localCoordsB.y)/2;
								
				localCoords.z = sqrt(1.0 - dot(localCoords, localCoords));
				
				// Normal direction with normal maps applied is calculated

				float3x3 local2WorldTranspose = float3x3(
					input.tangentDir, 
					input.binormalDir, 
					input.normalDir);
				float3 normalDirection = 
					normalize(mul(localCoords, local2WorldTranspose));
				
				//Calculate the direction from which the camera is viewing at the object

				float3 viewDirection = normalize(_WorldSpaceCameraPos - input.posWorld.xyz);

				float3 lightDirection = normalize(_WorldSpaceLightPos0.xyz);

				//Calculate the light added by ambient and material color;

				float3 ambientLighting = 
					UNITY_LIGHTMODEL_AMBIENT.rgb * _Color.rgb;
				
				//Calculate the diffuse color with its intensity

				float3 diffuseReflection = _LightColor0.rgb * _Color.rgb
					* max(0.0, dot(normalDirection, lightDirection));
				
				//Calculate the specular color with its intensity

				float3 specularReflection;
				if (dot(normalDirection, lightDirection) < 0.0) 
				{
					specularReflection = float3(0.0, 0.0, 0.0); 
				}
				else
				{
					specularReflection = _LightColor0.rgb 
						* _SpecColor.rgb * pow(max(0.0, dot(
						reflect(-lightDirection, normalDirection), 
						viewDirection)), _Shininess);
				}
				
				//Add bubble texture with the intensity dependant on local positions y axis

				float bubbleIntes = min(1.0,max( 0.0,(input.posLocal.y - _BubbleMinIntes) / (_BubbleMaxIntes - _BubbleMinIntes)));

				float4 bubbleCol = tex2D(_BubbleTex, _BubbleTex_ST.xy * input.tex.xy / unity_Scale.w + _BubbleTex_ST.zw) * bubbleIntes;
				
				float4 mainTexColor = tex2D(_MainTex, _MainTex_ST.xy * input.tex.xy / unity_Scale.w + _MainTex_ST.zw);
				
				//Final color calculation

				return float4(ambientLighting + diffuseReflection 
					+ specularReflection, 1.0) + mainTexColor + bubbleCol;
			}

			ENDCG
		}
	}
	Fallback "Specular"
}