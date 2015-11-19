#version 150

// vim: syntax=c

// true: faster, but some slopes get "pinched" out of the scene
// false: slower but safer
const bool do_slopes = true;

uniform float time;
uniform usampler3D tex_map;
uniform sampler2D tex_depth_in;
uniform bool have_depth_in;

uniform ivec3 bound_min;
uniform ivec3 bound_max;

in vec3 vert_ray_step;
flat in vec3 vert_cam_pos;
in vec2 vert_tc;

out vec2 out_depth;

void trace_scene(vec3 ray_pos, vec3 ray_dir, bool shadow_mode, out float trace_output)
{
	const int STEPS = 200;

	trace_output = 0.0;
	float atime = 0.0;

	if(any(lessThan(ray_pos, vec3(bound_min))) || any(greaterThanEqual(ray_pos, vec3(bound_max))))
	{
		// Trace to entry
		vec3 vtime_a = (vec3(bound_min)-ray_pos)/ray_dir;
		vec3 vtime_b = (vec3(bound_max)-ray_pos)/ray_dir;

		// Get suitable traces
		vec3 vtime_min = min(vtime_a, vtime_b);
		vec3 vtime_max = max(vtime_a, vtime_b);

		// Max-min for entry
		float time_enter = max(vtime_min.x, max(vtime_min.y, vtime_min.z));
		float time_exit  = min(vtime_max.x, min(vtime_max.y, vtime_max.z));

		// If it's behind us, don't draw it
		// (otherwise you get a kinda fun bug)
		if(time_exit < 0.001)
			return;

		// Cannot enter after we exit - this means we didn't even hit
		if(time_enter > time_exit)
			return;

		// Advance
		atime += time_enter + 0.1;
		ray_pos += ray_dir * (time_enter + 0.1);
	}

	const int layer_max = 6;
	int layer = 0;
	ray_pos /= float(1<<layer);
	ivec3 cell = ivec3(floor(ray_pos));

	vec3 src_suboffs = (ray_pos - floor(ray_pos));
	ivec3 cell_dir = ivec3(sign(ray_dir));
	vec3 aoffs = mix(1.0-src_suboffs, src_suboffs, lessThan(ray_dir, vec3(0.0)));
	vec3 adir = abs(ray_dir);
	bvec3 last_crossed = bvec3(false, false, true);
	uvec4 lblk = texelFetch(tex_map, cell, layer);
	vec3 norm = vec3(0.0, 0.0, 1.0);
	float norm_slope_time = 40.0;

	if(do_slopes && lblk.b != 0x00U)
	{
		vec3 old_norm = norm;
		norm = vec3(0.0);
		int popcnt = 0;

		if((lblk.b & 0x01U) != 0U) { norm += vec3(-1.0,-1.0,-1.0); popcnt++; }
		if((lblk.b & 0x02U) != 0U) { norm += vec3( 1.0,-1.0,-1.0); popcnt++; }
		if((lblk.b & 0x04U) != 0U) { norm += vec3(-1.0, 1.0,-1.0); popcnt++; }
		if((lblk.b & 0x08U) != 0U) { norm += vec3(-1.0,-1.0, 1.0); popcnt++; }
		if((lblk.b & 0x10U) != 0U) { norm += vec3( 1.0, 1.0,-1.0); popcnt++; }
		if((lblk.b & 0x20U) != 0U) { norm += vec3(-1.0, 1.0, 1.0); popcnt++; }
		if((lblk.b & 0x40U) != 0U) { norm += vec3( 1.0,-1.0, 1.0); popcnt++; }
		if((lblk.b & 0x80U) != 0U) { norm += vec3( 1.0, 1.0, 1.0); popcnt++; }

		if(popcnt == 0)
		{
			norm = old_norm;
		} else {
			norm = normalize(norm);

			// Get cell suboffset
			vec3 new_suboffs = mix(1.0-aoffs, aoffs, lessThan(ray_dir, vec3(0.0)));

			// Calculate plane stuff
			float nf_plane = dot(vec3(0.5), norm);
			if(popcnt == 1) nf_plane += 0.5/sqrt(3.0);
			else if(popcnt == 3) nf_plane -= 1.0/sqrt(5.0); // approximate
			else if(popcnt == 4) nf_plane -= 0.5/sqrt(3.0);
			float nf_suboffs = dot(new_suboffs, norm);
			float nf_adir = dot(ray_dir, norm);

			float nf_vel = nf_adir;
			float nf_dist = nf_suboffs - nf_plane;

			if(nf_dist <= 0.0)
			{
				norm = old_norm;
			} else if(nf_vel >= 0.0) {
				//
			} else {
				norm_slope_time = -nf_dist/nf_vel;
			}
		}
	}

	for(int i = 0; i < STEPS; i++)
	{
		// Get time to border
		vec3 vtime = aoffs/adir;
		float mintime = min(vtime.x, min(vtime.y, vtime.z));
		last_crossed = equal(vtime, vec3(mintime));

		// Check if we made it in time
		if(do_slopes && mintime >= norm_slope_time)
		{
			// We didn't
			atime += norm_slope_time;
			if(shadow_mode) trace_output = 1.0; // TODO: translucency
			break;
		}

		// We made it in time
		norm_slope_time = 40.0;

		// Trace
		atime += mintime*float(1<<layer);
		cell += cell_dir*ivec3(last_crossed);
		aoffs -= mintime*adir;
		aoffs += vec3(last_crossed);

		// Get next voxel
		if(any(lessThan(cell, bound_min>>layer)) || any(greaterThanEqual(cell<<layer, bound_max)))
		{
			break;
		}
		uvec4 blk = texelFetch(tex_map, cell, layer);

		// Ascension
		if(blk.r == 0x00U && (blk.a & 0xF0U) != 0x00U)
		{
			while(layer < layer_max && layer < int((blk.a)>>4))
			{
				layer++;
				ivec3 cell_lower = cell & 1;
				cell >>= 1;
				aoffs += mix(vec3(1-cell_lower), vec3(cell_lower), lessThan(ray_dir, vec3(0.0)));
				aoffs /= 2.0;
			}

			blk = texelFetch(tex_map, cell, layer);
		} else {
			// Descension
			while(layer > 0 && blk.r != 0x00U)
			{
				layer--;
				cell <<= 1;
				aoffs *= 2.0;
				cell ^= ivec3(floor(0.5+mix(vec3(1.0), vec3(0.0), lessThan(ray_dir, vec3(0.0)))));
				cell ^= ivec3(floor(0.5+mix(vec3(0.0), vec3(1.0), greaterThan(aoffs, vec3(1.0)))));
				aoffs -= vec3(greaterThan(aoffs, vec3(1.0)));
				blk = texelFetch(tex_map, cell, layer);
			}
		}

		if(blk.r != 0x00U)
		{
			norm = mix(vec3(0.0), -sign(ray_dir), last_crossed);
			vec3 norig = vec3(0.5);

			// 0x0FU: -Y, -X, -Z
			if(do_slopes && blk.b != 0x00U)
			{
				vec3 old_norm = norm;
				norm = vec3(0.0);
				int popcnt = 0;

				if((blk.b & 0x01U) != 0U) { norm += vec3(-1.0,-1.0,-1.0); popcnt++; }
				if((blk.b & 0x02U) != 0U) { norm += vec3( 1.0,-1.0,-1.0); popcnt++; }
				if((blk.b & 0x04U) != 0U) { norm += vec3(-1.0, 1.0,-1.0); popcnt++; }
				if((blk.b & 0x08U) != 0U) { norm += vec3(-1.0,-1.0, 1.0); popcnt++; }
				if((blk.b & 0x10U) != 0U) { norm += vec3( 1.0, 1.0,-1.0); popcnt++; }
				if((blk.b & 0x20U) != 0U) { norm += vec3(-1.0, 1.0, 1.0); popcnt++; }
				if((blk.b & 0x40U) != 0U) { norm += vec3( 1.0,-1.0, 1.0); popcnt++; }
				if((blk.b & 0x80U) != 0U) { norm += vec3( 1.0, 1.0, 1.0); popcnt++; }

				if(popcnt == 0)
				{
					norm = old_norm;
				} else {
					norm = normalize(norm);

					// Get cell suboffset
					vec3 new_suboffs = mix(1.0-aoffs, aoffs, lessThan(ray_dir, vec3(0.0)));

					// Calculate plane stuff
					float nf_plane = dot(vec3(0.5), norm);
					if(popcnt == 1) nf_plane += 0.5/sqrt(3.0);
					else if(popcnt == 3) nf_plane -= 1.0/sqrt(5.0); // approximate
					else if(popcnt == 4) nf_plane -= 0.5/sqrt(3.0);
					float nf_suboffs = dot(new_suboffs, norm);
					float nf_adir = dot(ray_dir, norm);

					float nf_vel = nf_adir;
					float nf_dist = nf_suboffs - nf_plane;

					if(nf_dist <= 0.0)
					{
						norm = old_norm;
					} else if(nf_vel >= 0.0) {
						continue;
					} else {
						norm_slope_time = -nf_dist/nf_vel;
						lblk = blk;
						continue;
					}
				}
			}

			if(shadow_mode) trace_output = 1.0; // TODO: translucency
			break;
		}
		lblk = blk;
	}

	if(!shadow_mode)
		trace_output = atime;
}

