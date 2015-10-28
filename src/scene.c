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
	if(!sent_shit)
	{
		// Get textures from Lua state
		lua_getglobal(Lbase, "tex_ray_vox"); tex_ray_vox = lua_tointeger(Lbase, -1); lua_pop(Lbase, 1);

		// Send voxel landscape
		glBindTexture(GL_TEXTURE_3D, tex_ray_vox);
		voxygen_load_repeated_chunk("dat/voxel1.voxygen");
		glBindTexture(GL_TEXTURE_3D, 0);

		sent_shit = true;
	}

	glGetError();

	// Call Lua hook
	lua_getglobal(Lbase, "hook_render");
	lua_pushnumber(Lbase, render_sec_current);
	lua_call(Lbase, 1, 0);
}

