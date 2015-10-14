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

#include <SDL.h>

#include "linmath.h"

#define false 0
#define true 1

SDL_Window *window;
SDL_GLContext window_gl;
int do_exit = false;
int mouse_locked = false;

double render_sec_current = 0.0;
double cam_rot_x = 0.0;
double cam_rot_y = 0.0;
double cam_pos_x = 0.0;
double cam_pos_y = 0.0;
double cam_pos_z = 0.0;

int key_pos_dxn = false;
int key_pos_dxp = false;
int key_pos_dyn = false;
int key_pos_dyp = false;
int key_pos_dzn = false;
int key_pos_dzp = false;

double bmin_x = 0.0;
double bmin_y = 0.0;
double bmin_z = 0.0;
double bmax_x = 0.0;
double bmax_y = 0.0;
double bmax_z = 0.0;

#define SPH_MAX (1024)
#define SPILIST_MAX (1024+1024)
#define KD_MAX (2048+128)

int sph_count = 0;
float sph_data[SPH_MAX*4];
struct sph {
	double v[3];
	double rad;
	uint32_t rgba;
	int idx;
} sph_list[SPH_MAX];

int kd_list_len = 0;
struct kd {
	struct kd *children[2];
	struct kd *parent;
	int *contents;
	double split_point;
	int idx;
	int split_axis;
	int contents_offs;
	int contents_len;
	// TODO: other things
} kd_list[KD_MAX];
int kd_data_split_axis[KD_MAX];
float kd_data_split_point[KD_MAX];
//int kd_data_child1[KD_MAX];
//int kd_data_spibeg[KD_MAX];
//int kd_data_spilen[KD_MAX];

int spilist[SPILIST_MAX];
int spilist_len = 0;

GLuint shader_ray;
GLint shader_ray_tex0;
GLint shader_ray_sph_count;
GLint shader_ray_sph_data;
GLint shader_ray_light0_pos;
GLint shader_ray_bmin;
GLint shader_ray_bmax;
GLint shader_ray_in_cam_inverse;
GLint shader_ray_in_aspect;
GLint shader_ray_kd_data_split_axis;
GLint shader_ray_kd_data_split_point;
GLint shader_ray_kd_data_child1;
GLint shader_ray_kd_data_spibeg;
GLint shader_ray_kd_data_spilen;
GLint shader_ray_kd_data_spilist;

GLuint tex_ray0;
GLuint va_ray_vbo;
GLuint va_ray_vao;
int16_t va_ray_data[12] = {
	-1,-1,
	 1,-1,
	-1, 1,
	 1, 1,
	-1, 1,
	 1,-1,
};

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

void init_gfx(void)
{
	char *ray_v_src = load_str("shader_ray.vert");
	char *ray_f_src = load_str("shader_ray.frag");
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
	glAttachShader(shader_ray, ray_v);
	glAttachShader(shader_ray, ray_f);
	glBindAttribLocation(shader_ray, 0, "in_vertex");
	glBindFragDataLocation(shader_ray, 0, "out_frag_color");
	glLinkProgram(shader_ray);
	glGetProgramInfoLog(shader_ray, 64*1024-1, NULL, info_log);
	printf("=== OVERALL PROGRAM ===\n%s\n\n", info_log);

	GLint link_status;
	glGetProgramiv(shader_ray, GL_LINK_STATUS, &link_status);
	assert(link_status == GL_TRUE);

	shader_ray_tex0 = glGetUniformLocation(shader_ray, "tex0");
	shader_ray_sph_count = glGetUniformLocation(shader_ray, "sph_count");
	shader_ray_sph_data = glGetUniformLocation(shader_ray, "sph_data");
	shader_ray_light0_pos = glGetUniformLocation(shader_ray, "light0_pos");
	shader_ray_bmin = glGetUniformLocation(shader_ray, "bmin");
	shader_ray_bmax = glGetUniformLocation(shader_ray, "bmax");
	shader_ray_in_cam_inverse = glGetUniformLocation(shader_ray, "in_cam_inverse");
	shader_ray_in_aspect = glGetUniformLocation(shader_ray, "in_aspect");
	shader_ray_kd_data_split_axis = glGetUniformLocation(shader_ray, "kd_data_split_axis");
	shader_ray_kd_data_split_point = glGetUniformLocation(shader_ray, "kd_data_split_point");
	//shader_ray_kd_data_child1 = glGetUniformLocation(shader_ray, "kd_data_child1");
	//shader_ray_kd_data_spibeg = glGetUniformLocation(shader_ray, "kd_data_spibeg");
	//shader_ray_kd_data_spilen = glGetUniformLocation(shader_ray, "kd_data_spilen");
	shader_ray_kd_data_spilist = glGetUniformLocation(shader_ray, "kd_data_spilist");

	glGenTextures(1, &tex_ray0);
	glBindTexture(GL_TEXTURE_2D, tex_ray0);
	//glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, 64, 256, 0, GL_RGBA, GL_UNSIGNED_BYTE, NULL);
	glTexStorage2D(GL_TEXTURE_2D, 1, GL_RGBA8, 64, 1024);
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
	glBindTexture(GL_TEXTURE_2D, 0);

	glGenBuffers(1, &va_ray_vbo);
	glBindBuffer(GL_ARRAY_BUFFER, va_ray_vbo);
	glBufferData(GL_ARRAY_BUFFER, 6*2*sizeof(int16_t), va_ray_data, GL_STATIC_DRAW);

	glGenVertexArrays(1, &va_ray_vao);
	glBindVertexArray(va_ray_vao);
	glBindBuffer(GL_ARRAY_BUFFER, va_ray_vbo);
	//glVertexPointer(2, GL_SHORT, 2*sizeof(int16_t), &(((int16_t *)0)[0]));
	glVertexAttribPointer(0, 2, GL_SHORT, GL_FALSE, 2*sizeof(int16_t), &(((int16_t *)0)[0]));
	glEnableVertexAttribArray(0);
	glBindVertexArray(0);
	glDisableVertexAttribArray(0);

	glBindBuffer(GL_ARRAY_BUFFER, 0);
}

