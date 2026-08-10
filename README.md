# EDI

[![R-CMD-check](https://github.com/kapelner/EDI/actions/workflows/R-CMD-check.yaml/badge.svg)](https://github.com/kapelner/EDI/actions/workflows/R-CMD-check.yaml)
[![Python tests](https://github.com/kapelner/EDI/actions/workflows/python-tests.yml/badge.svg)](https://github.com/kapelner/EDI/actions/workflows/python-tests.yml)
[![R coverage](https://codecov.io/gh/kapelner/EDI/branch/main/graph/badge.svg?flag=r)](https://codecov.io/gh/kapelner/EDI/flags/r)
[![Python coverage](https://codecov.io/gh/kapelner/EDI/branch/main/graph/badge.svg?flag=python)](https://codecov.io/gh/kapelner/EDI/flags/python)
[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](LICENSE)
![Platforms](https://img.shields.io/badge/platform-linux%20%7C%20macOS%20%7C%20windows-lightgrey)
[![Last commit](https://img.shields.io/github/last-commit/kapelner/EDI)](https://github.com/kapelner/EDI/commits/main)

**EDI** (Experimental Design and Inference) is a library of experimental
designs — both fixed and sequential — that use matching-on-the-fly
techniques to maintain covariate balance, paired with inference procedures
(exact, asymptotic, and distribution-free) tailored to each design and
response type (continuous, incidence, count, proportion, survival, and
ordinal). The core model-fitting kernels are written in C++ (Eigen +
LBFGS++) for speed.

This repo hosts **two packages** built on that shared C++ core:

- **[`R/`](R/README.md)** — the `EDI` R package (R6 classes for designs,
  inference, and simulation), which the C++ kernels were originally written
  for.
- **[`python/`](python/README.md)** — `edi_kernels`, a `pybind11` package
  that compiles the same C++ kernels directly, with no R or Rcpp dependency.

See each package's README for installation, usage, and benchmark results.

## Citation

If you use this software, please cite it — see [`CITATION.cff`](CITATION.cff)
(GitHub renders a "Cite this repository" button from this file) or, from R,
run `citation("EDI")`.
