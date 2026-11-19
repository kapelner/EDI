"""TODO-status audit: are the checkbox TODOs of the unreleased releases ticked correctly?

Plan: R/package_metadata/new_feature_plans/v1_0_6/audit_jobs_framework.md (Part 3).

Units are the top-level checkbox items (`- [ ]` / `- [x]`) of
`R/package_metadata/future_release_plans/release_v*.md` for releases not yet on CRAN, and
of the plan files under `new_feature_plans/` and `bug_fix_plans/` those release files link
to. A unit is its checkbox line plus its indented continuation lines (nested checkboxes
belong to the item they sit in). Struck-through pointers (`- [ ] ~~TODO-8~~ -> moved ...`)
are not judged: the mechanical stage checks that their target exists and lists the ones
whose target is ticked.

The parser (`parse_checkboxes`, `release_state`, `load_todo_state`) is also used by the
allowlist-hygiene audit, which imports it from here.

Agents have no shell, so everything that needs git is precomputed here: the commits that
cite a unit (`v1.0.6-TODO-43`, `v1.0.6 TODO-43`, `<plan>.md TODO-3`), their file lists and
diffs (written to the work folder), and the last commit of each file the unit names.
"""
import json
import os
import re
import subprocess
from pathlib import Path

import audit_common as ac

SPEC = {
    "name": "todo-status",
    "title": "TODO-status audit",
    "report": "pr",
    "claude": True,
    "model": ac.SONNET,        # per unit: Opus for the current and next release (see units())
    "batch_size": 8,
    "cycle_weeks": 12,         # per unit: 4 for open TODOs of the current and next release
    "max_batches": 16,
    "tools": "Read,Glob,Grep",
    "max_turns": 80,
}

META = "R/package_metadata"
RELEASES_DIR = f"{META}/future_release_plans"
PLAN_DIRS = (f"{META}/new_feature_plans/", f"{META}/bug_fix_plans/")
DESCRIPTION = "R/EDI/DESCRIPTION"
FAST_CYCLE, SLOW_CYCLE = 4, 12
MAX_UNIT_LINES = 400           # longer units are cut in the batch file; the agent reads the rest
MAX_DIFF_LINES = 1500
MAX_NAMED_FILES = 15
MAX_CITING = 20
VERDICTS = ("done", "partly done", "not done", "undone", "unclear")

# ---------------------------------------------------------------- parsing

CHECKBOX = re.compile(r"^(?P<indent>[ \t]*)[-*+] \[(?P<box>[ xX])\](?P<rest>(?:[ \t].*)?)$")
FENCE = re.compile(r"^[ \t]*(```|~~~)")
HEADING = re.compile(r"^#{1,6} ")
TODO_NUM = r"\d+[a-z]?(?:\.\d+[a-z]?)?"
LEAD_ID = re.compile(r"^[\s~*]*(TODO-" + TODO_NUM + r")(?![\w])")
AUDIT_NOTE = re.compile(r"\s*\*\((?:un)?ticked by the TODO audit [^\n]*?\)\*")
OWNER_CLOSED = re.compile(
    r"\bclosed\b[^\n]{0,100}?(?:\bby (?:the )?owner\b|\bowner decision\b|\(owner\b)"
    r"|\bowner decision\b[^\n]{0,100}?\bdone\b"
    r"|\bDECIDED\b[^\n]{0,40}?\(owner\)[^\n]{0,80}?\bCLOSED\b",
    re.I)
POINTER_TARGET = re.compile(
    r"(release_v\d+_\d+_\d+\.md|[\w-]+\.md)\s*(?:→|->)\s*TODO-(" + TODO_NUM + r")(?:\s*\.\.\s*(\d+))?")


def _indent(s):
    return len(s.expandtabs(4)) - len(s.expandtabs(4).lstrip(" "))


def strip_notes(text):
    """The text without the audit's own appended notes (so a tick does not count as an edit)."""
    return AUDIT_NOTE.sub("", text)


