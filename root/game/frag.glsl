// vim: syntax=c

// a bit grating on the eyes, but better than the dumbed-down model
//define DITHER_LIGHTS

// useful.
#define AMBIENT_OCCLUSION

// makes the edges stand out a bit better.
// TODO: better edge detection.
#define ENHANCE_QUALITY

#ifndef BEAMER
#define INPUT_BEAMER
#endif

#ifdef INPUT_BEAMER
uniform sampler2D tex_beamer;
#endif

uniform usampler3D tex_geom;
uniform sampler3D tex_density;
uniform sampler3D tex_ltpos;

uniform vec3 cam_pos;
in vec3 cam_dir;
in vec2 cam_texcoord;

out vec4 fcol;

const int MAX_LAYER = 5;
const float EPSILON = 0.0001;
float RENDER_MAXTIME = 10000.0;

uint world_get_geom(ivec3 pos, int layer)
{
	/*
	if(min(min(pos.x, pos.y), pos.z) < 0) return 0U;
	if(max(max(pos.x, pos.y*2), pos.z) >= (512>>layer)) return 0U;
	return texelFetch(tex_geom, pos.yxz, layer).r;
	*/
	//if(min(min(pos.y, pos.x), pos.z) < 0) return 0U;
	//if(max(max(pos.y, pos.x*2), pos.z) >= (512>>layer)) return 0U;
	return texelFetch(tex_geom, pos, layer).r;
}

float cast_ray(inout vec3 ray_pos, vec3 ray_dir, out vec3 frnorm, float maxtime, out vec4 fcol)
{
	const int MAX_STEP = 2000;

	int layer = 0;
	float atime = 0.0;

	vec3 vdir = normalize(ray_dir);
	ivec3 cpositive = ivec3(greaterThanEqual(vdir, vec3(0.0)));
	ivec3 cinc = 2*cpositive-1;
	bvec3 needbend = lessThan(abs(vec3(vdir)), vec3(EPSILON));
	vdir = mix(vdir, vec3(EPSILON), needbend);
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
		//if(skip.y != 0) skip.z = 0; if(skip.x != 0) skip.y = 0;
		wall -= mtime;
		atime += mtime*float(1<<layer);
		wall += vec3(skip)/adir;
		cell += (skip*cinc);

		// if out of range, stop
#ifdef BEAMER
		if(any(lessThan(cell, ivec3(0))))
			return (maxtime == RENDER_MAXTIME ? atime : maxtime);
		if(any(greaterThanEqual(cell<<layer, ivec3(256,512,512))))
			return (maxtime == RENDER_MAXTIME ? atime : maxtime);
#else
		if(any(lessThan(cell, ivec3(0)))) return maxtime;
		if(any(greaterThanEqual(cell<<layer, ivec3(256,512,512)))) return maxtime;
#endif

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
						wall -= vec3(boost)/adir;
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
					wall -= vec3(boost)/adir;
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

			} else {
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
			wall += vec3(subval)/adir;
			wall /= float(1<<layerinc);
			cell >>= layerinc;
			layer = nlayer;
		}
	}

	vec3 fpos = vec3(cell);
	fpos += vec3(cpositive)-vec3(cinc)*wall*adir;
	fpos -= vdir*0.001;
	ray_pos = fpos;

	// sometimes the GPU or shader compiler turns to utter shit with this
	//ray_pos = ray_pos + normalize(ray_dir)*(atime-0.01);

	return atime;
}

