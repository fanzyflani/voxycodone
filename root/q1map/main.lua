screen_w, screen_h = draw.screen_size_get()
screen_scale = 2

MAP_NAME = "start"

MAP_SPLIT_W = 1024
MAP_USE_REAL_NODES = false

-- from SDL_keycode.h
SDLK_ESCAPE = 27
SDLK_SPACE = 32
SDLK_w = ("w"):byte()
SDLK_s = ("s"):byte()
SDLK_a = ("a"):byte()
SDLK_d = ("d"):byte()
SDLK_0 = ("0"):byte()
SDLK_1 = ("1"):byte()
SDLK_2 = ("2"):byte()
SDLK_LCTRL = (1<<30)+224

cam_rot_x = 0.0
cam_rot_y = 0.0
cam_pos_x = 0.0
cam_pos_y = 0.0
cam_pos_z = 0.0
cam_vel_x = 0.0
cam_vel_y = 0.0
cam_vel_z = 0.0

loading = nil

function hook_key(key, state)
	if key == SDLK_ESCAPE and not state then
		misc.exit()
	elseif loading then return
	elseif key == SDLK_w then key_pos_dzp = state
	elseif key == SDLK_s then key_pos_dzn = state
	elseif key == SDLK_a then key_pos_dxn = state
	elseif key == SDLK_d then key_pos_dxp = state
	elseif key == SDLK_LCTRL then key_pos_dyn = state
	elseif key == SDLK_SPACE then key_pos_dyp = state
	end
end

function hook_mouse_button(button, state)
	if loading then return
	elseif button == 1 and not state then
		mouse_locked = not mouse_locked
		misc.mouse_grab_set(mouse_locked)
	elseif button == 2 and state then
		light_pos_x = nil
		light_pos_y = nil
		light_pos_z = nil
		light_dir_x = nil
		light_dir_y = nil
		light_dir_z = nil
	elseif button == 3 and state then
		light_pos_x = cam_pos_x
		light_pos_y = cam_pos_y
		light_pos_z = cam_pos_z
		light_dir_x = -math.cos(cam_rot_x)*math.sin(cam_rot_y)
		light_dir_y = -math.sin(cam_rot_x)
		light_dir_z = -math.cos(cam_rot_x)*math.cos(cam_rot_y)
	end
end

function hook_mouse_motion(x, y, dx, dy)
	if loading then return end
	if not mouse_locked then return end

	cam_rot_y = cam_rot_y - dx*math.pi/1000.0
	cam_rot_x = cam_rot_x + dy*math.pi/1000.0
	local clamp = math.pi/2.0-0.0001
	if cam_rot_x < -clamp then cam_rot_x = -clamp end
	if cam_rot_x >  clamp then cam_rot_x =  clamp end
end

function hook_render_loading(sec_current)
	if not shader_loading then return end

	draw.buffers_set({0})
	fbo.target_set(nil)
	shader.use(shader_loading)
	shader.uniform_f(shader.uniform_location_get(shader_loading, "time"), sec_current)
	shader.uniform_i(shader.uniform_location_get(shader_loading, "tex0"), 0)
	texture.unit_set(0, "2", tex_loading)
	draw.viewport_set(0, 0, screen_w, screen_h)
	draw.blit()
end

