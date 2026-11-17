"""Privacy check on public files (weekly, PR, Claude only on borderline hits).

Plan: R/package_metadata/new_feature_plans/v1_0_6/audit_jobs_framework.md (Part 4, "Privacy
check on public files"; audit_jobs_framework.md TODO-16).

The word list is NOT in the repository. It comes from the environment variable
AUDIT_SECRET_TERMS (the reusable workflow passes the AUDIT_PRIVACY_TERMS secret into the
prepare step under that name): one term per line, optionally `term|category`. Blank lines and
lines starting with `#` are skipped; the remaining lines are numbered 1, 2, ... in order, and
every output names a term only by that number ("term #3"). The term text never appears in a
finding, the report, a batch file, the notes or the logs: every piece of repository text this
module passes on is masked first (each occurrence of a term, and the word containing it,
becomes `[TERM #n]`), file paths included.

Mechanical (every tracked text file, case-insensitive):
- exact hit: the term as a whole word (or whole phrase) -> a finding `file:line` + term #n;
- the list is not configured -> one finding saying so.
Borderline hits go to the agent (Sonnet), one unit per file, line and term:
- partial-word: the term inside a longer word (terms of 4+ characters);
- near match: a word one edit (insert, delete, substitute, swap) from a one-word term of 5+
  characters.
The agent sees the masked line, two masked lines either side, the term number and the term's
category if the secret gives one, and says whether the line exposes private information.
Nothing is applied. The agent's verdicts are kept in the notes (`verdicts.json`), so a hit is
judged once per change of its line and still listed while it is there.
"""
import hashlib
import json
import os
import re
from pathlib import Path

import audit_common as ac

ENV = "AUDIT_SECRET_TERMS"
MAX_BYTES = 5_000_000
MAX_PER_TERM = 200
MIN_PARTIAL = 4
MIN_NEAR = 5
CONTEXT_LINES = 2
SPANS = "privacy_spans.json"
VERDICTS = "verdicts.json"
WORD = re.compile(r"[^\W_]+(?:['’][^\W_]+)*")

SPEC = {
    "name": "privacy",
    "title": "Privacy check on public files",
    "report": "pr",
    "claude": True,
    "model": ac.SONNET,
    "batch_size": 8,
    "max_batches": 5,
    "cycle_weeks": 52,     # a judged hit is re-read when its line changes, else once a year
    "tools": "Read,Glob,Grep",
    "max_turns": 30,
}


# ---------------------------------------------------------------- terms

def load_terms(raw):
    """[{"n", "text", "lower", "category"}] from the secret's text."""
    terms = []
    for line in (raw or "").splitlines():
        s = line.strip()
        if not s or s.startswith("#"):
            continue
        text, _, cat = s.partition("|")
        text = text.strip()
        if not text:
            continue
        terms.append({"n": len(terms) + 1, "text": text, "lower": text.lower(),
                      "category": cat.strip() or None})
    return terms


def _is_word_char(c):
    return bool(c) and (c.isalnum() or c == "_")


def within_one_edit(a, b):
    """True if a and b differ by exactly one insert, delete, substitution or adjacent swap."""
    if a == b:
        return False
    la, lb = len(a), len(b)
    if abs(la - lb) > 1:
        return False
    if la == lb:
        diff = [i for i in range(la) if a[i] != b[i]]
        if len(diff) == 1:
            return True
        return len(diff) == 2 and diff[1] == diff[0] + 1 and a[diff[0]] == b[diff[1]] and a[diff[1]] == b[diff[0]]
    if la > lb:
        a, b, la, lb = b, a, lb, la
    i = 0
    while i < la and a[i] == b[i]:
        i += 1
    return a[i:] == b[i + 1:]


