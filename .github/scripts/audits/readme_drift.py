"""README / vignette / article drift audit.

Plan: R/package_metadata/new_feature_plans/v1_0_6/audit_jobs_framework.md, Part 4 ("README /
vignette / article drift": weekly, Thursday 06:00 UTC, changed docs + rotation, Sonnet).

Mechanical stage (needs R and the installed EDI; the R side is readme_drift_run.R): every R chunk of
R/EDI/README.md (README.Rmd if there is one), R/EDI/vignettes/*.Rmd and R/EDI/vignettes/articles/*.Rmd
is run in order in a fresh R session per document, with a time limit, and its output, messages,
warnings and errors are recorded into the work folder. Chunks with `eval = FALSE` (per chunk, or by
a `knitr::opts_chunk$set(eval = FALSE)` before them) are not run, as when the document is built;
expressions that install packages or open a viewer are skipped. Errors, warnings and time-outs are
mechanical findings.
Claude stage: documents that changed or whose recorded output changed, plus a 4-week rotation; the
agent compares the numbers and claims in the prose with the recorded output.
Apply: only exact single-number replacements in prose, each shown with the recorded output line that
supports it; everything else is "Needs a human".
"""
import concurrent.futures as cf
import re
from pathlib import Path

import audit_common as ac
from audits import _doc_audit_shared as sh

SPEC = {
    "name": "readme-drift",
    "title": "README and vignette drift audit",
    "report": "pr",
    "claude": True,
    "model": ac.SONNET,
    "batch_size": 4,       # documents are long
    "cycle_weeks": 4,
    "max_batches": 4,
    "tools": "Read,Glob,Grep",
    "max_turns": 60,
}

SCRIPT = Path(__file__).with_name("readme_drift_run.R")
DOC_LIMIT = 900            # s per document
WORKERS = 2
OUT_DIR = "readme_outputs"

_FENCE_RMD = re.compile(r"^(\s*)(`{3,})\s*\{r([ ,][^}]*)?\}\s*$")
_FENCE_MD = re.compile(r"^(\s*)(`{3,})\s*(?:r|R|\{r([ ,][^}]*)?\})\s*$")
_NUMTOK = re.compile(r"(?<![\w.])[-+]?\d+(?:\.\d+)?(?:[eE][-+]?\d+)?%?(?![\w])")


def documents(repo):
    repo = Path(repo)
    pkg = repo / sh.PKG
    docs = []
    readme = pkg / "README.Rmd" if (pkg / "README.Rmd").exists() else pkg / "README.md"
    if readme.exists():
        docs.append(readme)
    docs += sorted((pkg / "vignettes").glob("*.Rmd")) + sorted((pkg / "vignettes" / "articles").glob("*.Rmd"))
    return [d.relative_to(repo).as_posix() for d in docs]


def _split_opts(s):
    parts, depth, cur = [], 0, ""
    for ch in s:
        if ch in "([{":
            depth += 1
        elif ch in ")]}":
            depth -= 1
        if ch == "," and depth == 0:
            parts.append(cur)
            cur = ""
        else:
            cur += ch
    if cur.strip():
        parts.append(cur)
    return [p.strip() for p in parts if p.strip()]


def chunk_options(header):
    """(label, {option: value text}) from the text after `{r`."""
    parts = _split_opts(header or "")
    label, opts = "", {}
    for i, p in enumerate(parts):
        if "=" in p:
            k, v = p.split("=", 1)
            opts[k.strip()] = v.strip()
        elif i == 0:
            label = p.strip().strip("'\"")
    return label, opts


def _bool(v):
    v = (v or "").strip()
    if v in ("FALSE", "F"):
        return False
    if v in ("TRUE", "T"):
        return True
    return None   # an expression: treated as TRUE (knitr evaluates it; we cannot)


def extract_chunks(text, markdown=False):
    """R chunks of a document, in order.

    Rmd: ```{r ...} chunks, honouring a chunk's `eval` option and a global
    `opts_chunk$set(eval = ...)` in an earlier chunk. Markdown (README.md): ```r fences, all run.
    Returns [{index, label, start_line, end_line, code, eval}] (lines 1-based, the fence lines)."""
    lines = text.split("\n")
    out, i, default_eval = [], 0, True
    fence = _FENCE_MD if markdown else _FENCE_RMD
    while i < len(lines):
        m = fence.match(lines[i])
        if not m:
            i += 1
            continue
        ticks = m.group(2)
        header = m.group(3) or ""
        start = i
        i += 1
        body = []
        while i < len(lines) and not re.match(r"^\s*" + ticks + r"\s*$", lines[i]):
            body.append(lines[i])
            i += 1
        label, opts = chunk_options(header)
        ev = _bool(opts.get("eval")) if "eval" in opts else default_eval
        code = "\n".join(body)
        g = re.search(r"opts_chunk\$set\((.*)\)", code, re.S)
        if g:
            _, gopts = chunk_options("x, " + g.group(1))
            if "eval" in gopts and _bool(gopts["eval"]) is not None:
                default_eval_next = _bool(gopts["eval"])
            else:
                default_eval_next = default_eval
        else:
            default_eval_next = default_eval
        out.append({"index": len(out) + 1, "label": label, "start_line": start + 1, "end_line": i + 1,
                    "code": code, "eval": ev is not False})
        default_eval = default_eval_next
        i += 1
    return out


