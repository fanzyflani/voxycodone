#include "common.h"

lua_State *Lbase = NULL;

// setups
void lbind_setup_draw(lua_State *L);
void lbind_setup_fbo(lua_State *L);
void lbind_setup_matrix(lua_State *L);
void lbind_setup_misc(lua_State *L);
void lbind_setup_sandbox(lua_State *L);
void lbind_setup_shader(lua_State *L);
void lbind_setup_texture(lua_State *L);
void lbind_setup_voxel(lua_State *L);

static int lbind_bin_load(lua_State *L)
{
	if(lua_gettop(L) < 1)
		return luaL_error(L, "expected at least 1 argument to bin_load`");

	size_t len;
	const char *fname = luaL_checkstring(L, 1);
	char *data = fs_bin_load(L, fname, &len);

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
	//printf("[[%s]] %li\n", ret, *size);
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
	//char *data = fs_bin_load(L, fname, &len);
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

lua_State *init_lua_vm(lua_State *Lparent, enum vc_vm vmtyp, const char *root, int port)
{
	assert(vmtyp >= 0 && vmtyp < VM_TYPE_COUNT);

	// Create state
	lua_State *L = NULL;

	// FIXME: confirm if this is safe!
	if(true || Lparent == NULL)
	{
		L = luaL_newstate();
	} else {
		L = lua_newthread(Lparent);
		// FIXME FIXME XXX THIS IS FUCKING DANGEROUS I CAN'T QUITE SET THE GLOBAL ENVIRONMENT YET
		//lua_newtable(L);
		//lua_setupvalue(L, );
	}

	// Create extraspace
	struct vc_extraspace *es = malloc(sizeof(struct vc_extraspace));
	*(struct vc_extraspace **)(lua_getextraspace(L)) = es;
	es->vmtyp = vmtyp;
	es->Lparent = Lparent;
	es->root_dir = NULL;

	if(vmtyp == VM_CLIENT)
	{
		// TODO: connect
	} else if(vmtyp != VM_BLIND) {
		es->root_dir = strdup(root);
	}

	// Open builtin libraries
	if(vmtyp != VM_BLIND) { luaL_requiref(L, "base", luaopen_base, 1); lua_pop(L, 1); }
	luaL_requiref(L, "string", luaopen_string, 1); lua_pop(L, 1);
	luaL_requiref(L, "math", luaopen_math, 1); lua_pop(L, 1);
	luaL_requiref(L, "table", luaopen_table, 1); lua_pop(L, 1);

	// package is now emulated in Lua, and io will be

	if(vmtyp != VM_BLIND)
	{
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
		lbind_setup_sandbox(L);
		lbind_setup_shader(L);
		lbind_setup_texture(L);
		lbind_setup_voxel(L);

		// Set some globals
		lua_pushboolean(L, context_is_compat); lua_setglobal(L, "VOXYCODONE_GL_COMPAT_PROFILE");
	}

	// Return
	return L;
}

void init_lua(void)
{
	// Create system state
	lua_State *L = Lbase = init_lua_vm(NULL, VM_SYSTEM, "root/", 0);

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

