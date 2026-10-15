# Optimizing R Itself for `EDI`

`EDI`'s own C++ kernels are already compiled with machine-specific flags (see
[Tuning Local Builds](../../README.md#tuning-local-builds) in the main README). But
every `EDI` call also spends time in the R interpreter: R6 method dispatch,
argument checking, resampling loops, `data.table` bookkeeping, and so on. That
code runs in whatever R binary you have installed, and distribution builds of
R are compiled with conservative, portable flags.

This document describes how to rebuild and reinstall R-devel with optimized
compiler settings, what that bought on a real `EDI` workload, and the pitfalls
we hit along the way.

- [Measured results](#measured-results)
- [Reinstalling R: opt or PGO](#reinstalling-r-opt-or-pgo)
  - [Which should I choose?](#which-should-i-choose)
  - [Shared setup](#shared-setup)
  - [Option A: opt build](#option-a-opt-build)
  - [Option B: PGO build](#option-b-pgo-build)
  - [After either option](#after-either-option)
- [Pitfalls and issues](#pitfalls-and-issues)
- [Parallel package installation (R-devel PR #278)](#parallel-package-installation-r-devel-pr-278)
- [Reproducing the benchmark](#reproducing-the-benchmark)

## Measured results

Three builds of the same R-devel source (r89955) were benchmarked with one
dataset, one design, and one replicate of `R/package_tests/comprehensive_tests.R`:

```sh
Rscript comprehensive_tests.R 1 1 NA Bernoulli NA pte_example NA 1
#                             |  |      |           |          |
#                          Nrep cores design     dataset      rep
```

| Build | Flags | Wall clock | vs base | User CPU | vs base |
| --- | --- | --- | --- | --- | --- |
| base | `-O3 -march=native -funroll-loops -fno-math-errno`, no LTO | 3:15:55 | — | 9131 s | — |
| opt | base + `-fno-semantic-interposition -fno-plt` + `--enable-lto=R` | 3:02:17 | **−7.0%** | 8416 s | −7.8% |
| PGO | opt + profile-guided optimization (trained on `make check`) | 2:51:55 | **−12.2%** | 7723 s | −15.4% |

The PGO build includes LTO: it is the opt build plus PGO. Per-call totals by
response type, over the 14,292 calls that succeeded in all three builds:

| Response type | Calls | opt | PGO |
| --- | --- | --- | --- |
| continuous | 1952 | −13.1% | −18.5% |
| incidence | 3384 | −9.1% | −16.3% |
| proportion | 1800 | −6.6% | −14.5% |
| count | 3168 | −4.4% | −12.5% |
| ordinal | 1676 | −7.2% | −8.7% |
| survival | 2312 | −5.1% | −5.5% |
| **Total** | 14292 | **−7.0%** | **−12.3%** |

How to read these numbers:

- **The results are identical.** All 14,408 result rows (p-values, confidence
  intervals, statuses, including the same 116 errors) match exactly across the
  three builds. None of these flags changes any computed value.
- **The gain is broad, not driven by outliers.** The median per-call time ratio
  is 0.93 for opt and 0.88 for PGO.
- **The gain varies by response type.** Response types whose time is
  dominated by `EDI`'s C++ kernels or by other packages' compiled code
  (survival, ordinal) gain the least, because rebuilding R does not recompile
  that code. Response types with more R-level overhead (continuous,
  incidence) gain the most.
- **About a quarter of CPU time is system time** (~3,400 s in every build),
  mostly from the test harness forking a child process per call for timeout
  enforcement. Compiler flags cannot affect that, which is why the user-CPU
  gains are larger than the wall-clock gains.
- **The baseline was already tuned.** It used `-O3 -march=native`. Compared
  with a stock distribution R (typically `-O2`, generic x86-64), the gap is
  presumably larger, but that was not measured.
- **Caveat: these are single runs on one laptop.** The machine was an Intel
  i7-9750H (6 cores / 12 threads) running WSL2, with gcc 15.2 and Intel MKL as
  the BLAS. Two unrelated CPU-bound processes (leftover `yes > /dev/null`)
  were running on the machine throughout all three runs, so each run had the
  same steady 2-core background load. That keeps the comparison between the
  builds fair, but the absolute times are somewhat slower than on an idle
  machine. A second base run, to check how much timing drifts between runs,
  was invalidated by additional external load and still needs to be redone
  on an idle machine.
- **What was not tested:** each piece on its own (LTO alone,
  `-fno-semantic-interposition -fno-plt` alone, or PGO without LTO), so the
  7% of the opt build can't be split between LTO and the new flags.

## Reinstalling R: opt or PGO

These instructions are for Debian/Ubuntu with gcc, installing to `/usr/local`
(replacing an R already installed there, if any). Build on the machine that
will run R, because `-march=native` produces a binary tied to that CPU type.

### Which should I choose?

| | Option A: opt | Option B: PGO |
| --- | --- | --- |
| Speedup on the benchmark above | −7% | −12% |
| Build time on the 6-core test laptop | ~7 min, plus ~5 min for `make check` | ~22 min (two builds plus a training run), plus ~5 min for the final `make check` |
| Steps | one configure, build, install | two configures and builds, a training run, then a cleanup of the installed `Makeconf` |
| When you update the R source later | rebuild as usual | redo **both** stages; a profile from older source silently loses most of its benefit |
| What can go wrong | little beyond a normal R build | the PGO-specific pitfalls below; all are handled in the commands, but there are more moving parts |

Choose **PGO** if you run long `EDI` simulations and don't mind a longer, more
involved build. Choose **opt** if you update R-devel often or want the
simplest rebuild. Either way, it's easy to switch later: rerun the other
option.

### Shared setup

Do these steps once, before either option.

**1. Enable source repositories and install build dependencies.**

```bash
# Enable deb-src (needed for `apt-get build-dep`)
# Ubuntu 24.04+ / Debian 13+ (deb822 *.sources files):
for f in /etc/apt/sources.list.d/*.sources; do
  [ -e "$f" ] && sudo sed -i -E 's/^Types:[[:space:]]*deb$/Types: deb deb-src/' "$f"
done
# Older Ubuntu / Debian (one-line sources.list):
[ -f /etc/apt/sources.list ] && sudo sed -i -E 's/^#[[:space:]]*deb-src /deb-src /' /etc/apt/sources.list
sudo apt-get update
apt-get source --print-uris r-base | head -3   # should print URLs, not an error

sudo apt-get build-dep r-base
sudo apt-get install git curl libopenblas-dev
```

**2. Get the R-devel source** (optionally with the
[PR #278](#parallel-package-installation-r-devel-pr-278) patch).

```bash
cd ~
git clone --depth 100 https://github.com/r-devel/r-svn.git R-devel
cd R-devel
# Optional: parallel package installation (see the PR #278 section)
curl -L https://github.com/r-devel/r-svn/pull/278.diff | git apply

# A git checkout has no SVN metadata; make reads SVNINFO to create SVN-REVISION
{
  echo "Revision: $(git log --grep=git-svn-id -n1 | grep git-svn | cut -d@ -f2 | cut -d' ' -f1)"
  echo "Last Changed Date: $(git log --grep=git-svn-id -n1 --pretty=format:%ad --date=short)"
} | tee SVNINFO > SVN-REVISION

tools/fetch-recommended
```

If you already have an R source tree that has been built before, `cd` into it
and run `make distclean` instead of cloning. Its existing `config.site` can
stay as it is: both options write their flags in a marked block at the end of
`config.site`, which overrides any earlier settings in that file and keeps the
rest (for example an MKL `BLAS_LIBS` line). See
[Pitfalls](#pitfalls-and-issues) for why the flags can't simply go on the
configure command line.

**3. Back up the current install** so you can roll back.

```bash
[ -d /usr/local/lib/R ] && sudo cp -a /usr/local/lib/R /usr/local/lib/R.backup-$(date +%F)
```

To roll back later:
`sudo rm -rf /usr/local/lib/R && sudo mv /usr/local/lib/R.backup-YYYY-MM-DD /usr/local/lib/R`.

### Option A: opt build

Run from the R source directory (`~/R-devel`):

```bash
cd ~/R-devel

OPT="-O3 -march=native -funroll-loops -fno-math-errno -fno-semantic-interposition -fno-plt"
NJ=$(nproc)
CONF="--prefix=/usr/local --enable-R-shlib --enable-lto=R --with-blas --with-lapack"
export MC_CORES=$NJ    # only has an effect with the PR #278 patch

# Write compiler flags as the last lines of config.site, replacing any earlier
# block from this guide. Usage: set_flags "<compiler flags>" ["<extra LDFLAGS>"]
set_flags() {
  sed -i '/^# >>> R_OPTIMIZATION/,/^# <<< R_OPTIMIZATION/d' config.site
  {
    echo "# >>> R_OPTIMIZATION (written by R_OPTIMIZATION.md; delete this block to undo)"
    for v in CFLAGS CXXFLAGS FFLAGS FCFLAGS; do echo "$v=\"$1\""; done
    if [ -n "${2:-}" ]; then echo "LDFLAGS=\"\${LDFLAGS} $2\""; fi
    echo "# <<< R_OPTIMIZATION"
  } >> config.site
}

set_flags "$OPT" "-Wl,--emit-relocs"    # --emit-relocs: keeps libR.so BOLT-ready, no runtime cost
./configure $CONF
grep '^CFLAGS =' Makeconf     # must show the $OPT flags followed by -flto
make -j$NJ PDFLATEX=
make check
sudo make install
```

Then continue with [After either option](#after-either-option).

### Option B: PGO build

Run from the R source directory (`~/R-devel`):

```bash
cd ~/R-devel

OPT="-O3 -march=native -funroll-loops -fno-math-errno -fno-semantic-interposition -fno-plt"
NJ=$(nproc)
CONF="--prefix=/usr/local --enable-R-shlib --enable-lto=R --with-blas --with-lapack"
export MC_CORES=$NJ    # only has an effect with the PR #278 patch
PGO_DIR=$HOME/R-pgo-profile
rm -rf "$PGO_DIR"

# Write compiler flags as the last lines of config.site, replacing any earlier
# block from this guide. Usage: set_flags "<compiler flags>" ["<extra LDFLAGS>"]
set_flags() {
  sed -i '/^# >>> R_OPTIMIZATION/,/^# <<< R_OPTIMIZATION/d' config.site
  {
    echo "# >>> R_OPTIMIZATION (written by R_OPTIMIZATION.md; delete this block to undo)"
    for v in CFLAGS CXXFLAGS FFLAGS FCFLAGS; do echo "$v=\"$1\""; done
    if [ -n "${2:-}" ]; then echo "LDFLAGS=\"\${LDFLAGS} $2\""; fi
    echo "# <<< R_OPTIMIZATION"
  } >> config.site
}

# Stage 1: instrumented build
set_flags "$OPT -fprofile-generate=$PGO_DIR -fprofile-update=atomic" "-fprofile-generate=$PGO_DIR"
./configure $CONF
grep '^CFLAGS =' Makeconf     # must show the $OPT flags, -fprofile-generate=..., and -flto
make -j$NJ PDFLATEX=

# Training run: exercises R and writes the profile to $PGO_DIR
make check
find "$PGO_DIR" -name '*.gcda' | wc -l      # should be several hundred

# Stage 2: rebuild using the profile
make distclean                              # keeps $PGO_DIR and SVNINFO
find "$PGO_DIR" -name '*conftest*' -delete  # see "configure's test programs poison the profile"
set_flags "$OPT -fprofile-use=$PGO_DIR -fprofile-partial-training -Wno-missing-profile -Wno-error=coverage-mismatch" \
          "-Wl,--emit-relocs"    # keeps libR.so BOLT-ready, no runtime cost
./configure $CONF
grep '^CFLAGS =' Makeconf     # must show the $OPT flags, -fprofile-use=..., and -flto
make -j$NJ PDFLATEX=
make check
sudo make install

# Packages built later (including EDI) read the installed Makeconf: remove the PGO flags from it
sudo sed -i -E 's/ -fprofile-use=[^ ]*| -fprofile-partial-training| -Wno-missing-profile| -Wno-error=coverage-mismatch//g' \
    /usr/local/lib/R/etc/Makeconf
grep -c fprofile /usr/local/lib/R/etc/Makeconf    # should print 0
```

Then continue with [After either option](#after-either-option).

### After either option

**Check the new R.**

```bash
hash -r                                      # forget the shell's cached path to R
R --version | head -1
R CMD config CFLAGS                          # shows the $OPT flags
readelf -S /usr/local/lib/R/lib/libR.so | grep -c '\.rela\.text'   # >= 1: relocations kept for BOLT
Rscript -e 'sessionInfo()' | grep -i blas    # shows the BLAS in use
R CMD INSTALL --help | grep jobs             # shows --jobs=N if the PR #278 patch is in
```

**Reinstall packages if the R version changed.** Packages in your user library
(`~/R/...`) and in `/usr/local/lib/R/site-library` are kept by
`make install`. If `R --version` reports the same version as before, they
keep working as is. If it changed, rebuild them:

```r
update.packages(checkBuilt = TRUE, ask = FALSE)
```

and reinstall `EDI` from the repository root:

```bash
R CMD INSTALL R/EDI    # add --jobs=N with the PR #278 patch
```

## Pitfalls and issues

**A `config.site` in the R source tree overrides the configure command line.**
R's configure reads three files *after* taking variables from the command
line: `config.site` in the source directory, then `~/.R/config`, then
`./config.site` in the build directory (the same file as the first, for an
ordinary in-source build). Any `CFLAGS=...` in those files silently replaces
`./configure CFLAGS="..."`. For example, a source tree that already has
`CFLAGS="-O3 -march=native"` in its `config.site` would quietly drop
`-fno-semantic-interposition -fno-plt` or the PGO flags. Options A and B avoid
this with `set_flags`, which writes the flags as the last lines of
`config.site`, and they check `Makeconf` right after configure. To undo,
delete the block between `# >>> R_OPTIMIZATION` and `# <<< R_OPTIMIZATION`.

**Setting `LTO` without `--enable-lto` silently does nothing.** Writing
`LTO="-flto=12"` in `config.site` has no effect unless configure is run with
`--enable-lto`; configure blanks `LTO` otherwise. Check by looking for
`-flto` in the `make` output. Use `--enable-lto=R`, which applies LTO to R
itself only. Plain `--enable-lto` also applies it to every package you install
afterward, including `EDI`, where GCC/RcppEigen LTO has caused severe
slowdowns on some small model-fit kernels (see `EDI_NATIVE_LTO` in the main
README).

**`-fno-semantic-interposition -fno-plt` matter because R is a shared library.**
With `--enable-R-shlib`, calls between functions inside `libR.so` normally go
through the PLT and cannot be inlined, in case some other library overrides
those symbols at load time. These flags remove that indirection. CPython got
5–27% from the same change when built as a shared library
([Fedora](https://fedoraproject.org/wiki/Changes/PythonNoSemanticInterpositionSpeedup)).
The cost is that you can no longer use `LD_PRELOAD` to override functions
inside `libR.so`.

**Never use `-ffast-math`, `-Ofast` or `-ffinite-math-only`.** R stores `NA`
as a NaN with a special payload. These flags let the compiler assume NaNs
never occur, which silently breaks `is.na()`, NA propagation and `NaN`
handling. `-fno-math-errno` alone is fine.

**`-march=native` is not portable.** A binary built with it only runs on CPUs
with the same instruction-set extensions. Do not copy it to a different
machine, a container image, or a cluster with mixed hardware.

**PGO: configure's test programs poison the profile.** In stage 1, every tiny
`conftest` program that configure compiles is also instrumented and writes
profile data. In stage 2, configure compiles different `conftest` programs at
the same paths, gcc finds profile data that doesn't match, and treats it as an
error. Configure then fails with the misleading message
`cannot compute suffix of executables: cannot compile and link`. Option B
handles this by deleting the `conftest` profiles and adding
`-Wno-error=coverage-mismatch`.

**PGO: use `-fprofile-update=atomic`.** R uses OpenMP threads and, with PR
#278, forked workers. Without atomic counter updates, concurrent writers
corrupt the profile counts.

**PGO: strip the flags from the installed `Makeconf`.** R records its
configure flags in `etc/Makeconf`, and `R CMD INSTALL` compiles every package
with them. If you leave `-fprofile-use=...` there, packages get compiled
against a profile that contains nothing about them. The `sed` at the end of
Option B removes those flags.

**PGO: the training workload matters.** PGO only optimizes the code paths the
training run exercises. `make check` is a reasonable general-purpose workload
and gave the numbers above. Training on `EDI` itself would likely help `EDI`
more, but risks making the build over-specific to that workload.

**PGO: how to confirm the profile was used.** In our build, the PGO
`libR.so` was 27% smaller (4.1 MB vs 5.6 MB), because gcc optimized
rarely run code for size. It also had 870 functions with split-off `.cold`
sections (`nm /usr/local/lib/R/lib/libR.so | grep -c '\.cold'`), against 32
without PGO. If neither changes, the profile was not picked up.

**Why both options link with `-Wl,--emit-relocs`.** It keeps `libR.so` ready
for BOLT, LLVM's post-link optimizer, without committing you to using it (see
`R/package_metadata/audits/further_optimizations.md` §6).
- **What it does:** BOLT improves an already-built library by moving its
  machine code around. To do that it must update every reference to each
  piece of code it moves. A normal link discards the list of those
  references (the static relocations), so the installed `libR.so` has no
  `.rela.text` section, and BOLT falls back to a mode that loses most of
  its benefit. `--emit-relocs` keeps the list in the file.
- **Cost:** the extra sections are not loaded when R runs, so speed and
  memory are unchanged. The file is somewhat larger on disk, and `strip`
  removes the sections if you ever want them gone.
- **It also applies to packages.** Because `LDFLAGS` is recorded in
  `Makeconf`, packages you install afterward (including `EDI.so`) are also
  linked with relocations kept, which makes them BOLT-ready too.
- **Why at build time:** adding it now saves a full stage-2 rebuild if you
  later try BOLT.

**A git checkout of R needs `SVNINFO`.** `make` regenerates `SVN-REVISION`
from `git svn info`, falling back to a file named `SVNINFO`. Without it the
build stops with `not an svn checkout`. Shared setup step 2 writes both, the
same way r-devel's own CI does.

**`doc/NEWS.pdf` can fail to build.** It needs pdflatex plus particular TeX
fonts, and fails with errors like `Font eccc1000 at 600 not found`. The
`PDFLATEX=` on the `make` lines above skips it; the PDF is not needed to use R.

**BLAS matters at least as much as compiler flags for linear algebra.** The
reference BLAS that R ships with is far slower than OpenBLAS or MKL for
matrix-heavy code. These flags do not affect BLAS speed. With
`--with-blas --with-lapack`, configure uses `BLAS_LIBS` from `config.site` if
it is set (for example, an Intel MKL link line); otherwise it searches the
system and picks up OpenBLAS from `libopenblas-dev`. After installing, check
which one you got with `sessionInfo()`.

## Parallel package installation (R-devel PR #278)

[r-devel/r-svn PR #278](https://github.com/r-devel/r-svn/pull/278) (open,
not merged into R) runs the CPU-bound steps of `R CMD INSTALL` in parallel
with `parallel::mclapply()`. Those steps are byte-compiling, Rd conversion,
building package indices, parsing R source files and copying `inst/`. This
speeds up installing R itself and installing large R-code packages such as
`EDI`. It does not speed up compiling C/C++ code, which `make -j` already
parallelizes.

The core count comes from `getOption("mc.cores")`, which the `parallel`
package sets from the `MC_CORES` environment variable. The patch also adds an
`R CMD INSTALL --jobs=N` flag that sets both. It does **not** read
`MAKEFLAGS`. `--jobs=N` takes precedence over an `MC_CORES` in
`~/.Renviron`, which would otherwise reset the count in the byte-compile
subprocess (fixed locally 2026-10-15 in `install.R`'s `R_runR_deps_only()`;
not yet in the installed R or the PR).

```bash
R CMD INSTALL --jobs=8 R/EDI
# in R:  install.packages("pkg", INSTALL_opts = "--jobs=8")
# or for every install (also changes the default core count for all mclapply() calls):
echo "MC_CORES=$(nproc)" >> ~/.Renviron
```

When building R itself, the `export MC_CORES=$NJ` line in both options makes
the base packages byte-compile in parallel.

## Reproducing the benchmark

1. Build each R variant **out of tree** from one clean source copy, so they
   share identical sources. Configure loads `./config.site` from the build
   directory last, so a per-variant `config.site` can add flags on top of the
   source tree's. For example:
   `CFLAGS="${CFLAGS} -fno-semantic-interposition -fno-plt"`.
2. Point every variant at the same package library, so only R itself differs:
   `R_LIBS_USER=~/R/x86_64-pc-linux-gnu-library/4.7 R_LIBS_SITE=/usr/local/lib/R/site-library`.
3. Run the test from a **copy** of `R/package_tests` (with `_dataset_load.R`,
   `prune_stale_result_rows.R`, and
   `R/EDI/tests/testthat/helper-likelihood-method-smoke.R` at the same relative
   paths). Delete its result CSV before each run. The script reads the
   existing results file and skips rows it has already computed, so a
   leftover file makes the next run do less work.
4. Run each variant on an otherwise idle machine. Wrap each run in
   `/usr/bin/time -v` to get user and system CPU, and repeat the baseline at
   the end to measure drift.
5. Compare the per-call `duration_time_sec` columns of the result CSVs,
   matched on `response_type`, `inference_class`, `function_run`, `beta_T` and
   `id`. Also compare `result_1`, `result_2` and `status` to confirm the builds
   give identical results.

Expect each run of `pte_example` / Bernoulli / rep 1 to take about 3 hours on
a 6-core laptop. The `diamonds` dataset takes considerably longer.
