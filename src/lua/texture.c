#include "common.h"

GLenum texture_get_target(lua_State *L, const char *fmt)
{
	if(fmt == NULL) fmt = "*** INVALID";

	if(fmt[0] == '1')
	{
		if(fmt[1] == '\x00')
			return GL_TEXTURE_1D;
		else if(fmt[1] == 'a' && fmt[2] == '\x00')
			return GL_TEXTURE_1D_ARRAY;

	} else if(fmt[0] == '2') {
		if(fmt[1] == '\x00')
			return GL_TEXTURE_2D;
		else if(fmt[1] == 'a' && fmt[2] == '\x00')
			return GL_TEXTURE_2D_ARRAY;

	} else if(fmt[0] == '3') {
		if(fmt[1] == '\x00')
			return GL_TEXTURE_3D;
	}

	luaL_error(L, "unexpected GL target format \"%s\"", fmt);
	return GL_FALSE;
}

static GLenum texture_get_internal_fmt(lua_State *L, const char *fmt)
{
	if(fmt == NULL) fmt = "*** INVALID";

	static const struct {
		const char *str;
		GLenum val;
	} fmt_list[] = {
		{"1f", GL_R32F}, {"2f", GL_RG32F}, {"3f", GL_RGB32F}, {"4f", GL_RGBA32F},

		{"1i", GL_R32I}, {"2i", GL_RG32I}, {"3i", GL_RGB32I}, {"4i", GL_RGBA32I},
		{"1s", GL_R16I}, {"2s", GL_RG16I}, {"3s", GL_RGB16I}, {"4s", GL_RGBA16I},
		{"1b", GL_R8I}, {"2b", GL_RG8I}, {"3b", GL_RGB8I}, {"4b", GL_RGBA8I},

		{"1ui", GL_R32UI}, {"2ui", GL_RG32UI}, {"3ui", GL_RGB32UI}, {"4ui", GL_RGBA32UI},
		{"1us", GL_R16UI}, {"2us", GL_RG16UI}, {"3us", GL_RGB16UI}, {"4us", GL_RGBA16UI},
		{"1ub", GL_R8UI}, {"2ub", GL_RG8UI}, {"3ub", GL_RGB8UI}, {"4ub", GL_RGBA8UI},

		{"1ns", GL_R16}, {"2ns", GL_RG16}, {"3ns", GL_RGB16}, {"4ns", GL_RGBA16},
		{"1nb", GL_R8}, {"2nb", GL_RG8}, {"3nb", GL_RGB8}, {"4nb", GL_RGBA8},

		{"1Ns", GL_R16_SNORM}, {"2Ns", GL_RG16_SNORM}, {"3Ns", GL_RGB16_SNORM},
		{"4Ns", GL_RGBA16_SNORM}, // WARNING: THIS MIGHT NOT ACTUALLY EXIST. It compiles though!
		{"1Nb", GL_R8_SNORM}, {"2Nb", GL_RG8_SNORM}, {"3Nb", GL_RGB8_SNORM}, {"4Nb", GL_RGBA8_SNORM},

		{NULL, 0}
	};

	int i;
	for(i = 0; fmt_list[i].str != NULL; i++)
		if(!strcmp(fmt_list[i].str, fmt))
			return fmt_list[i].val;

	luaL_error(L, "unexpected GL internal format \"%s\"", fmt);
	return GL_FALSE;

}

