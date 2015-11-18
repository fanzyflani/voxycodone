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

static int lbind_bin_load(lua_State *L)
{
	if(lua_gettop(L) < 1)
		return luaL_error(L, "expected at least 1 argument to bin_load`");

	size_t len;
	const char *fname = luaL_checkstring(L, 1);
	char *data = fs_bin_load_direct(fname, &len); // FIXME: replace with a checked fs call once it exists

	if(data == NULL)
	{
		lua_pushnil(L);

	} else {
		lua_pushlstring(L, data, len);
		free(data);

	}

	return 1;
}

static const char *lbind_loadstring_Reader(lua_State *L, void *data, size_t *size)
{
	if(*(const char **)data == NULL)
		return NULL;

	const char *ret = *(const char **)data;
	const char *nextp = *(((const char **)data)+1);
	*size = nextp - ret;
	printf("[[%s]] %li\n", ret, *size);
	*(const char **)data = NULL;

	return ret;

}

static int lbind_loadfile(lua_State *L)
{
	int top = lua_gettop(L);
	if(top < 1)
		return luaL_error(L, "expected at least 1 argument to loadfile (we are NOT loading from stdin!)");

	const char *fname = luaL_checkstring(L, 1);
	const char *chunkname = (top < 3 ? fname : lua_tostring(L, 3));

	// Load file as string
	size_t len;
	//char *data = fs_bin_load_direct(fname, &len); // FIXME: replace with a checked fs call once it exists
	lua_getglobal(L, "bin_load");
	lua_pushvalue(L, 1);
	lua_call(L, 1, 1);
	const char *data = lua_tolstring(L, -1, &len);
	// KEEP DATA ON STACK UNLESS YOU WANT A USE AFTER FREE

	if(data == NULL)
	{
		lua_pop(L, 1);
		return luaL_error(L, "failed to load file");
	}

	// Now load it up as a Lua function
	// (NO WE DO NOT SUPPORT BINARY CHUNKS NOW BUGGER OFF)
	const char *dptrs[2] = {data, data+len};
	int load_result = lua_load(L, lbind_loadstring_Reader, &dptrs, chunkname, "t");
	//free(data);

	lua_remove(L, -2); // NOW POP DATA
	if(load_result == LUA_OK)
	{
		// All good
		return 1;

	} else {
		// Push nil and rotate for error message
		lua_pushnil(L);
		lua_pushvalue(L, -2);
		lua_remove(L, -3);

		return 2;

	}
}

static int lbind_dofile(lua_State *L)
{
	int top = lua_gettop(L);
	if(top < 1)
		return luaL_error(L, "expected at least 1 argument to dofile (we are NOT loading from stdin!)");

	// Load file
	lua_getglobal(L, "loadfile");
	//lua_pushcfunction(L, lbind_loadfile);
	lua_pushvalue(L, 1);
	lua_call(L, 1, 1); // TODO: report errors
	lua_call(L, 0, 0);

	return 0;
}

lua_State *init_lua_system(void)
{
	// Create state
	lua_State *L = luaL_newstate();

	// Open builtin libraries
	luaL_requiref(L, "base", luaopen_base, 1);
	luaL_requiref(L, "string", luaopen_string, 1);
	luaL_requiref(L, "math", luaopen_math, 1);
	luaL_requiref(L, "table", luaopen_table, 1);

	// package is now emulated in Lua, and io will be

	// Open filesystem stuff
	lua_pushcfunction(L, lbind_bin_load); lua_setglobal(L, "bin_load");

	// Apply shims
	lua_pushcfunction(L, lbind_dofile); lua_setglobal(L, "dofile");
	lua_pushcfunction(L, lbind_loadfile); lua_setglobal(L, "loadfile");

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
		printf("ERROR LOADING: %s\n", lua_tostring(L, -1));
		fflush(stdout);
		abort();
	}

	lua_call(L, 0, 0); // if it's broken, it needs to crash
}

