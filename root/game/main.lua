screen_w, screen_h = draw.screen_size_get()
screen_scale = 2

-- from SDL_keycode.h
SDLK_RETURN = 13
SDLK_ESCAPE = 27
SDLK_SPACE = 32
SDLK_w = ("w"):byte()
SDLK_s = ("s"):byte()
SDLK_a = ("a"):byte()
SDLK_d = ("d"):byte()
SDLK_0 = ("0"):byte()
SDLK_1 = ("1"):byte()
SDLK_2 = ("2"):byte()
SDLK_RIGHT = (1<<30)+79
SDLK_LEFT = (1<<30)+80
SDLK_DOWN = (1<<30)+81
SDLK_UP = (1<<30)+82
SDLK_LCTRL = (1<<30)+224

cam_rot_x = 0.0
cam_rot_y = math.pi
cam_pos_x = 0.0
cam_pos_y = 16.0
cam_pos_z = -10.0
cam_vel_x = 0.0
cam_vel_y = 0.0
cam_vel_z = 0.0

loading = nil

function mapgen_point(x, y, z)
	--return (math.random() < 0.02 and 0)
	--return ((y&32)~=0 and 0)
	return math.sin(x*math.pi/16.0)*math.sin(z*math.pi/16.0) + math.cos(y*math.pi/16.0)>=0.0
end

function mapgen_area(cx, cy, cz)
	assert(cx >= 0 and cx < 512)
	assert(cy >= 0 and cy < 256)
	assert(cz >= 0 and cz < 512)
	assert((cx&31) == 0)
	assert((cy&31) == 0)
	assert((cz&31) == 0)
	print(cx, cy, cz)
	local data = {{}, {}, {}, {}, {}, {}}

	-- Generate base
	local x,y,z
	for z=0,31 do
	for x=0,31 do
	for y=0,31 do
		data[1][1+y+32*(x+32*z)] = (mapgen_point(cx+x, cy+y, cz+z) and 0) or 1
	end end end

	-- Build miptree upwards
	local i
	local w1 = 32
	local w2 = 16
	for i=1,5 do
		local bx,by,bz
		for bz=0,w2-1 do
		for bx=0,w2-1 do
		for by=0,w2-1 do
			local out = i+1
			local sx,sy,sz
			local offs = 1+by*2+w1*(bx*2+w1*bz*2)
			for sz=0,1 do
			if out == 0 then break end
			for sx=0,1 do
			if out == 0 then break end
			for sy=0,1 do
				--if data[i][1+(by*2+sy)+w1*((bx*2+sx)+w1*(bz*2+sz))] == 0 then
				if data[i][offs+sy+w1*(sx+w1*sz)] == 0 then
					out = 0
					break
				end
			end end end

			data[i+1][1+by+w2*(bx+w2*bz)] = out
		end end end

		w1 = w1>>1
		w2 = w2>>1
	end

	-- Build miptree downwards
	w2 = 1
	w1 = 2
	for i=5,1,-1 do
		for bz=0,w2-1 do
		for bx=0,w2-1 do
		for by=0,w2-1 do
			local ov = data[i+1][1+by+w2*(bx+w2*bz)]
			--assert(ov)
			if ov ~= 0 then
				local sx,sy,sz
				local offs = 1+by*2+w1*(bx*2+w1*bz*2)
				for sz=0,1 do
				for sx=0,1 do
				for sy=0,1 do
					--assert(data[i][offs+sy+w1*(sx+w1*sz)])
					--assert(data[i][offs+sy+w1*(sx+w1*sz)] ~= 0)
					data[i][offs+sy+w1*(sx+w1*sz)] = ov
				end end end
			end
		end end end
		w2 = w2<<1
		w1 = w1<<1
	end

	-- Write to texture
	misc.gl_error()
	for i=0,5 do
		texture.load_sub(tex_geom, "3", i,
			cy>>i, cx>>i, cz>>i,
			32>>i, 32>>i, 32>>i,
			"1ub", data[i+1])
		print(misc.gl_error())
	end
end

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
		-- middle
	elseif button == 3 and state then
		-- right
		local px, py, pz = cam_pos_x, cam_pos_y, cam_pos_z
		px = px + 256.5
		pz = pz + 256.5
		py = py + 192.5
		py = 256.0-py

		local ix = math.tointeger(math.floor(px/2.0))
		local iy = math.tointeger(math.floor(py/2.0))
		local iz = math.tointeger(math.floor(pz/2.0))

		print(ix, iy, iz)

		if ix >= 0 and iy >= 0 and iz >= 0 then
		if ix < 256 and iy < 128 and iz < 256 then
			local data = {py, px, pz, 1.0}
			map_light_data[1+iy+128*(ix+256*iz)] = data
			texture.load_sub(tex_ltpos, "3", 0,
				iy, ix, iz,
				1, 1, 1,
				"4f", data)
			texture.gen_mipmaps(tex_ltpos, "3")
		end
		end
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

