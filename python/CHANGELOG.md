# Changelog

All notable changes to `edi_kernels` are documented here. The version
number tracks `R/EDI/DESCRIPTION`'s `Version` field (see
`R/package_metadata/finished_features/python_bindings_package_spec.md`'s
"Versioning" checklist item) — a `.postN` suffix is used for
Python-packaging-only changes that don't touch `R/EDI/src/*.cpp`.

## [1.0.0.post3] - 2026-08-16

Note this one is not packaging-only despite the `.postN` suffix — in
addition to the CI/packaging and documentation fixes below, it touches
`R/EDI/src/fast_weibull_regression.cpp` directly (`R/EDI/DESCRIPTION`'s
`Version` remains `1.0.0`, unbumped). Prepared in anticipation of release;
still gated behind the same project note throughout this file: the R
side's broader `y`/`y_L`/`y_R` interval-censoring survival rework is a
still-evolving, multi-class effort (only Weibull AFT has a migrated fast
C++ kernel so far; `fast_coxph_regression.cpp`, `fast_weibull_frailty.cpp`,
and the KK-combined Clayton-copula/dep-censoring kernels are all still
`(y, dead)`-only, unchanged, confirmed directly) — hold off shipping until
that settles, rather than publish a version whose interval-censoring
support is Weibull-only with no indication of what else is still to come.

### Changed (breaking)

- `fast_weibull_regression(X, y, dead, ...)` is gone. In its place:
  `fast_weibull_regression_general(X, y, y_L, y_R, ...)`, which fits exact
  (`y` finite, `y_L`/`y_R` `NaN`), left-censored (`y_L = 0`),
  right-censored (`y_R = inf`), and interval-censored (`y_L`/`y_R` both
  finite) responses through one kernel — right-censored data (the only
  case the old kernel handled) is the `y_L = y, y_R = inf` special case of
  the same likelihood, verified byte-identical to the old kernel's output
  before this switch (see `R/package_metadata/audits/
  fast_weibull_regression_cpp_deprecation.md`: `0` difference in
  coefficients/vcov/neg-loglik at `n=200/1000/5000`, no measurable
  performance regression at `n>=1000`). This follows
  `interval_censored_survival_response.md`'s TODO-18 through TODO-21: the
  R side gave the general kernel a portable `EDI_CORE_ONLY`-safe core
  (TODO-19), migrated every remaining R call site off the old kernel —
  the KK-combined Clayton-copula/frailty/marginal classes,
  `InferenceSurvivalWeibullRegr`'s own exact/right-censored fast path,
  benchmarks, and tests (TODO-20) — and only then was the legacy kernel
  and its score/Hessian siblings actually deleted, together with this new
  Python binding (TODO-21).
- Verified end-to-end, not just at the signature level: R's full relevant
  test suite (`test-weibull-*.R`, `test-brt-smoothed-weibull-kernel.R`,
  `test-rcpp-fitting-equivalence.R`, `test-rcpp-fitting-real-data.R`) — 8
  of 9 files pass outright; the 9th
  (`test-brt-weibull-kernel-matches-reference.R`) has the same 4 pre-
  existing failures TODO-3 already documented as unrelated to this
  migration (`compute_fast_rand_bootstrap_distr` vs. its own generic
  fallback on an unrelated KK-matched-design path). All 181 Python tests
  pass, including a new `test_fast_weibull_regression_general.py`
  (R-fixture parity + omitted-argument coverage). `README.md`'s and
  `README_PYPI.md`'s Survival examples both call the new function with
  real `y_L`/`y_R` arrays and were re-run against the freshly built
  package, not just read.
- `compute_weibull_rand_bootstrap_parallel_cpp` deliberately still takes
  `(y0, dead)`, not `y_L`/`y_R` — its bootstrap replicates are
  right-censored/exact by construction (the open decision point TODO-20
  flagged), so it does its own local exact/right-censored-bounds
  conversion inline rather than needing general interval-censoring
  support. Not bound in Python (out of scope, R-internal bootstrap
  helper).
- Minor, unrelated staleness noticed while verifying: `src/edi_kernels/
  _core.pyi`'s docstrings (not signatures — those match exactly) lag
  behind the current `bindings_*.cpp` docstring text for several
  functions, `fast_weibull_regression_general`/`fast_weibull_frailty`
  included, confirmed via a fresh `pybind11-stubgen` regeneration. Cosmetic
  only (signatures/types are correct), but a stub regeneration is owed
  before the next release regardless of this migration.

### Internal (no behavior change, build performance only)

