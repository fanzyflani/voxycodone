#include "common.h"

static int lbind_shader_new(lua_State *L)
{
	int i;

	if(lua_gettop(L) < 3)
		return luaL_error(L, "expected at least 3 arguments to shader.new");
	
	// the 4-arg format is completely unsupported! don't use it! it's out of date!

	lua_getfield(L, 1, "vert");
	const char *vert_src = lua_tostring(L, -1);
	lua_pop(L, 1);

	lua_getfield(L, 1, "frag");
	const char *frag_src = lua_tostring(L, -1);
	lua_pop(L, 1);

	lua_getfield(L, 1, "geom");
	const char *geom_src = lua_tostring(L, -1);
	lua_pop(L, 1);

	if(vert_src == NULL)
		return luaL_error(L, "expected vertex shader\n");

	if(frag_src == NULL)
		return luaL_error(L, "expected fragment shader\n");

	// TODO: actually use input/output lists
	GLuint ret = init_shader_str(vert_src, frag_src, geom_src, L);

	if(ret == 0)
		lua_pushnil(L);
	else
		lua_pushinteger(L, ret);

	return 1;
}

static int lbind_shader_use(lua_State *L)
{
	int i;

	if(lua_gettop(L) < 1)
		return luaL_error(L, "expected at least 1 argument to shader.use");
	
	if(lua_isnil(L, 1))
		glUseProgram(0);
	else
		glUseProgram(lua_tointeger(L, 1));

	return 0;
}

static int lbind_shader_uniform_location_get(lua_State *L)
{
	int i;

	if(lua_gettop(L) < 2)
		return luaL_error(L, "expected at least 2 arguments to shader.uniform_location_get");

	GLuint shader = lua_tointeger(L, 1);
	const char *name = lua_tostring(L, 2);
	if(name == NULL)
		return luaL_error(L, "expected string for arg 2");

	lua_pushinteger(L, glGetUniformLocation(shader, name));
	return 1;
}

static int lbind_shader_uniform_matrix_4f(lua_State *L)
{
	int i;

	if(lua_gettop(L) < 2)
		return luaL_error(L, "expected at least 2 arguments to shader.uniform_matrix_4f");

	GLuint idx = lua_tointeger(L, 1);
	mat4x4 *mat = lua_touserdata(L, 2);
	if(mat == NULL)
		return luaL_error(L, "expected matrix for arg 2");

	glUniformMatrix4fv(idx, 1, GL_FALSE, (GLfloat *)mat);

	return 0;
}

static int lbind_shader_uniform_f(lua_State *L)
{
	int top = lua_gettop(L);
	if(top < 2)
		return luaL_error(L, "expected at least 2 arguments to shader.uniform_f");

	int elems = top-1;
	if(elems < 1 || elems > 4)
		return luaL_error(L, "invalid element count");

	GLint idx = lua_tointeger(L, 1);
	switch(elems)
	{
		case 1:
			glUniform1f(idx
				, lua_tonumber(L, 2)
				);
			break;

		case 2:
			glUniform2f(idx
				, lua_tonumber(L, 2)
				, lua_tonumber(L, 3)
				);
			break;

		case 3:
			glUniform3f(idx
				, lua_tonumber(L, 2)
				, lua_tonumber(L, 3)
				, lua_tonumber(L, 4)
				);
			break;

		case 4:
			glUniform4f(idx
				, lua_tonumber(L, 2)
				, lua_tonumber(L, 3)
				, lua_tonumber(L, 4)
				, lua_tonumber(L, 5)
				);
			break;

		default:
			return luaL_error(L, "EDOOFUS: invalid element count");
	}

	return 0;
}

