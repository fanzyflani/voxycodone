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

	// TODO: other things!
	lua_getglobal(L, "print");
	lua_pushstring(L, "Hello World!");
	lua_call(L, 1, 0);
}