- `R/EDI/src`'s unity-build collision audit and fix pass are complete (see
  `R/package_metadata/new_feature_plans/unity_build_collision_audit.md`
  and `release_v1_0_0.md`'s TODO-6) — a handful of duplicated file-scope
  helpers (`bounded_rand`, `DigammaFunctor`, `all_finite_mat`/`_vec`, etc.)
  across ~22 files were hoisted into shared headers or renamed apart, and
  one pre-existing ODR violation (`DigammaFunctor` defined at file scope
  in two files) was fixed regardless of unity. The full 105-file mega
  translation unit now compiles with zero errors. **None of this changes
  any kernel's numerical behavior or Python-visible API** — it only
  removes obstacles to merging `.cpp` files into fewer translation units
  for faster compiles.
- **Not yet wired up on either side** — this audit only proves unity
  builds are *possible*; nothing actually builds unified yet. Remaining,
  not done: (R side) the `configure`-emitted `Makevars` `OBJECTS` switch
  and `EDI_UNITY=0` dev escape hatch; (Python side) flipping CMake's
  native `UNITY_BUILD ON`/`UNITY_BUILD_BATCH_SIZE` in
  `python/CMakeLists.txt` — explicitly sequenced in
  `unity_build_collision_audit.md` as its own commit *after* wheel CI has
  cycled green on the post-audit per-file build, so unity-specific
  breakage stays distinguishable from audit-introduced breakage. Noted
  here in anticipation of that wiring landing: expect a wheel-build CI
  time reduction (source estimates ~6-7x on the R side, `~67 CPU-min` ->
  `~8-12 CPU-min`) with no change to `edi_kernels`' public API, install
  behavior, or numerical output — a CI-minutes win, not a user-facing one.

### Changed

- `.github/workflows/build-wheels.yml`: bumped `pypa/cibuildwheel` from
  `v2.23.4` to `v4.2.0` -- the older tag's composite action pinned
  `actions/setup-python@v5`, which GitHub now runs forcibly under Node 24
  with a deprecation warning on every wheel-build job; `v4.2.0`'s action
  uses `actions/setup-python@v7`, which targets Node 24 natively.
  Confirmed the new version parses `python/pyproject.toml`'s
  `[tool.cibuildwheel]` config identically (same cp39-cp313 x
  linux/macos/windows build matrix, via `cibuildwheel
  --print-build-identifiers`) before adopting it.
- `python/pyproject.toml`'s macOS `before-all` now runs
  `brew untap aws/tap` before `brew install libomp` -- `macos-latest`
  runners ship with this tap pre-installed and untrusted, which made
  Homebrew's tap-trust check print a warning on every `brew install`
  regardless of what was being installed. Untapping it (rather than
  setting `HOMEBREW_NO_REQUIRE_TAP_TRUST=1`, which Homebrew's own message
  says is unsupported and slated for removal) is harmless since nothing
  here uses `aws/tap`.

### Documentation

- Since the initial `1.0.0` release, package documentation has been vastly
  expanded and clarified, not just incrementally patched (`git diff
  py-v1.0.0 HEAD` across the doc-bearing files: +4,256/-84 lines net).
  Concretely: every one of the 8 `python/cpp/bindings_*.cpp` files gained
  full NumPy-style docstrings (`Parameters` sections) for every bound
  function, sourced from the R package's own Roxygen docs where a direct
  match exists and from the C++ implementation directly where it doesn't;
  a brand-new 1,616-line `src/edi_kernels/_core.pyi` type stub (plus a
  `py.typed` PEP 561 marker) was generated from that newly-documented
  module so types and docstrings can't drift apart; a brand-new, from-
  scratch `README_PYPI.md` (627 lines) replaced relying on `README.md`'s
  GitHub-relative links, with a runnable usage example and a benchmarked
  comparison-table entry for every one of the 63 public functions,
  verified end-to-end against the real installed package rather than
  assumed; and `README.md` itself grew by roughly 500 lines over the same
  span. `help(edi_kernels.<function>)` now works standalone, without an
  external doc site, for the first time.
- `python_bindings_package_spec.md` moved from `R/package_metadata/
  new_feature_plans/` to `R/package_metadata/finished_features/` now that
  all 14 of its TODOs are implemented and `1.0.0.post2` has shipped to
  PyPI. Fixed the 4 stale links this broke -- `python/README_PYPI.md`,
  `python/README.md`, this file's own versioning-policy pointer above, and
  a code comment in `.github/workflows/build-wheels.yml` -- all of which
  still pointed at the old `new_feature_plans/` path.

## [1.0.0.post2] - 2026-08-12

Packaging-only release — none of this touches `R/EDI/src/*.cpp`.

### Fixed

