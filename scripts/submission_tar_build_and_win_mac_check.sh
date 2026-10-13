#!/usr/bin/env bash
# Build the EDI release tarball and submit it to CRAN's win-builder.
#
# RUN THIS YOURSELF, ON YOUR OWN MACHINE. It is not meant to be executed by
# an agent: win-builder.r-project.org and mac.r-project.org are not reachable
# from a sandboxed agent environment, and this is a manual, once-per-release
# pre-submission step, not something to run on every push (see release.md).
#
# What this script does:
#   1. Builds the tarball from a clean checkout (avoids stray dev-tree files
#      such as sandbox device files leaking into the tarball) with
#      EDI_PORTABLE=1 forced and --compact-vignettes=gs+qpdf. EDI_PORTABLE=1
#      is NOT optional and is not left to the caller's environment: it is
#      set directly on the `R CMD build` invocation below, unconditionally.
#      An EDI_PORTABLE=0 build embeds -march=native/-mtune=native (targets
#      the build machine's exact CPU -- non-portable) and an
#      `override CXXFLAGS +=` line into src/Makevars -- both CRAN policy
#      violations that win-builder/mac-builder flag ("checking compilation
#      flags in Makevars ... WARNING"; confirmed 2026-08-28).
#
#      Since 2026-10-14 configure itself defaults to EDI_PORTABLE=1 (decision
#      D1, cross_platform_reproducibility.md), so the shipped tarball installs
#      portably on win-builder/mac-builder/CRAN with no EDI_PORTABLE set.
#      Before that the default was 0 and this script patched the scratch copy
#      of configure (needed because configure reruns at *install* time, where
#      the build-time EDI_PORTABLE=1 has no effect; confirmed 2026-08-29).
#      Step 1a now only verifies that the default is still portable, and
#      step 2b checks the generated Makevars end to end.
#   1b. Fails fast, before the slow build, if any Rd example uses \dontrun{}
#      or has unparseable example code (e.g. a \donttest{} nested inside a
#      \dontrun{} -- CRAN's "Unexecutable code in man/X.Rd" warning), via
#      scripts/check_examples_for_cran.R --static-only. CRAN reviewers reject
#      \dontrun{} on code that can actually run (confirmed 2026-09-25 review).
#   1c. Fails fast, before the slow build, if the R sources write to the
#      global environment: an assign()/rm()/`$<-` into .GlobalEnv (other than
#      restoring .Random.seed), an attach(), or a `<<-` whose target is not a
#      variable of an enclosing function (only those can reach .GlobalEnv), via
#      scripts/check_global_state_for_cran.R --static-only. CRAN rejected the
#      2026-09-25 submission for modifying .GlobalEnv and the user's options().
#   1d. Fails fast, before the slow build, if any Rd file's \usage has an
#      undocumented argument (or a documented one that isn't in \usage), via
#      scripts/check_rd_usage_for_cran.R (tools::checkDocFiles()) -- the check behind R CMD check's "checking Rd
#      \usage sections ... WARNING", which step 3 only reports as a WARNING and
#      so would not stop the upload (the 2026-09-25 generate_permutations_*_cpp
#      Rd files slipped through exactly that way).
#   2. Runs `R CMD check --as-cran` on the built tarball (NOT_CRAN=false) and
#      prints the full output to screen -- this is the same check CRAN's own
#      submission queue runs first, so seeing it clean here before uploading
#      catches most rejections locally instead of by email days later. This
#      step is genuinely slow (a full compile + the whole check machinery);
#      that cost is the point of a pre-submission script, not something to
#      route around here. Aborts before uploading if the check reports any
#      ERROR; WARNINGs/NOTEs are shown but don't block (win-builder/
#      mac-builder exist specifically to catch platform-specific issues this
#      local run can't, and the "New submission" NOTE is unavoidable).
#   2a. (Printed as step 3a.) Runs every Rd file's examples against the build R CMD check just
#      installed (scripts/check_examples_for_cran.R --lib EDI.Rcheck) and
#      aborts if any errors, or if any Rd file's examples (without their
#      \donttest{} code) take longer than EDI_EXAMPLE_TIME_LIMIT seconds
#      (default 2.5 -- well under CRAN's 5 s, since CRAN's machines are
#      slower). R CMD check only NOTEs slow examples; CRAN's reviewers then
#      reject them. \donttest{} code is also run and must not error, but is
#      not time-limited.
#   2b. (Printed as step 3b.) Loads the build R CMD check just installed and
#      runs EDI's load, parallel (set_num_cores), SimulationFramework and
#      InferenceSuite entry points, aborting if any of them leaves options(),
#      the working directory, the objects in .GlobalEnv or (for seeded runs)
#      .Random.seed changed (scripts/check_global_state_for_cran.R --lib
#      EDI.Rcheck). Step 3a's example run also fails any Rd example that
#      changes options(), the working directory or .GlobalEnv.
#   3. Prints instructions for win-builder. Submission is via a web form at
#      https://win-builder.r-project.org/upload.aspx -- an ASP.NET webform
#      (dynamic viewstate tokens per page load), not a stable curl/FTP
#      target, so like mac-builder below this script does not attempt to
#      script it; it stops short and tells you what to do manually. Results
#      are emailed to the maintainer address in DESCRIPTION.
#   4. Prints instructions for mac-builder. mac-builder
#      (https://mac.r-project.org/macbuilder/submit.html) has never had a
#      documented FTP/API upload path -- only a web upload form. This script
#      does not fabricate one; it stops short and tells you what to do
#      manually.
#
# This script DOES run a full `R CMD build` + `R CMD check --as-cran` --
# that is exactly what a pre-submission script is for. The CLAUDE.md rule
# against full builds/checks is about an AGENT running them against the
# shared working copy unasked; this script is meant to be run BY YOU, on
# YOUR machine, against a throwaway scratch copy, and only when you
# explicitly invoke it -- not something an agent executes on its own.
#
# Requires: qpdf, ghostscript (gs) for --compact-vignettes. win-builder/mac-builder
# uploads are both manual web-form steps printed at the end -- no upload tooling required.

