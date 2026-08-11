#include "common.hlsl"

float4 main(PS_INPUT input) : COLOR
{
	float3 normal = normalize(input.localNormal);
	float3 view = normalize(Constants1.xyz - input.localPosition);
	float facing = abs(dot(normal, view));
	float grazing = 1.0 - smoothstep(0.08, 0.55, facing);
	float pillar = step(0.5, Constants2.y);
	float radialLength = max(length(normal.xy), 0.0001);
	float3 pillarTangentU = float3(-normal.y / radialLength,
		normal.x / radialLength, 0.0);
	float3 tangentU = lerp(float3(1.0, 0.0, 0.0), pillarTangentU, pillar);
	float3 tangentV = lerp(float3(0.0, 1.0, 0.0),
		float3(0.0, 0.0, -1.0), pillar);
	float2 slope = float2(dot(view, tangentU), dot(view, tangentV)) /
		max(facing, 0.15);
	float2 shear = clamp(slope * Constants2.x * grazing,
		float2(-0.06, -0.06), float2(0.06, 0.06));
	float edgeDistance = min(min(input.uv.x, 1.0 - input.uv.x),
		min(input.uv.y, 1.0 - input.uv.y));
	shear *= smoothstep(0.0, 0.025, edgeDistance);
	float2 sampleUV = saturate(input.uv - shear);
	float4 albedo = tex2D(TexBase, sampleUV);
	float matrixAngle = (1.0 - smoothstep(0.08, 0.62, facing)) * Constants2.z;
	float verticalAngle = dot(view, tangentV);
	float3 matrixGamma = float3(
		0.84 - verticalAngle * 0.04,
		0.88,
		0.84 + verticalAngle * 0.04
	);
	float3 screenColor = pow(saturate(albedo.rgb),
		lerp(float3(1.0, 1.0, 1.0), matrixGamma, matrixAngle));
	float luminance = dot(screenColor, float3(0.2126, 0.7152, 0.0722));
	screenColor = lerp(screenColor, float3(luminance, luminance, luminance),
		matrixAngle * 0.12);
	float3 angleTint = lerp(float3(0.92, 0.98, 1.08),
		float3(1.08, 0.98, 0.92), verticalAngle * 0.5 + 0.5);
	screenColor *= lerp(float3(1.0, 1.0, 1.0), angleTint,
		matrixAngle * 0.2);
	screenColor = lerp(screenColor, float3(0.17, 0.18, 0.2),
		matrixAngle * 0.12);
	float inverseW = 1.0 / max(abs(input.projected.w), 0.0001);
	float2 lightUV = float2(
		input.projected.x * inverseW * 0.5 + 0.5,
		-input.projected.y * inverseW * 0.5 + 0.5
	);
	float3 light = tex2D(Tex1, lightUV).rgb;
	float maximum = max(light.r, max(light.g, light.b));
	float minimum = min(light.r, min(light.g, light.b));
	float saturation = (maximum - minimum) / max(maximum, 0.0001);
	float intensityGate = smoothstep(0.1, 0.65, maximum);
	float colorGate = smoothstep(0.15, 0.65, saturation);
	float dominance = intensityGate * colorGate * Constants0.y;
	float3 chroma = light / max(maximum, 0.0001);
	float3 filter = lerp(float3(1.0, 1.0, 1.0), chroma, dominance);
	float3 selectiveAlbedo = pow(saturate(screenColor), 2.2);
	float3 reflected = lerp(screenColor, selectiveAlbedo, dominance);

	return float4(reflected * filter * input.color.rgb * Constants0.x,
		albedo.a);
}