def outputs_path(ctx, doc):
    return ctx.workdir / OUT_DIR / (sh.slug(doc) + ".json")


def run_document(ctx, doc, chunks):
    """Run one document's chunks with readme_drift_run.R. Returns (record, timed_out)."""
    spec_path = ctx.workdir / OUT_DIR / (sh.slug(doc) + ".chunks.json")
    sh.write_json(spec_path, {"doc": doc, "chunks": chunks})
    out = outputs_path(ctx, doc)
    code, so, se = sh.run_r([str(SCRIPT), str(spec_path), str(out)], timeout=DOC_LIMIT,
                            cwd=ctx.path(doc).parent)
    rec = sh.read_json(out)
    if rec is None:
        tail = "\n".join((se or so or "").strip().splitlines()[-3:])
        rec = {"doc": doc, "chunks": [], "failed": f"the R session failed: {tail}"}
    return rec, code is None


def mechanical(ctx):
    ctx.workdir.mkdir(parents=True, exist_ok=True)
    (ctx.workdir / OUT_DIR).mkdir(exist_ok=True)
    status, findings, runs = [], [], {}
    docs = documents(ctx.repo)
    plan = {d: extract_chunks(ctx.read(d) or "", markdown=d.endswith(".md")) for d in docs}
    if not sh.have_r():
        status.append("R is not available in this job: no chunk was run")
        findings.append({"unit": None, "kind": "not-run", "text": "R is not available in this job: no chunk was run"})
    else:
        todo = {d: c for d, c in plan.items() if any(x["eval"] for x in c)}
        with cf.ThreadPoolExecutor(max_workers=WORKERS) as pool:
            futs = {pool.submit(run_document, ctx, d, c): d for d, c in todo.items()}
            for fut in cf.as_completed(futs):
                d = futs[fut]
                rec, timed_out = fut.result()
                rec["timed_out"] = timed_out
                runs[d] = rec
                sh.write_json(outputs_path(ctx, d), rec)
        status.append(f"ran the R chunks of {len(todo)} of {len(docs)} documents "
                      f"({len(docs) - len(todo)} have no chunk that is evaluated)")
    for d in sorted(runs):
        findings += findings_for_run(d, runs[d], plan[d])
    sh.write_json(ctx.workdir / "readme_status.json", status)
    return findings


def findings_for_run(doc, rec, chunks):
    out = []
    if rec.get("failed"):
        out.append({"unit": doc, "kind": "doc-not-run", "text": f"`{doc}`: {rec['failed']}"})
        return out
    done = {c["index"] for c in rec.get("chunks", [])}
    for c in rec.get("chunks", []):
        where = f"`{doc}` chunk {c['index']}" + (f" `{c['label']}`" if c.get("label") else "") + \
                f" (line {c.get('start_line')})"
        if c.get("error"):
            out.append({"unit": doc, "kind": "chunk-error", "text": f"{where}: error: {c['error']}"})
        for w in c.get("warnings") or []:
            out.append({"unit": doc, "kind": "chunk-warning", "text": f"{where}: warning: {w}"})
    if rec.get("timed_out") or not rec.get("finished"):
        left = [c for c in chunks if c["eval"] and c["index"] not in done]
        nxt = f"; stopped in or before chunk {left[0]['index']} (line {left[0]['start_line']})" if left else ""
        out.append({"unit": doc, "kind": "doc-time-limit",
                    "text": f"`{doc}`: did not finish within {DOC_LIMIT} s{nxt}"})
    return out


def has_result(output):
    """True if a chunk printed something besides the echoed code (`> ` and `+ ` lines)."""
    return any(l.strip() and not l.startswith(("> ", "+ ")) for l in (output or "").split("\n"))


def _output_text(rec):
    return "\n".join(c.get("output") or "" for c in (rec or {}).get("chunks", []))


def units(ctx):
    out = {}
    for d in documents(ctx.repo):
        rec = sh.read_json(outputs_path(ctx, d))
        if not rec or not any(c.get("eval") and has_result(c.get("output")) for c in rec.get("chunks", [])):
            continue   # nothing printed a result, so there is no output to compare the prose with
        chunks = extract_chunks(ctx.read(d) or "", markdown=d.endswith(".md"))
        out[d] = {
            "hash": ac.file_hash(ctx.path(d)),
            # The recorded output is a dependency: a document is re-read when what it prints changes.
            "deps": ac.text_hash([(c.get("index"), c.get("output"), c.get("error")) for c in rec["chunks"]]),
            "context": {
                "doc": d,
                "outputs_file": f".audit-work/{OUT_DIR}/{sh.slug(d)}.json",
                "chunks": [{"index": c["index"], "label": c["label"], "lines": f"{c['start_line']}-{c['end_line']}",
                            "evaluated": c["eval"]} for c in chunks],
                "chunk_errors": [c["index"] for c in rec["chunks"] if c.get("error")],
            },
        }
    return out


