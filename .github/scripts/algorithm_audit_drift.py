#!/usr/bin/env python3
"""Algorithm-audit drift check (stdlib only; read-only; never builds EDI).

Four checks, one markdown report:
  1. comparator versions  -- CRAN version vs R/package_metadata/audits/comparator_versions.json
  2. kernel drift         -- git log per audit row since the row's `reviewed` date
  3. plan-state hygiene   -- every audit TODO's "scheduled in release_vX.md -> TODO-N" target exists
  4. algorithm inventory  -- R/package_metadata/audits/algorithm_inventory.csv, the single source of
                             truth for which algorithms EDI implements and where: every R/EDI/src and
                             R/EDI/R file is inventoried or exempt, every entry's file and symbol still
                             exist, and every entry cites reference URLs that still resolve

Usage:
  algorithm_audit_drift.py [--out report.md] [--offline]   # run the checks
  algorithm_audit_drift.py --release-gate                  # pre-release: exit 1 if the gate fails
  algorithm_audit_drift.py --snapshot                      # rewrite comparator_versions.json from CRAN now
  algorithm_audit_drift.py --currency-context 60 --out ctx.json
      # JSON for the research workflow: functions added in the last N days that the inventory
      # lacks, and inventory entries whose file changed in that window

Exit code is always 0 on a completed run; the report's first line is
`FLAGGED` or `CLEAN` so the workflow can branch on it. See
R/package_metadata/new_feature_plans/v1_0_5/algorithm_audit_runbook.md.
"""
import argparse
import csv
import datetime
import fnmatch
import html
import json
import re
import subprocess
import sys
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
META = ROOT / "R" / "package_metadata"
AUDIT = META / "new_feature_plans" / "v1_0_5" / "algorithm_choice_audit.md"
RELEASES = META / "future_release_plans"
ROW_MAP = META / "audits" / "algorithm_audit_row_map.json"
PINS = META / "audits" / "comparator_versions.json"
INVENTORY = META / "audits" / "algorithm_inventory.csv"
RESEARCH_LOG = META / "audits" / "research_log.json"
TAXONOMY = META / "audits" / "algorithm_taxonomy.json"
REFERENCES = META / "audits" / "algorithm_references.csv"
SRC_DIR = ROOT / "R" / "EDI" / "src"
R_DIR = ROOT / "R" / "EDI" / "R"
DESCRIPTION = ROOT / "R" / "EDI" / "DESCRIPTION"

# Comparators the audit's verdicts lean on, whether or not DESCRIPTION lists them.
EXTRA_COMPARATORS = ["survival", "clinfun", "coin", "betareg", "aftgee", "icenReg",
                     "robustbase", "coxme", "lme4", "glmmTMB"]
BASE_PKGS = {"R", "base", "methods", "stats", "utils", "parallel", "tools", "graphics",
             "grDevices", "datasets", "grid", "splines", "stats4", "compiler", "tcltk"}
NEWS_KEYWORDS = re.compile(
    r"default|algorithm|\btie|quadrature|convergen|optimi[sz]|starting value|"
    r"deprecat|breaking|incompatible|behaviou?r|numerical|accuracy|bug", re.I)
MAX_NEWS_LINES = 8
MAX_COMMITS = 8
MAX_FETCH_ERRORS = 3  # more network failures than this and check 1 is not trustworthy


CRAN = "https://cran.r-project.org"


def canonical_cran_url(url):
    """CRAN material at its canonical host, cran.r-project.org (owner, 2026-11-16).

    Mirrors serve CRAN's own paths (`.../web/packages/<pkg>/...`, `.../src/contrib/...`) under
    another host, so those paths move to cran.r-project.org unchanged. rdrr.io and CRAN's
    read-only GitHub mirror (github.com/cran/<pkg>) have no path equivalent and map to the
    package page. Anything else is returned unchanged."""
    parsed = urllib.parse.urlsplit(url.strip())
    host, path = parsed.netloc.lower(), parsed.path
    if host == "cran.r-project.org":
        return urllib.parse.urlunsplit(("https", host) + tuple(parsed)[2:])
    for marker in ("/web/packages/", "/src/contrib/", "/web/views/"):
        if marker in path:
            return CRAN + marker + path.split(marker, 1)[1] + (f"#{parsed.fragment}" if parsed.fragment else "")
    if host == "rdrr.io" and path.startswith("/cran/") and len(path.split("/")) > 2:
        return f"{CRAN}/package={path.split('/')[2]}"
    if host == "github.com" and path.startswith("/cran/") and len(path.split("/")) > 2:
        return f"{CRAN}/package={path.split('/')[2]}"
    if parsed.query.startswith("package=") or "/package=" in path:
        pkg = (parsed.query or path).split("package=", 1)[1].split("&")[0].strip("/")
        if host.endswith("r-project.org") or "cran" in host:
            return f"{CRAN}/package={pkg}"
    return url


