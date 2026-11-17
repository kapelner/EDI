"""R <-> Python parity (monthly, 3rd Saturday, and after a push that touches python/ or a kernel
file python/CMakeLists.txt compiles; PR, Sonnet).

Plan: R/package_metadata/new_feature_plans/v1_0_6/audit_jobs_framework.md (Part 4, "R <-> Python
parity"; audit_jobs_framework.md TODO-16).

- Units: one pybind11 binding, i.e. one `m.def(...)` in python/cpp/bindings_*.cpp. Context,
  precomputed: the binding's line range, its py::arg names and defaults, the matching stub in
  python/src/edi_kernels/_core.pyi, the R/EDI/src kernel function(s) it calls, the Rcpp
  exports on the R side (signature with defaults): the R twin by name (fast_ols ->
  fast_ols_cpp) and any export that reaches the same kernel within two calls, the R files and
  lines that call those exports, the Rd page of each export, and the Python test file.
  Hash: the binding text and its stub. Deps: the export signatures and the R call lines.
- Selection: new or changed bindings, open findings, and a 1/6 monthly rotation; on a push run
  only new and changed bindings (no rotation), so repeated pushes do not re-read the slice.
  A push reaches this audit as a `workflow_run` event (rpy-parity-push.yml relays it, since
  claude-code-action rejects `push`), so both events count as a push here (push_event()).
- Mechanical (no Claude): a py::arg default that differs from the default of the same-named
  argument of the binding's R twin; a binding missing from the stub file or from the package's
  __init__.py imports.
- Apply: docstring-only fixes inside python/ whose old text occurs exactly once in the file and
  lies inside a docstring (a C++ string literal of a binding, or a triple-quoted string in a
  .py / .pyi file). The same replacement is made in _core.pyi when the old text occurs there
  exactly once too, so the stub keeps the binding's text. Everything else goes to "Needs a human".
"""
import re
from pathlib import Path

import audit_common as ac
from audits import _edi_index as ei
from audits import _rotation as rot

SPEC = {
    "name": "rpy-parity",
    "title": "R / Python parity",
    "report": "pr",
    "claude": True,
    "model": ac.SONNET,
    # Each binding means reading the m.def, the stub, the R export, its Rd page and the R
    # callers, so batches are small (as in docs-claims): 4 units, 80 turns, 32 units a run.
    "batch_size": 4,
    "max_batches": 8,
    "max_turns": 80,
    "period": "month",        # the rotation counts this job's monthly runs
    "cycle_weeks": 6,         # 1/6 rotation; push runs read no slice (see units())
    "tools": "Read,Glob,Grep",
}
BIND_DIR = "python/cpp"
STUB = "python/src/edi_kernels/_core.pyi"
INIT = "python/src/edi_kernels/__init__.py"
CMAKE = "python/CMakeLists.txt"
TWIN_SUFFIXES = ("_cpp", "_with_var_cpp", "_weighted_cpp")
# Events that mean "a push to main touched the bindings or a kernel". The workflow is started
# by `workflow_run` (from rpy-parity-push.yml), because anthropics/claude-code-action fails on a
# `push` event with "Unsupported event type: push"; `push` stays for local runs and tests.
PUSH_EVENTS = ("push", "workflow_run")

DEF_START = re.compile(r"\bm\.def\(\s*")
PYARG = re.compile(r'py::arg\("(\w+)"\)(?:\s*=\s*(py::none\(\)|"(?:[^"\\]|\\.)*"|[^,)\s]+))?')
CPP_DEF = re.compile(r"^[A-Za-z_][\w:<>, \t\*&]*?\b([A-Za-z_]\w*)[ \t]*\([^;\n]*$", re.M)


# ---------------------------------------------------------------- parsing

def _skip_string(text, i):
    """text[i] is a quote; return the index after the closing quote."""
    q = text[i]
    i += 1
    while i < len(text):
        if text[i] == "\\":
            i += 2
            continue
        if text[i] == q:
            return i + 1
        i += 1
    return i


