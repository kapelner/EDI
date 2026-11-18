"""Mechanical tidy of the release files, run by the TODO-status audit before its Claude stage.

Plan: R/package_metadata/new_feature_plans/v1_0_6/audit_jobs_framework.md (Part 3, "Mechanical tidy").

Two steps, in this order, on each unreleased `future_release_plans/release_v*.md`:

1. DEDUPLICATE. Two top-level checkbox entries with the same TODO number collide. The entry added
   first keeps the number (its "(added YYYY-MM-DD" date, else the git-blame date of its first line,
   else file order); each later one gets the next number above every number the file uses. A
   struck pointer for a split item (`~~TODO-5 (steps 5-8)~~ -> moved ...`) shares its live entry's
   number on purpose and is not a collision. References are rewritten only where they are provably
   about the renumbered entry:
     - inside its own block: its lead id, `v<this release>-TODO-<n>`, and unqualified `TODO-<n>`
       (not one that names another file, and not a nested `- TODO-<n>:` list lead, which is how
       entries quote a plan's own TODOs);
     - elsewhere in this release file or the repo: a `v<this release>-TODO-<n>` or unqualified
       `TODO-<n>` on a line that also carries the entry's bold title (a status line naming it);
     - in a file the renumbered entry introduced: named in backticks by that entry and by no other
       entry with the same number, and first committed on or after the entry's added date.
   Every other reference is listed for a human. Old-style references (`v1.0.6 TODO-30`,
   `release_v1_0_6.md -> TODO-30`) are never rewritten (CLAUDE.md lets them stay); they are listed.
2. REORDER. Within each contiguous run of top-level TODO entries (entries separated only by blank
   lines, at the same indent, under the same heading), the entries are put in numeric order
   (TODO-4 < TODO-4b < TODO-5 < TODO-17). An entry's whole block (checkbox line, indented
   continuation, nested items) moves as a unit; headings, prose, tables, blank-line gaps and checkbox
   items without a TODO number stay where they are, so sections never mix. Sorting globally would
   pull entries out of their topic sections ("Bugs found by the data-shape matrix (TODO-107..115)")
   and under prose that introduces other entries. The step is checked to be a pure permutation of
   lines (the multiset of lines is unchanged) and raises if it is not.

`duplicate_groups()` is the duplicate detector (shared parser: `todo_status.parse_checkboxes`).

Command line (dry run on copies; never writes the repo unless --apply):
    python3 .github/scripts/audits/_todo_tidy.py --repo . --out "$TMPDIR/tidy" [--apply]
"""
import os
import re
import subprocess
import sys
from collections import Counter
from pathlib import Path

if __name__ == "__main__":
    sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from audits import todo_status as ts  # noqa: E402

NUM = re.compile(r"(\d+)([a-z]?)(?:\.(\d+)([a-z]?))?$")
ADDED = re.compile(r"\badded\s+(\d{4}-\d{2}-\d{2})")
BOLD = re.compile(r"\*\*(.+?)\*\*")
MIN_TITLE = 12
NESTED_LEAD = re.compile(r"^[ \t]+[-*+][ \t]+(?:\*\*)?$")
FILE_QUAL = re.compile(r"\.md`?[ \t]*(?:\n[ \t]*)?(?:→|->)?[ \t]*(?:\n[ \t]*)?`?[ \t]*$")
MAX_COMMITS_LISTED = 10
# A heading that says its entries are in a deliberate order: its runs are never sorted.
ORDERED_HEADING = re.compile(r"\b(?:dependency|priority|execution|strict(?:ly)?|reading)[ -]order\b"
                             r"|\b(?:strictly |in )ordered\b|\bin order\)", re.I)


def num_key(num):
    """Sort key of a TODO number: 4 < 4b < 5 < 17 < 17a < 17.1."""
    m = NUM.match(num or "")
    if not m:
        return (10 ** 9, num or "", -1, "")
    return (int(m.group(1)), m.group(2), int(m.group(3)) if m.group(3) else -1, m.group(4))


def version_label(relfile):
    m = ts.RELEASE_FILE.search(relfile)
    return ".".join(m.groups()) if m else None


def _lines_consistent(text):
    """parse_checkboxes counts lines with splitlines(); edits here use split("\\n")."""
    parts = text.split("\n")
    if parts and parts[-1] == "":
        parts = parts[:-1]
    return text.splitlines() == parts


