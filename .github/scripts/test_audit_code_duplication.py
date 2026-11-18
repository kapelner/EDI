#!/usr/bin/env python3
"""Checks for the code-duplication audit and the per-push check (audits/code_duplication.py).

Stdlib only, no network, no jscpd: jscpd is replaced by a small exact-window detector over the
fixture files (`fake_jscpd`), which reports runs the way jscpd does (identical stretches, broken
wherever the copies differ). The main fixture is the shape of v1.0.6-TODO-117/-121: two copies of
compute_shared_icen() where InferenceSurvivalLogRank got the ictest() arm-sign fix and
InferenceSurvivalGehanWilcox did not.

Run: python3 .github/scripts/test_audit_code_duplication.py
"""
import contextlib
import json
import os
import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
import audit_common as ac  # noqa: E402
from audits import code_duplication as cd  # noqa: E402

REPO = Path(__file__).resolve().parents[2]


def icen(name, scores, prefix, fixed):
    """A compute_shared_icen() like the 2026-11 ones; `fixed` adds the arm-sign lines."""
    sign = ("\t\t\t# ictest() orders arms by first appearance (v1.0.6-TODO-117).\n"
            "\t\t\tarm_sign = ictest_treatment_minus_control_sign(fit)\n"
            "\t\t\tbeta_hat = arm_sign * as.numeric(fit$estimate)\n") if fixed else \
        "\t\t\tbeta_hat = as.numeric(fit$estimate)\n"
    z = "arm_sign * as.numeric(fit$statistic)" if fixed else "as.numeric(fit$statistic)"
    return (
        f"{name} = R6::R6Class(\"{name}\",\n"
        "\tprivate = list(\n"
        "\t\tcompute_shared_icen = function(estimate_only = FALSE){\n"
        "\t\t\tif (estimate_only && !is.null(private$cached_values$beta_hat_T)) return(invisible(NULL))\n"
        "\t\t\tif (!estimate_only && !is.null(private$cached_values$s_beta_hat_T)) return(invisible(NULL))\n"
        "\t\t\tassert_interval_installed(class(self)[1L])\n"
        "\t\t\tL = ifelse(is.na(private$y), private$y_L, private$y)\n"
        "\t\t\tR = ifelse(is.na(private$y), private$y_R, private$y)\n"
        "\t\t\tfit = tryCatch(\n"
        f"\t\t\t\tsuppressWarnings(interval::ictest(L, R, private$w, scores = \"{scores}\")),\n"
        "\t\t\t\terror = function(e) NULL\n"
        "\t\t\t)\n"
        "\t\t\tif (is.null(fit)) {\n"
        "\t\t\t\tprivate$cached_values$beta_hat_T = NA_real_\n"
        "\t\t\t\tif (estimate_only) return(invisible(NULL))\n"
        "\t\t\t\tprivate$cached_values$s_beta_hat_T = NA_real_\n"
        f"\t\t\t\tprivate$cached_values${prefix}_score = NA_real_\n"
        f"\t\t\t\tprivate$cached_values${prefix}_var = NA_real_\n"
        "\t\t\t\tprivate$cached_values$icen_pval = NA_real_\n"
        "\t\t\t\treturn(invisible(NULL))\n"
        "\t\t\t}\n"
        + sign +
        "\t\t\tprivate$cached_values$beta_hat_T = beta_hat\n"
        "\t\t\tif (estimate_only) return(invisible(NULL))\n"
        f"\t\t\tz_stat = {z}\n"
        "\t\t\tprivate$cached_values$s_beta_hat_T = if (is.finite(z_stat) && z_stat != 0) abs(beta_hat / z_stat) else NA_real_\n"
        f"\t\t\tprivate$cached_values${prefix}_score = z_stat\n"
        f"\t\t\tprivate$cached_values${prefix}_var = 1\n"
        "\t\t\tprivate$cached_values$icen_pval = as.numeric(fit$p.value)\n"
        "\t\t}\n"
        "\t)\n"
        ")\n")


