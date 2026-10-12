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
>   directly.
>   but is still unchecked; verify and tick it there.
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

| level | covers | promise |
|---|---|---|
| exact | random draws: design allocations, permutation, bootstrap and Bayesian-bootstrap index/weight draws | identical for the same seed and EDI version on every supported platform, at every thread count and worker count |
| tolerance | estimates, SEs, CIs, p-values | equal within a documented relative tolerance across platforms. Bit-identical floats would require identical libm, BLAS and CPU instruction sets, which no major R package promises |
| none, but announced | seed-pinned draws across EDI versions | may change; every release that changes them says so in NEWS |

**Open owner decision D1 (not a TODO):** source installs from GitHub
compile with `-march=native` by default (`R/EDI/configure:28-42`,
`EDI_PORTABLE` unset → 0). CRAN tarballs (patched by
`scripts/submission_tar_build_and_win_mac_check.sh`) and r-universe builds
are portable. Native builds change floating-point last bits, so "tolerance"
is the right promise for them. Making portable the default everywhere, with
native opt-in, would make agent and user source installs match. The cost is
speed for people who build from source.

## TODOs

Every TODO lists the tests it **must** ship with. A TODO is not done until
its tests are in `R/EDI/tests/testthat/`, or in `R/package_tests/` where
noted, and pass on all CI platform legs.

- [ ] TODO-1: **State the guarantee and record what ran.**
  - Rewrite `R/EDI/vignettes/reproducibility.Rmd` around the three levels
    above and the tolerance value. Its current thread-count claims are
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
    `R/EDI/src/`.
  - **Required tests:**
    - registry-driven invariance tests: for every design class, and for
      every inference class's randomization, bootstrap and Bayesian-bootstrap
      p-value and CI, the same seed gives identical results at
      `set_num_cores(1, 2, 4)`, under both the fork and `mirai` backends;
    - a test that the static check fails on a planted violation.
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
    exactly.
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

## Not in scope

- Bit-identical floating-point output across platforms (see the guarantee table).
- Reproducibility across R's non-default `RNGkind`s for C++ draws.
  `edi_rng::RRng` ports only Mersenne-Twister and Inversion. A
  non-default kind still seeds `RRng` deterministically (through one
  `unif_rand()`), but the draws no longer match a pure-R reference. TODO-1's
  record makes that visible.
