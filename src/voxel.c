#include "common.h"

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

