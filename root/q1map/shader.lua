selector = [=[

in vec3 vert_ray_step;
flat in vec3 vert_cam_pos;
in vec2 vert_tc;
in vec2 vert_vertex;

out vec4 out_color;

uniform int map_root;
uniform sampler1D tex_map_norms;
uniform isampler2D tex_map_splits;

const int STACK_MAX = 32;
int nsl[STACK_MAX];
int nsn[STACK_MAX];
float nsz[STACK_MAX];

void main()
{
	vec3 ray_pos = vert_cam_pos;
	vec3 ray_dir = normalize(vert_ray_step);
	float zfar = 10000.0;
	float znear = 0.0;

	// Create stack
	// keep the numbers small, otherwise they spill registers like mad
	// which slows things down horribly
	int nsp = 0;
	int nidx = map_root;

	// Traverse
	const int MAX_STEPS = 500;
	out_color = vec4(vert_tc, 0.5, 1.0);
	vec4 tnorm = vec4(0.0);
	bool has_entered = false;

	for(int step = 0; step < MAX_STEPS; step++)
	{
		if(nidx == -1 || (nidx == -2 && !has_entered))
		{
			if((!has_entered) && nidx == -1)
				has_entered = true;

			if(nsp == 0)
				return;

			nidx = nsl[--nsp];
			znear = zfar;
			zfar = nsz[nsp];
			int tnorm_idx = nsn[nsp];
			tnorm = texelFetch(tex_map_norms, tnorm_idx, 0);
			continue;
		}

		if(nidx < 0)
		{
			float fside1 = dot(tnorm, vec4(ray_pos, -1.0));
			float sign1 = sign(fside1);
			float diff = max(0.0, -sign1*dot(tnorm.xyz, ray_dir));
			float amb = 0.1;
			diff *= 1.0 - amb;
			out_color = vec4(vec3(1.0)*(diff+amb), 1.0);
			return;
		}

		// Get node
		ivec3 split = texelFetch(tex_map_splits, ivec2(nidx&1023, nidx>>10), 0).xyz;

		// Get normal
		vec4 norm = texelFetch(tex_map_norms, split.x, 0).xyzw;

		// Check side
		float fside1 = dot(norm, vec4(ray_pos + ray_dir*znear, -1.0));
		float fside2 = dot(norm, vec4(ray_pos + ray_dir*zfar, -1.0));
		float sign1 = sign(fside1);
		float sign2 = sign(fside2);
		int side1 = max(0, int(sign(fside1)));
		int side2 = max(0, int(sign(fside2)));

		if(side1 != side2)
		{
			// split

			if(nsp >= STACK_MAX)
			{
				// STACK OVERFLOW!
				out_color = vec4(1.0, 0.0, 0.0, 1.0);
				return;
			}

			if(zfar < znear)
			{
				// Collapse
				out_color = vec4(0.0, 0.0, 1.0, 1.0);
				return;
			}

			nsz[nsp] = zfar;
			nsn[nsp] = split.x;

			// TODO: work this out
			zfar = -fside1/dot(norm.xyz, ray_dir);
			zfar += znear;

		}

		if(side1 > 0)
		{
			// front
			nidx = split.y;

			if(side1 != side2)
				nsl[nsp++] = split.z;

		} else {
			// back
			nidx = split.z;

			if(side1 != side2)
				nsl[nsp++] = split.y;
		}
	}

	// Need more steps!
	out_color = vec4(0.0, 1.0, 0.0, 1.0);
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

frag = "#version 130\n#define TRACER\n"..selector,
}, {"in_vertex",}, {"out_color",})

