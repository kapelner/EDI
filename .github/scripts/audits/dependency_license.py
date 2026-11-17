"""Dependency and license drift (monthly, PR, Claude only to summarise NEWS).

Plan: R/package_metadata/new_feature_plans/v1_0_6/audit_jobs_framework.md (Part 4,
"Dependency and license drift"; audit_jobs_framework.md TODO-16).

Mechanical, for every package in R/EDI/DESCRIPTION Depends/Imports/Suggests/LinkingTo (base
R packages skipped), from its CRAN page https://cran.r-project.org/web/packages/<pkg>/index.html:

- license changed since the recorded snapshot (`license_snapshot.json` in this audit's notes
  folder on the audit-notes branch; the first run only records it);
- package archived on CRAN (the page says it was removed from the repository);
- CRAN page unreadable (reported, never treated as unchanged);
- for packages whose version changed since the snapshot: functions their NEWS calls
  deprecated or defunct that EDI still calls as `pkg::fun(` or imports with
  `importFrom(pkg, fun)` (a cheap text match; misses unqualified calls of Depends packages).

The packages behind the dataset catalog rows deliberately pinned to old releases (the
"deliberately pinned" table in R/package_metadata/dataset_license_audit.md) are never
flagged for version drift: no NEWS summary and no deprecation check. Their license is still
compared, because EDI's own dependency on the current release is a separate question from
the pinned dataset rows.

Claude (Sonnet): one unit per non-pinned package whose version changed, with the NEWS excerpt
between the recorded and the current version precomputed; the agent says what EDI should
check. Nothing is applied: every result goes under "Needs a human". The snapshot is updated
in the finish stage, so a run that fails before it re-reports the change next time.
"""
import html
import json
import re
import time
import urllib.error
import urllib.request
from pathlib import Path

import audit_common as ac

DESCRIPTION = "R/EDI/DESCRIPTION"
NAMESPACE = "R/EDI/NAMESPACE"
R_DIR = "R/EDI/R"
CRAN = "https://cran.r-project.org/web/packages"
USER_AGENT = "Mozilla/5.0 (compatible; scheduled-audit; python-urllib)"
SNAPSHOT = "license_snapshot.json"
PENDING = "license_snapshot.pending.json"
NEWS_CHARS = 6000
BASE_PACKAGES = {"R", "base", "compiler", "datasets", "grDevices", "graphics", "grid", "methods", "parallel",
                 "splines", "stats", "stats4", "tcltk", "tools", "utils"}

SPEC = {
    "period": "month",   # monthly job: the rotation cycle counts its monthly runs
    "name": "dependency-license",
    "title": "Dependency and license drift",
    "report": "pr",
    "claude": True,
    "model": ac.SONNET,
    "batch_size": 8,
    "max_batches": 4,
    "cycle_weeks": 52,          # units exist only for version changes; rotation is not used
    "tools": "Read,Glob,Grep",
    "max_turns": 40,
}


# ---------------------------------------------------------------- inputs

def description_packages(text):
    """{package: field} for Depends/Imports/Suggests/LinkingTo, version constraints dropped."""
    fields, cur = {}, None
    for line in text.splitlines():
        m = re.match(r"^([A-Za-z][A-Za-z0-9/._-]*):\s*(.*)$", line)
        if m:
            cur = m.group(1)
            fields[cur] = m.group(2)
        elif cur and line[:1].isspace():
            fields[cur] += " " + line.strip()
    out = {}
    for field in ("Depends", "Imports", "LinkingTo", "Suggests"):
        for item in fields.get(field, "").split(","):
            name = re.sub(r"\(.*?\)", "", item).strip()
            if name and name not in BASE_PACKAGES and name not in out:
                out[name] = field
    return out


