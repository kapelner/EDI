#!/usr/bin/env bash
# Reinstall EDI when a pull/merge/rebase brought in changes to what goes into
# the installed package, so the installed EDI never lags the checkout.
#
# Why (2026-11-17): a C++ change merged on GitHub (the compiled-code audit's
# PR) arrives through `git pull`, which never rebuilds. pre-push only looks at
# what is being pushed, so it can't notice; the installed EDI stayed one C++
# change behind until a manual R CMD INSTALL.
#
# Called by scripts/post-merge and scripts/post-rewrite (core.hooksPath =
# scripts) with the pre-update commit as $1. Make's incremental build means
# only the changed unity groups recompile. Set EDI_SKIP_POST_PULL_INSTALL=1
# to skip. A failed install never fails the pull itself (git ignores these
# hooks' exit status); it just says so.

old="${1:-}"
[ -n "${EDI_SKIP_POST_PULL_INSTALL:-}" ] && exit 0
[ -n "$old" ] || exit 0
git rev-parse --verify --quiet "$old^{commit}" > /dev/null || exit 0

cd "$(git rev-parse --show-toplevel)" || exit 0

# Same path set as pre-push's install gate.
changed="$(git diff --name-only "$old" HEAD -- R/EDI | grep -E '^R/EDI/(R/|src/|inst/|data/|DESCRIPTION$|NAMESPACE$|configure(\.win)?$)')"
[ -n "$changed" ] || exit 0

# src/ first, so C++ changes are never hidden behind the 10-file cap.
changed="$( { printf '%s\n' "$changed" | grep '^R/EDI/src/'; printf '%s\n' "$changed" | grep -v '^R/EDI/src/'; } )"

n="$(printf '%s\n' "$changed" | wc -l)"
echo "post-pull: $n EDI package file(s) changed -- reinstalling EDI (incremental; EDI_SKIP_POST_PULL_INSTALL=1 skips):"
printf '%s\n' "$changed" | head -10 | sed 's/^/  /'
[ "$n" -gt 10 ] && echo "  ... and $((n - 10)) more"
# configure drops every unity_NN.o older than a changed header, and the
# shared headers are included by every group, so this is a full recompile.
headers="$(printf '%s\n' "$changed" | grep -E '^R/EDI/src/.*\.(h|hpp)$')"
if [ -n "$headers" ]; then
	echo "post-pull: header changed ($(printf '%s\n' "$headers" | sed 's|^R/EDI/src/||' | paste -sd, - | sed 's/,/, /g')): all unity groups will recompile (several minutes); set EDI_SKIP_POST_PULL_INSTALL=1 to defer"
fi
if R CMD INSTALL R/EDI; then
	echo "post-pull: EDI reinstalled."
else
	echo "post-pull: EDI install FAILED -- the installed EDI is out of date; run R CMD INSTALL R/EDI." >&2
fi
exit 0
