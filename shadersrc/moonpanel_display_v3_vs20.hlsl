const float4x4 ViewProjection : register(c8);
const float4x3 Model : register(c58);

struct VS_INPUT
{
	float4 position : POSITION;
	float2 uv : TEXCOORD0;
	float4 color : COLOR0;
};

struct VS_OUTPUT
{
	float4 position : POSITION;
	float2 uv : TEXCOORD0;
	float4 projected : TEXCOORD1;
	float4 color : TEXCOORD3;
};

VS_OUTPUT main(VS_INPUT input)
{
	VS_OUTPUT output;
	float3 worldPosition = mul(input.position, Model);
	output.position = mul(float4(worldPosition, 1.0), ViewProjection);
	output.uv = input.uv;
	output.projected = output.position;
	output.color = input.color;
	return output;
}
