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

float cast_ray(inout vec3 ray_pos, vec3 ray_dir, out vec3 frnorm, float maxtime, out vec4 fcol)
{
	const int MAX_STEP = 2000;
	const float EPSILON = 0.0001;
	const int MAX_LAYER = 5;

	int layer = 0;
	float atime = 0.0;

	vec3 vdir = normalize(ray_dir);
	ivec3 cpositive = ivec3(greaterThanEqual(vdir, vec3(0.0)));
	ivec3 cinc = 2*cpositive-1;
	vec3 needbend = vec3(lessThan(abs(vec3(vdir)), vec3(EPSILON)));
	vdir = EPSILON*needbend + vdir*(1.0-needbend);
	//fcol = vec4(vdir.xyz, 1.0)*0.5+0.5;
	fcol = vec4(0.2, 0.0, 0.3, 1.0);
	frnorm = vdir;
	ivec3 cell = ivec3(floor(ray_pos));
	vec3 adir = abs(vdir);
	vec3 aidir = 1.0/adir;

	vec3 wall = ray_pos-vec3(cell);
	wall += vec3(cell & ((1<<layer)-1));
	wall /= float(1<<layer);
	cell >>= layer;
	wall = (mod(cpositive + wall*-vec3(cinc), vec3(1.0)))/adir;

	ivec3 skip = ivec3(0,0,1);
	for(int i = 0; i < MAX_STEP && atime < maxtime; i++)
	{
		// step
		float mtime = min(min(wall.x, wall.y), wall.z);
		skip = ivec3(lessThanEqual(wall, vec3(mtime)));
		wall -= mtime;
		atime += mtime*float(1<<layer);
		wall += vec3(skip)*aidir;
		cell += (skip*cinc);

		// if out of range, stop
		if(any(lessThan(cell, ivec3(0)))) return maxtime;
		if(any(greaterThanEqual(cell<<layer, ivec3(256,512,512)))) return maxtime;

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
	}

	/*
	vec3 fpos = vec3(cell);
	fpos += vec3(cpositive)-vec3(cinc)*wall*adir;
	ray_pos = fpos;
	*/

	ray_pos = ray_pos + normalize(ray_dir)*atime;

	return atime;
}

void main()
{
	vec3 ray_pos = cam_pos;
	ray_pos.xz += 256.5;
	ray_pos.y += 192.5;
	ray_pos.y = 256.0-ray_pos.y;

	vec3 ray_dir = cam_dir;
	ray_dir.y = -ray_dir.y;

	ray_pos = ray_pos.yxz;
	ray_dir = ray_dir.yxz;

	vec3 frnorm;
	vec3 outpos = ray_pos;
	float RENDER_MAXTIME = 10000.0;
	float atime_init = cast_ray(outpos, ray_dir, frnorm, RENDER_MAXTIME, fcol);
	if(atime_init == RENDER_MAXTIME) return;

	vec3 fpos = outpos*(1.0/vec3(256.0, 512.0, 512.0));
	vec3 vdir = normalize(ray_dir);

	// ambient occlusion
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
	// LIGHTING
	//
	vec3 diffamb = vec3(0.0);
	vec3 specular = vec3(0.0);

	// ambient
	diffamb += AMBIENT*ambmul;

	// camera light
	diffamb += 0.2*vec3(0.3, 0.5, 0.6)*max(0.0, dot(frnorm, vdir));

	// positioned lights
	float amul = 1.0*pow(8.0, 0.0);
	ivec3 texcell = ivec3(outpos);
	float tlight = 0.0;
	for(int i = 0, lmax = 2; i < 5; i++, amul *= 8.0)
	{
		//vec4 ltval_N = texelFetch(tex_ltpos, texcell>>(i+1), i);
		vec4 ltval_L = textureLod(tex_ltpos, fpos, float(i));
		if(ltval_L.w != 0.0)
		{
			vec3 ltpos_L = ltval_L.xyz/ltval_L.w;
			vec3 ltdir_L = normalize(ltpos_L - outpos);
			float diffmul = max(0.0, -dot(frnorm, ltdir_L));
			if(diffmul > 0.0)
			{
				vec3 cast_pos = outpos;
				float ltdist = length(ltpos_L - outpos);
				vec3 cast_norm;
				vec4 cast_col;
				float cast_time = cast_ray(cast_pos, ltdir_L, cast_norm, ltdist, cast_col);
				if(cast_time >= ltdist*0.8)
				{
					tlight += diffmul
						*min(1.0, ltval_L.w*amul)
						*min(1.0, (cast_time-ltdist*0.8)/(ltdist*0.2))
						;

					//if(--lmax <= 0) break;
				}
			}
		}
	}
	diffamb += vec3(0.5, 0.3, 0.2)*tlight;

	// sunlight + moonlight
	// TODO: adjustable angle + colour
	{
		const vec3 SUNLIGHT = vec3(-1.0, 0.2, 0.2);
		vec3 cast_pos, cast_norm;
		vec4 cast_col;
		cast_pos = outpos - vdir;
		float cast_time = cast_ray(cast_pos, SUNLIGHT, cast_norm, RENDER_MAXTIME, cast_col);

		if(cast_time >= RENDER_MAXTIME*0.9)
			diffamb += vec3(0.8, 0.8, 0.8)*max(0.0, -dot(normalize(SUNLIGHT),frnorm));

	}

	// combine all
	fcol.rgb *= diffamb;
	fcol.rgb += specular;
}

]=]}, {"in_vec"}, {"fcol"})

