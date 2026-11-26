"""Message argument audit: argument names quoted in stop() / warning() / message() strings must exist.

Plan: v1.0.6-TODO-55 in R/package_metadata/future_release_plans/release_v1_0_6.md, following the
framework in R/package_metadata/new_feature_plans/v1_0_6/audit_jobs_framework.md. No Claude, no R:
the R sources are read with a small tokenizer here.

A message that tells the user to "set `equal_block_sizes = FALSE`" is wrong when the class they are
using has no such argument (v1.0.6-TODO-36: DesignFixedBlockedCluster inherits that message from the
BlockingStructure component, but its initialize() has no `equal_block_sizes`). This audit reads every
string literal inside a stop(), warning() or message() call in R/EDI/R/*.R and picks out the argument
names it quotes as `name = ...`:

- backticked: `` `name = FALSE` ``, `` `name=` ``;
- Rd markup: `\\code{name = ...}`;
- single or escaped double quotes: `'name = 3'`, `\\"name = x\\"`;
- bare advice: "Set name = FALSE", "pass name = ...", "use name = ...", "with name = ..." (the verb
  right before the name, any value);
- bare, with a literal value: "name = TRUE but ...", "(y_R = Inf)", "name = %d" (a value pasted in
  from a variable, "n = ", n, is not read: those mostly report internal quantities);
- an argument named as such: "argument `name`", "`name` argument", "the 'name' parameter".

Each name must be one of, for the code the message is in:
- a formal argument of the enclosing function (or of a function around it);
- for code in an R6 class (define_design_class, define_inference_class, R6Class): a formal of the
  class's initialize() (inherited through `...`), the name or a formal of a public method of the class,
  its parents or its components;
- for code in a component source (the DESIGN_*_PUBLIC / _PRIVATE lists, an inference component's
  source class): the same, checked for every exported class that composes the component, directly,
  through a component dependency, or by inheritance. A name only some of those classes take is
  reported with the classes that do not take it; that is the v1.0.6-TODO-36 case.
Code outside any class (a package-level helper) is checked against the formals of its own function
chain and, failing that, of the package-level functions that call it by name, since helpers often
validate an argument of their caller.

Also accepted, to keep false positives low: for a class built from a design object (an initialize()
formal `des_obj`), the exported design classes' arguments (an inference message may quote `prob_T` or
`y_R`); names the message itself writes as a list element (`solver_args$max_iter`); names inside an R
call written in the message (`suppressWarnings(expr, classes = ...)`, `options(EDI.x = 1)`); and R's
own arguments (`call.`, `na.rm`, ...). A bare "x = TRUE but ..." in code several classes share states
a value some of them set, so it is reported only when the message is advice (backticked, quoted,
or after "set" / "use" / "pass"...).

Not read: a backticked name with no `=` and no "argument" next to it (in EDI's messages these are
almost all metadata fields such as `required_packages`, not arguments), and a message held in a
variable first (`msg = paste0(...); stop(msg)`), about 40 of the ~870 calls.

Report: an issue (label `audit-message-args`), one decision per message and name, with a stable id
(`message-args-d<hex>`) so a false positive is dismissed the framework's way, by listing its id in
R/package_metadata/audits/DISMISSED_DECISIONS.md with a reason. Nothing is edited.
"""
import re
import sys
from pathlib import Path

if __name__ == "__main__":   # a local run: make audit_common importable
    sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import audit_common as ac  # noqa: E402

SPEC = {
    "name": "message-args",
    "title": "Message argument audit",
    "report": "issue",
    "claude": False,
}

R_DIR = "R/EDI/R"
NAMESPACE = "R/EDI/NAMESPACE"
MESSAGE_FUNS = {"stop", "warning", "message"}
CLASS_FUNS = {"define_design_class", "define_inference_class", "R6Class"}
DESIGN_REGISTRY = "design_component_registry.R"
# R's own argument names and words that read like `x = ...` but are never EDI arguments.
NEVER_ARGS = {"call.", "domain", "immediate.", "noBreaks.", "appendLF", "na.rm", "stringsAsFactors",
              "drop", "envir"}