DOI_RE = re.compile(r"\b(10\.\d{4,9}/[^\s\"<>?#]+)", re.I)


def doi_of(url):
    """The DOI in a URL (doi.org links, and publisher URLs that embed it), else None."""
    m = DOI_RE.search(urllib.parse.unquote(url))
    return m.group(1).rstrip(".,;)").lower() if m else None


def pick_open_copies(work):
    """Open copies of a paper from an OpenAlex work record, best first: arXiv, then bioRxiv /
    medRxiv, then PubMed Central / Europe PMC. Publisher pages are never returned: they are what
    blocks automated access (owner, 2026-11-16: prefer preprint servers)."""
    ranked = []
    for loc in work.get("locations", []):
        url = loc.get("landing_page_url") or ""
        if not (loc.get("is_oa") and url):
            continue
        host = urllib.parse.urlsplit(url).netloc.lower()
        d = doi_of(url) or ""
        if "arxiv.org" in host or d.startswith("10.48550/arxiv."):
            arxiv_id = d.split("arxiv.", 1)[1] if d.startswith("10.48550/") else url.rsplit("/", 1)[-1]
            ranked.append((0, f"https://arxiv.org/abs/{arxiv_id}"))
        elif d.startswith("10.1101/") or "biorxiv.org" in host or "medrxiv.org" in host:
            ranked.append((1, url))
        elif "ncbi.nlm.nih.gov/pmc" in url or "pmc.ncbi.nlm.nih.gov" in host or "europepmc.org" in host:
            ranked.append((2, url))
    seen, out = set(), []
    for _, url in sorted(ranked):
        if url not in seen:
            seen.add(url)
            out.append(url)
    return out


def openalex_work(doi):
    """OpenAlex's record for a DOI (no key needed), or None on any failure."""
    try:
        return json.loads(http_get("https://api.openalex.org/works/doi:"
                                   + urllib.parse.quote(doi, safe="/")))
    except (urllib.error.URLError, OSError, ValueError):
        return None


def publisher_reachable(doi):
    """True if the DOI's publisher page loads for an automated client (follows doi.org's
    redirect); False on 401/403/451, other HTTP errors, or network failure."""
    try:
        http_get(f"https://doi.org/{urllib.parse.quote(doi, safe='/')}")
        return True
    except (urllib.error.URLError, OSError, ValueError):
        return False


def doi_access(doi, reachable=publisher_reachable, work_of=openalex_work):
    """Publisher first, OpenAlex as the fallback (owner, 2026-11-16).

    Returns (status, open_copies). status is "publisher" when the publisher page loads and the
    published version is open (OpenAlex marks it open, or has no record); then no copies are
    needed. Otherwise it is "blocked" (the page did not load) or "closed" (it loads but OpenAlex
    marks the published version closed, i.e. a paywall), and open_copies lists preprint / PMC
    copies from OpenAlex, best first (possibly empty)."""
    ok = reachable(doi)
    work = work_of(doi)
    primary = (work or {}).get("primary_location") or {}
    if ok and (work is None or primary.get("is_oa", True)):
        return "publisher", []
    return ("blocked" if not ok else "closed"), (pick_open_copies(work) if work else [])


def open_copies(doi):
    """Open copies for a DOI whose publisher version is not usable; [] when the publisher is."""
    return doi_access(doi)[1]


def http_get(url, timeout=20):
    req = urllib.request.Request(url, headers={"User-Agent": "EDI-algorithm-audit-drift"})
    with urllib.request.urlopen(req, timeout=timeout) as r:
        return r.read().decode("utf-8", "replace")


def description_packages():
    text = DESCRIPTION.read_text()
    pkgs = set()
    for field in ("Imports", "Suggests", "Depends", "LinkingTo"):
        m = re.search(rf"^{field}:\s*((?:.+\n?)(?:[ \t]+.+\n?)*)", text, re.M)
        if not m:
            continue
        for item in m.group(1).split(","):
            name = re.split(r"[\s(]", item.strip(), maxsplit=1)[0]
            if name and name not in BASE_PKGS:
                pkgs.add(name)
    return pkgs


def cran_version(pkg):
    """CRAN version, None if the package is not on CRAN (404); raises on any other failure."""
    last = None
    for _ in range(2):  # one retry for transient errors
        try:
            return json.loads(http_get(f"https://crandb.r-pkg.org/{pkg}"))["Version"]
        except urllib.error.HTTPError as e:
            if e.code == 404:
                return None
            last = e
        except (urllib.error.URLError, OSError, KeyError, ValueError) as e:
            last = e
    raise last


