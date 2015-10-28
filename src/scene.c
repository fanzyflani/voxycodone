#include "common.h"

double cam_rot_x = 0.0;
double cam_rot_y = 0.0;
double cam_pos_x = 0.0;
double cam_pos_y = 0.0;
double cam_pos_z = 0.0;

#define SCENE_GENKD 0
#define SCENE_VOXYGEN 1

int sent_shit = false;
void h_render_main(void)
{
	int x, y, z, i, j;

	mat4x4 mat_cam1;
	mat4x4 mat_cam2;

	mat4x4_identity(mat_cam1);
	mat4x4_rotate_X(mat_cam2, mat_cam1, cam_rot_x);
	mat4x4_rotate_Y(mat_cam1, mat_cam2, cam_rot_y);
	mat4x4_translate_in_place(mat_cam1, -cam_pos_x, -cam_pos_y, -cam_pos_z);

	/*
	int cube_units = 8;
	sph_count = cube_units*cube_units*cube_units;

	i = 0;
	for(y = 1; y <= cube_units; y++)
	for(x = 1; x <= cube_units; x++)
	for(z = 1; z <= cube_units; z++)
	{
		double rad = sin((((x+y-z/2.0)/cube_units)+render_sec_current)*M_PI*2.0)*0.5+1.0;
		sph_set(i++, x*4 - 2*cube_units - 2, y*4 - 3, -z*4, rad,
			y*255/cube_units, x*255/cube_units, z*255/cube_units, 255);
	}
	*/

#if SCENE_VOXYGEN != 0
#endif

#if SCENE_GENKD != 0
	sph_count = 50;
	double fx, fy, fz;
	fx = 0.0;
	fy = 0.0;
	fz = 0.0;
	for(i = 0; i < sph_count; i++)
	{
		fy = sin(((i/(double)sph_count+render_sec_current/50.0)*3.3 + 1.0/3.0)*M_PI*2.0)*30.0 + 30.0;
		fx = sin(((i/(double)sph_count+render_sec_current/50.0)*2.0 + 0.0/3.0)*M_PI*2.0)*50.0;
		fz = sin(((i/(double)sph_count+render_sec_current/50.0)*1.0 + 2.0/3.0)*M_PI*2.0)*50.0 - 60.0;
		sph_set(i, fx, fy, fz,
			//sin((i*2.0/(double)sph_count + render_sec_current/3.0)*M_PI*2.0),
			4.0,
			sin(M_PI*2.0*((i/(double)sph_count) + 0.0/3.0))*128.0+127.5,
			sin(M_PI*2.0*((i/(double)sph_count) + 1.0/3.0))*128.0+127.5,
			sin(M_PI*2.0*((i/(double)sph_count) + 2.0/3.0))*128.0+127.5,
			255);

	}

	kd_generate();
#else
	sph_count=0;
#endif

#if SCENE_GENKD != 0
	static uint32_t sph_buf1[SPH_MAX];
	static float sph_buf2[12*KD_MAX];
	for(i = 0; i < sph_count; i++)
	{
		struct sph *sph = &sph_list[i];

		sph_buf1[1*i + 0] = sph->rgba;
		sph_buf2[KD_MAX*4*0 + 4*i + 0] = sph->v[0];
		sph_buf2[KD_MAX*4*0 + 4*i + 1] = sph->v[1];
		sph_buf2[KD_MAX*4*0 + 4*i + 2] = sph->v[2];
		sph_buf2[KD_MAX*4*0 + 4*i + 3] = sph->rad;
	}

	static float kd_buf1[KD_MAX];
	static uint32_t kd_buf2[2*KD_MAX];

	for(i = 0; i < kd_list_len; i++)
	{
		kd_buf1[1*i + 0] = kd_data_split_point[i];
		kd_buf2[2*i + 0] = kd_data_split_axis[i];
		struct kd *kd = &kd_list[i];
		sph_buf2[KD_MAX*4*1 + 4*i + 0] = kd->b1[0];
		sph_buf2[KD_MAX*4*1 + 4*i + 1] = kd->b1[1];
		sph_buf2[KD_MAX*4*1 + 4*i + 2] = kd->b1[2];
		sph_buf2[KD_MAX*4*2 + 4*i + 0] = kd->b2[0];
		sph_buf2[KD_MAX*4*2 + 4*i + 1] = kd->b2[1];
		sph_buf2[KD_MAX*4*2 + 4*i + 2] = kd->b2[2];
	}

	for(i = 0; i < spilist_len; i++)
	{
		kd_buf2[2*i + 1] = spilist[i];
	}
#endif

	if(!sent_shit)
	{
		// Get textures from Lua state
		lua_getglobal(Lbase, "tex_ray0"); tex_ray0 = lua_tointeger(Lbase, -1); lua_pop(Lbase, 1);
		lua_getglobal(Lbase, "tex_ray1"); tex_ray1 = lua_tointeger(Lbase, -1); lua_pop(Lbase, 1);
		lua_getglobal(Lbase, "tex_ray2"); tex_ray2 = lua_tointeger(Lbase, -1); lua_pop(Lbase, 1);
		lua_getglobal(Lbase, "tex_ray3"); tex_ray3 = lua_tointeger(Lbase, -1); lua_pop(Lbase, 1);
		lua_getglobal(Lbase, "tex_ray_rand"); tex_ray_rand = lua_tointeger(Lbase, -1); lua_pop(Lbase, 1);
		lua_getglobal(Lbase, "tex_ray_vox"); tex_ray_vox = lua_tointeger(Lbase, -1); lua_pop(Lbase, 1);

		printf("textures: %i %i %i %i %i %i\n"
			, tex_ray0
			, tex_ray1
			, tex_ray2
			, tex_ray3
			, tex_ray_vox
			, tex_ray_rand
		);

		// Send voxel landscape
		glBindTexture(GL_TEXTURE_2D, 0);
		glBindTexture(GL_TEXTURE_3D, tex_ray_vox);
		glGetError();

		FILE *fp = fopen("dat/voxel1.voxygen", "rb");

		// TODO: load more than a chunk
		// Layer 1: 128^3 chunks in a [z][x]
		// Layer 2: 32^3 outer layers in a 4^3 arrangement [z][x][y]
		// Layer 3: Descend the damn layers
		// in this engine we rearrange it to [y][z][x]
		int cx, cz;
		const int cy = 0;
		int sx, sy, sz;
		uint8_t *voxygen_buf[5];

		// TODO: shift *all* the voxygen stuff into src/voxel.c
		voxygen_buf[0] = malloc(128*128*128);
		voxygen_buf[1] = malloc(64*64*64);
		voxygen_buf[2] = malloc(32*32*32);
		voxygen_buf[3] = malloc(16*16*16);
		voxygen_buf[4] = malloc(8*8*8);

		printf("Decoding voxel data\n");
		//int i;
		//for(i = 0; i < 50; i++)
		{
			//fseek(fp, 0, SEEK_SET);
			decode_voxygen_chunk(voxygen_buf, fp);
		}

		printf("Uploading voxel data\n");
		int layer;
		for(layer = 0; layer <= 4; layer++)
		{
			int lsize = 128>>layer;
			int ly = 128*2-(lsize*2);
			for(sz = 0; sz < 512; sz += lsize)
			for(sx = 0; sx < 512; sx += lsize)
			for(sy = 0; sy < lsize; sy += lsize)
			{
				glTexSubImage3D(GL_TEXTURE_3D, 0, sx, sz, sy + ly, lsize, lsize, lsize, GL_RED_INTEGER, GL_UNSIGNED_BYTE, voxygen_buf[layer]);
				//printf("%i - %i %i %i %i\n", glGetError(), sx, sy, sz, ly);
			}
		}
		printf("Freeing voxel data\n");

		free(voxygen_buf[0]);
		free(voxygen_buf[1]);
		free(voxygen_buf[2]);
		free(voxygen_buf[3]);
		free(voxygen_buf[4]);

		fclose(fp);

		glBindTexture(GL_TEXTURE_3D, 0);
		int err = glGetError();
		printf("tex_vox %i\n", err);
		assert(err == 0);

		sent_shit = true;
	}

	glGetError();
#if SCENE_GENKD != 0
	glBindTexture(GL_TEXTURE_2D, tex_ray0);
	glTexSubImage2D(GL_TEXTURE_2D, 0, 0, 0, 1, sph_count, GL_RGBA, GL_UNSIGNED_BYTE, sph_buf1);
	//printf("tex0 %i\n", glGetError());
	glBindTexture(GL_TEXTURE_2D, tex_ray1);
	glTexSubImage2D(GL_TEXTURE_2D, 0, 0, 0, 1, kd_list_len, GL_RED, GL_FLOAT, kd_buf1);
	//printf("tex1 %i\n", glGetError());
	glBindTexture(GL_TEXTURE_2D, tex_ray2);
	glTexSubImage2D(GL_TEXTURE_2D, 0, 0, 0, 2, KD_MAX, GL_RED_INTEGER, GL_UNSIGNED_INT, kd_buf2);
	//printf("tex2 %i\n", glGetError());
	glBindTexture(GL_TEXTURE_2D, tex_ray3);
	glTexSubImage2D(GL_TEXTURE_2D, 0, 0, 0, sph_count, 3, GL_RGBA, GL_FLOAT, sph_buf2);
	//printf("tex3 %i\n", glGetError());
#endif

	glBindFramebuffer(GL_FRAMEBUFFER, fbo0);
#if SCENE_GENKD != 0
	glActiveTexture(GL_TEXTURE0 + 1);
	glBindTexture(GL_TEXTURE_2D, tex_ray1);
	glActiveTexture(GL_TEXTURE0 + 2);
	glBindTexture(GL_TEXTURE_2D, tex_ray2);
	glActiveTexture(GL_TEXTURE0 + 3);
	glBindTexture(GL_TEXTURE_2D, tex_ray3);
#endif
	glActiveTexture(GL_TEXTURE0 + 4);
	glBindTexture(GL_TEXTURE_2D, tex_ray_rand);
	glActiveTexture(GL_TEXTURE0 + 5);
	glBindTexture(GL_TEXTURE_3D, tex_ray_vox);
#if SCENE_GENKD != 0
	glActiveTexture(GL_TEXTURE0 + 0);
	glBindTexture(GL_TEXTURE_2D, tex_ray0);
#endif
	glUseProgram(shader_ray);

	mat4x4_invert(mat_cam2, mat_cam1);
	glUniformMatrix4fv(shader_ray_in_cam_inverse, 1, GL_FALSE, (GLfloat *)mat_cam2);
	glUniform2f(shader_ray_in_aspect, 720.0/1280.0, 1.0);

	glUniform1i(shader_ray_tex0, 0);
	glUniform1i(shader_ray_tex1, 1);
	glUniform1i(shader_ray_tex2, 2);
	glUniform1i(shader_ray_tex3, 3);
	glUniform1i(shader_ray_tex_rand, 4);
	glUniform1i(shader_ray_tex_vox, 5);
	glUniform1i(shader_ray_sph_count, sph_count);
	glUniform1f(shader_ray_sec_current, render_sec_current);

	float lcol[3*LIGHT_MAX];
	float lpos[3*LIGHT_MAX];
	float ldir[3*LIGHT_MAX];
	float lcos[LIGHT_MAX];
	float lpow[LIGHT_MAX];

#if 1
	int light_count = 1;

	lcol[0*3 + 0] = 1.0;
	lcol[0*3 + 1] = 1.0;
	lcol[0*3 + 2] = 1.0;
	lpos[0*3 + 0] = cam_pos_x;
	lpos[0*3 + 1] = cam_pos_y;
	lpos[0*3 + 2] = cam_pos_z;
	ldir[0*3 + 0] = -cos(cam_rot_x)*sin(cam_rot_y);
	ldir[0*3 + 1] = -sin(cam_rot_x);
	ldir[0*3 + 2] = -cos(cam_rot_x)*cos(cam_rot_y);
	/*
	lpos[0*3 + 0] = 0.0;
	lpos[0*3 + 1] = 128.0;
	lpos[0*3 + 2] = 0.0;
	ldir[0*3 + 0] = 0.0;
	ldir[0*3 + 1] = -1.0;
	ldir[0*3 + 2] = 0.0;
	*/
	lcos[0] = 1.0 - 0.7;
	//lpow[0] = 1.0/4.0;
	lpow[0] = 1.0/4.0;

	float light_amb = 0.1;
#else
#if 0
	int light_count = 3;

	lcol[0*3 + 0] = 1.0;
	lcol[0*3 + 1] = 0.5;
	lcol[0*3 + 2] = 0.5;
	lpos[0*3 + 0] = 0.0;
	lpos[0*3 + 1] = 5.0;
	lpos[0*3 + 2] = -10.0;
	ldir[0*3 + 0] = sin(render_sec_current)*15.0+5.0;
	ldir[0*3 + 1] = -20.0;
	ldir[0*3 + 2] = cos(render_sec_current)*15.0+5.0;
	lcos[0] = 1.0 - 0.7;
	lpow[0] = 1.0/4.0;

	lcol[1*3 + 0] = 0.5;
	lcol[1*3 + 1] = 0.5;
	lcol[1*3 + 2] = 1.0;
	lpos[1*3 + 0] = 0.0;
	lpos[1*3 + 1] = 5.0;
	lpos[1*3 + 2] = -60.0;
	ldir[1*3 + 0] = -sin(render_sec_current)*15.0+5.0;
	ldir[1*3 + 1] = -20.0;
	ldir[1*3 + 2] = -cos(render_sec_current)*15.0+5.0;
	lcos[1] = 1.0 - 0.7;
	lpow[1] = 1.0/4.0;

	lcol[2*3 + 0] = 0.5;
	lcol[2*3 + 1] = 1.0;
	lcol[2*3 + 2] = 0.5;
	lpos[2*3 + 0] = 20.0;
	lpos[2*3 + 1] = 40.0;
	lpos[2*3 + 2] = -30.0;
	ldir[2*3 + 0] = 0.0;
	ldir[2*3 + 1] = -1.0;
	ldir[2*3 + 2] = 0.0;
	lcos[2] = cos((45.0+15.0*-cos(render_sec_current*0.4))*M_PI/180.0);
	lpow[2] = 1.0/4.0;

	float light_amb = 0.2;

#else
	int light_count = (
		render_sec_current < 1.0
		? 0
		: render_sec_current < 3.0
		? 1
		: render_sec_current < 4.0
		? 3
		: 5);

	lcol[0*3 + 0] = 0.3;
	lcol[0*3 + 1] = 0.3;
	lcol[0*3 + 2] = 0.3;
	lpos[0*3 + 0] = 0.0;
	lpos[0*3 + 1] = 0.0;
	lpos[0*3 + 2] = 9.0;
	ldir[0*3 + 0] = 0.0;
	ldir[0*3 + 1] = 0.0;
	ldir[0*3 + 2] = -1.0;
	lcos[0] = 1.0 - 0.6;
	lpow[0] = 1.0/4.0;

	lcol[1*3 + 0] = 1.0;
	lcol[1*3 + 1] = 1.0;
	lcol[1*3 + 2] = 1.0;
	lpos[1*3 + 0] = 5.0;
	lpos[1*3 + 1] = 5.0;
	lpos[1*3 + 2] = -10.0;
	ldir[1*3 + 0] = 0.0;
	ldir[1*3 + 1] = -1.0;
	ldir[1*3 + 2] = 0.0;
	lcos[1] = cos(45.0*M_PI/180.0);
	lpow[1] = 1.0/2.0;

	lcol[2*3 + 0] = 1.0;
	lcol[2*3 + 1] = 1.0;
	lcol[2*3 + 2] = 1.0;
	lpos[2*3 + 0] =-5.0;
	lpos[2*3 + 1] = 5.0;
	lpos[2*3 + 2] = -10.0;
	ldir[2*3 + 0] = 0.0;
	ldir[2*3 + 1] = -1.0;
	ldir[2*3 + 2] = 0.0;
	lcos[2] = cos(45.0*M_PI/180.0);
	lpow[2] = 1.0/2.0;

	lcol[3*3 + 0] = 1.0;
	lcol[3*3 + 1] = 1.0;
	lcol[3*3 + 2] = 1.0;
	lpos[3*3 + 0] = 5.0;
	lpos[3*3 + 1] = 5.0;
	lpos[3*3 + 2] = -30.0;
	ldir[3*3 + 0] = 0.0;
	ldir[3*3 + 1] = -1.0;
	ldir[3*3 + 2] = 0.0;
	lcos[3] = cos(45.0*M_PI/180.0);
	lpow[3] = 1.0/2.0;

	lcol[4*3 + 0] = 1.0;
	lcol[4*3 + 1] = 1.0;
	lcol[4*3 + 2] = 1.0;
	lpos[4*3 + 0] =-5.0;
	lpos[4*3 + 1] = 5.0;
	lpos[4*3 + 2] = -30.0;
	ldir[4*3 + 0] = 0.0;
	ldir[4*3 + 1] = -1.0;
	ldir[4*3 + 2] = 0.0;
	lcos[4] = cos(45.0*M_PI/180.0);
	lpow[4] = 1.0/2.0;

	for(i = 0; i < 2; i++)
	{
		if(render_sec_current < 1.6)
		for(j = 0; j < 3; j++)
			lcol[3*(0) + j] *= (render_sec_current-1.0)/0.6;

		if(render_sec_current < 3.1)
		for(j = 0; j < 3; j++)
			lcol[3*(1+i) + j] *= (render_sec_current-3.0)/0.1;

		if(render_sec_current < 4.1)
		for(j = 0; j < 3; j++)
			lcol[3*(3+i) + j] *= (render_sec_current-4.0)/0.1;

	}

	float light_amb = (render_sec_current < 1.0
		? 0.0
		: lcol[3*0 + 0]) * 0.2;
#endif
#endif

	glUniform1ui(shader_ray_light_count, light_count);
	glUniform1f(shader_ray_light_amb, light_amb);
	glUniform3fv(shader_ray_light0_col, light_count, lcol);
	glUniform3fv(shader_ray_light0_pos, light_count, lpos);
	glUniform3fv(shader_ray_light0_dir, light_count, ldir);
	glUniform1fv(shader_ray_light0_cos, light_count, lcos);
	glUniform1fv(shader_ray_light0_pow, light_count, lpow);

	glUniform3f(shader_ray_bmin, bmin_x, bmin_y, bmin_z);
	glUniform3f(shader_ray_bmax, bmax_x, bmax_y, bmax_z);

	//printf("%i %i %i\n", sph_count, spilist_len, kd_list_len);
	//glUniform4fv(shader_ray_sph_data, sph_count, sph_data);
	//glUniform1uiv(shader_ray_kd_data_split_axis, kd_list_len, kd_data_split_axis);
	//glUniform1fv(shader_ray_kd_data_split_point, kd_list_len, kd_data_split_point);
	//glUniform1iv(shader_ray_kd_data_child1, kd_list_len, kd_data_child1);
	//glUniform1iv(shader_ray_kd_data_spibeg, kd_list_len, kd_data_spibeg);
	//glUniform1iv(shader_ray_kd_data_spilen, kd_list_len, kd_data_spilen);
	//glUniform1iv(shader_ray_kd_data_spilist, spilist_len, spilist);

	GLenum bufs2[] = {
		GL_COLOR_ATTACHMENT0 + 0,
		GL_COLOR_ATTACHMENT0 + 1,
	};
	glDrawBuffers(2, bufs2);
	glBindVertexArray(va_ray_vao);
	glDrawArrays(GL_TRIANGLES, 0, 6);
	glBindVertexArray(0);

	glDrawBuffer(GL_BACK);
	glBindFramebuffer(GL_FRAMEBUFFER, 0);
	glActiveTexture(GL_TEXTURE0 + 1);
	glBindTexture(GL_TEXTURE_2D, tex_fbo0_1);
	glActiveTexture(GL_TEXTURE0 + 0);
	glBindTexture(GL_TEXTURE_2D, tex_fbo0_0);
	glUseProgram(shader_blur);

	//printf("%i %i\n", shader_blur_tex0, shader_blur_tex1);
	glUniform1i(shader_blur_tex0, 0);
	glUniform1i(shader_blur_tex1, 1);

	glBindVertexArray(va_ray_vao);
	glDrawArrays(GL_TRIANGLES, 0, 6);
	glBindVertexArray(0);

	glBindTexture(GL_TEXTURE_2D, 0);
	glUseProgram(0);
}

