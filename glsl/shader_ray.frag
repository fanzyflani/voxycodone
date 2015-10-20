// vim: syntax=c
#version 150

invariant in vec3 wpos_in;
in vec3 wdir_in;
out vec4 out_frag_color;
out vec4 out_frag_color_gi;

%include glsl/common.glsl

%include glsl/kd.lib
%include glsl/lighting.lib

%include glsl/sphere.obj
%include glsl/cylinder.obj
%include glsl/donut.obj
%include glsl/plane.obj

%include glsl/facroom1.scene

void main()
{
	Trace T0;

	T0.wpos = wpos_in;
	T0.wdir = normalize(wdir_in);

	// Set up boundary
	//float amax = max(max(abs(wdir.x),abs(wdir.y)),abs(wdir.z));
	//tcol = (amax == abs(wdir.y) ? vec3(0.4, 1.0, 0.3) : vec3(0.5, 0.7, 1.0)) * amax;
	//tcol = vec3(0.5, 0.7, 1.0) * amax;
	T0.tnorm = vec3(0.0);
	T0.ttime = T0.zfar = ZFAR;
	T0.tdiff = 1.0;
	T0.tshine = 0.3;

	if(do_debug) dcol = vec3(0.0);
	ccol = vec3(0.0);
	vec3 ccol_gi = vec3(0.0);
	float ccol_fac = 1.0;

	for(uint i = 0U; i < BOUNCES+1U; i++)
	{
		// Trace scene
		trace_scene(T0, false);

		if(T0.ttime == T0.zfar) break; // DIDN'T HIT ANYTHING

		// Move to surface
		T0.wpos = T0.wpos + (T0.ttime-EPSILON*8.0)*T0.wdir;
		T0.zfar -= T0.ttime;
		T0.ttime = T0.zfar;

		// Back up useful things
		Trace T1;
		T1 = T0;

		// Apply ambient
		vec3 acol_gi = vec3(0.0);
		vec3 acol = (
			RADIOSITY_BOUNCES_WARNING_THIS_IS_FUCKING_SLOW > 0U
			? vec3(0.0)
			: T0.tcol * light_amb);

		// Trace to light for shadows
		for(uint lidx = 0U; lidx < light_count; lidx++)
		{
			// Calculate diffuse
			apply_light(T0, lidx, T0.wpos);

			// Check if we hit something
			bool unshadowed = T0.tdiff > 0.0;
			if(!unshadowed) T0.tdiff = 0.0;

			// Cast shadow
			vec3 mcol = vec3(0.0);
			vec3 mcol_gi = vec3(0.0);

			if(do_shadow && unshadowed)
			{
				T0.zfar = T0.ttime = length(light_pos[lidx] - T0.wpos);

				if(false)
				{
					// Cast from light
					// disabled: causes fringing on the shadows
					// and no real performance improvements
					T0.wdir = normalize(T0.wpos - light_pos[lidx]);
					T0.wpos = light_pos[lidx];
				} else {
					// Cast to light
					T0.wdir = normalize(light_pos[lidx] - T0.wpos);
				}

				trace_scene(T0, true);
				mcol = T0.tcol * T0.tdiff;

				if(T0.ttime != T0.zfar)
				{
					unshadowed = false;
					mcol = vec3(0.0);
				}
			}

			// INDIRECT LIGHTING
			// Cast from light to random direction
			Trace Ti;
			if(do_indirect && RADIOSITY_BOUNCES_WARNING_THIS_IS_FUCKING_SLOW > 0U)
			{
				Ti = T1;

				Ti.wdir = normalize(light_dir[lidx]*2.0 + texture(tex_rand,
					vec2(gl_FragCoord.xy)/128.0).xyz*2.0-1.0);
				Ti.wpos = light_pos[lidx];
			}

			if(do_indirect)
			for(uint rb = 0U; rb < RADIOSITY_BOUNCES_WARNING_THIS_IS_FUCKING_SLOW; rb++)
			{
				// Calculate light
				trace_scene(Ti, false);
				vec3 mcol_i = vec3(0.2)*T1.tcol;
				Ti.wpos += Ti.wdir*(Ti.ttime - EPSILON*8.0);
				apply_light(Ti, lidx, Ti.wpos);
				if(Ti.tdiff <= 0.0) break;

				mcol_i *= Ti.tcol * Ti.tdiff;

				// Cast from point to target
				Ti.wdir = normalize(T0.wpos - Ti.wpos);
				Ti.zfar = Ti.ttime = length(T0.wpos - Ti.wpos) - 1.0;
				Trace Ti2 = Ti;
				trace_scene(Ti2, true);

				// Check if we hit it
				if(Ti2.ttime == Ti2.zfar)
				{
					//if(!unshadowed)  mcol_i = vec3(0.1);
					unshadowed = true;
					//mcol_i *= 100.0;
					//mcol_i = vec3(1.0);
					mcol_gi += mcol_i;
					//T0.tcol = vec3(1.0, 0.0, 0.0);
					//mcol = vec3(1.0);
				}
			}

			// Apply diffuse
			acol += mcol * light_col[lidx];
			acol_gi += mcol_gi * light_col[lidx];

			// Restore backup
			T0 = T1;

			// Reflect
			T0.wdir = 2.0*dot(T0.tnorm, -T0.wdir)*T0.tnorm + T0.wdir;

			// Apply specular
			if(unshadowed)
			{
				float spec = 0.0;
				//spec *= 0.0;
				vec3 ldir = normalize(light_pos[lidx] - T0.wpos);
				spec *= max(0.0, dot(T0.wdir, ldir));
				float lfoc = clamp((dot(ldir, -normalize(light_dir[lidx])) - light_cos[lidx])/light_cos[lidx], 0.0, 1.0);
				//spec *= (lfoc > 0.0 ? lfoc : 0.0);
				spec *= (lfoc > 0.0 ? 1.0 : 0.0);
				spec *= (dot(ldir, T0.tnorm) > 0.0 ? 1.0 : 0.0);
				if(spec > 0.0)
					//acol += pow(spec, 128.0);
					acol += 0.2*pow(spec, 4.0)*acol;
			}
		}

		// Accumulate colour
		ccol += acol * ccol_fac;
		ccol_gi += acol_gi * ccol_fac;
		ccol_fac *= T1.tshine;
		if(ccol_fac <= 1.0/255.0/2.0) break;

	}

	if(ccol_fac == 1.0)
	{
		vec3 ccol1 = vec3(0.1, 0.05, 0.3);
		//vec3 ccol1 = vec3(0.2, 0.05, 0.1);
		//vec3 ccol1 = vec3(0.7, 0.7, 0.7);
		vec3 ccol0 = vec3(0.5, 0.0, 0.0);
		vec3 scol3 = normalize(wdir_in);
		//vec3 ascol3 = abs(scol3);
		//scol3 /= max(max(ascol3.x, ascol3.y), ascol3.z);

		//vec2 scol = scol3.xz + scol3.yx - scol3.zy;
		//vec2 scol = vec2(atan(scol3.x, scol3.z)*2.0/3.141593, scol3.y);
		vec2 scol = vec2(scol3.x, scol3.y);

		float camt = 0.0;
		camt += texture(tex_rand, scol*(1.0/32.0), 0).r*0.5;
		camt += texture(tex_rand, scol*(1.0/16.0), 0).r*0.2;
		camt += texture(tex_rand, scol*(1.0/8.0), 0).r*0.15;
		camt += texture(tex_rand, scol*(1.0/4.0), 0).r*0.05;
		camt *= 1.3;
		camt = min(1.0, camt);
		ccol = (ccol0 + (ccol1 - ccol0)*camt);
		//ccol = texture(tex_rand, scol).rgb;
	}

	if(do_debug) ccol = dcol * vec3(0.5, 0.3, 1.0);

	//out_frag_color = vec4(ccol + ccol_gi, 1.0);
	out_frag_color = vec4(ccol, 1.0);
	out_frag_color_gi = vec4(ccol_gi, any(greaterThan(ccol_gi, vec3(0.0))) ? 1.0 : 0.0);
}

