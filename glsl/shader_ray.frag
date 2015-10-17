// vim: syntax=c
#version 150
const bool do_debug = false;
const bool do_kdtree = true;
const bool do_shadow = true;
const bool do_bbox = true;

const bool do_kd_restart = false;

const bool test_mesh = false; // WIP: hardcoded sphere grid spam

const float EPSILON = 0.0001;
const float ZFAR = 1000.0;
const uint BOUNCES = 2U;
const uint SPH_MAX = (1024U);
const uint SPILIST_MAX = (1024U+1024U);
const uint KD_MAX = (2048U);
const uint KD_TRACE_MAX = 10U;
const uint KD_LOOKUP_MAX = 128U;

uniform sampler2D tex0;
uniform sampler2D tex1;
uniform usampler2D tex2;
uniform sampler2D tex3;

uniform int sph_count;
//uniform vec4 sph_data[SPH_MAX];

uniform vec3 light0_pos;
uniform vec3 light0_dir;
uniform float light0_cos;
uniform float light0_pow;

uniform vec3 bmin, bmax;
//vec3 bmin, bmax;

invariant in vec3 wpos_in;
in vec3 wdir_in;
out vec4 out_frag_color;

// x,y = tmin, tmax
struct KDNode
{
	float tmin, tmax;
	uint idx;
	//uint pad0;
} kd_trace_nodes[KD_TRACE_MAX];
int kd_trace_head;
uint kd_trace_node;
float kd_tmin;
float kd_tmax;

// TODO: get uniform blocks working so we can make these into structs
// (it's theoretically better for cache)
//uniform uint kd_data_split_axis[KD_MAX];
//uniform float kd_data_split_point[KD_MAX];
//uniform int kd_data_child1[KD_MAX];
//uniform int kd_data_spibeg[KD_MAX];
//uniform int kd_data_spilen[KD_MAX];
//uniform int kd_data_spilist[SPILIST_MAX];

//vec3 light0_vec;
float ttime;
float tdiff;
float zfar = ZFAR;
vec3 tcol, tnorm;
vec3 wpos, wdir, idir;
vec3 ccol;
vec3 dcol;

int trace_spi;

const vec3 kd_axis_select[3] = vec3[](
	vec3(1.0, 0.0, 0.0),
	vec3(0.0, 1.0, 0.0),
	vec3(0.0, 0.0, 1.0));

vec4 fetch_data(int x, int y)
{
	return texelFetch(tex0, ivec2(x,y), 0);
}

float decode_float(vec4 c)
{
	c = floor(c * 255.0 + 0.3);
	return (c.r + c.g*256.0 + (c.b-128.0)*256.0*256.0)/1024.0;
}

float decode_float_16(vec4 c)
{
	c = floor(c * 255.0 + 0.3);
	return (c.r + (c.g-128.0)*256.0)/64.0;
}

void apply_light(vec3 epoint)
{
	vec3 ldir = normalize(light0_pos - epoint);
	float lfoc = (dot(ldir, -normalize(light0_dir)) - light0_cos)/light0_cos;
	if(lfoc > 0.0)
	{
		tdiff = max(0.0, dot(tnorm, ldir));
		tdiff *= pow(lfoc, light0_pow);
	} else {
		tdiff = 0.0;
	}
}

void shade_sphere(vec3 epos, vec3 ecol)
{
	// Calculate point of intersection
	vec3 epoint = wpos + ttime*wdir;

	// Calculate normal
	tnorm = normalize(epoint - epos);

	// Calculate colour
	apply_light(epoint);
	tcol = ecol;
}