def is_split_part(item):
    """A struck pointer for part of an item (`~~TODO-5 (steps 5-8)~~`): same number by design."""
    if not item["pointer"] or not item["todo"]:
        return False
    return bool(re.search(r"~~\s*" + re.escape(item["todo"]) + r"\s*\(", item["first_line"]))


def duplicate_groups(items):
    """{number: [items]} for TODO numbers that more than one top-level entry leads with."""
    groups = {}
    for it in items:
        if it["todo"] and not is_split_part(it):
            groups.setdefault(ts.todo_number(it["todo"]), []).append(it)
    return {n: g for n, g in groups.items() if len(g) > 1}


def added_date(item):
    flat = re.sub(r"\s+", " ", "\n".join(item["text"].split("\n")[:4]))
    m = ADDED.search(flat)
    return m.group(1) if m else None


def bold_title(item):
    flat = re.sub(r"\s+", " ", item["text"])
    for m in BOLD.finditer(flat):
        t = m.group(1).strip()
        if len(t) >= MIN_TITLE:
            return t
    return None


def _git(repo, *args):
    if repo is None:
        return ""
    r = subprocess.run(["git", *args], cwd=repo, capture_output=True, text=True)
    return r.stdout if r.returncode == 0 else ""


def git_blame_date(repo, relfile, line):
    out = _git(repo, "blame", "--porcelain", "-L", f"{line},{line}", "--", relfile)
    m = re.search(r"^committer-time (\d+)", out, re.M)
    if not m or "\nfilename " not in out or out.startswith("0000000"):
        return None
    import datetime as dt
    return dt.datetime.fromtimestamp(int(m.group(1)), dt.timezone.utc).date().isoformat()


def git_first_added(repo, relfile):
    out = _git(repo, "log", "--diff-filter=A", "--format=%cs", "--", relfile).split()
    return out[-1] if out else None


# ---------------------------------------------------------------- renumber

def plan_renumber(items, text, blame=None):
    """[{"old", "new", "item", "kept", "date", "date_source"}] for every later duplicate."""
    groups = duplicate_groups(items)
    if not groups:
        return []
    used = [num_key(ts.todo_number(it["todo"]))[0] for it in items if it["todo"]]
    for h in re.findall(r"^#{1,6} .*$", text, re.M):
        used += [int(x) for x in re.findall(r"TODO-(\d+)", h)]
    nxt = max(used) + 1
    out = []
    for num, group in sorted(groups.items(), key=lambda kv: min(it["line"] for it in kv[1])):
        dated = []
        for it in group:
            d, src = added_date(it), "added"
            if d is None and blame:
                d, src = blame(it), "git blame"
            if d is None:
                src = "none (file order)"
            dated.append((d or "9999-12-31", it["line"], it, d, src))
        dated.sort(key=lambda r: (r[0], r[1]))
        kept = dated[0][2]
        for _, _, it, d, src in dated[1:]:
            out.append({"old": num, "new": str(nxt), "item": it, "kept": kept, "kept_date": dated[0][3],
                        "date": d, "date_source": src, "title": bold_title(it)})
            nxt += 1
    return out


def _ref_pattern(num):
    return re.compile(r"(?<![\w.-])(?:v(\d+\.\d+\.\d+)([- ]))?TODO-" + re.escape(num) + r"(?![\w]|\.\d)")


def _line_of(text, pos):
    return text.count("\n", 0, pos) + 1


def _classify(text, m, this_version):
    """("new" | "bare" | "old" | "other", note) for one TODO-<n> match in a release-file text."""
    ver, sep = m.group(1), m.group(2)
    if ver:
        if ver != this_version:
            return "other", f"cites v{ver}"
        return ("new", "") if sep == "-" else ("old", "old-style `v<version> TODO-<n>`")
    before = text[max(0, m.start() - 120):m.start()]
    q = FILE_QUAL.search(before)
    if q:
        fm = re.search(r"([\w.-]+\.md)`?[ \t]*(?:\n[ \t]*)?(?:→|->)?[ \t]*(?:\n[ \t]*)?`?[ \t]*$", before)
        return "other", f"names `{fm.group(1) if fm else 'another file'}`"
    return "bare", ""


def _line_text(text, line_no):
    return text.split("\n")[line_no - 1]


