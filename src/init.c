#include "common.h"

GLuint shader_ray;
GLint shader_ray_tex0;
GLint shader_ray_tex1;
GLint shader_ray_tex2;
GLint shader_ray_tex3;
GLint shader_ray_sph_count;
GLint shader_ray_sph_data;
GLint shader_ray_light_count;
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
GLuint va_ray_vbo;
GLuint va_ray_vao;

const int16_t va_ray_data[12] = {
	-1,-1,
	 1,-1,
	-1, 1,
	 1, 1,
	-1, 1,
	 1,-1,
};

void init_gfx(void)
{
	char *ray_v_src = glslpp_load_str("glsl/shader_ray.vert", NULL);
	char *ray_f_src = glslpp_load_str("glsl/shader_ray.frag", NULL);
	const char *ray_v_src_alias = ray_v_src;
	const char *ray_f_src_alias = ray_f_src;

	GLuint ray_v = glCreateShader(GL_VERTEX_SHADER);
	GLuint ray_f = glCreateShader(GL_FRAGMENT_SHADER);

	glShaderSource(ray_v, 1, &ray_v_src_alias, NULL);
	glShaderSource(ray_f, 1, &ray_f_src_alias, NULL);

	free(ray_f_src);
	free(ray_v_src);

	char info_log[64*1024];
	glCompileShader(ray_v);
	glGetShaderInfoLog(ray_v, 64*1024-1, NULL, info_log);
	printf("===   VERTEX SHADER ===\n%s\n\n", info_log);
	glCompileShader(ray_f);
	glGetShaderInfoLog(ray_f, 64*1024-1, NULL, info_log);
	printf("=== FRAGMENT SHADER ===\n%s\n\n", info_log);
	shader_ray = glCreateProgram();
	printf("Attaching shaders\n");
	glAttachShader(shader_ray, ray_v);
	glAttachShader(shader_ray, ray_f);
	printf("Binding inputs\n");
	glBindAttribLocation(shader_ray, 0, "in_vertex");
	printf("Binding outputs\n");
	glBindFragDataLocation(shader_ray, 0, "out_frag_color");
	printf("Linking! This is the part where your computer dies\n");
	glLinkProgram(shader_ray);
	printf("Getting results\n");
	glGetProgramInfoLog(shader_ray, 64*1024-1, NULL, info_log);
	printf("=== OVERALL PROGRAM ===\n%s\n\n", info_log);

	GLint link_status;
	glGetProgramiv(shader_ray, GL_LINK_STATUS, &link_status);
	printf("Link status: %i\n", link_status);
	assert(link_status == GL_TRUE);

	shader_ray_tex0 = glGetUniformLocation(shader_ray, "tex0");
	shader_ray_tex1 = glGetUniformLocation(shader_ray, "tex1");
	shader_ray_tex2 = glGetUniformLocation(shader_ray, "tex2");
	shader_ray_tex3 = glGetUniformLocation(shader_ray, "tex3");
	shader_ray_sph_count = glGetUniformLocation(shader_ray, "sph_count");
	shader_ray_sph_data = glGetUniformLocation(shader_ray, "sph_data");
	shader_ray_light_count = glGetUniformLocation(shader_ray, "light_count");
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

	glGenTextures(1, &tex_ray0);
	glGenTextures(1, &tex_ray1);
	glGenTextures(1, &tex_ray2);
	glGenTextures(1, &tex_ray3);
	if(!epoxy_has_gl_extension("GL_ARB_texture_storage"))
	{
		printf("Eww yuck no glTexStorage2D update your drivers you scrub\n");
		glGetError();
		glBindTexture(GL_TEXTURE_2D, tex_ray0);
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAX_LEVEL, 0);
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
		glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, 1, SPH_MAX, 0, GL_RGBA, GL_UNSIGNED_BYTE, NULL);
		printf("%i\n", glGetError());

		glBindTexture(GL_TEXTURE_2D, tex_ray1);
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAX_LEVEL, 0);
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
		glTexImage2D(GL_TEXTURE_2D, 0, GL_R32F, 1, KD_MAX, 0, GL_RED, GL_FLOAT, NULL);
		printf("%i\n", glGetError());

		glBindTexture(GL_TEXTURE_2D, tex_ray2);
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAX_LEVEL, 0);
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
		glTexImage2D(GL_TEXTURE_2D, 0, GL_R32UI, 2, KD_MAX, 0, GL_RED_INTEGER, GL_UNSIGNED_INT, NULL);
		printf("%i\n", glGetError());

		glBindTexture(GL_TEXTURE_2D, tex_ray3);
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAX_LEVEL, 0);
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
		glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA32F, KD_MAX, 4, 0, GL_RGBA, GL_FLOAT, NULL);
		printf("%i\n", glGetError());
	} else {
		glGetError();
		glBindTexture(GL_TEXTURE_2D, tex_ray0);
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAX_LEVEL, 0);
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
		glTexStorage2D(GL_TEXTURE_2D, 1, GL_RGBA8, 1, SPH_MAX);
		printf("%i\n", glGetError());

		glBindTexture(GL_TEXTURE_2D, tex_ray1);
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAX_LEVEL, 0);
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
		glTexStorage2D(GL_TEXTURE_2D, 1, GL_R32F, 1, KD_MAX);
		printf("%i\n", glGetError());

		glBindTexture(GL_TEXTURE_2D, tex_ray2);
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAX_LEVEL, 0);
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
		glTexStorage2D(GL_TEXTURE_2D, 1, GL_R32UI, 2, KD_MAX);
		printf("%i\n", glGetError());

		glBindTexture(GL_TEXTURE_2D, tex_ray3);
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAX_LEVEL, 0);
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
		glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
		glTexStorage2D(GL_TEXTURE_2D, 1, GL_RGBA32F, KD_MAX, 4);
		printf("%i\n", glGetError());
	}
	glBindTexture(GL_TEXTURE_2D, 0);
	printf("Got texture\n");

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
}

