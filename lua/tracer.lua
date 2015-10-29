function tracer_generate(settings)
	local k, v

	local src_main_frag = "#version 150\n"
	src_main_frag = src_main_frag .. [=[
	invariant in vec3 wpos_in;
	in vec3 wdir_in;
	out vec4 out_frag_color;
	out vec4 out_frag_color_gi;

	const float EPSILON = 0.0001;
	const float ZFAR = 10000.0;
	const uint BOUNCES = 0U;

	vec3 ccol;

	struct Trace
	{
		vec3 src_wpos, src_wdir;

		vec3 hit_pos;
		float hit_time;
		float front_time;
		float back_time;

		vec3 obj_norm;
		float obj_time;
		vec3 mat_col;

		float zfar;

		float mat_shine;
	};


	]=]

	for k, v in pairs(OBJLIST) do
		print("processing", k)
		local src_obj = process_src(v)
		local src_mat = process_src(v[2].mat)
		local src_cmb = (
			"void obj_"..(v[2].name or k).."_trace(inout Trace T, bool shadow_mode) {\n" ..
			src_obj ..
			[=[
				if(shadow_mode) return;
			]=] ..
			src_mat ..
			"}\n" ..
			"\n")
		print("-----")
		print(src_cmb)
		print("-----\n")
		src_main_frag = src_main_frag .. src_cmb
	end

	src_main_frag = src_main_frag .. [=[
	void trace_scene(inout Trace T, bool shadow_mode)
	{

	]=]

	if settings.trace_scene then
		src_main_frag = src_main_frag .. settings.trace_scene
	else
		for k, v in pairs(OBJLIST) do
			src_main_frag = src_main_frag .. "\tobj_"..(v[2].name or k).."_trace(T, shadow_mode);\n"
		end
	end

	src_main_frag = src_main_frag .. [=[
	}
	]=]

	src_main_frag = src_main_frag .. [=[
	void main()
	{
		Trace T0;

		T0.src_wpos = wpos_in;
		T0.src_wdir = normalize(wdir_in);
		T0.mat_shine = 0.3;

		// Set up boundary
		T0.obj_norm = vec3(0.0);
		T0.hit_time = T0.zfar = ZFAR;

		ccol = vec3(0.0);
		vec3 ccol_gi = vec3(0.0);
		float ccol_fac = 1.0;

		for(uint i = 0U; i < BOUNCES+1U; i++)
		{
			// Trace scene
			trace_scene(T0, false);

			if(T0.hit_time == T0.zfar) break; // DIDN'T HIT ANYTHING

			vec3 spec_dir = T0.src_wdir - 2.0*dot(T0.obj_norm, T0.src_wdir)*T0.obj_norm;
			float diff = max(0.0, -dot(T0.src_wdir, T0.obj_norm));
			float spec = max(0.0, -dot(T0.src_wdir, spec_dir));
			spec = pow(spec, 128.0);
			float amb = 0.1;
			diff = diff * (1.0 - amb) + amb;
			ccol += (T0.mat_col * diff + spec) * ccol_fac;
			ccol_fac *= T0.mat_shine;
			if(ccol_fac < 0.01) break;

			// Reflect
			T0.src_wpos = T0.hit_pos;
			T0.src_wdir = spec_dir;
		}

		out_frag_color = vec4(ccol, 1.0);
		out_frag_color_gi = vec4(0.0);
	}
	]=]

	return src_main_frag
end