def parse_checkboxes(text, relpath):
    """Top-level checkbox items of a Markdown file.

    Returns a list of dicts: id, file, line (1-based), end_line, indent, checked, todo
    (e.g. "TODO-43" or None), first_line, text (the full item), pointer, owner_closed,
    targets ([(file basename, todo number)] named by a pointer).
    """
    lines = text.splitlines()
    items, seen = [], {}
    in_fence = False
    i = 0
    while i < len(lines):
        line = lines[i]
        if FENCE.match(line):
            in_fence = not in_fence
            i += 1
            continue
        m = None if in_fence else CHECKBOX.match(line)
        if not m:
            i += 1
            continue
        ind = _indent(m.group("indent"))
        end = i
        j = i + 1
        sub_fence = False
        while j < len(lines):
            nxt = lines[j]
            if not nxt.strip():
                j += 1
                continue
            if sub_fence:
                end = j
                if FENCE.match(nxt):
                    sub_fence = False
                j += 1
                continue
            if _indent(nxt) <= ind or HEADING.match(nxt):
                break
            if FENCE.match(nxt):
                sub_fence = True
            end = j
            j += 1
        body = "\n".join(lines[i:end + 1])
        rest = m.group("rest").strip()
        lead = LEAD_ID.match(rest)
        todo = lead.group(1) if lead else None
        pointer = rest.startswith("~~")
        norm = re.sub(r"\s+", " ", strip_notes(rest)).strip()
        base = f"{relpath}::{todo}" if todo else f"{relpath}::cb-{ac.text_hash(norm)[:8]}"
        n = seen.get(base, 0) + 1
        seen[base] = n
        uid = base if n == 1 else f"{base}#{n}"
        flat = re.sub(r"\s+", " ", body)
        targets = []
        if pointer:
            # Only the pointer's own lead (the bold part after the struck id) names its targets;
            # the rest of the text may cite other TODOs.
            lead_m = re.match(r"\s*[-*+] \[[ xX]\]\s*~~[^~]*~~\s*\*\*(.*?)\*\*", flat)
            lead_text = lead_m.group(1) if lead_m else re.sub(r"\s+", " ", line)
            for fm in POINTER_TARGET.finditer(lead_text):
                lo = fm.group(2)
                if fm.group(3) and lo.isdigit():
                    targets += [(fm.group(1), str(k)) for k in range(int(lo), int(fm.group(3)) + 1)]
                else:
                    targets.append((fm.group(1), lo))
        items.append({
            "id": uid, "file": relpath, "line": i + 1, "end_line": end + 1, "indent": ind,
            "checked": m.group("box") in "xX", "todo": todo, "first_line": line, "text": body,
            "pointer": pointer, "owner_closed": bool(OWNER_CLOSED.search(flat)), "targets": targets,
        })
        i = end + 1
    return items


def todo_number(todo):
    return todo.split("-", 1)[1] if todo else None


# ---------------------------------------------------------------- releases

RELEASE_FILE = re.compile(r"release_v(\d+)_(\d+)_(\d+)\.md$")
STATUS_RELEASED = re.compile(r"\bStatus:\**\s*(?:RELEASED|SHIPPED|PUBLISHED|ON CRAN)\b", re.I)
STATUS_UNRELEASED = re.compile(r"soon to be released|not yet released|unreleased", re.I)
STATUS_CLOSED_TO_NEW = re.compile(r"\bCLOSED to new (?:TODOs|work)\b", re.I)


def version_tuple(s):
    parts = re.findall(r"\d+", s or "")
    return tuple(int(p) for p in parts) if parts else ()


def description_version(repo):
    try:
        text = Path(repo, DESCRIPTION).read_text()
    except OSError:
        return ()
    m = re.search(r"^Version:\s*(\S+)", text, re.M)
    return version_tuple(m.group(1)) if m else ()


def status_lines(text):
    return [l for l in text.splitlines()[:40] if re.search(r"\bStatus:", l)]


def release_state(repo, relfile, text, desc_version):
    """{"version": (1, 0, 6), "label": "v1.0.6", "released": bool, "closed_to_new": bool}."""
    m = RELEASE_FILE.search(relfile)
    v = tuple(int(x) for x in m.groups())
    status = " ".join(status_lines(text))
    if STATUS_RELEASED.search(status):
        released = True
    elif STATUS_UNRELEASED.search(status):
        released = False
    else:
        released = bool(desc_version) and v <= desc_version
    return {"version": v, "label": "v" + ".".join(map(str, v)), "file": relfile, "released": released,
            "closed_to_new": bool(STATUS_CLOSED_TO_NEW.search(status))}


def model_split(releases):
    """Versions judged by Opus: the current and next release open to new TODOs, and any
    unreleased release below them (one closed to new work while it ships)."""
    unreleased = sorted((r for r in releases if not r["released"]), key=lambda r: r["version"])
    if not unreleased:
        return set(), None, None
    open_ = [r for r in unreleased if not r["closed_to_new"]] or unreleased
    current = open_[0]
    nxt = open_[1] if len(open_) > 1 else None
    top = (nxt or current)["version"]
    return {r["version"] for r in unreleased if r["version"] <= top}, current, nxt


