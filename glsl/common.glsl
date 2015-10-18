// vim: syntax=c
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

uniform mat4 in_cam_inverse;
uniform vec2 in_aspect;