def renumber_text(relfile, text, plan):
    """Apply `plan` to one release file. Returns (new_text, rewritten, flagged).

    rewritten/flagged: [{"file", "line", "old", "new" (rewritten only), "why", "text"}]."""
    this_version = version_label(relfile)
    edits = []          # (start, end, replacement)
    rewritten, flagged = [], []
    lines = text.split("\n")
    starts = [0]
    for ln in lines[:-1]:
        starts.append(starts[-1] + len(ln) + 1)

    def span(it):
        return starts[it["line"] - 1], starts[it["end_line"] - 1] + len(lines[it["end_line"] - 1])

    by_old = {}
    for r in plan:
        by_old.setdefault(r["old"], []).append(r)
    for old, recs in by_old.items():
        group_spans = {id(r["item"]): span(r["item"]) for r in recs}
        kept_span = span(recs[0]["kept"])
        for m in _ref_pattern(old).finditer(text):
            kind, note = _classify(text, m, this_version)
            if kind == "other":
                continue
            ln = _line_of(text, m.start())
            ltxt = lines[ln - 1].strip()
            owner = next((r for r in recs if group_spans[id(r["item"])][0] <= m.start() < group_spans[id(r["item"])][1]), None)
            if owner is None and kept_span[0] <= m.start() < kept_span[1]:
                continue        # inside the entry that keeps the number: about that entry
            if owner is not None:
                lead = (ln == owner["item"]["line"]
                        and re.match(r"^[ \t]*[-*+] \[[ xX]\][\s~*]*$", text[starts[ln - 1]:m.start()]))
                if kind == "old":
                    flagged.append({"file": relfile, "line": ln, "why": f"inside renumbered TODO-{old} -> "
                                    f"TODO-{owner['new']}, {note}; old-style references are never rewritten",
                                    "text": ltxt})
                    continue
                prefix = text[starts[ln - 1]:m.start()]
                if kind == "bare" and not lead and NESTED_LEAD.match(prefix):
                    flagged.append({"file": relfile, "line": ln, "why": f"inside renumbered TODO-{old} -> "
                                    f"TODO-{owner['new']}, but a nested list lead (likely a plan's own TODO)",
                                    "text": ltxt})
                    continue
                edits.append((m.start(), m.end(), _replace(m, owner["new"])))
                rewritten.append({"file": relfile, "line": ln, "old": m.group(0), "new": _replace(m, owner["new"]),
                                  "why": "the entry's own lead id" if lead else "inside the renumbered entry"})
                continue
            # Outside every block of the group: rewrite only on a status line naming the entry's title.
            hit = next((r for r in recs if r["title"] and r["title"] in re.sub(r"\s+", " ", lines[ln - 1])), None)
            if hit and kind in ("new", "bare"):
                edits.append((m.start(), m.end(), _replace(m, hit["new"])))
                rewritten.append({"file": relfile, "line": ln, "old": m.group(0), "new": _replace(m, hit["new"]),
                                  "why": "line names the renumbered entry's title"})
            else:
                flagged.append({"file": relfile, "line": ln, "why": f"ambiguous: TODO-{old} is now "
                                + " or ".join(["kept"] + [f"TODO-{r['new']}" for r in recs])
                                + (f"; {note}" if note else ""), "text": ltxt})
    new = text
    for s, e, rep in sorted(edits, reverse=True):
        new = new[:s] + rep + new[e:]
    if new.count("\n") != text.count("\n"):
        raise AssertionError(f"{relfile}: renumbering changed the line count")
    return new, rewritten, flagged


def _replace(m, new_num):
    s = m.group(0)
    return s[:s.rfind("TODO-") + 5] + new_num


# ---------------------------------------------------------------- references in other files

