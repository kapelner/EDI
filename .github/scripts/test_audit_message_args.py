#!/usr/bin/env python3
"""Checks for the message argument audit (audits/message_args.py). Stdlib only, no network.

v1.0.6-TODO-96: every argument name a stop() / warning() / message() string quotes must be an argument
of the code that can raise it. The fixture rebuilds the v1.0.6-TODO-73 shape: a blocking component
whose message says "Set equal_block_sizes = FALSE", composed by one class that takes that argument
and one that does not.
"""
import datetime as dt
import shutil
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
import audit_common as ac  # noqa: E402
from audits import message_args as ma  # noqa: E402

NOW = dt.datetime(2026, 11, 18, 7, tzinfo=dt.timezone.utc)

FILES = {
    "R/EDI/NAMESPACE": "export(DesignBlocking)\nexport(DesignBlockedCluster)\nexport(InferenceFoo)\n"
                       "export(InferenceBar)\nexport(set_cores)\n",
    # the component source and its registration (as in design_blocking_abstract.R and
    # design_component_registry.R)
    "R/EDI/R/design_blocking_abstract.R": (
        "DESIGN_BLOCKING_STRUCTURE_PUBLIC = list(\n"
        "\tget_block_ids = function() private$m\n"
        ")\n"
        "DESIGN_BLOCKING_STRUCTURE_PRIVATE = list(\n"
        "\tequal_block_sizes = TRUE,\n"
        "\texact_num_blocks = FALSE,\n"
        "\tget_strata_keys = function(){\n"
        "\t\tif (isTRUE(private$exact_num_blocks)) stop(\"exact_num_blocks = TRUE but the blocks differ.\")\n"
        "\t\tif (isTRUE(private$equal_block_sizes)) {\n"
        "\t\t\tstop(\"equal_block_sizes = TRUE but the strata produced unequal block sizes. \",\n"
        "\t\t\t\t\"Set equal_block_sizes = FALSE to allow unequal blocks.\")\n"
        "\t\t}\n"
        "\t}\n"
        ")\n"),
    "R/EDI/R/design_component_registry.R": (
        "populate_design_component_registry = function() {\n"
        "\tregister_design_component(DesignComponent(\n"
        "\t\tname = \"BlockingStructure\",\n"
        "\t\tdependencies = character(),\n"
        "\t\tpublic = DESIGN_BLOCKING_STRUCTURE_PUBLIC[c(\"get_block_ids\")],\n"
        "\t\tprivate = DESIGN_BLOCKING_STRUCTURE_PRIVATE[c(\"get_strata_keys\")]\n"
        "\t))\n"
        "}\n"),
    "R/EDI/R/design.R": (
        "Design = R6::R6Class(\"Design\",\n"
        "\tpublic = list(\n"
        "\t\tinitialize = function(n = NULL, prob_T = 0.5) {\n"
        "\t\t\tif (prob_T != 0.5) stop(\"this design needs prob_T = 0.5\")\n"
        "\t\t},\n"
        "\t\tadd_subject_response = function(t, y, y_R = Inf) NULL\n"
        "\t)\n"
        ")\n"
        "DesignBlocking = define_design_class(\n"
        "\tclassname = \"DesignBlocking\",\n"
        "\tinherit = Design,\n"
        "\tcomponents = \"BlockingStructure\",\n"
        "\tpublic = list(\n"
        "\t\tinitialize = function(strata_cols, equal_block_sizes = TRUE, exact_num_blocks = FALSE, ...) {\n"
        "\t\t\tsuper$initialize(...)\n"
        "\t\t}\n"
        "\t)\n"
        ")\n"
        "DesignBlockedCluster = define_design_class(\n"
        "\tclassname = \"DesignBlockedCluster\",\n"
        "\tinherit = Design,\n"
        "\tcomponents = c(\"BlockingStructure\"),\n"
        "\tpublic = list(\n"
        "\t\tinitialize = function(strata_cols, cluster_col, n = NULL) {\n"
        "\t\t\tif (is.null(cluster_col)) stop(\"Pass cluster_col = 'id' (the `cluster_col = ` argument).\")\n"
        "\t\t}\n"
        "\t)\n"
        ")\n"),
    "R/EDI/R/inference.R": (
        "EDI_COMPONENT_SPECS = list(\n"
        "\tBoot = list(status = \"active\", source_name = \"InferenceBootSource\", dependencies = character())\n"
        ")\n"
        "InferenceBootSource = list(\n"
        "\tpublic = list(\n"
        "\t\tcompute_boot_ci = function(B = 501, alpha = 0.05) {\n"
        "\t\t\tif (B < 10) stop(\"Use B = 501 or more.\")\n"
        "\t\t\tif (alpha > 1) stop(\"Set `level = 0.95` instead.\")\n"
        "\t\t\tcheck_draws(B)\n"
        "\t\t}\n"
        "\t)\n"
        ")\n"
        "Inference = R6::R6Class(\"Inference\",\n"
        "\tpublic = list(\n"
        "\t\tinitialize = function(des_obj, verbose = FALSE) {\n"
        "\t\t\tif (!verbose) message(\"quiet; pass verbose = TRUE to see progress, see the y_R = Inf rows\")\n"
        "\t\t},\n"
        "\t\tcompute_estimate = InferenceBootSource$public$compute_boot_ci,\n"
        "\t\trun = function() stop(\"Rerun with num_cores = 1, or call set_cores(num_cores = 1).\")\n"
        "\t)\n"
        ")\n"
        "InferenceFoo = define_inference_class(\n"
        "\tclassname = \"InferenceFoo\",\n"
        "\tinherit = Inference,\n"
        "\tcomponents = \"Boot\",\n"
        "\tpublic = list()\n"
        ")\n"
        "InferenceBar = define_inference_class(\n"
        "\tclassname = \"InferenceBar\",\n"
        "\tinherit = Inference,\n"
        "\tpublic = list(\n"
        "\t\tfit = function(estimate_only = FALSE, tol = 1e-8) {\n"
        "\t\t\twarning(sprintf(\"with tol = %g; suppress with suppressWarnings(expr, classes = 'x')\", 1),\n"
        "\t\t\t\tcall. = FALSE)\n"
        "\t\t\tstop('use solver_args$max_iter or raise max_iter = 50')\n"
        "\t\t}\n"
        "\t)\n"
        ")\n"),
    "R/EDI/R/helpers.R": (
        "check_draws = function(x) {\n"
        "\tif (x > 1e6) stop(\"Set B = 1000 or fewer.\")\n"
        "\tif (x < 0) stop(\"Set draws = 10.\")\n"
        "}\n"
        "set_cores = function(num_cores) invisible(num_cores)\n"
        "msg_helper = function(value) {\n"
        "\tstop(r\"(raw string: set raw_arg = TRUE)\")\n"
        "\t# stop(\"commented_arg = TRUE\") is a comment\n"
        "\tx$stop(\"not_a_message = TRUE\")\n"
        "}\n"),
}


