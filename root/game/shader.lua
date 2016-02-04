return shader.new({vert=[=[
#version 130

uniform mat4 in_cam_inverse;

in vec2 in_vec;
uniform vec3 cam_pos;
out vec3 cam_dir;
void main()
{
	//
	cam_dir = normalize((-in_cam_inverse[2]
		+ in_cam_inverse[0] * in_vec.x * 1280.0/720.0
		+ in_cam_inverse[1] * in_vec.y
		).xyz);

	gl_Position = vec4(in_vec, 0.1, 1.0);
}

]=],frag=[=[
#version 130

uniform usampler3D tex_geom;

uniform vec3 cam_pos;
in vec3 cam_dir;

out vec4 fcol;

uint world_get_geom(ivec3 pos, int layer)
{
	if(min(min(pos.x, pos.y), pos.z) < 0) return 0U;
	if(max(max(pos.x, pos.y*2), pos.z) >= (512>>layer)) return 0U;
	return texelFetch(tex_geom, pos.yxz, layer).r;
}

void main()
{
	const int MAX_STEP = 2000;
	const float EPSILON = 0.0001;
	const int MAX_LAYER = 5;

	int layer = 0;

	vec3 ray_pos = cam_pos;
	ray_pos.xz += 256.5;
	ray_pos.y += 192.5;
	ray_pos.y = 256.0-ray_pos.y;

	vec3 ray_dir = cam_dir;
	ray_dir.y = -ray_dir.y;

	vec3 vdir = normalize(ray_dir);
	ivec3 cpositive = ivec3(greaterThanEqual(vdir, vec3(0.0)));
	ivec3 cinc = 2*cpositive-1;
	vec3 needbend = vec3(lessThan(abs(vec3(vdir)), vec3(EPSILON)));
	vdir = EPSILON*needbend + vdir*(1.0-needbend);
	fcol = vec4(vdir.xyz, 1.0)*0.5+0.5;
	vec3 frnorm = vdir;
	ivec3 cell = ivec3(floor(ray_pos));
	vec3 adir = abs(vdir);
	vec3 aidir = 1.0/adir;

	vec3 wall = ray_pos-vec3(cell);
	wall += vec3(cell & ((1<<layer)-1));
	wall /= float(1<<layer);
	cell >>= layer;
	wall = (mod(cpositive + wall*-vec3(cinc), vec3(1.0)))/adir;

	ivec3 skip = ivec3(0,0,1);
	for(int i = 0; i < MAX_STEP; i++)
	{
		// compare
		uint v = world_get_geom(cell, layer);

		if(v == 0U)
		{
			if(layer > 0)
			for(int j = 0; j < MAX_LAYER; j++)
			{
				if(layer <= 0 || v != 0U) break;

				// move to wider layer
				layer--;
				cell <<= 1;
				wall *= 2.0;
				//ivec3 boost = ivec3(floor(wall));
				ivec3 boost = ivec3(greaterThanEqual(wall,vec3(aidir)));
				cell += boost^cpositive;
				wall -= vec3(boost)*aidir;
				v = world_get_geom(cell, layer);
			}

			if(layer <= 0 && v == 0U && i != 0)
			{
				// output colour
				fcol = vec4(1.0, 1.0, 1.0, 1.0);
				frnorm = normalize(vec3(skip*cinc));
				break;
			}
		}

		// expand if necessary
		int nlayer = int(v)-1;
		if(nlayer > layer)
		{
			int layerinc = nlayer-layer;
			ivec3 subval = cell;
			subval ^= (-cpositive);
			subval &= (1<<layerinc)-1;
			wall += vec3(subval)*aidir;
			wall /= float(1<<layerinc);
			cell >>= layerinc;
			layer = nlayer;
		}

		// step
		float mtime = min(min(wall.x, wall.y), wall.z);
		skip = ivec3(lessThanEqual(wall, vec3(mtime)));
		wall -= mtime;
		wall += vec3(skip)*aidir;
		cell += (skip*cinc);
	}

	const float AMBIENT = 0.1;
	fcol.rgb *= mix(AMBIENT, max(0.0, dot(frnorm, vdir)), 1.0);
}

]=]}, {"in_vec"}, {"fcol"})