static int lbind_shader_uniform_i(lua_State *L)
{
	int top = lua_gettop(L);
	if(top < 2)
		return luaL_error(L, "expected at least 2 arguments to shader.uniform_i");

	int elems = top-1;
	if(elems < 1 || elems > 4)
		return luaL_error(L, "invalid element count");

	GLint idx = lua_tointeger(L, 1);
	switch(elems)
	{
		case 1:
			glUniform1i(idx
				, lua_tointeger(L, 2)
				);
			break;

		case 2:
			glUniform2i(idx
				, lua_tointeger(L, 2)
				, lua_tointeger(L, 3)
				);
			break;

		case 3:
			glUniform3i(idx
				, lua_tointeger(L, 2)
				, lua_tointeger(L, 3)
				, lua_tointeger(L, 4)
				);
			break;

		case 4:
			glUniform4i(idx
				, lua_tointeger(L, 2)
				, lua_tointeger(L, 3)
				, lua_tointeger(L, 4)
				, lua_tointeger(L, 5)
				);
			break;

		default:
			return luaL_error(L, "EDOOFUS: invalid element count");
	}

	return 0;
}

static int lbind_shader_uniform_ui(lua_State *L)
{
	int top = lua_gettop(L);
	if(top < 2)
		return luaL_error(L, "expected at least 2 arguments to shader.uniform_ui");

	int elems = top-1;
	if(elems < 1 || elems > 4)
		return luaL_error(L, "invalid element count");

	GLint idx = lua_tointeger(L, 1);
	switch(elems)
	{
		case 1:
			glUniform1ui(idx
				, lua_tointeger(L, 2)
				);
			break;

		case 2:
			glUniform2ui(idx
				, lua_tointeger(L, 2)
				, lua_tointeger(L, 3)
				);
			break;

		case 3:
			glUniform3ui(idx
				, lua_tointeger(L, 2)
				, lua_tointeger(L, 3)
				, lua_tointeger(L, 4)
				);
			break;

		case 4:
			glUniform4ui(idx
				, lua_tointeger(L, 2)
				, lua_tointeger(L, 3)
				, lua_tointeger(L, 4)
				, lua_tointeger(L, 5)
				);
			break;

		default:
			return luaL_error(L, "EDOOFUS: invalid element count");
	}

	return 0;
}

static int lbind_shader_uniform_fv(lua_State *L)
{
	int i;

	int top = lua_gettop(L);
	if(top < 4)
		return luaL_error(L, "expected at least 4 arguments to shader.uniform_fv");

	lua_len(L, 4);
	size_t size = lua_tointeger(L, -1);
	lua_pop(L, 1);

	size_t len = lua_tointeger(L, 2);
	size_t elems = lua_tointeger(L, 3);
	if(elems < 1 || elems > 4)
		return luaL_error(L, "invalid element count");
	if(len*elems > size || len*elems < elems || len*elems < len)
		return luaL_error(L, "invalid length");

	size_t bsize_c = len*elems;
	if(bsize_c < len || bsize_c < elems)
		return luaL_error(L, "size overflow");
	size_t bsize = bsize_c * sizeof(float);
	if(bsize < sizeof(float) || bsize < bsize_c)
		return luaL_error(L, "size overflow");

	float *data = malloc(bsize);

	for(i = 0; i < bsize_c; i++)
	{
		lua_geti(L, 4, i+1);
		float f = lua_tonumber(L, -1);
		lua_pop(L, 1);
		data[i] = f;
	}

	GLint idx = lua_tointeger(L, 1);
	//printf("%i %u %u %u\n", idx, len, elems, size);
	switch(elems)
	{
		case 1: glUniform1fv(idx, len, data); break;
		case 2: glUniform2fv(idx, len, data); break;
		case 3: glUniform3fv(idx, len, data); break;
		case 4: glUniform4fv(idx, len, data); break;

		default:
			return luaL_error(L, "EDOOFUS: invalid element count");
	}

	free(data);

	return 0;
}