def build(root):
    for rel, text in FILES.items():
        p = root / rel
        p.parent.mkdir(parents=True, exist_ok=True)
        p.write_text(text)


class Tokenizer(unittest.TestCase):
    def test_strings_comments_and_raw_strings(self):
        toks = ma.tokenize('x = "a \\"b\\" c" # stop("no")\ny = r"(raw "q")" ; z = `odd name`\n')
        self.assertEqual([t.val for t in toks if t.kind == "str"], ['a "b" c', 'raw "q"'])
        self.assertIn("odd name", [t.val for t in toks if t.kind == "id"])
        self.assertNotIn("no", [t.val for t in toks])

    def test_quoted_names(self):
        q = lambda s: [n for n, _ in ma.quoted_names([s])]
        self.assertEqual(q("Set equal_block_sizes = FALSE to allow"), ["equal_block_sizes"])
        self.assertEqual(q("use `B = 501`, \\code{alpha = 0.1} or 'type = \"x\"'"), ["B", "alpha", "type"])
        self.assertEqual(sorted(q("the `tol` argument; argument 'alpha'")), ["alpha", "tol"])
        self.assertEqual(q("got n = ", ), [])                      # a value pasted from a variable
        self.assertEqual(q("n == 3 and a + b = c"), [])
        self.assertEqual(q("suppressWarnings(expr, classes = \"x\")"), [])
        self.assertEqual(q("raise solver_args$max_iter; max_iter = 3 now"), [])
        self.assertEqual(q("call. = FALSE"), [])
        self.assertEqual(q("`required_packages` must be a character vector"), [])   # no `=`: not read