// Slower than the usual method. Avoid.
/*
bool line_does_intersect(vec3 pos0, vec3 pos1)
{
	// Breadth-first search walking through the geometry
	vec3 abv = normalize(abs(pos1-pos0));
	bvec3 needbend = lessThan(abv, vec3(EPSILON));
	abv = mix(abv, vec3(EPSILON), needbend);
	vec3 abiv = 1.0/abv;

	// Calculate ivecs for position
	ivec3 iv0_base = ivec3(pos0);
	ivec3 iv1_base = ivec3(pos1);
	bvec3 bdir = greaterThanEqual(pos1, pos0);
	ivec3 idir = 2*ivec3(bdir)-1;

	for(int layer = MAX_LAYER; layer >= 0; layer--)
	{
		// Calculate ivecs at this level
		ivec3 cell = iv0_base>>layer;
		ivec3 tcell = iv1_base>>layer;

		// If cells match, do a fast-check
		if(cell == tcell)
		{
			if(texelFetch(tex_geom, cell, layer).r == 0U)
				continue;
			else
				return false;
		}

		// Calculate time to boundary
		vec3 ttb = (pos0 - vec3(cell<<layer))/float(1<<layer);
		ttb = mix(ttb, 1.0-ttb, bdir);
		ttb /= abv;

		// Calculate steps and follow them
		ivec3 steps_vec = abs(cell-tcell);
		int steps = steps_vec.x + steps_vec.y + steps_vec.z;
		int i = 0; for(; i < steps; i++)
		{
			// Check if we're in there
			//if(cell == tcell) { i = steps; break; }

			// Check if we hit something
			if(texelFetch(tex_geom, cell, layer).r == 0U)
				break;

			// Calculate time to boundary
			float mtime = min(min(ttb.x, ttb.y), ttb.z);

			// Advance
			ttb -= mtime;
			if(mtime == ttb.x)
			{
				cell.x += idir.x;
				ttb.x += abiv.x;

			} else if(mtime == ttb.y) {
				cell.y += idir.y;
				ttb.y += abiv.y;

			} else {
				cell.z += idir.z;
				ttb.z += abiv.z;

			}
		}

		// Check if we hit something
		if(texelFetch(tex_geom, cell, layer).r == 0U)
			continue;

		if(i == steps)
			return false;
	}

	return true;
}
*/

