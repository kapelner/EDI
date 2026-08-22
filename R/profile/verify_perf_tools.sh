#!/usr/bin/env bash
# Verify the performance-tooling roster from
# package_metadata/new_feature_plans/performance_profiling_and_upgrades.md §8.0
# is installed. Companion to install_perf_tools.sh. Exit 0 always; prints OK/MISSING per item.
SRC_DIR="${SRC_DIR:-$HOME/perf-tools}"
ok=0; miss=0
say() { printf '  %-8s %s\n' "$1" "$2"; }
chk_cmd() { if command -v "$1" >/dev/null 2>&1; then say OK "$1 ($(command -v "$1"))"; ok=$((ok+1)); else say MISSING "$1${2:+  ($2)}"; miss=$((miss+1)); fi; }
chk_pkg() { if dpkg -s "$1" >/dev/null 2>&1; then say OK "apt $1"; ok=$((ok+1)); else say MISSING "apt $1"; miss=$((miss+1)); fi; }
chk_py()  { if python3 -c "import $1" >/dev/null 2>&1; then say OK "python $1"; ok=$((ok+1)); else say MISSING "python $1"; miss=$((miss+1)); fi; }
chk_dir() { if [ -e "$1" ]; then say OK "$1"; ok=$((ok+1)); else say MISSING "$1${2:+  ($2)}"; miss=$((miss+1)); fi; }

echo "== apt packages =="
for p in linux-tools-common linux-tools-generic likwid uftrace binutils gdb elfutils libgoogle-perftools-dev \
  bpftrace bpfcc-tools systemtap ltrace strace valgrind kcachegrind massif-visualizer heaptrack heaptrack-gui \
  libjemalloc2 libjemalloc-dev dwarves llvm clang clang-tidy clang-tools lld cppcheck iwyu ccache hyperfine \
  stress-ng powertop lm-sensors numactl hwloc cpuid cpuset sysstat htop cpupower-gui libopenblas-dev libblis-dev \
  intel-mkl libbenchmark-dev libgit2-dev libssh2-1-dev libssl-dev; do chk_pkg "$p"; done

echo "== binaries on PATH =="
for c in perf valgrind callgrind_annotate cg_annotate ms_print heaptrack uftrace ltrace strace bpftrace \
  likwid-perfctr likwid-topology likwid-bench llvm-mca clang clang-tidy cppcheck include-what-you-use ccache \
  pahole hyperfine stress-ng powertop sensors numactl lstopo cpuid cset mpstat pidstat htop taskset setarch \
  gdb objdump readelf nm c++filt pprof kcachegrind massif-visualizer; do chk_cmd "$c"; done
# turbostat/cpupower live under /usr/lib/linux-tools/<ver>/ on WSL2 (no linux-tools-$(uname -r))
for t in turbostat cpupower; do
  f=$(ls /usr/lib/linux-tools/*/$t 2>/dev/null | head -1)
  if command -v $t >/dev/null 2>&1; then say OK "$t"; ok=$((ok+1)); elif [ -n "$f" ]; then say OK "$t (not on PATH: $f)"; ok=$((ok+1)); else say MISSING "$t"; miss=$((miss+1)); fi
done
# bcc tools are installed with a -bpfcc suffix on Ubuntu
for c in funclatency funccount profile offcputime memleak; do chk_cmd "$c-bpfcc"; done
# gperftools library (LD_PRELOAD targets)
for so in libprofiler.so libtcmalloc.so libjemalloc.so.2; do
  if ldconfig -p | grep -q "$so"; then say OK "lib $so"; ok=$((ok+1)); else say MISSING "lib $so"; miss=$((miss+1)); fi
done

echo "== pip modules =="
for m in osaca s_tui scalene memray pyperf pytest_benchmark asv snakeviz line_profiler gprof2dot; do chk_py "$m"; done
for c in osaca s-tui py-spy scalene memray pyperf asv snakeviz kernprof gprof2dot; do chk_cmd "$c" "pip --user bin dir may not be on PATH: ~/.local/bin"; done

echo "== R packages =="
Rscript -e '
pk <- c("profvis","proftools","bench","atime","touchstone","microbenchmark","RcppClock","tictoc","profmem",
        "lobstr","memuse","benchmarkme","RhpcBLASctl","lintr","covr","remotes","profile","jointprof")
inst <- pk %in% rownames(installed.packages())
for (i in seq_along(pk)) cat(sprintf("  %-8s R %s\n", if (inst[i]) "OK" else "MISSING", pk[i]))
cat(sprintf("  R_OK=%d R_MISSING=%d\n", sum(inst), sum(!inst)))
' 2>&1 | tee /tmp/_r_verify.txt | grep -v "^  R_OK"
r_ok=$(grep -o "R_OK=[0-9]*" /tmp/_r_verify.txt | cut -d= -f2); r_miss=$(grep -o "R_MISSING=[0-9]*" /tmp/_r_verify.txt | cut -d= -f2)
ok=$((ok+${r_ok:-0})); miss=$((miss+${r_miss:-0}))

echo "== git-clone / source-built tools ($SRC_DIR) =="
chk_dir "$SRC_DIR/pmu-tools/toplev.py"
chk_dir "$SRC_DIR/FlameGraph/flamegraph.pl"
chk_dir "$SRC_DIR/uiCA/uiCA.py"
chk_dir "$SRC_DIR/uiCA/instrData" "uiCA/setup.sh not run (downloads uops.info data)"
chk_dir "$SRC_DIR/nanoBench/nanoBench.sh"
chk_dir "$SRC_DIR/nanobench/src/include/nanobench.h"
chk_dir "$SRC_DIR/ClangBuildAnalyzer"
chk_dir "$SRC_DIR/bloaty"
chk_dir "$SRC_DIR/flexiblas"
chk_cmd bloaty "source build failed or not installed"
chk_cmd ClangBuildAnalyzer "source build failed or not installed"
chk_cmd flexiblas "source build failed or not installed"
chk_cmd speedscope "npm -g; or use https://www.speedscope.app"

echo "== vendor / manual tools =="
chk_cmd vtune "Intel oneAPI: apt install intel-oneapi-vtune, then source /opt/intel/oneapi/setvars.sh"
chk_cmd advisor "Intel oneAPI: apt install intel-oneapi-advisor"
[ -x /opt/intel/oneapi/vtune/latest/bin64/vtune ] && say NOTE "vtune present at /opt/intel/oneapi/vtune/latest (source setvars.sh to put on PATH)"
[ -x /opt/intel/oneapi/advisor/latest/bin64/advisor ] && say NOTE "advisor present at /opt/intel/oneapi/advisor/latest"
ps_scope=$(cat /proc/sys/kernel/yama/ptrace_scope 2>/dev/null); [ "${ps_scope:-0}" != "0" ] && say NOTE "kernel.yama.ptrace_scope=$ps_scope — VTune/Advisor user-mode sampling needs 0 (sudo sysctl -w kernel.yama.ptrace_scope=0)"
systemctl is-enabled sep5.service >/dev/null 2>&1 && say NOTE "sep5.service (VTune kernel driver) is enabled; on WSL2 it cannot load — sudo systemctl disable --now sep5.service"
chk_cmd sde64 "Intel SDE: manual download"
chk_cmd AMDuProfCLI "AMD uProf: AMD hosts only"
chk_cmd hotspot "KDAB AppImage — install_perf_tools.sh src step downloads it to $PREFIX/bin"
chk_cmd magic-trace "install_perf_tools.sh src step downloads it to $PREFIX/bin (Intel PT: bare metal only)"

echo
echo "SUMMARY: $ok OK, $miss MISSING"
