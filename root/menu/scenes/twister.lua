return shader.new({
vert = [=[
#version 130

uniform float time;

in vec2 in_vertex;

out vec3 vert_ray_step;
flat out vec3 vert_cam_pos;

void main()
{
	gl_Position = vec4(in_vertex, 0.5, 1.0);
	vert_ray_step = normalize(vec3(in_vertex.x*1280.0/720.0, in_vertex.y, 1.0));
	vert_cam_pos = vec3(0.0, 0.0, -3.0);

	// ROTATE
	float rotx = -0.0;
	//vert_cam_pos.yz = vert_cam_pos.yz*cos(rotx) + vec2(vert_cam_pos.z, -vert_cam_pos.y)*sin(rotx);
	vert_ray_step.yz = vert_ray_step.yz*cos(rotx) + vec2(vert_ray_step.z, -vert_ray_step.y)*sin(rotx);

	// ROTATE AGAIN
	float rtime = time * 0.15;
	vert_cam_pos.xz = vert_cam_pos.xz*cos(rtime) + vec2(vert_cam_pos.z, -vert_cam_pos.x)*sin(rtime);
	vert_ray_step.xz = vert_ray_step.xz*cos(rtime) + vec2(vert_ray_step.z, -vert_ray_step.x)*sin(rtime);
}

]=],

frag = [=[
#version 130

uniform float time;

in vec3 vert_ray_step;

flat in vec3 vert_cam_pos;
out vec4 out_color;

const float OFFS = 0.01;
const float OFFS2 = 0.70;
const float OFFS3 = 0.03;
const int STEPS = 30;
const int SUBDIVS = 4;
const vec3 OFFS_X = vec3(1.0, 0.0, 0.0)*OFFS;
const vec3 OFFS_Y = vec3(0.0, 1.0, 0.0)*OFFS;
const vec3 OFFS_Z = vec3(0.0, 0.0, 1.0)*OFFS;

float rm_scene(vec3 pos)
{
	float rot = sin(pos.y*0.7 + time*0.5)*3.141593/2.0;
	//float rot = (pos.y*0.7 + time*0.5)*3.141593/2.0;
	//float pnoise = -sin(length(pos.xyz)*10.0)*0.2;
	float pnoise = 0.0;
	pos.xz = pos.xz*cos(rot) + vec2(pos.z, -pos.x)*sin(rot);

	float dist = max(abs(pos.x), abs(pos.z));

	return 1.0 - dist + pnoise;
}

vec3 rm_scene_normal(vec3 pos, float base)
{
	return normalize(vec3(
	//return (vec3(
		//rm_scene(pos - OFFS_X) - rm_scene(pos + OFFS_X),
		//rm_scene(pos - OFFS_Y) - rm_scene(pos + OFFS_Y),
		// if we cancel this out then the R600 overflow won't fire
		//-1.0//rm_scene(pos - OFFS_Z) - rm_scene(pos + OFFS_Z)
		base - rm_scene(pos + OFFS_X),
		base - rm_scene(pos + OFFS_Y),
		base - rm_scene(pos + OFFS_Z)
	));
}

void main()
{
	vec3 ray_pos = vert_cam_pos;
	vec3 ray_step = normalize(vert_ray_step);

	// Rotate camera

	const vec4 BG = vec4(0.6, 0.8, 1.0, 1.0);
	out_color = BG;
	float out_acc = 1.0;

	float lstep = 1.0;
	float atime = 0.0;

	for(int i = 0; i < STEPS; i++)
	{
		float res = rm_scene(ray_pos);

		if(res > 0.0)
		{
			// binomial binary bintastic thing i can't remember the name of
			float sub = lstep*0.5;
			float subsub = sub;
			for(int j = 0; j < SUBDIVS; j++)
			{
				subsub *= 0.5;

				res = rm_scene(ray_pos-ray_step*sub);
				if(res <= 0.0)
					sub -= subsub;
				else
					sub += subsub;
			}

			ray_pos -= ray_step*sub;
			atime -= sub;

			out_color = vec4(1.0, 0.2, 0.0, 1.0);

			res = rm_scene(ray_pos);
			vec3 norm = rm_scene_normal(ray_pos, res);
			vec3 reldir = normalize(ray_pos - vert_cam_pos);
			//out_color.rgb *= 0.1 + 0.9*max(0.0, -dot(reldir, norm));
			out_color.rgb *= max(0.0, -dot(reldir, norm));
			/*
			float diff = max(0.0, -dot(norm, ray_step));
			//vec3 refl = normalize(ray_step - 2.0*dot(norm, ray_step)*norm);
			vec3 refl = ray_step - 2.0*dot(norm, ray_step)*norm;
			float spec = max(0.0, -dot(refl, normalize(ray_pos - vert_cam_pos)));
			spec = pow(spec, 128.0);
			out_color = out_color*(1.0-out_acc)
				+ mix(BG,
				(diff*0.9 + 0.1)*vec4(1.0, 0.2, 0.0, 1.0)
				+ spec*vec4(1.0, 1.0, 1.0, 0.0),
				pow(2.0, -0.2*atime))*out_acc;
			ray_step = refl;
			ray_pos += ray_step*0.02;
			atime += 0.02;
			out_acc *= 0.3;
			*/
			//if(out_acc < 0.01)
				break;
		}

		lstep = max(OFFS3, -res*OFFS2);
		atime += lstep;
		ray_pos += ray_step*lstep;
	}
}

]=],
}, {"in_vertex",}, {"out_color",})


