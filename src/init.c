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

void init_gfx(void)
{
	int i;

	//shader_blur = init_shader_fname("glsl/post_radblur.vert", "glsl/post_radblur.frag");
	//shader_blur_tex0 = glGetUniformLocation(shader_blur, "tex0");
	//shader_blur_tex1 = glGetUniformLocation(shader_blur, "tex1");

	//shader_ray = init_shader_fname("glsl/shader_ray.vert", "glsl/shader_ray.frag");
	/*
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
	*/

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

}