def call_end(text, open_paren):
    """Index just past the ')' matching text[open_paren] == '(' (strings and comments skipped)."""
    depth, i = 0, open_paren
    while i < len(text):
        c = text[i]
        if c in "\"'":
            i = _skip_string(text, i)
            continue
        if text.startswith("//", i):
            j = text.find("\n", i)
            i = len(text) if j < 0 else j
            continue
        if text.startswith("/*", i):
            j = text.find("*/", i)
            i = len(text) if j < 0 else j + 2
            continue
        if c == "(":
            depth += 1
        elif c == ")":
            depth -= 1
            if depth == 0:
                return i + 1
        i += 1
    return len(text)


def bindings(text):
    """[{name, literal, start_line, end_line, text}] for each m.def(...) in a binding file."""
    out = []
    for m in DEF_START.finditer(text):
        line_start = text.rfind("\n", 0, m.start()) + 1
        if text[line_start:m.start()].lstrip().startswith("//"):
            continue
        open_paren = m.end() - len(m.group(0)) + m.group(0).index("(")
        end = call_end(text, open_paren)
        block = text[m.start():end]
        lit = re.match(r'm\.def\(\s*"(\w+)"', block)
        name = lit.group(1) if lit else re.match(r"m\.def\(\s*([A-Za-z_]\w*)", block).group(1)
        out.append({"name": name, "literal": bool(lit),
                    "start_line": text.count("\n", 0, m.start()) + 1,
                    "end_line": text.count("\n", 0, end) + 1, "text": block, "offset": m.start()})
    return out


def code_only(text):
    """`text` with string literals and comments blanked (so names in a docstring do not count)."""
    out, i = [], 0
    while i < len(text):
        c = text[i]
        if c in "\"'":
            j = _skip_string(text, i)
            out.append(" ")
            i = j
            continue
        if text.startswith("//", i):
            j = text.find("\n", i)
            i = len(text) if j < 0 else j
            continue
        if text.startswith("/*", i):
            j = text.find("*/", i)
            i = len(text) if j < 0 else j + 2
            continue
        out.append(c)
        i += 1
    return "".join(out)


def py_args(block):
    """[(name, default or None)] in order."""
    return [(n, d) for n, d in PYARG.findall(block)] if block else []


def split_params(sig):
    """Parameters of a C++ signature `name(a, b = 1, ...)` split at depth-0 commas."""
    i = sig.find("(")
    if i < 0:
        return []
    body = sig[i + 1:call_end(sig, i) - 1]
    parts, depth, cur, j = [], 0, "", 0
    while j < len(body):
        c = body[j]
        if c in "\"'":
            k = _skip_string(body, j)
            cur += body[j:k]
            j = k
            continue
        if c in "(<{[":
            depth += 1
        elif c in ")>}]":
            depth -= 1
        if c == "," and depth == 0:
            parts.append(cur.strip())
            cur = ""
        else:
            cur += c
        j += 1
    if cur.strip():
        parts.append(cur.strip())
    return parts


def cpp_defaults(sig):
    """{arg name: default text} for the parameters of an export signature that have a default."""
    out = {}
    for p in split_params(sig):
        p = re.sub(r"//[^\n]*", "", p).strip()
        if "=" not in p:
            continue
        decl, default = p.split("=", 1)
        n = re.search(r"([A-Za-z_]\w*)\s*$", decl.strip())
        if n:
            out[n.group(1)] = default.strip()
    return out


def norm_default(v):
    """A comparable value for a default written in C++ or as a py::arg default, or None when
    the text is not a plain literal (so it is not compared)."""
    if v is None:
        return None
    s = v.strip()
    if s in ("py::none()", "R_NilValue", "NULL", "nullptr", "std::nullopt") or re.match(
            r"(Rcpp::)?Nullable<.*>\(\)$", s):
        return ("none",)
    if s in ("true", "TRUE"):
        return ("bool", True)
    if s in ("false", "FALSE"):
        return ("bool", False)
    if len(s) >= 2 and s[0] == s[-1] == '"':
        return ("str", s[1:-1])
    try:
        return ("num", float(s.rstrip("LlFfUu") if not s.lower().startswith("0x") else int(s, 16)))
    except ValueError:
        return None


