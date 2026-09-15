#!/usr/bin/env bash
# Runs once when this devcontainer is first created (devcontainer.json's
# postCreateCommand). Gets a fresh checkout to a state where both packages
# in this repo can be tested immediately: R/EDI installed and loadable,
# edi_kernels importable from an editable install.
#
# IMPORTANT for any agent working inside this container afterward: this
# script's own R/EDI build below is the ONE expected full compile for this
# environment -- it is what a devcontainer's initial setup is for, and
# there is no live build of the user's own to race inside a fresh,
# isolated container. It does NOT relax AGENTS.md/CLAUDE.md's rule against
# compiling R/EDI without the user's explicit permission in the current
# conversation for anything after this point: once the container is up,
# treat it exactly like any other checkout of this repo and ask first
# before installing/building/reloading-with-compilation again.
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."

echo "==> Installing R/EDI's Imports + Suggests + LinkingTo from DESCRIPTION"
Rscript -e 'pak::local_install_deps("R/EDI", dependencies = TRUE, ask = FALSE)'

echo "==> Building and installing R/EDI (one-time devcontainer bootstrap -- see this script's header comment)"
R_INSTALL_CMD="INSTALL"
R CMD "$R_INSTALL_CMD" R/EDI

echo "==> Installing edi_kernels (editable) + test deps"
python3 -m pip install --upgrade pip
pip install -e "./python[test]"

# Full unattended-installable roster from
# R/package_metadata/new_feature_plans/performance_profiling_and_upgrades.md
# section 8.0: perf, valgrind (callgrind/cachegrind/dhat/massif/helgrind),
# gdb, heaptrack, hyperfine, FlameGraph, kcachegrind, + 19 profiling-related
# R packages, + several pip profilers. Deliberately excludes the vendor/
# licensed tools (Intel VTune/Advisor/SDE/Pin, AMD uProf) the script itself
# only prints instructions for -- see that script's own final section --
# since those need manual/licensed installs and mostly need bare-metal
# hardware-counter access unavailable in a container anyway. Non-fatal: the
# script already degrades individual failed tools gracefully, but the whole
# thing running under this script's own `set -e` must not abort R/EDI or
# edi_kernels setup above, so failures here are logged and swallowed.
echo "==> Installing performance-profiling tools (perf, valgrind, and the rest of the roster)"
bash R/profile/install_perf_tools.sh || echo "profiling-tools install had failures (non-fatal, see above) -- rerun bash R/profile/install_perf_tools.sh or bash R/profile/verify_perf_tools.sh later"

# CRAN/GitHub packages for R/package_metadata/experimental_datasets.md's
# real-experiment datasets (covariate-source-only and real-assignment-replay
# modes) -- ordinary package installs, no external identity submitted
# anywhere, so these always run. Non-fatal per-package (mirrors
# experimental_datasets.md's own install snippet).
echo "==> Installing experimental-dataset R packages (medicaldata, qte, AER, ...)"
Rscript -e '
pkgs <- c("medicaldata", "qte", "AER", "stevedata", "whatifbandit", "cjoint",
          "WSCdata", "DigestiveDataSets", "NeuroDataSets", "CardioDataSets",
          "rpsftm", "ForCausality", "experiment", "GK2011", "endorse",
          "ecoteach", "epifitter", "callback", "survival", "geepack", "remotes")
pkgs <- setdiff(pkgs, rownames(installed.packages()))
if (length(pkgs)) tryCatch(install.packages(pkgs), error = function(e) message("some dataset packages failed: ", conditionMessage(e)))
if (!requireNamespace("experimentdatar", quietly = TRUE)) {
  tryCatch(remotes::install_github("itamarcaspi/experimentdatar", upgrade = "never"),
           error = function(e) message("experimentdatar failed: ", conditionMessage(e)))
}
' || echo "experimental-dataset R packages had failures (non-fatal, see above)"

# The Dataverse-sourced datasets (R/package_metadata/icpsr_download.R,
# "mechanism 1") need no account, but DO submit a name/email/institution to
# each dataset's Dataverse guestbook -- and the script's own fallback
# default for that identity is the repo owner's personal name and email
# (see dataverse_guestbook_identity() in that script), not a generic
# placeholder. Auto-running this unconditionally would submit the repo
# owner's identity on behalf of every fork/contributor who spins up this
# devcontainer without knowing that. So: only run it when EDI_DATAVERSE_EMAIL
# is explicitly set (e.g. in your own Codespaces/devcontainer secrets or
# `remoteEnv`) -- never fall back to the script's own default here.
if [ -n "${EDI_DATAVERSE_EMAIL:-}" ]; then
  echo "==> Downloading experiment datasets from Dataverse (EDI_DATAVERSE_EMAIL is set)"
  Rscript R/package_metadata/icpsr_download.R || echo "icpsr_download.R had failures (non-fatal, see above)"
else
  echo "==> Skipping Dataverse dataset download: EDI_DATAVERSE_EMAIL is not set."
  echo "    Set EDI_DATAVERSE_EMAIL (and optionally EDI_DATAVERSE_INSTITUTION) to your own"
  echo "    identity, then run: Rscript R/package_metadata/icpsr_download.R"
  echo "    See R/package_metadata/experimental_datasets.md for why this isn't automatic."
fi

echo "==> devcontainer setup complete: R/EDI is installed, edi_kernels is importable"
echo "    Try: Rscript -e 'library(EDI); packageVersion(\"EDI\")'"
echo "    Try: python3 -c 'import edi_kernels; print(edi_kernels.__file__)'"
echo "    Verify profiling tools: bash R/profile/verify_perf_tools.sh"
echo "    ccache stats (see Dockerfile for the ~/.R/Makevars wiring):"
ccache -s || true