ADVICE_VERBS = r"(?:[Ss]et|[Pp]ass|[Uu]se|[Ss]upply|[Pp]rovide|[Ss]pecify|[Ww]ith|[Cc]hoose|[Tt]ry|[Gg]ive|[Cc]all\s+\S+\s+with)"
IDENT = r"[A-Za-z][A-Za-z0-9._]*"
MAX_SHOWN = 15
DESIGN_FORMALS = {"des_obj", "design", "des"}   # an initialize() formal that takes a design object

NAME_PATTERNS = [
    ("backtick", re.compile(r"`(" + IDENT + r")\s*=(?!=)")),
    ("code", re.compile(r"\\code\{(" + IDENT + r")\s*=(?!=)")),
    ("quote", re.compile(r"(?:^|[^A-Za-z0-9_])['\"](" + IDENT + r")\s*=(?!=)")),
    ("advice", re.compile(r"\b" + ADVICE_VERBS + r"\s+(?:the\s+argument\s+)?(" + IDENT + r")\s*=(?!=)")),
    ("bare", re.compile(r"(?:^|(?<=[\s(,;:]))(" + IDENT + r") = (?=TRUE\b|FALSE\b|NULL\b|NA\b|Inf\b|-?\d|['\"]|%[dsgf])")),
    ("argument", re.compile(r"\b(?:argument|parameter|arg)s?\s+(?:\\code\{|[`'\"])(" + IDENT + r")[`'\"}]")),
    ("argument", re.compile(r"(?:\\code\{|[`'\"])(" + IDENT + r")[`'\"}]\s+(?:argument|parameter|arg)\b")),
]


# ---------------------------------------------------------------- tokenizer

class Tok:
    __slots__ = ("kind", "val", "line")

    def __init__(self, kind, val, line):
        self.kind, self.val, self.line = kind, val, line

    def __repr__(self):
        return f"Tok({self.kind},{self.val!r},{self.line})"


_RAW_OPEN = re.compile(r"[rR](['\"])(-*)([(\[{])")
_CLOSE = {"(": ")", "[": "]", "{": "}"}
_NUM = re.compile(r"(?:0[xX][0-9a-fA-F]+|\d+\.?\d*(?:[eE][+-]?\d+)?|\.\d+(?:[eE][+-]?\d+)?)[Li]?")
_ID = re.compile(r"[A-Za-z.][A-Za-z0-9._]*|\.\.\.")
_OPS = ["<<-", "->>", "%%", "|>", "<-", "->", "<=", ">=", "==", "!=", "&&", "||", "::", "\\"]


def _unescape(s):
    return re.sub(r"\\(.)", lambda m: {"n": "\n", "t": "\t"}.get(m.group(1), m.group(1)), s)


def tokenize(text):
    """R tokens: str (string value, escapes resolved), id, num, op, nl. Comments are dropped."""
    out, i, n, line = [], 0, len(text), 1
    while i < n:
        c = text[i]
        if c == "\n":
            out.append(Tok("nl", "\n", line))
            line += 1
            i += 1
        elif c in " \t\r\f":
            i += 1
        elif c == "#":
            j = text.find("\n", i)
            i = n if j < 0 else j
        elif c in "rR" and _RAW_OPEN.match(text, i):
            m = _RAW_OPEN.match(text, i)
            end = _CLOSE[m.group(3)] + m.group(2) + m.group(1)
            j = text.find(end, m.end())
            j = n if j < 0 else j
            val = text[m.end():j]
            out.append(Tok("str", val, line))
            line += val.count("\n")
            i = j + len(end)
        elif c in "\"'":
            j = i + 1
            while j < n and text[j] != c:
                j += 2 if text[j] == "\\" else 1
            raw = text[i + 1:j]
            out.append(Tok("str", _unescape(raw), line))
            line += raw.count("\n")
            i = j + 1
        elif c == "`":
            j = text.find("`", i + 1)
            j = n if j < 0 else j
            out.append(Tok("id", text[i + 1:j], line))
            i = j + 1
        elif c.isdigit() or (c == "." and i + 1 < n and text[i + 1].isdigit()):
            m = _NUM.match(text, i)
            out.append(Tok("num", m.group(0), line))
            i = m.end()
        elif c.isalpha() or c == ".":
            m = _ID.match(text, i)
            out.append(Tok("id", m.group(0), line))
            i = m.end()
        elif c == "%":
            j = text.find("%", i + 1)
            j = n if j < 0 or "\n" in text[i:j] else j
            out.append(Tok("op", text[i:j + 1], line))
            i = j + 1
        else:
            op = next((o for o in _OPS if text.startswith(o, i)), c)
            out.append(Tok("op", op, line))
            i += len(op)
    return out


