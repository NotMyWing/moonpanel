#include "common.hlsl"

float4 main(PS_INPUT input) : COLOR
{
	float4 albedo = tex2D(TexBase, input.uv);
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
	float dominance = intensityGate * colorGate;
	float3 chroma = light / max(maximum, 0.0001);
	float3 filter = lerp(float3(1.0, 1.0, 1.0), chroma, dominance);
	float3 selectiveAlbedo = pow(saturate(albedo.rgb), 2.2);
	float3 reflected = lerp(albedo.rgb, selectiveAlbedo, dominance);

	return float4(reflected * filter * Constants0.x, albedo.a);
}
