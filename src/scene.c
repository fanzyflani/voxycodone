#include "common.h"

double cam_rot_x = 0.0;
double cam_rot_y = 0.0;
double cam_pos_x = 0.0;
double cam_pos_y = 0.0;
double cam_pos_z = 0.0;

void h_render_main(void)
{
	mat4x4 mat_cam1;
	mat4x4 mat_cam2;

	mat4x4_identity(mat_cam1);
	mat4x4_rotate_X(mat_cam2, mat_cam1, cam_rot_x);
	mat4x4_rotate_Y(mat_cam1, mat_cam2, cam_rot_y);
	mat4x4_translate_in_place(mat_cam1, -cam_pos_x, -cam_pos_y, -cam_pos_z);

	int x, y, z, i;
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

	//sph_count = 16;
	//sph_count=0;
	kd_generate();

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

	glGetError();
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

	glActiveTexture(GL_TEXTURE0 + 1);
	glBindTexture(GL_TEXTURE_2D, tex_ray1);
	glActiveTexture(GL_TEXTURE0 + 2);
	glBindTexture(GL_TEXTURE_2D, tex_ray2);
	glActiveTexture(GL_TEXTURE0 + 3);
	glBindTexture(GL_TEXTURE_2D, tex_ray3);
	glActiveTexture(GL_TEXTURE0 + 0);
	glBindTexture(GL_TEXTURE_2D, tex_ray0);
	glUseProgram(shader_ray);

	mat4x4_invert(mat_cam2, mat_cam1);
	glUniformMatrix4fv(shader_ray_in_cam_inverse, 1, GL_FALSE, (GLfloat *)mat_cam2);
	glUniform2f(shader_ray_in_aspect, 720.0/1280.0, 1.0);

	glUniform1i(shader_ray_tex0, 0);
	glUniform1i(shader_ray_tex1, 1);
	glUniform1i(shader_ray_tex2, 2);
	glUniform1i(shader_ray_tex3, 3);
	glUniform1i(shader_ray_sph_count, sph_count);

	float lpos[3*32];
	float ldir[3*32];
	float lcos[32];
	float lpow[32];

	lpos[0*3 + 0] = 0.0;
	lpos[0*3 + 1] = 5.0;
	lpos[0*3 + 2] = -10.0;
	ldir[0*3 + 0] = sin(render_sec_current)*15.0+5.0;
	ldir[0*3 + 1] = -20.0;
	ldir[0*3 + 2] = cos(render_sec_current)*15.0+5.0;
	lcos[0] = 1.0 - 0.7;
	lpow[0] = 1.0/4.0;

	lpos[1*3 + 0] = 0.0;
	lpos[1*3 + 1] = 5.0;
	lpos[1*3 + 2] = -60.0;
	ldir[1*3 + 0] = -sin(render_sec_current)*15.0+5.0;
	ldir[1*3 + 1] = -20.0;
	ldir[1*3 + 2] = -cos(render_sec_current)*15.0+5.0;
	lcos[1] = 1.0 - 0.7;
	lpow[1] = 1.0/4.0;

	glUniform3fv(shader_ray_light0_pos, 2, lpos);
	glUniform3fv(shader_ray_light0_dir, 2, ldir);
	glUniform1fv(shader_ray_light0_cos, 2, lcos);
	glUniform1fv(shader_ray_light0_pow, 2, lpow);

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

	glBindVertexArray(va_ray_vao);
	glDrawArrays(GL_TRIANGLES, 0, 6);
	glBindVertexArray(0);

	glBindTexture(GL_TEXTURE_2D, 0);
	glUseProgram(0);
}

void hook_tick(double sec_current, double sec_delta)
{
	double mvspeed = 20.0;
	//double mvspeed = 2.0;
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
