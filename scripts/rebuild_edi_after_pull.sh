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

# Same path set as pre-push's install gate. An R or C/C++ file whose edits
# are only comments or whitespace is not a code change (owner ruling
# 2026-11-17), so it goes through scripts/significant_changes.py like every
# other change gate; if that helper fails, every changed file counts.
pkg_paths='^R/EDI/(R/|src/|inst/|data/|DESCRIPTION$|NAMESPACE$|configure(\.win)?$)'
ignored_log="$(mktemp)"
trap 'rm -f "$ignored_log"' EXIT
if all_changed="$(python3 scripts/significant_changes.py --report-ignored "$old" HEAD -- R/EDI 2> "$ignored_log")"; then
	ignored_src="$(sed -n 's|^  R/EDI/src/||p' "$ignored_log")"
else
	all_changed="$(git diff --name-only "$old" HEAD -- R/EDI)"
	ignored_src=""
fi
changed="$(printf '%s\n' "$all_changed" | grep -E "$pkg_paths")"

# git rewrote the comment-only sources, so they are now newer than objects
# built from the same code: configure would drop those unity_NN.o files (and
# make would rebuild per-file .o files), a full recompile when a header is
# among them. Re-stamp each object whose only newer sources are such files.
# An object that was already older than some other source is left alone.
if [ -n "$ignored_src" ] && [ -d R/EDI/src ]; then
	is_ignored() { printf '%s\n' "$ignored_src" | grep -qxF "$1"; }
	headers_all="$(cd R/EDI/src && ls -1 *.h *.hpp 2>/dev/null | grep -vx 'edi_build_flags.h')"
	restamped=0
	for obj in R/EDI/src/*.o; do
		[ -f "$obj" ] || continue
		base="${obj%.o}"
		case "$(basename "$base")" in
			unity_[0-9]*) [ -f "$base.cpp" ] || continue
				members="$(sed -n 's/^#include "\(.*\)"$/\1/p' "$base.cpp"; printf '%s\n' "$headers_all")" ;;
			*) [ -f "$base.cpp" ] || continue
				members="$(basename "$base").cpp" ;;
		esac
		hit=""; other_newer=""
		for m in $members; do
			[ -f "R/EDI/src/$m" ] && [ "R/EDI/src/$m" -nt "$obj" ] || continue
			if is_ignored "$m"; then hit=1; else other_newer=1; break; fi
		done
		if [ -n "$hit" ] && [ -z "$other_newer" ]; then
			touch -c "$obj" && restamped=$((restamped + 1))
		fi
	done
	[ "$restamped" -gt 0 ] && echo "post-pull: $(printf '%s\n' "$ignored_src" | wc -l) C/C++ file(s) changed only in comments/whitespace; re-stamped $restamped object(s) so they do not recompile."
fi
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
