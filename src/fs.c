#include "common.h"

char *fs_bin_load_direct(const char *fname, size_t *len)
{
	// AVOID CALLING THIS DIRECTLY IT'S DANGEROUS
	// (although right now it's the only option)

	FILE *fp = fopen(fname, "rb");
	if(fp == NULL)
		return NULL;
	
	size_t totlen = 0;
#define FS_FETCH_LEN (1024*10)
	size_t freelen = FS_FETCH_LEN;

	int fd = fileno(fp);
	struct stat sb;
	if(fstat(fd, &sb) == 0)
	{
		if((sb.st_mode & S_IFMT) == S_IFREG)
			freelen = sb.st_size;
	}

	char *buf = malloc(freelen+1);
	buf[0] = '\x00';

	//printf("{%s}\n", fname);
	for(;;)
	{
		size_t res = fread(buf+totlen, 1, freelen, fp);
		//printf("%li\n", res);
		if(res == -1)
			break;
		if(res == 0)
			break;

		//printf("{%s}\n", subbuf);
		buf[totlen+res] = '\x00';
		freelen = FS_FETCH_LEN;
		buf = realloc(buf, totlen+res+freelen+1);
		assert(buf != NULL);
		totlen += res;
	}

	fclose(fp);

	*len = totlen;
	return buf;
}

#if FILENAME_MAX < 256
#error "filename limit too low on this OS! must be >= 255 chars (excluding NUL)"
#endif

char *fs_dir_extend(const char *root_dir, const char *fname)
{
	assert(FILENAME_MAX >= 256);
	char tmp_buf[256];

	size_t curlen = strlen(root_dir);

	if(curlen+1+1 > 256)
		return NULL; // filename too long

	// copy root directory
	strcpy(tmp_buf, root_dir);

	// ensure there's a '/' there
	if(tmp_buf[curlen-1] != '/')
	{
		tmp_buf[curlen] = '/';
		tmp_buf[curlen+1] = '\x00';
		curlen++;
	}

	// check validity of root directory
	// (root dir SHOULD be correct by this point)
	if((tmp_buf[0] == '.' && tmp_buf[1] == '.') || strstr(tmp_buf, "/..") != NULL)
	{
		printf("XXX: REPORT THIS BUG: ROOT DIR NOT SANE: \"%s\"\n", tmp_buf);
		fflush(stdout);
		abort();
		return NULL;
	}

	// copy path
	size_t addlen = strlen(fname);
	if(curlen+addlen+1 > 256)
		return NULL; // filename too long
	
	strcpy(tmp_buf + curlen, fname);

	// check validity of path
	if((tmp_buf[0] == '.' && tmp_buf[1] == '.') || strstr(tmp_buf, "/..") != NULL)
		return NULL;

	// valid path!
	return strdup(tmp_buf);
}

char *fs_bin_load(lua_State *L, const char *fname, size_t *len)
{
	struct vc_extraspace *es = *(struct vc_extraspace **)(lua_getextraspace(L));

	// Check if we can actually load
	if(es->vmtyp == VM_CLIENT)
	{
		// TODO!
		return NULL;

	} else if(es->root_dir == NULL) {
		return NULL;
	}

	// Get new validated path
	char *new_fname = fs_dir_extend(es->root_dir, fname);
	//printf("%s %s %s\n", es->root_dir, fname, new_fname);
	if(new_fname == NULL)
		return NULL;

	// Return data
	char *data = fs_bin_load_direct(new_fname, len);
	free(new_fname);
	return data;
}