# ---------------------------------------------------------------- git helpers

def _git(repo, *args):
    r = subprocess.run(["git", *args], cwd=repo, capture_output=True, text=True)
    return r.stdout if r.returncode == 0 else ""


def tracked(repo, *paths):
    return [l for l in _git(repo, "ls-files", *paths).splitlines() if l]


def commit_log(repo):
    """[{sha, short, date (ISO), subject, body}] for HEAD's history, newest first."""
    raw = _git(repo, "log", "--format=%H%x1f%h%x1f%cI%x1f%s%x1f%b%x1e")
    out = []
    for rec in raw.split("\x1e"):
        rec = rec.strip("\n")
        if not rec:
            continue
        f = rec.split("\x1f")
        if len(f) < 5:
            continue
        out.append({"sha": f[0], "short": f[1], "date": f[2], "subject": f[3], "body": f[4]})
    return out


def last_commits(repo):
    """path -> (short sha, ISO date, subject) of the last commit that touched it."""
    raw = _git(repo, "log", "--format=%x1e%h%x1f%cI%x1f%s", "--name-only")
    out = {}
    for rec in raw.split("\x1e"):
        lines = rec.strip("\n").split("\n")
        if not lines or not lines[0]:
            continue
        head = lines[0].split("\x1f")
        if len(head) < 3:
            continue
        for p in lines[1:]:
            p = p.strip()
            if p and p not in out:
                out[p] = (head[0], head[1], head[2])
    return out


CITE_VERSION = re.compile(
    r"\bv(\d+\.\d+\.\d+)[- ]TODO-(" + TODO_NUM + r")((?:\s*(?:/|,|&|and)\s*(?:TODO-)?\d+[a-z]?)*)(?![\w])")
CITE_FILE = re.compile(r"([\w-]+\.md)(?:\s*(?:→|->))?\s+TODO-(" + TODO_NUM + r")(?![\w])")


def citations(message):
    """{(file basename, todo number)} cited in a commit message. `v1.0.6-TODO-43` and
    `v1.0.6 TODO-43` cite release_v1_0_6.md; `plan.md TODO-3` cites plan.md."""
    keys = set()
    for m in CITE_VERSION.finditer(message):
        base = "release_v" + m.group(1).replace(".", "_") + ".md"
        keys.add((base, m.group(2)))
        for extra in re.findall(r"\d+[a-z]?", m.group(3) or ""):
            keys.add((base, extra))
    for m in CITE_FILE.finditer(message):
        keys.add((m.group(1), m.group(2)))
    return keys


def citation_index(log):
    idx = {}
    for c in log:
        for k in citations(c["subject"] + "\n" + c["body"]):
            idx.setdefault(k, []).append(c)
    return idx


# ---------------------------------------------------------------- named files and classes

CLASS_DEF = re.compile(
    r"^([A-Z]\w+)\s*(?:=|<-)\s*(?:define_inference_class|define_design_class|R6::R6Class|R6Class)\s*\("
    r"|^\s*classname\s*=\s*\"([A-Z]\w+)\""
    r"|(?:define_inference_class|define_design_class|R6::R6Class|R6Class)\s*\(\s*\"([A-Z]\w+)\"", re.M)
PATHLIKE = re.compile(r"^[\w.][\w./-]*\.(?:R|r|cpp|c|h|hpp|py|md|yml|yaml|csv|json|sh|txt|Rd|toml|cff)$")
CLASSLIKE = re.compile(r"^((?:Inference|Design)[A-Z]\w+)(?:\$\w+)?(?:\(\))?$")


def class_files(repo):
    """Class name -> repo-relative file that defines it (R/EDI/R/*.R)."""
    out = {}
    for f in tracked(repo, "R/EDI/R/*.R"):
        try:
            text = Path(repo, f).read_text(errors="replace")
        except OSError:
            continue
        for m in CLASS_DEF.finditer(text):
            out.setdefault(m.group(1) or m.group(2) or m.group(3), f)
    return out


