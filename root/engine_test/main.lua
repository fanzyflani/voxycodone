screen_scale = 2

dofile("emul.lua")

require("util")
require("voxel")
require("scene/voxygen")

cur_scene_idx = #SCENE_LIST
cur_scene = SCENE_LIST[cur_scene_idx]

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
cam_vel_x = 0.0
cam_vel_y = 0.0
cam_vel_z = 0.0

function hook_key(key, state)
	if key == SDLK_ESCAPE and not state then
		if record_fp then
			record_fp:write("}\n")
			record_fp:close()
		end

		misc.exit()
	elseif key == SDLK_w then key_pos_dzp = state
	elseif key == SDLK_s then key_pos_dzn = state
	elseif key == SDLK_a then key_pos_dxn = state
	elseif key == SDLK_d then key_pos_dxp = state
	elseif key == SDLK_LCTRL then key_pos_dyn = state
	elseif key == SDLK_SPACE then key_pos_dyp = state
	elseif key == SDLK_0 and state then render_sec_first_current = render_sec_last_current
	elseif key == SDLK_1 and state then
		cur_scene_idx = cur_scene_idx - 1
		if cur_scene_idx < 1 then cur_scene_idx = #SCENE_LIST end
		cur_scene = SCENE_LIST[cur_scene_idx]
	elseif key == SDLK_2 and state then
		cur_scene_idx = cur_scene_idx + 1
		if cur_scene_idx > #SCENE_LIST then cur_scene_idx = 1 end
		cur_scene = SCENE_LIST[cur_scene_idx]
	end
end

function hook_mouse_button(button, state)
	if button == 1 and not state then
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
	if not mouse_locked then return end

	cam_rot_y = cam_rot_y - dx*math.pi/1000.0
	cam_rot_x = cam_rot_x + dy*math.pi/1000.0
	local clamp = math.pi/2.0-0.0001
	if cam_rot_x < -clamp then cam_rot_x = -clamp end
	if cam_rot_x >  clamp then cam_rot_x =  clamp end
end

function init_gfx()
	local x, y, i, j

	screen_w, screen_h = draw.screen_size_get()
	print("Screen size:", screen_w, screen_h)

	-- Initial texstorage
	LIGHT_MAX = 32

	misc.gl_error()
	tex_ray_vox = texture.new("3", 1, "1ub", 512, 512, 256, "nn", "1ub")
	print(misc.gl_error())

	-- Random noise
	local rand_noise = {{}, {}}
	for i = 1,128*128*4 do
		rand_noise[1][i] = math.random()
	end

	tex_ray_rand = texture.new("2", 8, "4f", 128, 128, "ll", "4f")
	texture.unit_set(0, "2", tex_ray_rand)
	texture.load_sub(tex_ray_rand, "2", 0, 0, 0, 128, 128, "4f", rand_noise[1])

	for j=1,8-1 do
		rand_noise[(j&1)+1] = {}
		for x=0,(128>>j)-1 do
		for y=0,(128>>j)-1 do
		for i=0,3 do
			rand_noise[(j&1)+1][((128>>j)*y + x)*4 + i + 1]
				= (0.0
				+ rand_noise[((j-1)&1)+1][((128>>(j-1))*(2*y+0) + (2*x+0))*4 + i + 1]
				+ rand_noise[((j-1)&1)+1][((128>>(j-1))*(2*y+0) + (2*x+1))*4 + i + 1]
				+ rand_noise[((j-1)&1)+1][((128>>(j-1))*(2*y+1) + (2*x+0))*4 + i + 1]
				+ rand_noise[((j-1)&1)+1][((128>>(j-1))*(2*y+1) + (2*x+1))*4 + i + 1])
					/ 4.0;

		end
		end
		end

		texture.load_sub(tex_ray_rand, "2", j, 0, 0, 128>>j, 128>>j, "4f", rand_noise[(j&1)+1])
	end

	print("tex_rand", misc.gl_error());

	-- FBO
	tex_fbo0_0 = texture.new("2", 1, "4nb", screen_w/screen_scale, screen_h/screen_scale, "ll", "4nb")
	print(misc.gl_error())
	tex_fbo0_1 = texture.new("2", 1, "4nb", screen_w/screen_scale, screen_h/screen_scale, "nn", "4nb")
	print(misc.gl_error())

	fbo0 = fbo.new()
	print(misc.gl_error())
	fbo.bind_tex(fbo0, 0, "2", tex_fbo0_0, 0)
	fbo.bind_tex(fbo0, 1, "2", tex_fbo0_1, 0)
	assert(fbo.validate(fbo0))
	fbo.target_set(nil)
	print("FBO", misc.gl_error())

	-- Shader
	local vert = glslpp_parse(bin_load("glsl/post_radblur.vert"))
	local frag = glslpp_parse(bin_load("glsl/post_radblur.frag"))
	shader_blur = shader.new({
		vert=vert,
		frag=frag,
	}, {"in_vertex"}, {"out_frag_color", "out_frag_color_gi"})
	print("shader_blur", misc.gl_error())

	shader_ray = {}

	local k, v
	for k, v in pairs(SCENE) do
		local vert = glslpp_parse(bin_load("glsl/shader_ray.vert"))
		local frag = glslpp_parse(v.frag)
		shader_ray[k] = shader.new({
			vert=vert,
			frag=frag,
		}, {"in_vertex"}, {"out_frag_color", "out_frag_color_gi"})
		print("shader_ray", k, misc.gl_error())
	end

	-- Voxel landscape
	-- THIS IS SLOW
	voxdata_load_repeated_chunk("dat/voxel1.voxygen")
