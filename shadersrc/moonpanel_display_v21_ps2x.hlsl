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
	float3 light = lerp(float3(1.0, 1.0, 1.0),
		saturate(tex2D(Tex1, lightUV).rgb), Constants0.w);
	float lightMaximum = max(light.r, max(light.g, light.b));
	float lightMinimum = min(light.r, min(light.g, light.b));
	float lightRange = lightMaximum - lightMinimum;
	float lightSaturation = lightRange / max(lightMaximum, 0.0001);
	float lightEnergy = smoothstep(0.0005, 0.004, lightMaximum);
	float coloredLight = smoothstep(0.12, 0.58, lightSaturation) *
		lightEnergy * Constants0.w;

	// The sampled Witness response preserves tiny non-zero lamp values and
	// approaches a square-root curve before its highlight shoulder.
	float3 curvedLight = pow(light, float3(0.45, 0.45, 0.45));
	curvedLight = saturate(curvedLight * (2.4 - 1.4 * curvedLight));

	float neutralLight = pow(saturate(dot(light,
		float3(0.3333, 0.3333, 0.3333))), 0.65);

	float sourceMaximum = max(screenColor.r,
		max(screenColor.g, screenColor.b));
	float stark = smoothstep(0.58, 0.82, sourceMaximum);
	float3 membership = step(sourceMaximum * 0.38, screenColor);
	float3 normalizedColor = screenColor / max(sourceMaximum, 0.0001);
	float3 clueReflectance = normalizedColor * membership;
	float3 clueLit = curvedLight * clueReflectance;
	float3 neutralClueLit = screenColor * neutralLight;
	float3 drivenClueLit = lerp(neutralClueLit, clueLit, coloredLight);

	// Dark panel materials use a much straighter response than clue pixels.
	float surfaceGamma = lerp(0.95, 0.62,
		smoothstep(0.12, 0.72, sourceMaximum));
	float3 surfaceLight = pow(light,
		float3(surfaceGamma, surfaceGamma, surfaceGamma));
	float3 surfaceLit = screenColor * surfaceLight;
	float3 lightDrivenResult = lerp(surfaceLit, drivenClueLit, stark);
	float3 reflected = lerp(screenColor, lightDrivenResult, Constants0.y);
	reflected *= input.color.rgb * Constants0.x;

	// HDR overbright values feed Source's normal bloom pass. Backlit panels
	// keep their authored emission in gamut; their glare is a separate pass.
	float visibleMaximum = max(reflected.r, max(reflected.g, reflected.b));
	float bloom = smoothstep(0.72, 0.96, sourceMaximum) *
		smoothstep(0.58, 0.92, visibleMaximum) * Constants0.z * Constants0.y;
	reflected *= 1.0 + bloom;

	return float4(reflected, albedo.a);
}