def match_brackets(toks):
    """{index of an opening bracket: index of its closing bracket} ([[ counts as two ['s)."""
    pairs, stack = {}, []
    for k, t in enumerate(toks):
        if t.kind != "op":
            continue
        if t.val in "([{":
            stack.append(k)
        elif t.val in ")]}" and stack:
            pairs[stack.pop()] = k
    return pairs


# ---------------------------------------------------------------- structure

class Func:
    """A function literal: its formals and the token span of its body."""

    def __init__(self, name, formals, start, end, line):
        self.name, self.formals, self.start, self.end, self.line = name, formals, start, end, line


def _formals(toks, lo, hi):
    """Formal names between the parentheses toks[lo] .. toks[hi]."""
    out, depth, expect = [], 0, True
    for k in range(lo + 1, hi):
        t = toks[k]
        if t.kind == "nl":
            continue
        if t.kind == "op" and t.val in "([{":
            depth += 1
        elif t.kind == "op" and t.val in ")]}":
            depth -= 1
        elif depth == 0 and t.kind == "op" and t.val == ",":
            expect = True
            continue
        if depth == 0 and expect and t.kind == "id":
            out.append(t.val)
        expect = False
    return out


_CONTINUE_OPS = {"+", "-", "*", "/", "^", "<-", "=", "==", "!=", "<", ">", "<=", ">=", "&", "|", "&&", "||",
                 "~", "|>", ",", "$", "@", "::", "!", "?", ":"}


def _expr_end(toks, k, pairs):
    """Last token index of the expression that starts at k (a non-brace function body)."""
    j = k
    while j < len(toks):
        t = toks[j]
        if t.kind == "op" and t.val in "([{":
            j = pairs.get(j, len(toks) - 1) + 1
            continue
        if t.kind == "op" and (t.val in ")]}" or t.val == ","):
            return j - 1
        if t.kind == "nl":
            prev = next((toks[p] for p in range(j - 1, k - 1, -1) if toks[p].kind != "nl"), None)
            if prev is not None and not (prev.kind == "op" and (prev.val in _CONTINUE_OPS or prev.val.startswith("%"))):
                if not (prev.kind == "id" and prev.val in ("else",)):
                    nxt = next((toks[p] for p in range(j + 1, len(toks)) if toks[p].kind != "nl"), None)
                    if not (nxt is not None and nxt.kind == "id" and nxt.val == "else"):
                        return j - 1
        j += 1
    return len(toks) - 1


def _prev(toks, k):
    k -= 1
    while k >= 0 and toks[k].kind == "nl":
        k -= 1
    return k


def _next(toks, k):
    k += 1
    while k < len(toks) and toks[k].kind == "nl":
        k += 1
    return k


def functions(toks, pairs):
    """Every function literal (`function(...)` or `\\(...)`), with the name it is assigned to."""
    out = []
    for k, t in enumerate(toks):
        if not ((t.kind == "id" and t.val == "function") or (t.kind == "op" and t.val == "\\")):
            continue
        lo = _next(toks, k)
        if lo >= len(toks) or toks[lo].val != "(" or lo not in pairs:
            continue
        hi = pairs[lo]
        b = _next(toks, hi)
        if b >= len(toks):
            continue
        end = pairs.get(b, b) if toks[b].kind == "op" and toks[b].val == "{" else _expr_end(toks, b, pairs)
        name = None
        p = _prev(toks, k)
        if p >= 0 and toks[p].kind == "op" and toks[p].val in ("=", "<-", "<<-"):
            q = _prev(toks, p)
            if q >= 0 and toks[q].kind in ("id", "str"):
                name = toks[q].val
        out.append(Func(name, _formals(toks, lo, hi), b, end, t.line))
    return out