static void texture_get_data_fmt(lua_State *L, const char *fmt,
	GLenum *format, GLenum *typ, size_t *cmps, size_t *ebytes)
{
	if(fmt == NULL) fmt = "*** INVALID";

	if(fmt[0] == '1') *cmps = 1;
	else if(fmt[0] == '2') *cmps = 2;
	else if(fmt[0] == '3') *cmps = 3;
	else if(fmt[0] == '4') *cmps = 4;
	else luaL_error(L, "invalid component count for data format");

	*ebytes = 0;
	int is_float = (fmt[1] == 'f');
	int is_normalised = (fmt[1] == 'n' || fmt[1] == 'N');
	int is_unsigned = (fmt[1] == 'u' || fmt[1] == 'n');

	if(fmt[1] == 'f') *ebytes = 4;
	else if(fmt[1] == 'i') *ebytes = 4;
	else if(fmt[1] == 's') *ebytes = 2;
	else if(fmt[1] == 'b') *ebytes = 1;
	else if(fmt[1] == 'u') {
		if(fmt[2] == 'i') *ebytes = 4;
		else if(fmt[2] == 's') *ebytes = 2;
		else if(fmt[2] == 'b') *ebytes = 1;
	} else if( fmt[1] == 'n' || fmt[1] == 'N') {
		if(fmt[2] == 's') *ebytes = 2;
		else if(fmt[2] == 'b') *ebytes = 1;
	}

	if(*ebytes == 0)
		luaL_error(L, "invalid byte count for data format");

	if(is_float || is_normalised)
	{
		switch(*cmps)
		{
			case 1: *format = GL_RED; break;
			case 2: *format = GL_RG; break;
			case 3: *format = GL_RGB; break;
			case 4: *format = GL_RGBA; break;
			default: luaL_error(L, "EDOOFUS invalid component count"); break;
		}
	} else {
		switch(*cmps)
		{
			case 1: *format = GL_RED_INTEGER; break;
			case 2: *format = GL_RG_INTEGER; break;
			case 3: *format = GL_RGB_INTEGER; break;
			case 4: *format = GL_RGBA_INTEGER; break;
			default: luaL_error(L, "EDOOFUS invalid component count"); break;
		}
	}

	if(is_float)
	{
		switch(*ebytes)
		{
			case 4: *typ = GL_FLOAT; break;
			default: luaL_error(L, "EDOOFUS invalid elem byte count"); break;
		}

	} else if(is_unsigned) {
		switch(*ebytes)
		{
			case 1: *typ = GL_UNSIGNED_BYTE; break;
			case 2: *typ = GL_UNSIGNED_SHORT; break;
			case 4: *typ = GL_UNSIGNED_INT; break;
			default: luaL_error(L, "EDOOFUS invalid elem byte count"); break;
		}

	} else {
		switch(*ebytes)
		{
			case 1: *typ = GL_BYTE; break;
			case 2: *typ = GL_SHORT; break;
			case 4: *typ = GL_INT; break;
			default: luaL_error(L, "EDOOFUS invalid elem byte count"); break;
		}
	}
}

static int lbind_texture_unit_set(lua_State *L)
{
	if(lua_gettop(L) < 3)
		return luaL_error(L, "expected 3 arguments to texture.unit_set");

	int unit = lua_tointeger(L, 1);
	const char *tex_fmt_str = lua_tostring(L, 2);
	GLenum tex_target = texture_get_target(L, tex_fmt_str);
	int tex = lua_tointeger(L, 3);

	glActiveTexture(GL_TEXTURE0 + unit);
	glBindTexture(tex_target, tex);
	glActiveTexture(GL_TEXTURE0);

	return 0;
}

