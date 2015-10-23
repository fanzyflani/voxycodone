-- experiments with the syntax and whatnot

OBJLIST = {}

function split(s, tok)
	local l = {}

	local i = 1
	local tlen = #tok
	while true do
		local j = s:find(tok, i)

		if not j then
			table.insert(l, s:sub(i))
			return l
		end

		table.insert(l, s:sub(i, j-1))
		i = j+tlen
	end
end

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
function process_src(o)
	local i = 1
	local src = fix_indent(o[2].src)
	print(o[1])
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
			end
		elseif name:sub(1,1) == "_" then
			name = "L"..proc_idx_main.."_"..name:sub(2)
			--print("LOC", "<"..name..">")
			varout = name
		elseif name == "CALC_HIT" then
			--print("CALC_HIT")
			varout = fix_indent([=[
				// CALC_HIT {
				if(T.obj_time < T.hit_time)
					return;

				T.hit_time = T.obj_time;
				T.hit_pos = T.src_wpos + (T.src_wdir * T.obj_time);
				// } CALC_HIT
			]=])
		else
			--print("GLB", "<"..name..">")
			varout = "T."..name
		end
		proc_src = proc_src .. varout
		i = k+1
	end
	print(proc_src)
end

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
		bias = var_float(settings.bias or 0.01),
		c0 = var_vec3(settings.c0),
		c1 = var_vec3(settings.c1),
	}

	this.src = [=[
		${mat_col} = int(dot(vec3(ivec3(${hit_pos} + ${.bias}) % 2), vec3(1.0))) % 2 >= 1
			? ${.c0}
			: ${.c1}
	]=]

	return {"mat", this}
end

function mat_solid(settings)
	local this = {}

	this.vars = {
		c0 = var_vec3(settings.c0),
	}

	this.src = [=[
		${mat_col} = ${.c0};
	]=]

	return {"mat", this}
end

function obj_plane(settings)
	local this = {}

	this.vars = {
		dir = var_dir_vec3(settings.dir),
		pos = var_vec3(settings.pos),
	}

	this.mat = settings.mat

	this.src = [=[
		float ${_offs_plane} = dot(${.dir}, ${.pos});
		float ${_offs_wpos} = dot(${.dir}, ${src_wpos});
		float ${_doffs} = ${_offs_plane} - ${_offs_wpos};
		float ${_time} = ${_doffs} * dot(${.dir}, ${src_wdir});

		if(${_time} < EPSILON)
			return;

		${obj_time} = ${_time};

		${CALC_HIT}

		${obj_norm} = ${.dir};
	]=]

	return add_obj(this)
end

-- DEFINITIONS
m_chequer_bw = mat_chequer {
	c0 = {0.9, 0.9, 0.9},
	c1 = {0.1, 0.1, 0.1},
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
	dir = "+y",
	pos = {0, -2, 0},
	mat = m_chequer_bw,
}

obj_plane {
	dir = "+z",
	pos = {0, 0, -20},
	mat = mat_solid { c0 = {1.0, 1.0, 0.0}, },
}

local k, v
print("")
for k, v in pairs(OBJLIST) do
	print("processing", k)
	print("-----")
	process_src(v)
	print("-----")
	process_src(v[2].mat)
	print("-----\n")
end

-- from SDL_keycode.h
SDLK_ESCAPE = 27
SDLK_SPACE = 32
SDLK_w = ("w"):byte()
SDLK_s = ("s"):byte()
SDLK_a = ("a"):byte()
SDLK_d = ("d"):byte()
SDLK_LCTRL = (1<<30)+224

key_pos_dzp = false
key_pos_dzn = false
key_pos_dxn = false
key_pos_dxp = false
key_pos_dyn = false
key_pos_dyp = false

cam_rot_x = 0.0
cam_rot_y = 0.0
cam_pos_x = 0.0
cam_pos_y = 0.0
cam_pos_z = 0.0

do_exit = false -- just in case we were to bother with this

function hook_key(key, state)
	if key == SDLK_ESCAPE and not state then
		do_exit = true
	elseif key == SDLK_w then key_pos_dzp = state
	elseif key == SDLK_s then key_pos_dzn = state
	elseif key == SDLK_a then key_pos_dxn = state
	elseif key == SDLK_d then key_pos_dxp = state
	elseif key == SDLK_LCTRL then key_pos_dyn = state
	elseif key == SDLK_SPACE then key_pos_dyp = state
	end
end

function hook_mouse_button(button, state)
	if button == 1 and not state then
		mouse_locked = not mouse_locked
		-- TODO provide API
		--misc.cursor_visible_set(not mouse_locked)
		--misc.mouse_grab_set(mouse_locked)
	end
end

function hook_mouse_motion(x, y, dx, dy)
	if not mouse_locked then return end

	cam_rot_y = cam_rot_y - dx*math.pi/1000.0
	cam_rot_x = cam_rot_x + dy*math.pi/1000.0
	local clamp = math.pi/2.0-0.0001
	if cam_rot_x < -clamp then cam_rot_x = -clamp end
	if cam_rot_x >  clamp then cam_rot_x =  clamp end
end

function hook_tick(sec_current, sec_delta)
	-- This is a Lua implementation
	-- of a C function
	-- which was originally written in Lua.

	local mvspeed = 20.0
	--local mvspeed = 2.0
	local mvspeedf = mvspeed * sec_delta

	local ldx = 0.0
	local ldy = 0.0
	local ldz = 0.0
	if key_pos_dxn then ldx = ldx - 1 end
	if key_pos_dxp then ldx = ldx + 1 end
	if key_pos_dyn then ldy = ldy - 1 end
	if key_pos_dyp then ldy = ldy + 1 end
	if key_pos_dzn then ldz = ldz - 1 end
	if key_pos_dzp then ldz = ldz + 1 end

	ldx = ldx * mvspeedf
	ldy = ldy * mvspeedf
	ldz = ldz * mvspeedf

	local ldw = ldz
	local ldh = ldx
	local ldv = ldy

	local xs, xc = math.sin(cam_rot_x), math.cos(cam_rot_x)
	local ys, yc = math.sin(cam_rot_y), math.cos(cam_rot_y)
	local fx, fy, fz = -xc*ys, -xs, -xc*yc
	local wx, wy, wz = -ys, 0, -yc
	local hx, hy, hz = yc, 0, -ys
	local vx, vy, vz = -xs*ys, xc, -xs*yc

	cam_pos_x = cam_pos_x + hx*ldh + fx*ldw + vx*ldv
	cam_pos_y = cam_pos_y + hy*ldh + fy*ldw + vy*ldv
	cam_pos_z = cam_pos_z + hz*ldh + fz*ldw + vz*ldv

	-- TODO: set camera
	--print(sec_delta)
end