def named_files(text, unit_file, tracked_set, by_base, classes):
    """Repo-relative files the unit names in backticks (paths, and classes via their file)."""
    found = []
    unit_dir = os.path.dirname(unit_file)
    for tok in re.findall(r"`([^`\n]{2,200})`", text):
        tok = tok.strip()
        tok = re.split(r"\s*(?:→|->)\s*", tok)[0].strip()
        tok = re.sub(r":\d[\d-]*$", "", tok)
        cm = CLASSLIKE.match(tok)
        if cm:
            f = classes.get(cm.group(1))
            if f:
                found.append(f)
            continue
        if not PATHLIKE.match(tok):
            continue
        cands = [tok, os.path.normpath(os.path.join(unit_dir, tok)), "R/" + tok, f"{META}/{tok}",
                 "R/EDI/" + tok]
        hit = next((c for c in cands if c in tracked_set), None)
        if not hit and "/" not in tok:
            opts = by_base.get(tok, [])
            hit = opts[0] if len(opts) == 1 else None
        found.append(hit or tok)
    out = []
    for f in found:
        if f not in out:
            out.append(f)
    return out[:MAX_NAMED_FILES]


# ---------------------------------------------------------------- scope

LINK = re.compile(r"[\w./-]*[\w-]+\.md")


def linked_plans(release_relfile, text, tracked_set, plan_by_base):
    """Plan files under new_feature_plans/ or bug_fix_plans/ a release file links to."""
    rel_dir = os.path.dirname(release_relfile)
    m = RELEASE_FILE.search(release_relfile)
    own_dir = f"v{m.group(1)}_{m.group(2)}_{m.group(3)}" if m else None
    out = []
    for tok in set(LINK.findall(text)):
        hit = None
        if "/" in tok:
            for c in (os.path.normpath(os.path.join(rel_dir, tok)), os.path.normpath(f"{META}/{tok}"),
                      os.path.normpath(tok)):
                if c in tracked_set:
                    hit = c
                    break
        else:
            opts = plan_by_base.get(tok, [])
            if len(opts) == 1:
                hit = opts[0]
            elif own_dir:
                own = [o for o in opts if f"/{own_dir}/" in o]
                hit = own[0] if len(own) == 1 else None
        if hit and hit.startswith(PLAN_DIRS) and "/graft/" not in hit:
            out.append(hit)
    return sorted(set(out))


def load_todo_state(repo):
    """Every release file's and in-scope plan file's checkbox items.

    Returns {"releases": [release_state...], "items": {file: [items]}, "file_release": {file:
    release_state (the earliest release that links it)}, "opus": set of versions, "current",
    "next"}. Released versions' files are parsed too (allowlist hygiene needs their state)
    but marked in_scope False.
    """
    repo = Path(repo)
    desc = description_version(repo)
    files = tracked(repo, f"{RELEASES_DIR}/release_v*.md")
    all_md = tracked(repo, f"{META}/*.md")
    tracked_set = set(all_md)
    plan_by_base = {}
    for f in all_md:
        if f.startswith(PLAN_DIRS) and "/graft/" not in f:
            plan_by_base.setdefault(os.path.basename(f), []).append(f)
    releases, items, file_release, in_scope = [], {}, {}, {}
    texts = {}
    for f in files:
        if not RELEASE_FILE.search(f):
            continue
        texts[f] = (repo / f).read_text(errors="replace")
        releases.append(release_state(repo, f, texts[f], desc))
    releases.sort(key=lambda r: r["version"])
    opus, current, nxt = model_split(releases)
    for r in releases:
        f = r["file"]
        items[f] = parse_checkboxes(texts[f], f)
        file_release[f] = r
        in_scope[f] = not r["released"]
        if r["released"]:
            continue
        for p in linked_plans(f, texts[f], tracked_set, plan_by_base):
            if p not in file_release or (file_release[p]["released"] and not r["released"]):
                file_release[p] = r
                in_scope[p] = True
    for p in list(file_release):
        if p not in items:
            try:
                items[p] = parse_checkboxes((repo / p).read_text(errors="replace"), p)
            except OSError:
                items[p] = []
    return {"releases": releases, "items": items, "file_release": file_release, "in_scope": in_scope,
            "opus": opus, "current": current, "next": nxt}


def todo_lookup(state):
    """(file basename, todo number) -> item, over every parsed file (release files first)."""
    out = {}
    for f, its in state["items"].items():
        for it in its:
            if it["todo"]:
                out.setdefault((os.path.basename(f), todo_number(it["todo"])), it)
    return out


# ---------------------------------------------------------------- audit stages

