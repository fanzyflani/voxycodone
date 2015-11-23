#include "common.h"

GLenum texture_get_target(lua_State *L, const char *fmt);

static int lbind_fbo_new(lua_State *L)
{
	GLuint fbo;
	glGenFramebuffers(1, &fbo);

	lua_pushinteger(L, fbo);
	return 1;
}

static int lbind_fbo_bind_tex(lua_State *L)
{
	if(lua_gettop(L) < 5)
		return luaL_error(L, "expected 5 arguments to fbo.bind_tex");

	struct vc_extraspace *es = *(struct vc_extraspace **)(lua_getextraspace(L));
	if(es->fbo == -1)
		return luaL_error(L, "this state does not support rendering");

	GLuint fbo = lua_tointeger(L, 1);
	int attachment = lua_tointeger(L, 2);
	const char *tex_fmt_str = lua_tostring(L, 3);
	GLuint tex = lua_tointeger(L, 4);
	int level = lua_tointeger(L, 5);
	GLenum tex_target = texture_get_target(L, tex_fmt_str);

	GLenum attachment_enum;
	if(attachment >= 0)
		attachment_enum = GL_COLOR_ATTACHMENT0 + attachment;
	else if(attachment == -1)
		attachment_enum = GL_DEPTH_ATTACHMENT;
	else if(attachment == -2)
		attachment_enum = GL_STENCIL_ATTACHMENT;
	else if(attachment == -3)
		attachment_enum = GL_DEPTH_STENCIL_ATTACHMENT;
	else
		return luaL_error(L, "invalid attachment number");

	glBindFramebuffer(GL_FRAMEBUFFER, fbo);
	glFramebufferTexture2D(GL_FRAMEBUFFER, attachment_enum, tex_target, tex, level);
	glBindFramebuffer(GL_FRAMEBUFFER, es->fbo);

	return 0;
}

static int lbind_fbo_target_set(lua_State *L)
{
	if(lua_gettop(L) < 1)
		return luaL_error(L, "expected 1 argument to fbo.target_set");

	struct vc_extraspace *es = *(struct vc_extraspace **)(lua_getextraspace(L));
	if(es->fbo == -1)
		return luaL_error(L, "this state does not support rendering");

	GLuint fbo = lua_tointeger(L, 1);

	if(fbo > 0)
		glBindFramebuffer(GL_FRAMEBUFFER, fbo);
	else
		glBindFramebuffer(GL_FRAMEBUFFER, es->fbo);

	return 0;
}

static int lbind_fbo_validate(lua_State *L)
{
	if(lua_gettop(L) < 1)
		return luaL_error(L, "expected 1 argument to fbo.validate");

	struct vc_extraspace *es = *(struct vc_extraspace **)(lua_getextraspace(L));
	if(es->fbo == -1)
		return luaL_error(L, "this state does not support rendering");

	GLuint fbo = lua_tointeger(L, 1);

	if(fbo > 0)
		glBindFramebuffer(GL_FRAMEBUFFER, fbo);
	else
		glBindFramebuffer(GL_FRAMEBUFFER, es->fbo);
	lua_pushboolean(L, glCheckFramebufferStatus(GL_FRAMEBUFFER) == GL_FRAMEBUFFER_COMPLETE);
	//printf("%04X\n", glCheckFramebufferStatus(GL_FRAMEBUFFER));
	glBindFramebuffer(GL_FRAMEBUFFER, es->fbo);

	return 1;
}

void lbind_setup_fbo(lua_State *L)
{
	lua_newtable(L);
	lua_pushcfunction(L, lbind_fbo_new); lua_setfield(L, -2, "new");
	lua_pushcfunction(L, lbind_fbo_bind_tex); lua_setfield(L, -2, "bind_tex");
	lua_pushcfunction(L, lbind_fbo_target_set); lua_setfield(L, -2, "target_set");
	lua_pushcfunction(L, lbind_fbo_validate); lua_setfield(L, -2, "validate");
	lua_setglobal(L, "fbo");
}