fps_tick = nil
fps_count = 0
function hook_render(sec_current)
	if loading then return end
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
	shader.uniform_matrix_4f(shader.uniform_location_get(shader_tracer, "in_cam_inverse"), mat_cam2)
	shader.uniform_f(shader.uniform_location_get(shader_tracer, "cam_pos"), cam_pos_x, cam_pos_y, cam_pos_z)
	shader.uniform_i(shader.uniform_location_get(shader_tracer, "tex_geom"), 0)
	shader.uniform_i(shader.uniform_location_get(shader_tracer, "tex_density"), 1)
	shader.uniform_i(shader.uniform_location_get(shader_tracer, "tex_ltpos"), 2)
	texture.unit_set(0, "3", tex_geom)
	texture.unit_set(1, "3", tex_density)
	texture.unit_set(2, "3", tex_ltpos)
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

function load_stuff()
	-- Shader
	if VOXYCODONE_GL_COMPAT_PROFILE then
		error("too much effort for compat profile right now!")
	end
	shader_tracer = loadfile("shader.lua")()
	assert(shader_tracer)
	coroutine.yield()

	-- Textures
	print(misc.gl_error())
	tex_geom = texture.new("3", 6, "1ub", 256, 512, 512, "nn", "1ub")
	tex_density = texture.new("3", 9, "1ns", 256, 512, 512, "lln", "1us")

	-- this one needs to be smaller
	-- otherwise we chew 1GB of VRAM right off the bat
	tex_ltpos = texture.new("3", 8, "4f", 128, 256, 256, "lln", "4f")

	-- Map data
	map_data_raw = misc.uncompress(bin_load("test.dat"),
		512*512*256 + 256*256*128 + 128*128*64 + 64*64*32 + 32*32*16 + 16*16*8)
	coroutine.yield()

	-- Map texture
	local offs, step, i = 1, 512*512*256
	print(map_data_raw:sub(1,1):byte())
	print(map_data_raw:sub(256,256):byte())
	for i=0,5 do
		print("load", i, step)
		if false then--i==0 then
			texture.load_sub(tex_geom, "3", i,
				0, 0, 0,
				256>>i, 512>>i, 512>>i,
				"1ub", map_data_raw)
		else
			texture.load_sub(tex_geom, "3", i,
				0, 0, 0,
				256>>i, 512>>i, 512>>i,
				"1ub", map_data_raw:sub(offs, offs+step-1))
		end

		offs = offs + step
		step = step >> 3
		--coroutine.yield()
	end
	print(misc.gl_error())
	if voxel.build_density_map then
		voxel.build_density_map(tex_density, 256, 512, 512, map_data_raw)
	else
		map_density = {}
		local j
		local offs = 0
		for j=1,512*512*256 do
			map_density[j] = (map_data_raw:byte(j+offs) == 0 and 0xFFFF) or 0
		end
		texture.load_sub(tex_density, "3", i,
			0, 0, 0,
			256, 512, 512,
			"1ns", map_density)
		map_density = nil
	end
	print("mipgen: density")
	texture.gen_mipmaps(tex_density, "3")
	print("density generated")
	print(misc.gl_error())
	coroutine.yield()

	-- Mapgen
	local i
	for i=1,40 do
		local ix = math.tointeger(math.floor(math.random()*512/32))*32
		local iy = math.tointeger(math.floor(math.random()*256/32))*32
		local iz = math.tointeger(math.floor(math.random()*512/32))*32
		--mapgen_area(ix, iy, iz)
	end

	-- Random lights
	-- TODO: clear texture somehow
	local i
	map_light_data = {}
	for i=1,0 do
		local ix, iy, iz
		local offs = 512*512*256+1
		repeat
			iy = math.tointeger(math.floor(math.random()*128))
			ix = math.tointeger(math.floor(math.random()*256))
			iz = math.tointeger(math.floor(math.random()*256))
		until map_data_raw:byte(offs+iy+128*(ix+256*iz)) ~= 0

		if false then
			iy = 127
			while map_data_raw:byte(offs+iy+256/2*(ix+512/2*iz)) == 0 do
				iy = iy - 1
			end
		elseif true then
			while map_data_raw:byte(offs+iy+1+128*(ix+256*iz)) ~= 0 do
				iy = iy + 1
			end
		end

		print("light", i, ix, iy, iz)
		local dbias = 1.0
		local data = {iy*2+dbias, ix*2+dbias, iz*2+dbias, 1.0}
		map_light_data[1+iy+128*(ix+256*iz)] = data
		texture.load_sub(tex_ltpos, "3", 0,
			iy, ix, iz,
			1, 1, 1,
			"4f", data)
		--mapgen_area(ix, iy, iz)
	end
	print("mipgen: ltpos")
	texture.gen_mipmaps(tex_ltpos, "3")
	print("ltpos generated")

	-- FBO
	tex_screen = texture.new("2", 1, "4nb", screen_w//screen_scale, screen_h//screen_scale, "ll", "4nb")
	fbo_scene = fbo.new()
	fbo.bind_tex(fbo_scene, 0, "2", tex_screen, 0)
	assert(fbo.validate(fbo_scene))

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
				if (not res) and msg then error(">"..msg) end
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
end

assert(shader_blit1)