def news_items(page):
    """CRAN's rendered NEWS HTML -> list of (kind, text): "head" for a heading, "item" for a
    bullet or paragraph. Wrapped lines are joined, so each item is one whole entry."""
    page = re.sub(r"<(script|style|head)\b.*?</\1>", "", page, flags=re.S | re.I)
    out = []
    for m in re.finditer(r"<(h[1-6]|li|p)\b[^>]*>(.*?)(?=<(?:/?h[1-6]|li|/li|p|/p|/ul|/ol|ul|ol)\b)",
                         page, flags=re.S | re.I):
        text = " ".join(html.unescape(re.sub(r"<[^>]+>", " ", m.group(2))).split())
        if text:
            out.append(("head" if m.group(1).lower().startswith("h") else "item", text))
    return out


def news_since(pkg, pinned):
    """Keyword-matching NEWS entries newer than the pinned version's heading; None if CRAN
    publishes no NEWS for the package. CRAN renders NEWS as HTML at news/news.html (NEWS.md
    packages) or news.html (NEWS.Rd packages); the raw NEWS/NEWS.md files are not served."""
    page = None
    for name in ("news/news.html", "news.html"):
        try:
            page = http_get(f"https://cran.r-project.org/web/packages/{pkg}/{name}")
            break
        except (urllib.error.URLError, OSError):
            continue
    if page is None:
        return None
    return filter_news(news_items(page), pinned)


def filter_news(items, pinned):
    """Entries above the first heading naming `pinned` (as a whole version token) that match
    NEWS_KEYWORDS, each capped at 300 characters."""
    token = re.compile(rf"(?<![\w.-]){re.escape(pinned)}(?![\w-]|\.\d)")
    cut = next((i for i, (kind, t) in enumerate(items) if kind == "head" and token.search(t)), None)
    note = []
    if cut is None:  # pinned heading not found: say so instead of dumping the whole history
        note, cut = [f"(no NEWS heading for the pinned {pinned}; newest entries shown)"], 40
    hits = [t if len(t) <= 300 else t[:297] + "..."
            for kind, t in items[:cut] if kind == "item" and NEWS_KEYWORDS.search(t)]
    return note + hits[:MAX_NEWS_LINES]


def check_versions(offline):
    out = {"changed": [], "unpinned": [], "not_on_cran": [], "errors": [], "skipped": offline}
    if offline:
        return out
    pins = json.loads(PINS.read_text()).get("packages", {}) if PINS.exists() else {}
    for pkg in sorted(description_packages() | set(EXTRA_COMPARATORS)):
        try:
            now = cran_version(pkg)
        except (urllib.error.URLError, OSError, KeyError, ValueError):
            out["errors"].append(pkg)  # network/server failure, not "absent"
            continue
        if now is None:
            out["not_on_cran"].append(pkg)
            continue
        pinned = pins.get(pkg)
        if pinned is None:
            out["unpinned"].append((pkg, now))
        elif pinned != now:
            out["changed"].append((pkg, pinned, now, news_since(pkg, pinned)))
    return out


def git(*args):
    return subprocess.run(["git", "-C", str(ROOT), *args], capture_output=True,
                          text=True, check=False).stdout


def load_inventory():
    with INVENTORY.open(newline="") as fh:
        return list(csv.DictReader(fh))


def load_references():
    with REFERENCES.open(newline="") as fh:
        return list(csv.DictReader(fh))


def entry_rows(entry):
    """Audit-row letters of an inventory entry: "A + Z" -> ["A", "Z"]."""
    return [r.strip() for r in entry["audit_row"].split("+") if r.strip()]


def row_files(inventory):
    """Audit row -> files whose change re-opens it (the inventory's `watch` column)."""
    out = {}
    for e in inventory:
        for r in e.get("watch", "").split():
            out.setdefault(r, set()).add(e["file"])
    return {r: sorted(f) for r, f in out.items()}


def source_files():
    """Every algorithm-bearing source file: git-tracked R/EDI/src/*.cpp|*.h and R/EDI/R/*.R.
    Build outputs (unity_*.cpp, edi_build_flags.h, RcppExports when regenerated) are untracked,
    so a local build and CI's fresh checkout see the same set."""
    tracked = git("ls-files", "--", str(SRC_DIR.relative_to(ROOT)),
                  str(R_DIR.relative_to(ROOT))).split()
    if not tracked:  # not a git checkout (e.g. the planted-fixture tests): use the directory
        tracked = [str(p.relative_to(ROOT)) for d in (SRC_DIR, R_DIR) for p in d.iterdir()]
    return sorted(f for f in tracked
                  if (f.startswith(str(SRC_DIR.relative_to(ROOT)) + "/") and f.endswith((".cpp", ".h")))
                  or (f.startswith(str(R_DIR.relative_to(ROOT)) + "/") and f.endswith(".R")))


