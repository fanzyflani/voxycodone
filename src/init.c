#include "common.h"

GLuint tex_ray_vox;
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
	int i;

	glGenBuffers(1, &va_ray_vbo);
	glBindBuffer(GL_ARRAY_BUFFER, va_ray_vbo);
	glBufferData(GL_ARRAY_BUFFER, 6*2*sizeof(int16_t), va_ray_data, GL_STATIC_DRAW);
	printf("Got buffer\n");

	if(!context_is_compat)
	{
		glGenVertexArrays(1, &va_ray_vao);
		glBindVertexArray(va_ray_vao);
		glBindBuffer(GL_ARRAY_BUFFER, va_ray_vbo);
		//glVertexPointer(2, GL_SHORT, 2*sizeof(int16_t), &(((int16_t *)0)[0]));
		glVertexAttribPointer(0, 2, GL_SHORT, GL_FALSE, 2*sizeof(int16_t), &(((int16_t *)0)[0]));
		glEnableVertexAttribArray(0);
		glBindVertexArray(0);
		glDisableVertexAttribArray(0);
		printf("Got VAO\n");
	}

	glBindBuffer(GL_ARRAY_BUFFER, 0);

	int wnd_w, wnd_h;
	SDL_GetWindowSize(window, &wnd_w, &wnd_h);
	printf("Window size: %i x %i\n", wnd_w, wnd_h);

}

