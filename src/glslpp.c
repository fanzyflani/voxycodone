#include "common.h"

char *load_str(const char *fname)
{
	FILE *fp = fopen(fname, "rb");
	size_t dynbuf_len = 0;
	char *dynbuf = malloc(dynbuf_len+1);
	char inbuf[1024];

	for(;;)
	{
		// Fetch
		ssize_t bytes_read = fread(inbuf, 1, 1024, fp);
		assert(bytes_read >= 0);

		// Check for EOF
		if(bytes_read == 0)
			break;

		// Expand
		dynbuf = realloc(dynbuf, dynbuf_len + bytes_read + 1);

		// Copy
		memcpy(dynbuf + dynbuf_len, inbuf, bytes_read);
		dynbuf_len += bytes_read;
	}
	dynbuf[dynbuf_len] = '\x00';

	fclose(fp);
	return dynbuf;
}

char *glslpp_load_str(const char *fname, size_t *len)
{
	printf("Loading GLSL shader \"%s\"\n", fname);

	FILE *fp = fopen(fname, "rb");
	size_t dynbuf_len = 0;
	char *dynbuf = malloc(dynbuf_len+1);
	char inbuf[1024];

	for(;;)
	{
		// Fetch
		const char *res = fgets(inbuf, 1024, fp);
		if(feof(fp)) break;
		assert(res != NULL);
		size_t bytes_read = strlen(inbuf);
		char *psrc = inbuf;
		size_t psrc_len = bytes_read;
		int free_psrc = false;

		// TODO: parse
		if(res[0] == '%')
		{
			if(!strncmp(res+1, "include ", 8))
			{
				// TODO: include
				inbuf[bytes_read-1] = '\x00'; // chop off newline
				psrc = glslpp_load_str(inbuf+1+8, &psrc_len);
				free_psrc = true;

			} else {
				printf("INVALID PREPROC STATEMENT: %s\n", res);
				assert(false);
			}
		}

		// Expand
		dynbuf = realloc(dynbuf, dynbuf_len + psrc_len + 1);

		// Copy
		memcpy(dynbuf + dynbuf_len, psrc, psrc_len);
		dynbuf_len += psrc_len;

		if(free_psrc)
			free(psrc);
	}
	dynbuf[dynbuf_len] = '\x00';

	fclose(fp);
	if(len != NULL) *len = dynbuf_len;
	return dynbuf;
}