def check_kernels():
    cfg = json.loads(ROW_MAP.read_text())
    rows = cfg["rows"]
    watched = row_files(load_inventory())
    max_age = cfg.get("max_age_days", 180)
    out = {"drifted": [], "stale": [], "max_age": max_age}
    today = datetime.date.today()
    for key, row in rows.items():
        age = (today - datetime.date.fromisoformat(row["reviewed"])).days
        if age > max_age:
            out["stale"].append((key, row["title"], row["reviewed"], age))
        existing = [f for f in watched.get(key, []) if (ROOT / f).exists()]
        if not existing:
            continue
        # `reviewed` covers that whole day: commits made earlier that day were part of the review
        log = git("log", f"--since={row['reviewed']} 23:59:59", "--format=%h %ad %s",
                  "--date=short", "--", *existing).strip().splitlines()
        if log:
            out["drifted"].append((key, row["title"], row["reviewed"], log))
    return out


def check_inventory(offline):
    """Check 4: the inventory is complete, current, and every entry is referenced."""
    cfg = json.loads(ROW_MAP.read_text())
    inv, refs = load_inventory(), load_references()
    out = {"uncovered": [], "stale_exempt": [], "exempt_inventoried": [], "unwatched_row": [],
           "bad_file": [], "bad_symbol": [], "bad_row": [], "bad_taxonomy_id": [],
           "unused_taxonomy": [], "taxonomy_terms": [],
           "no_refs": [], "unknown_ref": [], "orphan_ref": [], "dead_ref": [], "ref_errors": [],
           "entries": len(inv), "refs": len(refs), "skipped": offline}
    # Coverage: every source file is inventoried or matches an exempt pattern.
    files = source_files()
    patterns = list(cfg.get("exempt", {}))  # {path or glob: reason}
    inventoried = {e["file"] for e in inv}
    out["uncovered"] = [f for f in files if f not in inventoried
                        and not any(fnmatch.fnmatch(f, pat) for pat in patterns)]
    out["stale_exempt"] = [pat for pat in patterns
                           if not any(fnmatch.fnmatch(f, pat) for f in files)]
    out["exempt_inventoried"] = sorted(f for f in inventoried
                                       if any(fnmatch.fnmatch(f, pat) for pat in patterns))
    watched = row_files(inv)
    out["unwatched_row"] = [r for r in cfg["rows"] if r not in watched]
    # Each entry: file exists, symbol still in it, rows exist, refs present and known.
    known = {r["url"] for r in refs}
    used = set()
    taxonomy = load_taxonomy()
    probs, meths = taxonomy.get("problems", {}), taxonomy.get("methods", {})
    used_p, used_m = set(), set()
    text_cache = {}
    for i, e in enumerate(inv, start=2):  # line 1 is the header
        where = f"line {i}: `{e['file']}` `{e['symbol']}`"
        path = ROOT / e["file"]
        if not path.is_file():
            out["bad_file"].append(where)
            continue
        if e["symbol"]:
            text = text_cache.setdefault(e["file"], path.read_text(errors="replace"))
            if e["symbol"] not in text:
                out["bad_symbol"].append(where)
        bad = [r for r in entry_rows(e) + e.get("watch", "").split() if r not in cfg["rows"]]
        if bad or not entry_rows(e):
            out["bad_row"].append(f"{where}: audit_row `{e['audit_row']}` watch `{e['watch']}`")
        pid, mid = e.get("problem_id", ""), e.get("method_id", "")
        if pid not in probs or mid not in meths:
            out["bad_taxonomy_id"].append(f"{where}: problem_id `{pid}` method_id `{mid}`")
        used_p.add(pid)
        used_m.add(mid)
        urls = e["refs"].split()
        if not urls:
            out["no_refs"].append(where)
        for u in urls:
            used.add(u)
            if u not in known:
                out["unknown_ref"].append(f"{where}: {u}")
    out["orphan_ref"] = sorted(known - used)
    out["unused_taxonomy"] = ([f"problem `{p}`" for p in sorted(set(probs) - used_p)]
                              + [f"method `{m}`" for m in sorted(set(meths) - used_m)])
    for p, d in sorted(probs.items()):
        if not d.get("search_terms"):
            out["taxonomy_terms"].append(f"problem `{p}` has no search_terms")
    for m, d in sorted(meths.items()):
        missing = [k for k in ("synonyms", "broader", "narrower", "software") if k not in d]
        if missing:
            out["taxonomy_terms"].append(f"method `{m}` lacks {', '.join(missing)}")
    if not offline:
        out["dead_ref"], out["ref_errors"] = check_reference_urls(sorted(known))
    return out