def scan_repo_refs(repo, relfile, plan, all_items, read=None, first_added=None):
    """References to a renumbered number in other tracked files.

    Returns (edits {path: [(line, old, new)]}, rewritten, flagged, commits)."""
    version = version_label(relfile)
    vers_re = re.escape(version)
    base = os.path.basename(relfile)
    read = read or (lambda p: Path(repo, p).read_text(errors="replace"))
    first_added = first_added or (lambda p: git_first_added(repo, p))
    tracked = set(ts.tracked(repo)) if repo else set()
    by_base = {}
    for f in tracked:
        by_base.setdefault(os.path.basename(f), []).append(f)
    edits, rewritten, flagged, commits = {}, [], [], []
    by_old = {}
    for r in plan:
        by_old.setdefault(r["old"], []).append(r)
    for old, recs in by_old.items():
        group = [recs[0]["kept"]] + [r["item"] for r in recs]
        named = {id(it): _named_paths(it["text"], tracked, by_base) for it in group}
        introduced = {}
        for r in recs:
            others = set().union(*(named[id(g)] for g in group if g is not r["item"]))
            for p in named[id(r["item"])] - others:
                fa = first_added(p) if r["date"] else None
                if fa and fa >= r["date"]:
                    introduced[p] = r
        end = r"([^0-9a-zA-Z_.]|\.([^0-9]|$)|$)"     # not TODO-70, TODO-7b or TODO-7.1
        pat = (rf"v{vers_re}[- ]TODO-{re.escape(old)}{end}"
               rf"|{re.escape(base)}`?[[:space:]]*(→|->)?[[:space:]]*`?TODO-{re.escape(old)}{end}")
        out = _git(repo, "grep", "-n", "-I", "-E", pat, "--", ".", f":(exclude){relfile}")
        for row in out.splitlines():
            path, ln, content = row.split(":", 2)
            ln = int(ln)
            for m in re.finditer(rf"(?<![\w.-])(?:v{vers_re}([- ])|{re.escape(base)}`?\s*(?:→|->)?\s*`?)TODO-"
                                 rf"{re.escape(old)}(?![\w]|\.\d)", content):
                new_style = m.group(1) == "-"
                flat = re.sub(r"\s+", " ", content)
                hit = next((r for r in recs if r["title"] and r["title"] in flat), None) or introduced.get(path)
                if new_style and hit:
                    why = ("line names the renumbered entry's title" if hit.get("title") and hit["title"] in flat
                           else "file introduced by the renumbered entry")
                    newtok = m.group(0)[:-len(old)] + hit["new"]
                    edits.setdefault(path, []).append((ln, m.group(0), newtok))
                    rewritten.append({"file": path, "line": ln, "old": m.group(0), "new": newtok, "why": why})
                else:
                    why = ("old-style reference, never rewritten" if not new_style
                           else f"ambiguous: v{version}-TODO-{old} is now kept or "
                                + " or ".join(f"TODO-{r['new']}" for r in recs))
                    flagged.append({"file": path, "line": ln, "why": why, "text": content.strip()[:200]})
        log = _git(repo, "log", "--format=%h %cs %s", "-E", "-i",
                   f"--grep=v{vers_re}[- ]TODO-{re.escape(old)}{end}")
        cs = [c for c in log.splitlines() if c]
        if cs:
            commits.append({"old": old, "count": len(cs), "list": cs[:MAX_COMMITS_LISTED]})
    return edits, rewritten, flagged, commits


def _named_paths(text, tracked, by_base):
    out = set()
    for tok in re.findall(r"`([^`\n]{2,200})`", text):
        tok = re.sub(r":\d[\d-]*$", "", tok.strip())
        if not ts.PATHLIKE.match(tok):
            continue
        if tok in tracked:
            out.add(tok)
        elif "/" not in tok and len(by_base.get(tok, [])) == 1:
            out.add(by_base[tok][0])
    return out


def apply_line_edits(text, edits):
    lines = text.split("\n")
    for ln, old, new in edits:
        if old not in lines[ln - 1]:
            raise ValueError(f"line {ln}: {old!r} not found")
        lines[ln - 1] = lines[ln - 1].replace(old, new, 1)
    return "\n".join(lines)


# ---------------------------------------------------------------- reorder