LOGRANK = "R/EDI/R/inference_survival_log_rank.R"
GEHAN = "R/EDI/R/inference_survival_gehan_wilcox.R"
UNRELATED = "R/EDI/R/other.R"
OTHER_TEXT = "f = function(x) {\n\tx + 1\n}\n"


def fake_jscpd(root, min_lines=3):
    """jscpd stand-in: maximal runs of at least `min_lines` identical code lines (comments and blank
    lines ignored, as with jscpd --mode weak) between every two files, or two places in one file."""
    root = Path(root)
    files = {}
    for d in cd.SCAN_DIRS:
        for p in sorted((root / d).rglob("*")) if (root / d).is_dir() else []:
            if p.is_file():
                rel = str(p.relative_to(root))
                lines = cd.code_lines(rel, p.read_text())
                files[rel] = [(i + 1, l) for i, l in enumerate(lines) if l]
    out = []
    names = sorted(files)
    for x in range(len(names)):
        for y in range(x, len(names)):
            A, B = files[names[x]], files[names[y]]
            for i in range(len(A)):
                for j in range(len(B)):
                    if names[x] == names[y] and j <= i:
                        continue
                    if i and j and A[i - 1][1] == B[j - 1][1]:
                        continue   # not the start of a maximal run
                    k = 0
                    while i + k < len(A) and j + k < len(B) and A[i + k][1] == B[j + k][1]:
                        k += 1
                    if k >= min_lines and any(cd.nontrivial(A[i + t][1]) for t in range(k)):
                        if names[x] == names[y] and B[j][0] <= A[i + k - 1][0]:
                            continue
                        out.append({"a": (names[x], A[i][0], A[i + k - 1][0]),
                                    "b": (names[y], B[j][0], B[j + k - 1][0]), "tokens": 10 * k})
    return out


@contextlib.contextmanager
def patched(obj, name, value):
    old = getattr(obj, name)
    setattr(obj, name, value)
    try:
        yield
    finally:
        setattr(obj, name, old)


def write(root, files):
    for rel, text in files.items():
        p = Path(root) / rel
        p.parent.mkdir(parents=True, exist_ok=True)
        p.write_text(text)


def fams_of(root):
    return cd.families(root, fake_jscpd(root))


class Lowered(unittest.TestCase):
    """Smaller thresholds for the small fixtures; restored after each test."""

    def setUp(self):
        self._old = (cd.MIN_SHARED_TOKENS, cd.MIN_EXACT_TOKENS)
        cd.MIN_SHARED_TOKENS, cd.MIN_EXACT_TOKENS = 60, 60
        self.tmp = Path(tempfile.mkdtemp())

    def tearDown(self):
        cd.MIN_SHARED_TOKENS, cd.MIN_EXACT_TOKENS = self._old
        shutil.rmtree(self.tmp, ignore_errors=True)


# ---------------------------------------------------------------- normalizing and jscpd output

