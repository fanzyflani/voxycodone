require("lua/tracer")

tracer_clear()

glib_add([=[
uniform sampler2D tex_rand;
uniform usampler3D tex_vox;
uniform float scene_sb_offs;

const vec3[] lcol = vec3[](
	vec3(0.5, 0.5, 0.5),
	vec3(0.7, 0.4, 0.4),
	vec3(0.3, 0.7, 0.3),
	vec3(0.45, 0.45, 0.7),
	vec3(0.7, 0.1, 0.7)
);

uint voxel_fetch(int layer, ivec3 cell)
{
	//
	return (cell.y >= 0 && cell.y < 128
		? texelFetch(tex_vox, ((cell.xzy>>(layer)) + ivec3(256, 256, 256-(256>>(layer))) & ivec3(511, 511, 255)), 0).x
		: 0x00U);
	//if(cell.y >= 128) return 0x00U;
	//return texelFetch(tex_vox, (cell.xzy>>(layer)) + ivec3(256, 256, 256-(256>>(layer))), 0).x;

}

void scene_trace_voxygen(inout Trace T, bool shadow_mode)
{
	int i;

	const int base_layer = 4;
	const int VOXYGEN_TRACES = 40;
	const int VOXYGEN_TRACE_RANGE = 200;

	// Set camera pos
	vec3 bcpos = T.src_wpos + EPSILON + vec3(0.0, 96.0, 0.0);
	float atime = 0.0;

	// Trace to scene
	if(bcpos.y < 0.0)
	{
		if(T.src_wdir.y <= 0.0) return;

		atime = (0.0 - bcpos.y)/T.src_wdir.y;
		bcpos += atime*T.src_wdir;

	} else if(bcpos.y >= 128.0) {
		if(T.src_wdir.y >= 0.0) return;

		atime = (128.0 - bcpos.y)/T.src_wdir.y;
		bcpos += atime*T.src_wdir;

	}

	// Set other variables
	int layer = 0;
	vec3 cpos = floor((bcpos/float(1<<layer)))*float(1<<layer);
	ivec3 cell = ivec3(cpos);
	vec3 adir = abs(T.src_wdir);
	vec3 aidir = 1.0/max(vec3(EPSILON), adir);
	bvec3 sign_neg = lessThan(T.src_wdir, vec3(0.0));
	ivec3 sidir = ivec3(mix(vec3(1.0), vec3(-1.0), sign_neg));
	vec3 subcell = vec3(bcpos - cpos);
	subcell = mix(float(1<<layer) - subcell, subcell, sign_neg);

	//cell.xz %= 256;
	cell.xz += 64;
	cell.xz &= 128-1;
	cell.xz -= 64;

	bvec3 bound_crossed = bvec3(false, false, true);

	for(i = 0; i < 5000 && atime < T.hit_time; i++)
	//for(i = 0; i < VOXYGEN_TRACES; i++)
	//for(i = 0; i < VOXYGEN_TRACE_RANGE; i+=(1<<layer))
	{
		if(cell.y < 0 && sidir.y < 0) break;
		if(cell.y >= 128 && sidir.y > 0) break;

		uint v = voxel_fetch(layer, cell);

		if((v & 0x40U) != 0U)
		{
			// Ascend
			while(layer < base_layer)
			{
				ivec3 cbit = cell&(1<<layer);
				cell &= ~((2<<layer)-1);

				bvec3 cell_bit = notEqual(cbit, ivec3(0));
				bvec3 sidir_neg = lessThan(sidir, ivec3(0));
				bvec3 change_cell = equal(cell_bit, sidir_neg);
				subcell += vec3(change_cell)*float(1<<layer);
				layer++;

				// sidir neg = add 1 to subcell if bit 1
				// sidir pos = add 1 to subcell if bit 0

				if(cell.y < 0 || cell.y >= 128)
					continue;

				v = voxel_fetch(layer, cell);

				if((v & 0x40U) == 0U)
					break;
			}
		} else if((v & 0x80U) != 0U) {
			// Descend
			while(layer > 0)
			{
				if(any(lessThan(cell.xz, vec2(-128<<layer))) ||
						any(greaterThanEqual(cell.xz, vec2(128<<layer))))
					break;

				//if(!shadow_mode)ccol.r += 0.2;
				layer--;
				//i++;
				bvec3 subc_over = greaterThanEqual(subcell, vec3(float(1<<layer)));
				bvec3 sidir_neg = lessThan(sidir, ivec3(0));
				bvec3 change_cell = equal(subc_over, sidir_neg);
				vec3 subc_diff = vec3(subc_over)*float(1<<layer);
				subcell -= subc_diff;
				cell += ivec3(change_cell)<<layer;

				// sidir neg = add 1 if subcell >= 1<<layer
				// sidir pos = add 1 if subcell < 1<<layer

				v = voxel_fetch(layer, cell);

				if((v & 0x80U) == 0U)
					break;
			}
		}
		
		if(v != 0x00U) {

			// We hit a block
			if(atime > T.hit_time) return;
			T.hit_time = T.obj_time = atime;
			//T.front_time = atime;
			//T.back_time = atime + 1.0; // HACK
			T.hit_pos = T.src_wpos + T.src_wdir*(T.hit_time - EPSILON*8.0);
			if(shadow_mode) return;

			// Get texcoord modulus
			vec3 cmc = ((fract(subcell)-0.5)*vec3(sidir))+0.5;
			vec2 tc;

			if(bound_crossed.y)
			{
				tc = vec2(cmc.x, cmc.z);
			} else {
				tc = vec2(((cmc.x-cmc.z)-0.5)*float(dot(vec2(sidir.xz),vec2(bound_crossed.xz)))+0.5, cmc.y);
			}

			tc = fract(tc);
			//T.mat_col = vec3(texture(tex_rand, tc/16.0, 0).r*0.5+0.5);
			int mip = 0;
			float miptmp = 1280.0/16.0/2.0;
			//float miptmp = 1280.0/16.0/2.0/4.0;
			while(mip < 4 && atime >= miptmp)
			{
				mip++;
				miptmp *= 2.0;
			}

			T.mat_col = (
				voxel_fetch(layer, cell + ivec3(0, 4<<layer, 0)) == 0x01U
				? 
				(texelFetch(tex_rand, ivec2(tc*vec2(4.0, 16.0))>>mip, mip).r*0.5+0.5)
				* vec3(0.4, 0.4, 0.4)
			:
			(texelFetch(tex_rand, ivec2(tc*16)>>mip, mip).r*0.5+0.5)*(
				voxel_fetch(layer, cell + ivec3(0, 1<<layer, 0)) != 0x01U
				&& ((cmc.y < 0.25 && (!(bound_crossed.y && sidir.y > 0)))
				//&& ((!(bound_crossed.y && sidir.y > 0))
				|| (bound_crossed.y && sidir.y < 0))
				? vec3(0.3, 1.0, 0.3)
				: vec3(0.6, 0.4, 0.2)
			));

			//T.mat_col = ((v & 0x80U) != 0U) ? vec3(1.0, 0.0, 0.0) : vec3(0.0, 1.0, 0.0);
			//T.mat_col = vec3(0.5, 0.5, 0.5);
			//T.mat_col = lcol[layer];

			T.obj_norm = -normalize(mix(vec3(0.0), vec3(1.0), bound_crossed)*sidir);

			return;
		}

		// Only necessary if we don't have ascension
		if(false)
		if(any(lessThan(cell.xz, vec2(-256<<layer))) ||
				any(greaterThanEqual(cell.xz, vec2(256<<layer))))
			break;

		vec3 btime = subcell*aidir;
		float mintime = min(min(btime.x, btime.y), btime.z);
		atime += mintime;
		bound_crossed = lessThanEqual(btime, vec3(mintime));
		subcell += vec3(ivec3(bound_crossed)<<layer) - adir*mintime;
		cell += ivec3(bound_crossed) * (sidir<<layer);

		// Check for alignment
		if(false)
		//if(layer < base_layer && dot((cell*ivec3(bound_crossed)) & ((2<<layer)-1), ivec3(1)) == 0)
		while(layer < base_layer && (cell.y < 0 || cell.y >= 128
			|| (voxel_fetch(layer+1, cell) & 0x80U) == 0U))
		{
			// Ascend
			// TODO: investigate multiple ascensions per ray
			//ivec3 cbit = cell&((2<<layer)-1);
			ivec3 cbit = cell&(1<<layer);
			cell &= ~((2<<layer)-1);

			// sidir neg = add 1 to subcell if bit 1
			// sidir pos = add 1 to subcell if bit 0
			bvec3 cell_bit = notEqual(cbit, ivec3(0));
			bvec3 sidir_neg = lessThan(sidir, ivec3(0));
			bvec3 change_cell = equal(cell_bit, sidir_neg);
			subcell += vec3(change_cell)*float(1<<layer);
			layer++;
		}

	}
}
]=])

