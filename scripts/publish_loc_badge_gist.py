#!/usr/bin/env python3
"""Publishes generated lines-of-code badge data to a GitHub Gist via PATCH.

Called by .github/workflows/loc-badge.yml after
scripts/generate_loc_badge_data.py has written loc-badge.json + loc.html.
A Gist revision, not a repo commit -- this is the mechanism that keeps
README.md's badge live without README.md itself ever needing a commit (see
that workflow's header comment for why a Gist rather than GitHub Pages,
which this repo's pkgdown.yaml already occupies).

Requires GIST_ID (not secret -- a gist ID is just an opaque identifier, safe
to hardcode in the workflow) and GIST_PAT (a repo secret: a classic PAT
scoped to just "gist") in the environment.

Usage: python3 scripts/publish_loc_badge_gist.py <badge-json-path> <html-path>
"""
import json
import os
import sys
import urllib.error
import urllib.request


def main() -> int:
    if len(sys.argv) != 3:
        print(f"usage: {sys.argv[0]} <badge-json-path> <html-path>", file=sys.stderr)
        return 1
    badge_path, html_path = sys.argv[1], sys.argv[2]

    try:
        gist_id = os.environ["GIST_ID"]
        token = os.environ["GIST_PAT"]
    except KeyError as e:
        print(f"publish_loc_badge_gist.py: missing required env var {e}.", file=sys.stderr)
        return 1

    with open(badge_path) as f:
        badge_content = f.read()
    with open(html_path) as f:
        html_content = f.read()

    payload = json.dumps({
        "files": {
            "loc-badge.json": {"content": badge_content},
            "loc.html": {"content": html_content},
        }
    }).encode()

    req = urllib.request.Request(
        f"https://api.github.com/gists/{gist_id}",
        data=payload,
        method="PATCH",
        headers={
            "Authorization": f"Bearer {token}",
            "Accept": "application/vnd.github+json",
            "User-Agent": "EDI-loc-badge-workflow",
        },
    )
    try:
        with urllib.request.urlopen(req) as resp:
            if resp.status != 200:
                print(f"publish_loc_badge_gist.py: gist update returned HTTP {resp.status}.", file=sys.stderr)
                return 1
    except urllib.error.HTTPError as e:
        body = e.read().decode(errors="replace")
        print(f"publish_loc_badge_gist.py: gist update failed: HTTP {e.code} {body}", file=sys.stderr)
        return 1

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
