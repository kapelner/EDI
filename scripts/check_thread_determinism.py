#!/usr/bin/env python3
"""Static gate: R/EDI/src must stay deterministic across thread counts.

v1.1.0 cross_platform_reproducibility.md, TODO-2 and owner decision D3: one
installed binary must give bit-identical results across runs and across
OpenMP thread counts ("exact on one build"), and RNG-only draws must be
identical on every platform ("exact everywhere"). Both depend on every random
stream coming from edi_rng::RRng seeded per draw index
(edi_rng::seed_for_index(master, i)), and on no floating-point sum being
combined in an order the thread team decides. Nothing in the compiler
enforces either, so this script does.

Always banned (cannot be allowlisted):
  rng-shuffle         std::shuffle / std::random_shuffle (implementation-
                      defined algorithm; use edi_rng::fisher_yates_shuffle)
  rng-include         #include <random>
  rng-engine          <random> engines and std::seed_seq / generate_canonical
  rng-distribution    <random> distributions (std::normal_distribution, ...)
  rng-random-device   std::random_device
  rng-c-rand          rand(), srand(), rand_r(), [dejlmns]rand48()
  rng-thread-seed     seeding derived from omp_get_thread_num() (a stream per
                      thread, so draws change with the thread count)

Banned unless allowlisted with a written reason:
  float-reduction     an OpenMP reduction( clause shared across threads
                      (parallel / for / taskloop / sections) on a variable
                      that is not provably integral. `omp simd` reductions
                      (and EDI_SIMD_REDUCTION) stay inside one thread, their
                      order is fixed by the binary, and they are allowed.
  float-atomic        `omp atomic` updating a non-integral variable, or a
                      std::atomic<double/float>
  float-critical      `omp critical` whose body accumulates into a
                      non-integral variable (+=, -=, *=, /=)
  thread-partials     per-thread partial results: a container indexed by
                      omp_get_thread_num() (or a variable holding it), or a
                      floating-point container sized by the thread count,
                      combined afterwards in thread order

A variable counts as integral only when its nearest preceding declaration in
the same file has an integer type; unknown types are treated as floating, so
the check errs toward flagging.

Allowlist: scripts/check_thread_determinism_allowlist.csv, columns
file,rule,match,reason. `match` is a substring of the offending source line
(comments removed, whitespace collapsed), so entries survive line-number
shifts. Every entry needs a non-empty reason, must name an allowlistable rule,
and must still match something: a stale entry fails the check, so the list
cannot outlive the code it excuses.

Usage: check_thread_determinism.py [SRC_DIR] [--allowlist PATH]
Exit status 0 = clean, 1 = violations or allowlist errors.
"""
import argparse
import csv
import os
import re
import sys

ALWAYS_BANNED = {
    "rng-shuffle", "rng-include", "rng-engine", "rng-distribution",
    "rng-random-device", "rng-c-rand", "rng-thread-seed",
}
ALLOWLISTABLE = {"float-reduction", "float-atomic", "float-critical", "thread-partials"}

SOURCE_EXTS = (".cpp", ".cc", ".cxx", ".h", ".hpp", ".hh")

ENGINES = (
    "mt19937", "mt19937_64", "minstd_rand", "minstd_rand0", "ranlux24",
    "ranlux48", "ranlux24_base", "ranlux48_base", "knuth_b",
    "default_random_engine", "mersenne_twister_engine",
    "linear_congruential_engine", "subtract_with_carry_engine",
    "discard_block_engine", "independent_bits_engine", "shuffle_order_engine",
    "seed_seq", "generate_canonical",
)
DISTRIBUTIONS = (
    "uniform_int", "uniform_real", "bernoulli", "binomial", "negative_binomial",
    "geometric", "poisson", "exponential", "gamma", "weibull", "extreme_value",
    "normal", "lognormal", "chi_squared", "cauchy", "fisher_f", "student_t",
    "discrete", "piecewise_constant", "piecewise_linear",
)

