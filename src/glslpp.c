#include "common.h"

void print_shader_log(GLuint shader)
{
	GLint loglen = 0;
	glGetShaderiv(shader, GL_INFO_LOG_LENGTH, &loglen);
	char *info_log = malloc(loglen+1);
	info_log[0] = '\x00';
	info_log[loglen] = '\x00';
	glGetShaderInfoLog(shader, loglen, NULL, info_log);

	GLint srclen = 0;
	glGetShaderiv(shader, GL_SHADER_SOURCE_LENGTH, &srclen);
	char *src = malloc(srclen+1);
	src[0] = '\x00';
	src[srclen] = '\x00';
	glGetShaderSource(shader, srclen, NULL, src);

	// Walk shader log

	char *v = info_log;
	while(*v != '\x00')
	{
		char *f = strchr(v, '\n');
		if(f == NULL) f = v+strlen(v);

		int is_ln = (*f == '\n');
		if(is_ln) *f = '\x00';

		int n_file = 0;
		int n_line = 0;
		int n_chr = 0;
		sscanf(v, "%d:%d(%d)", &n_file, &n_line, &n_chr); // Intel
		sscanf(v, "%d(%d)", &n_file, &n_line); // nVidia
		sscanf(v, "ERROR: %d:%d:", &n_file, &n_line); // ATI (XXX: confirm it works)

		char *s = src;
		int i;
		for(i = 1; i < n_line && s != NULL; i++)
		{
			s = strchr(s, '\n');
			if(s != NULL) s++;
		}
		char *sf = strchr(s, '\n');
		if(sf == NULL) sf = s+strlen(s);

		int is_sln = (*sf == '\n');
		if(is_sln) *sf = '\x00';
		printf("\x1B[1m%s\x1B[0m\n", v);
		printf("%s\n\n", s);
		if(is_sln) *sf = '\n';

		if(is_ln) *f = '\n';
		if(is_ln) f++;

		v = f;
	}
	printf("\n");
	free(info_log);
}

void print_program_log(GLuint program)
{
	GLint loglen = 0;
	glGetProgramiv(program, GL_INFO_LOG_LENGTH, &loglen);
	char *info_log = malloc(loglen+1);
	info_log[0] = '\x00';
	info_log[loglen] = '\x00';
	glGetProgramInfoLog(program, loglen, NULL, info_log);
	printf("%s\n\n", info_log);
	free(info_log);
}

GLuint init_shader_str(const char *ray_v_src, const char *ray_f_src, const char *ray_g_src, lua_State *L)
{
	int i;

	const char *ray_v_src_alias = ray_v_src;
	const char *ray_g_src_alias = ray_g_src;
	const char *ray_f_src_alias = ray_f_src;

	GLuint ray_v = glCreateShader(GL_VERTEX_SHADER);
	GLuint ray_g = (ray_g_src == NULL ? 0 : glCreateShader(GL_GEOMETRY_SHADER));
	GLuint ray_f = glCreateShader(GL_FRAGMENT_SHADER);

	glShaderSource(ray_v, 1, &ray_v_src_alias, NULL);
	if(ray_g_src != NULL) glShaderSource(ray_g, 1, &ray_g_src_alias, NULL);
	glShaderSource(ray_f, 1, &ray_f_src_alias, NULL);

	glCompileShader(ray_v);
	printf("===   VERTEX SHADER ===\n");
	print_shader_log(ray_v);

	if(ray_g_src != NULL)
	{
		glCompileShader(ray_g);
		printf("=== GEOMETRY SHADER ===\n");
		print_shader_log(ray_g);
	}

	glCompileShader(ray_f);
	printf("=== FRAGMENT SHADER ===\n");
	print_shader_log(ray_f);

	GLuint out_shader = glCreateProgram();
	printf("Attaching shaders\n");
	glAttachShader(out_shader, ray_v);
	if(ray_g_src != NULL) glAttachShader(out_shader, ray_g);
	glAttachShader(out_shader, ray_f);

	// TODO: outsource this to a function
	glGetError();
	printf("Binding inputs\n");
	lua_len(L, 2); int len_input = lua_tointeger(L, -1); lua_pop(L, 1);
	for(i = 0; i < len_input; i++)
	{
		lua_geti(L, 2, i+1);
		glBindAttribLocation(out_shader, i, lua_tostring(L, -1));
		lua_pop(L, 1);
	}

	if(!context_is_compat)
	{
		printf("Binding outputs\n");
		lua_len(L, 3); int len_output = lua_tointeger(L, -1); lua_pop(L, 1);
		for(i = 0; i < len_output; i++)
		{
			lua_geti(L, 3, i+1);
			glBindFragDataLocation(out_shader, i, lua_tostring(L, -1));
			lua_pop(L, 1);
		}
	}

	printf("%i\n", glGetError());

	printf("Linking! This is the part where your computer dies\n");
	glLinkProgram(out_shader);

	printf("Getting results\n");
	printf("=== OVERALL PROGRAM ===\n");
	print_program_log(out_shader);

	GLint link_status;
	glGetProgramiv(out_shader, GL_LINK_STATUS, &link_status);
	printf("Link status: %i\n", link_status);

	if(link_status == GL_TRUE)
	{
		return out_shader;

	} else {
		glDeleteProgram(out_shader);
		glDeleteShader(ray_v);
		if(ray_g_src != NULL) glDeleteShader(ray_g);
		glDeleteShader(ray_f);

		return 0;
	}
}

