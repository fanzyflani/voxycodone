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

#include <lua.h>
#include <lualib.h>
#include <lauxlib.h>

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
#include <SDL_mixer.h>

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
GLuint init_shader_str(const char *ray_v_src, const char *ray_f_src, const char *ray_g_src, lua_State *L);

// init.c
extern GLuint tex_ray_vox;
extern GLuint va_ray_vbo;
extern GLuint va_ray_vao;

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

// lbind.c
extern lua_State *Lbase;

void init_lua(void);

// scene.c
void h_render_main(void);

// main.c
extern int do_exit;
extern int mouse_locked;
extern SDL_Window *window;
extern double render_sec_current;
extern int key_pos_dxn;
extern int key_pos_dxp;
extern int key_pos_dyn;
extern int key_pos_dyp;
extern int key_pos_dzn;
extern int key_pos_dzp;

