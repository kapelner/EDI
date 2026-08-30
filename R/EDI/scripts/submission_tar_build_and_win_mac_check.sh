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
#      EDI_PORTABLE=0 is configure's default, and that build embeds
#      -march=native/-mtune=native (targets the build machine's exact CPU --
#      non-portable) and an `override CXXFLAGS +=` line (discards R's own
#      configured flags instead of appending via PKG_CXXFLAGS) into
#      src/Makevars -- both are CRAN policy violations, and win-builder/
#      mac-builder both flag them ("checking compilation flags in Makevars
#      ... WARNING"). Confirmed in practice 2026-08-28: a tarball built
#      without this flag got that exact warning on mac-builder after
#      submission -- this script builds it itself specifically so that
#      mistake can't recur.
#
#      That said, EDI_PORTABLE=1 here only controls the temporary install
#      `R CMD build` performs for vignette rebuilding -- it has NO effect on
#      what happens when win-builder/mac-builder/CRAN later run
#      `R CMD INSTALL` on the uploaded tarball, because configure reruns at
#      *install* time and none of those machines set EDI_PORTABLE, so
#      configure's own default (0, non-portable) wins regardless. Confirmed
#      2026-08-29: win-builder and mac-builder both reproduced the
#      non-portable-flags WARNING even though this script's step 2 already
#      used EDI_PORTABLE=1. To fix that for real, this script patches the
#      SCRATCH COPY of configure (never the repo's real
#      R/EDI/configure) so that an *unset* EDI_PORTABLE defaults to the
#      portable build in the shipped tarball -- while local dev checkouts of
#      the real repo file keep the native-tuned default unchanged. Nothing
#      needs reverting: the scratch copy is discarded with the rest of
#      $SCRATCH_DIR.
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

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
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

echo "== 1a. Patching scratch copy's configure so an UNSET EDI_PORTABLE defaults to the portable build =="
echo "  (only $CLEAN_PKG_DIR/configure is touched -- the real repo file is never modified)"
CONFIGURE_DEFAULT_LINE='edi_portable="$(env_or_default EDI_PORTABLE 0)"'
CONFIGURE_PATCHED_LINE='edi_portable="$(env_or_default EDI_PORTABLE 1)"'
if ! grep -qF "$CONFIGURE_DEFAULT_LINE" "$CLEAN_PKG_DIR/configure"; then
  echo "ERROR: expected line not found in $CLEAN_PKG_DIR/configure -- configure's EDI_PORTABLE default logic may have changed; update this script's patch to match." >&2
  exit 1
fi
CONFIGURE_DEFAULT_LINE="$CONFIGURE_DEFAULT_LINE" CONFIGURE_PATCHED_LINE="$CONFIGURE_PATCHED_LINE" \
  perl -i -pe 's/\Q$ENV{CONFIGURE_DEFAULT_LINE}\E/$ENV{CONFIGURE_PATCHED_LINE}/' "$CLEAN_PKG_DIR/configure"
if ! grep -qF "$CONFIGURE_PATCHED_LINE" "$CLEAN_PKG_DIR/configure"; then
  echo "ERROR: patch of $CLEAN_PKG_DIR/configure did not take effect." >&2
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
  echo "ERROR: the SHIPPED tarball's configure still defaults to non-portable flags when EDI_PORTABLE is unset -- do not submit this tarball. The scratch-copy patch in step 1a did not take effect; investigate before retrying." >&2
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
