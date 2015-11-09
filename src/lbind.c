#include "common.h"

lua_State *Lbase = NULL;

// setups
void lbind_setup_draw(lua_State *L);
void lbind_setup_fbo(lua_State *L);
void lbind_setup_matrix(lua_State *L);
void lbind_setup_misc(lua_State *L);
void lbind_setup_shader(lua_State *L);
void lbind_setup_texture(lua_State *L);

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
	lbind_setup_draw(L);
	lbind_setup_fbo(L);
	lbind_setup_matrix(L);
	lbind_setup_misc(L);
	lbind_setup_shader(L);
	lbind_setup_texture(L);

	// --- voxel
	lua_newtable(L);
	lua_setglobal(L, "voxel");

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

