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

### Result (2026-10-14): no allocator beats glibc + huge pages; screen confounded by drift

**Setup.** The PGO build of R r90668 was used with the baseline already
including `GLIBC_TUNABLES=glibc.malloc.hugetlb=1` (section 3). Instead of
survival only, the workload was one heavy class per response type, run
concurrently, all test families (Wald/asymptotic, randomization/bootstrap,
other), `pte_example`, Bernoulli, `nc = 1`: ContinQuantileRegr,
IncidLogBinomial, PropBetaRegr, CountHurdleNegBin, SurvivalStratCoxPHRegr,
OrdinalContRatioRegr. That is 2,166 calls, about 14 minutes per run. Variants
in palindrome order: base → jemalloc → jemalloc + `MALLOC_CONF=thp:always,metadata_thp:auto`
→ tcmalloc → tcmalloc → jemalloc + THP → jemalloc → base. Each preloaded
allocator was confirmed to be mapped in R.

**Validity problems.** `EDI` was reinstalled twice during the screen, from
the development checkout (R code only; `EDI.so` was unchanged until the
second one):

- between jethp1 and tc1 (`EDI.rdb` md5 `a0375791…` → `6628846f…`), during
  commit/pre-push hook activity that regenerated `package_tests` CSVs;
- during base2 (16:31), which removed `EDI.rdb` mid-run. 772 base2 calls
  failed, so base2 is unusable and the palindrome cannot be closed.

`result_1`, `result_2` and `status` were identical in all 2,166 calls
across the seven complete runs, so the R-code change did not alter this
workload's results. Load did change, though. Total user CPU time, for
identical work, rose from 2,637 s (base1) to 3,032 s (jethp1), then fell to
2,474 s (je2). That is hump-shaped drift peaking around tc1/tc2.

**Per-call ratios vs base1** (matched calls > 0.05 s, n ≈ 1,700):

| Variant | Run 1 sum / median | Run 2 sum / median | Mean of runs (sum) |
|---|---|---|---|
| jemalloc | 1.047 / 1.025 | 0.946 / 0.919 | 0.997 |
| jemalloc + THP | 1.148 / 1.091 | 1.009 / 0.978 | 1.078 |
| tcmalloc | 1.207 / 1.087 | 1.072 / 1.017 | 1.140 |

Repeating the same allocator moved it by about 10% (tc1 → tc2 0.888,
je1 → je2 0.903, jethp1 → jethp2 0.878). That is as large as any gap between
allocators, and the ordering inside each half simply follows run order. The
per-response-type × family breakdown shows no allocator winning consistently
on Wald or on resampling calls.

**Fork/page-fault costs** (the main reason to try another allocator) did not
improve with any of them:

| Run | sys (s) | Minor faults | Max RSS |
|---|---|---|---|
| base1 | 618 | 83.4 M | 1,289 MB |
| je1 / je2 | 649 / 646 | 89.5 M / 102.2 M | 1,345 / 1,280 MB |
| jethp1 / jethp2 | 697 / 657 | 80.7 M / 89.4 M | 1,370 / 1,296 MB |
| tc1 / tc2 | 778 / 729 | 88.3 M / 100.0 M | 1,384 / 1,323 MB |

This matches section 3: the faults come from copy-on-write of R's GC heap
in the forked child, which the allocator does not control.

**Conclusion.** Keep glibc with `glibc.malloc.hugetlb=1`; do not add an
`LD_PRELOAD` allocator.

- tcmalloc and jemalloc + THP are, at best, no better.
- jemalloc averages out to parity (0.997) with ±5% uncertainty.
- None reduces system time or page faults.

A clean confirmation would need base vs jemalloc in ABBA order on an idle
machine with no `EDI` reinstalls during the run. A gain small enough to hide
in this noise is not worth the `ldpaths` maintenance. Data:
`sys3/multi/` in the 2026-10-14 session scratchpad (`analyze.R`, `ident.R`,
`progress.log`).

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