_CACHE = {}
_TIDY = {}      # repo -> {unit id: {"checkout_line", "checkout_todo"}} after this run's tidy


def tidy(ctx):
    """Mechanical tidy of the unreleased release files (audits/_todo_tidy.py): renumber duplicate
    TODO numbers, then put each section's entries in numeric order. Edits the work tree; audit_run
    calls it before `mechanical` in prepare and again (same commit, same result) in finish, where
    the change becomes its own commit, ahead of the Claude stage's ticks.

    Returns {"files", "applied", "human" (decision dicts), "info", "message"}."""
    from audits import _todo_tidy as tt
    repo = Path(ctx.repo)
    files, closed = tt.unreleased_release_files(repo)
    originals = {f: (repo / f).read_text(errors="replace") for f in files}
    res = tt.tidy_files(repo, files, no_reorder=closed)
    tt.write_files(repo, res["files"])
    _CACHE.pop(str(ctx.repo), None)
    # Where each moved or renumbered entry sits in the agents' checkout (which is not tidied).
    where = {}
    for f in files:
        if f not in res["files"]:
            continue
        before = parse_checkboxes(originals[f], f)
        after = parse_checkboxes(res["files"][f], f)
        renum = {e["line"]: e["new"] for r in res["report"] if r["file"] == f for e in r["renumbered"]}
        pool = {}
        for it in before:
            key = it["todo"] and ("TODO-" + renum[it["line"]] if it["line"] in renum else it["todo"])
            pool.setdefault((key, len(it["text"].splitlines())), []).append(it)
        for it in after:
            cands = pool.get((it["todo"], len(it["text"].splitlines()))) or []
            if not cands:
                continue
            old = cands.pop(0)
            if old["line"] != it["line"] or old["todo"] != it["todo"]:
                where[it["id"]] = {"checkout_line": old["line"], "checkout_todo": old["todo"]}
    _TIDY[str(ctx.repo)] = where
    applied, human, info = tt.summarise(res)
    msg = ("TODO-status audit: mechanical tidy of the release files\n\n"
           "Renumber duplicate TODO numbers and put each section's entries in numeric order "
           "(.github/scripts/audits/_todo_tidy.py). No entry text changes apart from renumbered ids.")
    return {"files": sorted(res["files"]), "applied": applied, "info": info, "message": msg,
            "human": [ac.decision(h["text"], unit=h["unit"], key="tidy-ambiguous-ref") for h in human]}


def _state(ctx):
    key = str(ctx.repo)
    if key not in _CACHE:
        _CACHE[key] = load_todo_state(ctx.repo)
    return _CACHE[key]


def find_target(st, look, base, num, repo):
    """The item a pointer names, or a stand-in for a group (TODO-1 -> TODO-1a, TODO-1b ...).
    Files outside the audit's scope (e.g. finished_features/) are parsed on demand.
    Returns (item or None, file found)."""
    if (base, num) in look:
        return look[(base, num)], True
    if not any(os.path.basename(f) == base for f in st["items"]):
        hits = [f for f in tracked(repo, f"{META}/*.md") if os.path.basename(f) == base]
        for f in hits:
            try:
                st["items"][f] = parse_checkboxes(Path(repo, f).read_text(errors="replace"), f)
            except OSError:
                continue
            for it in st["items"][f]:
                if it["todo"]:
                    look.setdefault((base, todo_number(it["todo"])), it)
        if (base, num) in look:
            return look[(base, num)], True
        if not hits:
            return None, False
    group = [it for (b, n), it in look.items() if b == base and re.fullmatch(re.escape(num) + r"[a-z]", n)]
    if group:
        return {"checked": all(g["checked"] for g in group), "group": True}, True
    return None, True


def mechanical(ctx):
    """Pointers: the target must exist; a ticked target is listed for the owner."""
    st = _state(ctx)
    look = todo_lookup(st)
    found = []
    for f, its in list(st["items"].items()):
        if not st["in_scope"].get(f):
            continue
        for it in list(its):
            if not it["pointer"] or not it["targets"]:
                continue
            for base, num in it["targets"]:
                tgt, file_found = find_target(st, look, base, num, ctx.repo)
                where = f"`{f}` line {it['line']} ({it['todo'] or 'pointer'})"
                if tgt is None:
                    what = "which is not a checkbox item there" if file_found else f"but no file `{base}` exists"
                    found.append({"unit": it["id"], "kind": "pointer-target-missing",
                                  "text": f"{where} points to `{base} → TODO-{num}`, {what}."})
                elif tgt["checked"] and not it["checked"]:
                    found.append({"unit": it["id"], "kind": "pointer-target-ticked",
                                  "text": f"{where} points to `{base} → TODO-{num}`, which is ticked; "
                                          "the pointer is left as it is (pointers are never ticked)."})
    return found