void trace_sphere(int spi, bool shadow_mode, vec3 epos, float erad)
{
	//if(true)return;
	if(do_debug) dcol.r += (1.0 - dcol.b)*0.2;
	// Calculate hypotenuse
	vec3 dpos = epos - wpos;

	// Calculate angle and thus adjacent
	float dirl = dot(dpos, wdir);
	//if(!einside && dirl < 0.0) return; // *** SKIP if behind camera
	if(dirl <= (shadow_mode ? 0.0 : 0.5)) return; // *** SKIP - frustum cull
	float dposl2 = dot(dpos, dpos);

	// this skip actually slows traces down, so DISABLED
	//if(ttime < sqrt(dposl2) - erad) return; // *** ACCEL SKIP if we cannot reach it

	float erad2 = erad*erad;
	bool einside = dposl2 < erad2;
	if(einside) return; // *** TEMPORARY ACCEL SKIP - inside is very slow with this struct!

	// Calculate relative radius
	float rad2 = dposl2 - dirl*dirl;
	if(rad2 > erad2) return; // *** SKIP if not in sphere

	//
	// TOUCHING PRIMITIVE
	//

	// Calculate time to entry point
	// time_offset^2 = erad2 - rad2
	float etime_offset2 = erad2 - rad2;
	float etime_offset = sqrt(etime_offset2);
	float etime = dirl + (einside ? etime_offset : -etime_offset);

	if(etime < EPSILON) return; // *** NOT SURE WHY WE HAVE TO SKIP BUT OH WELL

	// @@@ TIME SELECT
	if(etime > ttime) return; // *** TIME SKIP
	ttime = etime;
	if(do_debug) dcol.g += (1.0-dcol.g)*0.5;
	if(shadow_mode) return;

	// Set sphere index
	trace_spi = spi;
}

void trace_cylinder(bool shadow_mode, vec3 epos0, vec3 epos1, float erad, vec3 ecol)
{
	// Get normal
	vec3 enorm = normalize(epos1 - epos0);

	// Get base plane offset
	float eoffs0 = dot(epos0, enorm);
	float eoffs1 = dot(epos1, enorm);

	// Project to planes
	vec3 dwdir = sign(wdir)*max(vec3(EPSILON), abs(wdir));
	float proj_poffs = dot(enorm, wpos); // Distance to plane
	float proj_doffs = dot(enorm, wdir); // Offset for direction
	float proj0_time = (eoffs0-proj_poffs)/proj_doffs; // Time to plane 0
	float proj1_time = (eoffs1-proj_poffs)/proj_doffs; // Time to plane 1
	bool side0_valid = (proj0_time >= EPSILON);
	bool side1_valid = (proj1_time >= EPSILON);
	if(!(side0_valid || side1_valid)) return; // *** SKIP if behind
	vec3 proj0_wpos = wpos + proj0_time*dwdir;
	vec3 proj1_wpos = wpos + proj1_time*dwdir;
	vec3 proj_wdir = wdir - proj_doffs*enorm;

	// Check radius
	side0_valid = side0_valid && length(proj0_wpos - epos0) <= erad;
	side1_valid = side1_valid && length(proj1_wpos - epos1) <= erad;

	// Do caps
	if(side0_valid || side1_valid)
	{
		float etime0 = proj0_time;
		float etime1 = proj1_time;
		float etime = (etime0 < etime1 && side0_valid ? etime0 : etime1);
		vec3 epoint = (etime0 < etime1 && side0_valid ? proj0_wpos : proj1_wpos);

		// @@@ TIME SELECT
		if(etime >= ttime) return; // *** TIME SKIP
		ttime = etime;
		if(shadow_mode) return;

		tcol = ecol;
		//tnorm = normalize(proj_wpos - epos);
		tnorm = (dot(enorm, wdir) < 0.0 ? -enorm : enorm);
		apply_light(epoint);
	}

	// Do actual cylinder
	// (abuse plane 0 for position)

	// Calculate requirements for our double-triangle motion
	float prad = length(proj0_wpos - epos0);
	float pcos = dot(-wdir, proj_wdir);

	// Now for some trigonometric horror
	float tA = pcos*prad; // Time to tangent
	float K = sqrt(prad*prad - tA*tA); // Tangent distance
	float tB = sqrt(erad*erad - K*K); // Time from tangent to border

	// Assert things
	float tAB = tA+tB;
	//if(etime < proj0_time
	// TODO!

}