void main()
{
	vec3 ray_pos = cam_pos;
	vec3 ray_dir = cam_dir;
	vec3 frnorm;
	vec3 outpos = ray_pos;
	vec3 vdir = normalize(ray_dir);
#ifdef INPUT_BEAMER
	vec4 intex = texture(tex_beamer, cam_texcoord*0.5+0.5);
	float atime_target = 1.0/intex.w;
	float advancement = max(0.0, atime_target-0.1);
	outpos += vdir*advancement;
#endif
#ifdef BEAMER
	float atime_cast = cast_ray(outpos, ray_dir, frnorm, RENDER_MAXTIME, fcol);
	if(atime_cast == RENDER_MAXTIME)
	{
		fcol = vec4(0.0, 0.0, 0.0, 1.0/atime_cast);
		return;
	}

	fcol = vec4(1.0, 1.0, 1.0, 1.0/atime_cast);
#else
	float atime_cast = cast_ray(outpos, ray_dir, frnorm, RENDER_MAXTIME, fcol);
	if(atime_cast == RENDER_MAXTIME) return;
	float atime_added = atime_cast;
	atime_cast += advancement;
#endif

	vec3 fpos = outpos*(1.0/vec3(256.0, 512.0, 512.0));
	vec3 fpos_air = (outpos - 0.5*frnorm)*(1.0/vec3(256.0, 512.0, 512.0));

	// ambient occlusion
	const float AMBIENT = 0.1;
#ifdef AMBIENT_OCCLUSION
	float ambmul = (1.0 - 0.9*(0.0
		//+textureLod(tex_density, fpos, 5.0).r
		//+textureLod(tex_density, fpos, 4.0).r
		//+textureLod(tex_density, fpos, 3.0).r
		//+textureLod(tex_density, fpos, 2.0).r
		//+textureLod(tex_density, fpos, 1.0).r
		//+max(0.0, textureLod(tex_density, fpos + frnorm*0.5, 1.0).r*2.0-1.0)
		//+max(0.0, textureLod(tex_density, fpos + frnorm*0.5, 0.0).r*2.0-1.0)
		+textureLod(tex_density, fpos_air, 1.0).r
		+textureLod(tex_density, fpos_air, 0.0).r
		)/2.0);
#else
	float ambmul = 1.0;
#endif

	//
	// LIGHTING
	//
	vec3 diffamb = vec3(0.0);
	vec3 specular = vec3(0.0);

#ifndef BEAMER
	// ambient
	diffamb += AMBIENT*ambmul;

	// camera light
//ifndef AMBIENT_OCCLUSION
	diffamb += 0.2*vec3(0.3, 0.5, 0.6)*max(0.0, dot(frnorm, vdir));
//endif
#endif

	// positioned lights
	float amul = 1.0*pow(8.0, 0.0)/2048.0;
	ivec3 texcell = ivec3(outpos);
	float tlight = 0.0;

#ifndef BEAMER
#ifdef ENHANCE_QUALITY
	bool enhance_quality = abs(atime_cast/atime_target) > 1.0001;
#else
	bool enhance_quality = false;
#endif

	if(enhance_quality)
	{
#endif
	if(true)
	{
		// Higher-quality lighting model.
#ifdef DITHER_LIGHTS
		int fcx = int(floor(gl_FragCoord.x)) & 3;
		int fcy = int(floor(gl_FragCoord.y)) & 3;
		int i = int(((fcx + ((fcy&1)<<2)) ^ (fcy&2))&7);
		amul += pow(8.0, float(i));
#else
		for(int i = 0; i < 8; i++, amul *= 8.0)
#endif
		{
			//vec4 ltval_N = texelFetch(tex_ltpos, texcell>>(i+1), i);
			vec4 ltval_L = textureLod(tex_ltpos, fpos, float(i));
			if(ltval_L.w > EPSILON)
			{
				vec3 ltpos_L = ltval_L.xyz/ltval_L.w;
				vec3 ltdir_L = normalize(ltpos_L - outpos);
				float diffmul = max(0.0, -dot(frnorm, ltdir_L));
				if(diffmul > 0.0)
				{
					vec3 cast_pos = outpos;
					vec3 cast_norm;
					vec4 cast_col;
					float ltdist = length(ltpos_L - outpos);
					float cast_time = cast_ray(cast_pos, ltdir_L, cast_norm, ltdist, cast_col);
					//if(cast_time >= ltdist*0.8)
					if(cast_time >= ltdist)
					//if(!line_does_intersect(outpos, ltpos_L))
					{
						tlight += diffmul
							*min(1.0, ltval_L.w*amul)
#ifdef DITHER_LIGHTS
							*sqrt(8.0)
#endif
							//*min(1.0, (cast_time-ltdist*0.8)/(ltdist*0.2))
							;
					}
				}
			}
		}

	} else {
		// Lower-quality lighting model.
		// Shadows look terrible in this when you have more than one light.
		// It *is* slightly faster, but not recommended.
		vec4 effv = vec4(0.0);
		for(int i = 0; i < 8; i++)
		{
			vec4 ltv = textureLod(tex_ltpos, fpos, float(i));
			effv += ltv;

		}
		if(effv.w > EPSILON)
		{
			vec3 ltpos_L = effv.xyz/effv.w;
			vec3 ltdir_L = normalize(ltpos_L - outpos);
			float diffmul = max(0.0, -dot(frnorm, ltdir_L));
			if(diffmul > 0.0)
			{
				vec3 cast_pos = outpos;
				vec3 cast_norm;
				vec4 cast_col;
				float ltdist = length(ltpos_L - outpos);
				float cast_time = cast_ray(cast_pos, ltdir_L, cast_norm, ltdist, cast_col);
				if(cast_time >= ltdist)
				//if(!line_does_intersect(outpos, ltpos_L))
				{
					tlight += diffmul*sqrt(8.0)
						//*min(1.0, ltval_L.w*amul)
						//*min(1.0, (cast_time-ltdist*0.8)/(ltdist*0.2))
						;

					//if(--lmax <= 0) break;
				}
			}
		}
	}

	diffamb += vec3(0.5, 0.3, 0.2)*tlight;

	// sunlight + moonlight
	// TODO: adjustable angle + colour
	if(true){
		const vec3 SUNLIGHT = vec3(-1.0, 0.2, 0.2);
		vec3 cast_pos, cast_norm;
		vec4 cast_col;
		cast_pos = outpos - frnorm*0.1;
		float cast_time = cast_ray(cast_pos, SUNLIGHT, cast_norm, RENDER_MAXTIME*2.0, cast_col);

		if(cast_time >= RENDER_MAXTIME)
			diffamb += vec3(0.8, 0.8, 0.8)*max(0.0, -dot(normalize(SUNLIGHT),frnorm));

	}
#ifndef BEAMER
	}
#endif

	// combine all
	fcol.rgb *= diffamb;
	fcol.rgb += specular;

#ifndef BEAMER
	if(!enhance_quality)
	{
		fcol.rgb += intex.rgb;
	} else {
		//fcol.r += 0.2;
	}
#endif
}