def _previous_verdicts(ctx):
    try:
        return json.loads((ctx.notes.dir / "verdicts.json").read_text())
    except (OSError, ValueError):
        return {}


def units(ctx):
    st = _state(ctx)
    repo = ctx.repo
    log = commit_log(repo)
    idx = citation_index(log)
    last = last_commits(repo)
    all_files = tracked(repo)
    tracked_set = set(all_files)
    by_base = {}
    for f in all_files:
        by_base.setdefault(os.path.basename(f), []).append(f)
    classes = class_files(repo)
    seen = ctx.manifest.get("units", {})
    prev = _previous_verdicts(ctx)
    tidied = _TIDY.get(str(repo), {})
    commits_dir = Path(ctx.workdir) / "commits"
    written = set()
    out = {}
    for f, its in st["items"].items():
        if not st["in_scope"].get(f):
            continue
        rel = st["file_release"][f]
        opus = rel["version"] in st["opus"]
        for it in its:
            if it["pointer"]:
                continue
            uid = it["id"]
            cites = idx.get((os.path.basename(f), todo_number(it["todo"])), []) if it["todo"] else []
            cites = cites[:MAX_CITING]
            names = named_files(it["text"], f, tracked_set, by_base, classes)
            named = []
            for p in names:
                lc = last.get(p)
                named.append({"path": p, "exists": p in tracked_set,
                              "last_commit": f"{lc[0]} {lc[1][:10]} {lc[2]}" if lc else None})
            audited = ac.parse_time(seen.get(uid, {}).get("audited_at"))
            cite_rows = []
            for c in cites:
                diff_rel = f".audit-work/commits/{c['short']}.diff"
                if c["short"] not in written:
                    _write_diff(repo, c, commits_dir)
                    written.add(c["short"])
                when = ac.parse_time(c["date"])
                cite_rows.append({"sha": c["short"], "date": c["date"][:10], "subject": c["subject"],
                                  "since_last_audit": bool(audited is None or (when and when > audited)),
                                  "diff": diff_rel})
            lines = it["text"].splitlines()
            text = "\n".join(lines[:MAX_UNIT_LINES])
            if len(lines) > MAX_UNIT_LINES:
                text += f"\n[... cut at {MAX_UNIT_LINES} lines; read the rest in the file]"
            checked = it["checked"]
            norm = re.sub(r"^(\s*[-*+] )\[[ xX]\]", r"\1[ ]", strip_notes(it["text"]))
            out[uid] = {
                "hash": ac.text_hash(norm),
                "deps": ac.text_hash([c["sha"] for c in cites],
                                     [(n["path"], n["last_commit"]) for n in named]),
                "model": ac.OPUS if opus else ac.SONNET,
                "cycle_weeks": SLOW_CYCLE if (checked or not opus) else FAST_CYCLE,
                # A capped run reads open current/next-release TODOs first, later releases last.
                "priority": 0 if (opus and not checked) else (1 if opus else 2),
                "context": {
                    "file": f, "lines": f"{it['line']}-{it['end_line']}", "release": rel["label"],
                    "checked": checked, "owner_closed": it["owner_closed"], "todo": it["todo"],
                    "text": text, "citing_commits": cite_rows, "named_files": named,
                    "previous_verdict": prev.get(uid, {}).get("verdict"),
                    **({"in_your_checkout": {**tidied[uid], "note": (
                        "This run's mechanical tidy moved or renumbered this entry; `lines` and `todo` "
                        "are after the tidy. The checked-out file still has it at checkout_line as "
                        "checkout_todo.")}} if uid in tidied else {}),
                },
            }
    return out


def _write_diff(repo, c, commits_dir):
    commits_dir.mkdir(parents=True, exist_ok=True)
    show = _git(repo, "show", "--stat", "--patch", "--format=commit %H%nDate: %cI%n%n%s%n%n%b", c["sha"])
    lines = show.splitlines()
    if len(lines) > MAX_DIFF_LINES:
        lines = lines[:MAX_DIFF_LINES] + [f"[... diff cut at {MAX_DIFF_LINES} lines]"]
    (commits_dir / f"{c['short']}.diff").write_text("\n".join(lines) + "\n")