def check_reference_urls(urls):
    """(dead, errors): dead = resolved to 'does not exist'; errors = could not be checked."""
    dead, errors = [], []
    wiki = {}
    for u in urls:
        if u.startswith("https://en.wikipedia.org/wiki/"):
            title = urllib.parse.unquote(u.rsplit("/wiki/", 1)[1].split("#", 1)[0])
            wiki[title.replace("_", " ")] = u
            continue
        try:
            if u.startswith("https://doi.org/"):
                doi = urllib.parse.quote(u[len("https://doi.org/"):], safe="/")
                code = json.loads(http_get(f"https://doi.org/api/handles/{doi}"))["responseCode"]
                if code != 1:
                    dead.append(u)
            else:
                http_get(u)
        except urllib.error.HTTPError as e:
            (dead if e.code in (404, 410) else errors).append(u)
        except (urllib.error.URLError, OSError, KeyError, ValueError):
            errors.append(u)
    titles = sorted(wiki)
    for k in range(0, len(titles), 50):  # the API takes 50 titles per query
        batch = titles[k:k + 50]
        q = urllib.parse.urlencode({"action": "query", "format": "json", "redirects": 1,
                                    "titles": "|".join(batch)})
        try:
            pages = json.loads(http_get(f"https://en.wikipedia.org/w/api.php?{q}"))
        except (urllib.error.URLError, OSError, ValueError):
            errors += [wiki[t] for t in batch]
            continue
        q = pages.get("query", {})
        rename = {n["from"]: n["to"] for n in q.get("normalized", []) + q.get("redirects", [])}
        missing = {p["title"] for p in q.get("pages", {}).values() if "missing" in p}
        for t in batch:
            final = rename.get(rename.get(t, t), rename.get(t, t))
            if final in missing:
                dead.append(wiki[t])
    return dead, errors


R_DEF = re.compile(r"^\+\s*([A-Za-z.][\w.]*)\s*(?:<-|=)\s*function\s*\(")
CPP_DEF = re.compile(r"^\+\s*(?:template\s*<[^>]*>\s*)?(?:[\w:<>,*&]+\s+)+[*&]?([A-Za-z_]\w*)\s*\([^;]*$")
CPP_NOT_DEF = {"if", "for", "while", "switch", "return", "else", "catch", "sizeof", "do",
               "new", "delete", "case", "throw", "using", "typedef", "operator"}


def added_definitions(diff_text):
    """(file, symbol) for function definitions on added lines of a unified diff."""
    out, path = [], None
    for line in diff_text.splitlines():
        if line.startswith("+++ "):
            path = line[6:] if line.startswith("+++ b/") else None
            continue
        if not path or not line.startswith("+"):
            continue
        if path.endswith(".R"):
            m = R_DEF.match(line)
        elif path.endswith((".cpp", ".h")) and "=" not in line.split("(", 1)[0]:
            m = CPP_DEF.match(line)
            if m and m.group(1) in CPP_NOT_DEF:
                m = None
        else:
            m = None
        if m:
            out.append((path, m.group(1)))
    return out


def changed_text_by_file(diff_text):
    """file -> text of its changed lines plus hunk headers (git names the enclosing function)."""
    out, path = {}, None
    for line in diff_text.splitlines():
        if line.startswith("+++ "):
            path = line[6:] if line.startswith("+++ b/") else None
        elif path and (line.startswith("@@") or
                       (line[:1] in "+-" and not line.startswith(("---", "+++")))):
            out[path] = out.get(path, "") + line + "\n"
    return out


def load_taxonomy():
    """algorithm_taxonomy.json: {"problems": {...}, "methods": {...}}; empty when absent."""
    if not TAXONOMY.exists():
        return {"problems": {}, "methods": {}}
    return json.loads(TAXONOMY.read_text())


def research_batches(inventory, row_order=None):
    """Research task per problem (owner, 2026-11-16): problem_id -> sorted method_ids EDI uses
    for it, from the inventory's `problem_id` / `method_id` columns. One agent answers "what is
    the fastest acceptable way to solve this problem?" for all of them. (`row_order` is unused;
    kept for callers.)"""
    out = {}
    for e in inventory:
        if e.get("problem_id") and e.get("method_id"):
            out.setdefault(e["problem_id"], set()).add(e["method_id"])
    return {p: sorted(m) for p, m in sorted(out.items())}


