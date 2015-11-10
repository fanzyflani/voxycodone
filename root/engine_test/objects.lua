require("util")

OBJLIST = {}

function add_obj(o)
	o = {"obj", o}
	table.insert(OBJLIST, o)
	return o
end

function fix_indent(s)
	local l = split(s, "\n")
	local tabs = nil

	local k, v
	for k,v in pairs(l) do
		local i
		local has_data = false
		local ltabs = 0
		for i=1,#v do
			if v:sub(i,i) == "\t" or v:sub(i,i) == " " then
				ltabs = ltabs + 1
			else
				has_data = true
				break
			end
		end

		if has_data then
			if not tabs then
				tabs = ltabs
			elseif ltabs < tabs then
				tabs = ltabs
			end
		end
	end

	for k,v in pairs(l) do
		l[k] = v:sub(tabs+1)
	end

	return table.concat(l, "\n")
end

local proc_idx_main = 0
function process_src(o, settings)
	settings = settings or {}
	local i = 1
	local src = fix_indent(o[2].src)
	--print(o[1])
	--print(src:sub(i))

	local proc_src = ""
	local proc_idx = proc_idx_main
	proc_idx_main = proc_idx_main+1
	while true do
		local j = src:find("${", i)
		if not j then
			proc_src = proc_src .. src:sub(i)
			break
		end
		local k = src:find("}", j+2)
		proc_src = proc_src .. src:sub(i, j-1)
		local name = src:sub(j+2, k-1)
		local varout = nil

		if name:sub(1,1) == "." then
			name = name:sub(2)
			--print("VAR", "<"..name..">")
			local v = o[2].vars[name]
			if v[1] == "float" then
				varout = string.format("%f", v[2])
			elseif v[1] == "vec3" then
				varout = string.format("vec3(%f, %f, %f)", v[2][1], v[2][2], v[2][3])
			elseif v[1] == "int" then
				varout = string.format("%i", v[2])
			elseif v[1] == "ref" then
				varout = v[2]
			end
		elseif name:sub(1,1) == "_" then
			name = "L"..proc_idx_main.."_"..name:sub(2)
			--print("LOC", "<"..name..">")
			varout = name
		elseif name == "CALC_HIT" then
			--print("CALC_HIT")
			varout = fix_indent([=[
				// CALC_HIT {
				if(T.obj_time >= T.hit_time)
					return;

				T.hit_time = T.obj_time;
				T.hit_pos = T.src_wpos + (T.src_wdir * (T.obj_time - EPSILON*1.0));
				// } CALC_HIT
			]=])
		elseif name == "RETURN" then
			varout = settings.code_return or "return;"
		else
			--print("GLB", "<"..name..">")
			varout = "T."..name
		end
		proc_src = proc_src .. varout
		i = k+1
	end
	--print(proc_src)
	return proc_src
end

function var_ref(v) return {"ref", v} end
function var_float(v) return {"float", v} end
function var_vec2(v) return {"vec2", v} end
function var_vec3(v) return {"vec3", v} end
function var_vec4(v) return {"vec4", v} end
function var_int(v) return {"int", v} end
function var_ivec2(v) return {"ivec2", v} end
function var_ivec3(v) return {"ivec3", v} end
function var_ivec4(v) return {"ivec4", v} end
function var_uint(v) return {"uint", v} end
function var_uvec2(v) return {"uvec2", v} end
function var_uvec3(v) return {"uvec3", v} end
function var_uvec4(v) return {"uvec4", v} end

DIR_LIST_VEC3 = {
	["+x"] = var_vec3({ 1, 0, 0}),
	["+y"] = var_vec3({ 0, 1, 0}),
	["+z"] = var_vec3({ 0, 0, 1}),
	["-x"] = var_vec3({-1, 0, 0}),
	["-y"] = var_vec3({ 0,-1, 0}),
	["-z"] = var_vec3({ 0, 0,-1}),
}
function var_dir_vec3(s)
	if s[1] == "vec3" then
		return s
	else
		return DIR_LIST_VEC3[s]
	end
end

