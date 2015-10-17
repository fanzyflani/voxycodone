#include "common.h"

int kd_list_len = 0;
struct kd kd_list[KD_MAX];
GLuint kd_data_split_axis[KD_MAX];
GLfloat kd_data_split_point[KD_MAX];
//int kd_data_child1[KD_MAX];
//int kd_data_spibeg[KD_MAX];
//int kd_data_spilen[KD_MAX];

double bmin_x = 0.0;
double bmin_y = 0.0;
double bmin_z = 0.0;
double bmax_x = 0.0;
double bmax_y = 0.0;
double bmax_z = 0.0;

int spilist[SPILIST_MAX];
int spilist_len = 0;

int kd_imap_axis = 0;

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

int kd_sort_imap(void const* ap, void const* bp)
{
	int const* ai = (int const*)ap;
	int const* bi = (int const*)bp;

	struct sph const* ae = &sph_list[*ai];
	struct sph const* be = &sph_list[*bi];

	double ac = ae->v[kd_imap_axis];
	double bc = be->v[kd_imap_axis];
	double ar = ae->rad;
	double br = be->rad;

	return(ac < bc ? -1 : ac-ar > bc-br ? 1 : 0);
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

	// Get size
	double bs[3];

	kd_get_box(base, base_len, kd->b1, kd->b2);
	for(i = 0; i < 3; i++)
		bs[i] = kd->b2[i] - kd->b1[i];

	// If we have less than two in here, return
	if(base_len < 5)
	{
		// TODO make this faster
		if(0 && parent != NULL)
		{
			// Set up a box
			kd->split_axis = parent->split_axis;
			struct kd *skd, *ckd;
			int cidx = 0;
			int sidx = 0;

			if(kd->idx == parent->idx+1)
			{
				kd->split_point = kd->b1[kd->split_axis];
				sidx = kd_list_len++;
				cidx = kd_list_len++;
				kd->children[0] = &kd_list[sidx];
				kd->children[1] = &kd_list[cidx];
			} else {
				kd->split_point = kd->b2[kd->split_axis];
				cidx = kd_list_len++;
				sidx = kd_list_len++;
				kd->children[0] = &kd_list[cidx];
				kd->children[1] = &kd_list[sidx];
			}
			assert(kd_list_len <= KD_MAX);
			assert(kd_list_len >= 0);

			skd = &kd_list[sidx];
			skd->idx = sidx;
			skd->parent = kd;
			skd->contents = NULL;
			skd->contents_offs = 0;
			skd->contents_len = 0;
			skd->children[0] = NULL;
			skd->children[1] = NULL;
			skd->split_axis = -1;

			ckd = &kd_list[cidx];
			ckd->idx = cidx;
			ckd->parent = kd;
			ckd->contents_offs = 0;
			ckd->children[0] = NULL;
			ckd->children[1] = NULL;
			ckd->split_axis = -1;
			ckd->contents = malloc(base_len*sizeof(int));
			ckd->contents_len = base_len;
			if(base == NULL)
			{
				for(i = 0; i < base_len; i++)
					ckd->contents[i] = i;
			} else {
				memcpy(ckd->contents, base, base_len*sizeof(int));
			}

		} else {
			kd->contents = malloc(base_len*sizeof(int));
			kd->contents_len = base_len;
			if(base == NULL)
			{
				for(i = 0; i < base_len; i++)
					kd->contents[i] = i;
			} else {
				memcpy(kd->contents, base, base_len*sizeof(int));
			}
		}

		// OK, now return!
		return kd;
	}

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

	// Split index map
	int *submap0 = malloc(base_len*sizeof(int));
	int *submap1 = malloc(base_len*sizeof(int));
	int blen0 = 0;
	int blen1 = 0;

	// Build buckets
	for(i = 0; i < base_len; i++)
	{
		struct sph *sph = &sph_list[newmap[i]];

		if(sph->v[kd->split_axis] - sph->rad <= kd->split_point)
			submap0[blen0++] = newmap[i];
		if(sph->v[kd->split_axis] + sph->rad >= kd->split_point)
			submap1[blen1++] = newmap[i];
	}

	// If we're all in the bucket, change strategy and become a leaf instead
	if(blen0 == base_len || blen1 == base_len)
	{
		kd->split_axis = -1;
		kd->contents = malloc(base_len*sizeof(int));
		memcpy(kd->contents, base, base_len*sizeof(int));
		kd->contents_len = base_len;

		free(newmap);
		free(submap0);
		free(submap1);
		return kd;
	}

	// Split!
	kd->children[0] = kd_build_node(submap0, blen0, kd);
	kd->children[1] = kd_build_node(submap1, blen1, kd);

	// Return
	free(newmap);
	free(submap0);
	free(submap1);
	return kd;

}

void kd_generate(void)
{
	int i, j;

	// Recursively build tree
	kd_list_len = 0;
	kd_build_node(NULL, sph_count, NULL);

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
			kd_data_split_axis[i] = (kd->split_axis | (kd->children[1]->idx<<2)
				| ((kd->parent == NULL ? 0 : kd->parent->idx)<<20));
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

			assert(kd->contents_offs <= 0xFFF);
			assert(kd->contents_len <= 0x3F);
			assert(kd->parent == NULL || kd->parent->idx <= 0x3FF);
			//kd_data_spibeg[i] = kd->contents_offs;
			//kd_data_spilen[i] = kd->contents_len;
			kd_data_split_axis[i] = (kd->contents_offs<<2)|(kd->contents_len<<14)|3
				| ((kd->parent == NULL ? 0 : kd->parent->idx)<<20);
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

