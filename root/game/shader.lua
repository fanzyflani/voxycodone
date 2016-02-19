return shader.new({vert=[=[
#version 130

uniform mat4 in_cam_inverse;

in vec2 in_vec;
uniform vec3 cam_pos;
out vec3 cam_dir;
void main()
{
	cam_dir = normalize((-in_cam_inverse[2]
		+ in_cam_inverse[0] * in_vec.x * 1280.0/720.0
		+ in_cam_inverse[1] * in_vec.y
		).yxz)*vec3(-1.0, 1.0, 1.0);

	gl_Position = vec4(in_vec, 0.1, 1.0);
}

]=],frag=bin_load("frag.glsl")}, {"in_vec"}, {"fcol"})

