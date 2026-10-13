# Further Optimizations

Candidate optimizations beyond what has already been done:

- **Rebuilding R itself** with `-fno-semantic-interposition -fno-plt`, LTO
  (`--enable-lto=R`) and profile-guided optimization. Measured at −7% (opt)
  and −12% (PGO) wall clock on one dataset / design / replicate of
  `comprehensive_tests.R`, with identical results. See
  [R_OPTIMIZATION.md](../R_OPTIMIZATION.md).
- **Profiling and optimizing `EDI`'s C++ kernels** with `perf`: preallocated
  scratch buffers, hoisting, and allocator-churn removal across the GLMM,
  ordinal, hurdle and other families. See `perf_experiments_final.md` (in
  `EDI_priv`, under `R/package_metadata/audits/`).

Nothing below has been measured yet. Each item says what it would test, why it
might help, and how to adopt it if it wins.

## Where the remaining time goes

From the `/usr/bin/time -v` output of the R-build benchmark in
[R_OPTIMIZATION.md](../R_OPTIMIZATION.md#measured-results) (PGO build, one
replicate of `pte_example` / Bernoulli, 1 core):

| Bucket | Seconds | Share of CPU |
| --- | --- | --- |
| User time | 7723 | ~69% |
| System (kernel) time | 3407 | ~31% |

System time was ~3,400 s in **every** build (base, opt, PGO), so compiler
flags don't touch it. It is the largest bucket no optimization so far has
addressed. The test harness forks a child per call (`safe_call()` via
`parallel::mcparallel()`) from a process with up to ~1.8 GB resident, so fork
plus copy-on-write page faults are the prime suspect. `EDI`'s own parallel
paths fork too, so this is not only a test-harness artifact.

## 1. Replace the memory allocator (no rebuild)

**Hypothesis.** glibc `malloc` is general-purpose. jemalloc and tcmalloc are
usually faster for allocation-heavy programs and keep freed memory for
reuse. That could reduce two costs:

- the remaining small-allocation churn in R and `EDI`, which shows up as
  `_int_malloc`, `cfree` and `R_gc_internal` in the profiles in
  `perf_experiments_final.md` (user time);
- glibc's habit of returning large R vectors to the kernel with `munmap`
  and mapping them again later, where each fresh page costs a page fault
  (system time).

Both allocators are already installed on the development machine:

```bash
/usr/lib/x86_64-linux-gnu/libjemalloc.so.2
/usr/lib/x86_64-linux-gnu/libtcmalloc.so.4
```

mimalloc can be added with `sudo apt-get install libmimalloc2.0`.

### Experiment protocol

1. **Keep R fixed and change only the allocator.** Use one R build for every
   variant (e.g. the PGO build from R_OPTIMIZATION.md). Variants:
   - glibc (baseline): no `LD_PRELOAD`
   - jemalloc: `LD_PRELOAD=/usr/lib/x86_64-linux-gnu/libjemalloc.so.2`
   - tcmalloc: `LD_PRELOAD=/usr/lib/x86_64-linux-gnu/libtcmalloc.so.4`
   - optional, glibc tuned to keep memory:
     `GLIBC_TUNABLES=glibc.malloc.mmap_threshold=<bytes>:glibc.malloc.trim_threshold=<bytes>`.
     This tests the page-fault hypothesis without switching allocators.