// Let's not pretend that we actually call this a "torus"
void trace_donut(bool shadow_mode, vec3 epos, vec3 enorm, float radh, float radd, vec3 ecol)
{
	// Normalise
	enorm = normalize(enorm);

	float radx = radh+radd;

	//if((dot(enorm, wpos)-eoffs)*dot(enorm,wdir) >= EPSILON) return; // *** ACCEL SKIP

	// Project direction onto the plane
	// (200-level Linear Algebra, a paper I got a C- on)
	float proj_poffs = dot(enorm, wdir);
	vec3 proj_pdir = normalize(wdir - enorm*proj_poffs);

	// Get pos offset
	float eoffs = dot(epos, enorm);
	float nopos = dot(enorm, wpos) - eoffs;

	// Get dir offset
	float nodir = dot(enorm, wdir);
	//if(nodir*nopos >= 0.0) return; // *** ACCEL SKIP

	// Get time
	// TODO: find accurate skip
	float etime = -nopos/nodir;
	//if(etime < EPSILON) return; // *** SKIP if casting in wrong direction

	// Project position onto the plane
	vec3 epoint = wpos - enorm*etime;

	// Calculate requirements for our double-triangle motion
	vec3 pdir = normalize(epoint - epos);
	float prad = length(epoint - epos);
	float pcos = dot(-pdir, proj_pdir);

	// Now for some trigonometric horror
	float tA = pcos*prad; // Time to tangent
	float K = sqrt(prad*prad - tA*tA); // Tangent distance
	float tB = sqrt(radx*radx - K*K); // Time from tangent to border

	float ptime = tA+tB; 
	if(ptime < 0.0) ptime -= 2.0*tB;
	if(ptime < 0.0) return;
	//vec3 ppos = epos + normalize(proj_pdir*(ptime))*(radh+radd);

	// Trace sphere
	{
		float old_ttime = ttime;
		vec3 ppos = epoint + proj_pdir*(ptime);
		//vec3 ppos = wpos + pdir*(ptime);
		//ppos = epos + normalize(ppos - epos)*radx;
		/*
		trace_sphere(1, shadow_mode, ppos, radd);
		if((!shadow_mode) && ttime != old_ttime)
			shade_sphere(ppos, ecol);
		*/

		etime = ptime;
		if(ttime < etime) return;
		ttime = etime;
		tcol = ecol;
		tnorm = normalize(ppos - epos);
		apply_light(epoint);
	}
	if(false){
		float old_ttime = ttime;
		vec3 ppos = epoint + proj_pdir*(tA-tB);
		ppos = epos + normalize(ppos - epos)*radx;
		trace_sphere(1, shadow_mode, ppos, radd);
		if((!shadow_mode) && ttime != old_ttime)
			shade_sphere(ppos, ecol);
	}
}

void trace_plane(bool shadow_mode, vec3 enorm, float eoffs, vec3 ecol0, vec3 ecol1)
{
	// Normalise
	enorm = normalize(enorm);

	//if((dot(enorm, wpos)-eoffs)*dot(enorm,wdir) >= EPSILON) return; // *** ACCEL SKIP

	// Get pos offset
	float nopos = dot(enorm, wpos) - eoffs;

	// Check side
	bool einside = (nopos < 0.0);

	// Get dir offset
	float nodir = dot(enorm, idir);
	//if(nodir*nopos >= 0.0) return; // *** ACCEL SKIP

	// Get time
	float etime = -nopos*nodir;
	if(etime < EPSILON) return; // *** SKIP if casting in wrong direction

	// @@@ TIME SELECT
	if(etime >= ttime) return; // *** TIME SKIP
	ttime = etime;
	if(shadow_mode) return;

	// Calculate point of intersection
	vec3 epoint = wpos + etime*wdir;

	// TODO: genericise this pattern
	float c0 = floor(epoint.x/3.0);
	float c1 = floor(epoint.z/3.0);
	float csel = c0+c1;
	csel -= floor(csel/2.0)*2.0;

	// Calculate colour
	tnorm = (einside ? -enorm : enorm);
	apply_light(epoint);
	tcol = (csel >= 1.0 ? ecol1 : ecol0);
}