uint32_t encode_float(double v)
{
	uint32_t r = (int)floor(v*1024 + 0x800000 + 0.5);
	assert(r >= 0x000000 && r <= 0xFFFFFF);
	return r;
}

uint32_t encode_float_16(double v)
{
	uint32_t r = floor(v*64 + 0x8000 + 0.5);
	assert(r >= 0x0000 && r <= 0xFFFF);
	return r;
}

void sph_set(int i, double x, double y, double z, double rad, int r, int g, int b, int a)
{
	assert(i < SPH_MAX);
	assert(i >= 0);
	sph_list[i].idx = i;
	sph_list[i].v[0] = x;
	sph_list[i].v[1] = y;
	sph_list[i].v[2] = z;
	sph_list[i].rad = rad;

	if(r < 0) r = 0; if(r > 255) r = 255;
	if(g < 0) g = 0; if(g > 255) g = 255;
	if(b < 0) b = 0; if(b > 255) b = 255;
	if(a < 0) a = 0; if(a > 255) a = 255;

	sph_list[i].rgba = r + g*0x100 + b*0x10000 + a*0x1000000;

	sph_data[4*i + 0] = x;
	sph_data[4*i + 1] = y;
	sph_data[4*i + 2] = z;
	sph_data[4*i + 3] = rad;
}

void kd_get_box(const int *base, int base_len, double *b1, double *b2)
{
	int i, j;

	int first = (base == NULL && base_len > 0 ? 0 : base[0]);
	b1[0] = b2[0] = sph_list[first].v[0];
	b1[1] = b2[1] = sph_list[first].v[1];
	b1[2] = b2[2] = sph_list[first].v[2];

	// Find regions
	for(i = 0; i < base_len; i++)
	{
		int q = (base == NULL ? i : base[i]);
		double r = sph_list[q].rad + 2.0/1024.0;
		double x = sph_list[q].v[0];
		double y = sph_list[q].v[1];
		double z = sph_list[q].v[2];

		if(x-r < b1[0]) b1[0] = x-r;
		if(y-r < b1[1]) b1[1] = y-r;
		if(z-r < b1[2]) b1[2] = z-r;
		if(x+r > b2[0]) b2[0] = x+r;
		if(y+r > b2[1]) b2[1] = y+r;
		if(z+r > b2[2]) b2[2] = z+r;
	}
}

int kd_imap_axis = 0;
int kd_sort_imap(void const* ap, void const* bp)
{
	int const* ai = (int const*)ap;
	int const* bi = (int const*)bp;

	struct sph const* ae = &sph_list[*ai];
	struct sph const* be = &sph_list[*bi];

	double ac = ae->v[kd_imap_axis];
	double bc = be->v[kd_imap_axis];

	return(ac < bc ? -1 : ac > bc ? 1 : 0);
}

