# Base environment for the EDI devcontainer: R (rocker/r-ver already ships
# gcc/g++/gfortran/make, the full R build toolchain) plus the system
# libraries both packages in this repo need to compile from source --
# R/EDI/src/*.cpp (Rcpp/RcppEigen/RcppNumerical) and python/ (pybind11 +
# CMake). Versions/packages here mirror what CI actually installs (see
# .github/workflows/python-tests.yml's "Install system BLAS" step and
# test-coverage-R-advanced.yml's sysreqs comment) rather than being guessed.
FROM rocker/r-ver:latest

ENV DEBIAN_FRONTEND=noninteractive

# Skips -march=native/-mtune=native (see R/EDI/configure): a devcontainer
# image is built once and may run on different host CPUs than it was built
# on, so a machine-tuned build would be wrong there. This is the same
# portable-build opt-out CI's R-CMD-check.yaml sets.
ENV EDI_PORTABLE=1

# qpdf/ghostscript are not R package dependencies -- they're the CLI tools
# R CMD build's own --compact-vignettes=gs+qpdf shells out to (see
# R-CMD-check.yaml's build_args). sudo is for R/profile/install_perf_tools.sh
# (run from post-create.sh), which calls `sudo apt-get ...` throughout --
# a no-op wrapper as root, but the binary must exist. The
# libfontconfig1-dev/libfreetype6-dev/libharfbuzz-dev/libfribidi-dev/
# libpng-dev/libtiff5-dev/libjpeg-dev group covers ggplot2's common
# systemfonts/textshaping/ragg transitive needs up front; pak's sysreqs
# auto-detection below is the real backstop for anything still missing.
RUN apt-get update && apt-get install -y --no-install-recommends \
        build-essential gfortran cmake pkg-config git curl ca-certificates sudo ccache \
        pandoc qpdf ghostscript \
        python3 python3-pip python3-venv python3-dev \
        libcurl4-openssl-dev libssl-dev libxml2-dev \
        libglpk-dev \
        libfontconfig1-dev libfreetype6-dev libharfbuzz-dev libfribidi-dev \
        libpng-dev libtiff5-dev libjpeg-dev \
        libeigen3-dev libopenblas-dev \
    && rm -rf /var/lib/apt/lists/*

# LaTeX -- not for the vignettes (all five are rmarkdown::html_vignette,
# pure HTML, no LaTeX involved), but for: (1) R CMD check's own PDF
# reference manual step whenever run without --no-manual (every CI job
# passes --no-manual, so this only matters for a manual local run); and
# (2) the real .tex sources under R/package_metadata/new_research_ideas/
# (grant proposals, article class; a beamer talk) -- confirmed by grepping
# every \usepackage/\documentclass across those files, not guessed. `texlive`
# (the "recommended" tier: latex-base + latex-recommended + fonts-recommended
# + pictures) covers most of that list already; the four packages below add
# what it doesn't: texlive-latex-extra (abstract, appendix, cancel,
# csquotes, fancyhdr, multirow, subfigure, ulem, wasysym, mathdots, authblk),
# texlive-fonts-extra (dsfont/doublestroke, mathptmx), texlive-science
# (algorithm, algorithmic), texlive-bibtex-extra + biber (natbib's fuller
# style/backend support). This is well short of texlive-full (~5-7GB) but
# covers everything actually used in this repo.
RUN apt-get update && apt-get install -y --no-install-recommends \
        texlive texlive-latex-extra texlive-fonts-extra texlive-science \
        texlive-bibtex-extra biber lmodern \
    && rm -rf /var/lib/apt/lists/*

# pak resolves and installs R/EDI's Imports + Suggests + LinkingTo from
# DESCRIPTION in one call, and on Debian/Ubuntu also auto-detects and
# apt-get installs any *additional* system library a specific R package
# needs beyond the base set above (the same sysreqs database
# r-lib/actions/setup-r-dependencies uses in CI) -- so the apt-get list
# above only needs to cover what's needed up front, not track every
# transitive Suggests dependency by hand.
RUN install2.r --error --skipinstalled pak

# ccache: wraps the C/C++ compiler so recompiling R/EDI's 100+ .cpp files
# after a small edit (or reinstalling the same source again, e.g. after a
# container rebuild sharing the mounted cache below) reuses object files
# instead of recompiling from scratch. This is a *user* Makevars, not
# R/EDI/src/Makevars (which R/EDI/configure regenerates on every configure
# run and would silently drop a CXX override placed there instead) -- R's
# own precedence applies ~/.R/Makevars on top of every package's own
# Makevars, so this affects R/EDI and any other from-source R package build
# in this container uniformly. CCACHE_DIR points at a path devcontainer.json
# mounts as a named volume, so the cache survives a container rebuild, not
# just a single session.
ENV CCACHE_DIR=/ccache
RUN mkdir -p /root/.R /ccache && \
    printf 'CC = ccache gcc\nCXX = ccache g++\nCXX11 = ccache g++\nCXX14 = ccache g++\nCXX17 = ccache g++\nCXX20 = ccache g++\n' > /root/.R/Makevars

WORKDIR /workspaces/EDI
