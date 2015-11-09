#include "common.h"

// TODO: port this to Lua
// (we can port it back later)

void fill_voxygen_subchunk(uint8_t **voxygen_buf, int layer, int sx, int sy, int sz, uint8_t c)
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
	voxygen_buf[layer][(sx>>layer)+lsize*((sz>>layer)+lsize*(sy>>layer))] = c;

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

		fill_voxygen_subchunk(voxygen_buf, layer, sx+l0, sy+l0, sz+l0, c);
		fill_voxygen_subchunk(voxygen_buf, layer, sx+l1, sy+l0, sz+l0, c);
		fill_voxygen_subchunk(voxygen_buf, layer, sx+l0, sy+l0, sz+l1, c);
		fill_voxygen_subchunk(voxygen_buf, layer, sx+l1, sy+l0, sz+l1, c);
		fill_voxygen_subchunk(voxygen_buf, layer, sx+l0, sy+l1, sz+l0, c);
		fill_voxygen_subchunk(voxygen_buf, layer, sx+l1, sy+l1, sz+l0, c);
		fill_voxygen_subchunk(voxygen_buf, layer, sx+l0, sy+l1, sz+l1, c);
		fill_voxygen_subchunk(voxygen_buf, layer, sx+l1, sy+l1, sz+l1, c);
	}
}

void decode_voxygen_subchunk(uint8_t **voxygen_buf, FILE *fp, int layer, int sx, int sy, int sz)
{
	int c = fgetc(fp);
	assert(c >= 0);
	assert(c <= 0xFF); // juuuuust in case your libc sucks (this IS being overcautious though)
	assert((c & 0x40) == 0);

	if((c & 0x80) != 0)
	{
		assert(layer > 0);

		// Write
		int lsize = 128>>layer;
		voxygen_buf[layer][(sx>>layer)+lsize*((sz>>layer)+lsize*(sy>>layer))] = c;

		// Descend
		layer--;
		int l0 = 0;
		int l1 = 1<<layer;
		decode_voxygen_subchunk(voxygen_buf, fp, layer, sx+l0, sy+l0, sz+l0);
		decode_voxygen_subchunk(voxygen_buf, fp, layer, sx+l0, sy+l1, sz+l0);
		decode_voxygen_subchunk(voxygen_buf, fp, layer, sx+l1, sy+l0, sz+l0);
		decode_voxygen_subchunk(voxygen_buf, fp, layer, sx+l1, sy+l1, sz+l0);
		decode_voxygen_subchunk(voxygen_buf, fp, layer, sx+l0, sy+l0, sz+l1);
		decode_voxygen_subchunk(voxygen_buf, fp, layer, sx+l0, sy+l1, sz+l1);
		decode_voxygen_subchunk(voxygen_buf, fp, layer, sx+l1, sy+l0, sz+l1);
		decode_voxygen_subchunk(voxygen_buf, fp, layer, sx+l1, sy+l1, sz+l1);

	} else {
		// Fill
		fill_voxygen_subchunk(voxygen_buf, layer, sx, sy, sz, c);
	}

}

void decode_voxygen_chunk(uint8_t **voxygen_buf, FILE *fp)
{
	int sx, sy, sz;

	for(sz = 0; sz < 128; sz += 16)
	for(sx = 0; sx < 128; sx += 16)
	for(sy = 0; sy < 128; sy += 16)
		decode_voxygen_subchunk(voxygen_buf, fp, 4, sx, sy, sz);
}

void voxygen_load_repeated_chunk(const char *fname)
{
	glGetError();

	FILE *fp = fopen("dat/voxel1.voxygen", "rb");

	// TODO: load more than a chunk
	// Layer 1: 128^3 chunks in a [z][x]
	// Layer 2: 32^3 outer layers in a 4^3 arrangement [z][x][y]
	// Layer 3: Descend the damn layers
	// in this engine we rearrange it to [y][z][x]
	int cx, cz;
	const int cy = 0;
	int sx, sy, sz;
	uint8_t *voxygen_buf[5];

	// TODO: shift *all* the voxygen stuff into src/voxel.c
	voxygen_buf[0] = malloc(128*128*128);
	voxygen_buf[1] = malloc(64*64*64);
	voxygen_buf[2] = malloc(32*32*32);
	voxygen_buf[3] = malloc(16*16*16);
	voxygen_buf[4] = malloc(8*8*8);

	printf("Decoding voxel data\n");

	decode_voxygen_chunk(voxygen_buf, fp);

	printf("Uploading voxel data\n");
	int layer;
	for(layer = 0; layer <= 4; layer++)
	{
		int lsize = 128>>layer;
		int ly = 128*2-(lsize*2);
		for(sz = 0; sz < 512; sz += lsize)
		for(sx = 0; sx < 512; sx += lsize)
		for(sy = 0; sy < lsize; sy += lsize)
		{
			glTexSubImage3D(GL_TEXTURE_3D, 0, sx, sz, sy + ly, lsize, lsize, lsize, GL_RED_INTEGER, GL_UNSIGNED_BYTE, voxygen_buf[layer]);
			//printf("%i - %i %i %i %i\n", glGetError(), sx, sy, sz, ly);
		}
	}
	printf("Freeing voxel data\n");

	free(voxygen_buf[0]);
	free(voxygen_buf[1]);
	free(voxygen_buf[2]);
	free(voxygen_buf[3]);
	free(voxygen_buf[4]);

	fclose(fp);

	int err = glGetError();
	printf("tex_vox %i\n", err);
	assert(err == 0);
}

