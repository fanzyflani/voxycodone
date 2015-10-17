#include "common.h"

int sph_count = 0;
float sph_data[SPH_MAX*4];
struct sph sph_list[SPH_MAX];

void sph_set(int i, double x, double y, double z, double rad, int r, int g, int b, int a)
{
	assert(i < SPH_MAX);
	assert(i >= 0);
	sph_list[i].idx = i;
	sph_list[i].v[0] = x;
	sph_list[i].v[1] = y;
	sph_list[i].v[2] = z;
	sph_list[i].rad = rad;

	if(r < 0) r = 0; if(r > 255) r = 255;
	if(g < 0) g = 0; if(g > 255) g = 255;
	if(b < 0) b = 0; if(b > 255) b = 255;
	if(a < 0) a = 0; if(a > 255) a = 255;

	sph_list[i].rgba = r + g*0x100 + b*0x10000 + a*0x1000000;

	sph_data[4*i + 0] = x;
	sph_data[4*i + 1] = y;
	sph_data[4*i + 2] = z;
	sph_data[4*i + 3] = rad;
}