def pinned_packages(repo):
    """Packages named in the dataset catalog's "deliberately pinned" table(s)."""
    out = set()
    meta = Path(repo) / "R" / "package_metadata"
    for p in sorted(meta.glob("*dataset*.md")):
        text = p.read_text(errors="replace")
        for m in re.finditer(r"(?ims)^#+[^\n]*deliberately pinned[^\n]*\n(.*?)(?=^#+ |\Z)", text):
            for line in m.group(1).splitlines():
                cells = [c.strip() for c in line.strip().strip("|").split("|")]
                if len(cells) < 2 or set(cells[1]) <= set("-: "):
                    continue
                name = re.match(r"`?([A-Za-z][A-Za-z0-9.]*)\s+\d", cells[1])
                if name:
                    out.add(name.group(1))
    return out


# ---------------------------------------------------------------- CRAN

def fetch(url, tries=3, timeout=60):
    last = None
    for i in range(tries):
        try:
            req = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
            with urllib.request.urlopen(req, timeout=timeout) as r:
                return r.read().decode("utf-8", "replace")
        except urllib.error.HTTPError as e:
            if e.code == 404:
                raise RuntimeError(f"{url}: HTTP 404")
            last = e
        except Exception as e:  # noqa: BLE001 - reported as a finding
            last = e
        if i + 1 < tries:
            time.sleep(3 * (i + 1))
    raise RuntimeError(f"{url}: {last}")


def _text(fragment):
    s = re.sub(r"(?is)<code>(.*?)</code>", r"`\1`", fragment)
    s = re.sub(r"(?i)<br\s*/?>|</p>|</h\d>|</li>", "\n", s)
    s = re.sub(r"<[^>]+>", "", s)
    return html.unescape(s)


def parse_package_page(page):
    """{"version", "license", "archived" (reason or None), "news" (relative link or None)}."""
    def field(name):
        m = re.search(rf"(?is)<td>\s*{name}:\s*</td>\s*<td>(.*?)</td>", page)
        return re.sub(r"\s+", " ", _text(m.group(1))).strip() if m else None
    archived = None
    if re.search(r"(?i)was removed from the CRAN repository", page):
        reason = re.search(r"(?is)<p>\s*(Archived on[^<]*)</p>", page)
        archived = re.sub(r"\s+", " ", reason.group(1)).strip() if reason else "archived"
    news = re.search(r'(?i)<a href="([^"]*news[^"]*)"', page)
    return {"version": field("Version"), "license": field("License"), "archived": archived,
            "news": news.group(1) if news else None}


def news_excerpt(news_text, new_version, old_version, limit=NEWS_CHARS):
    """The part of a NEWS text from the first mention of new_version up to old_version."""
    text = re.sub(r"\n\s*\n+", "\n\n", news_text).strip()
    def at(v):
        m = re.search(rf"(?<![\d.]){re.escape(v)}(?![\d.]*\d)", text) if v else None
        return m.start() if m else None
    start = at(new_version)
    start = 0 if start is None else text.rfind("\n", 0, start) + 1
    end = at(old_version)
    if end is not None and end > start:
        end = text.rfind("\n", 0, end) + 1 or end
        excerpt = text[start:end]
    else:
        excerpt = text[start:start + limit + 1]
    excerpt = excerpt.strip()
    return excerpt[:limit] + ("\n[... truncated]" if len(excerpt) > limit else "")


DEPRECATION = re.compile(r"(?i)deprecat|defunct|removed")
FUNC_NAME = re.compile(r"`([A-Za-z.][A-Za-z0-9._]*)(?:\(\))?`|\b([A-Za-z.][A-Za-z0-9._]*)\(\)")


def deprecated_names(excerpt):
    names = set()
    for line in excerpt.splitlines():
        if DEPRECATION.search(line):
            for a, b in FUNC_NAME.findall(line):
                names.add(a or b)
    return names