end

render_sec_first_current = 0
render_sec_last_current = nil
render_sec_delta = nil
function hook_render(sec_current)
	local x, y, z, i, j

	if render_sec_delta then
		render_sec_delta = sec_current - render_sec_last_current
	else
		render_sec_delta = 0.00001 -- just in case
	end

	render_sec_last_current = sec_current

	mat_cam1 = mat_cam1 or matrix.new()
	mat_cam2 = mat_cam2 or matrix.new()

	matrix.identity(mat_cam1)
	matrix.rotate_X(mat_cam2, mat_cam1, cam_rot_x)
	matrix.rotate_Y(mat_cam1, mat_cam2, cam_rot_y)
	matrix.translate_in_place(mat_cam1, -cam_pos_x, -cam_pos_y, -cam_pos_z)

	sph_count=0

	misc.gl_error()
	fbo.target_set(fbo0)
	S.USE(shader_ray[cur_scene])

	if SCENE[cur_scene].update then
		SCENE[cur_scene].update(sec_current - render_sec_first_current, render_sec_delta)
	end

	if record_fp then
		record_fp:write(
		string.format("{%.5f, %.5f,%.5f,%.5f,%.5f,%.5f, %.5f,%.5f,%.5f},\n"
			, sec_current - render_sec_first_current
			, cam_pos_x
			, cam_pos_y
			, cam_pos_z
			, cam_rot_x
			, cam_rot_y
			, light_pos_x or cam_pos_x
			, light_pos_y or cam_pos_y
			, light_pos_z or cam_pos_z
		))
	end

	texture.unit_set(0, "2", tex_ray_rand)
	texture.unit_set(1, "3", tex_ray_vox)

	matrix.invert(mat_cam2, mat_cam1);
	shader.uniform_matrix_4f(S.in_cam_inverse, mat_cam2)
	shader.uniform_f(S.in_aspect, 720.0/1280.0, 1.0);

	shader.uniform_i(S.tex_rand, 0);
	shader.uniform_i(S.tex_vox, 1);
	shader.uniform_i(S.sph_count, sph_count);
	shader.uniform_f(S.sec_current, sec_current);

	local lcol = {}
	local lpos = {}
	local ldir = {}
	local lcos = {}
	local lpow = {}

	local light_count = 1

	lcol[1 + 0*3 + 0] = 1.0
	lcol[1 + 0*3 + 1] = 1.0
	lcol[1 + 0*3 + 2] = 1.0
	lpos[1 + 0*3 + 0] = light_pos_x or cam_pos_x
	lpos[1 + 0*3 + 1] = light_pos_y or cam_pos_y
	lpos[1 + 0*3 + 2] = light_pos_z or cam_pos_z
	ldir[1 + 0*3 + 0] = light_dir_x or -math.cos(cam_rot_x)*math.sin(cam_rot_y)
	ldir[1 + 0*3 + 1] = light_dir_y or -math.sin(cam_rot_x)
	ldir[1 + 0*3 + 2] = light_dir_z or -math.cos(cam_rot_x)*math.cos(cam_rot_y)
	lcos[1] = 1.0 - 0.7
	lpow[1] = 1.0/4.0

	local light_amb = 0.1;

	shader.uniform_ui(S.light_count, light_count);
	shader.uniform_f(S.light_amb, light_amb);
	shader.uniform_fv(S.light_col, light_count, 3, lcol);
	shader.uniform_fv(S.light_pos, light_count, 3, lpos);
	shader.uniform_fv(S.light_dir, light_count, 3, ldir);
	shader.uniform_fv(S.light_cos, light_count, 1, lcos);
	shader.uniform_fv(S.light_pow, light_count, 1, lpow);

	shader.uniform_f(S.bmin, bmin_x, bmin_y, bmin_z);
	shader.uniform_f(S.bmax, bmax_x, bmax_y, bmax_z);

	draw.buffers_set({0, 1})
	draw.viewport_set(0, 0, screen_w/screen_scale, screen_h/screen_scale)
	draw.blit()

	--draw.buffer_set_front()
	draw.buffers_set({0})
	fbo.target_set(nil)
	draw.viewport_set(0, 0, screen_w, screen_h)
	texture.unit_set(1, "2", tex_fbo0_1)
	texture.unit_set(0, "2", tex_fbo0_0)
	S.USE(shader_blur)

	shader.uniform_i(S.tex0, 0);
	shader.uniform_i(S.tex1, 1);

	draw.blit()

	S.USE(nil)
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

init_gfx()

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
end

