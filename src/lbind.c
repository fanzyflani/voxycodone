#include "common.h"

lua_State *Lbase = NULL;

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