**Measured (2026-10-14, section 3):** on the fork-per-call harness,
`R_GC_MEM_GROW=3 R_VSIZE=2Gb R_NSIZE=20000000` raised system time by 72% and
wall time by 19%. Don't use large heap settings with fork-heavy workloads.
They might still help single-process, non-forking runs, but that hasn't been
tested.

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

### Result (2026-10-14): the cause is the harness's per-call fork, and GC in the child

**Test slice.** Survival, CoxPH only, on the PGO build:
`comprehensive_tests.R 1 1 survival Bernoulli InferenceSurvivalCoxPHRegr pte_example NA 1`.
It makes 452 calls in about 5 minutes and has the same shape as the full
workload:

- 32% of CPU time is system time;
- 18–23 M minor page faults, about 40–50 k per call, or ~160 MB of newly
  touched pages per call against a 1.2 GB peak RSS;
- about 220 ms of system time per call, roughly 5 µs per fault on WSL2.

**Where it comes from.** A micro-probe ran 100 `mcparallel()` children per
condition (`forkprobe.R`, `gcprobe.R` in the session scratchpad). System time
per fork, parent plus child:

| Parent heap | Child does | sys / fork |
| --- | --- | --- |
| ~0 | nothing | 12 ms |
| ~0 | `gc()` | 94 ms |
| 1 GB of large vectors | nothing | 51 ms |
| 1 GB of large vectors | `gc()` | 137 ms |
| 1 GB, `glibc.malloc.hugetlb=1` | nothing | 18 ms |
| 1 GB, `glibc.malloc.hugetlb=1` | `gc()` | 104 ms |

There are two costs:

1. **Copying page tables at fork, and tearing them down at exit.** This
   costs about 40 ms per GB of parent RSS on WSL2.
2. **Copy-on-write caused by R's GC in the child.** R keeps mark bits in
   each node's header, so any GC in the child writes to, and therefore
   copies, every heap page holding live nodes. That includes all loaded
   package code. A full GC raised a child's faults from 4 k (17 MB) to 24 k
   (95 MB).

Most of the ~31% system share in `comprehensive_tests.R` is therefore the
harness's fork per call (`safe_call()`), not `EDI` itself. A single-core
`EDI` call never forks. The same cost does apply to `EDI`'s own parallel
paths: `InferenceSuite` with `num_cores > 1` (one `mcparallel()` per task)
and the `makeForkCluster` pools in the simulation framework.

**What was tried on the slice.** Results were identical in every run. Pairs
are adjacent runs, since two baselines drifted ~10% apart:

| Variant | sys vs paired baseline | wall vs paired baseline | Notes |
| --- | --- | --- | --- |
| `GLIBC_TUNABLES=glibc.malloc.hugetlb=1` | −10%, −12% | −2%, −1.4% | THP for malloc'd memory via `madvise`; RSS unchanged |
| `R_GC_MEM_GROW=3 R_VSIZE=2Gb R_NSIZE=20000000` | **+72%** | +19% | Larger parent heap (3.2 GB RSS) means more to copy, and children still collect |

**Conclusions.**

- **THP for malloc helps a little and costs nothing.** It works with the
  system's default THP mode (`madvise`), so it needs no sudo. To adopt it,
  set `GLIBC_TUNABLES` before R starts, in the same way as an allocator
  `LD_PRELOAD` (section 1):
  `echo 'export GLIBC_TUNABLES=glibc.malloc.hugetlb=1' | sudo tee -a /usr/local/lib/R/etc/ldpaths`.
  Reapply it after every R reinstall. Setting
  `/sys/kernel/mm/transparent_hugepage/enabled` to `always` should behave
  much the same for R, whose memory is all malloc'd, but it affects every
  process on the machine.
- **Don't enlarge R's heap when forking.** This contradicts the hypothesis
  in section 2 for any workload that forks: fewer GCs don't make up for a
  bigger image to copy.