class Scanner:
    """Finds and masks term occurrences in text. Holds the terms; never prints them."""

    def __init__(self, terms):
        self.terms = terms
        self.by_lower = {}
        for t in terms:
            self.by_lower.setdefault(t["lower"], t)
        alts = sorted({re.escape(t["lower"]) for t in terms}, key=len, reverse=True)
        self.any = re.compile("|".join(alts), re.I) if alts else None
        self.near_terms = {}
        for t in terms:
            if len(t["lower"]) >= MIN_NEAR and WORD.fullmatch(t["lower"]):
                self.near_terms.setdefault(len(t["lower"]), []).append(t)
        self._near_cache = {}

    def _near(self, word):
        w = word.lower()
        if w not in self._near_cache:
            hit = None
            for L in (len(w) - 1, len(w), len(w) + 1):
                for t in self.near_terms.get(L, ()):
                    if within_one_edit(w, t["lower"]):
                        hit = t
                        break
                if hit:
                    break
            self._near_cache[w] = hit
        return self._near_cache[w]

    def hits(self, line):
        """[(kind, term, (word_start, word_end), (match_start, match_end))]; kind is exact,
        partial, near or masked (an occurrence too short to judge, masked only)."""
        out, covered = [], []
        if self.any is None:
            return out
        for m in self.any.finditer(line):
            t = self.by_lower[m.group(0).lower()]
            s, e = m.span()
            whole = not _is_word_char(line[s - 1] if s else "") and not _is_word_char(line[e] if e < len(line) else "")
            ws, we = s, e
            if not whole:
                while ws > 0 and _is_word_char(line[ws - 1]):
                    ws -= 1
                while we < len(line) and _is_word_char(line[we]):
                    we += 1
            kind = "exact" if whole else ("partial" if len(t["lower"]) >= MIN_PARTIAL else "masked")
            out.append((kind, t, (ws, we), (s, e)))
            covered.append((ws, we))
        if self.near_terms:
            for m in WORD.finditer(line):
                s, e = m.span()
                if any(a < e and s < b for a, b in covered):
                    continue
                t = self._near(m.group(0))
                if t:
                    out.append(("near", t, (s, e), (s, e)))
        return out

    def mask(self, text, hits=None):
        hits = self.hits(text) if hits is None else hits
        spans = sorted({(ws, we, t["n"]) for _, t, (ws, we), _ in hits})
        out, pos = [], 0
        for ws, we, n in spans:
            if ws < pos:
                continue
            out.append(text[pos:ws])
            out.append(f"[TERM #{n}]")
            pos = we
        out.append(text[pos:])
        return "".join(out)


# ---------------------------------------------------------------- scan

def _binary(data):
    return b"\0" in data[:8192]


def _path_sha(path):
    return hashlib.sha256(path.encode()).hexdigest()[:20]


def scan(ctx):
    """Scan once per run (cached on ctx): exact findings, borderline units, span sidecar."""
    if getattr(ctx, "_privacy", None) is not None:
        return ctx._privacy
    terms = load_terms(os.environ.get(ENV, ""))
    res = {"configured": bool(terms), "exact": [], "units": {}, "spans": {}, "skipped": 0, "files": 0,
           "overflow": {}}
    if not terms:
        ctx._privacy = res
        return res
    sc = Scanner(terms)
    per_term = {}
    for path in ac.tracked_files(cwd=ctx.repo):
        p = ctx.path(path)
        try:
            if p.is_symlink() or not p.is_file() or p.stat().st_size > MAX_BYTES:
                res["skipped"] += 1
                continue
            data = p.read_bytes()
        except OSError:
            res["skipped"] += 1
            continue
        if _binary(data):
            res["skipped"] += 1
            continue
        res["files"] += 1
        shown = sc.mask(path)
        lines = data.decode("utf-8", "replace").splitlines()
        records = [(0, path, sc.hits(path))] if sc.hits(path) else []
        for i, line in enumerate(lines, 1):
            h = sc.hits(line)
            if h:
                records.append((i, line, h))
        for i, line, h in records:
            where = f"{shown}:{i}" if i else f"{shown} (file path)"
            for n in sorted({t["n"] for k, t, _, _ in h if k == "exact"}):
                per_term[n] = per_term.get(n, 0) + 1
                if per_term[n] > MAX_PER_TERM:
                    res["overflow"][n] = res["overflow"].get(n, 0) + 1
                    continue
                res["exact"].append({"unit": where, "kind": "exact", "term": n,
                                     "text": f"`{where}`: whole-word match of term #{n}."})
            border = {}
            for k, t, wspan, mspan in h:
                if k in ("partial", "near"):
                    border.setdefault(t["n"], (t, set(), []))
                    border[t["n"]][1].add(k)
                    border[t["n"]][2].append([*wspan, *mspan])
            for n, (t, kinds, spans) in sorted(border.items()):
                uid = f"{where}#term{n}"
                masked = sc.mask(line, h)
                lo, hi = max(1, i - CONTEXT_LINES), min(len(lines), i + CONTEXT_LINES)
                around = [f"{j}: {sc.mask(lines[j - 1])}" for j in range(lo, hi + 1)] if i else []
                ctx_u = {"file": shown, "line": i, "term": f"[TERM #{n}]",
                         "match": " and ".join(sorted({"partial": "partial-word", "near": "near match"}[k]
                                                      for k in kinds)),
                         "masked_line": masked, "masked_context": around}
                if t["category"]:
                    ctx_u["category"] = t["category"]
                res["units"][uid] = {"hash": ac.text_hash(masked, sorted(kinds)), "context": ctx_u}
                res["spans"][uid] = {"path_sha": _path_sha(path), "line": i, "spans": spans, "term": n}
    ctx.workdir.mkdir(parents=True, exist_ok=True)
    (ctx.workdir / SPANS).write_text(json.dumps(res["spans"], indent=1, sort_keys=True))
    ctx._privacy = res
    return res