class Findings(unittest.TestCase):
    def setUp(self):
        self.root = Path(tempfile.mkdtemp())
        build(self.root)
        self.found = ma.findings(self.root)
        self.by = {(x["file"].rsplit("/", 1)[-1], x["name"]): x for x in self.found}

    def tearDown(self):
        shutil.rmtree(self.root, ignore_errors=True)

    def test_component_message_flags_the_class_without_the_argument(self):
        # v1.0.6-TODO-73: DesignBlockedCluster composes BlockingStructure but has no equal_block_sizes.
        x = self.by[("design_blocking_abstract.R", "equal_block_sizes")]
        self.assertEqual(x["missing_in"], ["DesignBlockedCluster"])
        self.assertTrue(x["some"])
        self.assertEqual(x["function"], "get_strata_keys")
        self.assertEqual(x["line"], 10)
        self.assertIn("`DesignBlockedCluster`", ma.describe(x))
        self.assertIn("1 of the 2 exported classes", ma.describe(x))

    def test_shared_state_without_advice_is_not_reported(self):
        # "exact_num_blocks = TRUE but ..." states a value only DesignBlocking can set.
        self.assertNotIn(("design_blocking_abstract.R", "exact_num_blocks"), self.by)

    def test_formals_parents_and_design_arguments_are_accepted(self):
        for key in [("design.R", "prob_T"), ("design.R", "cluster_col"), ("inference.R", "verbose"),
                    ("inference.R", "y_R"), ("inference.R", "B"), ("helpers.R", "B"), ("inference.R", "tol"),
                    ("inference.R", "classes"), ("inference.R", "max_iter")]:
            self.assertNotIn(key, self.by, key)

    def test_unknown_names_are_reported(self):
        self.assertEqual(self.by[("inference.R", "level")]["missing_in"], ["InferenceFoo"])
        self.assertFalse(self.by[("inference.R", "level")]["some"])
        self.assertEqual(sorted(self.by[("inference.R", "num_cores")]["missing_in"]), ["InferenceBar", "InferenceFoo"])
        helper = self.by[("helpers.R", "draws")]
        self.assertEqual(helper["missing_in"], [])               # a helper: no class to name
        self.assertIn("not an argument of that function", ma.describe(helper))
        self.assertIn(("helpers.R", "raw_arg"), self.by)          # raw strings are read

    def test_comments_and_methods_named_stop_are_skipped(self):
        names = {n for _, n in self.by}
        self.assertNotIn("commented_arg", names)
        self.assertNotIn("not_a_message", names)

    def test_class_surface(self):
        pkg = ma.Package(self.root)
        self.assertEqual(pkg.init_formals("DesignBlocking"),
                         {"strata_cols", "equal_block_sizes", "exact_num_blocks", "n", "prob_T"})
        self.assertEqual(pkg.init_formals("DesignBlockedCluster"), {"strata_cols", "cluster_col", "n"})
        self.assertEqual(pkg.hosts_of_source("DESIGN_BLOCKING_STRUCTURE_PRIVATE"),
                         ["DesignBlockedCluster", "DesignBlocking"])
        self.assertEqual(pkg.hosts_of_source("InferenceBootSource"), ["InferenceFoo"])
        self.assertEqual(pkg.public_of("Inference")["compute_estimate"], ["B", "alpha"])   # pinned method
        self.assertIn("compute_boot_ci", pkg.surface("InferenceFoo"))
        self.assertNotIn("compute_boot_ci", pkg.surface("InferenceBar"))
        self.assertNotIn("get_strata_keys", pkg.surface("DesignBlocking"))                # private list