class TestNormalize(unittest.TestCase):
    def test_comments_and_whitespace(self):
        self.assertEqual(cd.code_lines("a.R", "x = 1  # set x\n# only\ny = '#not'\n"), ["x=1", "", "y='#not'"])
        self.assertEqual(cd.code_lines("a.cpp", "int a = 1; // c\n/* b\n c */ int b;\n"), ["int a=1;", "", "int b;"])
        self.assertEqual(cd.code_lines("a.py", "x = 1  # c\n"), ["x=1"])

    def test_layout_does_not_matter(self):
        self.assertEqual(cd._squeeze("for (int i = 0; i < n; i++)"), cd._squeeze("for(int i=0;i<n;i++)"))
        self.assertNotEqual(cd._squeeze("a - -b"), cd._squeeze("int ab"))

    def test_parse_jscpd_paths_relative_and_ordered(self):
        root = Path("/r").resolve()
        data = {"duplicates": [{"firstFile": {"name": str(root / "z.R"), "startLoc": {"line": 5}, "endLoc": {"line": 9}},
                                "secondFile": {"name": str(root / "a.R"), "startLoc": {"line": 1}, "endLoc": {"line": 4}},
                                "tokens": 70}]}
        c = cd.parse_jscpd(data, root)
        self.assertEqual(c, [{"a": ("a.R", 1, 4), "b": ("z.R", 5, 9), "tokens": 70}])

    def test_missing_jscpd_is_an_error_not_a_clean_scan(self):
        with patched(cd, "find_jscpd", lambda: None), tempfile.TemporaryDirectory() as d:
            (Path(d) / "R/EDI/R").mkdir(parents=True)
            with self.assertRaises(RuntimeError):
                cd.run_jscpd(d)

    def test_merge_runs_across_short_gaps_only(self):
        runs = [{"a": ("a", 1, 10), "b": ("b", 101, 110)}, {"a": ("a", 13, 20), "b": ("b", 114, 121)},
                {"a": ("a", 60, 70), "b": ("b", 160, 170)}]
        fams = cd.merge_runs(runs, gap=8)
        self.assertEqual([f[:6] for f in fams], [("a", 1, 20, "b", 101, 121), ("a", 60, 70, "b", 160, 170)])
        self.assertEqual(fams[0][6], 2)


# ---------------------------------------------------------------- the TODO-117/-121 shape

class TestDivergenceShape(Lowered):
    def setUp(self):
        super().setUp()
        write(self.tmp, {LOGRANK: icen("InferenceSurvivalLogRank", "logrank1", "logrank", fixed=True),
                         GEHAN: icen("InferenceSurvivalGehanWilcox", "wmw", "gw", fixed=False),
                         UNRELATED: OTHER_TEXT})

    def test_flagged_as_divergent_with_the_sign_lines(self):
        fams = [f for f in fams_of(self.tmp) if cd.is_candidate(f)]
        self.assertEqual(len(fams), 1)
        f = fams[0]
        self.assertEqual({f["a"][0], f["b"][0]}, {LOGRANK, GEHAN})
        self.assertEqual(f["kind"], "divergent")
        self.assertEqual(f["structural_hunks"], 2)
        structural = " ".join(h["a_tokens"] + " " + h["b_tokens"] for h in f["hunks"] if h["kind"] == "structural")
        self.assertIn("arm_sign", structural)
        renamed = {(h["a_tokens"], h["b_tokens"]) for h in f["hunks"] if h["kind"] == "renamed"}
        self.assertIn(('"wmw"', '"logrank1"'), renamed)
        self.assertGreaterEqual(f["similarity"], 0.8)
        self.assertIn("arm_sign", cd.unified(f))
        self.assertTrue(f["id"].startswith("dup-"))

    def test_both_fixed_is_only_renamed(self):
        write(self.tmp, {GEHAN: icen("InferenceSurvivalGehanWilcox", "wmw", "gw", fixed=True)})
        f = [f for f in fams_of(self.tmp) if cd.is_candidate(f)][0]
        self.assertEqual(f["kind"], "renamed")
        self.assertEqual(f["structural_hunks"], 0)

    def test_divergent_outranks_renamed(self):
        div = [f for f in fams_of(self.tmp) if cd.is_candidate(f)][0]
        write(self.tmp, {GEHAN: icen("InferenceSurvivalGehanWilcox", "wmw", "gw", fixed=True)})
        ren = [f for f in fams_of(self.tmp) if cd.is_candidate(f)][0]
        self.assertGreater(div["score"], ren["score"])

    def test_id_survives_line_moves_but_not_edits_inside(self):
        uid = [f for f in fams_of(self.tmp) if cd.is_candidate(f)][0]["id"]
        write(self.tmp, {LOGRANK: "# header\nhelper = function() 1\n\n" + icen("InferenceSurvivalLogRank", "logrank1", "logrank", True)})
        moved = [f for f in fams_of(self.tmp) if cd.is_candidate(f)][0]
        self.assertEqual(moved["id"], uid)
        self.assertEqual(moved["a"][0], GEHAN)
        self.assertGreater(moved["b"][1], 3)
        write(self.tmp, {LOGRANK: icen("InferenceSurvivalLogRank", "logrank1", "logrank", True).replace(
            "abs(beta_hat / z_stat)", "abs(beta_hat) / abs(z_stat)")})
        self.assertNotEqual([f for f in fams_of(self.tmp) if cd.is_candidate(f)][0]["id"], uid)

    def test_comment_only_difference_is_exact(self):
        text = icen("A", "wmw", "gw", fixed=False)
        write(self.tmp, {LOGRANK: text, GEHAN: text.replace("\t\t\tL = ifelse", "\t\t\t# a comment\n\t\t\tL = ifelse")})
        f = fams_of(self.tmp)[0]
        self.assertEqual(f["kind"], "exact")

    def test_hints(self):
        f = {"a": ["R/EDI/src/fast_gee.cpp", 1, 2], "b": ["python/cpp/bindings_incidence.cpp", 1, 2]}
        self.assertTrue(cd.boundary(f))
        self.assertIn("R/Python boundary", cd.hints(f)[0])
        self.assertIn("IVWC", " ".join(cd.hints({"a": ["R/EDI/R/x_ivwc.R", 1, 2], "b": ["R/EDI/R/y.R", 1, 2]})))