struct kd *kd_build_node(int *base, int base_len, struct kd *parent)
{
	int i, j;

	// Get base data
	assert(kd_list_len < KD_MAX);
	assert(kd_list_len >= 0);
	struct kd *kd = &kd_list[kd_list_len];
	kd->idx = kd_list_len++;
	kd->parent = parent;
	kd->contents = NULL;
	kd->contents_offs = 0;
	kd->contents_len = 0;
	kd->children[0] = NULL;
	kd->children[1] = NULL;
	kd->split_axis = -1;

	// If we have less than two in here, return
	if(base_len < 9)
	{
		// But first, let's get the contents list set up
		kd->contents = malloc(base_len*sizeof(int));
		kd->contents_len = base_len;
		if(base == NULL)
		{
			for(i = 0; i < base_len; i++)
				kd->contents[i] = i;
		} else {
			memcpy(kd->contents, base, base_len*sizeof(int));
		}

		// OK, now return!
		return kd;
	}

	// Get size
	double b1[3], b2[3];
	double bs[3];

	kd_get_box(base, base_len, b1, b2);
	for(i = 0; i < 3; i++)
		bs[i] = b2[i] - b1[i];

	// Find longest for split
	kd->split_axis = 0;
	for(i = 0; i < 3; i++)
		if(bs[i] > bs[kd->split_axis])
			kd->split_axis = i;

	// Allocate new index map
	int *newmap = malloc(base_len*sizeof(int));
	if(base == NULL)
	{
		for(i = 0; i < base_len; i++)
			newmap[i] = i;
	} else {
		memcpy(newmap, base, base_len*sizeof(int));
	}

	// Sort index map
	kd_imap_axis = kd->split_axis;
	qsort(newmap, base_len, sizeof(int), kd_sort_imap);

	/*
	printf("%i:", kd->split_axis);
	for(i = 0; i < base_len; i++)
		printf(" %3i(%5.2f)", newmap[i], sph_list[newmap[i]].v[kd->split_axis]);
	printf("\n");
	*/

	// Find median
	int median0 = (base_len-1)/2;
	int median1 = median0+1;

	// Place plane along "right" of median
	kd->split_point = sph_list[newmap[median0]].v[kd->split_axis]
		+ sph_list[newmap[median0]].rad + 0.01;

	// TODO: avoid a split

	// Build left bucket
	for(i = median0; i < base_len; i++)
	{
		struct sph *sph = &sph_list[newmap[i]];

		if(sph->v[kd->split_axis] - sph->rad >= kd->split_point)
			break;
	}
	int blen0 = i;

	// Build right bucket
	for(i = median1; i >= 0; i--)
	{
		struct sph *sph = &sph_list[newmap[i]];

		if(sph->v[kd->split_axis] + sph->rad <= kd->split_point)
			break;
	}

	int blen1 = base_len - (i+1);

	//printf("%i %i %i\n", blen0, blen1, base_len);
	// If we're all in the bucket, change strategy and become a leaf instead
	if(blen0 == base_len || blen1 == base_len)
	{
		kd->split_axis = -1;
		kd->contents = malloc(base_len*sizeof(int));
		memcpy(kd->contents, base, base_len*sizeof(int));
		kd->contents_len = base_len;

		free(newmap);
		return kd;
	}

	// Split!
	kd->children[0] = kd_build_node(newmap, blen0, kd);
	kd->children[1] = kd_build_node(newmap + base_len - blen1, blen1, kd);

	// Return
	free(newmap);
	return kd;

}

/*
function kd_get_sph_part_count(kd)
	if kd.children then
		return 0
			+ kd_get_sph_part_count(kd.children[1])
			+ kd_get_sph_part_count(kd.children[2])
	else
		return #kd.contents
	end
end

function kd_get_depth(kd)
	if kd.children then
		return 1 + math.max(
			kd_get_depth(kd.children[1]),
			kd_get_depth(kd.children[2]))
	else
		return 1
	end
end
*/