- **The real lever is structural, in the harness or in `EDI`'s fork
  paths.** For example:
  - run calls in-process when no hard timeout is needed;
  - fork from a lean "zygote" process that holds only the loaded packages
    and the current dataset;
  - keep the parent's live heap small at fork time (drop accumulated result
    objects and run `gc()` in the parent first).

  Only a change in R's GC, such as side-table mark bitmaps like Ruby's
  copy-on-write-friendly GC, would remove the copy-on-write that GC causes
  in children.
- **Native Linux is still untested.** The ~5 µs per fault and ~40 ms per GB
  fork cost measured here may be WSL2's extra layer of address
  translation.

### Result (2026-10-14): in-process `safe_call()` cuts per-call time by about a third, with identical results

`gc()` in the parent before each fork was not tried. The probe above shows
that a child's GC costs ~94 ms per fork even when the parent heap is near
empty, because loaded package code is also on the heap. Only avoiding the
fork removes that cost.

**Prototype.** The scratch copy of `comprehensive_tests.R` gained an opt-in
mode, `COMPREHENSIVE_SAFE_CALL_MODE=inprocess`. It evaluates `expr` in the
parent under `R.utils::withTimeout()`, the existing non-Unix fallback. To
keep fork semantics, it undoes what a forked child would have kept to
itself, **before** the `handle_*()` callbacks (which run in the parent in
both modes):

- `.Random.seed`;
- `num_cores`;
- every plain (not active, not locked) field of the inference object,
  its private environment, and its design's public and private
  environments.

The patch is `inprocess_safe_call.diff` in the session scratchpad. It
applies cleanly to the repo.

Two things that look harmless are not, and both were found by testing:

- **Calls mutate shared state.** They write caches, warm starts and draw
  counters on the inference object, and randomization tests write
  `permutations_cache` on the shared design.
- **Parent-side helpers consume the RNG.** `handle_success()`/`handle_error()`
  and `safe_call_debug()` call methods on the object that draw random
  numbers. Restoring the RNG *after* the handlers undid that legitimate
  parent-side use, which shifted every later random draw.

With the restore placed correctly, a per-call trace of a hash of
`.Random.seed` matched fork mode at all 194 calls of the ordinal class.

**Measurement.** The workload was the six-class mix from section 1 (2,166
calls, six processes in parallel). `EDI` was loaded from a private snapshot
of the installed package, because it was being reinstalled during the
session. The order was fork → in-process → in-process keep-state →
keep-state → in-process → fork.

| Run | Results identical to fork1 | Wall (s) | Sum of call times (s) | user (s) | sys (s) | Minor faults | Max RSS |
|---|---|---|---|---|---|---|---|
| fork1 | — | 1,539 | 6,653 | 4,179 | 1,081 | 93.8 M | 1,341 MB |
| inprocess1 | **2,166 / 2,166** | 786 | 2,736 | 2,766 | 48 | 0.7 M | 1,427 MB |
| keep-state1 | 615 / 2,166 | 332 | 1,279 | 1,392 | 21 | 0.7 M | 1,453 MB |
| keep-state2 | 615 / 2,166 | 336 | 1,379 | 1,495 | 22 | 0.7 M | 1,477 MB |
| inprocess2 | **2,166 / 2,166** | 641 | 2,027 | 2,126 | 32 | 0.7 M | 1,428 MB |
| fork2 | 2,166 / 2,166 | 829 | 3,040 | 2,647 | 652 | 92.9 M | 1,315 MB |

Other activity loaded the machine during the first pair: user CPU time for
the same work was 4,179 s in fork1 versus 2,647 s in fork2. The adjacent,
quieter pair, fork2 → inprocess2, is therefore the conservative estimate:

- **Per-call time:** sum of matched calls 0.673, median 0.550.
- **Wall clock:** −23%, from 829 s to 641 s.
- **System time:** −95%.
- **Minor faults:** −99%.

By response type and test family, the per-call ratio is 0.15–0.92 for
Wald/asymptotic calls (the fixed fork cost dominates fast calls; the median
asymptotic call dropped from 43 ms to 21 ms) and 0.43–0.76 for resampling
calls. The loaded first pair showed an even larger gain (sum 0.416): forking
degrades worse than in-process work under CPU contention.

