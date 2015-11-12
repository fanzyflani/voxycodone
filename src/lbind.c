#include "common.h"

lua_State *Lbase = NULL;

// setups
void lbind_setup_draw(lua_State *L);
void lbind_setup_fbo(lua_State *L);
void lbind_setup_matrix(lua_State *L);
void lbind_setup_misc(lua_State *L);
void lbind_setup_shader(lua_State *L);
void lbind_setup_texture(lua_State *L);
void lbind_setup_voxel(lua_State *L);

lua_State *init_lua_system(void)
{
	// Create state
	lua_State *L = luaL_newstate();

	// Open builtin libraries
	luaL_requiref(L, "package", luaopen_package, 1); // TODO: shim this package

	// Open other builtin libraries
	luaL_requiref(L, "base", luaopen_base, 1);
	luaL_requiref(L, "string", luaopen_string, 1);
	luaL_requiref(L, "math", luaopen_math, 1);
	luaL_requiref(L, "table", luaopen_table, 1);
	luaL_requiref(L, "io", luaopen_io, 1); // TODO: emulate this package

	// Apply shims


	//
	// Create tables to fill in
	//
	lbind_setup_draw(L);
	lbind_setup_fbo(L);
	lbind_setup_matrix(L);
	lbind_setup_misc(L);
	lbind_setup_shader(L);
	lbind_setup_texture(L);
	lbind_setup_voxel(L);

	// Return
	return L;
}

void init_lua(void)
{
	// Create system state
	lua_State *L = Lbase = init_lua_system();

	// Run main.lua
	printf("Running root/main.lua\n");
	if(luaL_loadfile(L, "root/main.lua") != LUA_OK)
	{
		printf("ERROR LOADING: %s\n", lua_tostring(L, 1));
		fflush(stdout);
		abort();
	}

	lua_call(L, 0, 0); // if it's broken, it needs to crash
}

