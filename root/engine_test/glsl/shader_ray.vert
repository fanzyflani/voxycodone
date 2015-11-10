// vim: syntax=c
#version 150

%include glsl/common.glsl

invariant out vec3 wpos_in;
out vec3 wdir_in;
in vec2 in_vertex;

void main()
{
	wdir_in = (in_cam_inverse * vec4(in_vertex / in_aspect, -1.0, 0.0)).xyz;
	wpos_in = (in_cam_inverse * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	gl_Position = vec4(in_vertex, 0.1, 1.0);
}

