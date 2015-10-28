#include "common.h"

GLuint shader_blur;
GLint shader_blur_tex0;
GLint shader_blur_tex1;

GLuint shader_ray;
GLint shader_ray_tex0;
GLint shader_ray_tex1;
GLint shader_ray_tex2;
GLint shader_ray_tex3;
GLint shader_ray_tex_rand;
GLint shader_ray_tex_vox;
GLint shader_ray_sec_current;
GLint shader_ray_sph_count;
GLint shader_ray_sph_data;
GLint shader_ray_light_count;
GLint shader_ray_light_amb;
GLint shader_ray_light0_col;
GLint shader_ray_light0_pos;
GLint shader_ray_light0_dir;
GLint shader_ray_light0_cos;
GLint shader_ray_light0_pow;
GLint shader_ray_bmin;
GLint shader_ray_bmax;
GLint shader_ray_in_cam_inverse;
GLint shader_ray_in_aspect;
GLint shader_ray_kd_data_split_axis;
GLint shader_ray_kd_data_split_point;
//GLint shader_ray_kd_data_child1;
//GLint shader_ray_kd_data_spibeg;
//GLint shader_ray_kd_data_spilen;
GLint shader_ray_kd_data_spilist;

GLuint tex_ray0;
GLuint tex_ray1;
GLuint tex_ray2;
GLuint tex_ray3;
GLuint tex_ray_rand;
GLuint tex_ray_vox;
GLuint va_ray_vbo;
GLuint va_ray_vao;
GLuint tex_fbo0_0;
GLuint tex_fbo0_1;
GLuint fbo0;

const int16_t va_ray_data[12] = {
	-1,-1,
	 1,-1,
	-1, 1,
	 1, 1,
	-1, 1,
	 1,-1,
};

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

GLuint init_shader(const char *fname_vert, const char *fname_frag)
{
	char *ray_v_src = glslpp_load_str(fname_vert, NULL);
	char *ray_f_src = glslpp_load_str(fname_frag, NULL);
	const char *ray_v_src_alias = ray_v_src;
	const char *ray_f_src_alias = ray_f_src;

	GLuint ray_v = glCreateShader(GL_VERTEX_SHADER);
	GLuint ray_f = glCreateShader(GL_FRAGMENT_SHADER);

	glShaderSource(ray_v, 1, &ray_v_src_alias, NULL);
	glShaderSource(ray_f, 1, &ray_f_src_alias, NULL);

	free(ray_f_src);
	free(ray_v_src);

	glCompileShader(ray_v);
	printf("===   VERTEX SHADER ===\n");
	print_shader_log(ray_v);
	glCompileShader(ray_f);
	printf("=== FRAGMENT SHADER ===\n");
	print_shader_log(ray_f);
	GLuint out_shader = glCreateProgram();
	printf("Attaching shaders\n");
	glAttachShader(out_shader, ray_v);
	glAttachShader(out_shader, ray_f);

	// TODO: outsource this to a function
	glGetError();
	printf("Binding inputs\n");
	glBindAttribLocation(out_shader, 0, "in_vertex");
	printf("Binding outputs\n");
	glBindFragDataLocation(out_shader, 0, "out_frag_color");
	glBindFragDataLocation(out_shader, 1, "out_frag_color_gi");
	printf("%i\n", glGetError());

	printf("Linking! This is the part where your computer dies\n");
	glLinkProgram(out_shader);
	printf("%i %i\n"
		, glGetFragDataLocation(out_shader, "out_frag_color")
		, glGetFragDataLocation(out_shader, "out_frag_color_gi")
		);

	printf("Getting results\n");
	printf("=== OVERALL PROGRAM ===\n");
	print_program_log(out_shader);

	GLint link_status;
	glGetProgramiv(out_shader, GL_LINK_STATUS, &link_status);
	printf("Link status: %i\n", link_status);
	assert(link_status == GL_TRUE);

	return out_shader;
}

