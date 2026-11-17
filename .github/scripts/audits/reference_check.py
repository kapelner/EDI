"""Reference check: does each DOI the package cites lead to the paper the text names?

Plan: R/package_metadata/new_feature_plans/v1_0_6/audit_jobs_framework.md, Part 4 ("Reference check":
monthly, 3rd Monday, changed references + 1/6 rotation, Sonnet). The nightly link job only checks
that a DOI resolves; this checks that it resolves to the cited work.

Mechanical stage (no R): every DOI in R/EDI/REFERENCES.md and in the roxygen @references of
R/EDI/R/*.R is looked up on Crossref (api.crossref.org/works/<doi>, a generic User-Agent, about one
request a second, cached on the notes branch for 60 days). A DOI Crossref does not know is a
finding; doi.org's registration-agency lookup then says whether it exists at all or is registered
elsewhere (e.g. DataCite).
Claude stage: one unit per reference entry (a REFERENCES.md bullet, or one DOI's citation inside an
@references block), new or changed entries plus a 1/6 rotation over the monthly runs; the agent compares the
entry's title, authors and year with the Crossref record, which is in its context (no web access).
Apply: only a year, or a typo in a title, and only when the agent cites the Crossref field and the
record in the work folder says the same; the rest is "Needs a human". Roxygen runs once if an R
file was edited.
"""
import difflib
import json
import re
import time
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path

import audit_common as ac
from audits import _doc_audit_shared as sh

SPEC = {
    "name": "reference-check",
    "title": "Reference check",
    "report": "pr",
    "claude": True,
    "model": ac.SONNET,
    "batch_size": 8,
    "period": "month",     # the rotation counts this job's monthly runs
    "cycle_weeks": 6,      # a 1/6 rotation: each unchanged unit is re-read once every 6 monthly runs
    "max_batches": 8,
    "tools": "Read,Glob,Grep",
    "max_turns": 50,
}
REFS = "R/EDI/REFERENCES.md"
CROSSREF = "https://api.crossref.org/works/"
DOI_RA = "https://doi.org/doiRA/"
USER_AGENT = "EDI-reference-check/1.0 (scheduled CI job; python-urllib)"
DELAY = 1.0
REFETCH_DAYS = 60
CACHE = "crossref_cache.json"

_DOI_BODY = r"10\.\d{4,9}/[^\s\]\}]+"


def norm_doi(d):
    d = urllib.parse.unquote(d.strip())
    d = re.sub(r"^(https?://(dx\.)?doi\.org/|doi:)", "", d, flags=re.I)
    return d.rstrip(".,;").strip()


def dois_in(text):
    """DOIs in markdown `[doi:X](...)`, `https://doi.org/X` and Rd `\\doi{X}` forms, in order."""
    found = []
    for m in re.finditer(r"\\doi\{([^{}]+)\}|doi:(" + _DOI_BODY + r")\]|https?://(?:dx\.)?doi\.org/([^\s)\]>]+)",
                         text):
        d = norm_doi(next(g for g in m.groups() if g))
        if d.lower() not in {x.lower() for x in found}:
            found.append(d)
    return found


# ---------------------------------------------------------------- entries

def references_md_entries(text, path=REFS):
    """Each `- **[Key]** ...` bullet (with its continuation lines) that holds a DOI."""
    lines = text.split("\n")
    out, i = [], 0
    while i < len(lines):
        m = re.match(r"^- \*\*\[([^\]]+)\]\*\*", lines[i])
        if not m:
            i += 1
            continue
        start = i
        i += 1
        while i < len(lines) and lines[i].strip() and re.match(r"^\s+\S", lines[i]):
            i += 1
        body = "\n".join(lines[start:i])
        ds = dois_in(body)
        if ds:
            out.append({"id": f"{path}#[{m.group(1)}]", "file": path, "start": start + 1, "end": i,
                        "text": body, "dois": ds})
    return out