static int lbind_texture_load_sub(lua_State *L)
{
	int i;

	if(lua_gettop(L) < 7)
		return luaL_error(L, "expected at least 7 arguments to texture.load_sub");

	int tex = lua_tointeger(L, 1);
	const char *tex_fmt_str = lua_tostring(L, 2);
	GLenum tex_target = texture_get_target(L, tex_fmt_str);
	int dims = tex_fmt_str[0] - '0';
	if(tex_fmt_str[1] == 'a') dims++;
	int level = lua_tointeger(L, 3);
	assert(dims >= 1 && dims <= 3);

	if(lua_gettop(L) < 5 + 2*dims)
		return luaL_error(L, "expected %d arguments to texture.load_sub", 5 + 2*dims);

	// yeah yeah this is an arbitrary limit that doesn't necessarily hold
	if(level < 0 || level >= 16)
		return luaL_error(L, "invalid texture level");

	const char *data_fmt_str = lua_tostring(L, 4+dims*2);
	GLenum data_fmt_format;
	GLenum data_fmt_typ;
	size_t data_fmt_cmps;
	size_t data_fmt_ebytes;
	texture_get_data_fmt(L, data_fmt_str, &data_fmt_format, &data_fmt_typ,
		&data_fmt_cmps, &data_fmt_ebytes);
	int xoffs = (dims < 1 ? 0 : lua_tointeger(L, 4));
	int yoffs = (dims < 2 ? 0 : lua_tointeger(L, 5));
	int zoffs = (dims < 3 ? 0 : lua_tointeger(L, 6));
	int xlen = (dims < 1 ? 1 : lua_tointeger(L, 4+dims));
	int ylen = (dims < 2 ? 1 : lua_tointeger(L, 5+dims));
	int zlen = (dims < 3 ? 1 : lua_tointeger(L, 6+dims));
	int aidx = dims*2 + 5;

	if(xlen < 1 || ylen < 1 || zlen < 1)
		return luaL_error(L, "invalid texture size");
	if(xoffs < 0 || yoffs < 0 || zoffs < 0)
		return luaL_error(L, "invalid texture offset");

	// The overlooked source of buffer overflow exploits
	size_t belems = ((size_t)xlen) * ((size_t)ylen);
	if(belems < xlen || belems < ylen)
		return luaL_error(L, "texture size overflow");
	size_t old_belems = belems;
	belems *= ((size_t)zlen);
	if(belems < zlen || belems < old_belems)
		return luaL_error(L, "texture size overflow");

	size_t becount = belems * data_fmt_cmps;
	if(becount < belems || becount < data_fmt_cmps)
		return luaL_error(L, "texture size overflow");

	size_t btotal = becount * data_fmt_ebytes;
	if(btotal < becount || btotal < data_fmt_ebytes)
		return luaL_error(L, "texture size overflow");

	// XXX: Do we use rawlen/rawgeti instead of len/geti?
	lua_len(L, aidx);
	size_t len = lua_tointeger(L, -1);
	lua_pop(L, 1);
	if(len < becount)
		return luaL_error(L, "not enough elements in texture array to fill buffer");

	// TODO: use directly-mapped PBOs so we don't have to malloc
	void *data = malloc(btotal);
	if(data == NULL)
		return luaL_error(L, "could not allocate temp buffer for texture");

	glBindTexture(tex_target, tex);

	switch(data_fmt_typ)
	{
		case GL_FLOAT:
			for(i = 0; i < becount; i++)
			{
				lua_geti(L, aidx, i+1);
				float f = lua_tonumber(L, -1);
				lua_pop(L, 1);
				((float *)data)[i] = f;
			}
			break;

		case GL_BYTE:
			for(i = 0; i < becount; i++)
			{
				lua_geti(L, aidx, i+1);
				int32_t f = lua_tointeger(L, -1);
				lua_pop(L, 1);
				((int8_t *)data)[i] = f;
			}
			break;

		case GL_SHORT:
			for(i = 0; i < becount; i++)
			{
				lua_geti(L, aidx, i+1);
				int32_t f = lua_tointeger(L, -1);
				lua_pop(L, 1);
				((int16_t *)data)[i] = f;
			}
			break;

		case GL_INT:
			for(i = 0; i < becount; i++)
			{
				lua_geti(L, aidx, i+1);
				int32_t f = lua_tointeger(L, -1);
				lua_pop(L, 1);
				((int32_t *)data)[i] = f;
			}
			break;

		case GL_UNSIGNED_BYTE:
			for(i = 0; i < becount; i++)
			{
				lua_geti(L, aidx, i+1);
				uint32_t f = lua_tointeger(L, -1);
				lua_pop(L, 1);
				((uint8_t *)data)[i] = f;
			}
			break;

		case GL_UNSIGNED_SHORT:
			for(i = 0; i < becount; i++)
			{
				lua_geti(L, aidx, i+1);
				uint32_t f = lua_tointeger(L, -1);
				lua_pop(L, 1);
				((uint16_t *)data)[i] = f;
			}
			break;

		case GL_UNSIGNED_INT:
			for(i = 0; i < becount; i++)
			{
				lua_geti(L, aidx, i+1);
				uint32_t f = lua_tointeger(L, -1);
				lua_pop(L, 1);
				((uint32_t *)data)[i] = f;
			}
			break;

		default:
			free(data);
			return luaL_error(L, "TODO support data format \"%s\"", data_fmt_str);
	}

	if(dims == 1)
	{
		//printf("%08X %08X %08X\n", tex_target, data_fmt_format, data_fmt_typ);
		glTexSubImage1D(tex_target, level, xoffs, xlen,
			data_fmt_format, data_fmt_typ, data);

		free(data);

	} else if(dims == 2) {
		//printf("%08X %08X %08X\n", tex_target, data_fmt_format, data_fmt_typ);
		glTexSubImage2D(tex_target, level, xoffs, yoffs, xlen, ylen,
			data_fmt_format, data_fmt_typ, data);

		free(data);

	} else if(dims == 3) {
		glTexSubImage3D(tex_target, level, xoffs, yoffs, zoffs, xlen, ylen, zlen,
			data_fmt_format, data_fmt_typ, data);

		free(data);

	} else {
		free(data);

		return luaL_error(L, "TODO: fill in other dimensions");

	}

	return 0;
}