**Keep-state** skips the restore, so calls reuse the fits and caches of
earlier calls, as in a normal user session. It halves the time again (wall
about 335 s), but only 615 of 2,166 results stay identical: resampling
calls see different random streams, and warm starts change fits. That
changes what the suite measures, so it is not a drop-in.

**Conclusions and what adoption needs.**

- In-process mode with state restore is a drop-in speedup for
  `comprehensive_tests.R` at `nc = 1`, verified identical on 2 × 2,166
  calls. It saves about a third of the test time on this machine.
- **Lost: the hard timeout.** `setTimeLimit()` cannot interrupt a long
  compiled call (the reason `safe_call()` forks). This workload had no
  timeouts. A safe adoption keeps fork mode for labels already known to be
  slow, or adds an external watchdog. For example, the runner kills the R
  process when the heartbeat shows one call past `FUNCTION_TIMEOUT_SEC`,
  records a timeout for that call, and relaunches; the harness already
  resumes from `is_row_completed()`.
- **Lost: crash isolation.** A native crash ends the run instead of one
  call. The same relaunch-and-resume covers it.
- **Restrict to `nc = 1`.** With `nc > 1`, OpenMP would run in a process
  that might later fork (the hazard documented in `safe_call()`).
- The restore covers plain fields of the inference object and its design.
  It does not cover objects nested in environment-valued fields or global
  variables. Any new class that keeps state elsewhere should be checked
  with the same identity test.

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

### Result (2026-10-14): no gain over `make check` training

**Pitfall: forked children lose their profile.** The harness runs every call
in a `parallel::mcparallel()` child. `mc_exit()` ends children with
`_exit()`, which skips gcov's atexit dump, so an instrumented R records
almost none of `EDI`'s actual work. For the training build only,
`src/library/parallel/src/fork.c` was patched behind `-DR_PGO_TRAINING`
(added to stage-1 `CFLAGS`):

- call `__gcov_reset()` in the child right after `fork()`, so the parent's
  pre-fork counts aren't added once per child;
- call `__gcov_dump()` before both `_exit()` calls (`mc_exit()` and the
  `SIGUSR1` handler).

To verify, run an `mcparallel()` job in the instrumented R, then `SIGKILL`
the parent: `eval.gcda` still changes. The same gap affects `make check`
training, but only a few tests fork.

**Training.** Stage 1 was trained on `make check`, then on
`comprehensive_tests.R 1 1 <type> FixediBCRD NA boston NA 1` for all six
response types in parallel. That took 2:14 instrumented, with `count` the
slowest, and left 794 gcda files (784 with `make check` alone). The dataset
and design were chosen to differ from the evaluation workload. Stage 2 used
Option B's flags plus `-Wl,--emit-relocs`. `make check` passed, and
`libR.so` came out at 6.7 MB vs 7.1 MB, since more code was marked cold.

**Evaluation.** Option B (`make check`-trained) vs `EDI`-trained, in ABBA
order. Drift was small this time: about 1% between same-binary runs.

| Workload | `EDI`-trained ÷ `make check`-trained |
| --- | --- |
| Survival / `pte_example` / Bernoulli: sum of per-call times | 0.995 (95% bootstrap CI over calls 0.989–1.002) |
| Survival: median per-call ratio (calls > 50 ms) | 1.007 |
| Survival: wall clock | 23:52 vs 23:58 (mean of two runs each) |
| `designs` section of `benchmark_model_fits.R`, per case | 0.94–1.05, no consistent direction |

All 2,312 survival calls returned identical results.

**Conclusion.** Within ±1% there's no difference, so keep Option B as
documented. `make check` already exercises the interpreter, GC and
allocation paths that dominate `libR.so` time in `EDI` workloads. The rest
of `EDI`'s time is in its own C++ kernels and in fork/page-fault system time
(~30%), neither of which an R-side profile reaches. This also points to
section 5 (PGO for `EDI.so`) and section 3 (system time) as the remaining
levers, rather than further work on R itself.

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
`perf2bolt`, then run `llvm-bolt`. The exact command that was tried, including
the required `-lite=0`, is in the result below.

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