# ---------------------------------------------------------------- apply

SHA = re.compile(r"^[0-9a-f]{7,40}$")
FILE_LINE = re.compile(r"^([\w./-]+\.\w+)(?::(\d+)(?:-\d+)?)?$")


class Evidence:
    """Checks that an evidence reference points at something real on this checkout."""

    def __init__(self, repo):
        self.repo = Path(repo)
        self._tests = None

    def ok(self, ref):
        ref = (ref or "").strip().strip("`")
        if not ref:
            return False
        if SHA.match(ref):
            return subprocess.run(["git", "cat-file", "-e", f"{ref}^{{commit}}"], cwd=self.repo,
                                  capture_output=True).returncode == 0
        m = FILE_LINE.match(ref)
        if m and (self.repo / m.group(1)).is_file():
            if not m.group(2):
                return True
            try:
                with open(self.repo / m.group(1), errors="replace") as fh:
                    n = sum(1 for _ in fh)
            except OSError:
                return False
            return int(m.group(2)) <= n
        return self.test_exists(ref)

    def test_exists(self, name):
        """A test name: a test file, or a test_that() / def test_ name in the test folders."""
        if self._tests is None:
            self._tests = []
            for d in ("R/EDI/tests", "python/tests", ".github/scripts", "R/package_tests"):
                for p in (self.repo / d).rglob("*") if (self.repo / d).is_dir() else []:
                    if p.is_file() and p.suffix in (".R", ".py") and "test" in p.name.lower():
                        self._tests.append(p)
        base = os.path.basename(name)
        if any(p.name == base for p in self._tests):
            return True
        if len(name) < 8:
            return False
        for p in self._tests:
            try:
                if name in p.read_text(errors="replace"):
                    return True
            except OSError:
                pass
        return False


def _clean(s, limit):
    s = re.sub(r"\s+", " ", str(s or "")).replace("*", "").replace("`", "").strip()
    return s if len(s) <= limit else s[:limit - 3].rstrip() + "..."


def _refs(finding):
    refs = []
    for p in finding.get("parts") or []:
        for e in p.get("evidence") or []:
            r = (e.get("ref") if isinstance(e, dict) else e) or ""
            r = r.strip().strip("`")
            if r and r not in refs:
                refs.append(r)
    return refs


def check_done(finding, ev):
    """None if a `done` verdict has verified evidence for every part, else the reason."""
    parts = finding.get("parts") or []
    if not parts:
        return "no parts listed"
    for p in parts:
        if p.get("status") != "done":
            return f"part not done: {_clean(p.get('part'), 120)}"
        refs = [(e.get("ref") if isinstance(e, dict) else e) for e in (p.get("evidence") or [])]
        if not refs:
            return f"no evidence for part: {_clean(p.get('part'), 120)}"
        if not any(ev.ok(r) for r in refs):
            return f"evidence not found on this checkout for part: {_clean(p.get('part'), 120)} ({', '.join(map(str, refs))})"
    return None


def set_box(path, line_no, checked, note):
    """Change the checkbox on `line_no` (1-based) and append `note` to that line."""
    lines = Path(path).read_text().split("\n")
    line = lines[line_no - 1]
    want_from = " " if checked else "[xX]"
    new = re.sub(r"^(\s*[-*+] )\[" + want_from + r"\]", r"\1[" + ("x" if checked else " ") + "]", line, count=1)
    if new == line:
        raise ValueError(f"{path}:{line_no}: checkbox not in the expected state")
    lines[line_no - 1] = new.rstrip() + " " + note
    Path(path).write_text("\n".join(lines))


