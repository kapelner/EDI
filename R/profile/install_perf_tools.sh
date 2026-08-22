#!/usr/bin/env bash
# Install the performance-tooling roster from
# package_metadata/new_feature_plans/performance_profiling_and_upgrades.md §8.0
# (Ubuntu 24.04/26.04; verified package names against Ubuntu 26.04 apt on 2026-08-22).
#
# Usage:  bash profile/install_perf_tools.sh            # apt + pip + R + git-clone tools
#         SKIP_SRC=1 bash profile/install_perf_tools.sh # apt + pip + R only
#         SRC_DIR=~/perf-tools bash profile/install_perf_tools.sh   # where git clones go (default ~/perf-tools)
#         PREFIX=~/.local bash profile/install_perf_tools.sh        # install prefix for source builds / npm (default ~/.local, no sudo)
#         ONLY=pip,r,src bash profile/install_perf_tools.sh         # run a subset of steps (apt,pip,r,src); sudo is only needed for apt
# Verify afterwards with:  bash profile/verify_perf_tools.sh
#
# Not installed here (manual / licensed / vendor downloads — see the end of this script):
#   Intel VTune + Advisor (oneAPI apt repo), Intel SDE, Intel Pin, AMD uProf, Compiler Explorer (docker),
#   IACA (discontinued).
set -euo pipefail
SRC_DIR="${SRC_DIR:-$HOME/perf-tools}"
PREFIX="${PREFIX:-$HOME/.local}"
ONLY="${ONLY:-apt,pip,r,src}"
want() { case ",$ONLY," in *",$1,"*) return 0;; *) return 1;; esac; }
mkdir -p "$PREFIX/bin"

if want apt; then
echo "== 1/5 apt packages =="
sudo apt-get update
APT_PKGS=(
  # sampling / HW-counter profilers
  linux-tools-common linux-tools-generic
  likwid uftrace binutils gdb elfutils
  libgoogle-perftools-dev            # gperftools: libprofiler (CPU), libtcmalloc*, pprof (no separate google-perftools pkg on 26.04)
  bpftrace bpfcc-tools systemtap
  ltrace strace
  # instrumenting simulators / memory tools
  valgrind kcachegrind massif-visualizer
  heaptrack heaptrack-gui
  libjemalloc2 libjemalloc-dev
  dwarves                            # pahole
  # assembly / compiler / static analysis
  llvm clang clang-tidy clang-tools lld
  cppcheck iwyu ccache
  # machine state & benchmark hygiene
  hyperfine stress-ng powertop lm-sensors
  numactl hwloc cpuid cpuset sysstat htop util-linux
  cpupower-gui
  # BLAS backends for A/B via update-alternatives
  libopenblas-dev libblis-dev intel-mkl
  # C++ microbench harness
  libbenchmark-dev
  # build deps for the git-clone tools below
  git cmake build-essential pkg-config python3 python3-pip python3-venv nodejs npm
  libre2-dev libprotobuf-dev protobuf-compiler libcapstone-dev zlib1g-dev
  r-base-dev libgit2-dev libssh2-1-dev libssl-dev libcurl4-openssl-dev   # git2r (atime dep) needs libgit2
)
# Install only what this Ubuntu release actually has, and say what it doesn't — one
# missing name must not abort the whole roster.
AVAIL=(); MISSING=()
for p in "${APT_PKGS[@]}"; do
  if apt-cache show "$p" >/dev/null 2>&1; then AVAIL+=("$p"); else MISSING+=("$p"); fi
