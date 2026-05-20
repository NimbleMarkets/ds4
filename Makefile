CC ?= cc
UNAME_S := $(shell uname -s)

ifeq ($(UNAME_S),Darwin)
NATIVE_CPU_FLAG ?= -mcpu=native
else
NATIVE_CPU_FLAG ?= -march=native
endif

DEBUG_FLAGS ?= -g
CFLAGS ?= -O3 -ffast-math $(DEBUG_FLAGS) $(NATIVE_CPU_FLAG) -Wall -Wextra -std=c99
OBJCFLAGS ?= -O3 -ffast-math $(DEBUG_FLAGS) $(NATIVE_CPU_FLAG) -Wall -Wextra -Wno-c23-extensions -fobjc-arc

LDLIBS ?= -lm -pthread
METAL_SRCS := \
	metal/flash_attn.metal \
	metal/dense.metal \
	metal/moe.metal \
	metal/dsv4_hc.metal \
	metal/unary.metal \
	metal/dsv4_kv.metal \
	metal/dsv4_rope.metal \
	metal/dsv4_misc.metal \
	metal/argsort.metal \
	metal/cpy.metal \
	metal/concat.metal \
	metal/get_rows.metal \
	metal/sum_rows.metal \
	metal/softmax.metal \
	metal/repeat.metal \
	metal/glu.metal \
	metal/norm.metal \
	metal/bin.metal \
	metal/set_rows.metal
METAL_EMBED := ds4_metal_sources.inc

ifeq ($(UNAME_S),Darwin)
METAL_LDLIBS := $(LDLIBS) -framework Foundation -framework Metal
CORE_OBJS = ds4.o ds4_metal.o
CPU_CORE_OBJS = ds4_cpu.o
else
CFLAGS += -D_GNU_SOURCE -fno-finite-math-only
CUDA_HOME ?= /usr/local/cuda
NVCC ?= $(CUDA_HOME)/bin/nvcc
CUDA_ARCH ?=
ifneq ($(strip $(CUDA_ARCH)),)
NVCC_ARCH_FLAGS := -arch=$(CUDA_ARCH)
endif
NVCCFLAGS ?= -O3 -g -lineinfo --use_fast_math $(NVCC_ARCH_FLAGS) -Xcompiler $(NATIVE_CPU_FLAG) -Xcompiler -pthread
CUDA_LDLIBS ?= -lm -Xcompiler -pthread -L$(CUDA_HOME)/targets/sbsa-linux/lib -L$(CUDA_HOME)/lib64 -lcudart -lcublas
CORE_OBJS = ds4.o ds4_cuda.o
CPU_CORE_OBJS = ds4_cpu.o
METAL_LDLIBS := $(LDLIBS)
endif

# Shared library exposing the public ds4.h API for FFI consumers, e.g. language
# bindings that dlopen() libds4 at runtime and resolve its symbols.
PREFIX ?= /usr/local
LIBDIR ?= $(PREFIX)/lib

ifeq ($(UNAME_S),Darwin)
SHLIB := libds4.dylib
else
SHLIB := libds4.so
endif

.PHONY: all help clean test cpu cuda cuda-spark cuda-generic cuda-regression \
        shared shared-cpu install-shared check-metal-sources

ifeq ($(UNAME_S),Darwin)
all: ds4 ds4-server ds4-bench ds4-eval ds4-agent

help:
	@echo "DS4 build targets:"
	@echo "  make              Build Metal ./ds4, ./ds4-server, ./ds4-bench, ./ds4-eval, and ./ds4-agent"
	@echo "  make cpu          Build CPU-only ./ds4, ./ds4-server, ./ds4-bench, ./ds4-eval, and ./ds4-agent"
	@echo "  make shared       Build Metal ./$(SHLIB) (FFI shared library)"
	@echo "  make shared-cpu   Build CPU-only ./$(SHLIB)"
	@echo "  make install-shared  Build ./$(SHLIB) and install it to $(LIBDIR)"
	@echo "  make check-metal-sources  Verify #embed can read every Metal source"
	@echo "  make test         Build and run tests"
	@echo "  make clean        Remove build outputs"

ds4: ds4_cli.o linenoise.o $(CORE_OBJS)
	$(CC) $(CFLAGS) -o $@ ds4_cli.o linenoise.o $(CORE_OBJS) $(METAL_LDLIBS)

ds4-server: ds4_server.o ds4_kvstore.o rax.o $(CORE_OBJS)
	$(CC) $(CFLAGS) -o $@ ds4_server.o ds4_kvstore.o rax.o $(CORE_OBJS) $(METAL_LDLIBS)

