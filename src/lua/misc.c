#include "common.h"

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

static int lbind_misc_mouse_visible_set(lua_State *L)
{
	if(lua_gettop(L) < 1)
		return luaL_error(L, "expected 1 argument to misc.mouse_visible_set");

	SDL_ShowCursor(lua_toboolean(L, 1));

	return 0;
}

static int lbind_misc_exit(lua_State *L)
{
	// FIXME: needs to pass back to parent

	do_exit = true;

	return 0;
}

static int lbind_misc_gl_error(lua_State *L)
{
	lua_pushinteger(L, glGetError());
	return 1;
}

void lbind_setup_misc(lua_State *L)
{
	lua_newtable(L);
	lua_pushcfunction(L, lbind_misc_exit); lua_setfield(L, -2, "exit");
	lua_pushcfunction(L, lbind_misc_gl_error); lua_setfield(L, -2, "gl_error");
	lua_pushcfunction(L, lbind_misc_mouse_grab_set); lua_setfield(L, -2, "mouse_grab_set");
	lua_pushcfunction(L, lbind_misc_mouse_visible_set); lua_setfield(L, -2, "mouse_visible_set");
	lua_setglobal(L, "misc");
}

