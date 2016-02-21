// vim: syntax=c

#ifdef COMPAT
#define a_vert_frag varying
#define t_uint int
#define f2d_texture texture2D
#define f3d_textureLod(tex, pos, bias) texture3D(tex, pos, bias)
#else
#define a_vert_frag in
#define t_uint uint
#define f2d_texture texture
#define f3d_textureLod(tex, pos, bias) textureLod(tex, pos, bias)
#endif
#ifndef BEAMER
#define INPUT_BEAMER
#endif

// a bit grating on the eyes, but better than the dumbed-down model
#ifndef INPUT_BEAMER
//define DITHER_LIGHTS
#else
//define INPUT_DITHER_LIGHTS
#endif

// useful.
#define AMBIENT_OCCLUSION

// makes the edges stand out a bit better.
// TODO: better edge detection.
#define ENHANCE_QUALITY

#ifdef INPUT_BEAMER
uniform sampler2D tex_beamer;
#endif

#ifdef COMPAT
uniform sampler3D tex_geom;
#else
uniform usampler3D tex_geom;
#endif
uniform sampler3D tex_density;
uniform sampler3D tex_ltpos;

uniform vec3 cam_pos;
a_vert_frag vec3 cam_dir;
a_vert_frag vec2 cam_texcoord;

#ifdef COMPAT
vec4 fcol;
#else
out vec4 fcol;
#endif

#ifdef COMPAT
const int MAX_LAYER = 0; // FIXME: layers
#else
const int MAX_LAYER = 5;
#endif
const float EPSILON = 0.0001;
float RENDER_MAXTIME = 10000.0;

t_uint world_get_geom(ivec3 pos, int layer)
{
	/*
	if(min(min(pos.x, pos.y), pos.z) < 0) return 0U;
	if(max(max(pos.x, pos.y*2), pos.z) >= (512>>layer)) return 0U;
	return texelFetch(tex_geom, pos.yxz, layer).r;
	*/
	//if(min(min(pos.y, pos.x), pos.z) < 0) return 0U;
	//if(max(max(pos.y, pos.x*2), pos.z) >= (512>>layer)) return 0U;
#ifdef COMPAT
	return t_uint(floor(texture3D(tex_geom, (vec3(pos)+0.5)/vec3(256.0,512.0,512.0), layer).r*255.0+0.5));
#else
	return texelFetch(tex_geom, pos, layer).r;
#endif
}