void kd_add_plane(uint idx, float tmin, float tmax)
{
	// KD-Restart doesn't use this function
	if(do_kd_restart) return;

	// Don't overflow trace list!
	if(kd_trace_head >= int(KD_TRACE_MAX))
	{
		ccol.r = 1.0;
		return;
	}

	// Don't add something that has no or negative time!
	if(tmin >= tmax) return;

	kd_trace_nodes[kd_trace_head].idx = idx;
	kd_trace_nodes[kd_trace_head].tmin = tmin;
	kd_trace_nodes[kd_trace_head].tmax = tmax;
	kd_trace_head++;
}

bool kd_fetch_plane(void)
{
	if(do_kd_restart)
	{
		kd_tmin = kd_tmax;
		kd_tmax = ttime;
		if(kd_tmin >= kd_tmax)
			return false;

		if(false)
		{
			// KD-Backtrack (well, not quite)
			//uint parent = (kd_data_split_axis[kd_trace_node] & 0xFFFFU) >> 2;
			uint parent = (texelFetch(tex2, ivec2(0, kd_trace_node), 0).x & 0xFFFFU) >> 2;
			for(uint i = 0U; i < KD_TRACE_MAX; i++)
			{
				// Check if parent valid
				if(parent == kd_trace_node)
					return false;

				// Advance to parent
				kd_trace_node = parent;
				//uint data = kd_data_split_axis[kd_trace_node];
				uint data = texelFetch(tex2, ivec2(0, kd_trace_node), 0).x;
				parent = data >> 20;

				// Check if in range
				// Note, we simply cannot have a leaf (unless there's a bug (NO PUN INTENDED))
				uint kd_trace_axis = data & 3U;
				//float split_point = kd_data_split_point[kd_trace_node];
				float split_point = texelFetch(tex1, ivec2(0,kd_trace_node), 0).x;
				float split_time;
				switch(kd_trace_axis)
				{
					case 0U:
						split_time = (split_point - wdir.x)*idir.x;
						break;
					case 1U:
						split_time = (split_point - wdir.y)*idir.y;
						break;
					case 2U:
					default:
						split_time = (split_point - wdir.z)*idir.z;
						break;
				}

				// If it is, use this node!
				//if(split_time >= kd_tmin && split_time <= kd_tmax)
				if(split_time >= kd_tmin)
				{
					// TODO: store node bounding boxes somehow.
					return true;
				}
			}
			return false;

		} else {
			// KD-Restart
			kd_trace_node = 0U;
			return true;
		}
	}

	// Ensure we have nodes remaining to trace through
	if(kd_trace_head <= 0) return false;

	// Load node info
	kd_trace_head--;
	kd_trace_node = kd_trace_nodes[kd_trace_head].idx;
	kd_tmin = kd_trace_nodes[kd_trace_head].tmin;
	kd_tmax = kd_trace_nodes[kd_trace_head].tmax;

	return true;
}