def task_problem(problem_id, taxonomy=None):
    """The taxonomy slice an agent gets: its problem and every method EDI uses for it."""
    taxonomy = taxonomy or load_taxonomy()
    methods = research_batches(load_inventory()).get(problem_id, [])
    return {"problem_id": problem_id,
            "problem": taxonomy["problems"].get(problem_id, {}),
            "methods": {m: taxonomy["methods"].get(m, {}) for m in methods}}


def load_research_log():
    """{problem_id: last research result}; {} when there is no log yet."""
    if not RESEARCH_LOG.exists():
        return {}
    return json.loads(RESEARCH_LOG.read_text()).get("problems", {})


def previous_results(problem_id, inventory, log=None, max_commits=5):
    """The problem's last research result from the log, plus the commits that touched its
    inventory files since then (so the agent knows whether the earlier answer still describes
    the code); {"no_previous": true} when it was never researched."""
    log = load_research_log() if log is None else log
    prev = log.get(problem_id)
    if not prev:
        return {"no_previous": True}
    files = sorted({e["file"] for e in inventory if e.get("problem_id") == problem_id})
    commits = []
    if files:
        commits = git("log", f"--since={prev['last_researched']} 23:59:59", "--format=%h %ad %s",
                      "--date=short", "--", *files).strip().splitlines()
    return dict(prev, code_commits_since=commits[:max_commits], code_changed_since=bool(commits))


def currency_context(days):
    """Inputs for the monthly inventory-currency agent (judgement the mechanical check can't make)."""
    inv = load_inventory()
    known = {(e["file"], e["symbol"]) for e in inv}
    exempt = list(json.loads(ROW_MAP.read_text()).get("exempt", {}))
    since = f"{days}.days"
    paths = ["R/EDI/src", "R/EDI/R"]
    diff = git("log", f"--since={since}", "-p", "--unified=0", "--format=", "--", *paths)
    new, seen = [], set()
    for f, sym in added_definitions(diff):
        if (f, sym) in known or (f, sym) in seen or any(fnmatch.fnmatch(f, p) for p in exempt):
            continue
        path = ROOT / f
        if path.is_file() and sym in path.read_text(errors="replace"):  # still there today
            seen.add((f, sym))
            new.append({"file": f, "symbol": sym})
    touched = changed_text_by_file(git("log", f"--since={since}", "-p", "--unified=3",
                                       "--format=", "--", *paths))
    entries = [{"file": e["file"], "symbol": e["symbol"], "algorithm": e["algorithm"],
                "audit_row": e["audit_row"]} for e in inv
               if e["symbol"] and re.search(rf"\b{re.escape(e['symbol'])}\b",
                                            touched.get(e["file"], ""))]
    return {"window_days": days, "today": datetime.date.today().isoformat(),
            "new_symbols": new, "changed_entries": entries}


TODO_HEAD = re.compile(r"^- \[([ x])\] (?:~~)?TODO-([0-9A-Za-z]+)")
REF = re.compile(r"(release_v\d_\d_\d\.md)\s*→\s*TODO-(\d+[a-z]?)(?:\.\.(\d+))?")


def release_index(fname, cache={}):
    if fname not in cache:
        active, stubs = set(), set()
        path = RELEASES / fname
        for line in (path.read_text().splitlines() if path.exists() else []):
            m = re.match(r"^- \[[ x]\] TODO-(\d+[a-z]?)\b", line)
            if m:
                active.add(m.group(1))
            m = re.match(r"^- \[[ x]\] ~~TODO-(\d+[a-z]?)~~", line)
            if m:
                stubs.add(m.group(1))
        cache[fname] = (path.exists(), active, stubs)
    return cache[fname]


def check_plan_state():
    out = {"dangling": [], "untagged": []}
    for line in AUDIT.read_text().splitlines():
        m = TODO_HEAD.match(line)
        if not m:
            continue
        done, tid = m.group(1) == "x", m.group(2)
        refs = REF.findall(line)
        if not refs and not done and "covered by" not in line:
            out["untagged"].append(tid)
        for fname, lo, hi in refs:
            exists, active, stubs = release_index(fname)
            targets = [lo] if not hi else [str(n) for n in range(int(lo), int(hi) + 1)]
            for t in targets:
                if not exists:
                    out["dangling"].append((tid, f"{fname} does not exist"))
                elif t not in active:
                    why = "is a moved-stub" if t in stubs else "not found"
                    out["dangling"].append((tid, f"{fname} → TODO-{t} {why}"))
    return out