class Container:
    """A top-level object: an R6 class, a list literal (component source) or a function."""

    def __init__(self, name, kind, file, start, end, line):
        self.name, self.kind, self.file, self.start, self.end, self.line = name, kind, file, start, end, line
        self.parent = None
        self.components = []
        self.pub = Public()


def _call_args(toks, lo, hi, pairs):
    """{arg name: (first token, last token)} for named arguments of the call whose parentheses are lo..hi."""
    out, k = {}, _next(toks, lo)
    while k < hi:
        name = None
        n1 = _next(toks, k)
        if toks[k].kind in ("id", "str") and n1 < hi and toks[n1].kind == "op" and toks[n1].val == "=":
            name, k = toks[k].val, _next(toks, n1)
        vstart = k
        while k < hi and not (toks[k].kind == "op" and toks[k].val == ","):
            if toks[k].kind == "op" and toks[k].val in "([{":
                k = pairs.get(k, hi)
            k += 1
        if name:
            out[name] = (vstart, k - 1)
        k = _next(toks, k)
    return out


def _strings_in(toks, lo, hi):
    return [toks[k].val for k in range(lo, hi + 1) if toks[k].kind == "str"]


class Public:
    """What a `public = ...` slot (or a component list) holds: methods written in place, methods
    pinned from another class (`m = X$public_methods$m`), and whole lists spliced in
    (`c(X$public, list(...))`, `DESIGN_X_PUBLIC[c(...)]`)."""

    def __init__(self):
        self.methods = {}    # name -> formals
        self.refs = {}       # name -> (container, method)
        self.splices = []    # container names
        self.fields = set()


def _public_value(toks, a, b, pairs, out):
    """Read one value of a public slot (tokens a..b) into `out`."""
    cl = _call_of(toks, a, pairs)
    if cl and cl[0] == "list":
        for name, (x, y) in _call_args(toks, cl[1], cl[2], pairs).items():
            if toks[x].kind == "id" and toks[x].val == "function":
                p = _next(toks, x)
                out.methods[name] = _formals(toks, p, pairs[p]) if p in pairs else []
            elif (y - x == 4 and toks[x].kind == "id" and toks[x + 1].val == "$"
                  and toks[x + 2].val in ("public_methods", "public") and toks[x + 3].val == "$"):
                out.refs[name] = (toks[x].val, toks[x + 4].val)
            else:
                out.fields.add(name)
        return
    if cl and cl[0] == "c":
        k = _next(toks, cl[1])
        while k < cl[2]:
            start = k
            while k < cl[2] and not (toks[k].kind == "op" and toks[k].val == ","):
                if toks[k].kind == "op" and toks[k].val in "([{":
                    k = pairs.get(k, cl[2])
                k += 1
            _public_value(toks, start, k - 1, pairs, out)
            k = _next(toks, k)
        return
    if toks[a].kind == "id" and re.fullmatch(r"[A-Za-z.][A-Za-z0-9._]*", toks[a].val):
        nxt = a + 1
        if nxt > b or toks[nxt].val == "[" or (toks[nxt].val == "$" and nxt + 1 <= b
                                               and toks[nxt + 1].val in ("public", "public_methods")):
            out.splices.append(toks[a].val)


def _call_of(toks, k, pairs):
    """(function name, open paren index, close paren index) of a call starting at token k, or None."""
    j = k
    if toks[j].kind == "id" and j + 1 < len(toks) and toks[j + 1].val == "::":
        j += 2
    if j < len(toks) and toks[j].kind == "id":
        p = j + 1
        if p < len(toks) and toks[p].kind == "op" and toks[p].val == "(" and p in pairs:
            return toks[j].val, p, pairs[p]
    return None