- `edi_kernels/__init__.py` only re-exported 1 of the 14 `fast_math`
  utility scalar kernels (`fast_pchisq_upper`) at the public top-level
  namespace — the other 13 (`fast_digamma`, `fast_trigamma`, `fast_lgamma`,
  `fast_lbeta`, `fast_dnbinom_mu`, `fast_qnorm`, `fast_log_pnorm`,
  `fast_log_dnorm`, `fast_erfc`, `pnorm_fast`, `dnorm_fast`, `fast_atan`,
  `fast_log1pexp`) were compiled into `_core` same as always but never
  surfaced through `from edi_kernels import ...`. Found by actually running
  `python/README_PYPI.md`'s own new Utilities example against the real
  published `1.0.0.post1` package rather than assuming it worked.

### Added

- `python/README_PYPI.md`: a full runnable example for every one of the 14
  `fast_math` utility functions (previously only `fast_pchisq_upper` had
  one), plus a dedicated "Utility (math kernel) speed gains" table mirroring
  the model-fitting one. Two model-fitting kernels
  (`fast_clayton_weibull_aft_optim`, `fast_dep_cens_transform_optim`) were
  also found to be completely unlisted in either comparison table despite
  having working examples already — added to "Kernels with no Python
  canonical baseline" (15 -> 17 entries).
- `python/README_PYPI.md`'s Proportion example now also covers
  `gee_pairs_singletons(..., "binomial")` on a `(0, 1)`-valued response —
  this is the exact kernel R's `InferencePropKKGEE` calls (GEE has no
  separate "proportion" family; the binomial working-variance/logit link
  already applies to any response in `[0, 1]`), confirmed by tracing
  `InferencePropKKGEE` -> `gee_family_str()` -> `gee_pairs_singletons_cpp`
  in `R/EDI/R/inference_mixin_kk_gee_shared.R`. Previously only shown with
  a strictly-binary response in the Incidence section.
- All 63 public `edi_kernels` functions audited end-to-end: every one has
  a runnable Usage example, and all 7 Usage code blocks execute cleanly
  against the real installed package.

## [1.0.0.post1] - 2026-08-11

Packaging-only release — none of this touches `R/EDI/src/*.cpp`, per this
file's own `.postN` scheme. (A first `py-v1.0.0.post1` tag push on
2026-08-11 failed at the `sdist` CI job before `publish` ran, so nothing
broken shipped under that version; the BLAS-fallback fix below landed
after that, and this is the tag actually released.) A survival-API
revision is planned for a future release and is not part of this one.

### Fixed

- The published `1.0.0` sdist could not be built from source at all —
  `CMakeLists.txt`'s `EDI_SRC_DIR` pointed at `../R/EDI/src`, which only
  exists as a sibling of `python/` in a live git checkout, not inside an
  extracted sdist tarball. Any install without a matching prebuilt wheel
  (e.g. Python 3.14, musllinux, non-x86/arm64) failed outright. Fixed via
  `pyproject.toml`'s `[tool.scikit-build.sdist.force-include]`, which
  vendors `R/EDI/src` into `vendor/EDI_src` inside the sdist only (never
  onto disk in a live checkout); `CMakeLists.txt` now prefers that
  vendored copy when present and falls back to the live sibling
  otherwise, plus fails configure with a clear message instead of an
  opaque pybind11 error if neither exists. `.github/workflows/
  build-wheels.yml`'s `build_sdist` job now actually extracts and
  installs the sdist it builds, in isolation from the checkout, before
  upload — the exact check that would have caught this before it shipped.
- The `scipy-openblas32` BLAS fallback (for platforms/environments with no
  system BLAS) was wired in for Windows only. A genuinely from-source
  install (the sdist path above, or a bare `pip install .`) has no
  `cibuildwheel` `before-all` step to install a system BLAS first, and a
  stock Linux environment can't be assumed to have one either — confirmed
  directly: a from-source install failed on a stock `ubuntu-latest` GitHub
  Actions runner with "No BLAS found ... and scipy-openblas32 isn't
  installed". `scipy-openblas32` is now an unconditional build dependency
  in `pyproject.toml`; `CMakeLists.txt`'s existing `find_package(BLAS)`
  logic still prefers a real system BLAS whenever one is found, so this is
  a pure fallback, not a change in what gets linked on platforms that
  already worked.

### Added

- Real per-argument docstrings (a full NumPy-style `Parameters` section)
  for all 49 bound model-fitting functions — sourced from the R package's
  own Roxygen documentation where a raw kernel has a direct match (15 of
  49), and from the C++ implementation directly where it doesn't (34 of
  49, confirmed empirically file-by-file, not assumed). `help(edi_kernels.
  <function>)` now works without an external doc site.