def reorder_text(relfile, text):
    """(new_text, runs) with each contiguous run of TODO entries in numeric order.

    runs: [{"heading", "first_line", "entries", "moved", "before", "after", "kept_order"}] for runs
    that are out of numeric order; kept_order is True (and nothing moves) under a heading that
    declares a deliberate order (ORDERED_HEADING, e.g. "Implementation TODOs (dependency order)")."""
    lines = text.split("\n")
    items = ts.parse_checkboxes(text, relfile)
    heading_at = {}
    current = None
    for i, l in enumerate(lines):
        if ts.HEADING.match(l):
            current = l.strip()
        heading_at[i + 1] = current
    runs, run = [], []
    for it in items:
        sortable = bool(it["todo"])
        if run and sortable and it["indent"] == run[-1]["indent"] and all(
                not lines[k].strip() for k in range(run[-1]["end_line"], it["line"] - 1)):
            run.append(it)
            continue
        if len(run) > 1:
            runs.append(run)
        run = [it] if sortable else []
    if len(run) > 1:
        runs.append(run)
    new_lines = list(lines)
    changed = []
    for run in runs:
        keys = [num_key(ts.todo_number(it["todo"])) for it in run]
        order = sorted(range(len(run)), key=lambda i: keys[i])
        if order == list(range(len(run))):
            continue
        heading = heading_at.get(run[0]["line"])
        info = {"heading": heading, "first_line": run[0]["line"], "entries": len(run),
                "moved": sum(1 for s, i in enumerate(order) if s != i),
                "before": [it["todo"] for it in run], "after": [run[i]["todo"] for i in order]}
        if heading and ORDERED_HEADING.search(heading):
            changed.append({**info, "kept_order": True})
            continue
        blocks = [lines[it["line"] - 1:it["end_line"]] for it in run]
        gaps = [lines[a["end_line"]:b["line"] - 1] for a, b in zip(run, run[1:])]
        seg = []
        for slot, idx in enumerate(order):
            seg += blocks[idx]
            if slot < len(gaps):
                seg += gaps[slot]
        lo, hi = run[0]["line"] - 1, run[-1]["end_line"]
        if len(seg) != hi - lo:
            raise AssertionError(f"{relfile}: run at line {lo + 1} changed length")
        new_lines[lo:hi] = seg
        changed.append({**info, "kept_order": False})
    if Counter(new_lines) != Counter(lines):
        raise AssertionError(f"{relfile}: reorder is not a permutation of lines")
    return "\n".join(new_lines), changed


# ---------------------------------------------------------------- whole repo

def tidy_files(repo, release_files, read=None, blame=True, first_added=None, no_reorder=()):
    """Plan the tidy of `release_files` (repo-relative). Writes nothing. Files in `no_reorder`
    (releases closed to new TODOs, which are about to ship) are deduplicated but not reordered.

    Returns {"files": {path: new_text} (only changed ones), "report": [per release file dict]}."""
    read = read or (lambda p: Path(repo, p).read_text(errors="replace"))
    new_files, report = {}, []
    other_edits = {}
    for rel in release_files:
        text = read(rel)
        entry = {"file": rel, "renumbered": [], "rewritten": [], "flagged": [], "commits": [], "runs": [],
                 "skipped": None, "reorder_skipped": None}
        report.append(entry)
        if not _lines_consistent(text):
            entry["skipped"] = "the file has line separators other than \\n; not tidied"
            continue
        items = ts.parse_checkboxes(text, rel)
        bl = (lambda it: git_blame_date(repo, rel, it["line"])) if (blame and repo) else None
        plan = plan_renumber(items, text, bl)
        if plan:
            text, rw, fl = renumber_text(rel, text, plan)
            ed, rw2, fl2, cm = scan_repo_refs(repo, rel, plan, items, read=read, first_added=first_added)
            for p, e in ed.items():
                other_edits.setdefault(p, []).extend(e)
            entry["rewritten"] = rw + rw2
            entry["flagged"] = fl + fl2
            entry["commits"] = cm
            entry["renumbered"] = [{"old": r["old"], "new": r["new"], "line": r["item"]["line"],
                                    "title": r["title"], "date": r["date"], "date_source": r["date_source"],
                                    "kept_line": r["kept"]["line"], "kept_date": r["kept_date"]} for r in plan]
        if rel in no_reorder:
            entry["reorder_skipped"] = "release closed to new TODOs"
        else:
            text, runs = reorder_text(rel, text)
            entry["runs"] = runs
        if text != read(rel):
            new_files[rel] = text
    for p, e in other_edits.items():
        base = new_files.get(p, read(p))
        new_files[p] = apply_line_edits(base, e)
    return {"files": new_files, "report": report}


def unreleased_release_files(repo):
    """(unreleased release files, the ones among them closed to new TODOs)."""
    st = ts.load_todo_state(repo)
    files = [r["file"] for r in st["releases"] if not r["released"]]
    return files, {r["file"] for r in st["releases"] if not r["released"] and r["closed_to_new"]}


