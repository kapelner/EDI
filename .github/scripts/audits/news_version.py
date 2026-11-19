"""NEWS and version consistency.

Plan: R/package_metadata/new_feature_plans/v1_0_6/audit_jobs_framework.md (Part 4, "NEWS and version
consistency").

Mechanical: the version numbers in R/EDI/DESCRIPTION, the Python package (python/pyproject.toml and
its CHANGELOG), the citation files (CITATION.cff, python/CITATION.cff, codemeta.json,
R/EDI/inst/CITATION) and the BibTeX blocks of the READMEs must agree with DESCRIPTION, and
DESCRIPTION must not be behind the last release tag. A `.postN` / `.devN` suffix (Python packaging)
and a fourth component (`1.0.4.9000`, R development) are ignored in the comparison.

Claude (Sonnet): one unit per commit since the last release tag that touches R/EDI/R or R/EDI/src.
The agent decides whether the commit changes behaviour a user can see and, if so, whether the top
section of R/EDI/NEWS.md covers it. Drafted NEWS lines go to "Needs a human"; nothing is applied.
"""
import json
import re
from pathlib import Path

import audit_common as ac

SPEC = {
    "name": "news-version",
    "title": "NEWS and version consistency",
    "report": "pr",
    "claude": True,
    "model": ac.SONNET,
    "batch_size": 8,
    "cycle_weeks": 52,        # a commit is judged once; a NEWS edit re-checks every commit (deps)
    "max_batches": 5,
    "tools": "Read,Glob,Grep",
    "max_turns": 50,
}

DESCRIPTION = "R/EDI/DESCRIPTION"
NEWS = "R/EDI/NEWS.md"
CODE_PATHS = ("R/EDI/R", "R/EDI/src")
MAX_DIFF_LINES = 2000
MAX_BODY = 3000
VERDICTS = ("covered", "missing", "not user-visible", "unclear")

# (path, how to read the version, what must hold)
TOML_VERSION = re.compile(r'^\[project\][^\[]*?^version\s*=\s*"([^"]+)"', re.M | re.S)
CFF_VERSION = re.compile(r'^version:\s*"?([^"\s]+)"?\s*$', re.M)
BIB_VERSION = re.compile(r"^\s*version\s*=\s*\{([^}]+)\}", re.M)
RCIT_VERSION = re.compile(r"R package version (\d+(?:\.\d+)+)")
NEWS_TOP = re.compile(r"^# \S+ (\S+)", re.M)
CHANGELOG_TOP = re.compile(r"^## \[(\d+(?:\.\d+)+[^\]]*)\]", re.M)
TAG = re.compile(r"^v(\d+)\.(\d+)\.(\d+)$")


def core(v):
    """(1, 0, 4) from 1.0.4, 1.0.4.post3, 1.0.4.dev0, 1.0.4.9000 or 1.0.4rc1."""
    m = re.match(r"(\d+)\.(\d+)(?:\.(\d+))?", v or "")
    return tuple(int(x or 0) for x in m.groups()) if m else None


def vstr(t):
    return ".".join(map(str, t)) if t else "?"


def _git(repo, *args):
    import subprocess
    r = subprocess.run(["git", *args], cwd=repo, capture_output=True, text=True)
    return r.stdout if r.returncode == 0 else ""


def last_release_tag(repo):
    """(tag, version tuple) of the highest v<x.y.z> tag reachable from HEAD, or (None, None)."""
    best = (None, None)
    for t in _git(repo, "tag", "--merged", "HEAD", "--list", "v*").split():
        m = TAG.match(t)
        if m:
            v = tuple(int(x) for x in m.groups())
            if best[1] is None or v > best[1]:
                best = (t, v)
    return best


def version_sources(ctx):
    """[(path, version string, rule)] for every file that states a version. rule: "equal" or
    "not-behind" (NEWS may already have the next version's section)."""
    out = []
    t = ctx.read("python/pyproject.toml")
    if t and TOML_VERSION.search(t):
        out.append(("python/pyproject.toml", TOML_VERSION.search(t).group(1), "equal"))
    for p in ("CITATION.cff", "python/CITATION.cff"):
        t = ctx.read(p)
        if t and CFF_VERSION.search(t):
            out.append((p, CFF_VERSION.search(t).group(1), "equal"))
    t = ctx.read("codemeta.json")
    if t:
        try:
            v = json.loads(t).get("version")
            if v:
                out.append(("codemeta.json", str(v), "equal"))
        except ValueError:
            pass
    t = ctx.read("R/EDI/inst/CITATION")
    if t:
        for m in RCIT_VERSION.finditer(t):
            out.append(("R/EDI/inst/CITATION", m.group(1), "equal"))
    for p in ("README.md", "R/EDI/README.md", "python/README.md", "python/README_PYPI.md"):
        t = ctx.read(p)
        for m in BIB_VERSION.finditer(t or ""):
            out.append((p, m.group(1).strip(), "equal"))
    t = ctx.read(NEWS)
    if t and NEWS_TOP.search(t):
        out.append((NEWS, NEWS_TOP.search(t).group(1), "not-behind"))
    t = ctx.read("python/CHANGELOG.md")
    if t and CHANGELOG_TOP.search(t):
        out.append(("python/CHANGELOG.md", CHANGELOG_TOP.search(t).group(1), "not-behind"))
    return out


def description_version(ctx):
    m = re.search(r"^Version:\s*(\S+)", ctx.read(DESCRIPTION) or "", re.M)
    return m.group(1) if m else None