INVENTORY_FLAGS = [
    ("uncovered", "Source files neither inventoried nor exempt"),
    ("stale_exempt", "Exempt patterns that match no file"),
    ("exempt_inventoried", "Files both inventoried and exempt (drop the exempt entry)"),
    ("unwatched_row", "Audit rows no inventory entry watches"),
    ("bad_file", "Entries whose file no longer exists"),
    ("bad_symbol", "Entries whose symbol is no longer in its file"),
    ("bad_row", "Entries with an unknown audit row"),
    ("bad_taxonomy_id", "Entries whose problem_id / method_id is not in algorithm_taxonomy.json"),
    ("unused_taxonomy", "Taxonomy problems / methods no inventory entry uses"),
    ("taxonomy_terms", "Taxonomy entries missing search-term lists"),
    ("no_refs", "Entries with no reference URL"),
    ("unknown_ref", "Reference URLs missing from algorithm_references.csv"),
    ("orphan_ref", "References no entry cites"),
    ("dead_ref", "Reference URLs that no longer resolve"),
]


def render(v, k, p, n):
    broken = len(v["errors"]) > MAX_FETCH_ERRORS
    refs_broken = len(n["ref_errors"]) > MAX_FETCH_ERRORS
    flagged = bool(broken or v["changed"] or v["unpinned"] or k["drifted"]
                   or k["stale"] or p["dangling"] or p["untagged"] or refs_broken
                   or any(n[key] for key, _ in INVENTORY_FLAGS))
    L = ["FLAGGED" if flagged else "CLEAN", "",
         f"# Algorithm-audit drift report ({datetime.date.today().isoformat()})", "",
         "Read-only output of `.github/scripts/algorithm_audit_drift.py`. A flag means "
         "*re-look*, not *wrong*. Procedure: "
         "`R/package_metadata/new_feature_plans/v1_0_5/algorithm_audit_runbook.md`.", ""]
    L.append("## 1. Comparator versions")
    if broken:
        L.append(f"- **CHECK UNRELIABLE:** {len(v['errors'])} of the packages could not be "
                 f"fetched from crandb (limit {MAX_FETCH_ERRORS}), so a 'no changes' result "
                 "here means nothing. Failed: " + ", ".join(v["errors"]))
    elif v["errors"]:
        L.append("- Fetch failed (below the limit, ignored this run): " + ", ".join(v["errors"]))
    if v["skipped"]:
        L.append("_Skipped (offline)._")
    for pkg, old, new, news in v["changed"]:
        L.append(f"- **{pkg}**: pinned `{old}` → CRAN `{new}`")
        for n in (news or []):
            L.append(f"  - {n}")
        if news is None:
            L.append("  - (CRAN publishes no NEWS for this package; check its ChangeLog or repository)")
    if v["unpinned"]:
        L.append("- Unpinned (run `--snapshot` after review): " +
                 ", ".join(f"{a} `{b}`" for a, b in v["unpinned"]))
    if v["not_on_cran"]:
        L.append("- Not on CRAN (ignored): " + ", ".join(v["not_on_cran"]))
    if not (v["changed"] or v["unpinned"] or v["skipped"] or broken):
        L.append("_No changes._")
    L += ["", "## 2. Kernel drift since each row's `reviewed` date"]
    for key, title, since, log in k["drifted"]:
        L.append(f"- **Row {key}** ({title}), reviewed {since}: {len(log)} commit(s)")
        L += [f"  - `{c}`" for c in log[:MAX_COMMITS]]
        if len(log) > MAX_COMMITS:
            L.append(f"  - … and {len(log) - MAX_COMMITS} more")
    if not k["drifted"]:
        L.append("_No watched file changed._")
    L += ["", f"### Rows past the maximum review age ({k['max_age']} days)"]
    L += [f"- **Row {key}** ({title}): last reviewed {d}, {age} days ago"
          for key, title, d, age in k["stale"]] or ["_None._"]
    L += ["", "## 3. Plan-state hygiene"]
    L += [f"- **Audit TODO-{t}**: {why}" for t, why in p["dangling"]]
    L += [f"- **Audit TODO-{t}**: unchecked but carries no release tag" for t in p["untagged"]]
    if not (p["dangling"] or p["untagged"]):
        L.append("_All audit TODOs resolve._")
    L += ["", "## 4. Algorithm inventory",
          f"`R/package_metadata/audits/algorithm_inventory.csv`: {n['entries']} entries, "
          f"{n['refs']} references."]
    if refs_broken:
        L.append(f"- **REFERENCE CHECK UNRELIABLE:** {len(n['ref_errors'])} URLs could not be "
                 f"checked (limit {MAX_FETCH_ERRORS}), so 'all resolve' means nothing.")
    elif n["ref_errors"]:
        L.append("- Could not check (below the limit, ignored this run): "
                 + ", ".join(n["ref_errors"]))
    if n["skipped"]:
        L.append("_Reference URLs not checked (offline)._")
    for key, title in INVENTORY_FLAGS:
        if n[key]:
            L.append(f"### {title}")
            L += [f"- {x}" if key not in ("uncovered", "stale_exempt", "exempt_inventoried",
                                                  "unwatched_row", "orphan_ref", "dead_ref")
                  else f"- `{x}`" for x in n[key]]
    if not (refs_broken or any(n[key] for key, _ in INVENTORY_FLAGS)):
        L.append("_Complete and current._")
    return flagged, "\n".join(L) + "\n"


