#include "common.h"

lua_State *Lbase = NULL;

static int lbind_draw_cam_set_pa(lua_State *L)
{
	if(lua_gettop(L) < 5)
		return luaL_error(L, "expected 5 arguments to draw.cam_set_pa");

	cam_pos_x = lua_tonumber(L, 1);
	cam_pos_y = lua_tonumber(L, 2);
	cam_pos_z = lua_tonumber(L, 3);
	cam_rot_x = lua_tonumber(L, 4);
	cam_rot_y = lua_tonumber(L, 5);

	return 0;
}

static int lbind_misc_mouse_grab_set(lua_State *L)
{
	if(lua_gettop(L) < 1)
		return luaL_error(L, "expected 1 argument to misc.mouse_grab_set");

	mouse_locked = lua_toboolean(L, 1);
	SDL_ShowCursor(!mouse_locked);
	SDL_SetWindowGrab(window, mouse_locked);
	SDL_SetRelativeMouseMode(mouse_locked);

	return 0;
}

static int lbind_misc_exit(lua_State *L)
{
	do_exit = true;

	return 0;
}

void init_lua(void)
{
	// Create state
	Lbase = luaL_newstate();
	lua_State *L = Lbase;

	// Open builtin libraries
	// TODO cherry-pick once we make this into a game engine
	luaL_openlibs(L);

	//
	// Create tables to fill in
	//

	// --- draw
	lua_newtable(L);
	lua_pushcfunction(L, lbind_draw_cam_set_pa); lua_setfield(L, -2, "cam_set_pa");
	lua_setglobal(L, "draw");

	// --- matrix
	lua_newtable(L);
	lua_setglobal(L, "matrix");

	// --- texture
	lua_newtable(L);
	lua_setglobal(L, "texture");

	// --- shader
	lua_newtable(L);
	lua_setglobal(L, "shader");

	// --- voxel
	lua_newtable(L);
	lua_setglobal(L, "voxel");

	// --- misc
	lua_newtable(L);
	lua_pushcfunction(L, lbind_misc_exit); lua_setfield(L, -2, "exit");
	lua_pushcfunction(L, lbind_misc_mouse_grab_set); lua_setfield(L, -2, "mouse_grab_set");
	lua_setglobal(L, "misc");

	// Run main.lua
	printf("Running lua/main.lua\n");
	if(luaL_loadfile(L, "lua/main.lua") != LUA_OK)
	{
		printf("ERROR LOADING: %s\n", lua_tostring(L, 1));
		fflush(stdout);
		abort();
	}

	lua_call(L, 0, 0); // if it's broken, it needs to crash
}