def containers(toks, pairs, file):
    """Top-level assignments at bracket depth 0."""
    out, k = [], 0
    while k < len(toks):
        t = toks[k]
        if t.kind == "op" and t.val in "([{":
            # a top-level bare call / expression: skip it
            k = pairs.get(k, len(toks) - 1) + 1
            continue
        if t.kind in ("id", "str"):
            p = _next(toks, k)
            if p < len(toks) and toks[p].kind == "op" and toks[p].val in ("=", "<-"):
                v = _next(toks, p)
                if v >= len(toks):
                    break
                call = None if toks[v].val == "function" else _call_of(toks, v, pairs)
                if call:
                    fn, lo, hi = call
                    c = Container(t.val, "list" if fn == "list" else ("class" if fn in CLASS_FUNS else "call"),
                                  file, v, hi, t.line)
                    args = _call_args(toks, lo, hi, pairs)
                    if fn in CLASS_FUNS:
                        if "inherit" in args:
                            a = args["inherit"][0]
                            c.parent = toks[a].val if toks[a].kind == "id" else None
                        if "components" in args:
                            a, b = args["components"]
                            c.components = _strings_in(toks, a, b)
                        if "public" in args:
                            _public_value(toks, *args["public"], pairs, c.pub)
                    elif fn == "list":
                        if "public" in args:   # list(public = list(...), private = list(...))
                            _public_value(toks, *args["public"], pairs, c.pub)
                            c.kind = "source"
                        elif not re.search(r"_PRIVATE$", c.name):
                            _public_value(toks, v, hi, pairs, c.pub)
                    out.append(c)
                    k = hi + 1
                    continue
                if toks[v].kind == "id" and toks[v].val == "function":
                    lo = _next(toks, v)
                    if lo in pairs:
                        b = _next(toks, pairs[lo])
                        end = pairs.get(b, b) if toks[b].val == "{" else _expr_end(toks, b, pairs)
                        c = Container(t.val, "function", file, v, end, t.line)
                        out.append(c)
                        k = end + 1
                        continue
        k += 1
    return out


# ---------------------------------------------------------------- messages

def message_calls(toks, pairs):
    """[(token index of the call name, open, close)] for stop(), warning() and message()."""
    out = []
    for k, t in enumerate(toks):
        if t.kind == "id" and t.val in MESSAGE_FUNS and k + 1 < len(toks) and toks[k + 1].val == "(":
            p = _prev(toks, k)
            if p >= 0 and toks[p].kind == "op" and toks[p].val in ("$", "@"):
                continue
            if p >= 0 and toks[p].val == "::" and toks[p - 1].val != "base":
                continue
            if k + 1 in pairs:
                out.append((k, k + 1, pairs[k + 1]))
    return out


def _inside_call(text, pos):
    """True when `pos` sits inside the parentheses of an R call written in the message, e.g.
    `suppressWarnings(expr, classes = ...)` or `options(EDI.x = 1)`: those name another function's
    arguments."""
    depth = 0
    for i in range(pos - 1, -1, -1):
        c = text[i]
        if c == ")":
            depth += 1
        elif c == "(":
            if depth == 0:
                return i > 0 and (text[i - 1].isalnum() or text[i - 1] in "._")
            depth -= 1
        elif c == "\n":
            return False
    return False


def quoted_names(strings):
    """[(name, how)] quoted as arguments in the message strings, in order, once each."""
    text = "".join(strings)
    seen, out = set(), []
    for how, pat in NAME_PATTERNS:
        for m in pat.finditer(text):
            if m.group(1) in NEVER_ARGS:
                continue
            nm = m.group(1).rstrip(".")
            st = m.start(1)
            if st > 0 and text[st - 1] in "$@":
                continue    # a list element (solver_args$brt_solver = ...), not an argument
            if _inside_call(text, st):
                continue
            if re.search(r"[$@]" + re.escape(nm) + r"\b", text):
                continue    # the message names it as a list element elsewhere (solver_args$x)
            if nm and nm not in seen and nm not in NEVER_ARGS:
                seen.add(nm)
                out.append((nm, how))
    return out


# ---------------------------------------------------------------- the model of the package