void kd_generate()
{
	int i, j;

	// Recursively build tree
	kd_list_len = 0;
	kd_build_node(NULL, sph_count, NULL);
	//local kd_root = kd_build_node(sph_list, nil)
	//local b1, b2 = kd_root.bmin, kd_root.bmax

	// Bounding-box for fast skips
	// XXX: this may need to be replaced with something faster
	double b1[3], b2[3];

	kd_get_box(NULL, sph_count, b1, b2);
	bmin_x = b1[0];
	bmin_y = b1[1];
	bmin_z = b1[2];
	bmax_x = b2[0];
	bmax_y = b2[1];
	bmax_z = b2[2];

	// Place kd tree
	spilist_len = 0;
	for(i = 0; i < kd_list_len; i++)
	{
		struct kd *kd = &kd_list[i];

		assert(kd->idx == i);
		assert(i >= 0);
		assert(i < KD_MAX);
		kd->contents_offs = spilist_len;

		if(kd->split_axis != -1)
		{
			assert(kd->split_axis == 0 || kd->split_axis == 1 || kd->split_axis == 2);
			assert(kd->children[0] != NULL);
			assert(kd->children[1] != NULL);
			assert(kd->children[0]->idx == kd->idx+1);
			assert(kd->children[1]->idx > kd->idx+1);
			assert(kd->children[0]->idx < kd_list_len);
			assert(kd->children[1]->idx < kd_list_len);
			assert(kd->children[0]->idx >= 0);
			assert(kd->children[1]->idx >= 0);
			assert(kd->children[1]->idx-kd->idx >= 2);
			/*
			common.img_pixel_set(tex_ray0, 16+0, i-1,
				0
				+ encode_float_16(kd.split_point)
				+ 0x00010000 * (kd.children[2].idx-kd.idx-2)
				+ 0x01000000 * (kd.split_axis-1)
			)
			*/

			//kd_data_split_axis[i] = -1-kd->split_axis;
			//kd_data_child1[i] = kd->children[1]->idx;
			kd_data_split_axis[i] = (kd->split_axis | (kd->children[1]->idx<<16));
			kd_data_split_point[i] = kd->split_point;
		} else {
			/*
			common.img_pixel_set(tex_ray0, 16+0, i-1,
				0
				+ 0x00010000 * idx_acc
				+ 0x00000100 * ((kd.contents and #kd.contents) or 0)
				+ 0x00000001 * 255
				+ 0x01000000 * 255
			)
			*/

			//kd_data_spibeg[i] = kd->contents_offs;
			//kd_data_spilen[i] = kd->contents_len;
			kd_data_split_axis[i] = (kd->contents_offs+3)|(kd->contents_len<<16);
			//kd_data_child1[i] = kd->contents_len;
		}

		if(kd->children[0] != NULL)
		{
			assert(kd->children[0]->idx > 0);
			assert(kd->children[1]->idx > 0);
			assert(kd->children[0]->idx > kd->idx);
			assert(kd->children[1]->idx > kd->idx);
			assert(kd->children[0] == &kd_list[kd->children[0]->idx]);
			assert(kd->children[1] == &kd_list[kd->children[1]->idx]);
			assert(kd->children[0]->parent == kd);
			assert(kd->children[1]->parent == kd);
		}

		if(kd->contents != NULL)
		{
			//printf("HONK %i\n", spilist_len);
			for(j = 0; j < kd->contents_len; j++)
			{
				assert(spilist_len >= 0);
				assert(spilist_len < SPILIST_MAX);
				spilist[spilist_len++] = kd->contents[j];
			}

			free(kd->contents);
			kd->contents = NULL;
		}
	}

	//printf("spi=%-4i kd=%-4i\n", spilist_len, kd_list_len);
}