ds4-bench: ds4_bench.o $(CORE_OBJS)
	$(CC) $(CFLAGS) -o $@ ds4_bench.o $(CORE_OBJS) $(METAL_LDLIBS)

ds4-eval: ds4_eval.o $(CORE_OBJS)
	$(CC) $(CFLAGS) -o $@ ds4_eval.o $(CORE_OBJS) $(METAL_LDLIBS)

ds4-agent: ds4_agent.o ds4_web.o ds4_kvstore.o linenoise.o $(CORE_OBJS)
	$(CC) $(CFLAGS) -o $@ ds4_agent.o ds4_web.o ds4_kvstore.o linenoise.o $(CORE_OBJS) $(METAL_LDLIBS)

cpu: ds4_cli_cpu.o ds4_server_cpu.o ds4_bench_cpu.o ds4_eval_cpu.o ds4_agent_cpu.o ds4_web.o ds4_kvstore.o linenoise.o rax.o $(CPU_CORE_OBJS)
	$(CC) $(CFLAGS) -o ds4 ds4_cli_cpu.o linenoise.o $(CPU_CORE_OBJS) $(LDLIBS)
	$(CC) $(CFLAGS) -o ds4-server ds4_server_cpu.o ds4_kvstore.o rax.o $(CPU_CORE_OBJS) $(LDLIBS)
	$(CC) $(CFLAGS) -o ds4-bench ds4_bench_cpu.o $(CPU_CORE_OBJS) $(LDLIBS)
	$(CC) $(CFLAGS) -o ds4-eval ds4_eval_cpu.o $(CPU_CORE_OBJS) $(LDLIBS)
	$(CC) $(CFLAGS) -o ds4-agent ds4_agent_cpu.o ds4_web.o ds4_kvstore.o linenoise.o $(CPU_CORE_OBJS) $(LDLIBS)

shared: ds4_pic.o ds4_metal_pic.o
	$(CC) $(CFLAGS) -fPIC -dynamiclib -install_name @rpath/$(SHLIB) -o $(SHLIB) $^ $(METAL_LDLIBS)

shared-cpu: ds4_cpu_pic.o
	$(CC) $(CFLAGS) -fPIC -dynamiclib -install_name @rpath/$(SHLIB) -o $(SHLIB) $^ $(LDLIBS)

cuda-regression:
	@echo "cuda-regression requires a CUDA build"
else
all: help

help:
	@echo "DS4 build targets:"
	@echo "  make cuda-spark          Build CUDA for DGX Spark / GB10"
	@echo "  make cuda-generic        Build CUDA for a generic local CUDA GPU"
	@echo "  make cuda CUDA_ARCH=sm_N Build CUDA with an explicit nvcc -arch value"
	@echo "  make cpu                 Build CPU-only ./ds4, ./ds4-server, ./ds4-bench, ./ds4-eval, and ./ds4-agent"
	@echo "  make shared [CUDA_ARCH=] Build CUDA ./$(SHLIB) (FFI shared library)"
	@echo "  make shared-cpu          Build CPU-only ./$(SHLIB)"
	@echo "  make install-shared      Build ./$(SHLIB) and install it to $(LIBDIR)"
	@echo "  make check-metal-sources Verify #embed can read every Metal source"
	@echo "  make test                Build and run tests"
	@echo "  make clean               Remove build outputs"

cuda-spark:
	$(MAKE) ds4 ds4-server ds4-bench ds4-eval ds4-agent CUDA_ARCH=

cuda-generic:
	$(MAKE) ds4 ds4-server ds4-bench ds4-eval ds4-agent CUDA_ARCH=native

cuda:
	@if [ -z "$(strip $(CUDA_ARCH))" ]; then \
		echo "error: specify CUDA_ARCH, for example: make cuda CUDA_ARCH=sm_120"; \
		echo "       or use make cuda-spark / make cuda-generic"; \
		exit 2; \
	fi
	$(MAKE) ds4 ds4-server ds4-bench ds4-eval ds4-agent CUDA_ARCH="$(CUDA_ARCH)"

ds4: ds4_cli.o linenoise.o $(CORE_OBJS)
	$(NVCC) $(NVCCFLAGS) -o $@ $^ $(CUDA_LDLIBS)

ds4-server: ds4_server.o ds4_kvstore.o rax.o $(CORE_OBJS)
	$(NVCC) $(NVCCFLAGS) -o $@ $^ $(CUDA_LDLIBS)

ds4-bench: ds4_bench.o $(CORE_OBJS)
	$(NVCC) $(NVCCFLAGS) -o $@ $^ $(CUDA_LDLIBS)