class Package:
    def __init__(self, repo, files=None):
        self.repo = Path(repo)
        self.files = files if files is not None else sorted(
            p.relative_to(self.repo).as_posix() for p in (self.repo / R_DIR).glob("*.R"))
        self.toks, self.pairs, self.funcs, self.conts = {}, {}, {}, {}
        self.by_name = {}
        for f in self.files:
            text = (self.repo / f).read_text(encoding="utf-8", errors="replace")
            toks = tokenize(text)
            pairs = match_brackets(toks)
            self.toks[f], self.pairs[f] = toks, pairs
            self.funcs[f] = functions(toks, pairs)
            self.conts[f] = containers(toks, pairs, f)
            for c in self.conts[f]:
                self.by_name[c.name] = c    # the last definition wins, as in R
        ns = self.repo / NAMESPACE
        self.exported = set(re.findall(r"^export\(([^)]+)\)", ns.read_text(), re.M)) if ns.exists() else set()
        self.component_sources = {}   # component name -> [container names]
        self.component_deps = {}      # component name -> [component names]
        self._read_design_components()
        self._read_inference_components()
        self.children = {}
        for c in self.by_name.values():
            if c.kind == "class" and c.parent:
                self.children.setdefault(c.parent, []).append(c.name)
        self._callers = None
        self._design_surface = None
        self._public_cache, self._surface_cache = {}, {}

    # components ---------------------------------------------------------

    def _read_design_components(self):
        f = f"{R_DIR}/{DESIGN_REGISTRY}"
        if f not in self.toks:
            return
        toks, pairs = self.toks[f], self.pairs[f]
        for k, t in enumerate(toks):
            if t.kind == "id" and t.val == "DesignComponent" and k + 1 < len(toks) and toks[k + 1].val == "(":
                lo, hi = k + 1, pairs.get(k + 1)
                if hi is None:
                    continue
                args = _call_args(toks, lo, hi, pairs)
                if "name" not in args:
                    continue
                name = toks[args["name"][0]].val
                srcs = sorted({toks[j].val for j in range(lo, hi) if toks[j].kind == "id"
                               and re.fullmatch(r"DESIGN_[A-Z0-9_]+", toks[j].val)})
                self.component_sources[name] = srcs
                if "dependencies" in args:
                    a, b = args["dependencies"]
                    self.component_deps[name] = _strings_in(toks, a, b)

    def _read_inference_components(self):
        spec = self.by_name.get("EDI_COMPONENT_SPECS")
        if not spec:
            return
        toks, pairs = self.toks[spec.file], self.pairs[spec.file]
        call = _call_of(toks, spec.start, pairs)
        if not call:
            return
        for name, (a, b) in _call_args(toks, call[1], call[2], pairs).items():
            cl = _call_of(toks, a, pairs)
            if not cl or cl[0] != "list":
                continue
            args = _call_args(toks, cl[1], cl[2], pairs)
            src = toks[args["source_name"][0]].val if "source_name" in args else name
            self.component_sources[name] = [src]
            if "dependencies" in args:
                self.component_deps[name] = _strings_in(toks, *args["dependencies"])

    def components_of(self, cls):
        """Every component a class has: its own, its parents', and their dependencies."""
        names, c, guard = [], self.by_name.get(cls), 0
        while c is not None and guard < 50:
            names += c.components
            c, guard = self.by_name.get(c.parent) if c.parent else None, guard + 1
        out, todo = [], list(names)
        while todo:
            x = todo.pop()
            if x in out:
                continue
            out.append(x)
            todo += self.component_deps.get(x, [])
        return out

    def hosts_of_source(self, cont_name):
        """Classes that compose a component whose source is this container."""
        comps = {c for c, srcs in self.component_sources.items() if cont_name in srcs}
        if not comps:
            return []
        return sorted(n for n, c in self.by_name.items() if c.kind == "class" and set(self.components_of(n)) & comps)

    # the names a class accepts ----------------------------------------

    def ancestors(self, cls):
        out, c = [], self.by_name.get(cls)
        while c is not None and c.parent and len(out) < 50:
            out.append(c.parent)
            c = self.by_name.get(c.parent)
        return out

    def public_of(self, name, seen=None):
        """{method: formals} of a container's public slot, splices and pinned methods resolved (its
        parents' methods not included)."""
        if name in self._public_cache:
            return self._public_cache[name]
        seen = set() if seen is None else seen
        c = self.by_name.get(name)
        if c is None or name in seen:
            return {}
        seen.add(name)
        out = {}
        for sp in c.pub.splices:
            out.update(self.public_of(sp, seen))
        out.update(c.pub.methods)
        for m, (src, sm) in c.pub.refs.items():
            for n in [src] + self.ancestors(src):
                fm = self.public_of(n, seen).get(sm)
                if fm is not None:
                    out[m] = fm
                    break
            else:
                out[m] = []
        self._public_cache[name] = out
        return out

    def init_formals(self, cls):
        out, n, guard = set(), cls, 0
        while n and guard < 50:
            guard += 1
            fm = self.public_of(n).get("initialize")
            if fm is not None:
                out |= set(fm)
                if "..." not in fm:
                    break
            c = self.by_name.get(n)
            n = c.parent if c is not None else None
        out.discard("...")
        return out

    def surface(self, cls):
        """Names a user of this class can pass or call: initialize formals, public method names and
        their formals, through parents and components."""
        if cls in self._surface_cache:
            return self._surface_cache[cls]
        out = set(self.init_formals(cls))
        names = [cls] + self.ancestors(cls)
        for comp in self.components_of(cls):
            for s in self.component_sources.get(comp, []):
                names += [s] + self.ancestors(s)
        for n in names:
            for m, fm in self.public_of(n).items():
                out.add(m)
                out |= set(fm)
        out.discard("...")
        self._surface_cache[cls] = out
        return out

    def descendants(self, cls):
        out, todo = [], list(self.children.get(cls, []))
        while todo:
            x = todo.pop()
            if x not in out:
                out.append(x)
                todo += self.children.get(x, [])
        return out

    # package-level helpers -------------------------------------------

    def hosts_of_container(self, cont):
        """The classes whose users can see a message written inside `cont`: a class and its
        descendants, plus, for a component source (a DESIGN_* list or an inference component's
        source class), every class that composes the component."""
        if cont is None or cont.kind == "function":
            return []
        hosts = set(self.hosts_of_source(cont.name))
        if cont.kind == "class":
            hosts |= {cont.name, *self.descendants(cont.name)}
        return sorted(hosts)

    def allowed_in_class(self, cls):
        """What a message reached from class `cls` may quote: its surface, plus the design classes'
        surfaces when the class is built from a design (an inference class quotes prob_T or y_R)."""
        out = set(self.surface(cls))
        if out & DESIGN_FORMALS:
            out |= self.design_surface()
        return out

    def design_surface(self):
        if self._design_surface is None:
            self._design_surface = set()
            for n in sorted(self.exported):
                if n.startswith(("Design", "ObservationalDesign")) and n in self.by_name:
                    self._design_surface |= self.surface(n)
        return self._design_surface

    def callers_allowed(self, fname, depth=3, seen=None):
        """For a package-level helper: the formals of every function that calls it by name and, when
        that call sits inside a class or component, what that class accepts (helpers often check an
        argument of their caller). A caller that is itself a package-level helper is followed up to
        `depth` levels."""
        if self._callers is None:
            self._callers = {}
            for f in self.files:
                toks = self.toks[f]
                for fn in self.funcs[f]:
                    for j in range(fn.start, min(fn.end, len(toks) - 2) + 1):
                        if toks[j].kind == "id" and toks[j + 1].val == "(":
                            self._callers.setdefault(toks[j].val, []).append((f, fn, j))
        seen = set() if seen is None else seen
        if fname in seen:
            return set()
        seen.add(fname)
        out = set()
        for f, fn, j in self._callers.get(fname, []):
            out |= set(fn.formals)
            cont = _container_at(self.conts[f], j)
            for h in self.hosts_of_container(cont):
                out |= self.allowed_in_class(h)
            if depth > 1 and cont is not None and cont.kind == "function":
                out |= self.callers_allowed(cont.name, depth - 1, seen)
        out.discard("...")
        return out