float cast_ray(inout vec3 ray_pos, vec3 ray_dir, out vec3 oray_norm, float maxtime, out vec4 oray_col)
{
	const int MAX_STEP = 2000;

	int layer = 0;
	float atime = 0.0;

	vec3 vdir = normalize(ray_dir);
	ivec3 cpositive = ivec3(greaterThanEqual(vdir, vec3(0.0)));
	ivec3 cinc = 2*cpositive-1;
#ifdef COMPAT
	vec3 needbend = vec3(lessThan(abs(vec3(vdir)), vec3(EPSILON)));
#else
	bvec3 needbend = lessThan(abs(vec3(vdir)), vec3(EPSILON));
#endif
	vdir = mix(vdir, vec3(EPSILON), needbend);
	//oray_col = vec4(vdir.xyz, 1.0)*0.5+0.5;
	oray_col = vec4(0.2, 0.0, 0.3, 1.0);
	oray_norm = vdir;
	ivec3 cell = ivec3(floor(ray_pos));
	vec3 adir = abs(vdir);
	vec3 aidir = 1.0/adir;

	vec3 wall = ray_pos-vec3(cell);
#ifdef COMPAT
	float layershiftf = exp2(float(layer));
	int layershifti = int(floor(layershiftf+0.5));
	wall += mod(vec3(cell), layershiftf);
	wall /= layershiftf;
	cell /= layershifti;
#else
	wall += vec3(cell & ((1<<layer)-1));
	wall /= float(1<<layer);
	cell >>= layer;
#endif
	wall = (mod(cpositive + wall*-vec3(cinc), vec3(1.0)))/adir;

	ivec3 skip = ivec3(0,0,1);
	for(int i = 0; i < MAX_STEP && atime < maxtime; i++)
	{
		// step
		float mtime = min(min(wall.x, wall.y), wall.z);
		skip = ivec3(lessThanEqual(wall, vec3(mtime)));
		//if(skip.y != 0) skip.z = 0; if(skip.x != 0) skip.y = 0;
		wall -= mtime;
#ifdef COMPAT
		atime += mtime*layershiftf;
#else
		atime += mtime*float(1<<layer);
#endif
		wall += vec3(skip)/adir;
		cell += (skip*cinc);

		// if out of range, stop
		if(any(lessThan(cell, ivec3(0))))
#ifdef BEAMER
			return (maxtime == RENDER_MAXTIME ? atime : maxtime);
#else
			return maxtime;
#endif
#ifdef COMPAT
		if(any(greaterThanEqual(cell*layershifti, ivec3(256,512,512))))
#else
		if(any(greaterThanEqual(cell<<layer, ivec3(256,512,512))))
#endif
#ifdef BEAMER
			return (maxtime == RENDER_MAXTIME ? atime : maxtime);
#else
			return maxtime;
#endif

		// compare
		t_uint v = world_get_geom(cell, layer);

		if(v == t_uint(0))
		{
			if(layer > 0)
			{
#ifndef COMPAT
				if(false)
				{
#endif
					for(int j = 0; j < MAX_LAYER; j++)
					{
						if(layer <= 0 || v != t_uint(0)) break;

						// move to wider layer
						layer--;
						wall *= 2.0;
#ifdef COMPAT
						cell *= 2;
						layershifti /= 2;
						layershiftf /= 2.0;
						ivec3 boost = ivec3(greaterThanEqual(wall,vec3(aidir)));
						cell += cpositive-boost*cinc;
#else
						cell <<= 1;
						ivec3 boost = ivec3(greaterThanEqual(wall,vec3(aidir)));
						cell += boost^cpositive;
#endif
						wall -= vec3(boost)/adir;
						v = world_get_geom(cell, layer);
					}

					if(v == t_uint(0))
					{
						// output colour
						oray_col = vec4(1.0, 1.0, 1.0, 1.0);
						oray_norm = normalize(vec3(skip*cinc));
						break;
					}

#ifndef COMPAT
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
						oray_col = vec4(1.0, 1.0, 1.0, 1.0);
						oray_norm = normalize(vec3(skip*cinc));
						break;
					}
				}
#endif

			} else {
				// output colour
				oray_col = vec4(1.0, 1.0, 1.0, 1.0);
				oray_norm = normalize(vec3(skip*cinc));
				break;
			}

			/*
			if(v == 0U)
			{
				if(layer <= 0 && i != 0)
				{
					// output colour
					oray_col = vec4(1.0, 1.0, 1.0, 1.0);
					oray_norm = normalize(vec3(skip*cinc));
					break;
				}
			}
			*/
		}

		// expand if necessary
		int nlayer = int(v)-1;
		if(nlayer > MAX_LAYER) nlayer = MAX_LAYER;

		if(layer < nlayer)
		{
#ifdef COMPAT
			// TODO: faster version
			for(; layer < nlayer; layer++)
			{
				ivec3 subval = cpositive-cinc*ivec3(mod(cell, 2));
				wall += vec3(subval)/adir;
				wall /= 2.0;
				cell /= 2;
				layershifti *= 2;
				layershiftf *= 2.0;
			}
#else
			int layerinc = nlayer-layer;
			ivec3 subval = cell;

			subval ^= (-cpositive);
			subval &= (1<<layerinc)-1;
			wall += vec3(subval)/adir;
			wall /= float(1<<layerinc);
			cell >>= layerinc;
			layer = nlayer;
#endif
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

void main()
{
	vec3 ray_pos = cam_pos;
	vec3 ray_dir = cam_dir;
	vec3 frnorm;
	vec3 outpos = ray_pos;
	vec3 vdir = normalize(ray_dir);
#ifdef INPUT_BEAMER
	vec4 intex = f2d_texture(tex_beamer, cam_texcoord*0.5+0.5);
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
	if(atime_cast == RENDER_MAXTIME)
	{
		//fcol = vec4(1.0, 1.0, 1.0, 1.0);
		return;
	}
#ifdef INPUT_BEAMER
	float atime_added = atime_cast;
	atime_cast += advancement;
#endif
#endif

	vec3 fpos = outpos*(1.0/vec3(256.0, 512.0, 512.0));
	vec3 fpos_air = (outpos - 0.5*frnorm)*(1.0/vec3(256.0, 512.0, 512.0));

	// ambient occlusion
	const float AMBIENT = 0.1;
#ifdef AMBIENT_OCCLUSION
	float ambmul = (1.0 - 0.9*(0.0
		//+f3d_textureLod(tex_density, fpos, 5.0).r
		//+f3d_textureLod(tex_density, fpos, 4.0).r
		//+f3d_textureLod(tex_density, fpos, 3.0).r
		//+f3d_textureLod(tex_density, fpos, 2.0).r
		//+f3d_textureLod(tex_density, fpos, 1.0).r
		//+max(0.0, f3d_textureLod(tex_density, fpos + frnorm*0.5, 1.0).r*2.0-1.0)
		//+max(0.0, f3d_textureLod(tex_density, fpos + frnorm*0.5, 0.0).r*2.0-1.0)
		+f3d_textureLod(tex_density, fpos_air, 1.0).r
		+f3d_textureLod(tex_density, fpos_air, 0.0).r
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
#ifdef INPUT_BEAMER
#ifdef ENHANCE_QUALITY
	bool enhance_quality = abs(atime_cast/atime_target) > 1.0001;
#else
	bool enhance_quality = false;
#endif
#else
	bool enhance_quality = true;
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
			vec4 ltval_L = f3d_textureLod(tex_ltpos, fpos, float(i));
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
			vec4 ltv = f3d_textureLod(tex_ltpos, fpos, float(i));
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
#if defined(INPUT_DITHER_LIGHTS) && !defined(COMPAT)
	else {
		vec3 inv00 = textureOffset(tex_beamer, cam_texcoord*0.5+0.5, ivec2(-1, -1)).rgb;
		vec3 inv01 = textureOffset(tex_beamer, cam_texcoord*0.5+0.5, ivec2( 0, -1)).rgb;
		vec3 inv10 = textureOffset(tex_beamer, cam_texcoord*0.5+0.5, ivec2(-1,  0)).rgb;
		vec3 inv11 = textureOffset(tex_beamer, cam_texcoord*0.5+0.5, ivec2( 0,  0)).rgb;
		vec3 inv20 = textureOffset(tex_beamer, cam_texcoord*0.5+0.5, ivec2(-1,  1)).rgb;
		vec3 inv21 = textureOffset(tex_beamer, cam_texcoord*0.5+0.5, ivec2( 0,  1)).rgb;
		vec3 inv30 = textureOffset(tex_beamer, cam_texcoord*0.5+0.5, ivec2(-1,  2)).rgb;
		vec3 inv31 = textureOffset(tex_beamer, cam_texcoord*0.5+0.5, ivec2( 0,  2)).rgb;
		intex.rgb = (
			inv00+inv01+inv10+inv11
			+
			inv20+inv21+inv30+inv31
			)/8.0;

	}
#endif
#endif

	// combine all
	fcol.rgb *= diffamb;
	fcol.rgb += specular;

#ifndef BEAMER
#ifdef INPUT_BEAMER
	if(!enhance_quality)
	{
		fcol.rgb += intex.rgb;
	} else {
		//fcol.r += 0.2;
	}
#endif
#endif

#ifdef COMPAT
	gl_FragColor = fcol;
#endif
}

