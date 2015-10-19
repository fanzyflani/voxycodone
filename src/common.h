#include <string.h>
#include <stdlib.h>
#include <stdint.h>
#include <stdio.h>
#include <errno.h>

#include <assert.h>
#include <math.h>

#ifndef WIN32
#include <unistd.h>
#include <signal.h>
#endif

#include <epoxy/gl.h>
#ifdef WIN32
#include <epoxy/wgl.h>
#endif

#ifdef WIN32
// libepoxy calls wglGetProcAddress for stuff that's core in 1.1
// at least on Wine this returns NULL for a lot of things
// so we have to get to the opengl32.dll crap directly
#undef glBindTexture
#undef glDrawArrays
#undef glGenTextures
#undef glTexImage2D
#undef glTexParameteri
#undef glTexSubImage2D
GLAPI void APIENTRY glBindTexture( GLenum target, GLuint texture );
GLAPI void APIENTRY glDrawArrays( GLenum mode, GLint first, GLsizei count );
GLAPI void APIENTRY glGenTextures( GLsizei n, GLuint *textures );
GLAPI void APIENTRY glTexImage2D( GLenum target, GLint level, GLint internalFormat, GLsizei width, GLsizei height, GLint border, GLenum format, GLenum type, const GLvoid *pixels );
GLAPI void APIENTRY glTexParameteri( GLenum target, GLenum pname, GLint param );
GLAPI void APIENTRY glTexSubImage2D( GLenum target, GLint level, GLint xoffset, GLint yoffset, GLsizei width, GLsizei height, GLenum format, GLenum type, const GLvoid *pixels );
#endif

#include <SDL.h>

#include "linmath.h"

#define false 0
#define true 1

#define SPH_MAX (1024)
#define SPILIST_MAX (1024+1024)
#define KD_MAX (2048)
#define LIGHT_MAX (32)

struct sph {
	double v[3];
	double rad;
	uint32_t rgba;
	int idx;
};

struct kd {
	struct kd *children[2];
	struct kd *parent;
	int *contents;
	double split_point;
	int idx;
	int split_axis;
	int contents_offs;
	int contents_len;
	double b1[3], b2[3];
	// TODO: other things
};

// glslpp.c
char *load_str(const char *fname);
char *glslpp_load_str(const char *fname, size_t *len);

// init.c
extern GLuint shader_blur;
extern GLint shader_blur_tex0;
extern GLint shader_blur_tex1;

extern GLuint shader_ray;
extern GLint shader_ray_tex0;
extern GLint shader_ray_tex1;
extern GLint shader_ray_tex2;
extern GLint shader_ray_tex3;
extern GLint shader_ray_tex_rand;
extern GLint shader_ray_sec_current;
extern GLint shader_ray_sph_count;
extern GLint shader_ray_sph_amb;
extern GLint shader_ray_sph_data;
extern GLint shader_ray_light_count;
extern GLint shader_ray_light_amb;
extern GLint shader_ray_light0_col;
extern GLint shader_ray_light0_pos;
extern GLint shader_ray_light0_dir;
extern GLint shader_ray_light0_cos;
extern GLint shader_ray_light0_pow;
extern GLint shader_ray_bmin;
extern GLint shader_ray_bmax;
extern GLint shader_ray_in_cam_inverse;
extern GLint shader_ray_in_aspect;
extern GLint shader_ray_kd_data_split_axis;
extern GLint shader_ray_kd_data_split_point;
//extern GLint shader_ray_kd_data_child1;
//extern GLint shader_ray_kd_data_spibeg;
//extern GLint shader_ray_kd_data_spilen;
extern GLint shader_ray_kd_data_spilist;

extern GLuint tex_ray0;
extern GLuint tex_ray1;
extern GLuint tex_ray2;
extern GLuint tex_ray3;
extern GLuint tex_ray_rand;
extern GLuint va_ray_vbo;
extern GLuint va_ray_vao;
extern GLuint tex_fbo0_0;
extern GLuint tex_fbo0_1;
extern GLuint fbo0;

void init_gfx(void);

// kd.c
extern double bmin_x;
extern double bmin_y;
extern double bmin_z;
extern double bmax_x;
extern double bmax_y;
extern double bmax_z;

extern int kd_list_len;
extern struct kd kd_list[KD_MAX];
extern GLuint kd_data_split_axis[KD_MAX];
extern GLfloat kd_data_split_point[KD_MAX];

extern int spilist[SPILIST_MAX];
extern int spilist_len;

void kd_generate(void);

// scene.c
extern double cam_rot_x;
extern double cam_rot_y;
extern double cam_pos_x;
extern double cam_pos_y;
extern double cam_pos_z;

void h_render_main(void);
void hook_tick(double sec_current, double sec_delta);

// sph.c
extern int sph_count;
extern struct sph sph_list[SPH_MAX];

void sph_set(int i, double x, double y, double z, double rad, int r, int g, int b, int a);


// main.c
extern SDL_Window *window;
extern double render_sec_current;
extern int key_pos_dxn;
extern int key_pos_dxp;
extern int key_pos_dyn;
extern int key_pos_dyp;
extern int key_pos_dzn;
extern int key_pos_dzp;

