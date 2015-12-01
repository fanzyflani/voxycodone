-- info from SDL_keycode.h
SDLK_RETURN = 13
SDLK_ESCAPE = 27
SDLK_SPACE = 32
SDLK_LCTRL = (1<<30)+224
SDLK_RIGHT = (1<<30)+79
SDLK_LEFT = (1<<30)+80
SDLK_DOWN = (1<<30)+81
SDLK_UP = (1<<30)+82
do
	local i
	for i=("a"):byte(),("z"):byte() do
		_ENV["SDLK_"..string.char(i)] = i
	end
	for i=("0"):byte(),("9"):byte() do
		_ENV["SDLK_"..string.char(i)] = i
	end
	for i=1,12 do
		_ENV["SDLK_F"..tostring(i)] = (i-1)+(1<<30)+58
	end
end

