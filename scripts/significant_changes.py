#!/usr/bin/env python3
"""Changed files, minus source files whose only edits are comments or whitespace.

Every gate that asks "did R or C++ code change?" (scripts/pre-push, the CI
change gates in R-CMD-check.yaml, nightly.yml, test-coverage-R*.yaml,
test-bulk-non-cran.yml, .github/scripts/benchmark_gate.py,
R/package_tests/ci/select_pr_coverage_tests.py, the results-freshness audit,
merge_comprehensive_slice_results.R's same-source check) goes through this
file, so that a comment or whitespace edit never counts as a code change
(owner ruling 2026-11-17).

A changed file is dropped from the list only when it is an R, C/C++ or Python
source that exists on both sides and whose two versions are identical once
comments are removed and whitespace is normalized:

  R (.R .r)        `#` comments (roxygen `#'` included) removed; strings,
                   raw strings r"(...)" and backtick names kept verbatim.
                   Newlines inside ( ) and [ ] are whitespace; elsewhere a
                   newline ends a statement, so one is kept except after an
                   operator, comma or opening bracket, or before a closing
                   brace (re-wrapping a call or a line never counts).
  C/C++            // and /* */ comments removed, except `// [[Rcpp::...]]`
  (.c .cc .cpp     attributes, which change RcppExports and so are code.
   .cxx .h .hh     Strings, char literals and raw strings R"d(...)d" kept
   .hpp)           verbatim; a preprocessor directive keeps its line end.
  Python (.py)     compared token by token (tokenize), without COMMENT and
                   NL tokens and with indentation compared by structure.

Whitespace between two identifier characters, or between two operator
characters (`a - -b` is not `a --b`), collapses to one space; all other
whitespace outside strings is dropped. Every other file -- docs, Rd, build
files, data, a source file added, deleted or renamed, or one that cannot be
read or lexed -- counts as changed whenever git says it changed: when in
doubt, a file counts.

Roxygen comments are comments here. A roxygen-only edit still reaches the
checks that need it through the regenerated man/*.Rd and NAMESPACE files it
produces (which are not filtered), and gates that are ABOUT comments (the
pre-push roxygen check, its doc-link check, the source-comment-rot audit)
read git's own unfiltered diff.

CLI:
  significant_changes.py [-C DIR] [--diff-filter F] [--report-ignored]
                         BASE [HEAD] [-- PATHSPEC...]

BASE..HEAD as in `git diff --name-only BASE HEAD`; `BASE...HEAD` (one
argument) diffs from their merge base. Without HEAD the work tree is
compared, as `git diff BASE` does. Prints one path per line; with
--report-ignored also lists the dropped paths on stderr. Exits 2 if git
fails, so callers can fail open.
"""
from __future__ import annotations

import io
import os
import subprocess
import sys
import tokenize

R_EXT = (".R", ".r")
CPP_EXT = (".c", ".cc", ".cpp", ".cxx", ".h", ".hh", ".hpp")
PY_EXT = (".py",)
SOURCE_EXT = R_EXT + CPP_EXT + PY_EXT

OPERATOR_CHARS = set("+-*/%<>=!&|^~:?@$")
R_CONTINUES_AFTER = OPERATOR_CHARS | set(",([{")


class GitError(RuntimeError):
    pass


def _is_word(c: str) -> bool:
    return c.isalnum() or c in "_." or ord(c) > 127


def _need_space(prev: str, nxt: str) -> bool:
    return (_is_word(prev) and _is_word(nxt)) or (prev in OPERATOR_CHARS and nxt in OPERATOR_CHARS)


class _Out:
    """Accumulates normalized text: whitespace is pending until the next real character."""

    def __init__(self):
        self.parts: list[str] = []
        self.prev = ""          # last character emitted
        self.space = False      # whitespace seen since `prev`
        self.newline = False    # a significant newline seen since `prev`

    def ws(self, newline=False):
        self.space = True
        self.newline = self.newline or newline

    def force_newline(self):
        if self.prev and self.prev != "\n":
            self.parts.append("\n")
            self.prev = "\n"
        self.space = self.newline = False

    def emit(self, text: str, keep_newline=None):
        """Emit code text. keep_newline(prev, first_char) decides whether a pending newline survives."""
        if not text:
            return
        if self.prev and (self.space or self.newline):
            if self.newline and keep_newline is not None and keep_newline(self.prev, text[0]):
                self.parts.append("\n")
            elif self.space and _need_space(self.prev, text[0]):
                self.parts.append(" ")
        self.space = self.newline = False
        self.parts.append(text)
        self.prev = text[-1]

    def text(self) -> str:
        return "".join(self.parts).strip("\n")


def _read_quoted(src: str, i: int, quote: str) -> int:
    """Index just past the closing quote of a backslash-escaped literal starting at src[i]."""
    j, n = i + 1, len(src)
    while j < n:
        c = src[j]
        if c == "\\":
            j += 2
            continue
        if c == quote:
            return j + 1
        j += 1
    return n


