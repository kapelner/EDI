#!/usr/bin/env bash
# Bare-metal counterpart of .devcontainer/Dockerfile: apt-installs everything a
# fresh Ubuntu host needs to build, check and profile EDI (R and Python), then
# hands off to R/profile/install_perf_tools.sh for the profiling roster.
#
# Usage:  bash scripts/setup_ubuntu_host.sh               # core packages + profiling tools
#         SKIP_PERF=1 bash scripts/setup_ubuntu_host.sh   # core packages only
#         PERF_ONLY=apt bash scripts/setup_ubuntu_host.sh # pass ONLY=apt to the perf script
#                                                         # (skip its slow pip/R/git-clone steps)
#
# Installs system libraries only -- no R or Python packages. Afterwards follow
# CONTRIBUTING.md §0 (pak::local_install_deps, pip install -e ./python[test]).
#
# Not installed here:
#   - a current R: r-base-dev from the stock archive is the distro's R; add the
#     CRAN Ubuntu apt repo first (https://cran.r-project.org/bin/linux/ubuntu/)
#     to track the release CRAN checks against.
#   - Intel oneAPI MKL / VTune / Advisor (Intel apt repo): see the end of
#     R/profile/install_perf_tools.sh.
#   - newer compilers from PPAs (e.g. g++-16).
set -euo pipefail

echo "== apt: core EDI build / check packages =="
sudo apt-get update
APT_PKGS=(
  # toolchain + R
  build-essential gfortran cmake pkg-config ccache git curl ca-certificates
  r-base-dev
  # linear algebra / numerics used by EDI and its LinkingTo / Suggests
  libopenblas-dev liblapack-dev libblas-dev libeigen3-dev liblbfgspp-dev
  libtbb-dev libgsl-dev libglpk-dev libsuitesparse-dev libgraphblas-dev
  coinor-cbc coinor-libcbc-dev
  jags r-cran-rjags
  # R dependency system libs (nanonext/mirai, curl/xml2, gert, ragg/textshaping,
  # V8, RPostgres/RMySQL, protolite, graphics devices)
  libuv1-dev libcurl4-openssl-dev libssl-dev libxml2-dev
  libgit2-dev libssh2-1-dev
  libfontconfig1-dev libfreetype-dev libharfbuzz-dev libfribidi-dev
  libpng-dev libjpeg-dev libtiff-dev libwebp-dev
  libcairo2-dev libpango1.0-dev libxt-dev libx11-dev
  libicu-dev libpcre2-dev libbz2-dev liblzma-dev libzstd-dev zlib1g-dev
  libreadline-dev libncurses-dev tcl-dev tk-dev
  libnode-dev libv8-dev
  libpq-dev libmysqlclient-dev
  libprotobuf-dev libprotoc-dev protobuf-compiler
  libyaml-dev libffi-dev libtirpc-dev
  # R CMD check --as-cran / docs
  pandoc qpdf ghostscript poppler-utils tidy
  texlive texlive-xetex texlive-latex-base texlive-latex-recommended
  texlive-latex-extra texlive-fonts-recommended texlive-fonts-extra
  texlive-extra-utils texlive-plain-generic texlive-science
  texlive-bibtex-extra biber lmodern
  # sanitizer / valgrind CI jobs
  valgrind gdb
  # repo tooling (LOC badge, scripts, GitHub CLI)
  cloc jq zstd gh
  # Python package
  python3 python3-dev python3-pip python3-venv
)
# Install only what this Ubuntu release actually has, and say what it doesn't --
# one missing name must not abort the whole list.
AVAIL=(); MISSING=()
for p in "${APT_PKGS[@]}"; do
  if apt-cache show "$p" >/dev/null 2>&1; then AVAIL+=("$p"); else MISSING+=("$p"); fi
done
[ ${#MISSING[@]} -gt 0 ] && echo "apt: not available on this release, skipping: ${MISSING[*]}"
sudo apt-get install -y "${AVAIL[@]}"
# libc6-dbg pinned to the installed libc6 (same fix as R-CMD-check.yaml's valgrind
# job): unpinned, apt can pick an older libc6-dbg that demands a libc6 downgrade.
sudo apt-get install -y "libc6-dbg=$(dpkg-query -W -f='${Version}' libc6)" ||
  echo "libc6-dbg matching libc6 not available, skipping (valgrind loses libc symbols)"

if [ -z "${SKIP_PERF:-}" ]; then
  echo "== profiling tools (R/profile/install_perf_tools.sh) =="
  ONLY="${PERF_ONLY:-apt,pip,r,src}" bash "$(dirname "$0")/../R/profile/install_perf_tools.sh"
fi
