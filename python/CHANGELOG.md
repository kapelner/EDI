# Changelog

All notable changes to `edi_kernels` are documented here. The version
number tracks `R/EDI/DESCRIPTION`'s `Version` field (see
`R/package_metadata/python_bindings_package_spec.md`'s "Versioning"
checklist item) — a `.postN` suffix is used for Python-packaging-only
changes that don't touch `R/EDI/src/*.cpp`.

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
- The published sdist cannot be built from source at all (`EDI_SRC_DIR`'s `../R/EDI/src` resolves outside the tarball) — affects any install without a matching prebuilt wheel (e.g. Python 3.14, musllinux, non-x86/arm64); see `R/package_metadata/new_feature_plans/python_bindings_package_spec.md` TODO-12.