def stub_blocks(stub_text):
    """{name: text of every `def name(...)` block (overloads joined)} in a .pyi file."""
    out = {}
    lines = stub_text.splitlines()
    i = 0
    while i < len(lines):
        m = re.match(r"def (\w+)\(", lines[i])
        if m:
            j = i + 1
            while j < len(lines) and not re.match(r"(def |@|\S)", lines[j]):
                j += 1
            out.setdefault(m.group(1), []).append("\n".join(lines[i:j]))
            i = j
            continue
        i += 1
    return {k: "\n".join(v) for k, v in out.items()}


def cpp_definitions(src_texts):
    """{function name: src file} for functions defined at column 0 in R/EDI/src."""
    out = {}
    for f, t in src_texts.items():
        for m in CPP_DEF.finditer(t):
            line = m.group(0)
            if line.rstrip().endswith(";") or line.startswith(("return", "if", "for", "while", "else")):
                continue
            out.setdefault(m.group(1), f)
    return out


def helper_names(text, offset):
    """For `m.def(name, ...)` inside a static helper, the literal names its callers pass."""
    head = text[:offset]
    m = None
    for m in re.finditer(r"^static\s+void\s+(\w+)\s*\(", head, re.M):
        pass
    if not m:
        return []
    names = []
    for c in re.finditer(r"\b" + re.escape(m.group(1)) + r"\s*\(\s*m\s*,", text):
        call = text[c.start():call_end(text, text.index("(", c.start()))]
        names += re.findall(r'"([a-z_][a-z0-9_]*)"', call)
    return names


def kernel_sources(cmake_text):
    return sorted(set(re.findall(r"\$\{EDI_SRC_DIR\}/([A-Za-z0-9_]+\.cpp)", cmake_text or "")))


# ---------------------------------------------------------------- units

def _scan(ctx):
    idx = ei.Index(ctx.repo)
    defs = cpp_definitions(idx.src)
    bodies = function_bodies(idx.src)
    export_names = set(idx.export_file)
    stub = stub_blocks(ctx.read(STUB) or "")
    out = []
    bdir = ctx.path(BIND_DIR)
    files = sorted(bdir.glob("bindings_*.cpp")) if bdir.is_dir() else []
    for p in files:
        rel = f"{BIND_DIR}/{p.name}"
        text = p.read_text(encoding="utf-8", errors="replace")
        seen = {}
        for b in bindings(text):
            key = f"{rel}::{b['name']}" if b["literal"] else f"{rel}::<{b['name']}>"
            seen[key] = seen.get(key, 0) + 1
            if seen[key] > 1:
                key = f"{key}#{seen[key]}"
            py_names = [b["name"]] if b["literal"] else helper_names(text, b["offset"])
            idents = set(re.findall(r"([A-Za-z_]\w{4,})", code_only(b["text"])))
            kernels = sorted({(n, defs[n]) for n in idents if n in defs and not n.startswith(("Eigen", "std"))})
            exports, done = [], set()

            def add(e, relation):
                if e in done or e not in idx.export_file:
                    return
                done.add(e)
                f = idx.export_file[e]
                exports.append({"export": e, "file": f, "relation": relation,
                                "signature": ei.export_signature(idx.src[f], e),
                                "rd": f"R/EDI/man/{e}.Rd" if ctx.path(f"R/EDI/man/{e}.Rd").exists() else ""})
            # The R twin by naming convention (fast_ols -> fast_ols_cpp), then any export that
            # reaches the same kernel within two calls.
            for n in py_names:
                for suffix in TWIN_SUFFIXES:
                    add(n + suffix, "same name")
            for n, _ in kernels:
                for e in exports_reaching(n, bodies, export_names, max_depth=2):
                    add(e, "calls the same kernel")
            callers = idx.callers([e["export"] for e in exports])
            tests = [f"python/tests/test_{n}.py" for n in py_names if ctx.path(f"python/tests/test_{n}.py").exists()]
            out.append({"id": key, "file": rel, "binding": b, "python_names": py_names,
                        "stub": "\n".join(stub[n] for n in py_names if n in stub),
                        "kernels": [{"function": n, "file": f} for n, f in kernels],
                        "exports": exports, "callers": callers, "tests": tests})
    return out


