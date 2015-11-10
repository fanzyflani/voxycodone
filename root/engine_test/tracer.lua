require("objects")

GLIBLIST = {}
SCENE_LIST = {}
SCENE = {}

function glib_add(s)
	table.insert(GLIBLIST, s)
end

function tracer_clear()
	GLIBLIST = {}
	OBJLIST = {}
end

function tracer_generate(settings)
	local k, v

	local name = settings.name
	assert(name, "give this tracer a name dammit")
	local do_shadow = settings.do_shadow
	if do_shadow == nil then do_shadow = true end
	do_shadow = (do_shadow and "true") or "false"

	local bounces = settings.bounces or 2

	local src_main_frag = "#version 150\n"
	src_main_frag = src_main_frag .. [=[
	invariant in vec3 wpos_in;
	in vec3 wdir_in;
	out vec4 out_frag_color;
	out vec4 out_frag_color_gi;

	const int LIGHT_MAX = 32;

	const float EPSILON = 0.0001;
	const float ZFAR = 10000.0;
	const uint BOUNCES = ]=]..bounces..[=[U;

	const bool do_shadow = ]=]..do_shadow..[=[;

	uniform uint light_count;
	uniform vec3 light_col[LIGHT_MAX];
	uniform vec3 light_pos[LIGHT_MAX];
	uniform vec3 light_dir[LIGHT_MAX];
	uniform float light_cos[LIGHT_MAX];
	uniform float light_pow[LIGHT_MAX];
	uniform float light_amb;

	vec3 ccol;
	float ccol_fac;

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

		float znear, zfar;

		float mat_shine;
	};


	]=]

	for k, v in pairs(GLIBLIST) do
		src_main_frag = src_main_frag .. v .."\n"
	end

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
		T0.znear = EPSILON;

		ccol = vec3(0.0);
		vec3 ccol_gi = vec3(0.0);
		ccol_fac = 1.0;

		for(uint i = 0U; i < BOUNCES+1U; i++)
		{
			// Trace scene
			trace_scene(T0, false);

			if(T0.hit_time == T0.zfar) break; // DIDN'T HIT ANYTHING

			float diff = 0.0;
			float spec = 0.0;
			vec3 spec_dir = T0.src_wdir - 2.0*dot(T0.obj_norm, T0.src_wdir)*T0.obj_norm;

			// Calc for light
			float llen = length(light_pos[0] - T0.hit_pos);
			vec3 ldir = (light_pos[0] - T0.hit_pos) / llen;

			// Trace shadow
			Trace T1 = T0;
			float ldiff = max(0.0, dot(ldir, T0.obj_norm));
			float lspec = max(0.0, dot(ldir, spec_dir));
			bool can_do_shadow = (ldiff > 0.0 || lspec > 0.0);
			T1.zfar = T1.hit_time = llen;
			if(do_shadow && can_do_shadow)
			{
				T1.src_wpos = T0.hit_pos;
				T1.src_wdir = ldir;
				trace_scene(T1, true);
			}

			// Check for occlusion
			if((can_do_shadow && T1.hit_time == T1.zfar)) // DIDN'T HIT ANYTHING
			{
				lspec = pow(lspec, 128.0);
				diff += ldiff;
				spec += lspec;
			}

			diff = diff * (1.0 - light_amb) + light_amb;
			ccol += (T0.mat_col * diff + spec) * ccol_fac;
			ccol_fac *= T0.mat_shine;
			if(ccol_fac < 0.01) break;

			// Reflect
			T0.src_wpos = T0.hit_pos;
			T0.src_wdir = spec_dir;
			T0.zfar -= T0.hit_time;
			T0.hit_time = T0.zfar;
		}

		out_frag_color = vec4(ccol, 1.0);
		out_frag_color_gi = vec4(0.0);
	}
	]=]

	SCENE[name] = {
		frag = src_main_frag,
		update = settings.update,
	}

	table.insert(SCENE_LIST, name)
end