# ---------------------------------------------------------------- per-push logic

class TestHunks(unittest.TestCase):
    DIFF = ("diff --git a/x.R b/x.R\n--- a/x.R\n+++ b/x.R\n@@ -10,2 +10,3 @@ ctx\n-a\n+b\n@@ -30,0 +32,2 @@\n+c\n"
            "diff --git a/gone.R b/gone.R\n--- a/gone.R\n+++ /dev/null\n@@ -1,5 +0,0 @@\n"
            "diff --git a/new.R b/new.R\n--- /dev/null\n+++ b/new.R\n@@ -0,0 +1,4 @@\n")

    def test_parse(self):
        h = cd.parse_hunks(self.DIFF)
        self.assertEqual(h["x.R"], {"old": [(10, 2), (30, 0)], "new": [(10, 3), (32, 2)]})
        self.assertEqual(h["gone.R"]["old"], [(1, 5)])
        self.assertEqual(h["new.R"]["new"], [(1, 4)])

    def test_touches(self):
        self.assertTrue(cd.touches([(10, 2)], 11, 20))
        self.assertFalse(cd.touches([(10, 2)], 12, 20))
        self.assertTrue(cd.touches([(30, 0)], 25, 35))    # an insertion inside the region
        self.assertFalse(cd.touches([(30, 0)], 31, 35))   # ... and one just before it
        self.assertFalse(cd.touches([(30, 0)], 20, 30))   # ... and one just after it


def fam(uid, a, b, kind="divergent"):
    return {"id": uid, "a": list(a), "b": list(b), "kind": kind, "shared_tokens": 500, "similarity": 0.95,
            "differing_tokens": 4, "structural_hunks": 1, "hunks": [], "shared": 30, "score": 10.0}


