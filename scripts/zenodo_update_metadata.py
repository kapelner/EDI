#!/usr/bin/env python3
"""Sync a published Zenodo record's keywords, description, and related
identifiers from the repo's `.zenodo.json`.

Why: `.zenodo.json` only applies to FUTURE GitHub releases. Records that were
already published keep whatever metadata they had. Zenodo allows metadata edits
on published records (files stay locked), and the DOI does not change.

Only three fields are touched: keywords, description, related_identifiers.
Everything else (title, creators, license, version, dates) is left as is.
Existing related identifiers are kept; ones from .zenodo.json are added if
missing.

Usage (from the repo root):

    # Dry run (default): prints the diff against the live public record.
    # Needs no token and changes nothing.
    python3 scripts/zenodo_update_metadata.py

    # Apply. Needs a personal access token with scopes deposit:write and
    # deposit:actions, created at https://zenodo.org/account/settings/applications/
    export ZENODO_TOKEN=...        # never commit or paste this anywhere
    python3 scripts/zenodo_update_metadata.py --apply

    # Other record ids, or every version of the record (dry run first!):
    python3 scripts/zenodo_update_metadata.py 22170036 23456789
    python3 scripts/zenodo_update_metadata.py --all-versions

Default record id is 22170036 (v1.0.0, DOI 10.5281/zenodo.22170036).
Standard library only.
"""
import argparse
import html
import json
import os
import re
import sys
import urllib.error
import urllib.request
from pathlib import Path

API = "https://zenodo.org/api"
DEFAULT_ID = "22170036"
ZENODO_JSON = Path(__file__).resolve().parent.parent / ".zenodo.json"


def call(method, path, token=None, body=None):
    url = path if path.startswith("http") else API + path
    data = json.dumps(body).encode() if body is not None else None
    req = urllib.request.Request(url, data=data, method=method)
    req.add_header("Content-Type", "application/json")
    if token:
        req.add_header("Authorization", "Bearer " + token)
    try:
        with urllib.request.urlopen(req, timeout=60) as r:
            raw = r.read()
            return json.loads(raw) if raw else {}
    except urllib.error.HTTPError as e:
        detail = e.read().decode(errors="replace")[:1500]
        sys.exit(f"HTTP {e.code} on {method} {path}\n{detail}")


def plain(s):
    return re.sub(r"\s+", " ", html.unescape(re.sub(r"<[^>]+>", "", s or ""))).strip()


def rel_key(r):
    return (r.get("identifier", "").rstrip("/"), r.get("relation"))


def build_target(current, want):
    """Return the new values for the three managed fields."""
    desc = "<p>" + html.escape(want["description"].strip(), quote=False) + "</p>"
    related = list(current.get("related_identifiers") or [])
    have = {rel_key(r) for r in related}
    for r in want.get("related_identifiers", []):
        if rel_key(r) not in have:
            new = dict(r)
            new.setdefault("scheme", "url")
            related.append(new)
    return {
        "keywords": list(want["keywords"]),
        "description": desc,
        "related_identifiers": related,
    }


def show_diff(rid, current, target):
    print(f"\n=== record {rid}  (version {current.get('version')}) ===")
    cur_k, new_k = current.get("keywords") or [], target["keywords"]
    add = [k for k in new_k if k not in cur_k]
    drop = [k for k in cur_k if k not in new_k]
    print(f"keywords: {len(cur_k)} -> {len(new_k)}")
    for k in add:
        print(f"  + {k}")
    for k in drop:
        print(f"  - {k}   (would be REMOVED)")
    same_desc = plain(current.get("description")) == plain(target["description"])
    print("description:", "unchanged" if same_desc else "CHANGED")
    if not same_desc:
        print("  old:", plain(current.get("description"))[:200], "...")
        print("  new:", plain(target["description"])[:200], "...")
    cur_r = {rel_key(r) for r in current.get("related_identifiers") or []}
    added = [r for r in target["related_identifiers"] if rel_key(r) not in cur_r]
    print(f"related identifiers: +{len(added)}")
    for r in added:
        print(f"  + {r['relation']}: {r['identifier']}")
    return bool(add or drop or not same_desc or added)


def apply_one(rid, token, want):
    # The deposit API returns the editable metadata (not just the public view).
    dep = call("GET", f"/deposit/depositions/{rid}", token)
    if dep.get("state") == "done":
        dep = call("POST", f"/deposit/depositions/{rid}/actions/edit", token)
    meta = dep["metadata"]
    target = build_target(meta, want)
    try:
        meta.update(target)
        call("PUT", f"/deposit/depositions/{rid}", token, {"metadata": meta})
        call("POST", f"/deposit/depositions/{rid}/actions/publish", token)
    except SystemExit:
        # Do not leave the record stuck in "edit" state.
        try:
            call("POST", f"/deposit/depositions/{rid}/actions/discard", token)
            print(f"record {rid}: edit failed; draft discarded, record unchanged.")
        except SystemExit:
            print(f"record {rid}: edit failed AND discard failed. Check the record "
                  "page on zenodo.org; it may be left in edit mode.")
        raise
    print(f"record {rid}: published.")


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    ap.add_argument("ids", nargs="*", help=f"record ids (default {DEFAULT_ID})")
    ap.add_argument("--apply", action="store_true", help="really edit (needs ZENODO_TOKEN)")
    ap.add_argument("--all-versions", action="store_true",
                    help="also include every other version of the record")
    args = ap.parse_args()

    want = json.loads(ZENODO_JSON.read_text(encoding="utf-8"))
    ids = args.ids or [DEFAULT_ID]
    if args.all_versions:
        found = []
        for rid in ids:
            vers = call("GET", f"/records/{rid}/versions?size=25&sort=version")
            found += [str(h["id"]) for h in vers.get("hits", {}).get("hits", [])]
        ids = list(dict.fromkeys(found or ids))
        print("records:", ", ".join(ids))

    token = os.environ.get("ZENODO_TOKEN")
    if args.apply and not token:
        sys.exit("--apply needs the ZENODO_TOKEN environment variable.")

    todo = []
    for rid in ids:
        pub = call("GET", f"/records/{rid}")  # public view, no token needed
        current = dict(pub["metadata"])
        current["related_identifiers"] = current.get("related_identifiers") or []
        if show_diff(rid, current, build_target(current, want)):
            todo.append(rid)
    if not todo:
        print("\nNothing to change.")
        return
    if not args.apply:
        print(f"\nDry run: {len(todo)} record(s) would change. Re-run with --apply.")
        return
    for rid in todo:
        apply_one(rid, token, want)


if __name__ == "__main__":
    main()