# ---------------------------------------------------------------- stages

def mechanical(ctx):
    res = scan(ctx)
    if not res["configured"]:
        return [{"unit": ENV, "kind": "not-configured",
                 "text": f"The privacy word list is not configured: the {ENV} environment variable (from the "
                         "AUDIT_PRIVACY_TERMS repository secret) is empty, so no file was checked."}]
    out = [{k: f[k] for k in ("unit", "kind", "text")} for f in res["exact"]]
    for n, extra in sorted(res["overflow"].items()):
        out.append({"unit": f"term{n}", "kind": "exact-overflow",
                    "text": f"Term #{n}: {extra} more whole-word line(s) not listed (the first {MAX_PER_TERM} are)."})
    return out


def units(ctx):
    return scan(ctx)["units"]


def _scrubber(ctx):
    """Replace, in agent text, the words of each unit's borderline hits, read back from the
    repository by position (the finish stage has no word list)."""
    try:
        spans = json.loads((ctx.workdir / SPANS).read_text())
    except (OSError, ValueError):
        spans = {}
    by_sha = {_path_sha(p): p for p in ac.tracked_files(cwd=ctx.repo)}
    words = []
    for s in spans.values():
        path = by_sha.get(s["path_sha"])
        if not path:
            continue
        if s["line"] == 0:
            text = path
        else:
            lines = (ctx.read(path) or "").splitlines()
            text = lines[s["line"] - 1] if 0 < s["line"] <= len(lines) else ""
        for ws, we, ms, me in s["spans"]:
            for w in (text[ws:we], text[ms:me]):
                if len(w) >= 2:
                    words.append((w, s["term"]))
    words.sort(key=lambda x: len(x[0]), reverse=True)

    def scrub(t):
        for w, n in words:
            t = re.sub(re.escape(w), f"[TERM #{n}]", t, flags=re.I)
        return t
    return scrub


def scrub_output(ctx, text):
    """Framework hook: mask matched words in an agent's raw output before it is uploaded as
    an artifact (the Claude job calls this; ctx.workdir holds this run's spans file)."""
    return _scrubber(ctx)(text)


def apply(ctx, results, mech):
    scrub = _scrubber(ctx)
    vpath = ctx.notes.dir / VERDICTS
    try:
        verdicts = json.loads(vpath.read_text())
    except (OSError, ValueError):
        verdicts = {}
    plan = {}
    try:
        plan = json.loads((ctx.workdir / "plan.json").read_text())
    except (OSError, ValueError):
        pass
    current = plan.get("units") or {}
    stamp = ctx.now.isoformat(timespec="seconds")
    for r in results:
        found = {f.get("unit"): f for f in r.get("findings") or []}
        for u in r.get("units_checked") or r.get("_units") or []:
            if u not in current:
                continue
            f = found.get(u)
            verdicts[u] = {"hash": current[u].get("hash"), "kind": (f or {}).get("kind", "benign"),
                           "text": scrub((f or {}).get("text", "")), "judged_at": stamp}
    configured = not any(f["kind"] == "not-configured" for f in mech)
    if configured:
        # Keep verdicts only for hits that still exist with the same line text.
        verdicts = {u: v for u, v in verdicts.items() if u in current and current[u].get("hash") == v["hash"]}
        vpath.write_text(json.dumps(verdicts, indent=1, sort_keys=True) + "\n")
    human = [f"`{u}`: {v['kind']}: {v['text']}" for u, v in sorted(verdicts.items())
             if v["kind"] in ("exposes", "unclear")]
    unjudged = sorted(u for u in current if u not in verdicts)
    if unjudged:
        human.append(f"{len(unjudged)} borderline hit(s) not judged yet (agent NOT RUN or rolled over): "
                     + ", ".join(f"`{u}`" for u in unjudged[:20]) + (" ..." if len(unjudged) > 20 else ""))
    exact = sum(1 for f in mech if f["kind"] == "exact")
    summary = ("" if not configured else
               f"{exact} whole-word hit(s); {len(current)} borderline hit(s), "
               f"{sum(1 for v in verdicts.values() if v['kind'] == 'benign')} judged benign. "
               "Terms are named only by their number in the AUDIT_PRIVACY_TERMS secret.")
    return {"summary": summary, "applied": [], "mechanical": [f["text"] for f in mech], "human": human}