2. **Use a shorter workload.** Run only the survival response type: 2,312
   calls, about 30 minutes per run with the PGO build (two passes of
   ~14 minutes each in the R-build benchmark). Survival is chosen because it
   exercises many of `EDI`'s heaviest C++ paths (Cox, Weibull/frailty GLMMs,
   dependent-censoring models), so allocator effects inside the kernels show
   up, not just R-level overhead. It was also the response type that gained
   least from rebuilding R (−5.5%), so it is where non-compiler
   optimizations have the most room to show up.
   ```sh
   Rscript comprehensive_tests.R 1 1 survival Bernoulli NA pte_example NA 1
   ```
   Follow the isolation steps in
   [Reproducing the benchmark](../R_OPTIMIZATION.md#reproducing-the-benchmark):
   run from a copy of `package_tests`, delete the results CSV before each
   run, and use the same package library for every variant.
3. **Control for noise.** Run in the order baseline → jemalloc → tcmalloc →
   baseline on an otherwise idle machine. If the differences come out
   smaller than the baseline-to-baseline drift, repeat the whole sequence.
4. **Check the allocator is really loaded.** Forked children inherit the
   parent's allocator, and `Rscript` subprocesses inherit `LD_PRELOAD`
   through the environment. Still, check from inside each run, because a
   silently ignored `LD_PRELOAD` would make the variants identical:
   ```r
   any(grepl("jemalloc|tcmalloc", readLines(sprintf("/proc/%d/maps", Sys.getpid()))))
   ```
5. **Measure:**
   - from `/usr/bin/time -v`: wall clock, user time, **system time**,
     **minor page faults** and **maximum resident set size** (peak memory).
     Peak memory matters because these allocators often hold more memory,
     and a bigger process makes each fork more expensive, which could
     cancel out the gain;
   - per-call `duration_time_sec`, matched across variants on
     `response_type`, `inference_class`, `function_run`, `beta_T` and `id`;
   - that `result_1`, `result_2` and `status` are identical across
     variants.
6. **Optionally layer in GC tuning.** On the winning allocator, add the R
   garbage-collector settings from [section 2](#2-tune-rs-garbage-collector-no-rebuild)
   in the same harness.

### Adopting a winner

`LD_PRELOAD` must be set before the R process starts, so `~/.Renviron` is too
late. Add one line to the installed R's `etc/ldpaths`, which R's startup
script reads before launching the R binary, so it covers `R`, `Rscript` and
`R CMD` alike:

```bash
echo 'export LD_PRELOAD=/usr/lib/x86_64-linux-gnu/libjemalloc.so.2' | sudo tee -a /usr/local/lib/R/etc/ldpaths
```

`make install` regenerates `ldpaths`, so reapply this line after each R
reinstall.

## 2. Tune R's garbage collector (no rebuild)

**Hypothesis.** `R_gc_internal` reaches ~11% of samples in some kernel
profiles in `perf_experiments_final.md`. R starts with small heaps and grows
them gradually, collecting often along the way. Starting larger and growing
faster means fewer collections.

**Settings to try** (environment variables, which can go in `~/.Renviron`):

| Variable | Default | Try |
| --- | --- | --- |
| `R_GC_MEM_GROW` | 1 (0 is "very conservative") | 2, 3 |
| `R_VSIZE` | 64 MB initial vector heap (`R_VSIZE` in `src/include/Defn.h`; `?Memory` still says 6Mb) | `1Gb`, `4Gb` |
| `R_NSIZE` | 350k cons cells | `10M` |

**First check whether it's worth it.** At the end of a run, `gc.time()`
reports total time spent in GC. If that's only a few percent, skip this
section.

**Watch:** a larger heap raises peak memory, which also makes each fork more
expensive. Use the same protocol as section 1.

## 3. Reduce system (fork / page-fault) time

**Hypothesis.** The ~31% system share comes from forking a large process and
the copy-on-write page faults that follow. Things that could reduce it:

- **Transparent huge pages (THP).** The development machine uses `madvise`
  (huge pages only for memory that explicitly requests them). With
  `always`, page tables are much smaller, so forking copies less. The
  trade-off is that copy-on-write then copies 2 MB pages instead of 4 KB
  ones. It's a one-line, reversible test:
  `echo always | sudo tee /sys/kernel/mm/transparent_hugepage/enabled`.
- **Native Linux instead of WSL2.** WSL2 runs in a lightweight VM, which
  adds a layer of address translation to page faults and process creation.
  The same workload on bare-metal Linux may show much less system time.
  That's worth knowing before tuning anything else in this section.
- **Smaller resident memory before forking.** Running `gc()` before
  dispatching forks, or dropping large objects that the children don't
  need, means less memory to copy-on-write. This is an `EDI`/harness code
  change rather than an environment setting.
- **Fewer forks.** The harness forks per call for hard-timeout enforcement.
  For benchmarking only, a mode that runs calls in-process (with timeouts
  disabled) would show how much of the system time is the harness rather
  than `EDI`.

**First:** run `perf record -e page-faults` or `perf trace -s` on a short
slice, to confirm that page faults and fork actually dominate the system
time before trying fixes.

## 4. Train R's PGO profile on an `EDI` workload

**Hypothesis.** R's PGO build was trained on `make check`, which is a generic
workload. Training on `EDI` itself would weight the interpreter and
`libR.so` code paths `EDI` actually uses.

**How:** in Option B of [R_OPTIMIZATION.md](../R_OPTIMIZATION.md#option-b-pgo-build),
replace (or supplement) the `make check` training step with a short
`comprehensive_tests.R` run using the stage-1 instrumented R (`bin/Rscript`
in the build tree). Its package library must be compatible: same R version.

**Risk:** over-fitting. Code paths that `EDI` doesn't exercise get optimized
for size instead of speed, which can slow down other R work. Evaluate on a
different dataset or design than the one used for training.

## 5. PGO for `EDI`'s own C++ kernels

**Hypothesis.** The same two-stage process, applied to `EDI.so`, could
improve branch layout and inlining in the kernels, especially the optimizer
loops and the GLMM quadrature.

**How:** build `EDI` with `-fprofile-generate` added to its `CXXFLAGS`, run a
training workload, then rebuild with `-fprofile-use`. This needs
`configure`/`Makevars` support, e.g. an `EDI_PGO` variable alongside
`EDI_NATIVE_LTO`.

**Caveats:**

- Per `CLAUDE.md`, full `EDI` builds only run when explicitly requested.
- LTO has already caused severe slowdowns on some small model-fit kernels,
  so measure carefully on the existing kernel benchmarks
  (`R/benchmark/`), not only end to end.
- The unity build (`EDI_UNITY=1`) changes the object files, so the profile
  must be generated and used with the same unity setting.

## 6. BOLT post-link optimization of `libR.so`

**Hypothesis.** BOLT (part of LLVM) rearranges an already-built binary's
machine code using a runtime profile, improving instruction-cache and branch
behavior. On interpreters it typically adds about 5–10% on top of PGO.

**How:** relink `libR.so` with `-Wl,--emit-relocs`, collect a profile with
`perf record -e cycles:u -j any,u` while running a workload, convert it with
`perf2bolt`, then run `llvm-bolt` with options such as
`-reorder-blocks=ext-tsp -reorder-functions=hfsort -split-functions`.

**Tools:** `sudo apt-get install bolt-21` (versioned to match the default
`llvm`; plain `bolt` is an unrelated Thunderbolt daemon). It is part of the
tool roster in `profile/install_perf_tools.sh`, and
`profile/verify_perf_tools.sh` checks it. On this WSL2 box (checked
2026-10-13), `perf record -e cycles:u -j any,u` captures LBR branch stacks
(32 entries), which is the profile mode `perf2bolt` wants. So this does
**not** require native Linux.

**Caveats:**

- The installed `libR.so` has no `.rela.text` section. BOLT's main
  optimizations need R linked with `-Wl,--emit-relocs` (add it to `LDFLAGS`
  at configure time).
- The optimized `libR.so` is a post-processed artifact that must be
  re-BOLTed after every R rebuild.
- This is the most involved item here. Do it last, and only if sections 1–3
  leave the interpreter as a dominant cost.

## Suggested order

1. Section 1 (allocator) and section 2 (GC): no rebuild, about 30 minutes
   per variant on the survival-only workload, trivial to adopt or revert.
2. Section 3: profile the system time first. Then THP (reversible), and if
   possible a native-Linux comparison.
3. Section 4: an extra training run in the next R rebuild.
4. Sections 5 and 6: larger engineering efforts, only if the earlier
   results point to compiled-code hot paths as the remaining bottleneck.
