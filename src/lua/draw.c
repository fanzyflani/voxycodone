#include "common.h"

static int lbind_draw_screen_size_get(lua_State *L)
{
	int wnd_w, wnd_h;
	SDL_GetWindowSize(window, &wnd_w, &wnd_h);
	
	lua_pushinteger(L, wnd_w);
	lua_pushinteger(L, wnd_h);
	return 2;
}

static int lbind_draw_viewport_set(lua_State *L)
{
	if(lua_gettop(L) < 4)
		return luaL_error(L, "expected 4 arguments to draw.viewport_set");

	GLint x = lua_tointeger(L, 1);
	GLint y = lua_tointeger(L, 2);
	GLsizei xlen = lua_tointeger(L, 3);
	GLsizei ylen = lua_tointeger(L, 4);
	glViewport(x, y, xlen, ylen);

	return 0;
}

static int lbind_draw_buffers_set(lua_State *L)
{
	int i;

	if(lua_gettop(L) < 1)
		return luaL_error(L, "expected 1 argument to draw.buffers_set");

	lua_len(L, 1);
	int len = lua_tointeger(L, -1);
	if(len <= 0 || len > 256) // arbitrary upper limit
		return luaL_error(L, "invalid length");
	lua_pop(L, 1);

	//
	int blen = len * sizeof(GLenum);
	if(blen < len)
		return luaL_error(L, "size overflow");

	GLenum *list = malloc(blen);
	for(i = 0; i < len; i++)
	{
		lua_geti(L, 1, i+1);
		int v = lua_tointeger(L, -1);
		lua_pop(L, 1);
		if(v >= 0 && v < 256)
			list[i] = GL_COLOR_ATTACHMENT0 + v;
		else {
			free(list);
			return luaL_error(L, "invalid output");
		}
	}

	assert(len > 0);
	glDrawBuffers(len, list);
	free(list);

	return 0;
}

static int lbind_draw_blit(lua_State *L)
{
	if(context_is_compat)
	{
		glBindBuffer(GL_ARRAY_BUFFER, va_ray_vbo);
		glVertexAttribPointer(0, 2, GL_SHORT, GL_FALSE, 2*sizeof(int16_t), &(((int16_t *)0)[0]));
		glEnableVertexAttribArray(0);
		glDrawArrays(GL_TRIANGLES, 0, 6);
		glDisableVertexAttribArray(0);
		glBindBuffer(GL_ARRAY_BUFFER, 0);
	} else {
		glBindVertexArray(va_ray_vao);
		glDrawArrays(GL_TRIANGLES, 0, 6);
		glBindVertexArray(0);
	}

	return 0;
}

void lbind_setup_draw(lua_State *L)
{
	lua_newtable(L);
	lua_pushcfunction(L, lbind_draw_screen_size_get); lua_setfield(L, -2, "screen_size_get");
	lua_pushcfunction(L, lbind_draw_blit); lua_setfield(L, -2, "blit");
	lua_pushcfunction(L, lbind_draw_viewport_set); lua_setfield(L, -2, "viewport_set");
	lua_pushcfunction(L, lbind_draw_buffers_set); lua_setfield(L, -2, "buffers_set");
	lua_setglobal(L, "draw");
}