def news_top(text):
    """(version, text) of NEWS.md's first `# ` section."""
    m = NEWS_TOP.search(text or "")
    if not m:
        return None, ""
    nxt = re.search(r"^# ", text[m.end():], re.M)
    end = m.end() + nxt.start() if nxt else len(text)
    return m.group(1), text[m.start():end]


def mechanical(ctx):
    out = []
    desc = description_version(ctx)
    d = core(desc)
    if d is None:
        return [{"unit": DESCRIPTION, "kind": "version-missing", "text": f"`{DESCRIPTION}` has no Version field."}]
    for path, v, rule in version_sources(ctx):
        c = core(v)
        if c is None and rule == "not-behind" and v.startswith("(development"):
            continue  # "# EDI (development version)": the next version, not yet numbered
        if c is None:
            out.append({"unit": path, "kind": "version-unreadable", "text": f"`{path}`: cannot read version `{v}`."})
        elif rule == "equal" and c != d:
            out.append({"unit": path, "kind": "version-mismatch",
                        "text": f"`{path}` says {v}; `{DESCRIPTION}` says {desc}. "
                                "DESCRIPTION is the single source: run `python3 scripts/sync_version.py`."})
        elif rule == "not-behind" and c < d:
            out.append({"unit": path, "kind": "version-behind",
                        "text": f"`{path}`'s top section is {v}, behind `{DESCRIPTION}`'s {desc}."})
    tag, tv = last_release_tag(ctx.repo)
    if tv and d < tv:
        out.append({"unit": DESCRIPTION, "kind": "behind-tag",
                    "text": f"`{DESCRIPTION}` says {desc}, behind the release tag `{tag}`."})
    top_v, _ = news_top(ctx.read(NEWS))
    n = len(release_commits(ctx.repo, tag)) if tag else 0
    if tag and n and core(top_v) is not None and core(top_v) <= tv:
        out.append({"unit": NEWS, "kind": "no-section-after-tag",
                    "text": f"`{NEWS}`'s top section is `{top_v}`, not newer than the release tag `{tag}`, so it cannot "
                            f"describe the {n} commit(s) since then that change `R/EDI/R` or `R/EDI/src`. "
                            "Add a section for the next version when the first user-visible change lands."})
    return out


def release_commits(repo, tag):
    rng = f"{tag}..HEAD" if tag else "HEAD"
    raw = _git(repo, "log", "--no-merges", "--format=%H%x1f%h%x1f%cI%x1f%s%x1f%b%x1e", rng, "--", *CODE_PATHS)
    out = []
    for rec in raw.split("\x1e"):
        f = rec.strip("\n").split("\x1f")
        if len(f) >= 5:
            out.append({"sha": f[0], "short": f[1], "date": f[2], "subject": f[3], "body": f[4]})
    return out


def units(ctx):
    tag, _ = last_release_tag(ctx.repo)
    if not tag:
        return {}
    top_v, top_text = news_top(ctx.read(NEWS))
    work = Path(ctx.workdir)
    (work / "news_commits").mkdir(parents=True, exist_ok=True)
    (work / "news_top.md").write_text(top_text or "(R/EDI/NEWS.md has no section)\n")
    deps = ac.text_hash(top_text)
    out = {}
    for c in release_commits(ctx.repo, tag):
        stat = _git(ctx.repo, "show", "--stat=200", "--format=", c["sha"]).strip()
        diff = _git(ctx.repo, "show", "--format=commit %H%nDate: %cI%n%n%s%n%n%b", c["sha"]).splitlines()
        if len(diff) > MAX_DIFF_LINES:
            diff = diff[:MAX_DIFF_LINES] + [f"[... diff cut at {MAX_DIFF_LINES} lines]"]
        (work / "news_commits" / f"{c['short']}.diff").write_text("\n".join(diff) + "\n")
        body = c["body"].strip()
        out[f"commit:{c['short']}"] = {
            "hash": c["sha"], "deps": deps,
            "context": {"sha": c["sha"], "date": c["date"][:10], "subject": c["subject"],
                        "body": body[:MAX_BODY] + ("\n[... cut]" if len(body) > MAX_BODY else ""),
                        "diffstat": stat, "diff": f".audit-work/news_commits/{c['short']}.diff",
                        "since_tag": tag, "news_top": ".audit-work/news_top.md", "news_top_version": top_v},
        }
    return out


def apply(ctx, results, mech):
    human, counts = [], {}
    for r in results:
        allowed = set(r.get("_units") or [])
        for f in r.get("findings") or []:
            uid, v = f.get("unit"), f.get("kind")
            if uid not in allowed or v not in VERDICTS:
                continue
            counts[v] = counts.get(v, 0) + 1
            text = re.sub(r"\s+", " ", str(f.get("text") or "")).strip()
            if v == "missing":
                line = str(f.get("news_line") or "").strip()
                sec = str(f.get("news_section") or "").strip() or "(section not given)"
                human.append(ac.decision(f"`{uid}`: user-visible, not in NEWS. {text}<br>Draft for `{sec}`:<br>"
                             f"<code>{line or '(no draft)'}</code>", unit=uid, key="missing"))
            elif v == "unclear":
                human.append(ac.decision(f"`{uid}`: unclear whether users see this. {text}", unit=uid, key="unclear"))
    tally = ", ".join(f"{n} {k}" for k, n in sorted(counts.items())) or "no commits judged"
    summary = (f"Commits judged this run: {tally}. Drafted NEWS lines are never applied: copy the ones you "
               f"agree with into `{NEWS}`.")
    return {"summary": summary, "applied": [], "mechanical": [m["text"] for m in mech], "human": human,
            "proposed": []}
