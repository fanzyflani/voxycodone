#include "common.h"

static void fill_voxdata_subchunk(uint8_t **voxdata_buf, int layer, int sx, int sy, int sz, uint8_t c)
{
	int lsize = 128>>layer;
	assert(layer >= 0);
	assert(layer <= 4);
	assert((sx>>layer) >= 0);
	assert((sy>>layer) >= 0);
	assert((sz>>layer) >= 0);
	assert((sx>>layer) < (128>>layer));
	assert((sy>>layer) < (128>>layer));
	assert((sz>>layer) < (128>>layer));
	assert((sx>>layer)+lsize*((sz>>layer)+lsize*(sy>>layer)) >= 0);
	assert((sx>>layer)+lsize*((sz>>layer)+lsize*(sy>>layer)) < (128>>layer)*(128>>layer)*(128>>layer));
	assert((c & 0x80) == 0);
	//if(layer == 0) c &= ~0x80;
	voxdata_buf[layer][(sx>>layer)+lsize*((sz>>layer)+lsize*(sy>>layer))] = c;

	if(layer > 0)
	{
		layer--;
		assert((c & 0x80) == 0);
		//c &= ~0x80;

		c |= 0x40;
		/*
		if((c & 0x40) == 0)
		{
			c = 0x40 + (layer+1);
		}
		*/

		int l0 = 0;
		int l1 = 1<<layer;

		fill_voxdata_subchunk(voxdata_buf, layer, sx+l0, sy+l0, sz+l0, c);
		fill_voxdata_subchunk(voxdata_buf, layer, sx+l1, sy+l0, sz+l0, c);
		fill_voxdata_subchunk(voxdata_buf, layer, sx+l0, sy+l0, sz+l1, c);
		fill_voxdata_subchunk(voxdata_buf, layer, sx+l1, sy+l0, sz+l1, c);
		fill_voxdata_subchunk(voxdata_buf, layer, sx+l0, sy+l1, sz+l0, c);
		fill_voxdata_subchunk(voxdata_buf, layer, sx+l1, sy+l1, sz+l0, c);
		fill_voxdata_subchunk(voxdata_buf, layer, sx+l0, sy+l1, sz+l1, c);
		fill_voxdata_subchunk(voxdata_buf, layer, sx+l1, sy+l1, sz+l1, c);
	}
}

static void decode_voxdata_subchunk(uint8_t **voxdata_buf, const char *fdata, size_t fdlen, off_t *fdoffs, int layer, int sx, int sy, int sz)
{
	assert(*fdoffs < fdlen);
	int c = (int)fdata[(*fdoffs)++];
	assert((c & 0x40) == 0);

	if((c & 0x80) != 0)
	{
		assert(layer > 0);

		// Write
		int lsize = 128>>layer;
		voxdata_buf[layer][(sx>>layer)+lsize*((sz>>layer)+lsize*(sy>>layer))] = c;

		// Descend
		layer--;
		int l0 = 0;
		int l1 = 1<<layer;
		decode_voxdata_subchunk(voxdata_buf, fdata, fdlen, fdoffs, layer, sx+l0, sy+l0, sz+l0);
		decode_voxdata_subchunk(voxdata_buf, fdata, fdlen, fdoffs, layer, sx+l0, sy+l1, sz+l0);
		decode_voxdata_subchunk(voxdata_buf, fdata, fdlen, fdoffs, layer, sx+l1, sy+l0, sz+l0);
		decode_voxdata_subchunk(voxdata_buf, fdata, fdlen, fdoffs, layer, sx+l1, sy+l1, sz+l0);
		decode_voxdata_subchunk(voxdata_buf, fdata, fdlen, fdoffs, layer, sx+l0, sy+l0, sz+l1);
		decode_voxdata_subchunk(voxdata_buf, fdata, fdlen, fdoffs, layer, sx+l0, sy+l1, sz+l1);
		decode_voxdata_subchunk(voxdata_buf, fdata, fdlen, fdoffs, layer, sx+l1, sy+l0, sz+l1);
		decode_voxdata_subchunk(voxdata_buf, fdata, fdlen, fdoffs, layer, sx+l1, sy+l1, sz+l1);

	} else {
		// Fill
		fill_voxdata_subchunk(voxdata_buf, layer, sx, sy, sz, c);
	}
}

static void decode_voxdata_chunk(uint8_t **voxdata_buf, const char *fdata, size_t fdlen, off_t *fdoffs)
{
	int sx, sy, sz;

	for(sz = 0; sz < 128; sz += 16)
	for(sx = 0; sx < 128; sx += 16)
	for(sy = 0; sy < 128; sy += 16)
		decode_voxdata_subchunk(voxdata_buf, fdata, fdlen, fdoffs, 4, sx, sy, sz);
}

