sampler TexBase : register(s0);
sampler Tex1 : register(s1);

const float4 Constants0 : register(c0);
const float4 Constants1 : register(c1);
const float4 Constants2 : register(c2);

struct PS_INPUT
{
	float2 uv : TEXCOORD0;
	float4 projected : TEXCOORD1;
	float3 localPosition : TEXCOORD2;
	float4 color : TEXCOORD3;
	float3 localNormal : TEXCOORD4;
};