tracer_generate {
	name = "voxygen",
	bounces = 0,
	do_shadow = false,
	update = function (sec_current, sec_delta)
		shader.uniform_f(S.scene_sb_offs, sec_current/5.0);
		
	end,
	trace_scene = [=[
		T.mat_shine = 0.0;

		scene_trace_voxygen(T, shadow_mode);

		if(T.hit_time == T.zfar)
		{
			// Get noise
			vec2 sb_tc = T.src_wdir.xz/T.src_wdir.y;
			vec2 sb_tc_offs = vec2(1.0, 0.5)*scene_sb_offs;

			float sb_noise = 0.0;
			float sb_lod = length(sb_tc)*2.0;
			sb_noise += textureLod(tex_rand, sb_tc/64.0 + sb_tc_offs/63.0, sb_lod).r/2.0;
			sb_noise += textureLod(tex_rand, sb_tc/32.0 + sb_tc_offs/31.0, sb_lod).g/4.0;
			sb_noise += textureLod(tex_rand, sb_tc/16.0 + sb_tc_offs/15.0, sb_lod).b/8.0;
			sb_noise += textureLod(tex_rand, sb_tc/8.0 + sb_tc_offs/7.0, sb_lod).r/16.0;
			sb_noise += textureLod(tex_rand, sb_tc/4.0 + sb_tc_offs/3.0, sb_lod).g/32.0;
			sb_noise = (sb_noise - 0.1);

			sb_noise = clamp(sb_noise*1.0, 0.0, 1.0);
			sb_noise = clamp(sb_noise/max(1.0, length(sb_tc)/50.0), 0.0, 1.0);

			vec3 sb_col = mix(vec3(0.0, 0.5, 1.0), vec3(1.0, 1.0, 1.0)*(sb_noise+0.5), sb_noise);

			T.mat_shine = 0.0;
			ccol += sb_col;
		}
	]=],
}