def _enclosing(funcs, k):
    """Functions whose body contains token k, outermost first."""
    return sorted((f for f in funcs if f.start <= k <= f.end), key=lambda f: f.start)


def _container_at(conts, k):
    return next((c for c in conts if c.start <= k <= c.end), None)


def findings(repo, files=None):
    """[{file, line, call, function, name, how, owner, missing_in, n_checked, some}] for every quoted
    argument name the code around its message does not accept."""
    pkg = Package(repo, files)
    out = []
    for f in pkg.files:
        toks, pairs = pkg.toks[f], pkg.pairs[f]
        for k, lo, hi in message_calls(toks, pairs):
            names = quoted_names(_strings_in(toks, lo, hi))
            if not names:
                continue
            chain = _enclosing(pkg.funcs[f], k)
            local = set().union(*(fn.formals for fn in chain)) if chain else set()
            cont = _container_at(pkg.conts[f], k)
            fname = next((fn.name for fn in reversed(chain) if fn.name), None)
            hosts = pkg.hosts_of_container(cont)
            check = [h for h in hosts if h in pkg.exported] or hosts
            row = {"file": f, "line": toks[k].line, "call": toks[k].val, "function": fname,
                   "owner": cont.name if cont else None}
            for nm, how in names:
                if nm in local:
                    continue
                if check:
                    missing = [h for h in check if nm not in pkg.allowed_in_class(h)]
                    if not missing:
                        continue
                    some = len(missing) < len(check)
                    if some and how == "bare":
                        # "x = TRUE but ..." in shared code states the value some classes set; only
                        # advice to set it is wrong for the classes that cannot.
                        continue
                    out.append({**row, "name": nm, "how": how, "missing_in": missing,
                                "n_checked": len(check), "some": some})
                else:
                    top = cont.name if cont is not None else fname
                    names_ok = pkg.callers_allowed(top) | (pkg.callers_allowed(fname) if fname else set())
                    if nm in names_ok:
                        continue
                    out.append({**row, "name": nm, "how": how, "missing_in": [], "n_checked": 0, "some": False})
    return out