void trace_scene(bool shadow_mode)
{
	idir = sign(wdir)/max(vec3(EPSILON), abs(wdir));

	if(test_mesh)
	{
		trace_plane(shadow_mode
			, vec3(0.0, 1.0, 0.0), -3.0
			, vec3(0.9, 0.9, 0.9)
			, vec3(0.1, 0.1, 0.1)
			);

		//trace_donut(shadow_mode, vec3(0.0, 0.0, -4.0), vec3(0.0, 0.0, 1.0), 1.0, 0.5, vec3(1.0, 0.0, 1.0));
		//trace_cylinder(shadow_mode, vec3(0.0, 0.0, -4.0), vec3(0.0, 0.0, 1.0), 1.0, vec3(1.0, 0.0, 1.0));
		//trace_cylinder(shadow_mode, vec3(0.0, -0.0, -4.0), vec3(0.0, 0.0, 4.0), 1.0, vec3(1.0, 0.0, 1.0));
		trace_cylinder(shadow_mode, vec3(1.0, 0.0, -4.0), vec3(2.0, 1.0, -4.0), 1.0, vec3(1.0, 0.0, 1.0));
		/*
		vec3 dsign = sign(wdir);
		vec3 adir = abs(wdir);
		vec3 aidir = 1.0/max(vec3(EPSILON), adir);
		vec3 ecol = vec3(1.0, 0.5, 0.3);
		trace_spi = -1;

		//vec3 epos = floor(wpos/2.0)*2.0;
		//vec3 rbox = (epos-wpos)*dsign;
		vec3 epos = floor((wpos+1.0)/2.0)*2.0 + 1.0*dsign;
		vec3 rbox = (epos-wpos)*dsign + 1.0;

		for(int i = 0; i < 3; i++)
		{
			trace_sphere(1, shadow_mode, epos, 1.0);

			if(trace_spi >= 0)
			{
				shade_sphere(epos, ecol);
				break;
			}

			vec3 cstime = aidir*rbox;
			float stime;

			if(cstime.x < cstime.y && cstime.x < cstime.z)
			{
				stime = cstime.x;
				rbox -= stime*adir;
				rbox.x = 2.0;
				epos.x += 2.0*dsign.x;

			} else if(cstime.y < cstime.z) {
				stime = cstime.y;
				rbox -= stime*aidir;
				rbox.y = 2.0;
				epos.y += 2.0*dsign.y;

			} else {
				stime = cstime.z;
				rbox -= stime*aidir;
				rbox.z = 2.0;
				epos.z += 2.0*dsign.z;

			}
		}
		*/

		return;
	}

	// Trace to plane
	trace_plane(shadow_mode
		, vec3(0.0, 1.0, 0.0), -3.0
		, vec3(0.9, 0.9, 0.9)
		, vec3(0.1, 0.1, 0.1)
		);

	/*
	trace_plane(vec3(0.0, -1.0, 0.0), -143.0
		, vec3(0.9, 0.9, 0.9)
		, vec3(0.1, 0.1, 0.1)
		);
	*/

	float base_ttime = ttime;
	float base_pretime = 0.0;
	float old_ttime = ttime;

	// Discern boxness

	if(do_bbox)
	{
		vec3 hitmin = idir*(bmin-wpos);
		vec3 hitmax = idir*(bmax-wpos);
		//vec3 hitf = (hitmin+hitmax)/2.0 + sign(wdir)*(hitmin-hitmax)/2.0;
		//vec3 hitg = (hitmin+hitmax)/2.0 + sign(wdir)*(hitmax-hitmin)/2.0;
		vec3 hitf = min(hitmin, hitmax);
		vec3 hitg = max(hitmin, hitmax);

		float facf = max(hitf.x, max(hitf.y, hitf.z));
		float facg = min(hitg.x, min(hitg.y, hitg.z));

		// Eliminate if we don't enter the bounding box
		//if(false)
		//if(facf > facg || facf > ttime || facg < EPSILON)
		//if(facf > facg)
		//if(facf > facg || facg < EPSILON)
		if(facf > facg || facf > ttime || facg < EPSILON)
		{
			//ccol = vec3(1.0, 0.0, 0.0);
			return;
		}

		base_ttime = min(ttime, facg);
		base_pretime = max(0.0, facf);
	}

	ttime = base_ttime;
	trace_spi = -1;

	if(do_kdtree)
	{
		// Trace through kd-tree
		kd_trace_head = 0;
		kd_tmin = base_pretime;
		kd_tmax = ttime;
		kd_trace_node = 0U;
		float kd_old_ttime;

		for(uint i = 0U; i < KD_LOOKUP_MAX; i++)
		{
			// KD TRACE MODE

			if(kd_tmin > ttime) break;

			if(kd_tmin >= kd_tmax)
			{
				if(kd_fetch_plane())
					continue;
				else
					break;
			}

			// Load plane
			//vec4 k0 = fetch_data(16+0, kd_trace_node);
			//uint data = kd_data_split_axis[kd_trace_node];
			uint data = texelFetch(tex2, ivec2(0,kd_trace_node), 0).x;
			uint split_axis = data & 3U;

			//if(k0.a < 0.5)
			if(split_axis != 3U)
			{
				// Split node
				uint child1 = (data >> 2) & 0xFFFFU;
				//uint parent = data >> 20;

				//float split_point = kd_data_split_point[kd_trace_node];
				float split_point = texelFetch(tex1, ivec2(0,kd_trace_node), 0).x;

				// Determine axis {pos, dir}
				float cmp_pos;
				float cmp_idir;

				switch(split_axis)
				{
					case 0U:
						cmp_pos = wpos.x;
						cmp_idir = idir.x;
						break;

					case 1U:
						cmp_pos = wpos.y;
						cmp_idir = idir.y;
						break;

					default:
						cmp_pos = wpos.z;
						cmp_idir = idir.z;
						break;
				}

				/*
				vec3 sel_vec = kd_axis_select[split_axis];
				cmp_pos = dot(wpos, sel_vec);
				cmp_idir = dot(idir, sel_vec);
				*/

				// Get time
				float split_time = (split_point-cmp_pos)*cmp_idir;

				// Check if centre does get hit at all
				//bool use_cnear = (split_time >= kd_tmin);
				//bool use_cfar = (split_time <= kd_tmax);

				uvec2 kbase = uvec2(kd_trace_node+1U, child1);
				uvec2 kpair = (cmp_idir < 0.0 ? kbase.yx : kbase.xy);
				uint c0 = kpair.x;
				uint c1 = kpair.y;

				/*
				// ASSERT: Must advance through list!
				if(c0 <= kd_trace_node || c1 <= kd_trace_node)
				{
					ccol.r = 1.0;
					return;
				}

				// ASSERT: Must not overflow list!
				if(c0 >= 11 || c1 >= 11)
				{
					ccol.g = 1.0;
					return;
				}
				*/

				// DEBUG: Show plane passes
				//if(split_time >= kd_tmin && split_time <= kd_tmax) ccol.b += (1.0 - ccol.b)*0.4;
				if(do_debug) if(split_time >= kd_tmin && split_time <= kd_tmax) dcol.b += (1.0 - dcol.b)*0.3;
				// //if(use_cnear && use_cfar) ccol.b += (1.0 - ccol.b)*0.4;

				// Push furthest first - this is a stack!
				// We "tail-call" the stack anyway
				// so make sure BOTH are valid before pushing
				// Otherwise, just pick one

				// LEMMA: At least one is valid
				// PRECOND: kd_tmin < kd_tmax
				// PROOF:
				// split_time >= kd_tmin ==> use_cnear
				// split_time <= kd_tmax ==> use_cfar
				//
				// Assume both fail:
				// ==> kd_tmax < split_time < kd_tmin
				// ==> kd_tmax < kd_tmin
				// which violates the precondition.
				//
				// Therefore, at least one node is valid, QED.

				if(split_time <= kd_tmin)
				{
					kd_trace_node = c1;
					kd_tmin = max(split_time, kd_tmin);
				} else {
					if(!do_kd_restart && split_time < kd_tmax)
						kd_add_plane(c1, max(kd_tmin, split_time), kd_tmax);
					//kd_add_plane(c0, kd_tmin, min(split_time, kd_tmax));

					kd_trace_node = c0;
					kd_tmax = min(split_time, kd_tmax);
				}

			} else {
				// Leaf node
				//ivec2 k1 = ivec2(floor(k0.xy*255.0+0.4));
				uint spilen = (data >> 14) & 0x3FU;

				if(spilen > 0U)
				{
					kd_old_ttime = ttime;
					uint spibeg = (data >> 2) & 0xFFFU;

					// SPHERE TRACE MODE
					for(uint j = 0U; j < spilen; j++)
					{
						//int spi = int(floor(decode_float(fetch_data(48+0, k1.x+j))+0.1));
						//int spi = kd_data_spilist[spibeg+j];
						int spi = int(texelFetch(tex2, ivec2(1,spibeg+j), 0).r);
						//vec4 spd = sph_data[spi];
						vec4 spd = texelFetch(tex3, ivec2(spi,0), 0);

						trace_sphere(spi, shadow_mode, spd.xyz, spd.w);
					}

					if(ttime == kd_tmax)
						ttime = kd_old_ttime;

					if(ttime < kd_tmax) break;

					if(kd_fetch_plane())
						continue;
					else
						break;
				}
			}
		}
	} else {
		// Trace to spheres
		for(int i = 0; i < sph_count; i++)
		{
			//vec4 spd = sph_data[i];
			vec4 spd = texelFetch(tex3, ivec2(i,0), 0);

			trace_sphere(i, shadow_mode, spd.xyz, spd.w);

			if(shadow_mode && ttime < base_ttime) break;
		}
	}

	if(trace_spi >= 0)
	{
		vec3 spd = texelFetch(tex3, ivec2(trace_spi,0), 0).xyz;
		shade_sphere(spd, fetch_data(0, trace_spi).rgb);
	}

	if(ttime == base_ttime)
		ttime = old_ttime;
}

