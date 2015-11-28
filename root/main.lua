screen_w, screen_h = draw.screen_size_get()

-- from SDL_keycode.h
SDLK_ESCAPE = 27

vm_active_stack = {}
vm_current = nil

mouse_moved = false
mouse_new_x = 0
mouse_new_y = 0
mouse_new_dx = 0
mouse_new_dy = 0

function hook_render(sec_current, ...)
	sandbox.send(vm_current, "hook_render", sec_current, ...)
	sandbox.poll(vm_current)
	--[[
	sandbox.send(vm_menu, "hook_render", sec_current, ...)
	sandbox.poll(vm_menu)
	]]

	fbo.target_set(nil)
	draw.buffers_set({0})

	texture.unit_set(0, "2", sandbox.fbo_get_tex(vm_current))
	shader.use(shader_blit1)
	shader.uniform_i(shader.uniform_location_get(shader_blit1, "tex0"), 0)
	draw.viewport_set(0, 0, screen_w, screen_h)
	draw.blit()

	--[[
	texture.unit_set(0, "2", sandbox.fbo_get_tex(vm_menu))
	shader.use(shader_blit1)
	shader.uniform_i(shader.uniform_location_get(shader_blit1, "tex0"), 0)
	draw.viewport_set(0, 0, screen_w/4, screen_h/4)
	draw.blit()
	]]
end

function hook_tick(sec_current, sec_delta, ...)
	--[[
	-- Need to buffer this, it gets REALLY slow
	if mouse_moved then
		--print("sending motion", mouse_new_dx, mouse_new_dy)
		sandbox.send(vm_current, "hook_mouse_motion", mouse_new_x, mouse_new_y, mouse_new_dx, mouse_new_dy)
		mouse_new_dx = 0
		mouse_new_dy = 0
		mouse_moved = false
	end
	]]

	sandbox.send(vm_current, "hook_tick", sec_current, sec_delta, ...)
	sandbox.poll(vm_current)

	-- TODO: check for messages
	--print(sec_current, #sandbox.mbox)
end

function hook_key(key, state, ...)
	-- TODO: hook wisely
	if key == SDLK_ESCAPE then
		if not state then
			misc.exit()
		end

		return
	end

	sandbox.send(vm_current, "hook_key", key, state, ...)
end

function hook_mouse_button(button, state, ...)
	sandbox.send(vm_current, "hook_mouse_button", button, state, ...)
end

function hook_mouse_motion(x, y, dx, dy, ...)
	sandbox.send(vm_current, "hook_mouse_motion", x, y, dx, dy, ...)
	--[[
	mouse_moved = true
	mouse_new_x = x
	mouse_new_y = y
	mouse_new_dx = mouse_new_dx + dx
	mouse_new_dy = mouse_new_dy + dy
	]]
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
		gl_FragColor = texture2D(tex0, tc, 0);
	}
	]=],
	}, {"in_vertex"}, {"out_color"})
	assert(shader_blit1)
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
	assert(shader_blit1)
end

do
	vm_menu = sandbox.new("plugin", "menu")
	vm_current = vm_menu

	--vm_client = sandbox.new("plugin", "bnlmaps")
	vm_client = sandbox.new("plugin", "q1map")
	vm_current = vm_client
end
