//version 130

// vim: syntax=c
const bool precise_shadows = true;

// true: faster, but some slopes get "pinched" out of the scene
// false: slower but safer
const bool do_slopes_beamer = true;

uniform float time;
uniform sampler2DArray tex_tiles;
uniform usampler3D tex_map;
uniform sampler2D tex_depth_in;
uniform bool have_depth_in;

uniform ivec3 bound_min;
uniform ivec3 bound_max;

in vec3 vert_ray_step;
flat in vec3 vert_cam_pos;
in vec2 vert_tc;
in vec2 vert_vertex;

#ifdef BEAMER
out vec2 out_depth;
#else
out vec4 out_color;
#endif

#ifdef BEAMER
void trace_scene(vec3 ray_pos, vec3 ray_dir, bool shadow_mode, out float trace_output)
#else
void trace_scene(vec3 ray_pos, vec3 ray_dir, inout float atime, out vec4 out_color)
#endif
{
	const int STEPS = 200;

#ifdef BEAMER
	trace_output = 0.0;
	float atime = 0.0;
#else
	out_color = vec4(0.0);
	float logsub = log(720.0/8.0);
#endif

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

#ifdef BEAMER
	if(do_slopes_beamer && lblk.b != 0x00U)
#else
	if(lblk.b != 0x00U)
#endif
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

		if(popcnt == 0 || dot(norm, norm) < 0.01)
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
#ifdef BEAMER
		if(do_slopes_beamer && mintime >= norm_slope_time)
#else
		if(mintime >= norm_slope_time)
#endif
		{
			// We didn't
#ifndef BEAMER
			vec4 cbase = vec4(1.0);

			vec3 ntx, nty;
			if(norm.x == 0.0 && norm.z == 0.0)
				ntx = -normalize(cross(norm, vec3(0.0, 0.0, 1.0)));
			else
				ntx = -normalize(cross(norm, vec3(0.0, 1.0, 0.0)));
			nty = normalize(cross(norm, ntx));
			vec3 antx = abs(ntx);
			vec3 anty = abs(nty);
			ntx *= (max(antx.x, max(antx.y, antx.z)));
			nty *= (max(anty.x, max(anty.y, anty.z)));
			aoffs -= norm_slope_time*adir;
			vec3 new_suboffs = mix(1.0-aoffs, aoffs, lessThan(ray_dir, vec3(0.0)));
			new_suboffs -= 0.5;
			vec2 tc = vec2(dot(ntx, new_suboffs), dot(nty, new_suboffs));
			tc += 0.5;
			cbase *= texture(tex_tiles, vec3(tc, float(lblk.r)), log(atime+norm_slope_time)-logsub);
			vec3 col = cbase.rgb;

			float diff = max(0.0, -dot(norm, ray_dir));
			const float amb = 0.1;
			diff = (1.0-amb)*diff + amb;

			if(lblk.a == 1U)
				col.rg *= 0.3;
			else if(lblk.a == 2U)
				col.gb *= 0.3;
#endif

#ifdef BEAMER
			if(shadow_mode)
#else
			if(cbase.a != 1.0)
#endif
			{
#ifdef BEAMER
				vec3 ntx, nty;
				if(norm.x == 0.0 && norm.z == 0.0)
					ntx = -normalize(cross(norm, vec3(0.0, 0.0, 1.0)));
				else
					ntx = -normalize(cross(norm, vec3(0.0, 1.0, 0.0)));
				nty = normalize(cross(norm, ntx));
				vec3 new_suboffs = mix(1.0-aoffs, aoffs, lessThan(ray_dir, vec3(0.0)));
				vec2 tc = vec2(dot(ntx, new_suboffs), dot(nty, new_suboffs));
				float cbase = texture(tex_tiles, vec3(tc, float(lblk.r)), atime).a;

				if(cbase < 1.0)
				{
					float tm = cbase;
					trace_output = 1.0 - trace_output;
					trace_output *= 1.0 - tm;
					trace_output = 1.0 - trace_output;
					if(trace_output > 254.0/255.0) break;
				} else {
					trace_output = 1.0;
					atime += norm_slope_time;
					break;
				}
#else
				float tm = cbase.a;
				//col = vec3(0.0, 0.0, 1.0);
				out_color.a = 1.0 - out_color.a;
				out_color.rgb += out_color.a*tm*col*diff;
				out_color.a *= 1.0 - tm;
				out_color.a = 1.0 - out_color.a;
				if(out_color.a > 254.0/255.0) return;
#endif
			} else {
				atime += norm_slope_time;
#ifdef BEAMER
				break;
#else
				out_color.rgb += (1.0 - out_color.a)*col*diff;
				out_color.a = 1.0;
				return;
#endif
			}
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
			int target_layer = min(layer_max, int((blk.a)>>4U));
			int layers_to_ascend = target_layer - layer;

			if(layers_to_ascend >= 1)
			{
				layer += layers_to_ascend;
				int lmask = (1<<layers_to_ascend)-1;
				ivec3 cell_lower = cell & lmask;
				cell >>= layers_to_ascend;
				aoffs += mix(vec3(lmask-cell_lower), vec3(cell_lower), lessThan(ray_dir, vec3(0.0)));
				aoffs /= float(1<<layers_to_ascend);
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

#ifdef BEAMER
			if(do_slopes_beamer && blk.b != 0x00U)
#else
			vec4 cbase = vec4(1.0);
			if(blk.b != 0x00U)
#endif
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

				if(popcnt == 0 || dot(norm, norm) < 0.01)
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

#ifndef BEAMER
			float diff = max(0.0, -dot(norm, ray_dir));
			const float amb = 0.1;
			diff = (1.0-amb)*diff + amb;

			vec3 ntx, nty;
			if(norm.x == 0.0 && norm.z == 0.0)
				ntx = -normalize(cross(norm, vec3(0.0, 0.0, 1.0)));
			else
				ntx = -normalize(cross(norm, vec3(0.0, 1.0, 0.0)));
			nty = normalize(cross(norm, ntx));
			vec3 new_suboffs = mix(1.0-aoffs, aoffs, lessThan(ray_dir, vec3(0.0)));
			vec2 tc = vec2(dot(ntx, new_suboffs), dot(nty, new_suboffs));
			cbase *= texture(tex_tiles, vec3(tc, float(blk.r)), log(atime)-logsub);
			//cbase *= texture(tex_tiles, vec3(tc, float(blk.b)), atime);
			//cbase.a = 1.0;
			vec3 col = cbase.rgb;
			if(blk.a == 1U)
				col.rg *= 0.3;
			else if(blk.a == 2U)
				col.gb *= 0.3;
#endif

#ifdef BEAMER
			if(shadow_mode)
#else
			if(cbase.a < 1.0)
#endif
			{
#ifdef BEAMER
				vec3 ntx, nty;
				if(norm.x == 0.0 && norm.z == 0.0)
					ntx = -normalize(cross(norm, vec3(0.0, 0.0, 1.0)));
				else
					ntx = -normalize(cross(norm, vec3(0.0, 1.0, 0.0)));
				nty = normalize(cross(norm, ntx));
				vec3 new_suboffs = mix(1.0-aoffs, aoffs, lessThan(ray_dir, vec3(0.0)));
				vec2 tc = vec2(dot(ntx, new_suboffs), dot(nty, new_suboffs));
				float cbase = texture(tex_tiles, vec3(tc, float(blk.r)), atime).a;

				if(cbase < 1.0)
				{
					float tm = cbase;
					trace_output = 1.0 - trace_output;
					trace_output *= 1.0 - tm;
					trace_output = 1.0 - trace_output;
					if(trace_output > 254.0/255.0) break;
				} else {
					trace_output = 1.0;
					break;
				}
#else
				float tm = cbase.a;
				//col = vec3(0.0, 0.0, 1.0);
				out_color.a = 1.0 - out_color.a;
				out_color.rgb += out_color.a*tm*col*diff;
				out_color.a *= 1.0 - tm;
				out_color.a = 1.0 - out_color.a;
				if(out_color.a > 254.0/255.0) return;
#endif
			} else {
#ifdef BEAMER
				break;
#else
				out_color.rgb += (1.0 - out_color.a)*col*diff;
				out_color.a = 1.0;
				return;
#endif
			}
		}
		lblk = blk;
	}

#ifdef BEAMER
	if(!shadow_mode)
		trace_output = atime;
#endif
}

