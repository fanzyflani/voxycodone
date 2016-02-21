glslver = (VOXYCODONE_GL_COMPAT_PROFILE and "120\n#define COMPAT\n") or "130"
return shader.new({vert="#version "..glslver..[=[

#ifdef COMPAT
#define a_in_vert attribute
#define a_vert_frag varying
#else
#define a_in_vert in
#define a_vert_frag out
#endif

uniform mat4 in_cam_inverse;

a_in_vert vec2 in_vec;
uniform vec3 cam_pos;
a_vert_frag vec3 cam_dir;
a_vert_frag vec2 cam_texcoord;
void main()
{
	cam_dir = normalize((-in_cam_inverse[2]
		+ in_cam_inverse[0] * in_vec.x * 1280.0/720.0
		+ in_cam_inverse[1] * in_vec.y
		).yxz)*vec3(-1.0, 1.0, 1.0);

	cam_texcoord = in_vec;
	gl_Position = vec4(in_vec, 0.1, 1.0);
}

]=],frag="#version "..glslver.."\n"..bin_load("frag.glsl")},
{"in_vec"}, {"fcol"}), shader.new(
{vert="#version "..glslver..[=[

#ifdef COMPAT
#define a_in_vert attribute
#define a_vert_frag varying
#else
#define a_in_vert in
#define a_vert_frag out
#endif

uniform mat4 in_cam_inverse;

a_in_vert vec2 in_vec;
uniform vec3 cam_pos;
a_vert_frag vec3 cam_dir;
a_vert_frag vec2 cam_texcoord;
void main()
{
	cam_dir = normalize((-in_cam_inverse[2]
		+ in_cam_inverse[0] * in_vec.x * 1280.0/720.0
		+ in_cam_inverse[1] * in_vec.y
		).yxz)*vec3(-1.0, 1.0, 1.0);

	cam_texcoord = in_vec;
	gl_Position = vec4(in_vec, 0.1, 1.0);
}

]=],frag="#version "..glslver.."\n#define BEAMER\n"..bin_load("frag.glsl")}, {"in_vec"}, {"fcol"})