SIMPLE_RULES = [
    ("rng-shuffle", re.compile(r"\b(?:std\s*::\s*)?(?:random_)?shuffle\s*\("),
     "std::shuffle/std::random_shuffle: use edi_rng::fisher_yates_shuffle"),
    ("rng-include", re.compile(r"#\s*include\s*<random>"),
     "#include <random>: draws must come from edi_rng::RRng (RNG.h)"),
    ("rng-engine", re.compile(r"\b(?:" + "|".join(ENGINES) + r")\b"),
     "<random> engine: use edi_rng::RRng seeded by edi_rng::seed_for_index"),
    ("rng-distribution", re.compile(r"\b(?:" + "|".join(DISTRIBUTIONS) + r")_distribution\b"),
     "<random> distribution: its algorithm is implementation-defined"),
    ("rng-random-device", re.compile(r"\brandom_device\b"),
     "std::random_device: nondeterministic seed"),
    ("rng-c-rand", re.compile(r"(?<![\w.>:])(?:std\s*::\s*|::\s*)?(?:s?rand|rand_r|[dejlmns]rand48)\s*\("),
     "C rand()/srand()/rand48: global, implementation-defined generator"),
]

INT_TYPE_RE = re.compile(
    r"\b(?:bool|char|short|int|long|unsigned|signed|size_t|ptrdiff_t|ssize_t|"
    r"u?int(?:8|16|32|64)_t|u?int_fast\d+_t|u?int_least\d+_t|R_xlen_t|R_len_t|"
    r"Index|Eigen::Index|StorageIndex)\b")
FLOAT_CONTAINER_RE = re.compile(
    r"\b(?:double|float|long\s+double|VectorXd|MatrixXd|ArrayXd|ArrayXXd|"
    r"VectorXf|MatrixXf|NumericVector|NumericMatrix|complex)\b")
THREAD_NUM_RE = re.compile(r"\bomp_get_thread_num\s*\(\s*\)")
THREAD_COUNT_RE = re.compile(r"\bomp_get_(?:max|num)_threads\s*\(\s*\)")
SEED_WORD_RE = re.compile(r"(?i)seed|rng|engine|stream|RRng")
COMPOUND_ASSIGN_RE = re.compile(r"([A-Za-z_]\w*)\s*(?:\[[^\]]*\]\s*)*(?:\+|-|\*|/)=")
SELF_ASSIGN_RE = re.compile(r"\b([A-Za-z_]\w*)\s*=\s*\1\s*[-+*/]")
INCDEC_RE = re.compile(r"(?:\+\+|--)\s*([A-Za-z_]\w*)|([A-Za-z_]\w*)\s*(?:\+\+|--)")
PRAGMA_STR_RE = re.compile(r'(?:_Pragma\s*\(\s*"([^"]*)"\s*\)|EDI_PRAGMA\s*\(([^)]*(?:\([^)]*\)[^)]*)*)\))')
REDUCTION_RE = re.compile(r"\breduction\s*\(\s*[^:]*:\s*([^)]*)\)")


def strip(text, keep_strings):
    """Blank comments (and, unless keep_strings, string/char literal
    contents), preserving newlines so line numbers still line up."""
    out = []
    i, n = 0, len(text)
    state = "code"
    while i < n:
        c = text[i]
        nxt = text[i + 1] if i + 1 < n else ""
        if state == "code":
            if c == "/" and nxt == "/":
                state = "line"; out.append("  "); i += 2; continue
            if c == "/" and nxt == "*":
                state = "block"; out.append("  "); i += 2; continue
            if c in "\"'":
                # a ' between two digits is a C++14 digit separator, not a char
                if c == "'" and i > 0 and text[i - 1].isalnum() and nxt.isalnum():
                    out.append(c); i += 1; continue
                state = c; out.append(c if keep_strings else " "); i += 1; continue
            out.append(c); i += 1
        elif state == "line":
            if c == "\n":
                state = "code"; out.append(c)
            else:
                out.append(" ")
            i += 1
        elif state == "block":
            if c == "*" and nxt == "/":
                state = "code"; out.append("  "); i += 2; continue
            out.append("\n" if c == "\n" else " "); i += 1
        else:  # inside a string or char literal; state is the quote char
            if c == "\\" and i + 1 < n:
                out.append(text[i:i + 2] if keep_strings else "  "); i += 2; continue
            if c == state:
                state = "code"; out.append(c if keep_strings else " "); i += 1; continue
            out.append(c if keep_strings or c == "\n" else " "); i += 1
    return "".join(out)


def collapse(s):
    return " ".join(s.split())


def is_integral(var, lines, upto):
    """True when the nearest declaration of `var` at or before line index
    `upto` has an integer type. Unknown -> False (treated as floating)."""
    decl = re.compile(r"(?:^|[;{(,])\s*(?:const\s+|static\s+|register\s+)*"
                      r"([A-Za-z_][\w:<>,\s]*?)[\s&*]+" + re.escape(var) + r"\s*(?:[=;,\[{)(]|$)")
    for k in range(upto, -1, -1):
        m = decl.search(lines[k])
        if not m:
            continue
        type_text = m.group(1)
        if re.search(r"\b(?:return|else|case|delete|new|throw)\b", type_text):
            continue
        if FLOAT_CONTAINER_RE.search(type_text):
            return False
        return bool(INT_TYPE_RE.search(type_text))
    return False


