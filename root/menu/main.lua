screen_w, screen_h = draw.screen_size_get()
screen_scale = 4

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
	draw.buffers_set({0})

	fbo.target_set(fbo_scene)
	shader.use(shader_test)
	shader.uniform_f(shader.uniform_location_get(shader_test, "time"), sec_current)
	shader.uniform_i(shader.uniform_location_get(shader_test, "tex_noise"), 0)
	texture.unit_set(0, "2", tex_noise)
	draw.viewport_set(0, 0, screen_w/screen_scale, screen_h/screen_scale)
	draw.blit()

	fbo.target_set(nil)
	shader.use(shader_blit1)
	shader.uniform_i(shader.uniform_location_get(shader_blit1, "tex0"), 0)
	texture.unit_set(0, "2", tex_screen)
	draw.viewport_set(0, 0, screen_w, screen_h)
	draw.blit()
end

function hook_tick(sec_current, sec_delta)
end

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

	l[1+0] = 0.0
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
		amp = amp * 0.7
	end

	texture.load_sub(tex_noise, "2", 0, 0, 0, size, size, "1f", l)
end

tex_screen = texture.new("2", 1, "4nb", screen_w/screen_scale, screen_h/screen_scale, "ll", "4nb")
fbo_scene = fbo.new()
fbo.bind_tex(fbo_scene, 0, "2", tex_screen, 0)
assert(fbo.validate(fbo_scene))
scene = "lettuce"
shader_test = loadfile("scenes/"..scene..".lua")()
assert(shader_test)

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