def snapshot():
    pkgs = {}
    for pkg in sorted(description_packages() | set(EXTRA_COMPARATORS)):
        try:
            ver = cran_version(pkg)
        except (urllib.error.URLError, OSError, KeyError, ValueError):
            sys.exit(f"snapshot aborted: fetching {pkg} failed; not writing a partial pin file")
        if ver is None:
            print(f"skip {pkg} (not on CRAN)", file=sys.stderr)
        else:
            pkgs[pkg] = ver
    PINS.write_text(json.dumps({"snapshot_date": datetime.date.today().isoformat(),
                                "packages": pkgs}, indent=2) + "\n")
    print(f"wrote {PINS} ({len(pkgs)} packages)")


def release_gate():
    """Pre-release gate: no open drift/failure issue and no row past its max age.
    Exit 0 pass, 1 fail, 2 could not be determined (gh missing/unauthenticated: not a pass)."""
    problems = []
    for label in ("algorithm-audit-drift", "algorithm-audit-drift-failure"):
        r = subprocess.run(["gh", "issue", "list", "--label", label, "--state", "open",
                            "--json", "number,title"], capture_output=True, text=True, cwd=ROOT)
        if r.returncode != 0:
            print(f"GATE UNDETERMINED: could not list `{label}` issues "
                  f"({r.stderr.strip() or 'gh failed'}). Run `gh auth login` and retry.")
            return 2
        problems += [f"open issue #{i['number']} ({label}): {i['title']}"
                     for i in json.loads(r.stdout)]
    problems += [f"row {key} ({title}) last reviewed {d}, {age} days ago"
                 for key, title, d, age in check_kernels()["stale"]]
    if problems:
        print("RELEASE GATE FAILED:\n" + "\n".join(f"- {x}" for x in problems))
        return 1
    print("RELEASE GATE PASSED: no open algorithm-audit issue, no row past its max age.")
    return 0


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default="-")
    ap.add_argument("--offline", action="store_true")
    ap.add_argument("--snapshot", action="store_true")
    ap.add_argument("--release-gate", action="store_true")
    ap.add_argument("--currency-context", type=int, metavar="DAYS")
    ap.add_argument("--research-batches", action="store_true",
                    help="print the research task -> algorithms map as JSON")
    ap.add_argument("--previous-results", metavar="PROBLEM",
                    help="print the research log's previous result for one problem as JSON")
    ap.add_argument("--task-problem", metavar="PROBLEM",
                    help="print the taxonomy slice (problem + its methods) for one problem")
    a = ap.parse_args()
    if a.previous_results or a.task_problem:
        pid = a.previous_results or a.task_problem
        inv = load_inventory()
        if pid not in research_batches(inv):
            sys.exit(f"unknown research problem {pid}")
        obj = previous_results(pid, inv) if a.previous_results else task_problem(pid)
        text = json.dumps(obj, indent=1, ensure_ascii=False) + "\n"
        return sys.stdout.write(text) if a.out == "-" else Path(a.out).write_text(text)
    if a.research_batches:
        text = json.dumps(research_batches(load_inventory()), indent=1) + "\n"
        return sys.stdout.write(text) if a.out == "-" else Path(a.out).write_text(text)
    if a.currency_context:
        text = json.dumps(currency_context(a.currency_context), indent=1) + "\n"
        return sys.stdout.write(text) if a.out == "-" else Path(a.out).write_text(text)
    if a.release_gate:
        sys.exit(release_gate())
    if a.snapshot:
        return snapshot()
    _, text = render(check_versions(a.offline), check_kernels(), check_plan_state(),
                     check_inventory(a.offline))
    if a.out == "-":
        sys.stdout.write(text)
    else:
        Path(a.out).write_text(text)


if __name__ == "__main__":
    main()