def logical_pragmas(code_lines):
    """Yield (line_index, pragma_text) for every OpenMP pragma, joining
    backslash continuations and expanding _Pragma/EDI_PRAGMA strings."""
    i = 0
    while i < len(code_lines):
        line = code_lines[i]
        m = re.match(r"\s*#\s*pragma\s+(.*)$", line)
        if m:
            text, j = m.group(1), i
            while text.rstrip().endswith("\\") and j + 1 < len(code_lines):
                j += 1
                text = text.rstrip()[:-1] + " " + code_lines[j]
            yield i, collapse(text)
            i = j + 1
            continue
        for pm in PRAGMA_STR_RE.finditer(line):
            yield i, collapse(pm.group(1) or pm.group(2) or "")
        i += 1


def body_after(code_lines, idx):
    """The statement or brace block following the pragma on line idx."""
    chunk = "\n".join(code_lines[idx + 1: idx + 60])
    s = chunk.lstrip()
    if s.startswith("{"):
        depth = 0
        for k, ch in enumerate(s):
            depth += ch == "{"
            depth -= ch == "}"
            if depth == 0:
                return s[:k + 1]
        return s
    end = s.find(";")
    return s if end < 0 else s[:end + 1]


def scan_file(path, rel):
    with open(path, encoding="utf-8", errors="replace") as fh:
        raw = fh.read()
    code = strip(raw, keep_strings=False).split("\n")
    code_s = strip(raw, keep_strings=True).split("\n")
    hits = []

    def add(rule, k, msg):
        hits.append((rel, k + 1, rule, collapse(code_s[k]), msg))

    for k, line in enumerate(code):
        for rule, rx, msg in SIMPLE_RULES:
            target = code_s[k] if rule == "rng-include" else line
            if rx.search(target):
                add(rule, k, msg)
        if re.search(r"\bstd\s*::\s*atomic\s*<\s*(?:long\s+)?(?:double|float)\s*>", line):
            add("float-atomic", k, "std::atomic of a floating type: update order follows the thread schedule")

    # Variables that hold the thread id or the thread count.
    tid_vars, tcount_vars = set(), set()
    for line in code:
        for m in re.finditer(r"\b([A-Za-z_]\w*)\s*=\s*(?:static_cast\s*<[^>]*>\s*\()?\s*omp_get_thread_num\s*\(", line):
            tid_vars.add(m.group(1))
        for m in re.finditer(r"\b([A-Za-z_]\w*)\s*=\s*(?:static_cast\s*<[^>]*>\s*\()?\s*omp_get_(?:max|num)_threads\s*\(", line):
            tcount_vars.add(m.group(1))
    tid_alt = "|".join(re.escape(v) for v in sorted(tid_vars))
    tid_expr = r"(?:omp_get_thread_num\s*\(\s*\)" + (r"|\b(?:" + tid_alt + r")\b" if tid_alt else "") + ")"
    tcount_alt = "|".join(re.escape(v) for v in sorted(tcount_vars))
    tcount_expr = r"(?:omp_get_(?:max|num)_threads\s*\(\s*\)" + (r"|\b(?:" + tcount_alt + r")\b" if tcount_alt else "") + ")"

    for k, line in enumerate(code):
        uses_tid = re.search(tid_expr, line)
        if uses_tid and SEED_WORD_RE.search(line) and not re.search(r"=\s*omp_get_thread_num", line):
            add("rng-thread-seed", k, "random stream seeded from the thread id: use seed_for_index(master, draw_index)")
        if re.search(r"\[\s*[^\]]*" + tid_expr + r"[^\]]*\]", line):
            add("thread-partials", k, "container indexed by thread id: per-thread partials combine in thread order")
        if FLOAT_CONTAINER_RE.search(line) and re.search(r"[({]\s*[^;]*" + tcount_expr, line) \
                and re.search(r"\b(?:vector|Vector|Matrix|Array|new)\b", line):
            add("thread-partials", k, "floating-point container sized by the thread count")

    for k, pragma in logical_pragmas(code_s):
        if not re.match(r"omp\b", pragma):
            continue
        words = set(re.findall(r"[a-z_]+", pragma.split("(")[0]))
        rm = REDUCTION_RE.search(pragma)
        if rm:
            simd_only = "simd" in words and not (words & {"parallel", "for", "taskloop", "sections", "distribute", "teams", "loop"})
            if not simd_only:
                for v in re.split(r"\s*,\s*", rm.group(1).strip()):
                    v = re.sub(r"\[.*", "", v).strip()
                    if v and not is_integral(v, code, k):
                        add("float-reduction", k, "OpenMP reduction on non-integral `%s` across threads: "
                            "combination order depends on the thread count" % v)
        if "atomic" in words:
            body = body_after(code, k)
            targets = [m.group(1) for m in COMPOUND_ASSIGN_RE.finditer(body)] + \
                      [m.group(1) for m in SELF_ASSIGN_RE.finditer(body)]
            if not targets:
                targets = [a or b for a, b in INCDEC_RE.findall(body)]
            if any(not is_integral(t, code, k) for t in targets):
                add("float-atomic", k, "omp atomic on a non-integral accumulator")
        if "critical" in words:
            body = body_after(code, k)
            targets = [m.group(1) for m in COMPOUND_ASSIGN_RE.finditer(body)] + \
                      [m.group(1) for m in SELF_ASSIGN_RE.finditer(body)]
            if any(not is_integral(t, code, k) for t in targets):
                add("float-critical", k, "omp critical accumulating into a non-integral variable")
    return hits


