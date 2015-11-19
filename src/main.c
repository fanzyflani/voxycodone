#include "common.h"
#ifdef WIN32
#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#endif

SDL_Window *window;
SDL_GLContext window_gl;
int do_exit = false;
int mouse_locked = false;

double render_sec_current = 0.0;

int main(int argc, char *argv[])
{
#ifdef WIN32
	// IIRC I wrote all this code thus can relicense
	{
		char cwd[2048] = "";
		GetModuleFileName(NULL, cwd, 2047);
		char *v = cwd + strlen(cwd) - 1;
		while(v >= cwd)
		{
			if(*v == '\\')
			{
				*(v+1) = '\x00';
				break;
			}
			v--;
		}
		printf("path: [%s]\n", cwd);

		if(_chdir(cwd) != 0)
		{
			MessageBox(NULL, "Failed to change directory.", "Error", MB_ICONSTOP);
			return 1;
		}
	}
#endif

	SDL_Init(SDL_INIT_VIDEO | SDL_INIT_AUDIO | SDL_INIT_NOPARACHUTE);
	Mix_Init(MIX_INIT_OGG);

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

	window = SDL_CreateWindow("Voxycodone prealpha",
		SDL_WINDOWPOS_UNDEFINED,
		SDL_WINDOWPOS_UNDEFINED,
		//1920, 1080,
		1280, 720,
		//800, 500,
		//640, 360,
		//320, 180,
		//SDL_WINDOW_FULLSCREEN | 
		SDL_WINDOW_OPENGL);

	window_gl = SDL_GL_CreateContext(window);
	SDL_GL_SetSwapInterval(0); // disable vsync, this is a benchmark
	//SDL_GL_SetSwapInterval(-1); // late swap tearing if you want it
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

	// TODO: move this to Lua somehow {
	// Get textures from Lua state
	//lua_getglobal(Lbase, "tex_ray_vox"); tex_ray_vox = lua_tointeger(Lbase, -1); lua_pop(Lbase, 1);

	// Send voxel landscape
	//glBindTexture(GL_TEXTURE_3D, tex_ray_vox);
	//voxygen_load_repeated_chunk("dat/voxel1.voxygen");
	//glBindTexture(GL_TEXTURE_3D, 0);
	// }

	Mix_OpenAudio(44100, AUDIO_S16SYS, 2, 4096);
	// TODO: clean this up {
	//Mix_Chunk *music = Mix_LoadWAV("dat/ds15rel-gm.ogg");
	//int music_chn = Mix_PlayChannel(-1, music, 0);
	// }

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
				lua_getglobal(Lbase, "hook_key");
				lua_pushinteger(Lbase, ev.key.keysym.sym);
				lua_pushboolean(Lbase, ev.type == SDL_KEYDOWN);
				lua_call(Lbase, 2, 0);
				break;

			case SDL_MOUSEBUTTONUP:
			case SDL_MOUSEBUTTONDOWN:
				lua_getglobal(Lbase, "hook_mouse_button");
				lua_pushinteger(Lbase, ev.button.button);
				lua_pushboolean(Lbase, ev.type == SDL_MOUSEBUTTONDOWN);
				lua_call(Lbase, 2, 0);
				break;

			case SDL_MOUSEMOTION:
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
			snprintf(fpsbuf, 64-1, ":D-%c-< FPS: %i", hands, fps);
			hands ^= ('/' ^ '\\');
			SDL_SetWindowTitle(window, fpsbuf);
			fps = 0;
		}
		double sec_delta = ((double)(ticks_now - ticks_prev))/1000.0;
		render_sec_current = ((double)(ticks_now))/1000.0;
		lua_getglobal(Lbase, "hook_tick");
		lua_pushnumber(Lbase, render_sec_current);
		lua_pushnumber(Lbase, sec_delta);
		lua_call(Lbase, 2, 0);

		lua_getglobal(Lbase, "hook_render");
		lua_pushnumber(Lbase, render_sec_current);
		lua_call(Lbase, 1, 0);

		//glFinish();
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