def function_bodies(src_texts):
    """{function name: [(src file, set of identifiers in its body)]} for column-0 definitions."""
    out = {}
    for f, t in src_texts.items():
        for m in CPP_DEF.finditer(t):
            line = m.group(0)
            if line.rstrip().endswith(";") or line.startswith(("return", "if", "for", "while", "else")):
                continue
            i = t.find("{", m.end())
            semi = t.find(";", m.end())
            if i < 0 or (0 <= semi < i and ")" in t[m.end():semi] and "(" not in t[semi:i]):
                continue
            depth, j = 0, i
            while j < len(t):
                if t[j] == "{":
                    depth += 1
                elif t[j] == "}":
                    depth -= 1
                    if depth == 0:
                        break
                j += 1
            out.setdefault(m.group(1), []).append((f, set(re.findall(r"[A-Za-z_]\w*(?=\s*\()", t[i:j]))))
    return out


def exports_reaching(kernel, bodies, export_names, max_depth=3):
    """Rcpp exports that call `kernel` directly or through at most `max_depth` - 1 other functions."""
    callers_of = {}
    for name, defs in bodies.items():
        for _, called in defs:
            for c in called:
                callers_of.setdefault(c, set()).add(name)
    found, frontier, seen = [], {kernel}, {kernel}
    for _ in range(max_depth):
        nxt = set()
        for n in frontier:
            for c in callers_of.get(n, ()):
                if c in seen:
                    continue
                seen.add(c)
                if c in export_names:
                    found.append(c)
                else:
                    nxt.add(c)
        frontier = nxt
    return sorted(found)


def push_event(event):
    """The event name the rotation helpers should see: any push-like event becomes "push"."""
    return "push" if event in PUSH_EVENTS else event


def units(ctx):
    out = {}
    for s in _scan(ctx):
        b = s["binding"]
        deps = ac.text_hash([e["signature"] for e in s["exports"]],
                            [l[1] for c in s["callers"] for l in c["lines"]])
        out[s["id"]] = {
            "hash": ac.text_hash(b["text"], s["stub"]),
            "deps": deps,
            "cycle_weeks": rot.unit_cycle(SPEC["cycle_weeks"], push_event(ctx.event)),
            "context": {
                "binding_file": s["file"], "binding_lines": [b["start_line"], b["end_line"]],
                "python_names": s["python_names"],
                "py_args": [{"name": n, "default": d or None} for n, d in py_args(b["text"])],
                "stub_file": STUB, "stub": s["stub"][:6000],
                "kernel_functions": s["kernels"],
                "r_exports": s["exports"],
                "r_callers": s["callers"],
                "python_tests": s["tests"],
            }}
    return out


# ---------------------------------------------------------------- mechanical

def mechanical(ctx):
    found = []
    init = ctx.read(INIT) or ""
    stub_text = ctx.read(STUB) or ""
    stub = stub_blocks(stub_text)
    for s in _scan(ctx):
        b = s["binding"]
        for n in s["python_names"]:
            if n not in stub:
                found.append({"unit": s["id"], "kind": "stub_missing",
                              "text": f"`{n}` is bound in `{s['file']}` but has no `def {n}(` in `{STUB}` "
                                      "(the stub is stale; regenerate it)."})
            if not re.search(r"\b" + re.escape(n) + r"\b", init):
                found.append({"unit": s["id"], "kind": "not_exported",
                              "text": f"`{n}` is bound in `{s['file']}` but `{INIT}` does not import it."})
        args = py_args(b["text"])
        for e in s["exports"]:
            if e["relation"] != "same name":
                continue
            rdef = cpp_defaults(e["signature"])
            for n, d in args:
                if n not in rdef or d is None:
                    continue
                pv, rv = norm_default(d), norm_default(rdef[n])
                if pv is None or rv is None or pv == rv:
                    continue
                found.append({"unit": s["id"], "kind": "default_mismatch",
                              "text": f"`{s['python_names'][0] if s['python_names'] else s['id']}({n} = {d})` "
                                      f"in `{s['file']}:{b['start_line']}` but its R twin "
                                      f"`{e['export']}({n} = {rdef[n]})` in `{e['file']}` has a different "
                                      f"default."})
    return found


# ---------------------------------------------------------------- apply

def _strip_escapes(s):
    return re.sub(r"\\.", "", s)


