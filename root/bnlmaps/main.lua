screen_w, screen_h = draw.screen_size_get()
screen_scale = 1

DEPTHONLY = 3

MAP_NAME = "mountain_express"

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

function hook_key(key, state)
	if key == SDLK_ESCAPE and not state then
		misc.exit()
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

function hook_render(sec_current)
	mat_cam1 = mat_cam1 or matrix.new()
	mat_cam2 = mat_cam2 or matrix.new()

	matrix.identity(mat_cam1)
	matrix.rotate_X(mat_cam2, mat_cam1, cam_rot_x)
	matrix.rotate_Y(mat_cam1, mat_cam2, cam_rot_y)
	matrix.translate_in_place(mat_cam1, -cam_pos_x, -cam_pos_y, -cam_pos_z)

	matrix.invert(mat_cam2, mat_cam1);

	-- DEPTH
	local i
	for i=DEPTHONLY,1,-1 do
		fbo.target_set(fbo_depth[i])
		shader.use(shader_beamer)
		shader.uniform_f(shader.uniform_location_get(shader_beamer, "time"), sec_current)
		shader.uniform_matrix_4f(shader.uniform_location_get(shader_beamer, "in_cam_inverse"), mat_cam2)
		shader.uniform_i(shader.uniform_location_get(shader_beamer, "tex_map"), 0)
		shader.uniform_i(shader.uniform_location_get(shader_beamer, "tex_depth_in"), 1)
		shader.uniform_i(shader.uniform_location_get(shader_beamer, "bound_min")
			, (MAX_LX-map_lx)//2-1
			, 0-1
			, (MAX_LZ-map_lz)//2-1
			)
		shader.uniform_i(shader.uniform_location_get(shader_beamer, "bound_max")
			, (MAX_LX+map_lx)//2+1
			, map_ly+1
			, (MAX_LZ+map_lz)//2+1
			)
		shader.uniform_i(shader.uniform_location_get(shader_beamer, "have_depth_in"), (i < DEPTHONLY and 1) or 0)
		texture.unit_set(0, "3", tex_map)
		texture.unit_set(1, "2", tex_depth[i+1]) -- out of range == nil
		draw.viewport_set(0, 0, (screen_w//screen_scale)>>i, (screen_h//screen_scale)>>i)
		draw.blit()
	end

	-- SCENE
	if screen_scale == 1 then
		fbo.target_set(nil)
	else
		fbo.target_set(fbo_scene)
	end

	shader.use(shader_tracer)
	shader.uniform_f(shader.uniform_location_get(shader_tracer, "time"), sec_current)
	shader.uniform_matrix_4f(shader.uniform_location_get(shader_tracer, "in_cam_inverse"), mat_cam2)
	shader.uniform_i(shader.uniform_location_get(shader_tracer, "tex_map"), 0)
	shader.uniform_i(shader.uniform_location_get(shader_tracer, "tex_depth_in"), 1)
	shader.uniform_i(shader.uniform_location_get(shader_tracer, "tex_tiles"), 2)
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
	shader.uniform_i(shader.uniform_location_get(shader_tracer, "have_depth_in"), (DEPTHONLY >= 1 and 1) or 0)
	texture.unit_set(0, "3", tex_map)
	texture.unit_set(1, "2", tex_depth[1])
	texture.unit_set(2, "2a", tex_tiles)
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

shader_tracer, shader_beamer = loadfile("shader.lua")()
assert(shader_tracer)
assert(shader_beamer)

print("Loading tiles!")
tex_tiles = texture.new("2a", 6, "4nb", 64, 64, 256, "nll", "4nb")
do
	local data = bin_load("dat/tiles.tga")
	local x, y, z, i
	local l = {}
	for z=0,256-1 do
		local zoffs = 4*64*64*z
	for x=0,(64*64*4)-1,4 do
		i = 18 + x + 4*64*64*(255-z)
		l[1 + x + zoffs] = data:byte(i+3)
		l[2 + x + zoffs] = data:byte(i+2)
		l[3 + x + zoffs] = data:byte(i+1)
		l[4 + x + zoffs] = data:byte(i+4)
	end
	end
	texture.load_sub(tex_tiles, "2a", 0, 0, 0, 0, 64, 64, 256, "4nb", l)
	texture.gen_mipmaps(tex_tiles, "2a")
end
print("Tiles loaded")

MAX_LX = 256+32
MAX_LY = 64+32
MAX_LZ = 128
MAX_LAYER = 5

tex_map = texture.new("3", MAX_LAYER+1, "4ub", MAX_LX, MAX_LY, MAX_LZ, "nnn", "4ub")
mdata = bin_load("map/"..MAP_NAME.."/map.dat")
map_lx, map_ly, map_lz = string.unpack("< i2 i2 i2", mdata:sub(1,6))
print (map_lx, map_ly, map_lz)
assert (#mdata == 6 + 4*map_lx*map_ly*map_lz)

local x,y,z,i,j
local map_octree = {}
local l = {}
map_octree[1] = l
print("Prepping")

i = 0
for i = 1,MAX_LX*MAX_LY*MAX_LZ*4 do
	l[i] = 0
end

print("Loading")
i = 0
for x = 0,map_lx-1 do
for y = 0,map_ly-1 do
for z = 0,map_lz-1 do
	--j = z + map_lz*(y + map_ly*x)
	j = (x+(MAX_LX-map_lx)//2) + MAX_LX*(y + MAX_LY*(z+(MAX_LZ-map_lz)//2))
	l[j*4+1], l[j*4+2], l[j*4+3], l[j*4+4] = string.unpack("< I1 I1 I1 I1", mdata:sub(7+i*4, 10+i*4))
	i = i + 1
end
end
end

print("Subdividing")
local tlx = MAX_LX
local tly = MAX_LY
local tlz = MAX_LZ

local layer
for layer=1,MAX_LAYER do
	--print(layer)
	local pl = l
	local pop = 0
	l = {}
	map_octree[layer+1] = l
	local tlx2 = tlx//2
	local tly2 = tly//2
	local tlz2 = tlz//2
	local vk
	vk = 0
	for z = 0,tlz-1,2 do
	for y = 0,tly-1,2 do
	for x = 0,tlx-1,2 do
		local sx, sy, sz
		local v
		v = 0x00

		for sx=0,1 do
		for sy=0,1 do
		for sz=0,1 do
			if v == 0x00 then
				local nv = pl[1 + 4*(x+sx + tlx*(y+sy + tly*(z+sz)))]
				if nv ~= 0x00 then
					v = nv
					pop = pop + 1
				end
			end
		end
		end
		end

		l[1 + vk] = v
		l[2 + vk] = 0
		l[3 + vk] = 0
		l[4 + vk] = 0
		vk = vk + 4
	end
	end
	end

	tlx = tlx2
	tly = tly2
	tlz = tlz2

	print(pop)
end

print("Communicating ascension info")
for layer=MAX_LAYER-1,0,-1 do
	print(layer)
	-- TODO!
	local tlx = MAX_LX>>layer
	local tly = MAX_LY>>layer
	local tlz = MAX_LZ>>layer
	local tlx2 = MAX_LX>>(layer+1)
	local tly2 = MAX_LY>>(layer+1)
	local tlz2 = MAX_LZ>>(layer+1)

	local dl = map_octree[layer+1]
	local sl = map_octree[layer+2]

	for z = 0,tlz-1 do
	for y = 0,tly-1 do
	for x = 0,tlx-1 do
		local sk = 4*((x>>1) + tlx2*((y>>1) + tly2*(z>>1)))
		if sl[sk+1] == 0x00 then
			local k = 4*(x + tlx*(y + tly*z))

			if layer == MAX_LAYER-1 then
				dl[k+4] = (dl[k+4] & 0x0F) | (MAX_LAYER<<4)
			else
				dl[k+4] = (dl[k+4] & 0x0F) | math.max((sl[sk+4]&0xF0), (layer+1)<<4)
			end
		end
	end
	end
	end
end

print("Actually loading textures")
for layer=0,MAX_LAYER do
	texture.load_sub(tex_map, "3", layer,
		0, 0, 0,
		MAX_LX>>(layer),
		MAX_LY>>(layer),
		MAX_LZ>>(layer),
		"4ub", map_octree[layer+1]
	)
end

tex_screen = texture.new("2", 1, "4nb", screen_w//screen_scale, screen_h//screen_scale, "ll", "4nb")
fbo_scene = fbo.new()
fbo.bind_tex(fbo_scene, 0, "2", tex_screen, 0)
assert(fbo.validate(fbo_scene))

tex_depth = {}
fbo_depth = {}
for i=1,DEPTHONLY do
	tex_depth[i] = texture.new("2", 1, "1f", (screen_w//screen_scale)>>i, (screen_h//screen_scale)>>i, "nn", "1f")
	fbo_depth[i] = fbo.new()
	fbo.bind_tex(fbo_depth[i], 0, "2", tex_depth[i], 0)
	assert(fbo.validate(fbo_depth[i]))
end

shader_blit1 = shader.new({
vert = [=[
#version 150
in vec2 in_vertex;
out vec2 tc;

void main()
{
	gl_Position = vec4(in_vertex, 0.1, 1.0);
	tc = in_vertex*0.5+0.5;
}
]=],
frag = [=[
#version 150

in vec2 tc;
out vec4 out_color;
uniform sampler2D tex0;

void main()
{
	out_color = texture(tex0, tc, 0);
}
]=],
}, {"in_vertex"}, {"out_color"})
assert(shader_blit1)