class Stages(unittest.TestCase):
    def setUp(self):
        self.root = Path(tempfile.mkdtemp())
        build(self.root)
        notes = ac.Notes(self.root / "notes", "message-args")
        self.ctx = ac.Context(ac.spec_of(ma), self.root, notes, self.root / "work", now=NOW)

    def tearDown(self):
        shutil.rmtree(self.root, ignore_errors=True)

    def test_spec(self):
        spec = ac.spec_of(ma)
        self.assertEqual((spec["name"], spec["report"], spec["claude"], spec["label"]),
                         ("message-args", "issue", False, "audit-message-args"))
        self.assertEqual(ma.mechanical(self.ctx), [])

    def test_apply_reports_stable_decisions_and_edits_nothing(self):
        before = {p: p.read_text() for p in self.root.rglob("*.R")}
        parts = ma.apply(self.ctx, [], [])
        self.assertEqual({p: p.read_text() for p in self.root.rglob("*.R")}, before)
        self.assertEqual(parts["applied"], [])
        self.assertEqual(parts["proposed"], [])
        units = [h["unit"] for h in parts["human"]]
        self.assertIn("R/EDI/R/design_blocking_abstract.R::get_strata_keys::equal_block_sizes", units)
        self.assertEqual(len(units), len(set(units)))
        self.assertTrue(all(h["key"] == "unknown-argument" for h in parts["human"]))
        self.assertIn(f"{len(units)} quoted argument name(s)", parts["summary"])
        # the id stays the same when the line moves
        a = ac.decision_id("message-args", units[0], "unknown-argument", parts["human"][0]["text"])
        self.assertEqual(a, ac.decision_id("message-args", units[0], "unknown-argument", "other text"))

    def test_dismissed_ids_drop_out(self):
        parts = ma.apply(self.ctx, [], [])
        ids = [ac.decision_id("message-args", h["unit"], h["key"], h["text"]) for h in parts["human"]]
        open_, lines, counts = ac.track_decisions("message-args", parts["human"], {}, set(), set(), set(),
                                                  {ids[0]}, NOW.isoformat())
        self.assertEqual(counts["dismissed"], 1)
        self.assertEqual(len(lines), len(ids) - 1)

    def test_workflow_and_status_list(self):
        wf_dir = Path(__file__).resolve().parents[1] / "workflows"
        wf = (wf_dir / "audit-message-args.yml").read_text()
        self.assertIn("audit: message-args", wf)
        self.assertIn("name: audit · weekly · message-args", wf)
        self.assertIn('- "audit · weekly · message-args"', (wf_dir / "audit-status.yml").read_text())


class RealTree(unittest.TestCase):
    """The audit over EDI's own sources still finds v1.0.6-TODO-73 (skipped outside the repo)."""

    def test_finds_todo_73(self):
        repo = Path(__file__).resolve().parents[2]
        if not (repo / "R/EDI/R/design_blocking_abstract.R").exists():
            self.skipTest("not in the EDI repository")
        hit = [x for x in ma.findings(repo) if x["name"] == "equal_block_sizes"
               and x["file"] == "R/EDI/R/design_blocking_abstract.R"]
        if not hit:
            self.skipTest("the message no longer suggests equal_block_sizes (v1.0.6-TODO-73 fixed?)")
        self.assertIn("DesignFixedBlockedCluster", hit[0]["missing_in"])
        self.assertNotIn("DesignFixedBlocking", hit[0]["missing_in"])


if __name__ == "__main__":
    unittest.main(verbosity=1)
