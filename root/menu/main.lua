
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
	shader.use(shader_test)
	shader.uniform_f(shader.uniform_location_get(shader_test, "time"), sec_current)
	shader.uniform_i(shader.uniform_location_get(shader_test, "tex_noise"), 0)
	texture.unit_set(0, "2", tex_noise)
	draw.blit()
end

function hook_tick(sec_current, sec_delta)
end

tex_noise = texture.new("2", 1, "1f", 256, 256, "ll", "1f")
do
	local x, y
	local l = {}
	for y=0,256-1 do
	for x=0,256-1 do
		l[1+x+y*256] = 0.0
	end
	end
	for y=0,256-1 do
	for x=0,256-1 do
		l[1+x+y*256] = math.random()
	end
	end

	texture.load_sub(tex_noise, "2", 0, 0, 0, 256, 256, "1f", l)
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
#version 150

uniform float time;
uniform sampler2D tex_noise;

in vec3 vert_ray_step;

flat in vec3 vert_cam_pos;
out vec4 out_color;

float get_noise(vec2 pos)
{
	pos += 0.5; // hide border wrap artifacts
	pos *= 256.0;
	ivec2 texel = ivec2(floor(pos)) % 256;
	vec2 t = (pos - floor(pos));

	float t00 = texelFetchOffset(tex_noise, texel, 0, ivec2(0,0)).r;
	float t01 = texelFetchOffset(tex_noise, texel, 0, ivec2(0,1)).r;
	float t10 = texelFetchOffset(tex_noise, texel, 0, ivec2(1,0)).r;
	float t11 = texelFetchOffset(tex_noise, texel, 0, ivec2(1,1)).r;

	/*
	Design a function such that
	f(0) = 0
	f(1) = 1
	f(0.5) = 0.5
	f(0.5-x) = 0.5-f(0.5+x)
	*/

	t = smoothstep(0.0, 1.0, t);

	return mix(
		mix(t00, t01, t.y),
		mix(t10, t11, t.y),
		t.x);

}

float rm_scene(vec3 pos)
{
	pos.xz = mod(pos.xz+2.5, 5.0)-2.5;
	//pos += sin(abs(pos)*30.0 + time)*0.04;

	float l1 = 1.5 - length(pos - vec3(-sin(time), cos(time), 0.0));
	float l2 = 1.5 - length(pos - vec3( 1.0, 0.0, 0.0));

	float lb = 0.0;
	l1 = max(0.0, l1);
	l2 = max(0.0, l2);
	lb += l1*l1;
	lb += l2*l2;
	lb -= 1.0;
	//lb += sin(time*1.0)*0.5;

	//lb += dot(vec3(1.0), sin(-pos*30.0 + time*3.0))*0.02;

	return lb;
}

void main()
{
	vec3 ray_pos = vert_cam_pos;
	const float OFFS = 0.01;
	const float OFFS2 = 0.99;
	const float OFFS3 = 0.12;
	const int STEPS = 30;
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