def roxygen_entries(repo):
    """One entry per DOI cited in an @references block: the citation text up to that DOI."""
    out, seen = [], {}
    for p in sorted(Path(repo, sh.R_DIR).glob("*.R")):
        rel = p.relative_to(repo).as_posix()
        for b in sh.parse_blocks(p.read_text(encoding="utf-8", errors="replace"), rel):
            for first, tag in b.tag_text("references"):
                prev = 0
                for m in re.finditer(r"\\doi\{([^{}]+)\}", tag):
                    seg = tag[prev:m.end()]
                    start_line = first + tag[:prev].count("\n") + (1 if seg.startswith("\n") else 0)
                    end_line = first + tag[:m.end()].count("\n")
                    prev = m.end()
                    seg = re.sub(r"^[\s;.,]+", "", seg)
                    seg = re.sub(r"^See also\s+", "", seg)
                    doi = norm_doi(m.group(1))
                    uid = f"{rel}#{doi}"
                    seen[uid] = seen.get(uid, 0) + 1
                    if seen[uid] > 1:
                        uid += f"#{seen[uid]}"
                    out.append({"id": uid, "file": rel, "start": start_line, "end": end_line,
                                "text": seg.strip(), "dois": [doi]})
    return out


def all_entries(repo):
    text = Path(repo, REFS).read_text(encoding="utf-8") if Path(repo, REFS).exists() else ""
    return references_md_entries(text) + roxygen_entries(repo)


# ---------------------------------------------------------------- Crossref

def _get(url, timeout=25):
    req = urllib.request.Request(url, headers={"User-Agent": USER_AGENT, "Accept": "application/json"})
    with urllib.request.urlopen(req, timeout=timeout) as r:
        return json.loads(r.read().decode("utf-8", "replace"))


def record_subset(msg):
    """The parts of a Crossref work the agent compares with the entry."""
    def year(key):
        try:
            return msg[key]["date-parts"][0][0]
        except (KeyError, IndexError, TypeError):
            return None
    return {
        "DOI": msg.get("DOI"),
        "type": msg.get("type"),
        "title": (msg.get("title") or [""])[0],
        "subtitle": (msg.get("subtitle") or [""])[0] if msg.get("subtitle") else "",
        "authors": [" ".join(x for x in (a.get("given"), a.get("family")) if x) or a.get("name", "")
                    for a in (msg.get("author") or [])[:25]],
        "n_authors": len(msg.get("author") or []),
        "container": (msg.get("container-title") or [""])[0] if msg.get("container-title") else "",
        "volume": msg.get("volume"), "issue": msg.get("issue"), "page": msg.get("page"),
        "issued": year("issued"), "published-print": year("published-print"),
        "published-online": year("published-online"),
    }


def lookup(doi, get=_get):
    """{"status": "ok", "record"} | {"status": "missing", "ra"} | {"status": "error", "error"}."""
    try:
        return {"status": "ok", "record": record_subset(get(CROSSREF + urllib.parse.quote(doi, safe="/"))["message"])}
    except urllib.error.HTTPError as e:
        if e.code != 404:
            return {"status": "error", "error": f"HTTP {e.code}"}
    except (urllib.error.URLError, OSError, ValueError, KeyError) as e:
        return {"status": "error", "error": str(e)[:200]}
    try:
        ra = get(DOI_RA + urllib.parse.quote(doi, safe="/"))
        ra = (ra[0] if isinstance(ra, list) and ra else {}).get("RA") or (ra[0] if ra else {}).get("status", "")
    except (urllib.error.URLError, OSError, ValueError, KeyError, IndexError, AttributeError):
        ra = ""
    return {"status": "missing", "ra": ra}


def resolve(dois, cache, now, get=_get, delay=DELAY, sleep=time.sleep):
    """Look up every DOI not fresh in `cache` (updated in place). Returns the number fetched."""
    n = 0
    for d in dois:
        c = cache.get(d.lower())
        t = ac.parse_time((c or {}).get("fetched_at"))
        if c and c.get("status") != "error" and t and (now - t).days < REFETCH_DAYS:
            continue
        if n and delay:
            sleep(delay)
        r = lookup(d, get)
        if r["status"] == "error":
            for k in range(2):                    # polite retry on a transient failure
                sleep(5 * (k + 1))
                r = lookup(d, get)
                if r["status"] != "error":
                    break
        cache[d.lower()] = {**r, "doi": d, "fetched_at": now.isoformat(timespec="seconds")}
        n += 1
    return n


# ---------------------------------------------------------------- stages