int sent_shit = false;
void h_render_main(void)
{
	mat4x4 mat_cam1;
	mat4x4 mat_cam2;

	mat4x4_identity(mat_cam1);
	mat4x4_rotate_X(mat_cam2, mat_cam1, cam_rot_x);
	mat4x4_rotate_Y(mat_cam1, mat_cam2, cam_rot_y);
	mat4x4_translate_in_place(mat_cam1, -cam_pos_x, -cam_pos_y, -cam_pos_z);

	int x, y, z, i;
	int cube_units = 10;
	sph_count = cube_units*cube_units*cube_units;

	i = 0;
	for(y = 1; y <= cube_units; y++)
	for(x = 1; x <= cube_units; x++)
	for(z = 1; z <= cube_units; z++)
		sph_set(i++, x*3 - 1.5*cube_units - 1.5, y*3 - 2.0, -z*3, 1.0,
			y*255/cube_units, x*255/cube_units, z*255/cube_units, 255);

	//sph_count = 16;
	kd_generate();

	if(!sent_shit)
	{
		static uint32_t sph_buf[1024];
		for(i = 0; i < sph_count; i++)
		{
			struct sph *sph = &sph_list[i];

			sph_buf[1*i + 0] = sph->rgba;
		}

		sent_shit = true;
		glBindTexture(GL_TEXTURE_2D, tex_ray0);
		glTexSubImage2D(GL_TEXTURE_2D, 0, 4, 0, 1, 1024, GL_RGBA, GL_UNSIGNED_BYTE, sph_buf);
	}

	glBindTexture(GL_TEXTURE_2D, tex_ray0);
	glUseProgram(shader_ray);

	mat4x4_invert(mat_cam2, mat_cam1);
	glUniformMatrix4fv(shader_ray_in_cam_inverse, 1, GL_FALSE, (GLfloat *)mat_cam2);
	glUniform2f(shader_ray_in_aspect, 720.0/1280.0, 1.0);

	glUniform1i(shader_ray_tex0, 0);
	glUniform1i(shader_ray_sph_count, sph_count);
	glUniform3f(shader_ray_light0_pos,
		//cam_pos_x, cam_pos_y, cam_pos_z);
		//0.0, 10.0, -10.0);
		sin(render_sec_current)*15.0+5.0, 10.0, cos(render_sec_current)*15.0+5.0);

	glUniform3f(shader_ray_bmin, bmin_x, bmin_y, bmin_z);
	glUniform3f(shader_ray_bmax, bmax_x, bmax_y, bmax_z);

	//printf("%i %i %i\n", sph_count, spilist_len, kd_list_len);
	glUniform4fv(shader_ray_sph_data, sph_count, sph_data);
	glUniform1iv(shader_ray_kd_data_split_axis, kd_list_len, kd_data_split_axis);
	glUniform1fv(shader_ray_kd_data_split_point, kd_list_len, kd_data_split_point);
	//glUniform1iv(shader_ray_kd_data_child1, kd_list_len, kd_data_child1);
	//glUniform1iv(shader_ray_kd_data_spibeg, kd_list_len, kd_data_spibeg);
	//glUniform1iv(shader_ray_kd_data_spilen, kd_list_len, kd_data_spilen);
	glUniform1iv(shader_ray_kd_data_spilist, spilist_len, spilist);

	glBindVertexArray(va_ray_vao);
	glDrawArrays(GL_TRIANGLES, 0, 6);
	glBindVertexArray(0);

	glBindTexture(GL_TEXTURE_2D, 0);
	glUseProgram(0);
}

void hook_key(SDL_Keycode key, int state)
{
	if(key == SDLK_ESCAPE && !state)
		do_exit = true;
	else if(key == SDLK_w) key_pos_dzp = state;
	else if(key == SDLK_s) key_pos_dzn = state;
	else if(key == SDLK_a) key_pos_dxn = state;
	else if(key == SDLK_d) key_pos_dxp = state;
	else if(key == SDLK_LCTRL) key_pos_dyn = state;
	else if(key == SDLK_SPACE) key_pos_dyp = state;
}

void hook_mouse_button(int button, int state)
{
	if(button == 1 && !state)
	{
		mouse_locked = !mouse_locked;
		SDL_ShowCursor(!mouse_locked);
		SDL_SetWindowGrab(window, mouse_locked);
		SDL_SetRelativeMouseMode(mouse_locked);
	}
}

void hook_mouse_motion(int x, int y, int dx, int dy)
{
	if(!mouse_locked)
		return;

	cam_rot_y = cam_rot_y - dx*M_PI/1000.0;
	cam_rot_x = cam_rot_x + dy*M_PI/1000.0;
	double clamp = M_PI/2.0-0.0001;
	if(cam_rot_x < -clamp) cam_rot_x = -clamp;
	if(cam_rot_x >  clamp) cam_rot_x =  clamp;
}