def edi_calls(repo, pkg, names):
    """[(name, "file:line")] where EDI calls pkg::name( or imports it."""
    hits = []
    if not names:
        return hits
    repo = Path(repo)
    pat = re.compile(rf"\b{re.escape(pkg)}:::?({'|'.join(re.escape(n) for n in sorted(names))})\s*\(")
    for f in sorted((repo / R_DIR).glob("*.R")):
        for i, line in enumerate(f.read_text(errors="replace").splitlines(), 1):
            for m in pat.finditer(line):
                hits.append((m.group(1), f"{f.relative_to(repo)}:{i}"))
    ns = repo / NAMESPACE
    if ns.exists():
        for i, line in enumerate(ns.read_text(errors="replace").splitlines(), 1):
            m = re.match(rf"\s*importFrom\(\s*{re.escape(pkg)}\s*,(.*)\)", line)
            if m:
                for n in re.split(r"[,\s]+", m.group(1).replace('"', "")):
                    if n in names:
                        hits.append((n, f"{NAMESPACE}:{i}"))
    return hits


def edi_usage(repo, pkg, limit=15):
    """Where EDI references pkg (for the agent): file:line of pkg:: calls and NAMESPACE imports."""
    repo = Path(repo)
    out = []
    pat = re.compile(rf"\b{re.escape(pkg)}::")
    for f in sorted((repo / R_DIR).glob("*.R")):
        for i, line in enumerate(f.read_text(errors="replace").splitlines(), 1):
            if pat.search(line):
                out.append(f"{f.relative_to(repo)}:{i}")
                if len(out) >= limit:
                    return out
    ns = repo / NAMESPACE
    if ns.exists():
        for i, line in enumerate(ns.read_text(errors="replace").splitlines(), 1):
            if re.match(rf"\s*import(From)?\(\s*{re.escape(pkg)}\b", line):
                out.append(f"{NAMESPACE}:{i}")
    return out[:limit]


# ---------------------------------------------------------------- state shared by the stages

def _load(path):
    try:
        d = json.loads(Path(path).read_text())
        return d if isinstance(d, dict) else {}
    except (OSError, ValueError):
        return {}


def survey(ctx, fetcher=None):
    """Read every dependency's CRAN page once per run; cached on ctx for units()."""
    if getattr(ctx, "_deplic", None) is not None:
        return ctx._deplic
    fetcher = fetcher or fetch
    deps = description_packages(ctx.read(DESCRIPTION) or "")
    pinned = pinned_packages(ctx.repo)
    snap = _load(ctx.notes.dir / SNAPSHOT).get("packages", {})
    stamp = ctx.now.isoformat(timespec="seconds")
    new_snap, rows = {}, []
    for pkg, field in deps.items():
        prev = snap.get(pkg)
        row = {"package": pkg, "field": field, "pinned": pkg in pinned, "prev": prev}
        try:
            info = parse_package_page(fetcher(f"{CRAN}/{pkg}/index.html"))
        except RuntimeError as e:
            row["error"] = str(e)
            if prev:
                new_snap[pkg] = prev
            rows.append(row)
            continue
        row.update(info)
        new_snap[pkg] = {"version": info["version"] or (prev or {}).get("version"),
                         "license": info["license"] or (prev or {}).get("license"),
                         "checked_at": stamp}
        if prev and prev.get("license") and info["license"] and prev["license"] != info["license"]:
            new_snap[pkg]["license_history"] = (prev.get("license_history") or []) + [
                {"from": prev["license"], "to": info["license"], "seen_at": stamp}]
        elif prev and prev.get("license_history"):
            new_snap[pkg]["license_history"] = prev["license_history"]
        if (prev and not row["pinned"] and info["version"] and prev.get("version")
                and info["version"] != prev["version"] and not info["archived"]):
            row["version_changed"] = True
            excerpt = ""
            if info["news"]:
                try:
                    news_url = f"{CRAN}/{pkg}/{info['news']}" if not info["news"].startswith("http") \
                        else info["news"]
                    excerpt = news_excerpt(_text(fetcher(news_url)), info["version"], prev["version"])
                except RuntimeError as e:
                    excerpt = f"(NEWS could not be read: {e})"
            row["news_excerpt"] = excerpt or "(no NEWS on CRAN)"
        rows.append(row)
    ctx.workdir.mkdir(parents=True, exist_ok=True)
    (ctx.workdir / PENDING).write_text(json.dumps({"packages": new_snap, "updated_at": stamp}, indent=1,
                                                  sort_keys=True) + "\n")
    ctx._deplic = {"rows": rows, "first_run": not snap}
    return ctx._deplic


