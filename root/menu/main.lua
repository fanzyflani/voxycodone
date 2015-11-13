
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
end

function hook_tick(sec_current, sec_delta)
end

