#!/usr/bin/env bash
# Regenerates the lines-of-code table in README.md, splicing the fresh cloc
# output between the <!-- cloc-table-start --> / <!-- cloc-table-end -->
# markers. Called by .githooks/pre-push; safe to run manually from anywhere
# in the repo.
set -euo pipefail

repo_root="$(git rev-parse --show-toplevel)"
cd "$repo_root"

if ! command -v cloc >/dev/null 2>&1; then
	echo "update_readme_cloc.sh: cloc is not installed; leaving README.md unchanged." >&2
	exit 0
fi

# --vcs=git restricts the count to git-tracked files so untracked local
# artifacts (python/.venv, build outputs) don't skew the numbers. The first
# three lines of `cloc --md` output are a cloc-version banner, not the table.
#
# cloc's own --md output puts a SECOND `--------|--------|...` divider line
# directly before the SUM row, mimicking a visual separator for plain-text
# viewing -- but GFM tables only recognize ONE separator row (immediately
# after the header), so that second divider renders as a literal row of
# dashes instead of a rule. Strip it and bold the SUM row instead, which is
# valid GFM and renders as an actual visual total row.
table="$(cloc --quiet --md --vcs=git \
	--include-lang="R,Python,C,C++,C/C++ Header" \
	--exclude-ext="Rd,rd" . | tail -n +4 \
	| grep -vE '^-+\|' \
	| awk -F'|' 'BEGIN{OFS="|"} /^SUM:/{for(i=1;i<=NF;i++) $i="**"$i"**"} {print}')"

awk -v table="$table" '
	/<!-- cloc-table-start -->/ { print; print table; skipping = 1; next }
	/<!-- cloc-table-end -->/   { skipping = 0 }
	!skipping                   { print }
' README.md > README.md.tmp && mv README.md.tmp README.md