static int lbind_voxel_decode_chunk(lua_State *L)
{
	const char *fdata;
	size_t fdlen;
	uint8_t *voxdata_buf[5];
	int i, layer;

	if(lua_gettop(L) < 1)
		return luaL_error(L, "expected 1 argument to voxel.decode_chunk");

	fdata = luaL_tolstring(L, 1, &fdlen);
	if(fdata == NULL)
		return luaL_error(L, "expected string for argument 1");

	voxdata_buf[0] = malloc(128*128*128);
	voxdata_buf[1] = malloc(64*64*64);
	voxdata_buf[2] = malloc(32*32*32);
	voxdata_buf[3] = malloc(16*16*16);
	voxdata_buf[4] = malloc(8*8*8);

	off_t fdoffs = 0;
	decode_voxdata_chunk(voxdata_buf, fdata, fdlen, &fdoffs);

	//printf("Copying temp voxel data\n");
	lua_newtable(L);
	for(layer = 0; layer <= 4; layer++)
	{
		lua_newtable(L);

		for(i = 0; i < ((1<<(7*3))>>(layer*3)); i++)
		{
			lua_pushinteger(L, voxdata_buf[layer][i]);
			lua_seti(L, -2, i+1);
		}

		lua_seti(L, -2, layer+1);
	}

	//printf("Freeing temp voxel data\n");

	free(voxdata_buf[0]);
	free(voxdata_buf[1]);
	free(voxdata_buf[2]);
	free(voxdata_buf[3]);
	free(voxdata_buf[4]);

	return 1;
}

static int lbind_voxel_upload_chunk_repeated(lua_State *L)
{
	// TODO: load more than a chunk
	// Layer 1: 128^3 chunks in a [z][x]
	// Layer 2: 32^3 outer layers in a 4^3 arrangement [z][x][y]
	// Layer 3: Descend the damn layers
	// in this engine we rearrange it to [y][z][x]
	int cx, cz;
	const int cy = 0;
	int sx, sy, sz;
	uint8_t *voxdata_buf[5];
	int i, layer;

	if(lua_gettop(L) < 2)
		return luaL_error(L, "expected 2 arguments to voxel.upload_chunk_repeated");

	voxdata_buf[0] = malloc(128*128*128);
	voxdata_buf[1] = malloc(64*64*64);
	voxdata_buf[2] = malloc(32*32*32);
	voxdata_buf[3] = malloc(16*16*16);
	voxdata_buf[4] = malloc(8*8*8);

	//printf("Copying temp voxel data\n");

	lua_newtable(L);
	for(layer = 0; layer <= 4; layer++)
	{
		lua_geti(L, 2, layer+1);

		for(i = 0; i < ((1<<(7*3))>>(layer*3)); i++)
		{
			lua_geti(L, -1, i+1);
			voxdata_buf[layer][i] = lua_tointeger(L, -1);
			lua_pop(L, 1);
		}

		lua_pop(L, 1);
	}

	//printf("Uploading voxel data\n");
	glBindTexture(GL_TEXTURE_3D, lua_tointeger(L, 1));
	for(layer = 0; layer <= 4; layer++)
	{
		int lsize = 128>>layer;
		int ly = 128*2-(lsize*2);
		for(sz = 0; sz < 512; sz += lsize)
		for(sx = 0; sx < 512; sx += lsize)
		for(sy = 0; sy < lsize; sy += lsize)
		{
			glTexSubImage3D(GL_TEXTURE_3D, 0, sx, sz, sy + ly, lsize, lsize, lsize, GL_RED_INTEGER, GL_UNSIGNED_BYTE, voxdata_buf[layer]);
			//printf("%i - %i %i %i %i\n", glGetError(), sx, sy, sz, ly);
		}
	}
	glBindTexture(GL_TEXTURE_3D, 0);

	//printf("Freeing temp voxel data\n");
	free(voxdata_buf[0]);
	free(voxdata_buf[1]);
	free(voxdata_buf[2]);
	free(voxdata_buf[3]);
	free(voxdata_buf[4]);

	//int err = glGetError();
	//printf("tex_vox %i\n", err);
	//assert(err == 0);

	return 0;
}

void lbind_setup_voxel(lua_State *L)
{
	lua_newtable(L);
	lua_pushcfunction(L, lbind_voxel_decode_chunk); lua_setfield(L, -2, "decode_chunk");
	lua_pushcfunction(L, lbind_voxel_upload_chunk_repeated); lua_setfield(L, -2, "upload_chunk_repeated");
	lua_setglobal(L, "voxel");
}

