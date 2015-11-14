
-- from SDL_keycode.h
SDLK_ESCAPE = 27

function hook_key(key, state)
	if key == SDLK_ESCAPE and not state then
		misc.exit()
	end
end

function hook_mouse_button(button, state)
end

function hook_mouse_motion(x, y, dx, dy)
end

function hook_render(sec_current)
	shader.use(shader_test)
	shader.uniform_f(shader.uniform_location_get(shader_test, "time"), sec_current)
	shader.uniform_i(shader.uniform_location_get(shader_test, "tex_noise"), 0)
	texture.unit_set(0, "2", tex_noise)
	draw.blit()
end

function hook_tick(sec_current, sec_delta)
end

tex_noise = texture.new("2", 1, "1f", 256, 256, "ll", "1f")
do
	local x, y
	local l = {}
	for y=0,256-1 do
	for x=0,256-1 do
		l[1+x+y*256] = 0.0
	end
	end
	for y=0,256-1 do
	for x=0,256-1 do
		l[1+x+y*256] = math.random()
	end
	end

	texture.load_sub(tex_noise, "2", 0, 0, 0, 256, 256, "1f", l)
end

shader_test = loadfile("scenes/blobs.lua")()
assert(shader_test)


