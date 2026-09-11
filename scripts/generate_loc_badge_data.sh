#!/usr/bin/env bash
# Generates the lines-of-code badge JSON + full-table Markdown page that
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
# clicking the badge would land on an unrendered wall of markup instead of a
# table.
#
# This replaced README.md's own inline cloc table (and the pre-push
# auto-commit that used to keep it fresh) -- see git history for
# scripts/update_readme_cloc.sh, which this supersedes. README.md now
# carries a static badge that fetches this data live; it is never edited by
# CI.
#
# Safe to run manually from anywhere in the repo:
#   scripts/generate_loc_badge_data.sh <badge-json-out> <md-out>
set -euo pipefail

if [ "$#" -ne 2 ]; then
	echo "usage: $0 <badge-json-out> <md-out>" >&2
	exit 1
fi
badge_out="$1"
md_out="$2"

if ! command -v cloc >/dev/null 2>&1; then
	echo "generate_loc_badge_data.sh: cloc is not installed." >&2
	exit 1
fi

repo_root="$(git rev-parse --show-toplevel)"
cloc_cmd='cloc --vcs=git --include-lang="R,Python,C,C++,C/C++ Header" --exclude-ext="Rd,rd" .'
cloc_json="$(cd "$repo_root" && cloc --json --quiet --vcs=git \
	--include-lang="R,Python,C,C++,C/C++ Header" --exclude-ext="Rd,rd" .)"

# "45.2k" rather than exact digits: fits shields.io's compact pill next to
# this repo's other short badges (build/coverage/license).
total_code="$(jq -r '.SUM.code' <<<"$cloc_json")"
message="$(awk -v n="$total_code" 'BEGIN {
	if (n < 1000) printf "%d", n
	else printf "%.1fk", n / 1000
}')"

jq -n --arg message "$message" \
	'{schemaVersion: 1, label: "lines of code", message: $message, color: "blue"}' \
	> "$badge_out"

# to_entries preserves the source object's key order, which for cloc's JSON
# output is the same descending-by-code-count order as its own table output
# (R, C++, Python, C/C++ Header for this repo) -- no separate sort needed.
rows="$(jq -r '
	to_entries
	| map(select(.key != "header" and .key != "SUM"))
	| .[]
	| "|\(.key)|\(.value.nFiles)|\(.value.blank)|\(.value.comment)|\(.value.code)|"
' <<<"$cloc_json")"

sum_row="$(jq -r '
	.SUM
	| "|**SUM:**|**\(.nFiles)**|**\(.blank)**|**\(.comment)**|**\(.code)**|"
' <<<"$cloc_json")"

generated_at="$(date -u +'%Y-%m-%d %H:%M UTC')"

cat > "$md_out" <<EOF
# EDI — Lines of Code

Language|files|blank|comment|code
:-------|-------:|-------:|-------:|-------:
$rows
$sum_row

Generated $generated_at by \`$cloc_cmd\` on every push to
[kapelner/EDI](https://github.com/kapelner/EDI)'s main branch
(\`--vcs=git\` counts only git-tracked files, so local artifacts such as
\`python/.venv\` don't skew the numbers).
EOF