def write_files(root, files):
    for p, t in files.items():
        dest = Path(root, p)
        dest.parent.mkdir(parents=True, exist_ok=True)
        dest.write_text(t)


def summarise(result):
    """(applied, human, info) for the audit report: lists of lines, human as {"text", "unit"}."""
    applied, human, info = [], [], []
    for e in result["report"]:
        f = e["file"]
        if e["skipped"]:
            human.append(f"`{f}`: {e['skipped']}.")
        sorted_runs = [r for r in e["runs"] if not r["kept_order"]]
        moved = sum(r["moved"] for r in sorted_runs)
        if moved:
            applied.append(f"`{f}`: {moved} entr{'y' if moved == 1 else 'ies'} moved into numeric order in "
                           f"{len(sorted_runs)} section run(s) ("
                           + "; ".join(f"{r['heading'] or 'top'} at line {r['first_line']}" for r in sorted_runs) + ").")
        for r in e["runs"]:
            if r["kept_order"]:
                info.append(f"`{f}` line {r['first_line']}: {r['moved']} entries out of numeric order under "
                            f"\"{r['heading'].lstrip('# ')}\", which declares a deliberate order; not moved.")
        if e.get("reorder_skipped"):
            info.append(f"`{f}`: not reordered ({e['reorder_skipped']}).")
        for r in e["renumbered"]:
            applied.append(f"`{f}`: duplicate TODO-{r['old']} at line {r['line']} "
                           f"({'added ' + r['date'] if r['date'] else 'no added date'}, by {r['date_source']}) "
                           f"renumbered to TODO-{r['new']}; the entry at line {r['kept_line']}"
                           f"{' (added ' + r['kept_date'] + ')' if r['kept_date'] else ''} keeps TODO-{r['old']}.")
        for w in e["rewritten"]:
            applied.append(f"`{w['file']}:{w['line']}`: `{w['old']}` -> `{w['new']}` ({w['why']}).")
        for x in e["flagged"]:
            # The unit (file + the reference's line text) keeps the decision id stable when lines shift.
            human.append({"text": f"`{x['file']}:{x['line']}`: {x['why']}: `{x['text'][:160].replace('`', '')}`",
                          "unit": x["file"] + "::" + " ".join(x["text"].split())})
        for c in e["commits"]:
            info.append(f"`{f}`: {c['count']} commit(s) cite the renumbered number TODO-{c['old']} "
                        "(commit messages cannot be rewritten; the citation is ambiguous): "
                        + ", ".join(c["list"]))
    return applied, human, info


def main(argv=None):
    import argparse
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--repo", default=".")
    ap.add_argument("--out", help="write the tidied files under this folder (a dry run)")
    ap.add_argument("--apply", action="store_true", help="write the tidied files into the repo")
    ap.add_argument("--src", help="read the release files from this folder instead of the repo "
                                  "(paths as in the repo; other files still come from the repo)")
    ap.add_argument("files", nargs="*", help="release files (default: every unreleased one)")
    a = ap.parse_args(argv)
    repo = str(Path(a.repo).resolve())
    files, closed = unreleased_release_files(repo)
    files = a.files or files

    def read(p):
        if a.src and Path(a.src, p).exists():
            return Path(a.src, p).read_text(errors="replace")
        return Path(repo, p).read_text(errors="replace")

    res = tidy_files(repo, files, read=read, no_reorder=closed)
    applied, human, info = summarise(res)
    for title, xs in (("Applied", applied), ("Needs a human", human), ("Information", info)):
        print(f"## {title} ({len(xs)})")
        for x in xs:
            print("- " + (x["text"] if isinstance(x, dict) else x))
    for e in res["report"]:
        for r in e["runs"]:
            print(f"   {e['file']} run at {r['first_line']} ({r['heading']}){' [KEPT]' if r['kept_order'] else ''}: {' '.join(t or '?' for t in r['before'])}"
                  f"  =>  {' '.join(t or '?' for t in r['after'])}")
    print("changed files:", ", ".join(sorted(res["files"])) or "none")
    if a.out:
        write_files(a.out, res["files"])
    if a.apply:
        write_files(repo, res["files"])
    return 0


if __name__ == "__main__":
    sys.exit(main())