class TestNewDivergences(unittest.TestCase):
    F = fam("dup-1", ("a.R", 10, 50), ("b.R", 100, 140))

    def run_(self, hunks, significant=("a.R", "b.R"), exists=lambda p: True, dismissed=frozenset()):
        return cd.new_divergences([self.F], hunks, set(significant), exists, dismissed)

    def test_edit_to_one_copy_is_flagged(self):
        r = self.run_({"a.R": {"old": [(20, 1)], "new": [(20, 2)]}})
        self.assertEqual([x["edited"] for x in r], ["a"])

    def test_edit_to_both_copies_is_not(self):
        self.assertEqual(self.run_({"a.R": {"old": [(20, 1)], "new": [(20, 2)]},
                                    "b.R": {"old": [(110, 1)], "new": [(110, 2)]}}), [])

    def test_edit_to_neither_copy_is_not(self):
        self.assertEqual(self.run_({"a.R": {"old": [(200, 1)], "new": [(200, 1)]}}), [])

    def test_comment_only_edit_is_not(self):
        self.assertEqual(self.run_({"a.R": {"old": [(20, 1)], "new": [(20, 1)]}}, significant=()), [])

    def test_deleting_a_copy_is_not(self):
        self.assertEqual(self.run_({"a.R": {"old": [(1, 60)], "new": []}}, exists=lambda p: p != "a.R"), [])

    def test_dismissed_family_is_not(self):
        self.assertEqual(self.run_({"a.R": {"old": [(20, 1)], "new": [(20, 2)]}},
                                   dismissed={cd.decision_id_of("dup-1")}), [])


class TestNewClones(Lowered):
    def test_new_copy_flagged_preexisting_not(self):
        base_files = {LOGRANK: icen("InferenceSurvivalLogRank", "logrank1", "logrank", True), UNRELATED: OTHER_TEXT}
        write(self.tmp / "base", base_files)
        write(self.tmp / "head", {**base_files, GEHAN: icen("InferenceSurvivalGehanWilcox", "wmw", "gw", False)})
        base, head = fams_of(self.tmp / "base"), fams_of(self.tmp / "head")
        n = len(icen("X", "wmw", "gw", False).splitlines())
        hunks = {GEHAN: {"old": [(0, 0)], "new": [(1, n)]}}

        def lines(root, fams):
            return {f[s][0]: cd.code_lines(f[s][0], (root / f[s][0]).read_text()) for f in fams for s in "ab"}

        hl, bl = lines(self.tmp / "head", head), lines(self.tmp / "base", base)
        new = cd.new_clones(head, base, hunks, hl, bl)
        self.assertEqual(len(new), 1)
        self.assertEqual({new[0]["a"][0], new[0]["b"][0]}, {LOGRANK, GEHAN})
        # The same pair already at base, one line edited: an edit to a known clone, not a new clone.
        self.assertEqual(cd.new_clones(head, head, {GEHAN: {"old": [(20, 1)], "new": [(20, 1)]}}, hl, hl), [])
        edited = [dict(f, id=f["id"] + "x") for f in head]
        self.assertEqual(cd.new_clones(edited, head, {GEHAN: {"old": [(20, 1)], "new": [(20, 1)]}}, hl, hl), [])
        self.assertEqual(cd.new_clones(head, base, hunks, hl, bl, {cd.decision_id_of(new[0]["id"])}), [])


def git(repo, *args):
    subprocess.run(["git", "-C", str(repo), *args], check=True, capture_output=True)


