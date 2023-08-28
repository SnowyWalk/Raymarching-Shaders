Shader "SnowyWalk/Aurora"
{
	Properties
	{
		_TimeScale ("타임 스케일", Float) = 1.
	}
	SubShader
	{
		Tags { "RenderType"="Opaque" }
		LOD 100

		Pass
		{
			Cull Front

			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			// make fog work
			#pragma multi_compile_fog

			#include "UnityCG.cginc"

			struct appdata
			{
				float4 vertex : POSITION;
			};

			struct v2f
			{
				float4 vertex : SV_POSITION;
				float3 uv : TEXCOORD0;
				//float3 viewDir : TEXCOORD1;
				UNITY_FOG_COORDS(1)
			};

			float _TimeScale;

			v2f vert (appdata v)
			{
				v2f o;
				o.vertex = UnityObjectToClipPos(v.vertex);
				o.uv = mul(unity_ObjectToWorld, v.vertex).xyz;
				return o;
			}

			#define time (_Time.y * _TimeScale)

			fixed2x2 mm2(in float a){float c = cos(a), s = sin(a);return fixed2x2(c,s,-s,c);}
			float tri(in float x){return clamp(abs(frac(x)-.5),0.01,0.49);}
			fixed2 tri2(in fixed2 p){return fixed2(tri(p.x)+tri(p.y),tri(p.y+tri(p.x)));}

			float triNoise2d(in fixed2 p, float spd)
			{
				float z=1.8;
				float z2=2.5;
				float rz = 0.;
				p = mul(p, mm2(p.x*0.06));
				fixed2 bp = p;
				for (float i=0.; i<5.; i++ )
				{
					fixed2 dg = tri2(bp*1.85)*.75;
					dg = mul(dg, mm2(time*spd));
					p -= dg/z2;

					bp = mul(bp, 1.3);
					z2 = mul(z2, .45);
					z = mul(z, .42);
					p = mul(p, 1.21 + (rz-1.0)*.02);
					
					rz += tri(p.x+tri(p.y))*z;
					p = mul(p, -fixed2x2(0.95534, 0.29552, -0.29552, 0.95534));
				}
				return clamp(1./pow(rz*29., 1.3),0.,.55);
			}

			float hash21(in fixed2 n){ return frac(sin(dot(n, fixed2(12.9898, 4.1414))) * 43758.5453); }
			fixed4 aurora(fixed3 ro, fixed3 rd, float4 vertex)
			{
				fixed4 col = fixed4(0,0,0,0);
				fixed4 avgCol = fixed4(0,0,0,0);
				
				[unroll(50)]
				for(float i=0.;i<50.;i++)
				{
					float of = 0.006*hash21(vertex.xy)*smoothstep(0.,15., i);
					float pt = ((.8+pow(i,1.4)*.002)-ro.y)/(rd.y*2.+0.4);
					pt -= of;
					fixed3 bpos = ro + pt*rd;
					fixed2 p = bpos.zx;
					float rzt = triNoise2d(p, 0.06);
					fixed4 col2 = fixed4(0,0,0, rzt);
					col2.rgb = (sin(1.-fixed3(2.15,-.5, 1.2)+i*0.043)*0.5+0.5)*rzt;
					avgCol =  lerp(avgCol, col2, .5);
					col += avgCol*exp2(-i*0.065 - 2.5)*smoothstep(0.,5., i);
					
				}
				
				col = mul(col, (clamp(rd.y*15.+.4,0.,1.)));
				
				return col*1.8;
			}

			//-------------------Background and Stars--------------------

			fixed3 nmzHash33(fixed3 q)
			{
				int3 p = uint3(int3(q));
				p = p*uint3(374761393U, 1103515245U, 668265263U) + p.zxy + p.yzx;
				p = p.yzx*(p.zxy^(p >> 3U));
				return fixed3(p^(p >> 16U))*(1.0/fixed3(0xffffffffU,0xffffffffU,0xffffffffU));
			}

			fixed3 stars(in fixed3 p, float2 uv)
			{
				fixed3 c = 0.;
				float res = 1000;
				//p.y += _Time.y * 0.1;  // 시간에 따라 y값을 조정
				
				for (float i = 0.; i < 3.; i++)
				{
					fixed3 q = frac(p * (.15 * res)) - 0.5;
					fixed3 id = floor(p * (.15 * res));
					fixed2 rn = nmzHash33(id).xy;
					float c2 = 1. - smoothstep(0., .6, length(q));
					c2 = mul(step(rn.x, .0005 + i * i * 0.001), c2);
					c += c2 * (lerp(fixed3(1.0, 0.49, 0.1), fixed3(0.75, 0.9, 1.), rn.y) * 0.1 + 0.9);
					p = mul(p, 1.3);
				}
				return c * c * .8;
			}

			fixed3 bg(in fixed3 rd)
			{
				float sd = dot(normalize(fixed3(-0.5, -0.6, 0.9)), rd)*0.5+0.5;
				sd = pow(sd, 5.);
				fixed3 col = lerp(fixed3(0.05,0.1,0.2), fixed3(0.1,0.05,0.2), sd);
				return col*.63;
			}

			fixed4 frag (v2f i) : SV_Target
			{
				fixed3 ro = fixed3(0,0,-6.7);
				fixed3 rd = normalize(i.uv - _WorldSpaceCameraPos);
				
				fixed3 col = 0.;
				float fade = smoothstep(0.,0.01,abs(rd.y))*0.1+0.9;
				
				col = bg(rd)*fade;
				
				if (rd.y > 0.){
					fixed4 aur = smoothstep(0.,1.5,aurora(ro,rd, i.vertex))*fade;
					col += stars(rd, i.uv);
					col = col * (1.-aur.a) + aur.rgb;
				}
				else //Reflections
				{
					rd.y = abs(rd.y);
					col = bg(rd)*fade*0.6;
					fixed4 aur = smoothstep(0.0,2.5,aurora(ro,rd, i.vertex));
					col += stars(rd, i.uv)*0.1;
					col = col*(1.-aur.a) + aur.rgb;
					fixed3 pos = ro + ((0.5-ro.y)/rd.y)*rd;
					float nz2 = triNoise2d(pos.xz*fixed2(.5,.7), .5);
					col += lerp(fixed3(0.2,0.25,0.5)*0.08,fixed3(0.3,0.3,0.5)*0.7, nz2*0.4);
				}
				
				return fixed4(col, 1.);
			}
			ENDCG
		}
	}
}
