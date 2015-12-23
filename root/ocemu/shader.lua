selector = [=[
in vec3 vert_ray_step;
flat in vec3 vert_cam_pos;
in vec2 vert_tc;
in vec2 vert_vertex;

out vec4 out_color;

uniform sampler2DArray tex_font;
uniform usampler2D tex_chars;
uniform sampler1D tex_palette;
uniform uvec2 virtual_screen_size;

void main()
{
	vec3 ray_pos = vert_cam_pos;
	vec3 ray_dir = normalize(vert_ray_step);
	float zfar = 10000.0;
	float znear = 0.0;

	vec2 subpos = vec2(vert_tc.x, 1.0-vert_tc.y)*vec2(virtual_screen_size);
	ivec2 cellpos = ivec2(floor(subpos));
	subpos -= floor(subpos);

	uvec3 sdata = texelFetch(tex_chars, cellpos, 0).rgb;
	float cv = texture(tex_font, vec3(subpos, float(sdata.r))).r;

	out_color = texelFetch(tex_palette, int(cv >= 0.5 ? sdata.g : sdata.b), 0);
	/*
	if(cv != 0.0)
	{
		out_color = vec4(vec3(1.0), 1.0);
	} else {
		out_color = vec4(ray_dir*0.5+0.5, 1.0);
	}
	*/
}

]=]

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

frag = "#version 130\n"..selector,
}, {"in_vertex",}, {"out_color",})