def normalize_r(src: str) -> str:
    out = _Out()
    stack: list[str] = []
    i, n = 0, len(src)

    def keep_newline(prev, nxt):
        if stack and stack[-1] in "([":
            return False
        return prev not in R_CONTINUES_AFTER and prev != "\n" and nxt not in "}{"

    while i < n:
        c = src[i]
        if c == "#":
            while i < n and src[i] != "\n":
                i += 1
            continue
        if c == "\n":
            out.ws(newline=True)
            i += 1
            continue
        if c.isspace():
            out.ws()
            i += 1
            continue
        # raw string: r"(...)", R'--[...]--', r"{...}"
        if c in "rR" and i + 2 < n and src[i + 1] in "\"'" and (i == 0 or not _is_word(src[i - 1])):
            j = i + 2
            while j < n and src[j] == "-":
                j += 1
            if j < n and src[j] in "([{":
                close = {"(": ")", "[": "]", "{": "}"}[src[j]] + src[i + 2:j] + src[i + 1]
                end = src.find(close, j + 1)
                end = n if end < 0 else end + len(close)
                out.emit(src[i:end], keep_newline)
                i = end
                continue
        if c in "\"'`":
            end = _read_quoted(src, i, c)
            out.emit(src[i:end], keep_newline)
            i = end
            continue
        if c in "([{":
            out.emit(c, keep_newline)
            stack.append(c)
        elif c in ")]}":
            out.emit(c, keep_newline)
            if stack:
                stack.pop()
        else:
            out.emit(c, keep_newline)
        i += 1
    return out.text()


_CPP_RAW_PREFIXES = ("R", "u8R", "uR", "UR", "LR")


def _ident_before(src: str, i: int) -> str:
    j = i
    while j > 0 and (src[j - 1].isalnum() or src[j - 1] == "_"):
        j -= 1
    return src[j:i]


def normalize_cpp(src: str) -> str:
    out = _Out()
    i, n = 0, len(src)
    line_start = True       # only whitespace seen on this line so far (outside comments)
    in_directive = False
    while i < n:
        c = src[i]
        if c == "\\" and i + 1 < n and src[i + 1] == "\n":   # line continuation
            out.ws()
            i += 2
            continue
        if c == "\n":
            if in_directive:
                out.force_newline()
                in_directive = False
            else:
                out.ws()
            line_start = True
            i += 1
            continue
        if c.isspace():
            out.ws()
            i += 1
            continue
        if src.startswith("//", i):
            end = src.find("\n", i)
            end = n if end < 0 else end
            body = src[i:end]
            if "[[Rcpp::" in body:
                out.force_newline()
                out.emit("//" + " ".join(body[2:].split()))
                out.force_newline()
            else:
                out.ws()
            i = end
            continue
        if src.startswith("/*", i):
            end = src.find("*/", i + 2)
            i = n if end < 0 else end + 2
            out.ws()
            continue
        if c == "#" and line_start:
            out.force_newline()
            in_directive = True
        line_start = False
        if c == '"':
            prefix = _ident_before(src, i)
            if prefix in _CPP_RAW_PREFIXES:
                paren = src.find("(", i + 1)
                if paren > 0 and paren - i - 1 <= 16 and "\n" not in src[i + 1:paren]:
                    close = ")" + src[i + 1:paren] + '"'
                    end = src.find(close, paren + 1)
                    end = n if end < 0 else end + len(close)
                    out.emit(src[i:end])
                    i = end
                    continue
            end = _read_quoted(src, i, '"')
            out.emit(src[i:end])
            i = end
            continue
        if c == "'":
            word = _ident_before(src, i)
            # digit separator (1'000'000), not a character literal
            if word[:1].isdigit() and i + 1 < n and src[i + 1].isalnum():
                out.emit(c)
                i += 1
                continue
            end = _read_quoted(src, i, "'")
            out.emit(src[i:end])
            i = end
            continue
        out.emit(c)
        i += 1
    return out.text()


def normalize_python(src: str) -> str:
    toks = []
    for tok in tokenize.generate_tokens(io.StringIO(src).readline):
        if tok.type in (tokenize.COMMENT, tokenize.NL, tokenize.ENDMARKER):
            continue
        if tok.type == tokenize.INDENT:
            toks.append("<INDENT>")
        elif tok.type == tokenize.DEDENT:
            toks.append("<DEDENT>")
        elif tok.type == tokenize.NEWLINE:
            toks.append("<NEWLINE>")
        else:
            toks.append(tok.string)
    return "\x00".join(toks)


def normalize(path: str, src: str) -> str | None:
    """Comment- and whitespace-free form of a source file, or None if `path` is not a source type."""
    if path.endswith(R_EXT):
        return normalize_r(src)
    if path.endswith(CPP_EXT):
        return normalize_cpp(src)
    if path.endswith(PY_EXT):
        return normalize_python(src)
    return None


def same_code(path: str, old: str | None, new: str | None) -> bool:
    """True when both versions exist and differ only in comments/whitespace."""
    if old is None or new is None or not path.endswith(SOURCE_EXT):
        return False
    try:
        return normalize(path, old) == normalize(path, new)
    except Exception:  # an unlexable file counts as changed
        return False


# ---------------------------------------------------------------- git plumbing

