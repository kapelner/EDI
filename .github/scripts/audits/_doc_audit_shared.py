"""Helpers shared by the documentation audits (rd, readme-drift, reference-check, docs-claims).

Plan: R/package_metadata/new_feature_plans/v1_0_6/audit_jobs_framework.md (Parts 2 and 4).

- roxygen block parsing for R/EDI/R/*.R, and the map from an Rd file to the blocks that produce it;
- a guarded "replace one sentence inside one roxygen topic" edit;
- running the repository's roxygen script once, keeping only the Rd files of the edited sources;
- small R helpers (is Rscript there, run an R script with a time limit).

Stdlib only. The file name starts with an underscore so the framework's Repo test does not treat
it as an audit module.
"""
import difflib
import json
import os
import re
import shutil
import signal
import subprocess
from pathlib import Path

PKG = "R/EDI"
R_DIR = "R/EDI/R"
MAN_DIR = "R/EDI/man"
# Roxygen text in these files is generated from C++ `//'` comments (Rcpp::compileAttributes), so a
# fix there would be overwritten: such fixes go to "Needs a human".
GENERATED_R = {"R/EDI/R/RcppExports.R"}

# ---------------------------------------------------------------- roxygen blocks

_ROX = re.compile(r"^([ \t]*)#'(.*)$")
_ASSIGN = re.compile(r"^[ \t]*(`[^`]+`|[A-Za-z.][A-Za-z0-9._]*)[ \t]*(=|<-)")
_TOP_ASSIGN = re.compile(r"^(`[^`]+`|[A-Za-z.][A-Za-z0-9._]*)[ \t]*(=|<-)")
_TAG = re.compile(r"^\s*@([A-Za-z0-9]+)\b\s*(.*)$")


class Block:
    """One run of consecutive `#'` lines. Line numbers are 1-based and inclusive."""

    def __init__(self, path, start, end, lines, indent, obj, topic, tags):
        self.path, self.start, self.end = path, start, end
        self.lines, self.indent, self.obj, self.topic, self.tags = lines, indent, obj, topic, tags

    def text(self):
        return "\n".join(self.lines)

    def tag_text(self, tag):
        """The text of each `@tag` in the block (to the next tag), as a list of (first line, text)."""
        out, cur, first = [], None, None
        for i, line in enumerate(self.lines):
            m = _TAG.match(line)
            if m:
                if cur is not None:
                    out.append((first, "\n".join(cur)))
                cur, first = ([m.group(2)], self.start + i) if m.group(1) == tag else (None, None)
            elif cur is not None:
                cur.append(line)
        if cur is not None:
            out.append((first, "\n".join(cur)))
        return out

    def __repr__(self):
        return f"Block({self.path}:{self.start}-{self.end} topic={self.topic})"


def parse_blocks(text, path=""):
    """Roxygen blocks of one R file, each with the Rd topic it feeds.

    Topic rules (roxygen's own, simplified): `@rdname X` or `@name X` or `@describeIn X`, then
    `@R6method Class$method` (its class), then the object assigned right after a top-level block,
    then, for an indented block (an R6 method's docs), the top-level object it sits inside.
    Blocks tagged `@noRd` get topic None.
    """
    lines = text.splitlines()
    blocks, i, enclosing = [], 0, None
    while i < len(lines):
        if _TOP_ASSIGN.match(lines[i]):
            enclosing = _TOP_ASSIGN.match(lines[i]).group(1).strip("`")
        m = _ROX.match(lines[i])
        if not m:
            i += 1
            continue
        start, indent, content = i, m.group(1), []
        while i < len(lines) and _ROX.match(lines[i]):
            content.append(_ROX.match(lines[i]).group(2))
            i += 1
        j = i
        while j < len(lines) and (not lines[j].strip() or re.match(r"^\s*#(?!')", lines[j])):
            j += 1   # roxygen skips blank lines and plain comments before the object
        obj = None
        if j < len(lines):
            a = _ASSIGN.match(lines[j])
            if a:
                obj = a.group(1).strip("`")
            elif lines[j].strip() in ("NULL", '"_PACKAGE"'):
                obj = lines[j].strip()
        tags = {}
        for c in content:
            t = _TAG.match(c)
            if t:
                tags.setdefault(t.group(1), []).append(t.group(2).strip())
        topic = None
        for tag in ("rdname", "name", "describeIn"):
            if tags.get(tag) and tags[tag][0]:
                topic = tags[tag][0].split()[0]
                break
        if topic is None and tags.get("R6method"):
            topic = tags["R6method"][0].split("$")[0].strip()
        if topic is None:
            if not indent and obj and obj not in ("NULL", '"_PACKAGE"'):
                topic = obj
            elif indent:
                topic = enclosing
        if "noRd" in tags:
            topic = None
        blocks.append(Block(path, start + 1, i, content, indent, obj, topic, tags))
        if not indent and obj and obj not in ("NULL", '"_PACKAGE"') and _TOP_ASSIGN.match(lines[j]):
            enclosing = obj
    return blocks