def iter_sources(src_dir):
    for root, dirs, files in os.walk(src_dir):
        dirs.sort()
        for f in sorted(files):
            if f.endswith(SOURCE_EXTS):
                yield os.path.join(root, f), os.path.relpath(os.path.join(root, f), src_dir)


def load_allowlist(path):
    errors, entries = [], []
    if not path or not os.path.exists(path):
        return entries, errors
    with open(path, encoding="utf-8", newline="") as fh:
        rows = [r for r in fh if not r.lstrip().startswith("#")]
    for n, row in enumerate(csv.DictReader(rows), start=2):
        f, rule = (row.get("file") or "").strip(), (row.get("rule") or "").strip()
        match, reason = collapse(row.get("match") or ""), (row.get("reason") or "").strip()
        if not f or not rule or not match:
            errors.append("allowlist row %d: file, rule and match are all required" % n)
        elif rule in ALWAYS_BANNED:
            errors.append("allowlist row %d: rule %s is always banned and cannot be allowlisted" % (n, rule))
        elif rule not in ALLOWLISTABLE:
            errors.append("allowlist row %d: unknown rule %r" % (n, rule))
        elif not reason:
            errors.append("allowlist row %d (%s %s): a written reason is required" % (n, f, rule))
        else:
            entries.append({"file": f, "rule": rule, "match": match, "reason": reason, "row": n, "used": False})
    return entries, errors


def main(argv=None):
    here = os.path.dirname(os.path.abspath(__file__))
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("src_dir", nargs="?", default=os.path.join(here, "..", "R", "EDI", "src"))
    ap.add_argument("--allowlist", default=os.path.join(here, "check_thread_determinism_allowlist.csv"))
    args = ap.parse_args(argv)

    entries, errors = load_allowlist(args.allowlist)
    violations, allowed = [], 0
    for path, rel in iter_sources(args.src_dir):
        for hit in scan_file(path, rel):
            f, line, rule, text, msg = hit
            entry = next((e for e in entries if e["file"] == f and e["rule"] == rule and e["match"] in text), None)
            if entry is not None and rule in ALLOWLISTABLE:
                entry["used"] = True
                allowed += 1
            else:
                violations.append(hit)

    for e in entries:
        if not e["used"]:
            errors.append("allowlist row %d (%s %s %r) matches nothing: remove the stale entry"
                          % (e["row"], e["file"], e["rule"], e["match"]))

    for f, line, rule, text, msg in violations:
        print("%s:%d: [%s] %s\n    %s" % (f, line, rule, msg, text), file=sys.stderr)
    for err in errors:
        print("allowlist: " + err, file=sys.stderr)
    if violations or errors:
        print("check_thread_determinism: FAILED (%d violation(s), %d allowlist error(s)). "
              "Allowlistable rules (%s) go in %s with a reason."
              % (len(violations), len(errors), ", ".join(sorted(ALLOWLISTABLE)), args.allowlist), file=sys.stderr)
        return 1
    print("check_thread_determinism: OK (%d allowlisted hit(s))." % allowed)
    return 0


if __name__ == "__main__":
    sys.exit(main())
