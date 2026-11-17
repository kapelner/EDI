"""Index of EDI's sources shared by the code-review audits (numerical-robustness, thread-rng,
rpy-parity, compiled-code). Not an audit: the leading underscore keeps it out of the module
checks in test_audit_common.py.

The agents have no shell, so everything they would otherwise grep for is worked out here, once
per run: which Rcpp exports each C++ file defines, which R files call them (with line numbers),
which R6 classes those R files define, and which test files mention any of those names.
Stdlib only; reads the work tree, never builds anything.
"""
import re
import subprocess
from pathlib import Path

SRC = "R/EDI/src"
RDIR = "R/EDI/R"
TEST_DIRS = ("R/EDI/tests/testthat", "R/package_tests/testthat_bulk")
SKIP_SRC = {"RcppExports.cpp", "RcppExports.h", "build_info.cpp"}

EXPORT_RE = re.compile(r"^//\s*\[\[Rcpp::export(?:\(([^)]*)\))?\]\]\s*$", re.M)
NAME_BEFORE_PAREN = re.compile(r"([A-Za-z_]\w*)\s*\($")
CLASS_RE = re.compile(r"^([A-Z]\w*)\s*(?:=|<-)\s*(?:define_\w+_class|R6::R6Class|R6Class)\(", re.M)
INCLUDE_RE = re.compile(r'^\s*#\s*include\s+"([^"]+)"', re.M)
IDENT_RE = re.compile(r"[A-Za-z_.][A-Za-z0-9_.]*")


def _read(path):
    try:
        return Path(path).read_text(encoding="utf-8", errors="replace")
    except OSError:
        return ""


def rcpp_exports(text):
    """Names of the functions a C++ file exports with // [[Rcpp::export]], in file order.
    An explicit export name (`// [[Rcpp::export(name = "x")]]` or `(x)`) wins."""
    names = []
    for m in EXPORT_RE.finditer(text):
        explicit = (m.group(1) or "").strip()
        if explicit:
            e = re.search(r'name\s*=\s*"([^"]+)"', explicit) or re.match(r'"?([A-Za-z_.][\w.]*)"?$', explicit)
            if e:
                names.append(e.group(1))
                continue
        sig = ""
        for line in text[m.end():].splitlines()[1:8]:
            sig += " " + line.strip()
            if "(" in line:
                break
        head = sig.split("(")[0].strip() + "("
        n = NAME_BEFORE_PAREN.search(head)
        if n:
            names.append(n.group(1))
    return names


def export_signature(text, name):
    """The text of an export's signature, from its name to the opening brace (max 40 lines)."""
    m = re.search(r"^[^\n;]*\b" + re.escape(name) + r"\s*\(", text, re.M)
    if not m:
        return ""
    lines = text[m.start():].splitlines()
    out = []
    for line in lines[:40]:
        out.append(line)
        if "{" in line:
            break
    return "\n".join(out).split("{")[0].rstrip()


def r_classes(text):
    return CLASS_RE.findall(text)


def line_hits(text, names, max_hits=None):
    """(line number, stripped line) for each line of `text` that names one of `names` as a call."""
    if not names:
        return []
    pat = re.compile(r"(?<![A-Za-z0-9_.])(" + "|".join(map(re.escape, sorted(names, key=len, reverse=True)))
                     + r")\s*\(")
    hits = []
    for i, line in enumerate(text.splitlines(), 1):
        s = line.strip()
        if s.startswith(("#", "//")):
            continue
        if pat.search(line):
            hits.append((i, s[:200]))
            if max_hits and len(hits) >= max_hits:
                break
    return hits


def git_log(repo, path, n=5):
    r = subprocess.run(["git", "log", f"-{n}", "--format=%h %ad %s", "--date=short", "--", path],
                       cwd=repo, capture_output=True, text=True)
    return [l for l in r.stdout.splitlines() if l] if r.returncode == 0 else []


class Index:
    """One pass over R/EDI/src, R/EDI/R and the test directories."""

    def __init__(self, repo):
        self.repo = Path(repo)
        self.src = {}        # "R/EDI/src/x.cpp" -> text
        self.r = {}          # "R/EDI/R/x.R" -> text
        self.tests = {}      # test file -> set of identifiers
        self.exports = {}    # src file -> [export names]
        self.export_file = {}
        self.classes = {}    # R file -> [class names]
        self.r_idents = {}   # R file -> set of identifiers
        d = self.repo / SRC
        if d.is_dir():
            for p in sorted(d.iterdir()):
                if p.suffix in (".cpp", ".h", ".hpp") and p.name not in SKIP_SRC and not p.name.startswith("unity_"):
                    rel = f"{SRC}/{p.name}"
                    self.src[rel] = _read(p)
                    ex = rcpp_exports(self.src[rel])
                    self.exports[rel] = ex
                    for e in ex:
                        self.export_file.setdefault(e, rel)
        d = self.repo / RDIR
        if d.is_dir():
            for p in sorted(d.glob("*.R")):
                if p.name == "RcppExports.R":     # generated wrappers: they "call" every export
                    continue
                rel = f"{RDIR}/{p.name}"
                t = _read(p)
                self.r[rel] = t
                self.classes[rel] = r_classes(t)
                self.r_idents[rel] = set(IDENT_RE.findall(t))
        for td in TEST_DIRS:
            d = self.repo / td
            if d.is_dir():
                for p in sorted(d.glob("test-*.R")):
                    self.tests[f"{td}/{p.name}"] = set(IDENT_RE.findall(_read(p)))

    def includes(self, src_rel):
        """Local headers a source file includes (those that exist in R/EDI/src)."""
        out = []
        for h in INCLUDE_RE.findall(self.src.get(src_rel, "")):
            rel = f"{SRC}/{Path(h).name}"
            if rel in self.src:
                out.append(rel)
        return out

    def includers(self, header_rel):
        name = Path(header_rel).name
        return [f for f, t in self.src.items() if f != header_rel and re.search(
            r'#\s*include\s+"(?:[^"]*/)?' + re.escape(name) + '"', t)]

    def callers(self, names, max_files=25, max_lines=6):
        """R files that call any of `names`: [{"file", "lines": [[n, text], ...]}]."""
        names = set(names)
        out = []
        for f, idents in self.r_idents.items():
            if not (idents & names):
                continue
            hits = line_hits(self.r[f], names, max_lines)
            if hits:
                out.append({"file": f, "lines": [list(h) for h in hits]})
        out.sort(key=lambda c: (-len(c["lines"]), c["file"]))
        return out[:max_files]

    def cpp_calls_in_r(self, r_rel):
        """Rcpp exports an R file calls: {export: defining src file}."""
        idents = self.r_idents.get(r_rel, set())
        return {e: f for e, f in self.export_file.items() if e in idents}

    def tests_naming(self, names, max_files=40):
        names = set(n for n in names if n)
        if not names:
            return []
        hits = [f for f, idents in self.tests.items() if idents & names]
        return hits[:max_files]

    def classes_in(self, files):
        out = []
        for f in files:
            out += self.classes.get(f, [])
        return sorted(set(out))
