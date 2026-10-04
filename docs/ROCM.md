# ROCm GPU architectures

[README](../README.md) | [Strix Halo](STRIX_HALO.md)

A HIP binary contains GPU code only for the architectures it was compiled for.
On any other AMD GPU the library still loads, but the first kernel launch
fails with `invalid device function`. DwarfStar therefore builds with an
explicit architecture list, which can hold several targets in one fat binary.

## Supported architectures

| Architecture | GPUs | Wavefront | Status |
| --- | --- | --- | --- |
| `gfx1151` | Strix Halo (Radeon 8060S) | 32 | supported; the reference system and default build |
| `gfx942` | Instinct MI300X / MI300A / MI325X | 64 | supported; verified on an MI325X (ROCm 10.0) with the 0731 Flash Q2 GGUF |
| `gfx1100`, `gfx1101`, `gfx1102` | Radeon RX 7900 / 7800 / 7700 / 7600 (RDNA3) | 32 | experimental: compiles, not yet run on hardware |
| `gfx1200`, `gfx1201` | Radeon RX 9060 / 9070 (RDNA4) | 32 | experimental: compiles, not yet run on hardware |

The release `libds4-VERSION-linux-x86_64-rocm.tar.gz` asset is built for all
of the architectures above. If you have run `ds4-eval` on one of the
experimental targets, please report the result.

**Unverified alternatives.** Other CDNA parts (`gfx90a` MI200, `gfx950` MI350)
are also wave64 and use the same code paths as `gfx942`, so they should work
when built with `ROCM_ARCHS`, but nobody has tested them. RDNA2 (`gfx1030`) has
no WMMA instructions and has not been tried.

On wave64 hardware, a few rocWMMA fast paths tuned for RDNA are disabled.
Those kernels split a block into 32-thread warps, and on CDNA two such warps
share a single 64-lane wavefront. Batched prefill therefore runs the portable
kernels there. The kernels that Strix Halo uses are unchanged.

## Build for your GPU

Find your architecture:

```sh
rocminfo | grep -o -m1 'gfx[0-9a-f]*'
```

Then build the CLI tools or the shared library for it:

```sh
make rocm ROCM_ARCHS=gfx942
make shared-rocm ROCM_ARCHS=gfx942
make shared-rocm ROCM_ARCHS="gfx1151 gfx1100 gfx942"   # several targets, one binary
```

Separate the list with spaces or commas. `ROCM_ARCH=gfx1100` (singular) still
selects a single target. `make strix-halo` and `make rocm` default to
`gfx1151`. Changing the list rebuilds every ROCm object, so a stale object can
never be linked in for the wrong target.

The library records its list in the exported `ds4_rocm_offload_archs` string,
which you can inspect without a GPU:

```sh
nm -D libds4.so | grep ds4_rocm_offload_archs
gdb -batch -ex 'print (char*)ds4_rocm_offload_archs' libds4.so
```

ds4go reads this string from the file before it loads the library. It refuses
a library that has no code for the host GPU, and suggests the rebuild command.

### Arch lists versus generic targets

LLVM also offers generic targets (`gfx9-4-generic`, `gfx11-generic`,
`gfx12-generic`), which emit one code object per family. Measured on an EPYC
9575F with `make -j20 shared-rocm`, clean, against ROCm 10.0:

| `ROCM_ARCHS` | Build time | `libds4.so` size |
| --- | ---: | ---: |
| `gfx1151` | 74 s | 72.8 MB |
| `gfx942` | 34 s | 30.6 MB |
| `gfx1151 gfx1100 gfx1101 gfx1102 gfx1200 gfx1201 gfx942` (release) | 407 s | 149.1 MB |
| `gfx11-generic gfx12-generic gfx9-4-generic` | fails to compile | - |

Generic targets are not an option yet: rocWMMA's `config.hpp` selects its
instructions by concrete-chip macros, and a generic target defines only
`__gfx11_generic__` and the like, so rocWMMA fails with `static assertion
failed: Unsupported architecture`. Defining a concrete macro by hand would
defeat the purpose of a generic target and is unsupported. Instead, add other
chips that rocWMMA supports to the explicit list, for example the APUs
`gfx1103`, `gfx1150`, `gfx1152` and `gfx1153`, or `gfx950`. Several kernels also
select code paths by concrete processor macros (`__gfx1151__`, `__gfx942__`),
which a generic target does not define. The release therefore uses an explicit
list. Its cost grows roughly linearly with the number of targets.

## ROCm runtime

The release asset is built against **ROCm 7.2.4**. It links
`libamdhip64.so.7`, `libhipblas.so.3`, `libhipblaslt.so.1`, and
`librocblas.so.5`. Any ROCm 7.x runtime provides these sonames, and ROCm 10.0
ships the same ones; `gfx942` was verified on ROCm 10.0. Your hipBLASLt and
rocBLAS installation must also include kernels for your GPU.

Newer ROCm releases can install under a versioned prefix such as
`/opt/rocm/core-10.0`, whose `lib/` directory is not on the dynamic loader's
search path. Register it once:

```sh
echo /opt/rocm/core-10.0/lib | sudo tee /etc/ld.so.conf.d/rocm-10.conf
sudo ldconfig
```

`rocminfo` and `amd-smi` live in `/opt/rocm/core-10.0/bin` on such installs.

## Verifying a new architecture

For a model-free check, run `make test-mxfp4-rocm ROCM_ARCHS=gfxNNNN`. Then,
with the 0731 Flash Q2 GGUF:

```sh
make test-rocm ROCM_ARCHS=gfxNNNN   # builds ds4_test, ds4-eval and the CLI; runs the core suite
DS4_TEST_MODEL=/path/to/0731.gguf \
DS4_TEST_VECTOR_FILE=tests/test-vectors/flash-0731/official.vec \
  ./ds4_test --logprob-vectors
./ds4-eval -m /path/to/0731.gguf --suite hard-smoke
```

The logprob vectors compare logits against the reference model, so they detect
kernel bugs that a pass/fail eval can miss.