void main()
{
	wpos = wpos_in;
	wdir = normalize(wdir_in);

	// Set up boundary
	float amax = max(max(abs(wdir.x),abs(wdir.y)),abs(wdir.z));
	//tcol = (amax == abs(wdir.y) ? vec3(0.4, 1.0, 0.3) : vec3(0.5, 0.7, 1.0)) * amax;
	tcol = vec3(0.5, 0.7, 1.0) * amax;
	tnorm = vec3(0.0);
	ttime = zfar;
	tdiff = 1.0;

	// TEMPORARY: Get bounding box
	/*
	bmin.x = decode_float(fetch_data(32, 0));
	bmin.y = decode_float(fetch_data(32, 1));
	bmin.z = decode_float(fetch_data(32, 2));
	bmax.x = decode_float(fetch_data(32, 3));
	bmax.y = decode_float(fetch_data(32, 4));
	bmax.z = decode_float(fetch_data(32, 5));
	*/

	if(do_debug) dcol = vec3(0.0);
	ccol = vec3(0.0);
	float ccol_fac = 1.0;

	for(uint i = 0U; i < BOUNCES+1U; i++)
	{
		// Trace scene
		trace_scene(false);

		if(ttime == zfar) break; // DIDN'T HIT ANYTHING

		// Move to surface
		wpos = wpos + (ttime-EPSILON*8.0)*wdir;
		zfar -= ttime;
		ttime = zfar;

		// Back up useful things
		float zfar_bak = zfar;
		//vec3 tcol_bak = tcol;
		//vec3 tnorm_bak = tnorm;
		//float tdiff_bak = tdiff;
		vec3 wpos_bak = wpos;
		vec3 wdir_bak = wdir;

		// Trace to light for shadows
		if(do_shadow)
		{
			zfar = ttime = length(light0_pos - wpos);

			if(false)
			{
				// Cast from light
				// disabled: causes fringing on the shadows
				// and no real performance improvements
				wdir = normalize(wpos - light0_pos);
				wpos = light0_pos;
			} else {
				// Cast to light
				wdir = normalize(light0_pos - wpos);
			}

			if(tdiff > 0.0)
			{
				trace_scene(true);
			}
		}

		// Check if we hit something
		bool unshadowed = (!do_shadow) || (ttime == zfar);

		// Restore colour backup
		//tcol = tcol_bak;
		//tdiff = tdiff_bak;

		// Restore trace backup
		//tnorm = tnorm_bak;
		wpos = wpos_bak;
		wdir = wdir_bak;
		ttime = zfar = zfar_bak;

		// Reflect
		wdir = 2.0*dot(tnorm, -wdir)*tnorm + wdir;

		// Apply ambient + diffuse
		float comb_light = 0.1;
		if(unshadowed)
			comb_light += 0.9*tdiff;
		tcol *= comb_light;

		// Apply specular
		if(unshadowed)
		{
			float spec = 1.0;
			vec3 ldir = normalize(light0_pos - wpos);
			spec *= max(0.0, dot(wdir, ldir));
			float lfoc = max(0.0, (dot(ldir, -normalize(light0_dir)) - light0_cos)/light0_cos);
			spec *= (lfoc > 0.0 ? 1.0 : 0.0);
			if(spec > 0.0)
				tcol += pow(spec, 128.0);
		}


		// Accumulate colour
		ccol += tcol * ccol_fac;
		ccol_fac *= 0.3;

	}

	if(ccol_fac == 1.0) ccol = tcol;
	if(do_debug) ccol = dcol * vec3(0.5, 0.3, 1.0);

	out_frag_color = vec4(ccol, 1.0);
}

