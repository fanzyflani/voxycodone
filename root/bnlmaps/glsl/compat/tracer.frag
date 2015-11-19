// version 120

// vim: syntax=c
const bool precise_shadows = true;

const vec3 MULDIM = 1.0/vec3(256.0+32.0, 64.0+32.0, 128.0);
// FIXME: completely fucks up when compiled as a uniform
//uniform vec2 imuldepth;
//const vec2 MULDEPTH = 4.0/vec2(1280.0, 720.0);
//const vec2 IMULDEPTH = vec2(1280.0, 720.0)/4.0;

uniform float time;
uniform sampler3D tex_tiles;
uniform sampler3D tex_map;
uniform sampler2D tex_depth_in;
uniform bool have_depth_in;

uniform ivec3 bound_min;
uniform ivec3 bound_max;

varying vec3 vert_ray_step;
invariant varying vec3 vert_cam_pos;
varying vec2 vert_tc;

//out vec4 out_color;

vec4 trace_scene(vec3 ray_pos, vec3 ray_dir, inout float atime)
{
	const int STEPS = 200;
	vec4 out_color = vec4(0.0);

	float logsub = log(720.0/8.0);
	//logsub += log(length(vec3(vert_tc.x * 1280.0/720.0, vert_tc.y, 1.0)));

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
			return out_color;

		// Cannot enter after we exit - this means we didn't even hit
		if(time_enter > time_exit)
			return out_color;

		// Advance
		atime += time_enter + 0.1;
		ray_pos += ray_dir * (time_enter + 0.1);
	}

	const int layer_max = 0; // FIXME: LOD seems broken
	int layer = 0;
	ray_pos /= 1.0*pow(2.0, float(layer));
	ivec3 cell = ivec3(floor(ray_pos));

	vec3 src_suboffs = (ray_pos - floor(ray_pos));
	ivec3 cell_dir = ivec3(sign(ray_dir));
	vec3 aoffs = mix(1.0-src_suboffs, src_suboffs, vec3(lessThan(ray_dir, vec3(0.0))));
	vec3 adir = abs(ray_dir);
	bvec3 last_crossed = bvec3(false, false, true);
	vec4 lblk = floor(0.5+255.0*texture3D(tex_map, (cell+0.5)*MULDIM, float(layer)));
	vec3 norm = vec3(0.0, 0.0, 1.0);
	float norm_slope_time = 40.0;

	if(lblk.b != 0.0)
	{
		vec3 old_norm = norm;
		norm = vec3(0.0);
		int popcnt = 0;

		float tsrc = lblk.b;
		if(tsrc >= 127.5) { norm += vec3( 1.0, 1.0, 1.0); popcnt++; tsrc -= 128.0; } tsrc *= 2.0;
		if(tsrc >= 127.5) { norm += vec3( 1.0,-1.0, 1.0); popcnt++; tsrc -= 128.0; } tsrc *= 2.0;
		if(tsrc >= 127.5) { norm += vec3(-1.0, 1.0, 1.0); popcnt++; tsrc -= 128.0; } tsrc *= 2.0;
		if(tsrc >= 127.5) { norm += vec3( 1.0, 1.0,-1.0); popcnt++; tsrc -= 128.0; } tsrc *= 2.0;
		if(tsrc >= 127.5) { norm += vec3(-1.0,-1.0, 1.0); popcnt++; tsrc -= 128.0; } tsrc *= 2.0;
		if(tsrc >= 127.5) { norm += vec3(-1.0, 1.0,-1.0); popcnt++; tsrc -= 128.0; } tsrc *= 2.0;
		if(tsrc >= 127.5) { norm += vec3( 1.0,-1.0,-1.0); popcnt++; tsrc -= 128.0; } tsrc *= 2.0;
		if(tsrc >= 127.5) { norm += vec3(-1.0,-1.0,-1.0); popcnt++; tsrc -= 128.0; } tsrc *= 2.0;

		if(popcnt == 0 || dot(norm, norm) < 0.01)
		{
			norm = old_norm;
		} else {
			norm = normalize(norm);

			// Get cell suboffset
			vec3 new_suboffs = mix(1.0-aoffs, aoffs, vec3(lessThan(ray_dir, vec3(0.0))));

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
		if(mintime >= norm_slope_time)
		{
			// We didn't
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
			vec3 new_suboffs = mix(1.0-aoffs, aoffs, vec3(lessThan(ray_dir, vec3(0.0))));
			new_suboffs -= 0.5;
			vec2 tc = vec2(dot(ntx, new_suboffs), dot(nty, new_suboffs));
			tc += 0.5;
			cbase *= texture3D(tex_tiles, vec3(tc, float(lblk.r+0.5)/256.0));
			vec3 col = cbase.rgb;

			float diff = max(0.0, -dot(norm, ray_dir));
			const float amb = 0.1;
			diff = (1.0-amb)*diff + amb;

			if(lblk.a == 1U)
				col.rg *= 0.3;
			else if(lblk.a == 2U)
				col.gb *= 0.3;

			if(cbase.a != 1.0)
			{
				float tm = cbase.a;
				//col = vec3(0.0, 0.0, 1.0);
				out_color.a = 1.0 - out_color.a;
				out_color.rgb += out_color.a*tm*col*diff;
				out_color.a *= 1.0 - tm;
				out_color.a = 1.0 - out_color.a;
				if(out_color.a > 254.0/255.0) return out_color;
			} else {
				out_color.rgb += (1.0 - out_color.a)*col*diff;
				out_color.a = 1.0;
				atime += norm_slope_time;
				return out_color;
			}
		}

		// We made it in time
		norm_slope_time = 40.0;

		// Trace
		atime += mintime*pow(2.0, float(layer));
		cell += cell_dir*ivec3(last_crossed);
		aoffs -= mintime*adir;
		aoffs += vec3(last_crossed);

		// Get next voxel
		if(any(lessThan(cell, ivec3(floor(bound_min/pow(2.0, float(layer))))))
			|| any(greaterThanEqual(ivec3(cell*pow(2.0, float(layer))), bound_max)))
		{
			/*
			out_color.rgb = vec3(last_crossed);
			if(dot(vec3(last_crossed), vec3(cell_dir)) < 0.0)
				out_color.rgb = 1.0 - out_color.rgb;
			*/
			break;
		}
		vec4 blk = floor(0.5+255.0*texture3D(tex_map, (cell+0.5)*MULDIM, float(layer)));

		// Ascension
		if(blk.r == 0.0 && floor(blk.a/16.0+0.1) != 0.0)
		{
			int target_layer = min(layer_max, int(floor(0.1+(blk.a/16.0))));
			int layers_to_ascend = target_layer - layer;

			if(layers_to_ascend >= 1)
			{
				layer += layers_to_ascend;
				float lmask = pow(2.0, float(layers_to_ascend));
				ivec3 cell_lower = ivec3(floor(0.5+mod(vec3(cell), lmask)));
				cell = ivec3(floor(0.0001 + vec3(cell)/pow(2.0, float(layers_to_ascend))));
				aoffs += mix(vec3(lmask-cell_lower), vec3(cell_lower), vec3(lessThan(ray_dir, vec3(0.0))));
				aoffs /= lmask;
			}

			blk = floor(0.5+255.0*texture3D(tex_map, (cell+0.5)*MULDIM, float(layer)));
		} else {
			// Descension
			while(layer > 0 && blk.r != 0.0)
			{
				layer--;
				cell *= 2;
				aoffs *= 2.0;
				cell += ivec3(notEqual(
					ivec3(floor(0.5+mix(vec3(1.0), vec3(0.0), vec3(lessThan(ray_dir, vec3(0.0))))))
					,
					ivec3(floor(0.5+mix(vec3(0.0), vec3(1.0), vec3(greaterThan(aoffs, vec3(1.0))))))
				));
				aoffs -= vec3(greaterThan(aoffs, vec3(1.0)));
				blk = floor(0.5+255.0*texture3D(tex_map, (cell+0.5)*MULDIM, float(layer)));
			}
		}

		if(blk.r != 0.0)
		{
			vec4 cbase = vec4(1.0);
			norm = mix(vec3(0.0), -sign(ray_dir), vec3(last_crossed));

			if(blk.b != 0.0)
			{
				vec3 old_norm = norm;
				norm = vec3(0.0);
				int popcnt = 0;

				float tsrc = blk.b;
				if(tsrc >= 127.5) { norm += vec3( 1.0, 1.0, 1.0); popcnt++; tsrc -= 128.0; } tsrc *= 2.0;
				if(tsrc >= 127.5) { norm += vec3( 1.0,-1.0, 1.0); popcnt++; tsrc -= 128.0; } tsrc *= 2.0;
				if(tsrc >= 127.5) { norm += vec3(-1.0, 1.0, 1.0); popcnt++; tsrc -= 128.0; } tsrc *= 2.0;
				if(tsrc >= 127.5) { norm += vec3( 1.0, 1.0,-1.0); popcnt++; tsrc -= 128.0; } tsrc *= 2.0;
				if(tsrc >= 127.5) { norm += vec3(-1.0,-1.0, 1.0); popcnt++; tsrc -= 128.0; } tsrc *= 2.0;
				if(tsrc >= 127.5) { norm += vec3(-1.0, 1.0,-1.0); popcnt++; tsrc -= 128.0; } tsrc *= 2.0;
				if(tsrc >= 127.5) { norm += vec3( 1.0,-1.0,-1.0); popcnt++; tsrc -= 128.0; } tsrc *= 2.0;
				if(tsrc >= 127.5) { norm += vec3(-1.0,-1.0,-1.0); popcnt++; tsrc -= 128.0; } tsrc *= 2.0;

				if(popcnt == 0 || dot(norm, norm) < 0.5)
				{
					norm = old_norm;
				} else {
					norm = normalize(norm);

					// Get cell suboffset
					vec3 new_suboffs = mix(1.0-aoffs, aoffs, vec3(lessThan(ray_dir, vec3(0.0))));

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

			float diff = max(0.0, -dot(norm, ray_dir));
			const float amb = 0.1;
			diff = (1.0-amb)*diff + amb;

			vec3 ntx, nty;
			if(norm.x == 0.0 && norm.z == 0.0)
				ntx = -normalize(cross(norm, vec3(0.0, 0.0, 1.0)));
			else
				ntx = -normalize(cross(norm, vec3(0.0, 1.0, 0.0)));
			nty = normalize(cross(norm, ntx));
			vec3 new_suboffs = mix(1.0-aoffs, aoffs, vec3(lessThan(ray_dir, vec3(0.0))));
			vec2 tc = vec2(dot(ntx, new_suboffs), dot(nty, new_suboffs));
			cbase *= texture3D(tex_tiles, vec3(tc, float(blk.r+0.5)/256.0));
			//cbase *= texture(tex_tiles, vec3(tc, float(blk.b)), atime);
			//cbase.a = 1.0;
			vec3 col = cbase.rgb;
			if(blk.a == 1U)
				col.rg *= 0.3;
			else if(blk.a == 2U)
				col.gb *= 0.3;

			if(cbase.a < 1.0)
			{
				float tm = cbase.a;
				//col = vec3(0.0, 0.0, 1.0);
				out_color.a = 1.0 - out_color.a;
				out_color.rgb += out_color.a*tm*col*diff;
				out_color.a *= 1.0 - tm;
				out_color.a = 1.0 - out_color.a;
				if(out_color.a > 254.0/255.0) return out_color;
			} else {
				out_color.rgb += (1.0 - out_color.a)*col*diff;
				out_color.a = 1.0;
				return out_color;
			}
		}
		lblk = blk;
	}

	return out_color;
}

void main()
{
	const vec4 BG = vec4(0.1, 0.0, 0.2, 1.0);

	vec3 ray_pos = vert_cam_pos + vec3((bound_max+bound_min)/2) + 0.5;
	vec3 ray_dir = normalize(vert_ray_step);

	float new_time = 0.0;
	float pretrace_time = 0.0;
	float pretrace_shadow = 0.0;
	float pretrace_shadow_variance = 0.0;

	if(have_depth_in)
	{
		//vec2 MULDEPTH = 1.0/imuldepth;
		vec2 dbb = texture2D(tex_depth_in, vert_tc + MULDEPTH*vec2( 0.0, 0.0)).rg;
		vec2 d00 = texture2D(tex_depth_in, vert_tc + MULDEPTH*vec2(-1.0, 0.0)).rg;
		vec2 d01 = texture2D(tex_depth_in, vert_tc + MULDEPTH*vec2( 0.0,-1.0)).rg;
		vec2 d10 = texture2D(tex_depth_in, vert_tc + MULDEPTH*vec2( 1.0, 0.0)).rg;
		vec2 d11 = texture2D(tex_depth_in, vert_tc + MULDEPTH*vec2( 0.0, 1.0)).rg;
		vec2 dtime = min(dbb, min(min(d00, d01), min(d10, d11)));
		vec2 rtime = max(dbb, max(max(d00, d01), max(d10, d11)));
		pretrace_time = dtime.r;
		pretrace_shadow = rtime.g;
		pretrace_shadow_variance = rtime.g - dtime.g;
		dtime -= min(vec2(1.0), rtime-dtime);
		dtime = max(vec2(0.0), dtime);
		new_time = dtime.r;
		ray_pos += ray_dir * new_time;

		//gl_FragColor = vec4(1.0); gl_FragColor.rgb *= 10.0/dtime.r; return;
	}

	float atime_main = new_time;
	float atime_shad = 0.0;
	gl_FragColor = trace_scene(ray_pos, ray_dir, atime_main);

	if(true) // Shadows
	{
		//if(out_color.a >= 1.0/255.0)
		if(gl_FragColor.a >= 1.0)
		{
			vec3 shadow_ray_pos = ray_pos + ray_dir*(atime_main - new_time - 0.01);
			vec4 shadow_color = vec4(0.0);
			if((!precise_shadows) || (pretrace_shadow_variance < 0.01 && abs(atime_main - new_time) < 0.3))
			{
				shadow_color.a = pretrace_shadow;
			} else {
				shadow_color = trace_scene(shadow_ray_pos,
					normalize(vec3(0.3, 1.0, 0.3)),
				atime_shad);
			}
			gl_FragColor.rgb *= ((1.0-shadow_color.a)*0.6+0.4);
		} else {
			gl_FragColor.rgb *= 0.4;
		}
	}

	gl_FragColor.rgb += BG.rgb * (1.0-gl_FragColor.a);
	gl_FragColor.a = 1.0;
}