# ---------------------------------------------------------------- stages

def mechanical(ctx, fetcher=None):
    s = survey(ctx, fetcher)
    out = []
    for r in s["rows"]:
        pkg = r["package"]
        if r.get("error"):
            out.append({"unit": pkg, "kind": "unreadable",
                        "text": f"`{pkg}` ({r['field']}): the CRAN page could not be read: {r['error']}"})
            continue
        if r.get("archived"):
            out.append({"unit": pkg, "kind": "archived",
                        "text": f"`{pkg}` ({r['field']}) is archived on CRAN: {r['archived']}"})
        prev = r.get("prev") or {}
        if prev.get("license") and r.get("license") and prev["license"] != r["license"]:
            note = (" The dataset catalog pins an older release of this package on purpose "
                    "(R/package_metadata/dataset_license_audit.md); this finding is about EDI's "
                    "dependency on the current release, not those rows." if r["pinned"] else "")
            out.append({"unit": pkg, "kind": "license-changed",
                        "text": f"`{pkg}` ({r['field']}): license changed from `{prev['license']}` to "
                                f"`{r['license']}` (version {prev.get('version')} -> {r.get('version')}).{note}"})
        if r.get("version_changed"):
            names = deprecated_names(r.get("news_excerpt", ""))
            for name, where in edi_calls(ctx.repo, pkg, names):
                out.append({"unit": pkg, "kind": "deprecated-call",
                            "text": f"`{pkg}::{name}` is called deprecated, defunct or removed in {pkg} "
                                    f"{r['version']}'s NEWS, and EDI uses it at `{where}`."})
    return out


def units(ctx):
    s = survey(ctx)
    out = {}
    for r in s["rows"]:
        if not r.get("version_changed"):
            continue
        pkg, old, new = r["package"], r["prev"]["version"], r["version"]
        out[pkg] = {"hash": ac.text_hash(pkg, old, new),
                    "context": {"package": pkg, "field": r["field"], "old_version": old, "new_version": new,
                                "news_excerpt": r["news_excerpt"],
                                "edi_references": edi_usage(ctx.repo, pkg)}}
    return out


def apply(ctx, results, mech):
    pending = ctx.workdir / PENDING
    first = not (ctx.notes.dir / SNAPSHOT).exists()
    if pending.exists():
        (ctx.notes.dir / SNAPSHOT).write_text(pending.read_text())
    plan = _load(ctx.workdir / "plan.json")
    changed = sorted((plan.get("units") or {}).keys())
    by_unit, proposed = {}, []
    for r in results:
        for f in r.get("findings") or []:
            if f.get("unit") in changed:
                by_unit.setdefault(f["unit"], []).append(f)
                if f.get("kind") == "check":
                    proposed.append({"unit": f["unit"], "kind": "news-check", "text": f.get("text", ""),
                                     "source": "claude"})
    covered = {u for r in results for u in (r.get("units_checked") or r.get("_units") or [])}
    human = []
    for pkg in changed:
        fs = by_unit.get(pkg, [])
        checks = [f.get("text", "") for f in fs if f.get("kind") == "check"]
        if checks:
            human.append(f"`{pkg}`: " + " ".join(checks))
        elif pkg not in covered:
            human.append(f"`{pkg}`: version changed; NEWS not summarised (agent NOT RUN).")
    quiet = [p for p in changed if p in covered and not any(f.get("kind") == "check" for f in by_unit.get(p, []))]
    summary = (f"{len(changed)} non-pinned dependencies changed version since the last snapshot"
               + (f"; nothing for EDI to check in: {', '.join(quiet)}" if quiet else "") + "."
               if changed else "")
    if first:
        summary = (summary + " " if summary else "") + "First run: the license and version snapshot was recorded."
    return {"summary": summary, "applied": [], "mechanical": [f["text"] for f in mech], "human": human,
            "proposed": proposed}