def apply(ctx, results, mech):
    st = load_todo_state(ctx.repo)      # re-read: the work tree is what we edit
    by_id = {it["id"]: it for its in st["items"].values() for it in its}
    ev = Evidence(ctx.repo)
    date = ctx.now.date().isoformat()
    prev = _previous_verdicts(ctx)
    applied, human, proposed, changed_info, partly = [], [], [], [], []
    counts = {}
    verdicts = dict(prev)
    for r in results:
        allowed = set(r.get("_units") or [])
        for f in r.get("findings") or []:
            uid, verdict = f.get("unit"), f.get("kind")
            if uid not in allowed or verdict not in VERDICTS:
                continue
            counts[verdict] = counts.get(verdict, 0) + 1
            it = by_id.get(uid)
            summary = _clean(f.get("text"), 400)
            label = f"`{uid}`"
            old = (prev.get(uid) or {}).get("verdict")
            verdicts[uid] = {"verdict": verdict, "at": date, "text": summary}
            if it is None:
                human.append(ac.decision(f"{label}: verdict `{verdict}`, but the item is no longer in the file; not applied.", unit=uid, key="item-gone"))
                continue
            path = ctx.path(it["file"])
            if verdict == "done":
                if it["checked"]:
                    continue
                if it["pointer"]:
                    human.append(ac.decision(f"{label}: `done`, but it is a pointer; pointers are never ticked. {summary}", unit=uid, key="pointer-done"))
                    continue
                why = check_done(f, ev)
                if why:
                    human.append(ac.decision(f"{label}: `done` but not ticked ({why}). {summary}", unit=uid, key="done-not-ticked"))
                    continue
                refs = _refs(f)
                note = f"*(ticked by the TODO audit {date}: {_clean('; '.join(refs), 300)})*"
                set_box(path, it["line"], True, note)
                applied.append(f"`{it['file']}` {it['todo'] or 'line ' + str(it['line'])}: ticked. {summary}")
                proposed.append({"unit": uid, "kind": "tick", "text": "tick on evidence: " + "; ".join(sorted(refs)),
                                 "applied_file": it["file"], "applied_text": note})
            elif verdict == "undone":
                if not it["checked"]:
                    continue
                gap = _clean(f.get("gap") or f.get("text"), 300)
                if it["owner_closed"]:
                    human.append(ac.decision(f"{label}: `undone` ({gap}), but the owner closed this item explicitly; "
                                 "not unticked.", unit=uid, key="undone-owner-closed"))
                    continue
                if not gap:
                    human.append(ac.decision(f"{label}: `undone` with no gap stated; not unticked.", unit=uid, key="undone-no-gap"))
                    continue
                note = f"*(unticked by the TODO audit {date}: {gap})*"
                set_box(path, it["line"], False, note)
                applied.append(f"`{it['file']}` {it['todo'] or 'line ' + str(it['line'])}: unticked. {gap}")
                proposed.append({"unit": uid, "kind": "untick", "text": "untick: " + gap,
                                 "applied_file": it["file"], "applied_text": note})
            elif verdict == "partly done":
                parts = []
                for p in f.get("parts") or []:
                    refs = ", ".join(_clean(e.get("ref") if isinstance(e, dict) else e, 80)
                                     for e in (p.get("evidence") or []))
                    parts.append(f"{p.get('status', '?')}: {_clean(p.get('part'), 160)}"
                                 + (f" ({refs})" if refs else ""))
                partly.append(f"{label}: partly done. {summary}" + ("<br>" + "<br>".join(parts) if parts else ""))
            elif verdict == "unclear":
                # The agent could not tell from the code: a decision for the owner (tick it, reword it so
                # a reader can check it, or dismiss the id), kept until a re-read gives a clear verdict.
                human.append(ac.decision(f"{label}: status unclear from the code. {summary} Tick or reword the "
                                         "TODO, or dismiss this id.", unit=uid, key="unclear"))
            else:   # not done: the TODO itself tracks the work
                if old != verdict:
                    changed_info.append(f"{label}: `{verdict}`" + (f" (was `{old}`)" if old else "")
                                        + f". {summary}")
    try:
        ctx.notes.dir.mkdir(parents=True, exist_ok=True)
        (ctx.notes.dir / "verdicts.json").write_text(json.dumps(verdicts, indent=1, sort_keys=True) + "\n")
    except OSError:
        pass
    # Changed `not done` verdicts and `partly done` progress notes are information, not
    # decisions (the TODO already tracks the work): they go in the collapsed "For information" block,
    # which comes last, so a report over GitHub's body limit is cut there first (audit_common.fit_body).
    info = changed_info + partly
    tally = ", ".join(f"{v} {k}" for k, v in sorted(counts.items())) or "no verdicts"
    split = ", ".join("v" + ".".join(map(str, v)) for v in sorted(st["opus"])) or "none"
    summary = (f"Verdicts this run: {tally}. Opus judged the TODOs of {split}; Sonnet the later releases. "
               "Every tick and untick below needs the owner's review; reverting one on this branch records "
               "it as rejected.")
    return {"summary": summary, "applied": applied, "mechanical": [m["text"] for m in mech],
            "human": human, "info": info, "proposed": proposed}
