// tools/toraw normandie.vxl | python -c 'import sys, zlib; sys.stdout.write(zlib.compress(sys.stdin.read()))' > root/game/test.dat
#include <string.h>
#include <stdlib.h>
#include <stdint.h>
#include <stdio.h>
#include <errno.h>

#include <assert.h>

uint8_t rawdata0[512][512][256];
uint8_t rawdata1[256][256][128];
uint8_t rawdata2[128][128][64];
uint8_t rawdata3[64][64][32];
uint8_t rawdata4[32][32][16];
uint8_t rawdata5[16][16][8];

int main(int argc, char *argv[])
{
	int x, y, z, i;

	// load vxl data
	FILE *fp = fopen(argv[1], "rb");
	fprintf(stderr, "loading vxl data\n");

	for(y = 0; y < 512; y++)
	for(x = 0; x < 512; x++)
	{
		int n,s,e,a;
		n = fgetc(fp);
		s = fgetc(fp);
		e = fgetc(fp);
		a = fgetc(fp);

		z = 0;
		for(;;)
		{
			for(; z < s; z++) rawdata0[y][x][z] = 0x01;
			assert(n >= 0);
			if(n == 0)
			{
				for(i = 0; i < (e-s+1)*4; i++) fgetc(fp);
				for(; z < 256; z++) rawdata0[y][x][z] = 0x00;
				break;
			}
			for(i = 0; i < (n-1)*4; i++) fgetc(fp);
			n = fgetc(fp);
			s = fgetc(fp);
			e = fgetc(fp);
			a = fgetc(fp);
			for(; z < a; z++) rawdata0[y][x][z] = 0x00;
		}
	}

	// octree
	fprintf(stderr, "building octree - narrowing\n");
#define BUILD_OCTREE_NARROW(dst,src,lvl,lz,ly,lx) \
	fprintf(stderr, "pass %i\n", lvl); \
	for(y = 0; y < ly; y++) \
	for(x = 0; x < lx; x++) \
	for(z = 0; z < lz; z++) \
	{ \
		int sx0 = x<<1; \
		int sy0 = y<<1; \
		int sz0 = z<<1; \
		int ipass = 1; \
		int tx, ty, tz; \
		for(tz = 0; tz < 2; tz++) \
		for(ty = 0; ty < 2; ty++) \
		for(tx = 0; tx < 2; tx++) \
		{ \
			int cv = src[sy0+ty][sx0+tx][sz0+tz]; \
			if(cv == 0) \
			{ \
				ipass = 0; \
			} \
		} \
		dst[y][x][z] = (ipass ? lvl+1 : 0); \
	}

	BUILD_OCTREE_NARROW(rawdata1, rawdata0, 1, 128, 256, 256)
	BUILD_OCTREE_NARROW(rawdata2, rawdata1, 2, 64, 128, 128)
	BUILD_OCTREE_NARROW(rawdata3, rawdata2, 3, 32, 64, 64)
	BUILD_OCTREE_NARROW(rawdata4, rawdata3, 4, 16, 32, 32)
	BUILD_OCTREE_NARROW(rawdata5, rawdata4, 5, 8, 16, 16)

	fprintf(stderr, "building octree - widening\n");
#define BUILD_OCTREE_WIDEN(src,dst,lvl,lz,ly,lx) \
	fprintf(stderr, "pass %i\n", lvl); \
	for(y = 0; y < ly; y++) \
	for(x = 0; x < lx; x++) \
	for(z = 0; z < lz; z++) \
	{ \
		int dx0 = x<<1; \
		int dy0 = y<<1; \
		int dz0 = z<<1; \
		int tx, ty, tz; \
		int sb = src[y][x][z]; \
		if(sb != 0) \
		{ \
			for(tz = 0; tz < 2; tz++) \
			for(ty = 0; ty < 2; ty++) \
			for(tx = 0; tx < 2; tx++) \
			{ \
				dst[dy0+ty][dx0+tx][dz0+tz] = sb; \
			} \
		} \
	}

	BUILD_OCTREE_WIDEN(rawdata5, rawdata4, 5, 8, 16, 16)
	BUILD_OCTREE_WIDEN(rawdata4, rawdata3, 4, 16, 32, 32)
	BUILD_OCTREE_WIDEN(rawdata3, rawdata2, 3, 32, 64, 64)
	BUILD_OCTREE_WIDEN(rawdata2, rawdata1, 2, 64, 128, 128)
	BUILD_OCTREE_WIDEN(rawdata1, rawdata0, 1, 128, 256, 256)

	// write to stdout
	fprintf(stderr, "writing output\n");
	fprintf(stderr, "pass 0\n"); fwrite(rawdata0, (512*512*256)>>(3*0), 1, stdout);
	fprintf(stderr, "pass 1\n"); fwrite(rawdata1, (512*512*256)>>(3*1), 1, stdout);
	fprintf(stderr, "pass 2\n"); fwrite(rawdata2, (512*512*256)>>(3*2), 1, stdout);
	fprintf(stderr, "pass 3\n"); fwrite(rawdata3, (512*512*256)>>(3*3), 1, stdout);
	fprintf(stderr, "pass 4\n"); fwrite(rawdata4, (512*512*256)>>(3*4), 1, stdout);
	fprintf(stderr, "pass 5\n"); fwrite(rawdata5, (512*512*256)>>(3*5), 1, stdout);

	fprintf(stderr, "done!\n");

	return 0;
}

