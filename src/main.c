#include "common.h"

SDL_Window *window;
SDL_GLContext window_gl;
int do_exit = false;
int mouse_locked = false;

double render_sec_current = 0.0;

int key_pos_dxn = false;
int key_pos_dxp = false;
int key_pos_dyn = false;
int key_pos_dyp = false;
int key_pos_dzn = false;
int key_pos_dzp = false;

void hook_key(SDL_Keycode key, int state)
{
	if(key == SDLK_ESCAPE && !state)
		do_exit = true;
	else if(key == SDLK_w) key_pos_dzp = state;
	else if(key == SDLK_s) key_pos_dzn = state;
	else if(key == SDLK_a) key_pos_dxn = state;
	else if(key == SDLK_d) key_pos_dxp = state;
	else if(key == SDLK_LCTRL) key_pos_dyn = state;
	else if(key == SDLK_SPACE) key_pos_dyp = state;
}

void hook_mouse_button(int button, int state)
{
	if(button == 1 && !state)
	{
		mouse_locked = !mouse_locked;
		SDL_ShowCursor(!mouse_locked);
		SDL_SetWindowGrab(window, mouse_locked);
		SDL_SetRelativeMouseMode(mouse_locked);
	}
}

void hook_mouse_motion(int x, int y, int dx, int dy)
{
	if(!mouse_locked)
		return;

	cam_rot_y = cam_rot_y - dx*M_PI/1000.0;
	cam_rot_x = cam_rot_x + dy*M_PI/1000.0;
	double clamp = M_PI/2.0-0.0001;
	if(cam_rot_x < -clamp) cam_rot_x = -clamp;
	if(cam_rot_x >  clamp) cam_rot_x =  clamp;
}

int main(int argc, char *argv[])
{
	SDL_Init(SDL_INIT_VIDEO | SDL_INIT_NOPARACHUTE);

	SDL_GL_SetAttribute(SDL_GL_CONTEXT_PROFILE_MASK, SDL_GL_CONTEXT_PROFILE_CORE);
	SDL_GL_SetAttribute(SDL_GL_CONTEXT_MAJOR_VERSION, 3);
	SDL_GL_SetAttribute(SDL_GL_CONTEXT_MINOR_VERSION, 2);

	SDL_GL_SetAttribute(SDL_GL_RED_SIZE, 8);
	SDL_GL_SetAttribute(SDL_GL_GREEN_SIZE, 8);
	SDL_GL_SetAttribute(SDL_GL_BLUE_SIZE, 8);
	SDL_GL_SetAttribute(SDL_GL_ALPHA_SIZE, 0);
	SDL_GL_SetAttribute(SDL_GL_DEPTH_SIZE, 0);
	SDL_GL_SetAttribute(SDL_GL_STENCIL_SIZE, 0);
	SDL_GL_SetAttribute(SDL_GL_DOUBLEBUFFER, 1);

	window = SDL_CreateWindow("OBEY AUTHORITY CEASE REPRODUCTION EAT MCDONALDS",
		SDL_WINDOWPOS_UNDEFINED,
		SDL_WINDOWPOS_UNDEFINED,
		1280, 720,
		//800, 500,
		//640, 360,
		SDL_WINDOW_OPENGL);

	window_gl = SDL_GL_CreateContext(window);
	SDL_GL_SetSwapInterval(0); // disable vsync, because fuck vsync
	printf("GL version %i\n", epoxy_gl_version());

#ifndef WIN32
	signal(SIGINT, SIG_DFL);
	signal(SIGTERM, SIG_DFL);
#endif

	init_gfx();
	init_lua();

	int32_t ticks_prev = SDL_GetTicks();
	int32_t ticks_get_fps = ticks_prev;
	int fps = 0;
	char hands = '/';

	for(;;)
	{
		SDL_Event ev;

		while(SDL_PollEvent(&ev))
		switch(ev.type)
		{
			case SDL_QUIT:
				do_exit = true;
				break;

			case SDL_KEYUP:
			case SDL_KEYDOWN:
				hook_key(ev.key.keysym.sym, ev.type == SDL_KEYDOWN);
				lua_getglobal(Lbase, "hook_key");
				lua_pushinteger(Lbase, ev.key.keysym.sym);
				lua_pushboolean(Lbase, ev.type == SDL_KEYDOWN);
				lua_call(Lbase, 2, 0);
				break;

			case SDL_MOUSEBUTTONUP:
			case SDL_MOUSEBUTTONDOWN:
				hook_mouse_button(ev.button.button, ev.type == SDL_MOUSEBUTTONDOWN);
				lua_getglobal(Lbase, "hook_mouse_button");
				lua_pushinteger(Lbase, ev.button.button);
				lua_pushboolean(Lbase, ev.type == SDL_MOUSEBUTTONDOWN);
				lua_call(Lbase, 2, 0);
				break;

			case SDL_MOUSEMOTION:
				hook_mouse_motion(ev.motion.x, ev.motion.y, ev.motion.xrel, ev.motion.yrel);
				lua_getglobal(Lbase, "hook_mouse_motion");
				lua_pushinteger(Lbase, ev.motion.x);
				lua_pushinteger(Lbase, ev.motion.y);
				lua_pushinteger(Lbase, ev.motion.xrel);
				lua_pushinteger(Lbase, ev.motion.yrel);
				lua_call(Lbase, 4, 0);
				break;
		}

		if(do_exit) break;

		int32_t ticks_now = SDL_GetTicks();
		fps++;
		if(ticks_now >= ticks_get_fps)
		{
			while(ticks_now >= ticks_get_fps)
				ticks_get_fps += 1000;

			char fpsbuf[64];
			fpsbuf[64-1] = '\x00';
			snprintf(fpsbuf, 64-1, "TheFutureIsYesterday :D-%c-< FPS: %i", hands, fps);
			hands ^= ('/' ^ '\\');
			SDL_SetWindowTitle(window, fpsbuf);
			fps = 0;
		}
		double sec_delta = ((double)(ticks_now - ticks_prev))/1000.0;
		render_sec_current = ((double)(ticks_now))/1000.0;
		hook_tick(render_sec_current, sec_delta);
		lua_getglobal(Lbase, "hook_tick");
		lua_pushnumber(Lbase, render_sec_current);
		lua_pushnumber(Lbase, sec_delta);
		lua_call(Lbase, 2, 0);
		h_render_main();
		glFinish();
		SDL_GL_SwapWindow(window);
		ticks_prev = ticks_now;

#ifndef WIN32
		//usleep(500);
#else
		//SDL_Delay(10);
#endif
	}

	return 0;
}