done
[ ${#MISSING[@]} -gt 0 ] && echo "apt: not available on this release, skipping: ${MISSING[*]}"
sudo apt-get install -y --no-install-recommends "${AVAIL[@]}"

# NOTE (WSL2, measured on this box 2026-08-22, kernel 6.6.87.2-microsoft-standard-WSL2):
#   linux-tools-$(uname -r) does not exist for the Microsoft kernel; use linux-tools-generic's
#   binaries under /usr/lib/linux-tools/<ver>/ or the locally built /usr/local/bin/perf.
#   WORKS in WSL2:  perf record/report/annotate (software + HW sampling), perf stat with
#     cycles/instructions/branches/branch-misses/cache-misses and named events (fp_assist.any,
#     topdown-*), perf stat --topdown (TMA level 1), perf diff, bpftrace/bcc uprobes (BTF present),
#     valgrind/heaptrack/DHAT, llvm-mca/OSACA/uiCA/SDE, hyperfine, all R/Python profilers.
#   DOES NOT work in WSL2: PEBS precise events (cycles:pp -> "Error") so perf mem and perf c2c
#     fail ("memory events not supported"); Intel PT (no intel_pt PMU); /dev/cpu/*/msr (so
#     likwid-perfctr, turbostat, likwid-powermeter cannot read counters/frequency/energy);
#     RAPL powercap; cpufreq governor / turbo control; reliable physical-core pinning
#     (taskset pins to vCPUs the Hyper-V scheduler may migrate). Run those TODOs on bare metal.
# NOTE (tcmalloc): Ubuntu 26.04 ships tcmalloc inside libgoogle-perftools-dev
# (libtcmalloc.so / libtcmalloc_minimal.so), not as libtcmalloc-minimal4.
fi


if want pip; then
echo "== 2/5 pip packages (user site, no sudo) =="
python3 -m pip install --user --upgrade --break-system-packages --timeout 120 --retries 10 --resume-retries 5 \
  osaca s-tui \
  py-spy scalene memray pyperf pytest-benchmark asv snakeviz line_profiler \
  gprof2dot
echo "pip console scripts are in ~/.local/bin — make sure it is on PATH"
fi

if want r; then
echo "== 3/5 R packages =="
# Non-fatal: one package failing (e.g. atime without libgit2-dev) must not stop the src step.
Rscript -e '
r <- "https://cloud.r-project.org"
pk <- c("profvis","proftools","bench","atime","microbenchmark","tictoc","profmem",
        "lobstr","memuse","benchmarkme","RhpcBLASctl","lintr","covr",
        "remotes","profile","RProtoBuf","proffer")   # RProtoBuf+proffer: jointprof deps (need libprotoc-dev)
pk <- setdiff(pk, rownames(installed.packages()))
if (length(pk)) install.packages(pk, repos = r)
# jointprof (R + native stacks in one profile) — its GitHub Remotes: field points at a dead
# krlmlr/proffer, so install proffer from CRAN first (above) and ignore Remotes here.
# touchstone and RcppClock are archived on CRAN (2024/25) — GitHub only.
for (r in c("lorenzwalthert/touchstone", "zdebruine/RcppClock")) {
  p <- basename(r); if (requireNamespace(p, quietly = TRUE)) next
  tryCatch(remotes::install_github(r, upgrade = "never"), error = function(e) message(p, " failed: ", conditionMessage(e)))
}
# remotes::install_github() fails on jointprof'"'"'s dead "Remotes: r-prof/proffer#12" line even when
# proffer is already installed, so install the tarball with base R, which ignores Remotes entirely.
if (!requireNamespace("jointprof", quietly = TRUE)) tryCatch({
  tf <- tempfile(fileext = ".tar.gz"); download.file("https://github.com/r-prof/jointprof/archive/HEAD.tar.gz", tf, quiet = TRUE)
  td <- tempfile(); dir.create(td); untar(tf, exdir = td); src <- list.dirs(td, recursive = FALSE)[1]
  install.packages(src, repos = NULL, type = "source")
}, error = function(e) message("jointprof not installed: ", conditionMessage(e)))
miss <- setdiff(c(pk, "touchstone", "RcppClock", "jointprof"), rownames(installed.packages()))
if (length(miss)) message("R packages still missing: ", paste(miss, collapse = ", "))
' || echo "R step had failures (see above) — continuing"
fi

if want src && [ "${SKIP_SRC:-0}" != "1" ]; then
  echo "== 4/5 git-clone tools -> $SRC_DIR (source builds install under $PREFIX, no sudo) =="
  mkdir -p "$SRC_DIR" && cd "$SRC_DIR"
  clone() { [ -d "$2" ] || git clone --depth 1 "$1" "$2"; }
  clone https://github.com/andikleen/pmu-tools.git        pmu-tools     # toplev.py, ocperf.py
  clone https://github.com/brendangregg/FlameGraph.git    FlameGraph    # stackcollapse-perf.pl, flamegraph.pl
  clone https://github.com/andreas-abel/uiCA.git          uiCA          # cycle-accurate Intel sim
  clone https://github.com/andreas-abel/nanoBench.git     nanoBench     # measured instruction latencies (kernel module optional)
  clone https://github.com/google/bloaty.git              bloaty        # binary-size profiler (not in apt)
  clone https://github.com/aras-p/ClangBuildAnalyzer.git  ClangBuildAnalyzer
  clone https://github.com/martinus/nanobench.git         nanobench     # header-only microbench
  clone https://github.com/mpimd-csc/flexiblas.git        flexiblas     # runtime BLAS switching (not in apt)
  clone https://github.com/cyring/CoreFreq.git            CoreFreq 2>/dev/null || true  # optional
  ( cd uiCA && ./setup.sh ) || echo "uiCA setup failed (needs internet for uops.info XML) — rerun later"
  ( cd bloaty && cmake -B build -G "Unix Makefiles" -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX="$PREFIX" >/dev/null && cmake --build build -j"$(nproc)" && cmake --install build ) || echo "bloaty build failed"
  ( cd ClangBuildAnalyzer && cmake -B build -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX="$PREFIX" >/dev/null && cmake --build build -j"$(nproc)" && cmake --install build ) || echo "ClangBuildAnalyzer build failed"
  ( cd flexiblas && cmake -B build -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX="$PREFIX" -DCMAKE_INSTALL_RPATH="$PREFIX/lib" >/dev/null && cmake --build build -j"$(nproc)" && cmake --install build ) || echo "flexiblas build failed"
  npm install -g --prefix "$PREFIX" speedscope 2>/dev/null || echo "speedscope: use https://www.speedscope.app instead"
  # thin wrappers so the clone-only tools are on PATH via $PREFIX/bin
  for t in toplev.py ocperf.py; do printf '#!/bin/sh\nexec python3 %s/pmu-tools/%s "$@"\n' "$SRC_DIR" "$t" > "$PREFIX/bin/${t%.py}"; chmod +x "$PREFIX/bin/${t%.py}"; done
  for t in flamegraph.pl stackcollapse-perf.pl; do ln -sf "$SRC_DIR/FlameGraph/$t" "$PREFIX/bin/$t"; done
  printf '#!/bin/sh\nexec python3 %s/uiCA/uiCA.py "$@"\n' "$SRC_DIR" > "$PREFIX/bin/uiCA"; chmod +x "$PREFIX/bin/uiCA"
  echo "Wrappers/symlinks for toplev, ocperf, flamegraph.pl, stackcollapse-perf.pl, uiCA placed in $PREFIX/bin — ensure it is on PATH"
  echo "flexiblas libs are in $PREFIX/lib — builds from before the rpath flag need: export LD_LIBRARY_PATH=$PREFIX/lib:\$LD_LIBRARY_PATH"
  echo "toplev: first run downloads the CPU event tables into ~/.cache/pmu-events (needs network)"
  # Single-file downloads that need no build and no sudo:
  #  - pprof: the gperftools perl script is no longer shipped in the Ubuntu gperftools deb (>= 2.16)
  #  - hotspot: KDAB's perf GUI, AppImage (needs libfuse2, or run with --appimage-extract-and-run)
  #  - magic-trace: Jane Street's Intel PT UI (bare-metal Intel only; inert on WSL2)
  curl -fsSL https://raw.githubusercontent.com/gperftools/gperftools/gperftools-2.15/src/pprof -o "$PREFIX/bin/pprof" && chmod +x "$PREFIX/bin/pprof" || echo "pprof download failed"
  hs_url=$(curl -fsSL https://api.github.com/repos/KDAB/hotspot/releases/latest | grep -o 'https://[^"]*x86_64\.AppImage"' | head -1 | tr -d '"')
  { [ -n "$hs_url" ] && curl -fL --retry 5 -o "$PREFIX/bin/hotspot" "$hs_url" && chmod +x "$PREFIX/bin/hotspot"; } || echo "hotspot download failed"
  curl -fL --retry 5 -o "$PREFIX/bin/magic-trace" https://github.com/janestreet/magic-trace/releases/latest/download/magic-trace && chmod +x "$PREFIX/bin/magic-trace" || echo "magic-trace download failed"
fi

echo "== 5/5 manual / vendor downloads (not automated) =="
cat <<'TXT'
  Intel VTune + Advisor:
    wget -O- https://apt.repos.intel.com/intel-gpg-keys/GPG-PUB-KEY-INTEL-SW-PRODUCTS.PUB | gpg --dearmor | sudo tee /usr/share/keyrings/oneapi-archive-keyring.gpg >/dev/null
    echo "deb [signed-by=/usr/share/keyrings/oneapi-archive-keyring.gpg] https://apt.repos.intel.com/oneapi all main" | sudo tee /etc/apt/sources.list.d/oneAPI.list
    sudo apt-get update && sudo apt-get install -y intel-oneapi-vtune intel-oneapi-advisor
    # then, every shell:  source /opt/intel/oneapi/setvars.sh   (or call /opt/intel/oneapi/vtune/latest/bin64/vtune directly)
    # user-mode sampling (hotspots, threading, Advisor survey) needs:  sudo sysctl -w kernel.yama.ptrace_scope=0
    #   (persist: echo kernel.yama.ptrace_scope=0 | sudo tee /etc/sysctl.d/10-ptrace.conf)
    # On WSL2 the postinst tries to build the sep5 sampling driver and fails (no kernel headers for the
    # Microsoft kernel; the module could not be loaded anyway). That is harmless — VTune falls back to
    # driverless mode — but the failed unit re-fails at every boot, so:  sudo systemctl disable --now sep5.service
    # Hardware-event analyses (uarch-exploration, memory-access, hw hotspots) report "cannot recognize the
    # processor" inside WSL2 (2026.4 on i7-9750H) — they need bare metal, like PEBS/MSR. User-mode
    # hotspots/threading and Advisor survey/roofline (software FLOP counting) work on WSL2.
  Intel SDE (instruction mix, ISA emulation): https://www.intel.com/content/www/us/en/developer/articles/tool/software-development-emulator.html
  Intel Pin:                                  https://www.intel.com/content/www/us/en/developer/articles/tool/pin-a-binary-instrumentation-tool-downloads.html
  AMD uProf (AMD hosts):                      https://www.amd.com/en/developer/uprof.html  (.deb)
  Compiler Explorer (local):                  docker run -p 10240:10240 compilerexplorer/compiler-explorer  (or madduci/docker-compiler-explorer)
  IACA: discontinued by Intel — use uiCA/llvm-mca/OSACA.
  Empirical Roofline Tool (ERT):              https://bitbucket.org/berkeleylab/cs-roofline-toolkit
TXT
echo "done."
