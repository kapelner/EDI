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
#      such as -march=native Makevars flags or sandbox device files leaking
#      into the tarball), with --compact-vignettes=gs+qpdf.
#   2. Uploads the tarball to win-builder (R-release and R-devel) via FTP.
#      This is the long-documented, stable CRAN submission mechanism:
#      https://win-builder.r-project.org/ -- upload by anonymous FTP, results
#      emailed to the maintainer address in DESCRIPTION.
#   3. Prints instructions for mac-builder. mac-builder
#      (https://mac.r-project.org/macbuilder/submit.html) has never had a
#      documented FTP/API upload path -- only a web upload form. This script
#      does not fabricate one; it stops short and tells you what to do
#      manually.
#
# This script only builds (R CMD build); it deliberately never runs
# R CMD check -- that is a full compile of the package and must not be run
# without being asked fresh in that turn (see CLAUDE.md).
#
# Requires R CMD build to be free of package.check errors and: qpdf, ghostscript
# (gs) for --compact-vignettes; curl for the FTP upload.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
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

echo "== 2. R CMD build (--compact-vignettes=gs+qpdf) =="
cd "$SCRATCH_DIR"
R CMD build EDI --compact-vignettes=gs+qpdf

TARBALL="$(ls -1 "$SCRATCH_DIR"/EDI_*.tar.gz | sort -V | tail -n1)"
if [[ -z "$TARBALL" ]]; then
  echo "ERROR: no tarball produced by R CMD build" >&2
  exit 1
fi
echo "Built: $TARBALL"

echo "== 3. Uploading to win-builder (R-release and R-devel) =="
echo "  (anonymous FTP; results are emailed to the maintainer address in DESCRIPTION)"
curl -sS -T "$TARBALL" ftp://win-builder.r-project.org/R-release/
curl -sS -T "$TARBALL" ftp://win-builder.r-project.org/R-devel/
echo "Uploaded to win-builder R-release and R-devel. Watch for the results email."

echo ""
echo "== 4. mac-builder: NO SCRIPTABLE UPLOAD PATH =="
echo "mac-builder does not expose an FTP/API upload endpoint, only a web form."
echo "Submit the tarball manually:"
echo "  1. Open https://mac.r-project.org/macbuilder/submit.html in a browser."
echo "  2. Upload: $TARBALL"
echo "  3. Submit and wait for the results email."
echo ""
echo "Tarball retained at: $TARBALL"
echo "(scratch build directory: $SCRATCH_DIR)"
