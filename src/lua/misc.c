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

static int lbind_misc_uncompress(lua_State *L)
{
	int top = lua_gettop(L);

	if(top < 1)
		return luaL_error(L, "expected 1 argument to misc.uncompress");
	
	// Grab string
	size_t slen_full;
	const Bytef *sdat = (const Bytef *)luaL_checklstring(L, 1, &slen_full);
	uLongf slen = (uLongf)slen_full;
	if(slen_full < 1024) slen_full = 1024;

	// Iteratively increase buffer until we can uncompress successfully
	// We can accept a hint if necessary
	size_t dlen_cur = slen_full*2;
	if(top >= 2) dlen_cur = luaL_checkinteger(L, 2);

	uLongf dlen = 0;
	Bytef *ddat = malloc(dlen_cur);

	for(;;)
	{
		dlen = (uLongf)dlen_cur;
		//fprintf(stderr, "dlen %d\n", dlen);
		int result = uncompress(ddat, &dlen, sdat, slen);

		if(result == Z_OK)
		{
			break;

		} else if(result == Z_BUF_ERROR) { 
			dlen_cur += slen_full;
			ddat = realloc(ddat, dlen_cur);

		} else {
			free(ddat);
			return luaL_error(L, "error code %d reading zlib stream", result);

		}
	}

	// Push, free, return!
	lua_pushlstring(L, (char *)ddat, dlen);
	free(ddat);
	return 1;
}

void lbind_setup_misc(lua_State *L)
{
	lua_newtable(L);
	lua_pushcfunction(L, lbind_misc_exit); lua_setfield(L, -2, "exit");
	lua_pushcfunction(L, lbind_misc_gl_error); lua_setfield(L, -2, "gl_error");
	lua_pushcfunction(L, lbind_misc_mouse_grab_set); lua_setfield(L, -2, "mouse_grab_set");
	lua_pushcfunction(L, lbind_misc_mouse_visible_set); lua_setfield(L, -2, "mouse_visible_set");
	lua_pushcfunction(L, lbind_misc_uncompress); lua_setfield(L, -2, "uncompress");
	lua_setglobal(L, "misc");
}

