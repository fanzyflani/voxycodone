#version 150

const int SPH_MAX = 255;

uniform sampler2D tex0;
uniform vec2 tex0_size;
uniform vec2 tex0_isize;

uniform int sph_count;

invariant out vec3 wpos_in;
out vec3 wdir_in;

attribute vec2 in_vertex;
uniform mat4 in_cam_inverse;
uniform vec2 in_aspect;

vec4 fetch_data(int x, int y)
{
	vec2 tc = vec2(float(x), float(y));
	return texture2D(tex0, (tc+0.4)*tex0_isize);
}

float decode_float(vec4 c)
{
	c = floor(c * 255.0 + 0.3);
	return ((c.b + c.g*256.0 + (c.r-128.0)*256.0*256.0))/1024.0;
	//return 1.0;
}

void main()
{
	wdir_in = (in_cam_inverse * vec4(in_vertex / in_aspect, -1.0, 0.0)).xyz;
	wpos_in = (in_cam_inverse * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	gl_Position = vec4(in_vertex, 0.1, 1.0);
}