def mechanical(ctx, get=_get, sleep=time.sleep):
    ctx.workdir.mkdir(parents=True, exist_ok=True)
    entries = all_entries(ctx.repo)
    cache_path = ctx.notes.dir / CACHE
    cache = sh.read_json(cache_path, {}) or {}
    dois = []
    for e in entries:
        for d in e["dois"]:
            if d.lower() not in {x.lower() for x in dois}:
                dois.append(d)
    fetched = resolve(dois, cache, ctx.now, get=get, sleep=sleep)
    sh.write_json(cache_path, cache)
    records = {d.lower(): cache.get(d.lower()) for d in dois}
    sh.write_json(ctx.workdir / "crossref.json", records)
    sh.write_json(ctx.workdir / "reference_entries.json", entries)
    findings, status, elsewhere, errors = [], [], [], []
    where = {}
    for e in entries:
        for d in e["dois"]:
            where.setdefault(d.lower(), []).append(e["id"])
    for d in dois:
        r = records[d.lower()] or {}
        if r.get("status") == "missing":
            ra = r.get("ra") or ""
            if ra and ra.lower() not in ("crossref", "doi does not exist", "invalid doi", "unknown"):
                elsewhere.append(f"`{d}` ({ra})")
                continue
            say = "doi.org says it does not exist" if "not exist" in ra.lower() or "invalid" in ra.lower() \
                else "doi.org did not name a registration agency"
            for uid in where[d.lower()]:
                findings.append({"unit": uid, "kind": "doi-unknown",
                                 "text": f"`{d}` (cited in `{uid}`): Crossref does not know this DOI, and {say}"})
        elif r.get("status") == "error":
            errors.append(d)
    status.append(f"{len(dois)} DOIs in {len(entries)} reference entries; {fetched} looked up on Crossref this "
                  f"run, the rest from the {REFETCH_DAYS}-day cache")
    if elsewhere:
        status.append("registered with an agency other than Crossref, so not compared: " + ", ".join(elsewhere))
    if errors:
        status.append(f"{len(errors)} DOI(s) could not be looked up (network or server error), NOT CHECKED: "
                      + ", ".join(f"`{d}`" for d in errors))
    sh.write_json(ctx.workdir / "reference_status.json", status)
    return findings


def units(ctx):
    entries = sh.read_json(ctx.workdir / "reference_entries.json") or all_entries(ctx.repo)
    records = sh.read_json(ctx.workdir / "crossref.json", {}) or {}
    out = {}
    for e in entries:
        recs = {d: (records.get(d.lower()) or {}).get("record") for d in e["dois"]}
        recs = {d: r for d, r in recs.items() if r}
        if not recs:
            continue   # nothing to compare with (unknown DOI: a mechanical finding; lookup error: next run)
        out[e["id"]] = {
            "hash": ac.text_hash(e["text"]),
            "deps": ac.text_hash(recs),
            "context": {"file": e["file"], "lines": f"{e['start']}-{e['end']}", "entry": e["text"],
                        "dois": e["dois"], "crossref": recs},
        }
    return out


def _norm_title(s):
    s = re.sub(r"<[^>]+>", "", s or "")
    s = re.sub(r"\\[A-Za-z]+\{([^{}]*)\}", r"\1", s)
    s = re.sub(r"[{}\"“”'`*_]", "", s)
    s = re.sub(r"[^\w\s]", " ", s.lower())
    return re.sub(r"\s+", " ", s).strip()


def record_years(rec):
    return {y for y in (rec.get("issued"), rec.get("published-print"), rec.get("published-online")) if y}


def check_fix(entry, rec, f):
    """Mechanical rules for an automatic year or title fix. Returns (ok, reason)."""
    kind, old, new = f.get("kind"), (f.get("old_text") or ""), (f.get("new_text") or "")
    field, value = f.get("crossref_field") or "", str(f.get("crossref_value") or "")
    if kind not in ("year", "title-typo"):
        return False, "only a year or a title typo is applied automatically"
    if not (old and new and field and value):
        return False, "needs old_text, new_text, crossref_field and crossref_value"
    if entry["text"].count(old) != 1:
        return False, f"old_text occurs {entry['text'].count(old)} times in the entry (needs exactly once)"
    if kind == "year":
        if not (re.fullmatch(r"(19|20)\d\d", old) and re.fullmatch(r"(19|20)\d\d", new)):
            return False, "a year fix replaces one four-digit year with another"
        if field not in ("issued", "published-print", "published-online"):
            return False, "a year must cite issued, published-print or published-online"
        if str(rec.get(field)) != new or value.strip() != new:
            return False, f"the Crossref record has {field} = {rec.get(field)}, not {new}"
        if int(old) in record_years(rec):
            return False, f"{old} is one of the record's years (print vs online), so not a typo"
        if not re.search(r"(?<!\d)" + old + r"(?!\d)", entry["text"]):
            return False, "old year is not a standalone number in the entry"
        return True, ""
    title = rec.get("title") or ""
    full = f"{title}: {rec.get('subtitle')}" if rec.get("subtitle") else title
    if field != "title" or _norm_title(value) not in (_norm_title(title), _norm_title(full)):
        return False, "crossref_value is not the record's title"
    if _norm_title(new) not in (_norm_title(title), _norm_title(full)):
        return False, "new_text is not the record's title (ignoring case and punctuation)"
    if _norm_title(old) == _norm_title(new):
        return False, "differs from the record only in case or punctuation (style, not a typo)"
    if difflib.SequenceMatcher(a=_norm_title(old), b=_norm_title(new)).ratio() < 0.85:
        return False, "too different from the record's title to be a typo (a different paper?)"
    return True, ""


