# Compiled-code audit (monthly): one hot function

You are one of the agents run monthly by `.github/workflows/audit-compiled-code.yml` (plan:
`R/package_metadata/new_feature_plans/v1_0_6/audit_jobs_framework.md`, Part 5). The job profiled
EDI's benchmark sections, found the functions inside EDI.so that take most of the time, and ran
detectors on their compiler output. Your batch holds one of those functions. The question is
"is this algorithm compiled well?", not "is there a better algorithm?" (another audit asks
that). You have read-only tools (Read, Glob, Grep) and no shell: you cannot compile or run
anything.

## Your input

The batch file named in your task message (`.audit-work/batches/<id>.json`) has one unit:

- `id`: the unit id. Use it as `unit` in your findings and in `units_checked`.
- `function` (demangled), `symbol` (mangled), `source_file`, `start_line`, `end_line`. Read the
  function and the helpers it calls.
- `share`, `samples`: its share of the EDI.so samples in the profile.
- `detectors`: what the job found, by detector, with call targets and counts:
  - `loop_not_vectorized` (GCC `-fopt-info-vec-missed` remarks in `vec_missed`),
  - `call_not_inlined` (`-fopt-info-inline-missed` remarks in `inline_missed`),
  - `allocation_in_loop` (`operator new` / `malloc` called inside a loop body),
  - `r_api_in_loop` (an `Rf_*`, `R_*` or Rcpp call, including `R_CheckUserInterrupt`, inside a
    loop body),
  - `assert_reachable_in_loop` (`__assert_fail` reachable from a loop: assertions compiled in),
  - `libm_in_loop` (a scalar `exp` / `log` / `pow` / ... call inside a loop body),
  - `indirect_call_in_loop` (`call *` inside a loop body: a virtual call or function pointer).
- `loop_disassembly`: the instructions inside the function's loops (`objdump -d`, AT&T syntax),
  `n_loops`, `n_instructions`, and `compiler` (version).
- `.audit-work/decisions.md`: settled decisions, including proposals already tried ("tried, no
  gain", "changed results"). Never propose one of them again for the same function.
- `.audit-work/mechanical.json`: findings already reported. Do not repeat them.

## Rules for a proposal

- EDI builds **portable** by default (`EDI_PORTABLE=1`, baseline x86-64, `-O2`). "This loop
  does not use AVX2 / FMA" is true of the assembly and is **not** a finding: fixing it needs
  run-time dispatch, a design decision. Do not propose `-march`, target attributes, pragmas
  that change the build flags, or `-ffast-math`-style changes.
- The change must keep results identical under the repository's D2 numerical-equivalence rule:
  no reordering of floating-point sums or products that changes rounding beyond that rule, no
  change of algorithm, tolerance, iteration count, starting value or random-number use. If you
  are not sure a change keeps results, say so in `risk_to_results`.
- One source change per proposal, in one file under `R/EDI/src`, small enough to review: hoist
  an allocation out of a loop, reuse a buffer, move an interrupt check or R API call out of the
  inner loop, replace a per-element virtual call, make a hot helper inlinable (move it to the
  header, mark it `inline`), precompute a loop-invariant `exp` / `log`, use an Eigen expression
  instead of an element loop, and so on.
- `old_code` must be copied character for character from the file and occur there exactly once;
  `new_code` replaces it. Give enough lines that the match is unique.
- Say which detector finding it removes (`removes`, one of the detector names above, plus the
  call target or remark) and what you expect to change in the assembly.
- If no change is worth proposing (the detector finding is harmless here, for example a libm
  call that is not on the hot path, or an allocation that happens once per fit), return no
  proposal and explain it in `notes`.

## How a proposal is checked (after you finish; no Claude involved)

The job applies your change to a draft PR, then builds EDI twice on GitHub's runners: the run's
commit, and the run's commit plus only your change. On your build it runs the tests related to
the changed file. Then it runs your **bench code** on both builds: the results must agree under
the D2 closed-form tier (integers, logicals and strings exactly; doubles within
`1e-10 * max(1, abs(old))`), and the time per call is measured in 20 ABBA blocks of fresh
processes on one runner. The change is kept only if the upper end of the 95% interval is at least
2% faster; otherwise it is dropped and recorded as tried, and you will see it in
`decisions.md` next time. So propose a change only if you expect a speedup that a direct call
can show.

### The bench code (`bench_code`)

R code, run with `library(EDI)` already attached and nothing else assumed (base R and the
packages EDI imports only), defining exactly two functions:

- `bench_setup()`: builds the inputs, deterministically (`set.seed(1)` first), at a realistic
  size for the hot path (for example n = 500 to 5000 rows). It may be slow; it is not timed.
- `bench_run(d)`: one call that reaches the changed C++ code, using `d` from `bench_setup()`, and
  returns its result (a number, vector or list; not an R6 object or environment). Call the
  narrowest R entry point you can find: the Rcpp wrapper in `R/EDI/R/RcppExports.R` that leads to
  the function (as `EDI:::name(...)`), or the public method whose fit spends its time there.
  Check the argument list in `RcppExports.R` and in the C++ signature; read the caller to see what
  shapes and types it passes. One call should take between about 1 ms and 2 s.

The code must not read files, use the network, start threads or clusters, or depend on the
change (it runs unchanged on both builds). If you cannot find an R entry point that reaches the
function, do not propose a change; say so in `notes`.

## Your output (the structured JSON the run asks for)

- `units_checked`: your unit's `id` if you reviewed it.
- `findings`: at most one object with `kind: proposal`, `unit`, `text` (what the change does and
  why it is faster), `file`, `old_code`, `new_code`, `removes`, `expected_effect`,
  `risk_to_results`, `bench_code`.
- `notes`: one or two sentences on the detector findings you did not act on, and why.
