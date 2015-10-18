// vim: syntax=c
#version 150

invariant in vec3 wpos_in;
in vec3 wdir_in;
out vec4 out_frag_color;

%include glsl/common.glsl

%include glsl/kd.lib

void apply_light(vec3 epoint)
{
	vec3 ldir = normalize(light0_pos - epoint);
	float lfoc = (dot(ldir, -normalize(light0_dir)) - light0_cos)/light0_cos;
	if(lfoc > 0.0)
	{
		tdiff = max(0.0, dot(tnorm, ldir));
		tdiff *= pow(lfoc, light0_pow);
	} else {
		tdiff = 0.0;
	}
}

%include glsl/sphere.obj
%include glsl/cylinder.obj
%include glsl/donut.obj
%include glsl/plane.obj

%include glsl/genkd1.scene

void main()
{
	wpos = wpos_in;
	wdir = normalize(wdir_in);

	// Set up boundary
	float amax = max(max(abs(wdir.x),abs(wdir.y)),abs(wdir.z));
	//tcol = (amax == abs(wdir.y) ? vec3(0.4, 1.0, 0.3) : vec3(0.5, 0.7, 1.0)) * amax;
	tcol = vec3(0.5, 0.7, 1.0) * amax;
	tnorm = vec3(0.0);
	ttime = zfar;
	tdiff = 1.0;

	if(do_debug) dcol = vec3(0.0);
	ccol = vec3(0.0);
	float ccol_fac = 1.0;

	for(uint i = 0U; i < BOUNCES+1U; i++)
	{
		// Trace scene
		trace_scene(false);

		if(ttime == zfar) break; // DIDN'T HIT ANYTHING

		// Move to surface
		wpos = wpos + (ttime-EPSILON*8.0)*wdir;
		zfar -= ttime;
		ttime = zfar;

		// Back up useful things
		float zfar_bak = zfar;
		//vec3 tcol_bak = tcol;
		//vec3 tnorm_bak = tnorm;
		//float tdiff_bak = tdiff;
		vec3 wpos_bak = wpos;
		vec3 wdir_bak = wdir;

		// Trace to light for shadows
		if(do_shadow)
		{
			zfar = ttime = length(light0_pos - wpos);

			if(false)
			{
				// Cast from light
				// disabled: causes fringing on the shadows
				// and no real performance improvements
				wdir = normalize(wpos - light0_pos);
				wpos = light0_pos;
			} else {
				// Cast to light
				wdir = normalize(light0_pos - wpos);
			}

			if(tdiff > 0.0)
			{
				trace_scene(true);
			}
		}

		// Check if we hit something
		bool unshadowed = (!do_shadow) || (ttime == zfar);

		// Restore colour backup
		//tcol = tcol_bak;
		//tdiff = tdiff_bak;

		// Restore trace backup
		//tnorm = tnorm_bak;
		wpos = wpos_bak;
		wdir = wdir_bak;
		ttime = zfar = zfar_bak;

		// Reflect
		wdir = 2.0*dot(tnorm, -wdir)*tnorm + wdir;

		// Apply ambient + diffuse
		float comb_light = 0.1;
		if(unshadowed)
			comb_light += 0.9*tdiff;
		tcol *= comb_light;

		// Apply specular
		if(unshadowed)
		{
			float spec = 1.0;
			vec3 ldir = normalize(light0_pos - wpos);
			spec *= max(0.0, dot(wdir, ldir));
			float lfoc = max(0.0, (dot(ldir, -normalize(light0_dir)) - light0_cos)/light0_cos);
			spec *= (lfoc > 0.0 ? 1.0 : 0.0);
			if(spec > 0.0)
				tcol += pow(spec, 128.0);
		}


		// Accumulate colour
		ccol += tcol * ccol_fac;
		ccol_fac *= 0.3;

	}

	if(ccol_fac == 1.0) ccol = tcol;
	if(do_debug) ccol = dcol * vec3(0.5, 0.3, 1.0);

	out_frag_color = vec4(ccol, 1.0);
}