ds4-eval: ds4_eval.o $(CORE_OBJS)
	$(NVCC) $(NVCCFLAGS) -o $@ $^ $(CUDA_LDLIBS)

ds4-agent: ds4_agent.o ds4_web.o ds4_kvstore.o linenoise.o $(CORE_OBJS)
	$(NVCC) $(NVCCFLAGS) -o $@ $^ $(CUDA_LDLIBS)

cpu: ds4_cli_cpu.o ds4_server_cpu.o ds4_bench_cpu.o ds4_eval_cpu.o ds4_agent_cpu.o ds4_web.o ds4_kvstore.o linenoise.o rax.o $(CPU_CORE_OBJS)
	$(CC) $(CFLAGS) -o ds4 ds4_cli_cpu.o linenoise.o $(CPU_CORE_OBJS) $(LDLIBS)
	$(CC) $(CFLAGS) -o ds4-server ds4_server_cpu.o ds4_kvstore.o rax.o $(CPU_CORE_OBJS) $(LDLIBS)
	$(CC) $(CFLAGS) -o ds4-bench ds4_bench_cpu.o $(CPU_CORE_OBJS) $(LDLIBS)
	$(CC) $(CFLAGS) -o ds4-eval ds4_eval_cpu.o $(CPU_CORE_OBJS) $(LDLIBS)
	$(CC) $(CFLAGS) -o ds4-agent ds4_agent_cpu.o ds4_web.o ds4_kvstore.o linenoise.o $(CPU_CORE_OBJS) $(LDLIBS)

shared: ds4_pic.o ds4_cuda_pic.o
	$(NVCC) $(NVCCFLAGS) -Xcompiler -fPIC --shared -o $(SHLIB) $^ $(CUDA_LDLIBS)

shared-cpu: ds4_cpu_pic.o
	$(CC) $(CFLAGS) -fPIC -shared -Wl,-soname,$(SHLIB) -o $(SHLIB) $^ $(LDLIBS)

cuda-regression: tests/cuda_long_context_smoke
	./tests/cuda_long_context_smoke
endif

ds4.o: ds4.c ds4.h ds4_gpu.h
	$(CC) $(CFLAGS) -c -o $@ ds4.c

ds4_cli.o: ds4_cli.c ds4.h linenoise.h
	$(CC) $(CFLAGS) -c -o $@ ds4_cli.c

ds4_server.o: ds4_server.c ds4.h ds4_kvstore.h rax.h
	$(CC) $(CFLAGS) -c -o $@ ds4_server.c

ds4_bench.o: ds4_bench.c ds4.h
	$(CC) $(CFLAGS) -c -o $@ ds4_bench.c

ds4_eval.o: ds4_eval.c ds4.h
	$(CC) $(CFLAGS) -c -o $@ ds4_eval.c

ds4_agent.o: ds4_agent.c ds4.h ds4_kvstore.h ds4_web.h linenoise.h
	$(CC) $(CFLAGS) -c -o $@ ds4_agent.c

ds4_web.o: ds4_web.c ds4_web.h
	$(CC) $(CFLAGS) -c -o $@ ds4_web.c

ds4_kvstore.o: ds4_kvstore.c ds4_kvstore.h ds4.h
	$(CC) $(CFLAGS) -c -o $@ ds4_kvstore.c

ds4_test.o: tests/ds4_test.c ds4_server.c ds4.h ds4_kvstore.h rax.h
	$(CC) $(CFLAGS) -Wno-unused-function -c -o $@ tests/ds4_test.c

tests/cuda_long_context_smoke.o: tests/cuda_long_context_smoke.c ds4_gpu.h
	$(CC) $(CFLAGS) -I. -c -o $@ tests/cuda_long_context_smoke.c

rax.o: rax.c rax.h rax_malloc.h
	$(CC) $(CFLAGS) -c -o $@ rax.c

linenoise.o: linenoise.c linenoise.h
	$(CC) $(CFLAGS) -c -o $@ linenoise.c

ds4_cpu.o: ds4.c ds4.h ds4_gpu.h
	$(CC) $(CFLAGS) -DDS4_NO_GPU -c -o $@ ds4.c

ds4_cli_cpu.o: ds4_cli.c ds4.h linenoise.h
	$(CC) $(CFLAGS) -DDS4_NO_GPU -c -o $@ ds4_cli.c

ds4_server_cpu.o: ds4_server.c ds4.h ds4_kvstore.h rax.h
	$(CC) $(CFLAGS) -DDS4_NO_GPU -c -o $@ ds4_server.c