def apply(ctx, results, mech, roxygen=None):
    status = sh.read_json(ctx.workdir / "reference_status.json", []) or []
    entries = {e["id"]: e for e in (sh.read_json(ctx.workdir / "reference_entries.json") or [])}
    records = sh.read_json(ctx.workdir / "crossref.json", {}) or {}
    rejected = {h["id"] for h in ctx.notes.findings() if h.get("status") == "rejected"}
    applied, human, proposed, edited = [], [], [], set()
    for r in results:
        for f in r.get("findings") or []:
            uid = f.get("unit", "")
            note = f"`{uid}` ({f.get('kind', '')}): {f.get('text', '')}"
            if f.get("old_text") or f.get("new_text"):
                note += f"\n  - now: “{f.get('old_text', '')}”; Crossref: “{f.get('new_text', '')}”"
            e = entries.get(uid)
            doi = f.get("doi") or (e["dois"][0] if e and len(e["dois"]) == 1 else "")
            rec = (records.get(doi.lower()) or {}).get("record") if doi else None
            if f.get("kind") not in ("year", "title-typo"):
                human.append(ac.decision(note, unit=uid, key=f.get("kind")))
                continue
            if not e or not rec:
                human.append(ac.decision(note + "\n  - not applied automatically: entry or Crossref record not found "
                                    "(name the DOI for an entry with several)", unit=uid, key=f.get("kind")))
                continue
            if e["file"] in sh.GENERATED_R:
                human.append(ac.decision(note + "\n  - not applied automatically: this text is generated from a C++ `//'` "
                                    "comment in R/EDI/src; fix it there", unit=uid, key=f.get("kind")))
                continue
            fid = ac.finding_id(ctx.spec["name"], uid, f["kind"], f"{f.get('old_text')} -> {f.get('new_text')}")
            if fid in rejected:
                continue
            ok, why = check_fix(e, rec, f)
            if ok:
                text = ctx.read(e["file"]) or ""
                lines = text.split("\n")
                span = "\n".join(lines[e["start"] - 1:e["end"]])
                if span.count(f["old_text"]) != 1:
                    ok, why = False, "old_text is not exactly once in the entry as it is in the file"
            if not ok:
                human.append(ac.decision(note + f"\n  - not applied automatically: {why}", unit=uid, key=f.get("kind")))
                continue
            new_span = span.replace(f["old_text"], f["new_text"], 1)
            new_text = "\n".join(lines[:e["start"] - 1] + [new_span] + lines[e["end"]:])
            ctx.path(e["file"]).write_text(new_text)
            if e["file"].startswith(sh.R_DIR + "/"):
                edited.add(e["file"])
            applied.append(f"`{e['file']}` ({uid}): {f['kind']} “{f['old_text']}” → “{f['new_text']}” "
                           f"(Crossref {f.get('crossref_field')}: “{f.get('crossref_value')}”)")
            proposed.append({"unit": uid, "kind": f["kind"], "text": f"{f.get('old_text')} -> {f.get('new_text')}",
                             "applied_file": e["file"], "applied_text": sh.first_changed_line(text, new_text)})
    rox = (roxygen or sh.run_roxygen_once)(ctx.repo, sorted(edited))
    if edited:
        status.append(rox["note"])
    return {"summary": "\n".join(f"- {s}" for s in status), "applied": applied,
            "mechanical": [m["text"] for m in mech], "human": human, "proposed": proposed}
