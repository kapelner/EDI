# Cross-platform reproducibility: a stated, tested guarantee

Date: 2026-10-11
Status: planned. Release index: `../future_release_plans/release_v1_1_0.md → TODO-48`
(added 2026-10-11, user decision).
Origin: `marketing_plans/agent_proofing.md` W6 (repo-root `marketing_plans/`, gitignored).

> **Depends on:**
> - `../future_release_plans/release_v1_0_5.md → TODO-91`: portable
>   Fisher–Yates instead of `std::shuffle`. Appears implemented in the tree:
>   `RNG.h:339-349` supplies the shared helper, and the two legacy
>   rerandomization helpers perform the same bounded-`RRng` Fisher–Yates loop
>   directly. v1.0.5 TODO-91 was closed 2026-10-20 after R-CMD-check run
>   39110868823 confirmed the committed digests and RNG golden across its
>   eight platform legs; the broader every-class fixture requested below
>   remains part of this v1.1.0 plan.
> - `release_v1_0_5.md → TODO-93`: per-replicate seeds drawn without replacement.
> - `release_v1_0_5.md → TODO-95`: thread-count-dependent design draws,
>   `../bug_fix_plans/design_draws_depend_on_thread_count.md`.
> - `algorithm_choice_audit.md → TODO-38`: algorithm provenance on fitted
>   objects. TODO-1 below shares its storage slot; design the two together.

## Why

An agent in a Linux container and a user on macOS or Windows must get the
same allocation from the same seed. Otherwise every comparison between them
looks like a bug in EDI or in the agent's code (`agent_proofing.md` W6). A
trial audit needs the same thing: an allocation recorded today must be
regenerable later on any machine.

Today the guarantee is partly met and partly unstated:
- **Met:** draws use `edi_rng::RRng`, a port of R's Mersenne-Twister, and a
  portable Fisher–Yates shuffle.
- **Not met:** four OpenMP design kernels depend on the thread count (v1.0.5
  TODO-95).
- **Unchecked:** p-value counting has no tie tolerance.
- **Not enforced:** nothing in CI compares outputs across platforms.

## The guarantee (what to promise, and what not to)

Revised 2026-10-15 (owner decision D3, below): the former single "exact"
level is split, and same-binary determinism is added.

