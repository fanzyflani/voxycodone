screen_w, screen_h = draw.screen_size_get()
screen_scale = 1

-- table sourced from here: http://www.unicode.org/Public/MAPPINGS/VENDORS/MICSFT/PC/CP437.TXT
-- also had to pinch some stuff from wikipedia (fix your political shit and i might donate again)
CP437_TO_UNI = {
	0x263A, 0x263B, 0x2665, 0x2666, 0x2663, 0x2660, 0x2022,
	0x25D8, 0x25CB, 0x25D9, 0x2642, 0x2640, 0x266A, 0x266B, 0x263C,
	0x25BA, 0x25C4, 0x2195, 0x203C, 0x00B6, 0x00A7, 0x25AC, 0x21A8,
	0x2191, 0x2193, 0x2192, 0x2190, 0x221F, 0x2194, 0x25B2, 0x25BC,
	0x0020, 0x0021, 0x0022, 0x0023, 0x0024, 0x0025, 0x0026, 0x0027,
	0x0028, 0x0029, 0x002a, 0x002b, 0x002c, 0x002d, 0x002e, 0x002f,
	0x0030, 0x0031, 0x0032, 0x0033, 0x0034, 0x0035, 0x0036, 0x0037,
	0x0038, 0x0039, 0x003a, 0x003b, 0x003c, 0x003d, 0x003e, 0x003f,
	0x0040, 0x0041, 0x0042, 0x0043, 0x0044, 0x0045, 0x0046, 0x0047,
	0x0048, 0x0049, 0x004a, 0x004b, 0x004c, 0x004d, 0x004e, 0x004f,
	0x0050, 0x0051, 0x0052, 0x0053, 0x0054, 0x0055, 0x0056, 0x0057,
	0x0058, 0x0059, 0x005a, 0x005b, 0x005c, 0x005d, 0x005e, 0x005f,
	0x0060, 0x0061, 0x0062, 0x0063, 0x0064, 0x0065, 0x0066, 0x0067,
	0x0068, 0x0069, 0x006a, 0x006b, 0x006c, 0x006d, 0x006e, 0x006f,
	0x0070, 0x0071, 0x0072, 0x0073, 0x0074, 0x0075, 0x0076, 0x0077,
	0x0078, 0x0079, 0x007a, 0x007b, 0x007c, 0x007d, 0x007e, 0x007f,
	0x00c7, 0x00fc, 0x00e9, 0x00e2, 0x00e4, 0x00e0, 0x00e5, 0x00e7,
	0x00ea, 0x00eb, 0x00e8, 0x00ef, 0x00ee, 0x00ec, 0x00c4, 0x00c5,
	0x00c9, 0x00e6, 0x00c6, 0x00f4, 0x00f6, 0x00f2, 0x00fb, 0x00f9,
	0x00ff, 0x00d6, 0x00dc, 0x00a2, 0x00a3, 0x00a5, 0x20a7, 0x0192,
	0x00e1, 0x00ed, 0x00f3, 0x00fa, 0x00f1, 0x00d1, 0x00aa, 0x00ba,
	0x00bf, 0x2310, 0x00ac, 0x00bd, 0x00bc, 0x00a1, 0x00ab, 0x00bb,
	0x2591, 0x2592, 0x2593, 0x2502, 0x2524, 0x2561, 0x2562, 0x2556,
	0x2555, 0x2563, 0x2551, 0x2557, 0x255d, 0x255c, 0x255b, 0x2510,
	0x2514, 0x2534, 0x252c, 0x251c, 0x2500, 0x253c, 0x255e, 0x255f,
	0x255a, 0x2554, 0x2569, 0x2566, 0x2560, 0x2550, 0x256c, 0x2567,
	0x2568, 0x2564, 0x2565, 0x2559, 0x2558, 0x2552, 0x2553, 0x256b,
	0x256a, 0x2518, 0x250c, 0x2588, 0x2584, 0x258c, 0x2590, 0x2580,
	0x03b1, 0x00df, 0x0393, 0x03c0, 0x03a3, 0x03c3, 0x00b5, 0x03c4,
	0x03a6, 0x0398, 0x03a9, 0x03b4, 0x221e, 0x03c6, 0x03b5, 0x2229,
	0x2261, 0x00b1, 0x2265, 0x2264, 0x2320, 0x2321, 0x00f7, 0x2248,
	0x00b0, 0x2219, 0x00b7, 0x221a, 0x207f, 0x00b2, 0x25a0, 0x00a0,
	[0]=0x0000,
}