class TestPushCheckEndToEnd(Lowered):
    """A real git repository, the real significant_changes.py, jscpd replaced by fake_jscpd."""

    def setUp(self):
        super().setUp()
        r = self.tmp
        shutil.copy(REPO / "scripts/significant_changes.py", r / "sc.py")
        (r / "scripts").mkdir()
        (r / "sc.py").rename(r / "scripts/significant_changes.py")
        write(r, {LOGRANK: icen("InferenceSurvivalLogRank", "logrank1", "logrank", False),
                  GEHAN: icen("InferenceSurvivalGehanWilcox", "wmw", "gw", False), UNRELATED: OTHER_TEXT})
        git(r, "init", "-q")
        git(r, "add", "-A")
        git(r, "-c", "user.name=t", "-c", "user.email=t@t", "commit", "-qm", "base")

    def commit(self, files, msg):
        write(self.tmp, files)
        git(self.tmp, "add", "-A")
        git(self.tmp, "-c", "user.name=t", "-c", "user.email=t@t", "commit", "-qm", msg)

    def check(self):
        with patched(cd, "run_jscpd", lambda root, **kw: fake_jscpd(root)):
            return cd.push_check(self.tmp, "HEAD~1", "HEAD", dismissed=set())

    def test_fixing_one_copy_is_a_new_divergence(self):
        self.commit({LOGRANK: icen("InferenceSurvivalLogRank", "logrank1", "logrank", True)}, "fix logrank only")
        res = self.check()
        self.assertEqual(len(res["new_divergences"]), 1)
        d = res["new_divergences"][0]
        self.assertEqual(d[d["edited"]][0], LOGRANK)
        self.assertEqual(res["new_clones"], [])
        md = cd.render_push(res)
        self.assertIn(cd.MARKER, md)
        self.assertIn("Edits to one copy", md)
        self.assertIn(cd.decision_id_of(d["id"]), md)

    def test_fixing_both_copies_is_clean(self):
        self.commit({LOGRANK: icen("InferenceSurvivalLogRank", "logrank1", "logrank", True),
                     GEHAN: icen("InferenceSurvivalGehanWilcox", "wmw", "gw", True)}, "fix both")
        res = self.check()
        self.assertEqual((res["new_divergences"], res["new_clones"]), ([], []))
        self.assertIn("No new clones", cd.render_push(res))

    def test_comment_only_edit_is_ignored(self):
        self.commit({LOGRANK: icen("InferenceSurvivalLogRank", "logrank1", "logrank", False).replace(
            "\t\t\tL = ifelse", "\t\t\t# why\n\t\t\tL = ifelse")}, "comment")
        res = self.check()
        self.assertEqual(res["significant"], [])
        self.assertIn("No R, C++ or Python code changed", cd.render_push(res))

    def test_new_copy_is_a_new_clone(self):
        self.commit({"R/EDI/R/inference_survival_new.R": icen("InferenceSurvivalNew", "wmw", "nw", False)}, "copy")
        res = self.check()
        self.assertGreaterEqual(len(res["new_clones"]), 1)
        self.assertTrue(all("inference_survival_new.R" in (f["a"][0] + f["b"][0]) for f in res["new_clones"]))
        self.assertEqual(res["new_divergences"], [])


# ---------------------------------------------------------------- weekly stages