void init_gfx(void)
{
	int i;

	shader_blur = init_shader("glsl/post_radblur.vert", "glsl/post_radblur.frag");
	shader_blur_tex0 = glGetUniformLocation(shader_blur, "tex0");
	shader_blur_tex1 = glGetUniformLocation(shader_blur, "tex1");

	shader_ray = init_shader("glsl/shader_ray.vert", "glsl/shader_ray.frag");
	shader_ray_tex0 = glGetUniformLocation(shader_ray, "tex0");
	shader_ray_tex1 = glGetUniformLocation(shader_ray, "tex1");
	shader_ray_tex2 = glGetUniformLocation(shader_ray, "tex2");
	shader_ray_tex3 = glGetUniformLocation(shader_ray, "tex3");
	shader_ray_tex_rand = glGetUniformLocation(shader_ray, "tex_rand");
	shader_ray_tex_vox = glGetUniformLocation(shader_ray, "tex_vox");
	shader_ray_sec_current = glGetUniformLocation(shader_ray, "sec_current");
	shader_ray_sph_count = glGetUniformLocation(shader_ray, "sph_count");
	shader_ray_sph_data = glGetUniformLocation(shader_ray, "sph_data");
	shader_ray_light_count = glGetUniformLocation(shader_ray, "light_count");
	shader_ray_light_amb = glGetUniformLocation(shader_ray, "light_amb");
	shader_ray_light0_col = glGetUniformLocation(shader_ray, "light_col");
	shader_ray_light0_pos = glGetUniformLocation(shader_ray, "light_pos");
	shader_ray_light0_dir = glGetUniformLocation(shader_ray, "light_dir");
	shader_ray_light0_cos = glGetUniformLocation(shader_ray, "light_cos");
	shader_ray_light0_pow = glGetUniformLocation(shader_ray, "light_pow");
	shader_ray_bmin = glGetUniformLocation(shader_ray, "bmin");
	shader_ray_bmax = glGetUniformLocation(shader_ray, "bmax");
	shader_ray_in_cam_inverse = glGetUniformLocation(shader_ray, "in_cam_inverse");
	shader_ray_in_aspect = glGetUniformLocation(shader_ray, "in_aspect");
	//shader_ray_kd_data_split_axis = glGetUniformLocation(shader_ray, "kd_data_split_axis");
	//shader_ray_kd_data_split_point = glGetUniformLocation(shader_ray, "kd_data_split_point");
	//shader_ray_kd_data_child1 = glGetUniformLocation(shader_ray, "kd_data_child1");
	//shader_ray_kd_data_spibeg = glGetUniformLocation(shader_ray, "kd_data_spibeg");
	//shader_ray_kd_data_spilen = glGetUniformLocation(shader_ray, "kd_data_spilen");
	shader_ray_kd_data_spilist = glGetUniformLocation(shader_ray, "kd_data_spilist");
	//printf("Got uniforms %i\n", shader_ray_kd_data_spilist);
	printf("Got uniforms\n");

	glGenBuffers(1, &va_ray_vbo);
	glBindBuffer(GL_ARRAY_BUFFER, va_ray_vbo);
	glBufferData(GL_ARRAY_BUFFER, 6*2*sizeof(int16_t), va_ray_data, GL_STATIC_DRAW);
	printf("Got buffer\n");

	glGenVertexArrays(1, &va_ray_vao);
	glBindVertexArray(va_ray_vao);
	glBindBuffer(GL_ARRAY_BUFFER, va_ray_vbo);
	//glVertexPointer(2, GL_SHORT, 2*sizeof(int16_t), &(((int16_t *)0)[0]));
	glVertexAttribPointer(0, 2, GL_SHORT, GL_FALSE, 2*sizeof(int16_t), &(((int16_t *)0)[0]));
	glEnableVertexAttribArray(0);
	glBindVertexArray(0);
	glDisableVertexAttribArray(0);
	printf("Got VAO\n");

	glBindBuffer(GL_ARRAY_BUFFER, 0);

	int wnd_w, wnd_h;
	SDL_GetWindowSize(window, &wnd_w, &wnd_h);
	printf("Window size: %i x %i\n", wnd_w, wnd_h);

	glGetError();
	glGenTextures(1, &tex_fbo0_0);
	glBindTexture(GL_TEXTURE_2D, tex_fbo0_0);
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAX_LEVEL, 0);
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
	glTexStorage2D(GL_TEXTURE_2D, 1, GL_RGBA8, wnd_w, wnd_h);
	printf("Got FBO tex 0\n");

	glGenTextures(1, &tex_fbo0_1);
	glBindTexture(GL_TEXTURE_2D, tex_fbo0_1);
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAX_LEVEL, 0);
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
	glTexStorage2D(GL_TEXTURE_2D, 1, GL_RGBA8, wnd_w, wnd_h);
	printf("Got FBO tex 1\n");

	glGenFramebuffers(1, &fbo0);
	glBindFramebuffer(GL_FRAMEBUFFER, fbo0);
	glBindTexture(GL_TEXTURE_2D, 0);
	glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0 + 0, GL_TEXTURE_2D, tex_fbo0_0, 0);
	glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0 + 1, GL_TEXTURE_2D, tex_fbo0_1, 0);
	printf("Got FBO %i\n", glGetError());
	assert(glCheckFramebufferStatus(GL_FRAMEBUFFER) == GL_FRAMEBUFFER_COMPLETE);

	glBindFramebuffer(GL_FRAMEBUFFER, 0);

}