def _git(repo, *args, text=True):
    r = subprocess.run(["git", "-C", str(repo), *args], capture_output=True, text=text)
    if r.returncode:
        err = r.stderr if text else r.stderr.decode("utf-8", "replace")
        raise GitError(f"git {' '.join(args)}: {err.strip()}")
    return r.stdout


def resolve_range(repo, base: str, head: str | None):
    """Split 'A...B' into (merge-base, B); otherwise return (base, head) unchanged."""
    if head is None and "..." in base:
        a, b = base.split("...", 1)
        mb = _git(repo, "merge-base", a or "HEAD", b or "HEAD").strip()
        return mb, (b or "HEAD")
    return base, head


def changed_paths(repo, base: str, head: str | None, pathspecs=(), diff_filter: str | None = None):
    """Every path git reports as changed (renames split into delete + add)."""
    args = ["diff", "--name-only", "--no-renames", "-z"]
    if diff_filter:
        args.append(f"--diff-filter={diff_filter}")
    args.append(base)
    if head is not None:
        args.append(head)
    args.append("--")
    args.extend(pathspecs)
    return [p for p in _git(repo, *args).split("\0") if p]


class _BlobReader:
    def __init__(self, repo):
        self.repo = repo
        self.proc = None

    def read(self, rev: str, path: str) -> str | None:
        if self.proc is None:
            self.proc = subprocess.Popen(["git", "-C", str(self.repo), "cat-file", "--batch"],
                                         stdin=subprocess.PIPE, stdout=subprocess.PIPE)
        self.proc.stdin.write(f"{rev}:{path}\n".encode())
        self.proc.stdin.flush()
        header = self.proc.stdout.readline().decode()
        parts = header.split()
        if len(parts) != 3 or parts[1] != "blob":
            return None
        size = int(parts[2])
        data = self.proc.stdout.read(size)
        self.proc.stdout.read(1)  # trailing newline
        return data.decode("utf-8", "replace")

    def close(self):
        if self.proc is not None:
            self.proc.stdin.close()
            self.proc.stdout.close()
            self.proc.wait()


def _worktree_text(repo, path):
    try:
        with open(os.path.join(repo, path), encoding="utf-8", errors="replace") as fh:
            return fh.read()
    except OSError:
        return None


def split_changes(repo, base: str, head: str | None, paths):
    """(significant, ignored) partition of `paths`, comparing base with head (work tree if None)."""
    repo = os.path.abspath(str(repo))
    top = _git(repo, "rev-parse", "--show-toplevel").strip()
    significant, ignored = [], []
    reader = _BlobReader(top)
    try:
        for p in paths:
            if not p.endswith(SOURCE_EXT):
                significant.append(p)
                continue
            old = reader.read(base, p)
            new = _worktree_text(top, p) if head is None else reader.read(head, p)
            (ignored if same_code(p, old, new) else significant).append(p)
    finally:
        reader.close()
    return significant, ignored


def significant_changes(repo, base: str, head: str | None = None, pathspecs=(), diff_filter=None,
                        with_ignored=False):
    """Paths changed between base and head (work tree if None) that are more than comments/whitespace."""
    base, head = resolve_range(repo, base, head)
    sig, ign = split_changes(repo, base, head, changed_paths(repo, base, head, pathspecs, diff_filter))
    return (sig, ign) if with_ignored else sig


def is_functional_change(base: str, head: str | None, path: str, repo=".") -> bool:
    """One path: True unless it is a source file whose base and head differ only in comments/whitespace."""
    sig, _ = split_changes(repo, base, head, [path])
    return bool(sig)


# ---------------------------------------------------------------- CLI

def main(argv=None):
    argv = list(sys.argv[1:] if argv is None else argv)
    pathspecs: list[str] = []
    if "--" in argv:
        k = argv.index("--")
        argv, pathspecs = argv[:k], argv[k + 1:]
    repo, diff_filter, report, positional = ".", None, False, []
    it = iter(argv)
    for a in it:
        if a == "-C":
            repo = next(it)
        elif a.startswith("--diff-filter="):
            diff_filter = a.split("=", 1)[1]
        elif a == "--diff-filter":
            diff_filter = next(it)
        elif a == "--report-ignored":
            report = True
        elif a in ("-h", "--help"):
            print(__doc__)
            return 0
        else:
            positional.append(a)
    if not 1 <= len(positional) <= 2:
        print("usage: significant_changes.py [-C DIR] [--diff-filter F] [--report-ignored] BASE [HEAD] [-- PATHSPEC...]",
              file=sys.stderr)
        return 2
    base = positional[0]
    head = positional[1] if len(positional) == 2 else None
    try:
        sig, ign = significant_changes(repo, base, head, pathspecs, diff_filter, with_ignored=True)
    except (GitError, OSError) as e:
        print(f"significant_changes: {e}", file=sys.stderr)
        return 2
    for p in sig:
        print(p)
    if report and ign:
        print(f"significant_changes: {len(ign)} file(s) changed only in comments/whitespace, not counted:",
              file=sys.stderr)
        for p in ign:
            print(f"  {p}", file=sys.stderr)
    return 0


if __name__ == "__main__":
    sys.exit(main())
