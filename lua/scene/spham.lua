require("lua/objects")
require("lua/tracer")

tracer_clear()

glib_add([=[
vec3 s_pos;
vec3 s_col;

uniform sampler2D tex_rand;

]=])

obj_sphere {
	name = "sref",
	pos = var_ref("s_pos"),
	rad = var_float(1.0),
	--mat = mat_solid { c0 = var_vec3({1.0, 0.5, 0.0}), },
	mat = mat_solid { c0 = var_ref("s_col"), },
}

tracer_generate {
	name = "spham",
	do_shadow = false,
	trace_scene = [=[

	const float spacing = 5.0;
	const int max_trace = 10;

	s_pos = (vec3(0.5) + floor(T.src_wpos/spacing))*spacing;

	vec3 subpos = T.src_wpos/spacing;
	subpos -= floor(subpos);
	//subpos = mix(subpos, 1.0-subpos, lessThan(T.src_wdir, vec3(0.0)));
	subpos = mix(1.0-subpos, subpos, lessThan(T.src_wdir, vec3(0.0)));

	vec3 adir = abs(T.src_wdir);
	vec3 cdir = sign(T.src_wdir)*spacing;

	for(int i = 0; i < max_trace; i++)
	{
		s_col = texture(tex_rand, (s_pos.xy + s_pos.yz - s_pos.zx)/spacing/32.0).rgb;
		obj_sref_trace(T, shadow_mode);

		if(T.hit_time < T.zfar)
		{
			T.mat_col = mix(vec3(0.0), T.mat_col, clamp(pow(0.8, T.hit_time), 0.0, 1.0))*ccol_fac;
			return;
		}

		vec3 ctime = subpos/adir;
		float mintime = min(ctime.x, min(ctime.y, ctime.z));
		subpos -= mintime * adir;
		subpos += vec3(equal(ctime, vec3(mintime)));
		s_pos += vec3(equal(ctime, vec3(mintime))) * cdir;
	}

	]=],
}