function mat_chequer(settings)
	local this = {}

	this.vars = {
		bias = settings.bias or var_float(0.01),
		sq_size = settings.sq_size or var_float(1.0),
		c0 = settings.c0,
		c1 = settings.c1,
	}

	this.src = [=[
		${mat_col} = int(dot(vec3(ivec3(floor(${hit_pos}/${.sq_size} + ${.bias})) & 1), vec3(1.0))) % 2 >= 1
			? ${.c0}
			: ${.c1};
	]=]

	return {"mat", this}
end

function mat_solid(settings)
	local this = {}

	this.vars = {
		c0 = settings.c0,
	}

	this.src = [=[
		${mat_col} = ${.c0};
	]=]

	return {"mat", this}
end

function obj_plane(settings)
	local this = {}

	this.name = settings.name

	this.vars = {
		dir = var_dir_vec3(settings.dir),
		pos = settings.pos,
	}

	this.mat = settings.mat

	this.src = [=[
		float ${_offs_plane} = dot(${.dir}, ${.pos});
		float ${_offs_wpos} = dot(${.dir}, ${src_wpos});
		float ${_doffs} = ${_offs_plane} - ${_offs_wpos};
		float ${_time} = ${_doffs} * dot(${.dir}, 1.0 / ${src_wdir});

		if(${_time} <= ${znear})
			${RETURN}

		${obj_time} = ${_time};

		${CALC_HIT}

		${front_time} = ${back_time} = ${obj_time};
		${obj_norm} = ${.dir};
	]=]

	return add_obj(this)
end

function obj_sphere(settings)
	local this = {}

	this.name = settings.name

	this.vars = {
		rad = settings.rad,
		pos = settings.pos,
	}

	this.mat = settings.mat

	this.src = [=[
		vec3 ${_rel_pos} = ${src_wpos} - ${.pos};
		float ${_tA} = -dot(${src_wdir}, ${_rel_pos});
		float ${_srad2} = ${.rad} * ${.rad};
		float ${_slen2} = dot(${_rel_pos}, ${_rel_pos});
		float ${_tB2} = ${_tA}*${_tA} + ${_srad2} - ${_slen2};

		if(${_tB2} < 0.0)
			${RETURN}

		float ${_tB} = sqrt(${_tB2});
		float ${_tX} = ${_tA}-${_tB};
		float ${_tY} = ${_tA}+${_tB};

		if(${_tY} <= ${znear})
			${RETURN}

		bool ${_is_inside} = (${_tX} <= ${znear});

		${obj_time} = (${_is_inside} ? ${_tY} : ${_tX});

		${CALC_HIT}

		${front_time} = ${_tX};
		${back_time} = ${_tY};
		${obj_norm} = normalize(${hit_pos} - ${.pos});
		if(${_is_inside}) ${obj_norm} = -${obj_norm};
	]=]

	return add_obj(this)
end

function obj_box(settings)
	local this = {}

	this.name = settings.name

	this.vars = {
		pos1 = settings.pos1,
		pos2 = settings.pos2,
	}

	this.mat = settings.mat

	this.src = [=[
		vec3 ${_vt1} = (${.pos1} - ${src_wpos}) / ${src_wdir};
		vec3 ${_vt2} = (${.pos2} - ${src_wpos}) / ${src_wdir};

		vec3 ${_vtmin} = mix(${_vt2}, ${_vt1}, lessThan(${_vt1}, ${_vt2}));
		vec3 ${_vtmax} = mix(${_vt2}, ${_vt1}, greaterThanEqual(${_vt1}, ${_vt2}));

		float ${_tf} = max(${_vtmin}.x, max(${_vtmin}.y, ${_vtmin}.z));
		float ${_tb} = min(${_vtmax}.x, min(${_vtmax}.y, ${_vtmax}.z));

		if(${_tb} <= ${_tf})
			${RETURN}

		if(${_tb} <= ${znear})
			${RETURN}

		bool ${_is_inside} = (${_tf} <= ${znear});

		${obj_time} = (${_is_inside} ? ${_tb} : ${_tf});

		${CALC_HIT}

		${front_time} = ${_tf};
		${back_time} = ${_tb};

		${obj_norm} = vec3(equal(vec3(${obj_time}), ${_vt2}))
			- vec3(equal(vec3(${obj_time}), ${_vt1}));
		if(${_is_inside}) ${obj_norm} = -${obj_norm};
	]=]

	return add_obj(this)
end