def describe(x):
    where = f"`{x['file']}:{x['line']}`"
    fn = f" in `{x['function']}()`" if x["function"] else ""
    owner = f" of `{x['owner']}`" if x["owner"] and x["owner"] != x["function"] else ""
    head = f"{where}{fn}{owner}: the {x['call']}() message quotes `{x['name']}`"
    if not x["missing_in"]:
        return head + ", which is not an argument of that function (nor of the functions that call it)."
    m = x["missing_in"]
    shown = ", ".join(f"`{c}`" for c in m[:MAX_SHOWN]) + (f" and {len(m) - MAX_SHOWN} more" if len(m) > MAX_SHOWN else "")
    if x["some"]:
        return head + (f", but {len(m)} of the {x['n_checked']} exported classes built from this code take no "
                       f"such argument: {shown}.")
    return head + f", which is not an argument or public method of {shown}."


# ---------------------------------------------------------------- stages

def mechanical(ctx):
    return []


def apply(ctx, results, mech):
    found = findings(ctx.repo)
    human = []
    for x in sorted(found, key=lambda x: (x["file"], x["line"], x["name"])):
        unit = f"{x['file']}::{x['function'] or x['owner'] or '?'}::{x['name']}"
        human.append(ac.decision(describe(x), unit=unit, key="unknown-argument"))
    n_files = len(list(Path(ctx.repo, R_DIR).glob("*.R")))
    summary = (f"Read the stop(), warning() and message() calls in {n_files} files under `{R_DIR}`: "
               f"{len(found)} quoted argument name(s) that the code reaching the message does not accept. "
               "A message that tells the user to set an argument the class does not take fails when they "
               "follow it (v1.0.6-TODO-36). Nothing is edited. A false positive is dismissed by listing its "
               "id in `R/package_metadata/audits/DISMISSED_DECISIONS.md` with the reason.")
    return {"summary": summary, "applied": [], "mechanical": [], "human": human, "proposed": []}


if __name__ == "__main__":   # local run: python3 .github/scripts/audits/message_args.py [repo]
    for x in findings(sys.argv[1] if len(sys.argv) > 1 else "."):
        print(describe(x))
