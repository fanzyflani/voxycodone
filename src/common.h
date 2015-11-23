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
#undef glBindT/xture
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

// ENUMS
enum vc_vm {
	VM_BLIND = 0,
	VM_CLIENT,
	VM_SERVER,
	VM_PLUGIN,
	VM_SYSTEM,

	VM_TYPE_COUNT
};

// STRUCTS
struct vc_extraspace
{
	enum vc_vm vmtyp;

	lua_State *Lparent;
	lua_State **pLself;
	char *root_dir;

	GLint fbo; // -1 == no rendering!
	GLuint fbo_ctex; // 0 == no rendering!
	//GLuint fbo_dstex; // 0 == no rendering!

	// TODO: ENet socket stuff
};

// fs.c
char *fs_bin_load_direct(const char *fname, size_t *len);
char *fs_dir_extend(const char *root_dir, const char *fname);
char *fs_bin_load(lua_State *L, const char *fname, size_t *len);

// glslpp.c
GLuint init_shader_str(const char *ray_v_src, const char *ray_f_src, const char *ray_g_src, lua_State *L);

// init.c
extern GLuint tex_ray_vox;
extern GLuint va_ray_vbo;
extern GLuint va_ray_vao;

void init_gfx(void);

// lbind.c
extern lua_State *Lbase;

lua_State *init_lua_vm(lua_State *Lparent, enum vc_vm vmtyp, const char *root, int port);
void init_lua(void);

// scene.c
void h_render_main(void);

// main.c
extern int do_exit;
extern int mouse_locked;
extern int context_is_compat;
extern SDL_Window *window;
extern double render_sec_current;

