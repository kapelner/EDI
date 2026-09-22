#!/usr/bin/env bash
# Generates the two lines-of-code badge JSONs + full-table Markdown page that
# scripts/publish_loc_badge_gist.sh pushes to a Gist on every push to main
# (see .github/workflows/loc-badge.yml).
#
# Bash + jq rather than Python: a sibling script that's just a cloc wrapper
# doesn't need to be a .py file, and build-wheels.yml's push trigger matches
# "**/*.py" anywhere in the repo (intentionally broad -- see that workflow's
# comment) to catch cross-language scripts like
# R/benchmark/benchmark_model_fits_python.py. A .py file here would make an
# unrelated README-badge commit spuriously trigger a full 3-OS wheel build.
#
# Markdown rather than HTML for the table: gist.github.com renders a .md
# file's GFM table formatted (same as it renders a repo README), whereas an
# .html file in a gist is shown as syntax-highlighted source, not executed --
# clicking either badge would land on an unrendered wall of markup instead of
# a table.
#
# This replaced README.md's own inline cloc table (and the pre-push
# auto-commit that used to keep it fresh) -- see git history for
# scripts/update_readme_cloc.sh, which this supersedes. README.md now
# carries two static badges that fetch this data live; it is never edited by
# CI.
#
# Safe to run manually from anywhere in the repo:
#   scripts/generate_loc_badge_data.sh <code-badge-json-out> <tests-badge-json-out> <md-out>
set -euo pipefail

if [ "$#" -ne 3 ]; then
	echo "usage: $0 <code-badge-json-out> <tests-badge-json-out> <md-out>" >&2
	exit 1
fi
code_badge_out="$1"
tests_badge_out="$2"
md_out="$3"

if ! command -v cloc >/dev/null 2>&1; then
	echo "generate_loc_badge_data.sh: cloc is not installed." >&2
	exit 1
fi

repo_root="$(git rev-parse --show-toplevel)"

# Tests/diagnostics/scripts/benchmarks directories, excluded from the main
# per-language breakdown and reported as their own category (and own badge)
# instead -- otherwise e.g. R/package_tests' ~150k lines of generated
# testthat_bulk/ fixtures dwarf the actual package source in the R row and
# make the badge/table misleading about how big the shipped package is.
other_dirs=(
	R/package_tests R/EDI/tests python/tests
	R/benchmark R/scripts R/EDI/scripts
	python/benchmark python/benchmarks
	scripts
)
other_match_d="($(IFS='|'; echo "${other_dirs[*]}"))"

code_cloc_cmd='cloc --vcs=git --include-lang="R,Python,C,C++,C/C++ Header" --exclude-ext="Rd,rd" --fullpath --not-match-d="'"$other_match_d"'" .'
code_cloc_json="$(cd "$repo_root" && cloc --json --quiet --vcs=git \
	--include-lang="R,Python,C,C++,C/C++ Header" --exclude-ext="Rd,rd" \
	--fullpath --not-match-d="$other_match_d" .)"

other_cloc_cmd='cloc --vcs=git --include-lang="R,Python,C,C++,C/C++ Header" --exclude-ext="Rd,rd" --fullpath --match-d="'"$other_match_d"'" .'
other_cloc_json="$(cd "$repo_root" && cloc --json --quiet --vcs=git \
	--include-lang="R,Python,C,C++,C/C++ Header" --exclude-ext="Rd,rd" \
	--fullpath --match-d="$other_match_d" .)"

# "45.2k" rather than exact digits: fits shields.io's compact pill next to
# this repo's other short badges (build/coverage/license).
to_message() {
	awk -v n="$1" 'BEGIN {
		if (n < 1000) printf "%d", n
		else printf "%.1fk", n / 1000
	}'
}

code_total="$(jq -r '.SUM.code' <<<"$code_cloc_json")"
other_total="$(jq -r '.SUM.code' <<<"$other_cloc_json")"
code_message="$(to_message "$code_total")"
other_message="$(to_message "$other_total")"

jq -n --arg message "$code_message" \
	'{schemaVersion: 1, label: "lines of code", message: $message, color: "blue"}' \
	> "$code_badge_out"

jq -n --arg message "$other_message" \
	'{schemaVersion: 1, label: "tests, diagnostics, etc", message: $message, color: "lightgrey"}' \
	> "$tests_badge_out"

# to_entries preserves the source object's key order, which for cloc's JSON
# output is the same descending-by-code-count order as its own table output
# (R, C++, Python, C/C++ Header for this repo) -- no separate sort needed.
rows="$(jq -r '
	to_entries
	| map(select(.key != "header" and .key != "SUM"))
	| .[]
	| "|\(.key)|\(.value.nFiles)|\(.value.blank)|\(.value.comment)|\(.value.code)|"
' <<<"$code_cloc_json")"

sum_row="$(jq -r '
	.SUM
	| "|**SUM:**|**\(.nFiles)**|**\(.blank)**|**\(.comment)**|**\(.code)**|"
' <<<"$code_cloc_json")"

other_rows="$(jq -r '
	to_entries
	| map(select(.key != "header" and .key != "SUM"))
	| .[]
	| "|\(.key)|\(.value.nFiles)|\(.value.blank)|\(.value.comment)|\(.value.code)|"
' <<<"$other_cloc_json")"

other_sum_row="$(jq -r '
	.SUM
	| "|**SUM:**|**\(.nFiles)**|**\(.blank)**|**\(.comment)**|**\(.code)**|"
' <<<"$other_cloc_json")"

generated_at="$(date -u +'%Y-%m-%d %H:%M UTC')"

cat > "$md_out" <<EOF
# EDI — Lines of Code

## Functional code

Language|files|blank|comment|code
:-------|-------:|-------:|-------:|-------:
$rows
$sum_row

## Tests, diagnostics, etc

Language|files|blank|comment|code
:-------|-------:|-------:|-------:|-------:
$other_rows
$other_sum_row

Generated $generated_at on every push to
[kapelner/EDI](https://github.com/kapelner/EDI)'s main branch.
Functional code: \`$code_cloc_cmd\`. Tests, diagnostics, etc
(\`$(IFS=', '; echo "${other_dirs[*]}")\`): \`$other_cloc_cmd\`.
(\`--vcs=git\` counts only git-tracked files, so local artifacts such as
\`python/.venv\` don't skew the numbers.)
EOF
