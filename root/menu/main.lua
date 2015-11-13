
-- from SDL_keycode.h
SDLK_ESCAPE = 27

function hook_key(key, state)
	if key == SDLK_ESCAPE and not state then
		misc.exit()
	end
end

function hook_mouse_button(button, state)
end

function hook_mouse_motion(x, y, dx, dy)
end

function hook_render(sec_current)
	fbo.target_set(nil)
	shader.use(shader_test)
	shader.uniform_f(shader.uniform_location_get(shader_test, "time"), sec_current)
	draw.blit()
end

function hook_tick(sec_current, sec_delta)
end

shader_test = shader.new({
vert = [=[
#version 150

uniform float time;

in vec2 in_vertex;

out vec3 vert_ray_step;
flat out vec3 vert_cam_pos;

void main()
{
	gl_Position = vec4(in_vertex, 0.5, 1.0);
	vert_ray_step = normalize(vec3(in_vertex.x*1280.0/720.0, in_vertex.y, 1.0));
	vert_cam_pos = vec3(0.0, 0.0, -2.0);

	// ROTATE
	float rtime = time * 0.15;
	vert_cam_pos.xz = vert_cam_pos.xz*cos(rtime) + vec2(vert_cam_pos.z, -vert_cam_pos.x)*sin(rtime);
	vert_ray_step.xz = vert_ray_step.xz*cos(rtime) + vec2(vert_ray_step.z, -vert_ray_step.x)*sin(rtime);
}

]=],

frag = [=[
#version 150

uniform float time;

in vec3 vert_ray_step;

flat in vec3 vert_cam_pos;
out vec4 out_color;

float rm_scene(vec3 pos)
{
	pos = mod(pos+2.5, 5.0)-2.5;
	//pos += sin(abs(pos)*30.0 + time)*0.04;

	float l1 = 1.0 - length(pos - vec3( 0.0, 0.0, 0.0));
	l1 += dot(vec3(1.0), sin(-pos*30.0 + time*3.0))*0.02;
	return l1;
}

void main()
{
	vec3 ray_pos = vert_cam_pos;
	const float OFFS = 0.001;
	const float OFFS2 = 0.99;
	const float OFFS3 = 0.28;
	const int STEPS = 20;
	const int SUBDIVS = 4;
	vec3 ray_step = normalize(vert_ray_step);
	const vec3 OFFS_X = vec3(1.0, 0.0, 0.0)*OFFS;
	const vec3 OFFS_Y = vec3(0.0, 1.0, 0.0)*OFFS;
	const vec3 OFFS_Z = vec3(0.0, 0.0, 1.0)*OFFS;

	// Rotate camera

	out_color = vec4(0.0, 0.0, 0.3, 1.0);
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

				if(rm_scene(ray_pos-ray_step*sub) <= 0.0)
					sub -= subsub;
				else
					sub += subsub;
			}
			ray_pos -= ray_step*sub;
			atime -= sub;

			vec3 norm = normalize(vec3(
				rm_scene(ray_pos - OFFS_X) - rm_scene(ray_pos + OFFS_X),
				rm_scene(ray_pos - OFFS_Y) - rm_scene(ray_pos + OFFS_Y),
				rm_scene(ray_pos - OFFS_Z) - rm_scene(ray_pos + OFFS_Z)
			));
			float diff = max(0.0, -dot(norm, ray_step));
			//vec3 refl = normalize(ray_step - 2.0*dot(norm, ray_step)*norm);
			vec3 refl = ray_step - 2.0*dot(norm, ray_step)*norm;
			float spec = max(0.0, -dot(refl, normalize(ray_pos - vert_cam_pos)));
			spec = pow(spec, 128.0);
			out_color = out_color*(1.0-out_acc)
				+ mix(out_color,
				(diff*0.9 + 0.1)*vec4(1.0, 0.2, 0.0, 1.0)
				+ spec*vec4(1.0, 1.0, 1.0, 0.0),
				pow(2.0, -0.2*atime))*out_acc;
			ray_step = refl;
			ray_pos += ray_step*0.02;
			atime += 0.02;
			out_acc *= 0.3;
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

assert(shader_test)


