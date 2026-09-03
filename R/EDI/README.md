# EDI: Experimental Design and Inference <img src="man/figures/logo.png" align="right" height="139" alt="EDI hex logo" />

[![CRAN](https://img.shields.io/cran/v/EDI.svg)](https://CRAN.R-project.org/package=EDI)
[![R-universe version](https://kapelner.r-universe.dev/EDI/badges/version)](https://kapelner.r-universe.dev/EDI)
[![R-CMD-check](https://github.com/kapelner/EDI/actions/workflows/R-CMD-check.yaml/badge.svg)](https://github.com/kapelner/EDI/actions/workflows/R-CMD-check.yaml)
[![R coverage](https://codecov.io/gh/kapelner/EDI/branch/main/graph/badge.svg?flag=r)](https://codecov.io/gh/kapelner/EDI/flags/r)
[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](https://www.gnu.org/licenses/gpl-3.0)
[![DOI](https://zenodo.org/badge/DOI/10.5281/zenodo.22170036.svg)](https://doi.org/10.5281/zenodo.22170036)

`EDI` (Experimental Design and Inference) marries experimental designs (fixed
and sequential) with inference procedures (exact, asymptotic, and
distribution-free) tailored to each design and response type: continuous,
incidence, count, proportion, survival with left/right censoring, and ordinal.
Designs, inference, and Monte Carlo simulation are exposed as R6 classes; the
core estimation and variance-computing kernels are written in C++ (Eigen +
LBFGS++) for speed.

## Installation

Requires R >= 3.5.0. The quickest route is prebuilt binaries (Linux, macOS,
and Windows, no compiler toolchain needed) from Adam Kapelner's
[R-universe](https://kapelner.r-universe.dev):

```r
install.packages(
  "EDI",
  repos = c(
    kapelner = "https://kapelner.r-universe.dev",
    CRAN = "https://cloud.r-project.org"
  )
)
```

Or build the development version from a clone of the repository (requires a
C++ compiler toolchain for R packages, e.g. Rtools on Windows, Xcode command
line tools on macOS, or `r-base-dev` on Debian/Ubuntu):

```r
# from the repository root
install.packages("R/EDI", repos = NULL, type = "source")
```

`EDI` has been submitted to CRAN; once accepted, plain
`install.packages("EDI")` will work too.

## Getting started

```r
library(EDI)
vignette("reproducibility", package = "EDI")      # RNG/seed conventions across designs, bootstrap, and simulation
vignette("extending-edi", package = "EDI")        # writing your own Design/Inference R6 subclasses
vignette("backend-contracts", package = "EDI")    # how the C++ core is shared between the R (Rcpp) and Python (pybind11) bindings
vignette("notation-glossary", package = "EDI")    # symbols/naming conventions shared across Design*/Inference* classes and docs
vignette("validation-evidence", package = "EDI")  # index into the test suite showing each model family computes what it claims
```

See the [repository README](https://github.com/kapelner/EDI#readme) for
worked examples (fixed and sequential designs, the inference suite, design
bakeoffs via `SimulationFramework`), local performance tuning, and the
companion Python package `edi_kernels`.
