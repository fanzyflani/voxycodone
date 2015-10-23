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

	// Run main.lua
	printf("Running lua/main.lua\n");
	luaL_loadfile(L, "lua/main.lua");
	lua_call(L, 0, 0); // if it's broken, it needs to crash
}