set -euo pipefail

# The whole body is one { ... } block so bash parses the entire file before
# running any of it. Bash otherwise reads a script from disk incrementally, so
# editing this file while it runs (the build/check steps take many minutes)
# makes the running copy resume mid-line and die with a bogus "syntax error".
{

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PKG_DIR="$REPO_ROOT/R/EDI"
SCRATCH_DIR="$(mktemp -d -t edi_release_build.XXXXXX)"
CLEAN_PKG_DIR="$SCRATCH_DIR/EDI"

echo "== 1. Building clean copy of $PKG_DIR at $CLEAN_PKG_DIR (excluding .claude/.git/build artifacts) =="
rsync -a \
  --exclude='.claude' \
  --exclude='.git' \
  --exclude='src/*.o' \
  --exclude='src/*.so' \
  --exclude='src/*.dll' \
  "$PKG_DIR/" "$CLEAN_PKG_DIR/"

echo "== 1a. Verifying configure defaults to the portable build when EDI_PORTABLE is unset =="
CONFIGURE_DEFAULT_LINE='edi_portable="$(env_or_default EDI_PORTABLE 1)"'
if ! grep -qF "$CONFIGURE_DEFAULT_LINE" "$CLEAN_PKG_DIR/configure"; then
  echo "ERROR: $CLEAN_PKG_DIR/configure no longer defaults EDI_PORTABLE to 1 -- CRAN would install a non-portable build. Restore the portable default (see R/EDI/configure) before submitting." >&2
  exit 1
fi

EXAMPLES_CHECK="$REPO_ROOT/scripts/check_examples_for_cran.R"
echo "== 1b. Static example checks: no \\dontrun{}, all example code parses =="
if ! Rscript "$EXAMPLES_CHECK" "$CLEAN_PKG_DIR" --static-only; then
  echo "ERROR: Rd examples have problems CRAN will reject (listed above) -- not building. Fix the roxygen @examples in R/, regenerate man/ (Rscript R/fast_roxygenize.R) and re-run this script." >&2
  exit 1
fi

GLOBAL_STATE_CHECK="$REPO_ROOT/scripts/check_global_state_for_cran.R"
echo "== 1c. Static global-environment checks: no .GlobalEnv writes, no unsafe <<-, no attach() =="
if ! Rscript "$GLOBAL_STATE_CHECK" "$CLEAN_PKG_DIR" --static-only; then
  echo "ERROR: the R sources modify the global environment in ways CRAN rejects (listed above) -- not building. Use a local environment instead (see https://contributor.r-project.org/cran-cookbook/code_issues.html#writing-to-the-.globalenv) and re-run this script." >&2
  exit 1
fi

echo "== 1d. Rd \\usage checks: every function argument documented (tools::checkDocFiles) =="
if ! Rscript "$REPO_ROOT/scripts/check_rd_usage_for_cran.R" "$CLEAN_PKG_DIR"; then
  echo "ERROR: Rd files have undocumented arguments (listed above) -- CRAN flags this as a WARNING. Add the missing @param entries in the roxygen source (R/ or //' comments in src/), regenerate man/ (Rscript R/fast_roxygenize.R) and re-run this script." >&2
  exit 1
fi

echo "== 2. R CMD build (EDI_PORTABLE=1, --compact-vignettes=gs+qpdf) =="
cd "$SCRATCH_DIR"
EDI_PORTABLE=1 R CMD build EDI --compact-vignettes=gs+qpdf

TARBALL="$(ls -1 "$SCRATCH_DIR"/EDI_*.tar.gz | sort -V | tail -n1)"
if [[ -z "$TARBALL" ]]; then
  echo "ERROR: no tarball produced by R CMD build" >&2
  exit 1
fi
echo "Built: $TARBALL"

echo "== 2a. Copying tarball to repo root (overwriting any existing EDI_*.tar.gz there) =="
rm -f "$REPO_ROOT"/EDI_*.tar.gz
cp "$TARBALL" "$REPO_ROOT/$(basename "$TARBALL")"
TARBALL="$REPO_ROOT/$(basename "$TARBALL")"
echo "Copied to: $TARBALL"

echo "== 2b. Verifying the SHIPPED tarball's configure defaults to a portable Makevars when EDI_PORTABLE is left UNSET =="
echo "  (this simulates exactly what win-builder/mac-builder/CRAN do at install time -- no EDI_PORTABLE in their environment)"
VERIFY_DIR="$SCRATCH_DIR/verify_portable_default"
mkdir -p "$VERIFY_DIR"
tar xzf "$TARBALL" -C "$VERIFY_DIR"
(
  cd "$VERIFY_DIR/EDI"
  R_HOME="$(R RHOME)"
  export R_HOME
  unset EDI_PORTABLE
  ./configure
)
GENERATED_MAKEVARS="$VERIFY_DIR/EDI/src/Makevars"
if [[ ! -f "$GENERATED_MAKEVARS" ]]; then
  echo "ERROR: shipped configure did not produce src/Makevars -- cannot verify portability." >&2
  exit 1
fi
if grep -qE -- '-march=native|-mtune=native|override CXXFLAGS' "$GENERATED_MAKEVARS"; then
  echo "ERROR: the SHIPPED tarball's configure still defaults to non-portable flags when EDI_PORTABLE is unset -- do not submit this tarball. Check configure's EDI_PORTABLE default (step 1a) before retrying." >&2
  cat "$GENERATED_MAKEVARS" >&2
  exit 1
fi
echo "Confirmed: shipped configure's default (EDI_PORTABLE unset) produces a portable Makevars."
rm -rf "$VERIFY_DIR"

echo "== 3. R CMD check --as-cran (this is the slow part -- full compile + full check) =="
echo "  R_MAKEVARS_USER overrides this machine's own R Makeconf (which bakes -march=native"
echo "  into R's global CXXFLAGS here -- see \$(R CMD config CXXFLAGS); that is a local-R-build"
echo "  artifact, appended AFTER PKG_CXXFLAGS by R's own compile rule). A plain CXXFLAGS=... env"
echo "  var does NOT override it -- GNU Make gives a makefile's own plain assignment (Makeconf's"
echo "  'CXXFLAGS = -O3 -march=native ...') precedence over an inherited environment variable of"
echo "  the same name; confirmed by testing directly on this machine. A personal Makevars file"
echo "  (R_MAKEVARS_USER) is processed with higher precedence than Makeconf per Writing R"
echo "  Extensions, and does take effect -- also confirmed by testing directly. win-builder/"
echo "  mac-builder/CRAN's R builds don't have -march=native in Makeconf to begin with, so"
echo "  leaving it in here would produce a 'compilation flags used' NOTE that will not"
echo "  reproduce there and should not be copied into cran-comments.md."
echo "  EDI_SKIP_LOCAL_TUNING=1 suppresses this machine's saved-tuning startup message"
echo "  (from a previous local tune_EDI_for_this_machine() run) -- win-builder/mac-builder/"
echo "  CRAN have no such saved tuning file so would never print it either; without this,"
echo "  the check log here would contain local-machine-only noise not safe to paste as-is."
USER_MAKEVARS_OVERRIDE="$SCRATCH_DIR/user_makevars_override"
echo "CXXFLAGS = -O3" > "$USER_MAKEVARS_OVERRIDE"
CHECK_LOG="$SCRATCH_DIR/check.log"
set +e
(cd "$SCRATCH_DIR" && NOT_CRAN=false EDI_SKIP_LOCAL_TUNING=1 R_MAKEVARS_USER="$USER_MAKEVARS_OVERRIDE" R CMD check --as-cran "$(basename "$TARBALL")" 2>&1 | tee "$CHECK_LOG")
CHECK_EXIT=$?
set -e
CHECK_DIR="$SCRATCH_DIR/EDI.Rcheck"
if [[ -f "$CHECK_DIR/00check.log" ]]; then
  echo ""
  echo "-- 00check.log summary --"
  tail -n 20 "$CHECK_DIR/00check.log"
fi
if [[ "$CHECK_EXIT" -ne 0 ]] || grep -qE '^Status:.*ERROR' "$CHECK_LOG"; then
  echo "ERROR: R CMD check --as-cran reported an ERROR (see output above / $CHECK_LOG) -- not uploading. Fix the ERROR and re-run this script." >&2
  exit 1
fi
echo "R CMD check --as-cran completed with no ERROR (WARNINGs/NOTEs, if any, are shown above -- review them, but they don't block upload)."

echo ""
echo "== 3a. Timing every Rd file's examples against the build R CMD check installed (limit ${EDI_EXAMPLE_TIME_LIMIT:-2.5}s each, excluding \\donttest{}) =="
if ! NOT_CRAN=false EDI_SKIP_LOCAL_TUNING=1 _R_CHECK_LIMIT_CORES_=true OMP_THREAD_LIMIT=2 \
    Rscript "$EXAMPLES_CHECK" "$CLEAN_PKG_DIR" --lib "$CHECK_DIR"; then
  echo "ERROR: Rd examples fail or are too slow for CRAN (listed above) -- not uploading. Unwrap/shrink them, or move the slow part into \\donttest{}, then regenerate man/ and re-run this script." >&2
  exit 1
fi

echo ""
echo "== 3b. Runtime global-state check: loading EDI and running its entry points must leave options(), the working directory, .GlobalEnv and .Random.seed unchanged =="
if ! NOT_CRAN=false EDI_SKIP_LOCAL_TUNING=1 _R_CHECK_LIMIT_CORES_=true OMP_THREAD_LIMIT=2 \
    Rscript "$GLOBAL_STATE_CHECK" "$CLEAN_PKG_DIR" --lib "$CHECK_DIR"; then
  echo "ERROR: EDI changes the user's global state (listed above) -- not uploading. CRAN requires options()/par()/setwd() changes inside functions to be undone with an immediate on.exit(), and forbids writing to .GlobalEnv or changing .Random.seed. Fix and re-run this script." >&2
  exit 1
fi

echo ""
echo "== 4. win-builder: NO SCRIPTABLE UPLOAD PATH -- web form only =="
echo "Upload it:"
echo "  1. Open https://win-builder.r-project.org/upload.aspx in a browser."
echo "  2. Read the instructions/disclaimer at https://win-builder.r-project.org/ first if you haven't."
echo "  3. Upload: $TARBALL"
echo "     Submit to R-release and R-devel (upload separately to each section on the page)."
echo "  4. Results are emailed to the maintainer address in DESCRIPTION."

echo ""
echo "== 5. mac-builder: NO SCRIPTABLE UPLOAD PATH =="
echo "mac-builder does not expose an FTP/API upload endpoint, only a web form."
echo "Submit the tarball manually:"
echo "  1. Open https://mac.r-project.org/macbuilder/submit.html in a browser."
echo "  2. Upload: $TARBALL"
echo "  3. Submit and wait for the results email."
echo ""
echo "Tarball retained at: $TARBALL"
echo "(scratch build directory: $SCRATCH_DIR)"

exit 0
}