| level | covers | promise |
|---|---|---|
| exact everywhere | draws that use only the RNG: complete randomization, Bernoulli, blocked and permuted-block designs, biased-coin designs, permutation, bootstrap and Bayesian-bootstrap index/weight draws | identical for the same seed and EDI version on every supported platform, at every thread count and worker count |
| exact on one build | every output, floats included | the same installed binary gives identical results across runs and across thread and worker counts |
| exact except near-ties | allocations chosen by comparing floating-point objectives: greedy, D-optimal, pair-switching, optimal/annealing designs, rerandomization acceptance | identical across platforms except where two candidates' objectives (or an objective and its threshold) tie within the documented tolerance; such cases are rare and documented |
| tolerance | estimates, SEs, CIs, p-values across platforms | equal within `REPRO_FLOAT_TOL` (set by TODO-4's first CI run). Bit-identical floats would require identical libm, BLAS, FMA contraction and CPU instruction sets, which no major numerical platform promises |
| announced | seed-pinned draws across EDI versions | may change; every release that changes them says so in NEWS (and, if D4 adopts it, `draw_version` reproduces earlier releases' draws) |

**Owner decision D1 (decided and implemented 2026-10-14): portable by default
everywhere.**
- `R/EDI/configure` defaults `EDI_PORTABLE` to 1 for every install: GitHub
  source, CRAN, r-universe and CI. The tracked `src/Makevars` and
  `src/Makevars.win` are portable. The submission script now only verifies
  this default instead of patching it.
- The tuned build is opt-in: users who want speed compile it themselves with
  `EDI_PORTABLE=0` and optimized libraries. These changes are recorded in the
  README (one sentence under Installing, plus the Tuning Local Builds table),
  in NEWS (Breaking changes), and in the benchmark scripts' native modes,
  which now set `EDI_PORTABLE=0` explicitly.
- The guarantee's float "tolerance" level still covers opt-in native builds,
  which CI's `native` leg measures.

**Owner decision D3 (decided 2026-10-15): where bit-for-bit is required.**
It is required only where it is achievable and catches real bugs, which is
what comparable platforms do: Stan, PyTorch and MKL's CNR mode promise
exactness only on a fixed environment; NumPy and R promise stable integer
RNG streams but not floats; climate models gate on bit-for-bit for one
machine and compiler and use statistical tests across machines.
- **Random-number-only draws are exact everywhere.** They are integers
  produced by `edi_rng::RRng` and compared against exact constants, so no
  floating-point difference can reach them.
- **One binary is deterministic.** Checked 2026-10-15: the only OpenMP
  reductions in `R/EDI/src/` are `omp simd` reductions inside one thread
  (`pair_dist_helpers.cpp:78`, `ols_distr_parallel.cpp:65`,
  `simple_mean_diff_parallel.cpp:39`), whose order is fixed by the binary;
  there are no `parallel for` reductions, atomics or critical sections, and
  `omp_get_thread_num()` is used only for interrupt checks. With per-index
  seeding (v1.0.5 TODO-95) the whole package can therefore be bit-identical
  across thread counts on one build. TODO-2's static check keeps it that way.
- **Optimizer-chosen allocations are not promised exact across
  platforms.** A near-tie between two swaps, or a rerandomization criterion
  landing on its threshold, can resolve differently under a different libm
  or FMA contraction. TODO-4's digests treat them separately, and TODO-6
  decides whether to make those comparisons tie-tolerant.
- **The stored allocation is the record of truth**, as in clinical trial
  randomization systems. Regenerating from a seed is a check, not the audit
  trail; TODO-1's vignette says so.

## Release-to-release equivalence (the 1.x default rule)

**Owner decision D2 (decided 2026-10-15): numerical equivalence replaces
bit-for-bit.** The 1.x releases used to require that every default
"reproduce the prior release bit-for-bit". That rule is replaced by the
tiered rule below, and every release plan's standing constraints point here
instead of restating it. The reasons:
- No build ever met it. A different compiler, BLAS, flags or CPU changes the
  last bits of the same source. The D1 switch to portable builds already
  changed every GitHub install's floats.
- The tests never enforced it. About 6,700 of the roughly 9,600 equality
  assertions are `expect_equal` (default tolerance ~1.5e-8), and the explicit
  tolerances in use are mostly 1e-12, 1e-10 and 1e-8.
- It contradicted the cross-platform guarantee above, which already promises
  exact integers and tolerance-equal floats.
- Its exception lists grew with every accuracy or speed improvement
  (`release_v1_1_0.md → TODO-50`, `release_v1_2_0.md → TODO-22/23`,
  libmvec, adaptive quadrature).

A change to a default **preserves results** when every output meets its row
below, compared with that output on the same platform:

| output | requirement |
|---|---|
| integers and discrete choices: design allocations, resampling indices and weights' draws, selected covariates or strata, convergence and fallback flags, error/warning conditions | exact |
| closed-form floats: mean differences, OLS/WLS coefficients, closed-form SEs, CIs and p-values | `abs(new - old) <= 1e-10 * max(1, abs(old))` |
| floats from an iterative solver: MLEs, their SEs, CI bounds found by root-finding or bisection | within 10× the solver's own convergence tolerance, on the same relative scale; the tolerance used is the one the class documents |
| Monte Carlo p-values and CIs (randomization, bootstrap, Bayesian bootstrap) | the same, except changes accounted for by near-tied replicates: a p-value may move by at most (number of replicates with `abs(t_b - t_obs) <= 1e-10 * max(1, abs(t_obs))`)/r, and CI bounds only through those same replicates |

- **Fixed reference points.** Equivalence is checked against golden
  fixtures from the **last release**, not the previous commit, so many small
  changes within tolerance cannot add up to drift (TODO-5 below).
- **Anything else is a documented default change**, with a NEWS entry and,
  for a correctness fix, a test showing the old value was wrong. That
  includes every change to seed-pinned draws and every accuracy fix that
  moves results beyond the table.
- **Stricter gates stay available.** A TODO may still require exact
  equality where it is cheap and diagnostic, e.g. presorting or hoisting that
  is bit-identical by construction, or a kernel whose parity test with its R
  reference is exact today. Those TODOs say so explicitly; the release rule
  does not demand it.
- **Cross-platform vs cross-release.** The cross-platform "tolerance" level
  (CI's `REPRO_FLOAT_TOL`, 1e-8 until TODO-4's first run sets it) compares
  different machines and is looser. The table above compares the same
  machine across versions and is tighter.

## TODOs

Every TODO lists the tests it **must** ship with. A TODO is not done until
its tests are in `R/EDI/tests/testthat/`, or in `R/package_tests/` where
noted, and pass on all CI platform legs.

- [ ] TODO-1: **State the guarantee and record what ran.**
  - Rewrite `R/EDI/vignettes/reproducibility.Rmd` around the five levels
    above and the tolerance value, and recommend saving the allocation
    itself (not only the seed) as the trial record. Its current thread-count claims are
    corrected by v1.0.5 TODO-95.
  - Attach a reproducibility record to every design draw and inference
    result: seed, `RNGkind()`, EDI version, OpenMP thread count, R worker
    count, and the build's portable/native flag (already exposed by
    `build_info.cpp`, `env_edi_portable`). Use the same slot as audit
    TODO-38's algorithm provenance.
  - **Required tests:** a registry-wide test that every design class and
    every inference class's results carry the record with the correct values
    (thread count after `set_num_cores(2)`, a non-default `RNGkind`, and so
    on). A test that two runs with different records but the same seed give
    identical draws.
- [ ] TODO-2: **Thread- and worker-count independence as a package-wide
  invariant.** v1.0.5 TODO-95 fixes the four known design kernels; this
  makes the property hold everywhere and keeps it from regressing.
  - Use `edi_rng::seed_for_index(master, i)` (introduced by TODO-95) as
    the only way parallel code derives a random stream.
  - Audit the remaining parallel sources of randomness:
    - OpenMP inference kernels;
    - fork-cluster and `mirai` resampling (per-replicate seeds, so
      worker-count invariance is expected; confirm it);
    - `SimulationFramework` parallel runs.
  - Remove the unused `#include <random>` in `spbr_speedups.cpp`,
    `fast_shuffle.cpp`, `design_fixed_greedy.cpp`, `rerandomization_helpers.cpp`,
    `design_optimal_annealing_search.cpp` and `random_block_size_speedups.cpp`.
  - Add a pre-push static check that bans `std::shuffle`,
    `std::random_shuffle`, `<random>` engines and distributions,
    `std::random_device`, `rand()`, and per-thread-indexed seeding in
    `R/EDI/src/`. Also ban, unless allowlisted with a reason, OpenMP
    `parallel for ... reduction(` on floating-point variables, `omp atomic`
    and `omp critical` on floating-point accumulators, and per-thread
    partial sums combined in thread order: each makes floats depend on the
    thread count and breaks the "exact on one build" level (D3). `omp simd`
    reductions are allowed.
  - Combine R-level worker results (fork and `mirai`) in replicate order,
    never completion order.
  - **Required tests:**
    - registry-driven invariance tests: for every design class, and for
      every inference class's randomization, bootstrap and Bayesian-bootstrap
      p-value and CI, the same seed gives identical results at
      `set_num_cores(1, 2, 4)`, under both the fork and `mirai` backends;
    - same-binary determinism (D3): for every inference class at its
      defaults, two runs with the same seed, and runs at 1 and 4 threads,
      give `identical()` estimates, SEs, CIs and p-values, not merely
      tolerance-equal ones;
    - a test that the static check fails on each planted violation,
      including a floating-point `parallel for` reduction.
- [ ] TODO-3: **Tie tolerance in randomization p-value counting.**
  Verify first, then fix.
  - `inference_all_abstract_rand.R:334,712` counts `t0s >= t` and
    `t0s <= t` with no tolerance, and the C++ counters must be checked too.
    For discrete statistics (binary outcomes, small n, symmetric designs, the
    observed allocation reappearing among redraws), a null draw equal to the
    observed statistic in exact arithmetic can fall on either side through
    rounding. In particular, the observed statistic and the null draws may
    come from different code paths. That would make p-values
    platform-dependent and slightly anti-conservative.
  - If confirmed, compare with a relative tolerance
    (`t0s >= t - tol * max(1, abs(t))`, as `coin` does). Choose `tol` once,
    package-wide, and document it.
  - This changes results only where a tie was being resolved by rounding;
    record it as a documented default change.
  - **Required tests:**
    - exact-enumeration fixtures with known ties (n ≤ 12, binary outcome),
      where the tolerant p-value equals the enumerated p exactly;
    - a perturbation test: computing the statistic with a different
      summation order leaves the p-value unchanged;
    - a test that the R and C++ counting paths agree on tied fixtures.
- [ ] TODO-4: **Enforce it in CI across platforms.**
  - **Golden digests:** a committed fixture file with seed-pinned digests of
    integer outputs, generated by one script, at 1 and 4 threads. It covers
    allocations for every design class, plus permutation, bootstrap and
    Bayesian-bootstrap index draws.
  - **Floats:** estimates, CIs and p-values for one representative class per
    response type, checked within the TODO-1 tolerance.
  - Run it on every CI platform leg (Linux, macOS, Windows), with portable
    and native builds where the leg allows. Integer digests must match
    exactly, split by the D3 levels:
    - RNG-only draws must match on every leg, with no exceptions;
    - optimizer-chosen allocations (greedy, D-optimal, pair-switching,
      optimal/annealing, rerandomization) carry a fixture column marking
      them. On a cross-platform mismatch the test re-runs the case with
      objective-gap logging, and passes only if the differing step was a
      near-tie within the documented tolerance; it reports every such case
      in the job summary. Until TODO-6 lands, any such mismatch is listed in
      the job summary rather than silently passing.
    - Within one leg, the same-binary level applies: digests at 1 and 4
      threads match exactly for every class, optimizer-chosen ones
      included.
  - Regenerating the fixture is a deliberate act: the script refuses to
    overwrite without a flag, and any change needs a NEWS line.
  - **How this tests other platforms from a Linux workstation.** The
    committed fixture is what connects the platforms: it is generated once
    on Linux, and every other platform runs a test that compares its own
    output against that file. Nobody needs a Mac or Windows machine locally.
    - **CI legs that already exist.** `R-CMD-check.yaml` already runs
      `macos-latest` (arm64, clang, Accelerate/reference BLAS),
      `windows-latest` release and devel (Rtools gcc/UCRT), and Ubuntu
      devel/release/oldrel-1. A test in `R/EDI/tests/testthat/` runs on all
      six legs automatically, with no new workflow.
    - **A cross-leg diff job.** Each leg uploads its computed digests and
      float values as an artifact. A final job collects them into one
      platform × class table and fails on any integer mismatch or any float
      outside tolerance. This catches the case the fixture alone cannot: two
      non-Linux platforms that agree with each other but not with a stale
      fixture. The table also tells you the observed float spread, which is
      what the TODO-1 tolerance should be based on.
    - **Free platforms beyond CI.** The digest test is cheap, so it should
      not use `skip_on_cran()`. It then runs on CRAN's check flavours
      (Fedora clang, Debian gcc, macOS arm64 and x86_64, Windows) and on
      r-universe's builds, including webR (WebAssembly), on every release.
      The CRAN check-results page becomes a cross-platform report. Keep its
      runtime to a few seconds.
    - **Local variation on Linux.** Most of the variation that matters is
      in the build and the libraries, not the OS, so a lot can be tested
      locally:
      - gcc vs clang (both are installed);
      - `EDI_PORTABLE=1` vs `-march=native`;
      - BLAS: the workstation R uses MKL (`La_library()`); OpenBLAS and
        reference BLAS are also installed, and Docker `rocker/r-ver`
        images give a clean reference-BLAS R;
      - optionally, aarch64 through Docker with QEMU emulation (slow;
        CI's macOS arm64 leg already covers ARM).
      These are full builds of `R/EDI`, so under `CLAUDE.md` they are run by
      the owner or in CI, never by an agent without being asked in that turn.
    - **Windows on this machine.** The workstation is WSL2 with Windows R
      4.5.0 at `C:\Program Files\R\R-4.5.0` (EDI not installed there). A
      Windows-side install would allow local Windows checks. That is
      optional, since the `windows-latest` legs cover it, and it is the
      owner's build to run.
    - **CI changes (audited 2026-10-13; wired the same day, not yet run in
      CI, uncommitted).**
      - [x] Digest test: `R/EDI/tests/testthat/test-cross-platform-reproducibility-digests.R`.
        - Covers 6 design classes, at 1, 2 and 4 threads (2 at most on
          CRAN), plus 4 floats from `InferenceAllSimpleAverageDiff`.
        - Checks thread invariance within the run, and checks against
          `fixtures/cross_platform_digests.csv` when that file exists.
        - Writes per-leg rows when `EDI_REPRO_DIGEST_DIR` is set. Runs in
          ~2.5 s, not `skip_on_cran()`.
        - **Fixture not yet generated:** run the file with
          `EDI_REPRO_WRITE_FIXTURE=true` once v1.0.5 TODO-95 is merged and
          built. Until then the fixture check skips.
      - [x] Per-leg artifact upload, plus the `repro-compare` job
        (`needs: R-CMD-check`, `!cancelled()`). It runs
        `.github/scripts/compare_repro_digests.R`, which fails on any digest
        mismatch, on any float spread above `REPRO_FLOAT_TOL` (provisional
        1e-8), or when fewer than `REPRO_EXPECTED_LEGS` (8) legs report. It
        writes a leg × class table to the job summary. Verified locally on
        matching and perturbed inputs.
      - [x] The `paths:` filter now includes `R/EDI/tests/**` and the
        compare script.
      - [x] Thread counts: the digest test records
        `get_omp_max_threads_cpp()` before each draw. The compare job lists
        legs that got fewer threads than requested.
        - `OMP_NUM_THREADS=1` should not cap `set_num_cores(k)`, because
          `set_package_threads()` calls `omp_set_num_threads()`. It does,
          however, set `OMP_THREAD_LIMIT` (`R/globals.R:1644`), so a session
          whose OpenMP runtime starts after a call with k = 1 may be capped.
          The probe is what reveals that.
        - Note: `binary_match_search.cpp:35` resets the global OpenMP thread
          count from its own argument, so the probe is read before each draw,
          not after.
      - [x] macOS OpenMP leg (`variant: 'openmp'`): Homebrew `libomp` added
        through `CPPFLAGS`/`LDFLAGS` in `~/.R/Makevars`, following
        mac.r-project.org/openmp. It sets `EDI_EXPECT_OPENMP=true`, so the
        digest test fails if the build still runs single-threaded.
      - [x] Workers: `test-aa-fork-worker-count-invariance.R`, Linux only and
        exempt from `EDI_PREPUSH_NO_PARALLEL`.
        - Bootstrap CIs for `InferenceAllSimpleAverageDiff` and
          `InferenceContinOLS` are identical at 1, 2 and 3 fork workers
          (verified locally, ~6 s).
        - The test asserts that `par_lapply()` really received n_cores > 1.
        - Randomization p-values for these classes run in a C++ kernel and
          never use R workers, so they are covered by the thread digests.
        - The mirai backend is still covered only by the sanitizer and
          valgrind jobs.
      - [x] Native leg (`variant: 'native'`, `EDI_PORTABLE=0`) with
        `error-on: "error"`, because `-march=native` is always an `--as-cran`
        WARNING.
      - [ ] Run it in CI and read the first job summary. Set the TODO-1 float
        tolerance from the observed spread.
      - [ ] Extend the digest cases to every `seed_reproducible_draw` class in
        the registry, and add the meta-test listed below. (2026-10-15: 11 of
        the registry's design classes are covered, including every class
        whose draws moved to the portable shuffle for v1.0.5 TODO-91;
        sequential designs digest both their one-at-a-time assignment and
        their redraws, and the compare script keys by design and quantity.)
    - **Required test for the harness itself:** a deliberately perturbed
      fixture row makes the digest test fail, and a perturbed artifact makes
      the cross-leg diff job fail. Run both once when the harness is added,
      to show it can actually fail.
  - **Required tests:**
    - the digest test itself;
    - a meta-test that the fixture has a row for every class in the design
      registry and every resampling method in the inference registry, so a
      new class fails CI until it is added;
    - a test that the regeneration script refuses to overwrite silently.
- [ ] TODO-5 (added 2026-10-15, user decision D2): **Release-equivalence
  golden fixtures.**
  - At each release tag, one script records the outputs that the D2 table
    covers for a fixed set of cases: every class in the design and inference
    registries, at their defaults, on small seeded datasets. The record
    holds integer digests (shared with TODO-4's fixture) plus the float
    values, their tier, and, for iterative fits, the solver tolerance.
  - The fixture is committed under `R/package_tests/` and replaced only by
    the release script, never by hand.
  - A test compares the working tree against the last release's fixture
    using the D2 tiers, and reports each failure with its tier and the size
    of the difference, so a documented default change can name the rows it
    moves.
  - **Required tests:**
    - the comparison test itself;
    - a perturbed fixture row in each tier makes it fail, and a perturbation
      inside the tier's tolerance does not;
    - the same registry-coverage meta-test as TODO-4.
- [ ] TODO-6 (added 2026-10-15, user decision D3): **Near-ties in
  optimizer-chosen allocations.** Verify first, then decide.
  - Measure: over the TODO-4 digest cases and a seeded sweep (~1,000 draws
    per optimizer design class), log the gap between the chosen candidate
    and the runner-up at every step (best swap, accept/reject against a
    rerandomization threshold). Report how often the gap is under 1e-12
    relative, i.e. close enough for libm or FMA differences to flip it.
  - If such near-ties occur at a non-negligible rate, make the comparison
    tie-tolerant with a deterministic tie-break: candidates within
    `tol * max(1, abs(best))` count as tied and the lowest index wins;
    a rerandomization criterion within `tol` of its threshold is accepted.
    Choose `tol` once, package-wide, alongside TODO-3's p-value `tol`.
    This changes seed-pinned draws once, as a documented default change
    (bundle it with v1.0.5 TODO-91/95's draw change if both land in the
    same release).
  - If they essentially never occur, record the measurement here and leave
    the comparisons exact; TODO-4's near-tie reporting stays as the
    safety net.
  - **Required tests:**
    - a constructed fixture with two exactly tied swaps (symmetric
      covariates) where perturbing one objective by 1 ulp leaves the
      allocation unchanged under the tolerant comparison;
    - a rerandomization fixture whose criterion equals the threshold to
      within 1 ulp, with the same property;
    - the same-binary digests from TODO-2 still pass.
- [ ] TODO-7 (added 2026-10-15): **Owner decision D4: `draw_version`, so
  earlier releases' draws can be reproduced.** Decision-gated; nothing is
  built until the owner accepts it.
  - Precedent: R's `RNGversion()` / `sample.kind = "Rounding"` reproduces
    pre-3.6.0 `sample()` draws; NumPy freezes the legacy `RandomState`
    stream.
  - Proposal: `set_draw_version("1.0.4")` (package option, default the
    current version) routes each design and resampling kernel whose draws
    changed to the earlier algorithm. Keep a version only for draw changes
    that shipped in a release (the first candidates are v1.0.5 TODO-91 and
    TODO-95, and TODO-6 above if it lands). Each kept old path costs a
    maintained, tested code path, so the decision should weigh how many
    trial users need regeneration rather than a stored allocation (D3).
  - **Required tests (if adopted):** for each kept version, golden digests
    from that release are reproduced exactly under `set_draw_version()`;
    the TODO-1 record includes the draw version; an unknown version errors.

## Not in scope

- Bit-identical floating-point output across platforms (see the guarantee table).
- Reproducibility across R's non-default `RNGkind`s for C++ draws.
  `edi_rng::RRng` ports only Mersenne-Twister and Inversion. A
  non-default kind still seeds `RRng` deterministically (through one
  `unif_rand()`), but the draws no longer match a pure-R reference. TODO-1's
  record makes that visible.
