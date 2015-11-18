#include "common.h"

char *fs_bin_load_direct(const char *fname, size_t *len)
{
	// AVOID CALLING THIS DIRECTLY IT'S DANGEROUS
	// (although right now it's the only option)

	FILE *fp = fopen(fname, "rb");
	if(fp == NULL)
		return NULL;
	
	size_t totlen = 0;
	char *buf = malloc(1024);
	buf[0] = '\x00';

	//printf("{%s}\n", fname);
	for(;;)
	{
		char subbuf[1025];
		size_t res = fread(subbuf, 1, 1024, fp);
		//printf("%li\n", res);
		if(res == -1)
			break;
		if(res == 0)
			break;

		//printf("{%s}\n", subbuf);
		subbuf[res] = '\x00';
		buf = realloc(buf, totlen+res+1024);
		assert(buf != NULL);

		memcpy(buf+totlen, subbuf, res);
		totlen += res;
		buf[totlen] = '\x00';
	}

	fclose(fp);

	*len = totlen;
	return buf;
}

