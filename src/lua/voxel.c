#include "common.h"

static int lbind_voxel_build_density_map(lua_State *L)
{
	size_t i;

	int tex;
	int levels;
	size_t xlen, ylen, zlen;

	if(lua_gettop(L) < 5)
		return luaL_error(L, "expected 5 arguments to voxel.build_density_map");

	// Get inputs
	int *p_tex = luaL_checkudata(L, 1, "GLtex");
	tex = *p_tex;
	xlen = lua_tointeger(L, 2);
	ylen = lua_tointeger(L, 3);
	zlen = lua_tointeger(L, 4);
	size_t dbufsz;
	const char *data = luaL_checklstring(L, 5, &dbufsz);
	
	if(xlen < 1 || ylen < 1 || zlen < 1)
		return luaL_error(L, "invalid dimensions");
	if(xlen > 8192 || ylen > 8192 || zlen > 8192) // note, this is rather arbitrary
		return luaL_error(L, "invalid dimensions");

	// Get size
	size_t rlen2 = xlen*ylen;
	if(rlen2 < xlen || rlen2 < ylen)
		return luaL_error(L, "multiply overflow");
	size_t rlen = rlen2*zlen;
	if(rlen < rlen2 || rlen < zlen)
		return luaL_error(L, "multiply overflow");
	if(rlen*2 < rlen)
		return luaL_error(L, "multiply overflow");
	
	// Check length
	if(dbufsz < rlen)
		return luaL_error(L, "string not long enough to fill buffer");

	// Unpack data to unsigned shorts
	uint16_t *sdata = malloc(rlen*2);
	for(i = 0; i < rlen; i++)
		sdata[i] = (data[i] == 0 ? 0xFFFF : 0x0000);

	// Upload to card
	glBindTexture(GL_TEXTURE_3D, tex);
	glTexSubImage3D(GL_TEXTURE_3D, 0, 0, 0, 0, xlen, ylen, zlen,
		GL_RED, GL_UNSIGNED_SHORT, (void *)sdata);
	glBindTexture(GL_TEXTURE_3D, 0);

	// Free data
	free(sdata);

	return 0;
}

void lbind_setup_voxel(lua_State *L)
{
	lua_newtable(L);
	lua_pushcfunction(L, lbind_voxel_build_density_map); lua_setfield(L, -2, "build_density_map");
	lua_setglobal(L, "voxel");
}

