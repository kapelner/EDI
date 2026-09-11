#!/usr/bin/env bash
# Publishes generated lines-of-code badge data to a GitHub Gist via PATCH.
#
# Called by .github/workflows/loc-badge.yml after
# scripts/generate_loc_badge_data.sh has written loc-badge.json + loc.md. A
# Gist revision, not a repo commit -- this is the mechanism that keeps
# README.md's badge live without README.md itself ever needing a commit
# (see that workflow's header comment for why a Gist rather than GitHub
# Pages, which this repo's pkgdown.yaml already occupies).
#
# Bash + jq + curl rather than Python -- see generate_loc_badge_data.sh's
# header comment for why (build-wheels.yml's "**/*.py" push trigger).
#
# Requires GIST_ID (not secret -- a gist ID is just an opaque identifier,
# safe to hardcode in the workflow) and GIST_PAT (a repo secret: a classic
# PAT scoped to just "gist") in the environment.
#
# Usage: scripts/publish_loc_badge_gist.sh <badge-json-path> <md-path>
set -euo pipefail

if [ "$#" -ne 2 ]; then
	echo "usage: $0 <badge-json-path> <md-path>" >&2
	exit 1
fi
badge_path="$1"
md_path="$2"

: "${GIST_ID:?GIST_ID is required}"
: "${GIST_PAT:?GIST_PAT is required}"

payload="$(jq -n \
	--rawfile badge "$badge_path" \
	--rawfile md "$md_path" \
	'{files: {"loc-badge.json": {content: $badge}, "loc.md": {content: $md}}}')"

response_body="$(mktemp)"
trap 'rm -f "$response_body"' EXIT

response_code="$(curl -sS -o "$response_body" -w '%{http_code}' \
	-X PATCH \
	-H "Authorization: Bearer $GIST_PAT" \
	-H "Accept: application/vnd.github+json" \
	-H "User-Agent: EDI-loc-badge-workflow" \
	--data "$payload" \
	"https://api.github.com/gists/$GIST_ID")"

if [ "$response_code" != "200" ]; then
	echo "publish_loc_badge_gist.sh: gist update failed: HTTP $response_code" >&2
	cat "$response_body" >&2
	exit 1
fi
