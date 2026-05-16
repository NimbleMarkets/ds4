/* Metal kernels embedded at compile time with C23 #embed. */

typedef struct {
    const char *path;
    const char *source;
} ds4_metal_embedded_source;

static const char ds4_metal_flash_attn_source[] = {
#embed "metal/flash_attn.metal"
    , 0
};
static const char ds4_metal_dense_source[] = {
#embed "metal/dense.metal"
    , 0
};
static const char ds4_metal_moe_source[] = {
#embed "metal/moe.metal"
    , 0
};
static const char ds4_metal_dsv4_hc_source[] = {
#embed "metal/dsv4_hc.metal"
    , 0
};
static const char ds4_metal_unary_source[] = {
#embed "metal/unary.metal"
    , 0
};
static const char ds4_metal_dsv4_kv_source[] = {
#embed "metal/dsv4_kv.metal"
    , 0
};
static const char ds4_metal_dsv4_rope_source[] = {
#embed "metal/dsv4_rope.metal"
    , 0
};
static const char ds4_metal_dsv4_misc_source[] = {
#embed "metal/dsv4_misc.metal"
    , 0
};
static const char ds4_metal_argsort_source[] = {
#embed "metal/argsort.metal"
    , 0
};
static const char ds4_metal_cpy_source[] = {
#embed "metal/cpy.metal"
    , 0
};
static const char ds4_metal_concat_source[] = {
#embed "metal/concat.metal"
    , 0
};
static const char ds4_metal_get_rows_source[] = {
#embed "metal/get_rows.metal"
    , 0
};
static const char ds4_metal_sum_rows_source[] = {
#embed "metal/sum_rows.metal"
    , 0
};
static const char ds4_metal_softmax_source[] = {
#embed "metal/softmax.metal"
    , 0
};
static const char ds4_metal_repeat_source[] = {
#embed "metal/repeat.metal"
    , 0
};
static const char ds4_metal_glu_source[] = {
#embed "metal/glu.metal"
    , 0
};
static const char ds4_metal_norm_source[] = {
#embed "metal/norm.metal"
    , 0
};
static const char ds4_metal_bin_source[] = {
#embed "metal/bin.metal"
    , 0
};
static const char ds4_metal_set_rows_source[] = {
#embed "metal/set_rows.metal"
    , 0
};

static const ds4_metal_embedded_source ds4_metal_embedded_sources[] = {
    {"metal/flash_attn.metal", ds4_metal_flash_attn_source},
    {"metal/dense.metal",      ds4_metal_dense_source},
    {"metal/moe.metal",        ds4_metal_moe_source},
    {"metal/dsv4_hc.metal",    ds4_metal_dsv4_hc_source},
    {"metal/unary.metal",      ds4_metal_unary_source},
    {"metal/dsv4_kv.metal",    ds4_metal_dsv4_kv_source},
    {"metal/dsv4_rope.metal",  ds4_metal_dsv4_rope_source},
    {"metal/dsv4_misc.metal",  ds4_metal_dsv4_misc_source},
    {"metal/argsort.metal",    ds4_metal_argsort_source},
    {"metal/cpy.metal",        ds4_metal_cpy_source},
    {"metal/concat.metal",     ds4_metal_concat_source},
    {"metal/get_rows.metal",   ds4_metal_get_rows_source},
    {"metal/sum_rows.metal",   ds4_metal_sum_rows_source},
    {"metal/softmax.metal",    ds4_metal_softmax_source},
    {"metal/repeat.metal",     ds4_metal_repeat_source},
    {"metal/glu.metal",        ds4_metal_glu_source},
    {"metal/norm.metal",       ds4_metal_norm_source},
    {"metal/bin.metal",        ds4_metal_bin_source},
    {"metal/set_rows.metal",   ds4_metal_set_rows_source},
};

static const size_t ds4_metal_embedded_source_count =
    sizeof(ds4_metal_embedded_sources) / sizeof(ds4_metal_embedded_sources[0]);