fps_tick = nil
fps_count = 0
function hook_render(sec_current)
	if loading then return hook_render_loading(sec_current) end
	fps_tick = fps_tick or (sec_current + 1.0)
	if sec_current >= fps_tick then
		fps_tick = fps_tick + 1.0
		print("FPS:", fps_count)
		fps_count = 0
	end
	fps_count = fps_count + 1

	mat_cam1 = mat_cam1 or matrix.new()
	mat_cam2 = mat_cam2 or matrix.new()

	matrix.identity(mat_cam1)
	matrix.rotate_X(mat_cam2, mat_cam1, cam_rot_x)
	matrix.rotate_Y(mat_cam1, mat_cam2, cam_rot_y)
	matrix.translate_in_place(mat_cam1, -cam_pos_x, -cam_pos_y, -cam_pos_z)

	matrix.invert(mat_cam2, mat_cam1);

	-- SCENE
	if screen_scale == 1 then
		fbo.target_set(nil)
	else
		fbo.target_set(fbo_scene)
	end

	shader.use(shader_tracer)
	shader.uniform_f(shader.uniform_location_get(shader_tracer, "time"), sec_current)
	shader.uniform_matrix_4f(shader.uniform_location_get(shader_tracer, "in_cam_inverse"), mat_cam2)
	--shader.uniform_i(shader.uniform_location_get(shader_tracer, "tex_map"), 0)
	--[[
	shader.uniform_i(shader.uniform_location_get(shader_tracer, "bound_min")
		, (MAX_LX-map_lx)//2-1
		, 0-1
		, (MAX_LZ-map_lz)//2-1
		)
	shader.uniform_i(shader.uniform_location_get(shader_tracer, "bound_max")
		, (MAX_LX+map_lx)//2+1
		, map_ly+1
		, (MAX_LZ+map_lz)//2+1
		)
	]]
	--texture.unit_set(0, "2", tex_map)
	--[[
	shader.uniform_iv(shader.uniform_location_get(shader_tracer,
		"map_splits"), #map_splits // 4, 4, map_splits)
	shader.uniform_fv(shader.uniform_location_get(shader_tracer,
		"map_norms"), #map_norms // 4, 4, map_norms)
	]]
	shader.uniform_i(shader.uniform_location_get(shader_tracer,
		"map_root"), map_root)
	shader.uniform_i(shader.uniform_location_get(shader_tracer, "tex_map_norms"), 0)
	shader.uniform_i(shader.uniform_location_get(shader_tracer, "tex_map_splits"), 1)
	texture.unit_set(0, "1", tex_map_norms)
	texture.unit_set(1, "2", tex_map_splits)
	draw.viewport_set(0, 0, screen_w//screen_scale, screen_h//screen_scale)
	draw.blit()

	-- BLIT
	if screen_scale ~= 1 then
		fbo.target_set(nil)
		shader.use(shader_blit1)
		shader.uniform_i(shader.uniform_location_get(shader_blit1, "tex0"), 0)
		texture.unit_set(0, "2", tex_screen)
		draw.viewport_set(0, 0, screen_w, screen_h)
		draw.blit()
	end
end

function hook_tick(sec_current, sec_delta)
	if loading then return end

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

	--local mvspeedef = mvspeed*(1.0 - math.exp(-sec_delta*0.1));
	--local mvspeedef = mvspeed*(1.0 - math.exp(-sec_delta*0.9));
	local mvspeedef = 1.0
	cam_vel_x = cam_vel_x + (hx*ldh + fx*ldw + vx*ldv - cam_vel_x)*mvspeedef
	cam_vel_y = cam_vel_y + (hy*ldh + fy*ldw + vy*ldv - cam_vel_y)*mvspeedef
	cam_vel_z = cam_vel_z + (hz*ldh + fz*ldw + vz*ldv - cam_vel_z)*mvspeedef

	cam_pos_x = cam_pos_x + cam_vel_x
	cam_pos_y = cam_pos_y + cam_vel_y
	cam_pos_z = cam_pos_z + cam_vel_z
end

--[[
local size = 1024
tex_noise = texture.new("2", 1, "1f", size, size, "ll", "1f")
do
	local x, y
	local l = {}
	for y=0,size-1 do
	for x=0,size-1 do
		l[1+x+y*size] = 0.0
	end
	end

	l[1+0] = math.random()
	local i
	local step = size
	local amp = 1.0
	while true do
		local hstep = step//2
		if hstep < 1 then break end

		for y=hstep,size-1,step do
		for x=hstep,size-1,step do
			local x0 = (x - hstep) % size
			local y0 = (y - hstep) % size
			local x1 = (x + hstep) % size
			local y1 = (y + hstep) % size

			l[1+x+y0*size] = (l[1+x0+y0*size] + l[1+x1+y0*size])/2.0
			l[1+x0+y*size] = (l[1+x0+y0*size] + l[1+x0+y1*size])/2.0
			l[1+x+y1*size] = (l[1+x0+y1*size] + l[1+x1+y1*size])/2.0
			l[1+x1+y*size] = (l[1+x1+y0*size] + l[1+x1+y1*size])/2.0

			l[1+x+y*size] = ((math.random()*2.0-1.0)*amp
				+ (l[1+x+y0*size]
				+ l[1+x+y1*size]
				+ l[1+x0+y*size]
				+ l[1+x1+y*size])/4.0)
		end
		end

		step = hstep
		amp = amp * 0.5
	end

	texture.load_sub(tex_noise, "2", 0, 0, 0, size, size, "1f", l)
end
]]

function load_stuff()
	if VOXYCODONE_GL_COMPAT_PROFILE then
		error("too much effort for compat profile right now!")
	end

	shader_tracer = loadfile("shader.lua")()
	assert(shader_tracer)

	-- map
	mdata = bin_load("dat/"..MAP_NAME..".bsp")
	coroutine.yield()
	bsp_version = string.unpack("< i4", mdata:sub(1,4))
	print("BSP VERSION:", bsp_version)
	assert(bsp_version == 29)
	print("getting dirs")

	local dirs = {}
	map_dirs = dirs
	local DIRNAMES = {
		"entities", "planes", "miptex", "vertices", "visilist",
		"nodes", "texinfo", "faces", "lightmaps", "clipnodes",
		"leaves", "lface", "edges", "ledges", "models",
	}
	local k, v
	for k, v in ipairs(DIRNAMES) do
		local cpos, clen = string.unpack("< i4 i4", mdata:sub((k-1)*8+4+1, (k-1)*8+4+8))
		local cdata = mdata:sub(cpos+1, cpos+clen)
		local d = cdata
		print(k, v, #cdata, clen - #cdata)

		coroutine.yield()

		if v == "leafs" then
			assert((clen % 24) == 0)
			local i
			local rlen = clen//24
			d = {}
			for i=0,rlen-1 do
				local plane_id, front, back, bx1, by1, bz1, bx2, by2, bz2,
						face_id, face_num = 
					string.unpack("< i4 i2 i2 i2 i2 i2 i2 i2 i2 I2 I2",
						cdata:sub(i*24+1, (i+1)*24))
				d[i+1] = {
					plane_id = plane_id,
					front = front,
					back = back,
					bx1 = bx1,
					by1 = by1,
					bz1 = bz1,
					bx2 = bx2,
					by2 = by2,
					bz2 = bz2,
					face_id = face_id,
					face_num = face_num,
				}
			end

		elseif v == "models" then
			assert((clen % 64) == 0)
			local i
			local rlen = clen//64
			d = {}
			for i=0,rlen-1 do
				local bx1, by1, bz1, bx2, by2, bz2,
					ox, oy, oz,
					node_id0,
					node_id1,
					node_id2,
					node_id3,
					numleafs, face_id, face_num =
					string.unpack("< f f f f f f f f f i4 i4 i4 i4 i4 i4 i4",
						cdata:sub(i*64+1, (i+1)*64))
				d[i+1] = {
					bx1 = bx1,
					by1 = by1,
					bz1 = bz1,
					bx2 = bx2,
					by2 = by2,
					bz2 = bz2,
					ox = ox,
					oy = oy,
					oz = oz,
					node_id0 = node_id0,
					node_id1 = node_id1,
					node_id2 = node_id2,
					node_id3 = node_id3,
					numleafs = numleafs,
					face_id = face_id,
					face_num = face_num,
				}

				--print(i, numleafs)
			end

		elseif v == "nodes" then
			assert((clen % 24) == 0)
			local i
			local rlen = clen//24
			d = {}
			for i=0,rlen-1 do
				local plane_id, front, back, bx1, by1, bz1, bx2, by2, bz2,
						face_id, face_num = 
					string.unpack("< i4 i2 i2 i2 i2 i2 i2 i2 i2 I2 I2",
						cdata:sub(i*24+1, (i+1)*24))
				d[i+1] = {
					plane_id = plane_id,
					front = front,
					back = back,
					bx1 = bx1,
					by1 = by1,
					bz1 = bz1,
					bx2 = bx2,
					by2 = by2,
					bz2 = bz2,
					face_id = face_id,
					face_num = face_num,
				}
			end

		elseif v == "planes" then
			assert((clen % 20) == 0)
			local i
			local rlen = clen//20
			d = {}
			for i=0,rlen-1 do
				local x, y, z, ofs, typ = string.unpack("< f f f f i4",
						cdata:sub(i*20+1, (i+1)*20))
				d[i+1] = { x, y, z, ofs, typ } -- probably won't use typ
			end

		elseif v == "vertices" then
			assert((clen % 12) == 0)
			local i
			local rlen = clen//12
			d = {}
			for i=0,rlen-1 do
				local x, y, z = string.unpack("< f f f",
						cdata:sub(i*12+1, (i+1)*12))
				d[i+1] = { x, y, z, }
			end

		elseif v == "clipnodes" then
			assert((clen % 8) == 0)
			local i
			local rlen = clen//8
			d = {}
			for i=0,rlen-1 do
				local planenum, front, back = string.unpack("< I4 i2 i2",
						cdata:sub(i*8+1, (i+1)*8))
				d[i+1] = {
					planenum = planenum,
					front = front,
					back = back,
				}
			end
		end

		dirs[v] = d
	end

	-- set up map info
	map_norms = {}
	map_splits = {}
	map_root = map_dirs.models[1].node_id1
	local i
	for i=0,#map_dirs.planes-1 do
		local l = map_dirs.planes[i+1]
		map_norms[4*i+1] = l[1]
		map_norms[4*i+2] = l[3]
		map_norms[4*i+3] = -l[2]
		map_norms[4*i+4] = l[4] / 32.0
		--print(l[1], l[2], l[3], l[4])
	end

	-- clipnodes?
	if MAP_USE_REAL_NODES then
		-- TODO!
		for i=0,#map_dirs.clipnodes-1 do
			local l = map_dirs.clipnodes[i+1]
			local l2 = map_dirs.planes[l.planenum+1]
			map_splits[4*i+1] = l.planenum
			map_splits[4*i+2] = l.front
			map_splits[4*i+3] = l.back
			map_splits[4*i+4] = -1
		end
	else
		for i=0,#map_dirs.clipnodes-1 do
			local l = map_dirs.clipnodes[i+1]
			local l2 = map_dirs.planes[l.planenum+1]
			map_splits[4*i+1] = l.planenum
			map_splits[4*i+2] = l.front
			map_splits[4*i+3] = l.back
			map_splits[4*i+4] = -1
		end
	end

	-- PAD
	while (#map_splits % (MAP_SPLIT_W*4)) ~= 0 do
		map_splits[#map_splits+1] = 0
	end
	print("S", #map_splits // 4, #map_norms // 4)

	misc.gl_error()
	tex_map_norms = texture.new("1", 1, "4f", #map_norms//4, "nn", "4f")
	tex_map_splits = texture.new("2", 1, "4s", MAP_SPLIT_W, #map_splits//(4*MAP_SPLIT_W), "nn", "4s")
	texture.load_sub(tex_map_norms, "1", 0, 0, #map_norms//4, "4f", map_norms)
	texture.load_sub(tex_map_splits, "2", 0, 0, 0,
		MAP_SPLIT_W, #map_splits//(4*MAP_SPLIT_W), "4s", map_splits)
	print("TEX ERRS:", misc.gl_error())

	tex_screen = texture.new("2", 1, "4nb", screen_w//screen_scale, screen_h//screen_scale, "ll", "4nb")
	coroutine.yield()
	fbo_scene = fbo.new()
	fbo.bind_tex(fbo_scene, 0, "2", tex_screen, 0)
	assert(fbo.validate(fbo_scene))

	--tex_map = texture.new("3", MAX_LAYER+1, "4ub", MAX_LX, MAX_LY, MAX_LZ, "nnn", "4ub")

	print("Done!")
	print("no error happened!")
	return nil
end

loading = coroutine.create(load_stuff)

function hook_poll()
	local k, v
	for k, v in ipairs(sandbox.mbox) do
		if v[2] == "hook_tick" then hook_tick(v[3], v[4])
		elseif v[2] == "hook_render" then hook_render(v[3])
		elseif v[2] == "hook_key" then hook_key(v[3], v[4])
		elseif v[2] == "hook_mouse_button" then hook_mouse_button(v[3], v[4])
		elseif v[2] == "hook_mouse_motion" then hook_mouse_motion(v[3], v[4], v[5], v[6])
		else print("UNHANDLED MESSAGE TYPE", v[2])
		end
	end

	sandbox.mbox = {}

	if loading then
		if loading ~= "load_forever" then
			local res, msg = coroutine.resume(loading)
			if (not res) or coroutine.status(loading) == "dead" then
				if (not res) and msg then error(msg) end
				loading = nil
				--loading = "load_forever"
			end
		end
	end
end

if VOXYCODONE_GL_COMPAT_PROFILE then
	shader_blit1 = shader.new({
	vert = [=[
	#version 120
	attribute vec2 in_vertex;
	varying vec2 tc;

	void main()
	{
		gl_Position = vec4(in_vertex, 0.1, 1.0);
		tc = in_vertex*0.5+0.5;
	}
	]=],
	frag = [=[
	#version 120

	varying vec2 tc;
	uniform sampler2D tex0;

	void main()
	{
		gl_FragColor = texture2D(tex0, tc);
	}
	]=],
	}, {"in_vertex"}, {"out_color"})
else
	shader_blit1 = shader.new({
	vert = [=[
	#version 130
	in vec2 in_vertex;
	out vec2 tc;

	void main()
	{
		gl_Position = vec4(in_vertex, 0.1, 1.0);
		tc = in_vertex*0.5+0.5;
	}
	]=],
	frag = [=[
	#version 130

	in vec2 tc;
	out vec4 out_color;
	uniform sampler2D tex0;

	void main()
	{
		out_color = texture(tex0, tc, 0);
	}
	]=],
	}, {"in_vertex"}, {"out_color"})

	shader_loading = shader.new({
	vert = [=[
	#version 130
	in vec2 in_vertex;
	out vec2 tc;

	void main()
	{
		gl_Position = vec4(in_vertex, 0.1, 1.0);
		tc = in_vertex*0.5+0.5;
	}
	]=],
	frag = [=[
	#version 130

	in vec2 tc;
	out vec4 out_color;
	uniform float time;
	uniform sampler2D tex0;

	void main()
	{
		vec2 ltc = tc - 0.5;
		ltc.x *= 1280.0/720.0;
		out_color.a = 0.0;

		float rang = time*1.4;
		ltc = cos(rang)*ltc + sin(rang)*vec2(-ltc.y, ltc.x);
		ltc *= 0.8 + (-sin(time*1.3)*0.5+0.5)*1.8;
		ltc += time*vec2(2.0, 1.0)*0.3;

		ltc += 0.5;
		//if(min(ltc.x, ltc.y) >= 0.0 && max(ltc.x, ltc.y) < 1.0)
			out_color = texture(tex0, ltc, 0);

		if(out_color.a < 1.0)
			out_color = vec4(
				sin(tc.x*5.0+time),
				sin(tc.y*5.0-time),
				sin(tc.x*3.0-tc.y*3.0+time*0.5),
				1.0);
	}
	]=],
	}, {"in_vertex"}, {"out_color"})

	assert(shader_loading)
end

assert(shader_blit1)

do
	local data = bin_load("dat/loading.tga")
	local x, i
	local l = {}
	for x=0,(512*512*4)-1,4 do
		i = 18 + x
		l[1 + x] = data:byte(i+3)
		l[2 + x] = data:byte(i+2)
		l[3 + x] = data:byte(i+1)
		l[4 + x] = data:byte(i+4)
	end

	tex_loading = texture.new("2", 1, "4nb", 512, 512, "nn", "4nb")
	texture.load_sub(tex_loading, "2", 0, 0, 0, 512, 512, "4nb", l)
end