UNI_TO_CP437 = {}
do
	local i
	for i=0,255 do
		UNI_TO_CP437[CP437_TO_UNI[i]] = i
	end
end

dofile("gpu.lua")

--[[
default 16-colour palette when not using the greyscale slide:

	0xFFFFFF,0xFFCC33,0xCC66CC,0x6699FF,
	0xFFFF33,0x33CC33,0xFF6699,0x333333,
	0xCCCCCC,0x336699,0x9933CC,0x333399,
	0x663300,0x336600,0xFF3333,0x000000,

(thanks gamax92)
]]

virtual_w = 160
virtual_h = 50
gpu_res_w, gpu_res_h = 160, 50
--gpu_res_w, gpu_res_h = 80, 25

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
	shader.uniform_matrix_4f(shader.uniform_location_get(shader_tracer, "in_cam_inverse"), mat_cam2)
	shader.uniform_ui(shader.uniform_location_get(shader_tracer, "virtual_screen_size")
		, gpu_res_w, gpu_res_h)

	shader.uniform_i(shader.uniform_location_get(shader_tracer, "tex_font"), 0)
	shader.uniform_i(shader.uniform_location_get(shader_tracer, "tex_chars"), 1)
	shader.uniform_i(shader.uniform_location_get(shader_tracer, "tex_palette"), 2)
	texture.unit_set(0, "2a", tex_font)
	texture.unit_set(1, "2", tex_chars)
	texture.unit_set(2, "1", tex_palette)

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

	if demo_co then
		local res, msg = coroutine.resume(demo_co, sec_current, sec_delta)
		if (not res) or coroutine.status(demo_co) == "dead" then
			if (not res) and msg then error(">"..msg) end
			demo_co = nil
			print("*** DEMO ENDED ***")
		end
	end

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
	if VOXYCODONE_GL_COMPAT_PROFILE then
		error("too much effort for compat profile right now!")
	end

	shader_tracer = loadfile("shader.lua")()
	assert(shader_tracer)

	misc.gl_error()
	local font = {}
	do
		local fstr = bin_load("rawcga.bin")

		local x,y,z,i,j

		i = 1
		j = 1
		for z=0,256-1 do
		for y=0,8-1 do
			local v = fstr:sub(j,j):byte()
			j = j + 1
			for x=0,8-1 do
				if ((v<<x)&128) == 0 then
					font[i] = 0
				else
					font[i] = 255
				end
				i = i + 1
			end
		end
		end
	end
	tex_font = texture.new("2a", 1, "1nb", 8, 8, 256, "nn", "1nb")
	texture.load_sub(tex_font, "2a", 0, 0, 0, 0, 8, 8, 256, "1nb", font)

	do
		local i
		virtual_data = {}
		for i=0,virtual_w*virtual_h-1 do
			virtual_data[3*i+1] = 0x20
			virtual_data[3*i+2] = 0x0F
			virtual_data[3*i+3] = 0x00
		end
	end
	tex_chars = texture.new("2", 1, "3ub", virtual_w, virtual_h, "nn", "3ub")
	texture.load_sub(tex_chars, "2", 0, 0, 0, virtual_w, virtual_h, "3ub", virtual_data)

	do
		local i
		virtual_palette = {}
		for i=0,16-1 do
			virtual_palette[3*i+1] = i*255//15
			virtual_palette[3*i+2] = i*255//15
			virtual_palette[3*i+3] = i*255//15
		end

		i = 16
		for i=16,256-1 do
			-- FIXME: need to confirm palette order
			local b = ((i-16)%5)
			local g = ((i-16)//5)%8
			local r = ((i-16)//5)//8
			virtual_palette[3*i+1] = (r*255+3)//6
			virtual_palette[3*i+2] = (g*255+4)//8
			virtual_palette[3*i+3] = (b*255+2)//5
		end
	end
	tex_palette = texture.new("1", 1, "3nb", 256, "nn", "3nb")
	texture.load_sub(tex_palette, "1", 0, 0, 256, "3nb", virtual_palette)

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

demo_fn = loadfile("demo.lua")
demo_co = coroutine.create(demo_fn)