ds4_bench_cpu.o: ds4_bench.c ds4.h
	$(CC) $(CFLAGS) -DDS4_NO_GPU -c -o $@ ds4_bench.c

ds4_eval_cpu.o: ds4_eval.c ds4.h
	$(CC) $(CFLAGS) -DDS4_NO_GPU -c -o $@ ds4_eval.c

ds4_agent_cpu.o: ds4_agent.c ds4.h ds4_kvstore.h ds4_web.h linenoise.h
	$(CC) $(CFLAGS) -DDS4_NO_GPU -c -o $@ ds4_agent.c

check-metal-sources: ds4_metal.m ds4_gpu.h $(METAL_EMBED) $(METAL_SRCS)
	$(CC) $(OBJCFLAGS) -fsyntax-only ds4_metal.m

ds4_metal.o: ds4_metal.m ds4_gpu.h $(METAL_EMBED) $(METAL_SRCS)
	$(CC) $(OBJCFLAGS) -c -o $@ ds4_metal.m

ds4_cuda.o: ds4_cuda.cu ds4_gpu.h ds4_iq2_tables_cuda.inc
	$(NVCC) $(NVCCFLAGS) -c -o $@ ds4_cuda.cu

# Position-independent objects for the libds4 shared library.  Kept separate
# from the executable objects above so the perf-tuned binaries are untouched.
ds4_pic.o: ds4.c ds4.h ds4_gpu.h
	$(CC) $(CFLAGS) -fPIC -c -o $@ ds4.c

ds4_cpu_pic.o: ds4.c ds4.h ds4_gpu.h
	$(CC) $(CFLAGS) -fPIC -DDS4_NO_GPU -c -o $@ ds4.c

ds4_metal_pic.o: ds4_metal.m ds4_gpu.h $(METAL_EMBED) $(METAL_SRCS)
	$(CC) $(OBJCFLAGS) -fPIC -c -o $@ ds4_metal.m

ds4_cuda_pic.o: ds4_cuda.cu ds4_gpu.h ds4_iq2_tables_cuda.inc
	$(NVCC) $(NVCCFLAGS) -Xcompiler -fPIC -c -o $@ ds4_cuda.cu

# Build and install the shared library (override LIBDIR to choose the path).
install-shared: shared
	mkdir -p $(LIBDIR)
	cp $(SHLIB) $(LIBDIR)/$(SHLIB)
	@echo "installed $(SHLIB) -> $(LIBDIR)/$(SHLIB)"

tests/ds4_gpu_log_stub.o: tests/ds4_gpu_log_stub.c
	$(CC) $(CFLAGS) -c -o $@ tests/ds4_gpu_log_stub.c

# The smoke test links ds4_cuda.o without the full engine.  ds4_cuda.o
# references ds4_gpu_log (defined in ds4.c) for kernel diagnostics, so we
# satisfy it with a tiny stderr-only stub instead of dragging ds4.o in.
tests/cuda_long_context_smoke: tests/cuda_long_context_smoke.o tests/ds4_gpu_log_stub.o ds4_cuda.o
	$(NVCC) $(NVCCFLAGS) -o $@ $^ $(CUDA_LDLIBS)

# Test-flavored core object: identical to ds4.o except it also defines
# ds4_test_invoke_die() so the unit-test binary can trigger ds4_die() from
# outside the translation unit.  Production objects (ds4.o, ds4_pic.o) do
# not get DS4_TESTING and therefore do not export this symbol.
ds4_for_test.o: ds4.c ds4.h ds4_gpu.h
	$(CC) $(CFLAGS) -DDS4_TESTING -c -o $@ ds4.c

TEST_CORE_OBJS = $(subst ds4.o,ds4_for_test.o,$(CORE_OBJS))

ds4_test: ds4_test.o ds4_kvstore.o rax.o $(TEST_CORE_OBJS)
ifeq ($(UNAME_S),Darwin)
	$(CC) $(CFLAGS) -o $@ ds4_test.o ds4_kvstore.o rax.o $(TEST_CORE_OBJS) $(METAL_LDLIBS)
else
	$(NVCC) $(NVCCFLAGS) -o $@ ds4_test.o ds4_kvstore.o rax.o $(TEST_CORE_OBJS) $(CUDA_LDLIBS)
endif

test: ds4_test ds4-eval
	./ds4-eval --self-test-extractors
	./ds4_test

clean:
	rm -f ds4 ds4-server ds4-bench ds4-eval ds4-agent ds4_cpu ds4_native ds4_server_test ds4_test *.o libds4.dylib libds4.so libds4.dll tests/cuda_long_context_smoke tests/cuda_long_context_smoke.o tests/ds4_gpu_log_stub.o