def nice_name(topic):
    """roxygen2's Rd file name for a topic (roxygen2:::nice_name)."""
    x = re.sub(r"\s+", "_", topic)
    x = re.sub(r"[^A-Za-z0-9_.-]+", "-", x)
    x = re.sub(r"-+", "-", x)
    x = re.sub(r"^-|-$", "", x)
    return re.sub(r"^\.", "dot-", x)


def rd_sources(rd_text):
    """Files named by the `% Please edit documentation in a.R, b.R` header, repo-relative."""
    head = rd_text.splitlines()[:12]
    for i, line in enumerate(head):
        m = re.match(r"%\s*Please edit documentation in\s*(.*)$", line)
        if m:
            parts = [m.group(1)]
            for cont in head[i + 1:]:   # roxygen wraps a long list onto "%   more.R" lines
                if not re.match(r"%\s{2,}\S", cont):
                    break
                parts.append(cont.lstrip("% "))
            names = ",".join(parts)
            return [f"{PKG}/{p.strip()}" for p in names.split(",") if p.strip()]
    return []


def rd_name(rd_text):
    m = re.search(r"^\\name\{([^}]*)\}", rd_text, re.M)
    return m.group(1) if m else None


class RoxygenIndex:
    """All roxygen blocks under R/EDI/R, by file and by Rd file stem."""

    def __init__(self, repo):
        self.repo = Path(repo)
        self.by_file, self.by_stem = {}, {}
        for p in sorted((self.repo / R_DIR).glob("*.R")):
            rel = p.relative_to(self.repo).as_posix()
            bl = parse_blocks(p.read_text(encoding="utf-8", errors="replace"), rel)
            self.by_file[rel] = bl
            for b in bl:
                if b.topic:
                    self.by_stem.setdefault(nice_name(b.topic), []).append(b)

    def blocks_for_rd(self, rd_rel, rd_text=None):
        """Blocks that produce one Rd file, restricted to the files its header names."""
        if rd_text is None:
            rd_text = (self.repo / rd_rel).read_text(encoding="utf-8", errors="replace")
        stem = Path(rd_rel).stem
        names = {stem}
        nm = rd_name(rd_text)
        if nm:
            names.add(nice_name(nm))
        srcs = set(rd_sources(rd_text))
        out = []
        for n in names:
            out += [b for b in self.by_stem.get(n, []) if not srcs or b.path in srcs]
        uniq = {(b.path, b.start): b for b in out}
        return [uniq[k] for k in sorted(uniq)]


def blocks_context(blocks):
    """[{file, lines: "a-b"}] for an agent's context."""
    return [{"file": b.path, "lines": f"{b.start}-{b.end}"} for b in blocks]


# ---------------------------------------------------------------- one-sentence edits

_WS = re.compile(r"\s+")
_NUM = re.compile(r"(?<![\w.])[-+]?\d+(?:\.\d+)?(?:[eE][-+]?\d+)?(?![\w])")
_CODEISH = re.compile(r"\\(?:code|eqn|deqn|link|href|url|doi|var|env|file|pkg)\{[^{}]*\}|`[^`]*`|\[[^\]]*\]\([^)]*\)")


