require("lua/objects")
require("lua/tracer")

tracer_clear()

-- LIBS
glib_add([=[
uniform vec3 scene_s1_pos;
uniform vec3 scene_s2_pos;
]=])

-- DEFINITIONS
m_chequer_bw = mat_chequer {
	c0 = var_vec3({0.9, 0.9, 0.9}),
	c1 = var_vec3({0.1, 0.1, 0.1}),
	sq_size = var_float(5.0),
}

--[[
obj_csg_subtract {
	main = obj_plane {
		dir = "+y",
		pos = {0, -2, 0},
		mat = m_chequer_bw,
	},

	cutters = {
		obj_sphere {
			pos = {0, -2, 0},
			rad = 1.0,
			mat = mat_solid {
				c0 = {0.9, 0.3, 0.9},
			},
		},
	},
}
]]

obj_plane {
	name = "floor",
	dir = "+y",
	pos = var_vec3({0, -2, 0}),
	mat = m_chequer_bw,
}

--[[
obj_plane {
	dir = "+z",
	pos = {0, 0, -20},
	mat = mat_solid { c0 = {1.0, 1.0, 0.0}, },
}
]]

--[[
obj_sphere {
	pos = {-3, 3.0, -10},
	rad = 5.0,
	mat = mat_solid { c0 = {1.0, 0.5, 0.0}, },
}

obj_sphere {
	pos = {3, 3.0, -10},
	rad = 5.0,
	mat = mat_solid { c0 = {0.0, 0.5, 1.0}, },
}
]]

obj_box {
	name = "box1",
	pos1 = var_vec3({-1, -1, -3}),
	pos2 = var_vec3({ 1,  1, -1}),
	mat = mat_solid { c0 = var_vec3({0.3, 1.0, 0.3}), },
}

local csg_test = {
	o1 = obj_sphere {
		name = "s1",
		--pos = var_vec3({-3, 3.0, -10}),
		pos = var_ref("scene_s1_pos"),
		rad = var_float(5.0),
		--mat = mat_solid { c0 = {1.0, 0.5, 0.0}, },
		mat = mat_chequer {
			c0 = var_vec3({1.0, 0.5, 0.0}),
			c1 = var_vec3({0.0, 0.5, 1.0}),
			sq_size = var_float(0.5),
		},
	},

	o2 = obj_sphere {
		name = "s2",
		--pos = var_vec3({3, 3.0, -10}),
		pos = var_ref("scene_s2_pos"),
		rad = var_float(5.0),
		--mat = mat_solid { c0 = {0.0, 0.5, 1.0}, },
		mat = mat_solid { c0 = var_vec3({0.5, 0.3, 0.0}), },
	},
}

local function scene_test_update(sec_current, sec_delta)
	local a1 = sec_current*2.0
	local a2 = sec_current*2.0
	local s1x = 0 - 3.0*math.cos(a1)
	local s1y = 3.0
	local s1z = -10 - 3.0*math.sin(a1*1.7)
	local s2x = 0 + 3.0*math.cos(a1*1.4)
	local s2y = 3.0
	local s2z = -10 + 3.0*math.sin(a2)

	shader.uniform_f(S.scene_s1_pos, s1x, s1y, s1z);
	shader.uniform_f(S.scene_s2_pos, s2x, s2y, s2z);
end

tracer_generate {
	name = "test_isect",
	update = scene_test_update,
	trace_scene = [=[

	Trace T1 = T;
	Trace T2 = T;
	obj_s1_trace(T1, true);
	obj_s2_trace(T2, true);

	// Ensure we hit both
	if(T1.hit_time < T1.zfar && T2.hit_time < T2.zfar)
	{
		if(T1.hit_time == T1.back_time && T2.hit_time == T2.back_time)
		{
			// Inside both
			obj_s1_trace(T, shadow_mode);
			obj_s2_trace(T, shadow_mode);

		} else if(T2.front_time < T1.front_time && T1.front_time < T2.back_time) {
			// Hit s1
			T.znear = T2.front_time;
			obj_s1_trace(T, shadow_mode);
			T.znear = T2.znear;

		} else if(T1.front_time < T2.front_time && T2.front_time < T1.back_time) {
			// Hit s2
			T.znear = T1.front_time;
			obj_s2_trace(T, shadow_mode);
			T.znear = T1.znear;
		}

	}

	obj_floor_trace(T, shadow_mode);
	obj_box1_trace(T, shadow_mode);

	]=],
}

tracer_generate {
	name = "test_sub",
	update = scene_test_update,
	trace_scene = [=[

	Trace T1 = T;
	Trace T2 = T;
	obj_s1_trace(T1, true);
	obj_s2_trace(T2, true);

	if(T1.hit_time < T1.zfar && T1.hit_time == T1.back_time)
	{
		// Inside T1
		if(T2.hit_time >= T2.zfar)
		{
			obj_s1_trace(T, shadow_mode);
		} else if(T2.hit_time < T1.back_time) {
			obj_s2_trace(T, shadow_mode);

		}

	} else if(T1.hit_time < T1.zfar) {
		// Hit T1
		if(T2.hit_time >= T2.zfar || T1.front_time < T2.front_time || T1.front_time > T2.back_time)
		{
			obj_s1_trace(T, shadow_mode);

		} else if(T2.back_time > T1.back_time) {
			// PASS THROUGH

		} else {
			T.znear = T1.hit_time;
			obj_s2_trace(T, shadow_mode);
			T.znear = T1.znear;
		}

	}

	obj_floor_trace(T, shadow_mode);
	obj_box1_trace(T, shadow_mode);

	]=],
}

tracer_generate {
	name = "test_skip",
	update = scene_test_update,
	trace_scene = [=[

	Trace T1 = T;
	obj_s1_trace(T1, true);
	obj_floor_trace(T1, true);
	obj_box1_trace(T1, true);

	Trace T2 = T;
	obj_s2_trace(T2, true);

	if(T2.hit_time < T2.zfar && T2.front_time < T1.hit_time)
	{
		T.znear = T2.back_time;
	}

	obj_s1_trace(T, shadow_mode);
	obj_floor_trace(T, shadow_mode);
	obj_box1_trace(T, shadow_mode);

	T.znear = T1.znear;

	]=],
}

tracer_generate {
	--name = "test_union",
	name = "test",
	update = scene_test_update,
}