# ---------------------------------------------------------------- apply

def _num(s):
    try:
        return float(s.rstrip("%"))
    except (TypeError, ValueError):
        return None


def _decimals(s):
    s = s.rstrip("%")
    return len(s.split(".", 1)[1]) if "." in s and "e" not in s.lower() else 0


def supports(output_line, new_number):
    """True if `new_number` is a number in `output_line`, exactly or rounded to its own decimals."""
    target = _num(new_number)
    if target is None:
        return False
    d = _decimals(new_number)
    for tok in _NUMTOK.findall(output_line):
        v = _num(tok)
        if v is None:
            continue
        if tok.rstrip("%") == new_number.rstrip("%") or round(v, d) == target:
            return True
    return False


def in_chunk(line_no, chunks):
    return any(c["start_line"] <= line_no <= c["end_line"] for c in chunks)


def check_number_fix(doc_text, outputs_text, f, markdown=False):
    """Mechanical rules for an automatic number replacement. Returns (ok, reason, new doc text)."""
    old_text, old_n, new_n, line = (f.get(k) or "" for k in ("old_text", "old_number", "new_number", "output_line"))
    if f.get("kind") != "number-drift" or not (old_text and old_n and new_n and line):
        return False, "not a number fix with old_text, old_number, new_number and output_line", None
    if "\n" in old_text or "`r " in old_text:
        return False, "old_text spans lines or holds inline R code", None
    if doc_text.count(old_text) != 1:
        return False, f"old_text occurs {doc_text.count(old_text)} times in the document (needs exactly once)", None
    toks = [t for t in _NUMTOK.findall(old_text) if t.rstrip("%") == old_n.rstrip("%")]
    if len(toks) != 1:
        return False, "old_number is not exactly one number in old_text", None
    if _num(new_n) is None or _num(new_n) == _num(old_n):
        return False, "new_number is not a different number", None
    if not any(line.rstrip() and line.rstrip() in l for l in outputs_text.split("\n")) and \
            line.rstrip() not in outputs_text:
        return False, "output_line is not in the recorded output", None
    if not supports(line, new_n):
        return False, "output_line does not contain new_number (exactly or rounded)", None
    pos = doc_text.index(old_text)
    line_no = doc_text[:pos].count("\n") + 1
    if in_chunk(line_no, extract_chunks(doc_text, markdown)):
        return False, "old_text is inside a code chunk", None
    m = re.search(r"(?<![\w.])" + re.escape(old_n) + r"(?![\w])", old_text)
    new_text = old_text[:m.start()] + new_n + old_text[m.end():]
    return True, "", doc_text.replace(old_text, new_text, 1)


def apply(ctx, results, mech):
    status = sh.read_json(ctx.workdir / "readme_status.json", []) or []
    rejected = {h["id"] for h in ctx.notes.findings() if h.get("status") == "rejected"}
    applied, human, proposed = [], [], []
    for r in results:
        for f in r.get("findings") or []:
            doc = f.get("unit", "")
            note = f"`{doc}` ({f.get('kind', '')}): {f.get('text', '')}"
            if f.get("old_text"):
                note += f"\n  - prose: “{f['old_text']}”"
            if f.get("output_line"):
                note += f"\n  - output: `{f['output_line']}`"
            text = ctx.read(doc)
            if f.get("kind") != "number-drift" or text is None:
                human.append(ac.decision(note, unit=f.get("unit"), key=f.get("kind")))
                continue
            fid = ac.finding_id(ctx.spec["name"], doc, "number-drift",
                                f"{f.get('old_text')}: {f.get('old_number')} -> {f.get('new_number')}")
            if fid in rejected:
                continue
            rec = sh.read_json(outputs_path(ctx, doc), {})
            ok, why, new_doc = check_number_fix(text, _output_text(rec), f, markdown=doc.endswith(".md"))
            if not ok:
                human.append(ac.decision(note + f"\n  - not applied automatically: {why}", unit=f.get("unit"), key=f.get("kind")))
                continue
            ctx.path(doc).write_text(new_doc)
            new_line = f["old_text"].replace(f["old_number"], f["new_number"], 1)
            applied.append(f"`{doc}`: {f['old_number']} → {f['new_number']} in “{f['old_text']}” "
                           f"(output: `{f['output_line'].strip()}`)")
            proposed.append({"unit": doc, "kind": "number-drift",
                             "text": f"{f.get('old_text')}: {f.get('old_number')} -> {f.get('new_number')}",
                             "applied_file": doc, "applied_text": new_line})
            if doc.endswith("README.Rmd"):
                status.append("README.Rmd changed: README.md must be re-knitted from it")
    return {"summary": "\n".join(f"- {s}" for s in status), "applied": applied,
            "mechanical": [m["text"] for m in mech], "human": human, "proposed": proposed}
