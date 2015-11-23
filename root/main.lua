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
	print(sec_current, #sandbox.mbox)
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

do
	vm_menu = sandbox.new("plugin", "menu")
	vm_current = vm_menu

	vm_client = sandbox.new("plugin", "bnlmaps")
	vm_current = vm_client
end