void hook_tick(double sec_current, double sec_delta)
{
	double mvspeed = 20.0;
	double mvspeedf = mvspeed * sec_delta;

	double ldx = 0.0;
	double ldy = 0.0;
	double ldz = 0.0;
	if (key_pos_dxn) ldx = ldx - 1;
	if (key_pos_dxp) ldx = ldx + 1;
	if (key_pos_dyn) ldy = ldy - 1;
	if (key_pos_dyp) ldy = ldy + 1;
	if (key_pos_dzn) ldz = ldz - 1;
	if (key_pos_dzp) ldz = ldz + 1;

	ldx = ldx * mvspeedf;
	ldy = ldy * mvspeedf;
	ldz = ldz * mvspeedf;

	double ldw = ldz;
	double ldh = ldx;
	double ldv = ldy;

	double xs = sin(cam_rot_x), xc = cos(cam_rot_x);
	double ys = sin(cam_rot_y), yc = cos(cam_rot_y);
	double fx = -xc*ys, fy = -xs, fz = -xc*yc;
	double wx = -ys, wy = 0, wz = -yc;
	double hx = yc, hy = 0, hz = -ys;
	double vx = -xs*ys, vy = xc, vz = -xs*yc;

	cam_pos_x = cam_pos_x + hx*ldh + fx*ldw + vx*ldv;
	cam_pos_y = cam_pos_y + hy*ldh + fy*ldw + vy*ldv;
	cam_pos_z = cam_pos_z + hz*ldh + fz*ldw + vz*ldv;
}

int main(int argc, char *argv[])
{
	SDL_Init(SDL_INIT_VIDEO | SDL_INIT_NOPARACHUTE);

	SDL_GL_SetAttribute(SDL_GL_CONTEXT_PROFILE_MASK, SDL_GL_CONTEXT_PROFILE_CORE);
	SDL_GL_SetAttribute(SDL_GL_CONTEXT_MAJOR_VERSION, 3);
	SDL_GL_SetAttribute(SDL_GL_CONTEXT_MINOR_VERSION, 2);

	SDL_GL_SetAttribute(SDL_GL_RED_SIZE, 8);
	SDL_GL_SetAttribute(SDL_GL_GREEN_SIZE, 8);
	SDL_GL_SetAttribute(SDL_GL_BLUE_SIZE, 8);
	SDL_GL_SetAttribute(SDL_GL_ALPHA_SIZE, 0);
	SDL_GL_SetAttribute(SDL_GL_DEPTH_SIZE, 0);
	SDL_GL_SetAttribute(SDL_GL_STENCIL_SIZE, 0);
	SDL_GL_SetAttribute(SDL_GL_DOUBLEBUFFER, 1);

	window = SDL_CreateWindow("WIP RAYTRACER",
		SDL_WINDOWPOS_UNDEFINED,
		SDL_WINDOWPOS_UNDEFINED,
		1280, 720,
		//800, 500,
		//640, 360,
		SDL_WINDOW_OPENGL);

	window_gl = SDL_GL_CreateContext(window);
	SDL_GL_SetSwapInterval(0); // disable vsync, because fuck vsync
	printf("GL version %i\n", epoxy_gl_version());

#ifndef WIN32
	signal(SIGINT, SIG_DFL);
	signal(SIGTERM, SIG_DFL);
#endif

	init_gfx();

	int32_t ticks_prev = SDL_GetTicks();
	int32_t ticks_get_fps = ticks_prev;
	int fps = 0;

	for(;;)
	{
		SDL_Event ev;

		while(SDL_PollEvent(&ev))
		switch(ev.type)
		{
			case SDL_QUIT:
				do_exit = true;
				break;

			case SDL_KEYUP:
			case SDL_KEYDOWN:
				hook_key(ev.key.keysym.sym, ev.type == SDL_KEYDOWN);
				break;

			case SDL_MOUSEBUTTONUP:
			case SDL_MOUSEBUTTONDOWN:
				hook_mouse_button(ev.button.button, ev.type == SDL_MOUSEBUTTONDOWN);
				break;

			case SDL_MOUSEMOTION:
				hook_mouse_motion(ev.motion.x, ev.motion.y, ev.motion.xrel, ev.motion.yrel);
				break;
		}

		if(do_exit) break;

		int32_t ticks_now = SDL_GetTicks();
		fps++;
		if(ticks_now >= ticks_get_fps)
		{
			while(ticks_now >= ticks_get_fps)
				ticks_get_fps += 1000;

			char fpsbuf[32];
			fpsbuf[31] = '\x00';
			snprintf(fpsbuf, 32-1, "FPS: %i", fps);
			SDL_SetWindowTitle(window, fpsbuf);
			fps = 0;
		}
		double sec_delta = ((double)(ticks_now - ticks_prev))/1000.0;
		render_sec_current = ((double)(ticks_now))/1000.0;
		hook_tick(render_sec_current, sec_delta);
		h_render_main();
		SDL_GL_SwapWindow(window);
		ticks_prev = ticks_now;

#ifndef WIN32
		//usleep(500);
#else
		SDL_Delay(10);
#endif
	}

	return 0;
}