class TestWeekly(Lowered):
    def setUp(self):
        super().setUp()
        write(self.tmp / "repo", {LOGRANK: icen("InferenceSurvivalLogRank", "logrank1", "logrank", True),
                                  GEHAN: icen("InferenceSurvivalGehanWilcox", "wmw", "gw", False),
                                  UNRELATED: OTHER_TEXT})
        self.repo = self.tmp / "repo"
        self.notes = ac.Notes(self.tmp / "notes", "code-duplication")
        self.spec = ac.spec_of(cd)

    def ctx(self, error=False, scope="auto"):
        c = ac.Context(self.spec, self.repo, self.notes, self.tmp / "work", scope=scope, sha="abc123")
        if error:
            c._dup = {"families": [], "stats": {}, "error": "jscpd is not installed"}
        else:
            c._dup = {"families": fams_of(self.repo), "stats": {"min_tokens": 50, "jscpd_clones": 2, "jscpd_seconds": 0.1,
                                                                 "families": 1, "candidates": 1, "divergent": 1},
                      "error": None}
        return c

    def test_spec_prompt_schema(self):
        self.assertEqual(self.spec["report"], "issue")
        self.assertTrue(self.spec["claude"])
        prompts = REPO / ".github/prompts"
        schema = (prompts / "audit_code_duplication.schema.json").read_text()
        self.assertNotIn("'", schema)
        self.assertEqual(json.loads(schema)["properties"]["findings"]["items"]["properties"]["verdict"]["enum"],
                         list(cd.VERDICTS))
        self.assertIn("divergence_bug", (prompts / "audit_code_duplication.md").read_text())

    def test_units_then_verdicts_then_decisions(self):
        with patched(cd, "code_changed_since", lambda ctx, sha: True):
            ctx = self.ctx()
            units = cd.units(ctx)
        self.assertEqual(len(units), 1)
        uid = next(iter(units))
        self.assertIn("arm_sign", units[uid]["context"]["diff"])
        res = [{"_units": [uid], "findings": [{"unit": uid, "verdict": "divergence_bug", "text": "Gehan lacks the sign fix.",
                                                "evidence": [f"{GEHAN}:24"]}]}]
        parts = cd.apply(ctx, res, [])
        self.assertEqual(len(parts["human"]), 1)
        self.assertIn("Divergence-bug suspect", parts["human"][0]["text"])
        self.assertEqual(parts["human"][0]["unit"], uid)
        m = self.notes.manifest()
        self.assertEqual((m["code_sha"], m["backlog"]), ("abc123", 0))
        # Next run: the candidate has a verdict, so no unit; the decision is still listed.
        with patched(cd, "code_changed_since", lambda ctx, sha: True):
            ctx = self.ctx()
            ctx.manifest = self.notes.manifest()
            self.assertEqual(cd.units(ctx), {})
            parts = cd.apply(ctx, [], [])
        self.assertEqual(len(parts["human"]), 1)
        # A failed detection lists it again rather than resolving it.
        parts = cd.apply(self.ctx(error=True), [], [])
        self.assertEqual(len(parts["human"]), 1)
        self.assertIn("Detection did not run", parts["summary"])
        self.assertEqual(self.notes.manifest()["code_sha"], "abc123")

    def test_intentional_is_information_only(self):
        with patched(cd, "code_changed_since", lambda ctx, sha: True):
            ctx = self.ctx()
            uid = next(iter(cd.units(ctx)))
        parts = cd.apply(ctx, [{"findings": [{"unit": uid, "verdict": "intentional", "text": "fast path", "evidence": []}]}], [])
        self.assertEqual(parts["human"], [])
        self.assertIn("judged intentional: 1", parts["summary"])

    def test_no_code_change_and_no_backlog_skips_claude(self):
        with patched(cd, "code_changed_since", lambda ctx, sha: False):
            ctx = self.ctx()
            ctx.manifest = {"units": {}, "code_sha": "abc123", "backlog": 0}
            self.assertEqual(cd.units(ctx), {})
            self.assertIn("no R/C++/Python code change", ctx._dup["skipped"])
            ctx = self.ctx()
            ctx.manifest = {"units": {}, "code_sha": "abc123", "backlog": 3}
            self.assertEqual(len(cd.units(ctx)), 1)        # a backlog is worked off even with no change
            ctx = self.ctx(scope="all")
            ctx.manifest = {"units": {}, "code_sha": "abc123", "backlog": 0}
            self.assertEqual(len(cd.units(ctx)), 1)

    def test_dismissed_is_never_a_unit(self):
        with patched(cd, "code_changed_since", lambda ctx, sha: True):
            uid = next(iter(cd.units(self.ctx())))
            (self.repo / "R/package_metadata/audits").mkdir(parents=True)
            (self.repo / ac.DISMISSED_FILE).write_text(f"- `{cd.decision_id_of(uid)}`: deliberate (2026-11-18)\n")
            self.assertEqual(cd.units(self.ctx()), {})


class TestWorkflows(unittest.TestCase):
    def test_schedule_and_switch(self):
        wf = REPO / ".github/workflows"
        weekly = (wf / "audit-code-duplication.yml").read_text()
        self.assertIn('cron: "7 7 * * 0"', weekly)
        self.assertIn("name: audit · weekly · code-duplication", weekly)
        push = (wf / "code-duplication-push.yml").read_text()
        self.assertIn('FAIL_ON_DIVERGENCE: "false"', push)
        self.assertIn("pull_request:", push)
        self.assertIn(cd.MARKER, push)
        self.assertNotIn("code_duplication", (REPO / "scripts/pre-push").read_text())


if __name__ == "__main__":
    unittest.main(verbosity=1)
