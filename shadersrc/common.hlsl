sampler TexBase : register(s0);
sampler Tex1 : register(s1);
sampler Tex2 : register(s2);
sampler Tex3 : register(s3);

float2 TexBaseSize : register(c4);
float2 Tex1Size : register(c5);
float2 Tex2Size : register(c6);
float2 Tex3Size : register(c7);

const float4 Constants0 : register(c0);
const float4 Constants1 : register(c1);
const float4 Constants2 : register(c2);
const float4 Constants3 : register(c3);

struct PS_INPUT
{
	float2 uv : TEXCOORD0;
	float4 projected : TEXCOORD1;
	float3 localPosition : TEXCOORD2;
	float4 color : TEXCOORD3;
	float3 localNormal : TEXCOORD4;
};