- `src/edi_kernels/_core.pyi` type stub and a `py.typed` marker (PEP 561),
  generated from the now-documented compiled module via `pybind11-
  stubgen` so types and docstrings can't drift apart. Neither existed
  before this release, despite `_core.pyi` being listed in the original
  package layout.
- `python/README_PYPI.md`: a PyPI-specific project description, separate
  from `python/README.md` (which stays for GitHub's own subfolder
  rendering). `python/README.md`'s relative links (`../R/...`, the
  generated benchmark report, etc.) 404 on a PyPI listing, since PyPI's
  renderer has no concept of "relative to this repo" — every link in the
  new file is an absolute `github.com/kapelner/EDI/...` URL instead.
  Verified with `twine check` against a real sdist build.
- `R/EDI/DESCRIPTION`'s `URL:` field now also lists the PyPI project page.

### Changed

- Benchmark-report links (in both READMEs) switched from
  `htmlpreview.github.io` to `githack.com`'s CDN mirror of this repo.
  Neither `htmlpreview.github.io` (needs client-side JS a plain link visit
  won't reliably trigger) nor an earlier attempt using jsDelivr's CDN
  mirror (serves GitHub files as `Content-Type: text/plain` regardless of
  extension, confirmed via response headers) actually render the report
  as a page in a real browser — `githack.com` does, confirmed the same
  way.

## [1.0.0] - 2026-08-05

Initial release.

### Added

- pybind11 bindings for all 33 `R/EDI/src` model-fitting kernels (37 bound
  Python functions total, counting the `_with_var` secondary entry points
  for `fast_log_binomial_regression`/`fast_identity_binomial_regression`),
  covering the continuous, binary, count, proportion, ordinal, incidence/
  GEE, survival, and GLMM/CLMM/LMM response-type families.
- An `EDI_CORE_ONLY` build path: every bound kernel compiles directly out
  of `R/EDI/src/*.cpp` with zero R/Rcpp/Rmath dependency, against vanilla
  Eigen + LBFGSpp fetched from their own upstream repositories. No kernel
  logic is duplicated or reimplemented in Python or in the `pybind11`
  binding layer.
- Every `Rcpp::Nullable<T>` argument exposed as a Python keyword argument
  with a working `std::optional`-based default — full optionality, not
  just the arguments a typical user needs.
- `python/tests/`: an R-fixture parity test for every bound kernel
  (`atol=1e-9, rtol=1e-9`) plus a dedicated omitted-argument test per
  kernel proving every optional parameter has a working default when left
  unset. 176 tests, all passing.
- `benchmarks/baselines.py`: a canonical-baseline registry (statsmodels,
  lifelines, scikit-survival, etc.) for the response-type families that
  have a clean Python equivalent, plus explicit Baseline Gap documentation
  for the families that don't (GLMM/CLMM/LMM, adjacent-category/
  continuation-ratio/stereotype ordinal, zero-one-inflated beta, Weibull
  frailty, KK-combined estimators) rather than silently omitting them.
- `R/package_metadata/benchmark_model_fits_python.html`: a generated
  benchmark report in the same column shape as the R package's own
  `benchmark_model_fits_R.html`.
- Packaging: `python/README.md`, `python/LICENSE` (GPL-3.0-only, matching
  `R/EDI/DESCRIPTION`'s `License: GPL-3`), portable-wheel support via
  `[tool.cibuildwheel]` (manylinux_2_28, macOS x86_64+arm64, Windows with a
  `scipy-openblas32` BLAS fallback), and a CI pipeline
  (`.github/workflows/build-wheels.yml`) that builds every platform's wheel
  plus an sdist and publishes to PyPI via Trusted Publishing (OIDC) on a
  `py-v*` tag push.

### Known issues

- `fast_zero_one_inflated_beta`'s R-facing return list has no
  `converged`/`iterations`/`gradient_norm` fields, even though the
  underlying `LikelihoodFitResult` the Python binding surfaces does carry
  them — an R-side gap, not a Python binding bug.
- `estimate_only=True` omits the `vcov`/`params` keys entirely on some
  kernels (`fast_gaussian_lmm`, `fast_coxph_regression`,
  `fast_weibull_regression`) rather than setting them to `None` the way
  `fast_poisson_glmm` does — inconsistent across kernels, documented
  per-file in the affected parity tests.
- The published sdist cannot be built from source at all (`EDI_SRC_DIR`'s `../R/EDI/src` resolves outside the tarball) — affects any install without a matching prebuilt wheel (e.g. Python 3.14, musllinux, non-x86/arm64); see `R/package_metadata/finished_features/python_bindings_package_spec.md` TODO-12.
