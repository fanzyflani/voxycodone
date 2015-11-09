#include "common.h"

static int lbind_matrix_new(lua_State *L)
{
	mat4x4 *mat = lua_newuserdata(L, sizeof(mat4x4));

	mat4x4_identity(*mat);

	return 1;
}

static int lbind_matrix_identity(lua_State *L)
{
	if(lua_gettop(L) < 1)
		return luaL_error(L, "expected 1 argument to matrix.identity");

	mat4x4 *mat = lua_touserdata(L, 1);

	assert(mat != NULL);
	mat4x4_identity(*mat);

	return 0;
}

static int lbind_matrix_rotate_X(lua_State *L)
{
	if(lua_gettop(L) < 3)
		return luaL_error(L, "expected 3 arguments to matrix.rotate_X");

	mat4x4 *mat_A = lua_touserdata(L, 1);
	mat4x4 *mat_B = lua_touserdata(L, 2);
	double rot = lua_tonumber(L, 3);

	assert(mat_A != NULL);
	assert(mat_B != NULL);

	mat4x4_rotate_X(*mat_A, *mat_B, rot);

	return 0;
}

static int lbind_matrix_rotate_Y(lua_State *L)
{
	if(lua_gettop(L) < 3)
		return luaL_error(L, "expected 3 arguments to matrix.rotate_Y");

	mat4x4 *mat_A = lua_touserdata(L, 1);
	mat4x4 *mat_B = lua_touserdata(L, 2);
	double rot = lua_tonumber(L, 3);

	assert(mat_A != NULL);
	assert(mat_B != NULL);

	mat4x4_rotate_Y(*mat_A, *mat_B, rot);

	return 0;
}

static int lbind_matrix_translate_in_place(lua_State *L)
{
	if(lua_gettop(L) < 4)
		return luaL_error(L, "expected 4 arguments to matrix.translate_in_place");

	mat4x4 *mat_A = lua_touserdata(L, 1);
	double tx = lua_tonumber(L, 2);
	double ty = lua_tonumber(L, 3);
	double tz = lua_tonumber(L, 4);

	assert(mat_A != NULL);

	mat4x4_translate_in_place(*mat_A, tx, ty, tz);

	return 0;
}

static int lbind_matrix_invert(lua_State *L)
{
	if(lua_gettop(L) < 2)
		return luaL_error(L, "expected 2 arguments to matrix.invert");

	mat4x4 *mat_A = lua_touserdata(L, 1);
	mat4x4 *mat_B = lua_touserdata(L, 2);

	assert(mat_A != NULL);
	assert(mat_B != NULL);
	mat4x4_invert(*mat_A, *mat_B);

	return 0;
}

void lbind_setup_matrix(lua_State *L)
{
	lua_newtable(L);
	lua_pushcfunction(L, lbind_matrix_new); lua_setfield(L, -2, "new");
	lua_pushcfunction(L, lbind_matrix_identity); lua_setfield(L, -2, "identity");
	lua_pushcfunction(L, lbind_matrix_rotate_X); lua_setfield(L, -2, "rotate_X");
	lua_pushcfunction(L, lbind_matrix_rotate_Y); lua_setfield(L, -2, "rotate_Y");
	lua_pushcfunction(L, lbind_matrix_translate_in_place); lua_setfield(L, -2, "translate_in_place");
	lua_pushcfunction(L, lbind_matrix_invert); lua_setfield(L, -2, "invert");
	lua_setglobal(L, "matrix");
}

