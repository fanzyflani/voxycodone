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
		).xyz);

	gl_Position = vec4(in_vec, 0.1, 1.0);
}

]=],frag=[=[
#version 130

uniform usampler3D tex_geom;
uniform sampler3D tex_density;
uniform sampler3D tex_ltpos;

uniform vec3 cam_pos;
in vec3 cam_dir;

out vec4 fcol;

uint world_get_geom(ivec3 pos, int layer)
{
	/*
	if(min(min(pos.x, pos.y), pos.z) < 0) return 0U;
	if(max(max(pos.x, pos.y*2), pos.z) >= (512>>layer)) return 0U;
	return texelFetch(tex_geom, pos.yxz, layer).r;
	*/
	if(min(min(pos.y, pos.x), pos.z) < 0) return 0U;
	if(max(max(pos.y, pos.x*2), pos.z) >= (512>>layer)) return 0U;
	return texelFetch(tex_geom, pos, layer).r;
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

	ray_pos = ray_pos.yxz;
	ray_dir = ray_dir.yxz;

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
			{
				if(false)
				{
					for(int j = 0; j < MAX_LAYER; j++)
					{
						if(layer <= 0 || v != 0U) break;

						// move to wider layer
						layer--;
						cell <<= 1;
						wall *= 2.0;
						ivec3 boost = ivec3(greaterThanEqual(wall,vec3(aidir)));
						cell += boost^cpositive;
						wall -= vec3(boost)*aidir;
						v = world_get_geom(cell, layer);
					}

					if(v == 0U)
					{
						// output colour
						fcol = vec4(1.0, 1.0, 1.0, 1.0);
						frnorm = normalize(vec3(skip*cinc));
						break;
					}

				} else {
					// move to bottom layer
					// -- this means we get to the layer lookup faster
					// this version gets a bit more snow than the other version

					// i tried manually unrolling this into a switch.
					// it was slower.

					ivec3 cpositive_mask = cpositive*((1<<layer)-1);
					cell <<= layer;
					wall *= float(1<<layer);
					ivec3 boost = ivec3(floor(wall*adir-0.00001));
					cell += boost^cpositive_mask;
					wall -= vec3(boost)*aidir;
					layer = 0;
					v = world_get_geom(cell, layer);

					if(v == 0U)
					{
						// output colour
						fcol = vec4(1.0, 1.0, 1.0, 1.0);
						frnorm = normalize(vec3(skip*cinc));
						break;
					}
				}

			} else if(i != 0) {
				// output colour
				fcol = vec4(1.0, 1.0, 1.0, 1.0);
				frnorm = normalize(vec3(skip*cinc));
				break;
			}

			/*
			if(v == 0U)
			{
				if(layer <= 0 && i != 0)
				{
					// output colour
					fcol = vec4(1.0, 1.0, 1.0, 1.0);
					frnorm = normalize(vec3(skip*cinc));
					break;
				}
			}
			*/
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

	vec3 fpos = vec3(cell);
	fpos += vec3(cpositive)-vec3(cinc)*wall*adir;
	fpos = fpos*(1.0/vec3(256.0, 512.0, 512.0));

	const float AMBIENT = 0.1;
	float ambmul = (1.0 - 0.9*(0.0
		//+textureLod(tex_density, fpos, 5.0).r
		//+textureLod(tex_density, fpos, 4.0).r
		//+textureLod(tex_density, fpos, 3.0).r
		//+textureLod(tex_density, fpos, 2.0).r
		//+textureLod(tex_density, fpos, 1.0).r
		+max(0.0, textureLod(tex_density, fpos, 1.0).r*2.0-1.0)
		+max(0.0, textureLod(tex_density, fpos, 0.0).r*2.0-1.0)
		)/2.0);

	//
	vec3 diffamb = vec3(0.0);
	vec3 specular = vec3(0.0);

	// ambient
	diffamb += AMBIENT*ambmul;

	// camera light
	diffamb += 0.2*vec3(0.3, 0.5, 0.6)*max(0.0, dot(frnorm, vdir));

	// positioned lights
	float amul = 1.0*pow(8.0, 3.0);
	float rmul = 1.0*pow(0.9, 3.0);
	for(int i = 3; i < 9; i++, amul *= 8.0, rmul *= 0.9)
	{
		vec4 ltval = textureLod(tex_ltpos, fpos, float(i));
		if(ltval.a != 0.0)
		{
			vec3 ltdir = ltval.rgb/ltval.a;
			ltdir -= fpos;
			ltdir = normalize(ltdir);
			diffamb += vec3(0.5, 0.3, 0.2)*max(0.0, dot(frnorm, ltdir))
				*min(1.0, ltval.a*amul)*rmul;
		}
	}

	// combine all
	fcol.rgb *= diffamb;
	fcol.rgb += specular;
}

]=]}, {"in_vec"}, {"fcol"})

