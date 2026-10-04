# Changelog (NimbleMarkets `nm-shared` fork)

Changes this fork carries on top of upstream DwarfStar. Upstream changes are
not listed here.

## Unreleased

### ROCm: multi-architecture builds and wave64 (CDNA) support

* `ROCM_ARCHS` builds one fat binary for several AMD GPU architectures, for
  example `make shared-rocm ROCM_ARCHS="gfx1151 gfx942"`. Spaces and commas
  both work as separators. `ROCM_ARCH=gfxNNNN` still selects a single
  architecture, and `make strix-halo` / `make rocm` still default to `gfx1151`.
  Every ROCm build target and ROCm test uses the list.
* When the list changes, ROCm objects are rebuilt instead of being linked into
  a binary that mixes architectures. A `.rocm-archs.stamp` file tracks the list.
* The library exports the compiled list as `ds4_rocm_offload_archs`, a
  comma-separated `const char[]`. Loaders such as ds4go read it from the ELF
  dynamic symbol table and refuse a library that has no code for the host GPU.
  Without that check, the mismatch only shows up as `invalid device function`
  on the first kernel launch.
* The release `linux-x86_64-rocm` asset now covers `gfx1151 gfx1100 gfx1101
  gfx1102 gfx1200 gfx1201 gfx942`. `gfx1151` and `gfx942` are verified; the
  RDNA3 and RDNA4 targets are experimental. The tarball adds a `ROCM_ARCHS`
  file, and CI builds the same list.
* wave64 fixes for CDNA (`gfx942`; also needed for `gfx90a`/`gfx950`). All of
  them are no-ops on wave32 RDNA, so Strix Halo behaviour is unchanged.
  * Shuffle masks are now taken relative to the hardware wavefront
    (`DS4_LANE_GROUP_MASK`). `FULL_WARP_MASK` means "this lane's 32-lane warp"
    on HIP. HIP's `*_sync` builtins trap when the mask is not exactly the set
    of active lanes. That broke the MoE quarter/half-warp sums, the indexed
    attention score dots, and both router top-k kernels (DeepSeek and GLM).
  * Broadcast shuffles from lane 0 that relied on the default width now pass
    width 32. Before this, on wave64 the odd head of the heads8 online
    attention kernels read the even head's score and softmax stats.
  * Kernels that split a block into 32-thread warps and issue rocWMMA
    operations per warp now launch only on wave32 hardware
    (`ds4_rocm_is_wave32()`). wave64 hardware falls through to the existing
    portable kernels. Affected: the MoE hotlist gate/up/down WMMA kernels, the
    indexer `wmma128` scorer, and the opt-in `DS4_ROCM_ATTN_WMMA16*` paths.
    `ds4_rocm_gfx1151_flag()` also requires wave32, so an environment override
    can no longer force a wave32-only kernel onto CDNA.
  * The Q8_0 batched row-tile kernel calls RDNA3 `__builtin_amdgcn_wmma_*_w32`
    directly. It now compiles only for gfx11 and launches only on gfx11
    devices (`ds4_rocm_has_gfx11_wmma()`). Previously it did not compile for
    any other target.
* New [docs/ROCM.md](docs/ROCM.md) covers supported architectures, building
  for your GPU, build-time and size numbers, the ROCm runtime version, and the
  `ld.so.conf.d` note for `/opt/rocm/core-*/lib`.