static int lbind_texture_new(lua_State *L)
{
	int i;

	if(lua_gettop(L) < 6)
		return luaL_error(L, "expected at least 6 arguments to texture.new");

	// we need this for ARB_direct_state_access glCreateTextures!
	// (forward compat, currently not using right now)
	const char *tex_fmt_str = lua_tostring(L, 1);
	int levels = lua_tointeger(L, 2);
	const char *internal_fmt_str = lua_tostring(L, 3);
	GLenum tex_target = texture_get_target(L, tex_fmt_str);
	int dims = tex_fmt_str[0] - '0';
	if(tex_fmt_str[1] == 'a') dims++;
	assert(dims >= 1 && dims <= 3);

	if(lua_gettop(L) < 5+dims)
		return luaL_error(L, "expected %d arguments to texture.new", 5+dims);

	const char *filter_fmt_str = lua_tostring(L, dims+4);
	const char *data_fmt_str = lua_tostring(L, dims+5);

	if(filter_fmt_str == NULL) filter_fmt_str = "*** INVALID";

	GLenum internal_fmt = texture_get_internal_fmt(L, internal_fmt_str);

	// yeah yeah this is an arbitrary limit that doesn't necessarily hold
	if(levels-1 < 0 || levels-1 >= 16)
		return luaL_error(L, "invalid texture level");

	// fun thing, the last argument is only for glTexImage[123]D
	// if we use glTex\(ture\)\=Storage[123]D it's not necessary

	GLuint tex = 0;
	glGenTextures(1, &tex);
	glBindTexture(tex_target, tex);
	glTexParameteri(tex_target, GL_TEXTURE_MAX_LEVEL, levels-1);
	glTexParameteri(tex_target, GL_TEXTURE_WRAP_S, GL_REPEAT);
	glTexParameteri(tex_target, GL_TEXTURE_WRAP_T, GL_REPEAT);
	glTexParameteri(tex_target, GL_TEXTURE_WRAP_R, GL_REPEAT);
	//printf("%04X %u\n", tex_target, tex);

	if(filter_fmt_str[0] == 'n')
		glTexParameteri(tex_target, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
	else if(filter_fmt_str[0] == 'l')
		glTexParameteri(tex_target, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
	else
		return luaL_error(L, "invalid minification filter");

	if(filter_fmt_str[1] == 'n' && filter_fmt_str[2] == '\x00')
		glTexParameteri(tex_target, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
	else if(filter_fmt_str[1] == 'l' && filter_fmt_str[2] == '\x00')
		glTexParameteri(tex_target, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
	else if(filter_fmt_str[1] == 'n' && filter_fmt_str[2] == 'n' && filter_fmt_str[3] == '\x00')
		glTexParameteri(tex_target, GL_TEXTURE_MIN_FILTER, GL_NEAREST_MIPMAP_NEAREST);
	else if(filter_fmt_str[1] == 'n' && filter_fmt_str[2] == 'l' && filter_fmt_str[3] == '\x00')
		glTexParameteri(tex_target, GL_TEXTURE_MIN_FILTER, GL_NEAREST_MIPMAP_LINEAR);
	else if(filter_fmt_str[1] == 'l' && filter_fmt_str[2] == 'n' && filter_fmt_str[3] == '\x00')
		glTexParameteri(tex_target, GL_TEXTURE_MIN_FILTER, GL_LINEAR_MIPMAP_NEAREST);
	else if(filter_fmt_str[1] == 'l' && filter_fmt_str[2] == 'l' && filter_fmt_str[3] == '\x00')
		glTexParameteri(tex_target, GL_TEXTURE_MIN_FILTER, GL_LINEAR_MIPMAP_LINEAR);
	else
		return luaL_error(L, "invalid magnification filter");

	int xlen = (dims < 1 ? 1 : lua_tointeger(L, 4));
	int ylen = (dims < 2 ? 1 : lua_tointeger(L, 5));
	int zlen = (dims < 3 ? 1 : lua_tointeger(L, 6));
	if(xlen < 1 || ylen < 1 || zlen < 1)
		return luaL_error(L, "invalid texture size");

	if(epoxy_has_gl_extension("GL_ARB_texture_storage"))
	{
		if(dims == 1)
			glTexStorage1D(tex_target, levels, internal_fmt, xlen);
		else if(dims == 2)
			glTexStorage2D(tex_target, levels, internal_fmt, xlen, ylen);
		else if(dims == 3)
			glTexStorage3D(tex_target, levels, internal_fmt, xlen, ylen, zlen);
		else
			return luaL_error(L, "TODO: fill in other dimensions");

	} else {
		GLenum data_fmt_format;
		GLenum data_fmt_typ;
		size_t data_fmt_cmps;
		size_t data_fmt_ebytes;
		texture_get_data_fmt(L, data_fmt_str, &data_fmt_format, &data_fmt_typ,
			&data_fmt_cmps, &data_fmt_ebytes);

		if(dims == 1)
			for(i = 0; i < levels; i++)
				glTexImage1D(tex_target, i, internal_fmt, xlen>>i, 0,
					data_fmt_format, data_fmt_typ, NULL);
		else if(dims == 2)
			for(i = 0; i < levels; i++)
				glTexImage2D(tex_target, i, internal_fmt, xlen>>i, ylen>>i, 0,
					data_fmt_format, data_fmt_typ, NULL);
		else if(dims == 3)
			for(i = 0; i < levels; i++)
				glTexImage3D(tex_target, i, internal_fmt, xlen>>i, ylen>>i, zlen>>i, 0,
					data_fmt_format, data_fmt_typ, NULL);
		else
			return luaL_error(L, "TODO: fill in other dimensions");

	}

	lua_pushinteger(L, tex);
	return 1;
}

static int lbind_texture_gen_mipmaps(lua_State *L)
{
	int i;

	if(lua_gettop(L) < 2)
		return luaL_error(L, "expected at least 2 arguments to texture.gen_mipmaps");

	int tex = lua_tointeger(L, 1);
	const char *tex_fmt_str = lua_tostring(L, 2);
	GLenum tex_target = texture_get_target(L, tex_fmt_str);

	glBindTexture(tex_target, tex);
	glGenerateMipmap(tex_target);

	return 0;
}

void lbind_setup_texture(lua_State *L)
{
	lua_newtable(L);
	lua_pushcfunction(L, lbind_texture_new); lua_setfield(L, -2, "new");
	lua_pushcfunction(L, lbind_texture_unit_set); lua_setfield(L, -2, "unit_set");
	lua_pushcfunction(L, lbind_texture_load_sub); lua_setfield(L, -2, "load_sub");
	lua_pushcfunction(L, lbind_texture_gen_mipmaps); lua_setfield(L, -2, "gen_mipmaps");
	lua_setglobal(L, "texture");
}