void main()
{
	const vec4 BG = vec4(0.1, 0.0, 0.2, 1.0);

	vec3 ray_pos = vert_cam_pos + vec3((bound_max+bound_min)/2) + 0.5;
	vec3 ray_dir = normalize(vert_ray_step);

	float new_time = 0.0;

	if(have_depth_in)
	{
		vec2 dbb = textureOffset(tex_depth_in, vert_tc, ivec2( 0, 0)).rg;
		vec2 d00 = textureOffset(tex_depth_in, vert_tc, ivec2(-1, 0)).rg;
		vec2 d01 = textureOffset(tex_depth_in, vert_tc, ivec2( 0,-1)).rg;
		vec2 d10 = textureOffset(tex_depth_in, vert_tc, ivec2( 1, 0)).rg;
		vec2 d11 = textureOffset(tex_depth_in, vert_tc, ivec2( 0, 1)).rg;
		vec2 dtime = min(dbb, min(min(d00, d01), min(d10, d11)));
		vec2 rtime = max(dbb, max(max(d00, d01), max(d10, d11)));
		dtime.r -= min(1.0, rtime.r-dtime.r);
		dtime = max(vec2(0.0), dtime);
		new_time = dtime.r;
		ray_pos += ray_dir * new_time;
	}

	trace_scene(ray_pos, ray_dir, false, out_depth.r);
	out_depth.r += new_time;
	trace_scene(ray_pos + ray_dir*((out_depth.r - new_time)-0.01),
		normalize(vec3(0.3, 1.0, 0.3)),
		true, out_depth.g);
}