### Result (2026-10-14): no measurable gain on the survival workload

**Setup.** The PGO build from R_OPTIMIZATION.md Option B (r90668, linked
with `-Wl,--emit-relocs`) was profiled during `make check` with
`perf record -e cycles:u -j any,u -F 4999` (3.5 min, 368 MB). The profile was
converted with `perf2bolt-21` and the library optimized with:

```bash
llvm-bolt-21 libR.so -o libR.bolt.so -data=libR.fdata -lite=0 \
  -reorder-blocks=ext-tsp -reorder-functions=cdsort -split-functions \
  -split-all-cold -split-eh -dyno-stats -icf=1 -use-gnu-stack
```

**`-lite=0` is required.** In BOLT's default lite mode, functions without
profile samples are left in place. Every moved function's original entry
points must then be patched with jumps, and 50 functions fail that patching
and are skipped. Those include `bcEval_loop` (the bytecode interpreter,
whose threaded-code labels are entry points packed too closely to patch) and
`R_gc_internal`. With `-lite=0`, no patching is needed, and `bcEval_loop`,
`Rf_eval` and `R_gc_internal` all move into the hot-text region. BOLT's
static estimate is 27.5% fewer taken branches. `perf2bolt` reported 10.7% of
traces as mismatching the binary even though the binary was identical, which
is probably LBR imprecision under WSL2.

**Measurement.** Two R copies were identical except for `lib/libR.so`. Each
ran the survival-only workload from section 1, in the order PGO → BOLT →
PGO → BOLT:

| Run | Wall | User s | Sum of per-call `duration_time_sec` |
| --- | --- | --- | --- |
| pgo1 | 25:38 | 1149 | 1501.5 |
| bolt1 | 25:52 | 1163 | 1511.3 |
| pgo2 | 28:21 | 1296 | 1661.2 |
| bolt2 | 27:27 | 1216 | 1606.7 |

All 2,312 calls returned identical `result_1`, `result_2` and `status` in
every run.

**Drift swamps the effect.** The same PGO binary was 11% slower in pgo2 than
in pgo1. The load average reached ~2.7 during pgo2, so something else was
running. Pairing adjacent runs gives BOLT +0.5% (bolt1 vs pgo1) and −3.4%
(bolt2 vs pgo2). Pooled, the median per-call ratio is 0.984 for calls over
50 ms. Because the runs got slower over time and ABAB order puts BOLT later
on average, that pooled figure is biased slightly against BOLT.

**Conclusion.** On this workload BOLT is worth at most a few percent, which
is below what this machine can resolve. That is not enough to justify the
upkeep: re-profiling and re-BOLTing after every R rebuild, keeping
`--emit-relocs`, and depending on `-lite=0` behavior. Survival time is
dominated by `EDI`'s C++ kernels and fork/system time (~30%), not by
`libR.so` code layout, so this is consistent with section 3 being the bigger
lever. To settle it, rerun with ABBA order on a verified-idle machine,
ideally native Linux, or try an interpreter-heavy workload (the R6-heavy
`designs` section of `benchmark_model_fits.R`), where layout matters more.

## Suggested order

1. ~~Section 1~~ (allocator): tried 2026-10-14, no gain over glibc + huge
   pages. Section 2 (GC): large heaps are harmful with forking (section 3);
   small-step tuning is untested.
2. Section 3: done. THP-malloc adopted. The in-process `safe_call()`
   prototype saves about a third of test time with identical results; it
   needs a watchdog or resume path before adoption. A native-Linux
   comparison is still open.
3. ~~Section 4~~ and ~~section 6~~: tried 2026-10-14, no measurable gain
   (see their result subsections).
4. Section 5: a larger engineering effort, only if the earlier results point
   to compiled-code hot paths as the remaining bottleneck.