def norm_ws(s):
    return _WS.sub(" ", s or "").strip()


def sentence_count_ok(s):
    """True if s reads as one sentence: no `. X` boundary inside it (X upper case)."""
    body = norm_ws(s)
    return not re.search(r"[.!?]\s+[A-Z(\\]", body)


def safe_text_fix(old, new, max_changed_words=4):
    """Mechanical guard for an automatic spelling/grammar fix. Returns (ok, reason)."""
    o, n = norm_ws(old), norm_ws(new)
    if not o or not n:
        return False, "empty old or new sentence"
    if o == n:
        return False, "old and new sentences are the same"
    if "\n" in (new or "").strip():
        return False, "new sentence has a line break"
    if re.search(r"(^|\s)@[A-Za-z]", o) or re.search(r"(^|\s)@[A-Za-z]", n):
        return False, "touches a roxygen tag"
    if not (sentence_count_ok(o) and sentence_count_ok(n)):
        return False, "more than one sentence"
    if sorted(_NUM.findall(o)) != sorted(_NUM.findall(n)):
        return False, "changes a number"
    if sorted(_CODEISH.findall(o)) != sorted(_CODEISH.findall(n)):
        return False, "changes code, math, a link or markup"
    ow, nw = o.split(" "), n.split(" ")
    sm = difflib.SequenceMatcher(a=ow, b=nw, autojunk=False)
    changed = sum(max(i2 - i1, j2 - j1) for tag, i1, i2, j1, j2 in sm.get_opcodes() if tag != "equal")
    if changed > max_changed_words or changed > max(1, len(ow) // 4):
        return False, f"changes {changed} words (more than a spelling or grammar fix)"
    if {w.lower().strip(".,;:") for w in ("not", "never", "no", "always", "only", "cannot")} & (
            {w.lower().strip(".,;:") for w in ow} ^ {w.lower().strip(".,;:") for w in nw}):
        return False, "adds or removes a negation or a quantifier"
    return True, ""


def _content_spans(text, blocks):
    """Absolute offsets of every roxygen content character of `blocks` in `text`.

    Returns a list of (normalised string, list mapping each normalised char to an absolute
    offset). Lines are joined by one space, and whitespace runs collapse to one space.
    """
    line_starts = [0]
    for m in re.finditer("\n", text):
        line_starts.append(m.end())
    lines = text.split("\n")
    chars, offs = [], []
    for b in blocks:
        for ln in range(b.start, b.end + 1):
            line = lines[ln - 1]
            m = _ROX.match(line)
            if not m:
                continue
            base = line_starts[ln - 1] + m.start(2)
            for k, ch in enumerate(m.group(2)):
                chars.append(ch)
                offs.append(base + k)
            chars.append("\n")
            offs.append(None)
    norm, nmap, prev_ws = [], [], True
    for ch, off in zip(chars, offs):
        if ch.isspace():
            if not prev_ws:
                norm.append(" ")
                nmap.append(off)
            prev_ws = True
        else:
            norm.append(ch)
            nmap.append(off)
            prev_ws = False
    return "".join(norm), nmap


def count_in_blocks(text, blocks, needle):
    hay, _ = _content_spans(text, blocks)
    n = norm_ws(needle)
    return hay.count(n) if n else 0


def replace_in_blocks(text, blocks, old, new):
    """Replace the one occurrence of sentence `old` inside `blocks` with `new`.

    Matching ignores line breaks, `#'` prefixes and whitespace runs. Only the words that differ
    are rewritten, so the line layout survives a one-word fix. Returns the new file text, or
    None when `old` does not occur exactly once.
    """
    hay, nmap = _content_spans(text, blocks)
    o, n = norm_ws(old), norm_ws(new)
    if not o or hay.count(o) != 1:
        return None
    s = hay.index(o)
    # word positions of the old sentence: (start offset, end offset exclusive) in the file
    words, k = [], 0
    for w in o.split(" "):
        ws = s + k
        we = ws + len(w) - 1
        words.append((nmap[ws], nmap[we] + 1))
        k += len(w) + 1
    ow, nw = o.split(" "), n.split(" ")
    edits = []
    for tag, i1, i2, j1, j2 in difflib.SequenceMatcher(a=ow, b=nw, autojunk=False).get_opcodes():
        if tag == "equal":
            continue
        rep = " ".join(nw[j1:j2])
        if tag == "insert":
            pos = words[i1 - 1][1] if i1 > 0 else words[0][0]
            edits.append((pos, pos, (" " + rep) if i1 > 0 else (rep + " ")))
        elif tag == "delete":
            a = words[i1 - 1][1] if i1 > 0 else words[i1][0]
            b = words[i2 - 1][1] if i1 > 0 else (words[i2][0] if i2 < len(words) else words[i2 - 1][1])
            edits.append((a, b, ""))
        else:
            edits.append((words[i1][0], words[i2 - 1][1], rep))
    if any("\n" in text[a:b] for a, b, _ in edits):
        # The changed words straddle a line break. Rewriting across the `#'` prefix risks a
        # blank roxygen line (a new paragraph), so this is left to a human.
        return None
    for a, b, rep in sorted(edits, reverse=True):
        text = text[:a] + rep + text[b:]
    return text


# ---------------------------------------------------------------- R

def have_r():
    return shutil.which("Rscript") is not None


def run_r(args, timeout, cwd=None, env=None):
    """Run Rscript with a wall-clock limit; the whole process group is killed on time-out.

    Returns (returncode or None on time-out, stdout, stderr)."""
    e = dict(os.environ)
    e.update({"OMP_NUM_THREADS": "1", "OPENBLAS_NUM_THREADS": "1", "MKL_NUM_THREADS": "1",
              "R_DEFAULT_INTERNET_TIMEOUT": "20"})
    if env:
        e.update(env)
    p = subprocess.Popen(["Rscript", *args], cwd=cwd, env=e, stdout=subprocess.PIPE,
                         stderr=subprocess.PIPE, text=True, start_new_session=True)
    try:
        out, err = p.communicate(timeout=timeout)
        return p.returncode, out, err
    except subprocess.TimeoutExpired:
        try:
            os.killpg(p.pid, signal.SIGKILL)
        except OSError:
            pass
        out, err = p.communicate()
        return None, out, err


def _porcelain(repo):
    r = subprocess.run(["git", "status", "--porcelain", "--untracked-files=all"], cwd=repo,
                       capture_output=True, text=True)
    out = {}
    for line in r.stdout.splitlines():
        if len(line) > 3:
            out[line[3:].split(" -> ")[-1]] = line[:2]
    return out


def run_roxygen_once(repo, edited_r_files, timeout=1800):
    """Regenerate the Rd files once, after every fix is applied.

    Runs the repository's own roxygen script (R/fast_roxygenize.R: roxygen2::roxygenize with a
    source loader, so nothing compiles; it also carries the R6 file-mapping patches the plain
    `load = "source"` loader lacks). Of what it changes, only the Rd files whose header names an
    edited R file are kept; everything else it touched (RcppExports, NAMESPACE, unrelated pages)
    is put back, so the PR holds just the fixes and their pages.

    Returns {"ran": bool, "ok": bool, "note": str, "kept": [rel paths], "reverted": [rel paths]}.
    """
    repo = Path(repo)
    if not edited_r_files:
        return {"ran": False, "ok": True, "note": "no roxygen source was edited", "kept": [], "reverted": []}
    if not have_r():
        return {"ran": False, "ok": False, "kept": [], "reverted": [],
                "note": "R is not available in this job, so roxygen was NOT RUN: the Rd files still "
                        "need regenerating (`cd R && Rscript fast_roxygenize.R`)."}
    before = _porcelain(repo)
    code, out, err = run_r(["fast_roxygenize.R"], timeout, cwd=repo / "R")
    after = _porcelain(repo)
    edited = set(edited_r_files)
    kept, reverted = [], []
    for path, st in sorted(after.items()):
        if path in before and before[path] == st:
            continue
        keep = False
        if path.startswith(MAN_DIR + "/") and path.endswith(".Rd") and (repo / path).exists():
            srcs = set(rd_sources((repo / path).read_text(encoding="utf-8", errors="replace")))
            keep = bool(srcs & edited)
        if path in edited:
            keep = True
        if keep:
            kept.append(path)
            continue
        if st.strip() == "??":
            try:
                (repo / path).unlink()
            except OSError:
                pass
        else:
            subprocess.run(["git", "checkout", "--", path], cwd=repo, capture_output=True)
        reverted.append(path)
    if code is None:
        note = f"roxygen timed out after {timeout} s; the Rd files still need regenerating"
        ok = False
    elif code:
        tail = "\n".join((err or out or "").strip().splitlines()[-8:])
        note = f"roxygen failed (exit {code}); the Rd files still need regenerating. Last lines:\n```\n{tail}\n```"
        ok = False
    else:
        note = f"roxygen ran once and regenerated {sum(p.endswith('.Rd') for p in kept)} Rd file(s)"
        ok = True
    if reverted:
        note += f"; {len(reverted)} other file(s) it touched were put back"
    return {"ran": True, "ok": ok, "note": note, "kept": kept, "reverted": reverted}


# ---------------------------------------------------------------- misc

def write_json(path, obj):
    Path(path).parent.mkdir(parents=True, exist_ok=True)
    Path(path).write_text(json.dumps(obj, indent=1, sort_keys=True))


def read_json(path, default=None):
    try:
        return json.loads(Path(path).read_text())
    except (OSError, ValueError):
        return default


def slug(s):
    return re.sub(r"[^A-Za-z0-9._-]+", "_", s).strip("_")[:120]


# ---------------------------------------------------------------- tag ranges and block edits

def tag_range(text, block, tag):
    """(first, last) file lines of `@tag` inside `block`: from the tag line to the line before the
    next tag, without trailing empty `#'` lines. None if the block has no such tag."""
    lines = text.split("\n")
    first = None
    for ln in range(block.start, block.end + 1):
        m = _ROX.match(lines[ln - 1])
        if not m:
            continue
        t = _TAG.match(m.group(2))
        if t and first is None and t.group(1) == tag:
            first = ln
        elif t and first is not None:
            last = ln - 1
            break
    else:
        last = block.end
    if first is None:
        return None
    while last > first and not _ROX.match(lines[last - 1]).group(2).strip():
        last -= 1
    return first, last


def replace_tag_lines(text, block, tag, new_body):
    """Replace the whole `@tag` section of `block` with `@tag` plus `new_body` (plain text, no
    `#'` prefixes). Only those lines change. Returns the new text, or None if the tag is missing."""
    rng = tag_range(text, block, tag)
    if rng is None:
        return None
    lines = text.split("\n")
    prefix = block.indent + "#'"
    body = (new_body or "").strip("\n").split("\n")
    new = [f"{prefix} @{tag}"] + [f"{prefix} {l}" if l.strip() else prefix for l in body]
    a, b = rng
    return "\n".join(lines[:a - 1] + new + lines[b:])


def rd_section(rd_text, name, limit=None):
    """The body of a top-level Rd section such as \\usage or \\arguments (brace matched)."""
    m = re.search(r"^\\" + re.escape(name) + r"\{", rd_text, re.M)
    if not m:
        return ""
    depth, i = 1, m.end()
    while i < len(rd_text) and depth:
        c = rd_text[i]
        if c == "\\":
            i += 2
            continue
        depth += (c == "{") - (c == "}")
        i += 1
    body = rd_text[m.end():i - 1].strip("\n")
    if limit and len(body) > limit:
        body = body[:limit] + "\n... (truncated; read the Rd file for the rest)"
    return body


def first_changed_line(old_text, new_text):
    """A stripped line of new_text that is not in old_text (the applied_text of a fix)."""
    old = set(old_text.split("\n"))
    for line in new_text.split("\n"):
        if line not in old and line.strip():
            return line.strip()
    return ""
