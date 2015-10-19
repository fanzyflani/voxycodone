// vim: syntax=c
#version 150

in vec2 tc;
out vec4 out_frag_color;

uniform sampler2D tex0;
uniform sampler2D tex1;

void main()
{
	vec3 c0 = texture(tex0, tc, 0).rgb;

	vec3 b0 = textureOffset(tex1, tc, ivec2(0,0), 0).rgb;
	vec3 b1 = (0.0
		+ textureOffset(tex1, tc, ivec2( 1, 0), 0).rgb
		+ textureOffset(tex1, tc, ivec2( 0, 1), 0).rgb
		+ textureOffset(tex1, tc, ivec2(-1, 0), 0).rgb
		+ textureOffset(tex1, tc, ivec2( 0,-1), 0).rgb
		);
	vec3 b2 = (0.0
		+ textureOffset(tex1, tc, ivec2( 1, 1), 0).rgb
		+ textureOffset(tex1, tc, ivec2(-1,-1), 0).rgb
		+ textureOffset(tex1, tc, ivec2(-1, 1), 0).rgb
		+ textureOffset(tex1, tc, ivec2( 1,-1), 0).rgb
		);
	/*
	vec3 b3 = (0.0
		+ textureOffset(tex1, tc, ivec2( 2, 1), 0).rgb
		+ textureOffset(tex1, tc, ivec2(-1,-2), 0).rgb
		+ textureOffset(tex1, tc, ivec2(-1, 2), 0).rgb
		+ textureOffset(tex1, tc, ivec2( 2,-1), 0).rgb
		+ textureOffset(tex1, tc, ivec2( 1, 2), 0).rgb
		+ textureOffset(tex1, tc, ivec2(-2,-1), 0).rgb
		+ textureOffset(tex1, tc, ivec2(-2, 1), 0).rgb
		+ textureOffset(tex1, tc, ivec2( 1,-2), 0).rgb
		);
	*/
	//vec3 c1 = (b0+b1+b2+b3)/(1.0+4.0+4.0+8.0);
	vec3 c1 = b0*0.5+(b1*0.3+b2*0.2)/4.0;

	out_frag_color = vec4(c0+c1, 1.0);
}

