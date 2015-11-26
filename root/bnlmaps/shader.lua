if VOXYCODONE_GL_COMPAT_PROFILE then
	local selector = bin_load("glsl/compat/selector.frag")
	return shader.new({
	vert = [=[
	#version 120

	uniform float time;
	uniform mat4 in_cam_inverse;

	attribute vec2 in_vertex;

	varying vec3 vert_ray_step;
	invariant varying vec3 vert_cam_pos;
	varying vec2 vert_tc;

	void main()
	{
		//vert_ray_step = (in_cam_inverse * vec4(in_vertex.x * 1280.0/720.0, in_vertex.y, -1.0, 0.0)).xyz;
		//vert_ray_step = (in_cam_inverse * vec4(vec2(in_vertex.x, in_vertex.y * 720.0/1280.0)
		vert_ray_step = (in_cam_inverse * vec4(vec2(in_vertex.x * 1280.0/720.0, in_vertex.y)
			* tan(90.0*3.141593/180.0/2.0),
			-1.0, 0.0)).xyz;
		vert_cam_pos = (in_cam_inverse * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
		vert_tc = (in_vertex+1.0)/2.0;
		gl_Position = vec4(in_vertex, 0.1, 1.0);
	}

	]=],

	frag =
	"#version 120\n#define TRACER\n"..
	string.format("const vec2 MULDEPTH = 4.0/vec2(%f, %f);\n", screen_w/screen_scale, screen_h/screen_scale)..
	selector,

	}, {"in_vertex",}, {"out_color",}), shader.new({
	vert = [=[
	#version 120

	uniform float time;
	uniform mat4 in_cam_inverse;

	attribute vec2 in_vertex;

	varying vec3 vert_ray_step;
	invariant varying vec3 vert_cam_pos;
	varying vec2 vert_tc;

	void main()
	{
		//vert_ray_step = (in_cam_inverse * vec4(in_vertex.x * 1280.0/720.0, in_vertex.y, -1.0, 0.0)).xyz;
		//vert_ray_step = (in_cam_inverse * vec4(vec2(in_vertex.x, in_vertex.y * 720.0/1280.0)
		vert_ray_step = (in_cam_inverse * vec4(vec2(in_vertex.x * 1280.0/720.0, in_vertex.y)
			* tan(90.0*3.141593/180.0/2.0),
			-1.0, 0.0)).xyz;
		vert_cam_pos = (in_cam_inverse * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
		vert_tc = (in_vertex+1.0)/2.0;
		gl_Position = vec4(in_vertex, 0.1, 1.0);
	}

	]=],

	frag =
	"#version 120\n#define BEAMER\n"..
	string.format("const vec2 MULDEPTH = 4.0/vec2(%f, %f);\n", screen_w/screen_scale, screen_h/screen_scale)..
	selector,

	}, {"in_vertex",}, {"out_depth",})
end

local selector = bin_load("glsl/selector.frag")

return shader.new({
vert = [=[
#version 130

uniform float time;
uniform mat4 in_cam_inverse;

in vec2 in_vertex;

out vec3 vert_ray_step;
flat out vec3 vert_cam_pos;
out vec2 vert_tc;
out vec2 vert_vertex;

void main()
{
	//vert_ray_step = (in_cam_inverse * vec4(in_vertex.x * 1280.0/720.0, in_vertex.y, -1.0, 0.0)).xyz;
	//vert_ray_step = (in_cam_inverse * vec4(vec2(in_vertex.x, in_vertex.y * 720.0/1280.0)
	vert_ray_step = (in_cam_inverse * vec4(vec2(in_vertex.x * 1280.0/720.0, in_vertex.y)
		* tan(90.0*3.141593/180.0/2.0),
		-1.0, 0.0)).xyz;
	vert_cam_pos = (in_cam_inverse * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	vert_tc = (in_vertex+1.0)/2.0;
	vert_vertex = in_vertex * vec2(1280.0/720.0, 1.0);
	gl_Position = vec4(in_vertex, 0.1, 1.0);
}

]=],

frag = "#version 130\n#define TRACER\n"..selector,
}, {"in_vertex",}, {"out_color",}), shader.new({
vert = [=[
#version 130

uniform float time;
uniform mat4 in_cam_inverse;

in vec2 in_vertex;

out vec3 vert_ray_step;
flat out vec3 vert_cam_pos;
out vec2 vert_tc;
out vec2 vert_vertex;

void main()
{
	//vert_ray_step = (in_cam_inverse * vec4(in_vertex.x * 1280.0/720.0, in_vertex.y, -1.0, 0.0)).xyz;
	//vert_ray_step = (in_cam_inverse * vec4(vec2(in_vertex.x, in_vertex.y * 720.0/1280.0)
	vert_ray_step = (in_cam_inverse * vec4(vec2(in_vertex.x * 1280.0/720.0, in_vertex.y)
		* tan(90.0*3.141593/180.0/2.0),
		-1.0, 0.0)).xyz;
	vert_cam_pos = (in_cam_inverse * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	vert_tc = (in_vertex+1.0)/2.0;
	vert_vertex = in_vertex * vec2(1280.0/720.0, 1.0);
	gl_Position = vec4(in_vertex, 0.1, 1.0);
}

]=],

frag = "#version 130\n#define BEAMER\n"..selector,
}, {"in_vertex",}, {"out_depth",})