void main()
{
	const vec4 BG = vec4(0.1, 0.0, 0.2, 1.0);

	float fisheye = 1.0*length(vec3(vert_vertex, 1.0));
	float ifisheye = 1.0/fisheye;

	vec3 ray_pos = vert_cam_pos + vec3((bound_max+bound_min)/2) + 0.5;
	vec3 ray_dir = normalize(vert_ray_step);

	float new_time = 0.0;
#ifndef BEAMER
	float pretrace_time = 0.0;
	float pretrace_shadow = 0.0;
	float pretrace_shadow_variance = 0.0;
#endif

	bool need_extra_trace = false;

	if(have_depth_in)
	{
		// FIXME this needs a tidyup
		vec2 dbb = textureOffset(tex_depth_in, vert_tc, ivec2( 0, 0)).rg;
		vec2 dx0 = textureOffset(tex_depth_in, vert_tc, ivec2(-1, 0)).rg;
		vec2 dy0 = textureOffset(tex_depth_in, vert_tc, ivec2( 0,-1)).rg;
		vec2 dx1 = textureOffset(tex_depth_in, vert_tc, ivec2( 1, 0)).rg;
		vec2 dy1 = textureOffset(tex_depth_in, vert_tc, ivec2( 0, 1)).rg;
		//vec2 dx2 = textureOffset(tex_depth_in, vert_tc, ivec2( 2, 0)).rg;
		//vec2 dy2 = textureOffset(tex_depth_in, vert_tc, ivec2( 0, 2)).rg;
		vec2 dtime = max(dbb, max(max(dx0, dx1), max(dy0, dy1)));
		vec2 rtime = min(dbb, min(min(dx0, dx1), min(dy0, dy1)));

		dtime.r = ifisheye/dtime.r;
		rtime.r = ifisheye/rtime.r;

		float dgradx0 = dbb.r - dx0.r;
		float dgrady0 = dbb.r - dy0.r;
		float dgradx1 = dx1.r - dbb.r;
		float dgrady1 = dy1.r - dbb.r;
		//float dgradx2 = dx2.r - dx1.r;
		//float dgrady2 = dy2.r - dy1.r;
		//float dgrad2x = max(abs(dgradx1 - dgradx0), abs(dgradx2 - dgradx1));
		//float dgrad2y = max(abs(dgrady1 - dgrady0), abs(dgrady2 - dgrady1));
		float dgrad2x = abs(dgradx1 - dgradx0);
		float dgrad2y = abs(dgrady1 - dgrady0);
		float d = dgrad2x + dgrad2y;
#ifdef BEAMER
		// FIXME this is probably incorrect now
		// by FIXME i mean "fix or chuck it out"
		//dtime.r -= min(1.0, dtime.r-rtime.r);
#else
		pretrace_time = dtime.r;
		pretrace_shadow = rtime.g;
		//pretrace_shadow_variance = rtime.g - dtime.g;
		pretrace_shadow_variance = dtime.g - rtime.g;
#endif
		bool fast_trace = (d < 1.0/256.0);

		if(fast_trace)
		{
			new_time = ifisheye/dbb.r - 0.01;

			if(texelFetch(tex_map, ivec3(floor(ray_pos + ray_dir * new_time)), 0).r != 0x00U)
				fast_trace = false;
		}

		if(fast_trace)
		{
			dtime.r = new_time;
		} else {
			dtime.r -= 1.0;
			need_extra_trace = true;
		}

		dtime.r = max(0.0, dtime.r);
		new_time = dtime.r;
		ray_pos += ray_dir * new_time;
	}

#ifdef BEAMER
	trace_scene(ray_pos, ray_dir, false, out_depth.r);
	out_depth.r += new_time;
	trace_scene(ray_pos + ray_dir*((out_depth.r - new_time)-0.01),
		normalize(vec3(0.3, 1.0, 0.3)),
		true, out_depth.g);
	out_depth.r = ifisheye/out_depth.r;
#else
	float atime_main = new_time;
	float atime_shad = 0.0;
	trace_scene(ray_pos, ray_dir, atime_main, out_color);
	//out_color.r += atime_main - new_time;
	//if(need_extra_trace) out_color.b += 1.0;

	if(true) // Shadows
	{
		//if(out_color.a >= 1.0/255.0)
		if(out_color.a >= 1.0)
		{
			vec3 shadow_ray_pos = ray_pos + ray_dir*(atime_main - new_time - 0.01);
			vec4 shadow_color = vec4(0.0);
			if((!precise_shadows) || (pretrace_shadow_variance < 0.01 && abs(atime_main - new_time) < 0.3))
			{
				shadow_color.a = pretrace_shadow;
			} else {
				//out_color.g += 1.0;
				trace_scene(shadow_ray_pos,
					normalize(vec3(0.3, 1.0, 0.3)),
				atime_shad, shadow_color);
			}
			out_color.rgb *= ((1.0-shadow_color.a)*0.6+0.4);
		} else {
			out_color.rgb *= 0.4;
		}
	}

	out_color.rgb += BG.rgb * (1.0-out_color.a);
	out_color.a = 1.0;
#endif
}