def literal_safe(s):
    """Text that can sit inside one C++ string literal: no newline, no unescaped quote, no
    trailing lone backslash."""
    if "\n" in s or "\r" in s:
        return False
    t = _strip_escapes(s)
    return '"' not in t and not t.endswith("\\")


def inside_cpp_literal(text, pos, length):
    """True when text[pos:pos+length] lies inside one string literal on a line that holds only
    string literal(s) (a docstring line of a binding)."""
    ls = text.rfind("\n", 0, pos) + 1
    le = text.find("\n", pos)
    le = len(text) if le < 0 else le
    if pos + length > le:
        return False
    line = text[ls:le]
    if not line.lstrip().startswith('"'):
        return False
    before = _strip_escapes(text[ls:pos])
    return before.count('"') % 2 == 1


def inside_py_docstring(text, pos, length):
    before = text[:pos]
    inside = (before.count('"""') % 2 == 1) or (before.count("'''") % 2 == 1)
    return inside and '"""' not in text[pos:pos + length] and "'''" not in text[pos:pos + length]


def check_fix(text, rel, old, new):
    """None if the docstring fix may be applied, else the reason it may not."""
    if not old or new is None or old == new:
        return "no old text, or no change"
    n = text.count(old)
    if n != 1:
        return f"the old text occurs {n} times in `{rel}` (must be exactly once)"
    pos = text.index(old)
    if rel.endswith(".cpp"):
        if not (literal_safe(old) and literal_safe(new)):
            return "the change is not confined to one string literal (newline or quote in the text)"
        if not inside_cpp_literal(text, pos, len(old)):
            return "the old text is not inside a docstring string literal"
    elif rel.endswith((".py", ".pyi")):
        if '"""' in new or "'''" in new:
            return "the new text would end the docstring"
        if not inside_py_docstring(text, pos, len(old)):
            return "the old text is not inside a docstring"
    else:
        return "only .cpp bindings and .py / .pyi files are edited"
    return None


def apply(ctx, results, mech):
    applied, human, proposed = [], [], []
    texts = {}

    def get(rel):
        if rel not in texts:
            texts[rel] = ctx.read(rel)
        return texts[rel]

    for r in results:
        for f in r.get("findings") or []:
            if not isinstance(f, dict):
                continue
            label = f"`{f.get('unit', '')}` ({f.get('kind', 'finding')}): {f.get('text', '').strip()}"
            fix = f.get("fix") or {}
            rel = (fix.get("file") or "").strip().lstrip("./")
            if f.get("kind") != "docstring" or not rel:
                human.append(label + (f" Suggested: {f['suggestion']}" if f.get("suggestion") else ""))
                proposed.append(f)
                continue
            if not rel.startswith("python/") or ".." in Path(rel).parts:
                human.append(f"{label} (not applied: the fix is outside python/)")
                proposed.append(f)
                continue
            text = get(rel)
            if text is None:
                human.append(f"{label} (not applied: `{rel}` not found)")
                proposed.append(f)
                continue
            old, new = fix.get("old_text") or "", fix.get("new_text")
            why = check_fix(text, rel, old, new)
            if why:
                human.append(f"{label} (not applied: {why})")
                proposed.append(f)
                continue
            texts[rel] = text.replace(old, new, 1)
            ctx.path(rel).write_text(texts[rel])
            note = ""
            if rel != STUB:
                stub = get(STUB)
                if stub is not None and stub.count(old) == 1 and check_fix(stub, STUB, old, new) is None:
                    texts[STUB] = stub.replace(old, new, 1)
                    ctx.path(STUB).write_text(texts[STUB])
                    note = f"; same change in `{STUB}`"
                elif stub is not None and old in stub:
                    note = f"; `{STUB}` not changed (the text occurs {stub.count(old)} times there), regenerate it"
            applied.append(f"`{rel}`: {label}{note}")
            proposed.append({**f, "applied_file": rel, "applied_text": new})
    n = sum(len(r.get("findings") or []) for r in results)
    return {"summary": f"{n} parity finding(s) from the agents; {len(applied)} docstring fix(es) applied.",
            "applied": applied, "mechanical": [m["text"] for m in mech], "human": human,
            "proposed": proposed}