static int lbind_shader_uniform_iv(lua_State *L)
{
	int i;

	int top = lua_gettop(L);
	if(top < 4)
		return luaL_error(L, "expected at least 4 arguments to shader.uniform_iv");

	lua_len(L, 4);
	size_t size = lua_tointeger(L, -1);
	lua_pop(L, 1);

	size_t len = lua_tointeger(L, 2);
	size_t elems = lua_tointeger(L, 3);
	if(elems < 1 || elems > 4)
		return luaL_error(L, "invalid element count");
	if(len*elems > size || len*elems < elems || len*elems < len)
		return luaL_error(L, "invalid length");

	size_t bsize_c = len*elems;
	if(bsize_c < len || bsize_c < elems)
		return luaL_error(L, "size overflow");
	size_t bsize = bsize_c * sizeof(int32_t);
	if(bsize < sizeof(float) || bsize < bsize_c)
		return luaL_error(L, "size overflow");

	int32_t *data = malloc(bsize);

	for(i = 0; i < bsize_c; i++)
	{
		lua_geti(L, 4, i+1);
		int32_t f = lua_tointeger(L, -1);
		lua_pop(L, 1);
		data[i] = f;
	}

	GLint idx = lua_tointeger(L, 1);
	//printf("%i %u %u %u\n", idx, len, elems, size);
	switch(elems)
	{
		case 1: glUniform1iv(idx, len, data); break;
		case 2: glUniform2iv(idx, len, data); break;
		case 3: glUniform3iv(idx, len, data); break;
		case 4: glUniform4iv(idx, len, data); break;

		default:
			return luaL_error(L, "EDOOFUS: invalid element count");
	}

	free(data);

	return 0;
}

static int lbind_shader_uniform_uiv(lua_State *L)
{
	int i;

	int top = lua_gettop(L);
	if(top < 4)
		return luaL_error(L, "expected at least 4 arguments to shader.uniform_uiv");

	lua_len(L, 4);
	size_t size = lua_tointeger(L, -1);
	lua_pop(L, 1);

	size_t len = lua_tointeger(L, 2);
	size_t elems = lua_tointeger(L, 3);
	if(elems < 1 || elems > 4)
		return luaL_error(L, "invalid element count");
	if(len*elems > size || len*elems < elems || len*elems < len)
		return luaL_error(L, "invalid length");

	size_t bsize_c = len*elems;
	if(bsize_c < len || bsize_c < elems)
		return luaL_error(L, "size overflow");
	size_t bsize = bsize_c * sizeof(uint32_t);
	if(bsize < sizeof(float) || bsize < bsize_c)
		return luaL_error(L, "size overflow");

	uint32_t *data = malloc(bsize);

	for(i = 0; i < bsize_c; i++)
	{
		lua_geti(L, 4, i+1);
		uint32_t f = lua_tointeger(L, -1);
		lua_pop(L, 1);
		data[i] = f;
	}

	GLint idx = lua_tointeger(L, 1);
	//printf("%i %u %u %u\n", idx, len, elems, size);
	switch(elems)
	{
		case 1: glUniform1uiv(idx, len, data); break;
		case 2: glUniform2uiv(idx, len, data); break;
		case 3: glUniform3uiv(idx, len, data); break;
		case 4: glUniform4uiv(idx, len, data); break;

		default:
			return luaL_error(L, "EDOOFUS: invalid element count");
	}

	free(data);

	return 0;
}

void lbind_setup_shader(lua_State *L)
{
	lua_newtable(L);
	lua_pushcfunction(L, lbind_shader_new); lua_setfield(L, -2, "new");
	lua_pushcfunction(L, lbind_shader_use); lua_setfield(L, -2, "use");
	lua_pushcfunction(L, lbind_shader_uniform_location_get); lua_setfield(L, -2, "uniform_location_get");
	lua_pushcfunction(L, lbind_shader_uniform_matrix_4f); lua_setfield(L, -2, "uniform_matrix_4f");
	lua_pushcfunction(L, lbind_shader_uniform_f); lua_setfield(L, -2, "uniform_f");
	lua_pushcfunction(L, lbind_shader_uniform_i); lua_setfield(L, -2, "uniform_i");
	lua_pushcfunction(L, lbind_shader_uniform_ui); lua_setfield(L, -2, "uniform_ui");
	lua_pushcfunction(L, lbind_shader_uniform_fv); lua_setfield(L, -2, "uniform_fv");
	lua_pushcfunction(L, lbind_shader_uniform_iv); lua_setfield(L, -2, "uniform_iv");
	lua_pushcfunction(L, lbind_shader_uniform_uiv); lua_setfield(L, -2, "uniform_uiv");
	lua_setglobal(L, "shader");
}
