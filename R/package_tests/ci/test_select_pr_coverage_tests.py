#!/usr/bin/env python3
"""Pure regression checks for select_pr_coverage_tests.py: stdlib only, no git, no R.
Builds a synthetic repo (manifest + source + test files) in a temp dir, mirroring
test_check_coverage_floor.py's style."""
import json
import subprocess
import sys
import tempfile
from pathlib import Path

SCRIPT = Path(__file__).parent / "select_pr_coverage_tests.py"
B = "R/package_tests/testthat_bulk/"
F = "R/EDI/tests/testthat/"


def make_repo(root):
	for d in ("R/EDI/tests/testthat", "R/package_tests/testthat_bulk", "R/EDI/R", "R/EDI/src", "R/package_tests/ci"):
		(root / d).mkdir(parents=True)

	# Changed R source: a define_inference_class() class, a helper, and a name that
	# will be mentioned by EVERY bulk file (must be dropped as ubiquitous).
	(root / "R/EDI/R/inference_widget_regr.R").write_text(
		'InferenceWidgetRegr = define_inference_class(\n'
		'\tclassname = "InferenceWidgetRegr",\n'
		'\tpublic = list(initialize = function(x) x)\n'
		')\n'
		'widget_helper_fn = function(a) a + 1\n'
		'ubiquitous_helper = function() NULL\n'
	)
	# Changed C++ kernel with one exported function.
	(root / "R/EDI/src/fast_widget_kernel.cpp").write_text(
		'#include <RcppEigen.h>\n'
		'// [[Rcpp::export]]\n'
		'Eigen::VectorXd fast_widget_kernel_cpp(const Eigen::Map<Eigen::MatrixXd>& X) {\n'
		'  return X.col(0);\n}\n'
	)
	# Generated file: enumerates a kernel that otherwise matches an unrelated test.
	(root / "R/EDI/R/RcppExports.R").write_text(
		'generated_noise_kernel_cpp <- function(X) {\n    .Call(`_EDI_generated_noise_kernel_cpp`, X)\n}\n'
	)

	for f in ("test-a.R", "test-b.R"):
		(root / "R/EDI/tests/testthat" / f).write_text("test_that('x', expect_true(TRUE))\n")

	bulk = {
		# filename matches the kebab-cased source stem -> strong signal
		"test-fast-widget-kernel-shape-reference.R": "ubiquitous_helper(); test_that('k', expect_true(TRUE))\n",
		# content mentions the class and the kernel -> two token hits
		"test-widget-golden.R": "ubiquitous_helper(); InferenceWidgetRegr$new(d); fast_widget_kernel_cpp(X)\n",
		# content mentions only the helper -> one hit
		"test-helper-user.R": "ubiquitous_helper(); widget_helper_fn(3)\n",
		# substring-but-not-word match must NOT count
		"test-unrelated-substring.R": "ubiquitous_helper(); InferenceWidgetRegrExtended$new(d)\n",
		# mentions only the GENERATED file's kernel -> must NOT be selected
		"test-generated-only.R": "ubiquitous_helper(); generated_noise_kernel_cpp(X)\n",
		# completely unrelated
		"test-unrelated.R": "ubiquitous_helper(); test_that('u', expect_true(TRUE))\n",
		# a bulk test the PR itself edits -> ranked first even with zero hits
		"test-edited-by-pr.R": "ubiquitous_helper(); test_that('e', expect_true(TRUE))\n",
	}
	for name, body in bulk.items():
		(root / "R/package_tests/testthat_bulk" / name).write_text(body)

	est = {
		"test-fast-widget-kernel-shape-reference.R": 100,
		"test-widget-golden.R": 500,
		"test-helper-user.R": 400,
		"test-unrelated-substring.R": 10,
		"test-generated-only.R": 10,
		"test-unrelated.R": 10,
		"test-edited-by-pr.R": 50,
	}
	rows = ["test_file,runtime_tier,estimated_seconds,estimate_source"]
	for f in ("test-a.R", "test-b.R"):
		rows.append(f"{F}{f},coverage,30,bootstrap")
	for name, seconds in est.items():
		rows.append(f"{B}{name},coverage,{seconds},bootstrap")
		rows.append(f"{B}{name},correctness,{seconds},bootstrap")
	(root / "R/package_tests/ci/test_runtimes.csv").write_text("\n".join(rows) + "\n")


def run(root, changed, budget):
	changed_file = root / "changed.txt"
	changed_file.write_text("\n".join(changed) + "\n")
	out = root / "out"
	res = subprocess.run(
		[sys.executable, str(SCRIPT), "--root", str(root), "--changed-files-from", str(changed_file),
		 "--output", str(out), "--budget-seconds", str(budget)],
		capture_output=True, text=True,
	)
	assert res.returncode == 0, res.stderr + res.stdout
	shard = json.loads((out / "shard-0.json").read_text())
	report = json.loads((out / "selection_report.json").read_text())
	return shard, report, res.stdout


with tempfile.TemporaryDirectory() as tmp:
	root = Path(tmp)
	make_repo(root)
	changed = [
		"R/EDI/R/inference_widget_regr.R",
		"R/EDI/src/fast_widget_kernel.cpp",
		"R/EDI/R/RcppExports.R",
		B + "test-edited-by-pr.R",
		"README.md",
	]

	# Generous budget: everything related is selected, nothing unrelated is.
	shard, report, out = run(root, changed, budget=10_000)
	files = shard["test_files"]
	assert set(shard) == {"shard", "estimated_seconds", "test_files"}, shard.keys()
	assert F + "test-a.R" in files and F + "test-b.R" in files
	assert B + "test-edited-by-pr.R" in files, "PR-edited bulk test must run"
	assert B + "test-fast-widget-kernel-shape-reference.R" in files, "filename-stem match"
	assert B + "test-widget-golden.R" in files, "class + kernel token match"
	assert B + "test-helper-user.R" in files, "top-level helper token match"
	assert B + "test-unrelated-substring.R" not in files, "substring is not a word match"
	assert B + "test-generated-only.R" not in files, "RcppExports.R must contribute no names"
	assert B + "test-unrelated.R" not in files, "ubiquitous name must not select files"
	assert abs(shard["estimated_seconds"] - (60 + 50 + 100 + 500 + 400)) < 1e-9, shard["estimated_seconds"]
	tokens = set(report["tokens"])
	assert {"InferenceWidgetRegr", "widget_helper_fn", "fast_widget_kernel_cpp",
	        "inference_widget_regr", "fast-widget-kernel"} <= tokens, tokens
	assert "initialize" not in tokens, "stoplisted generic names must not become tokens"
	assert "generated_noise_kernel_cpp" not in tokens
	assert report["generated_files_ignored"] == ["R/EDI/R/RcppExports.R"], report["generated_files_ignored"]
	assert report["tokens_dropped_as_ubiquitous"] == ["ubiquitous_helper"], report["tokens_dropped_as_ubiquitous"]
	# Ranking: the PR's own edited test first, then filename+kernel golden, then the one-hit helper.
	order = [e["test_file"] for e in report["bulk_selected"]]
	assert order[0] == B + "test-edited-by-pr.R", order
	assert order.index(B + "test-widget-golden.R") < order.index(B + "test-helper-user.R"), order
	assert report["bulk_selected"][0]["kind"] == "changed_test"

	# Tight budget shared by changed + related: the edited test (50 s) is placed first,
	# the filename-match file (100 s) still fits, the 500 s/400 s files are reported dropped.
	shard, report, out = run(root, changed, budget=150)
	files = shard["test_files"]
	assert F + "test-a.R" in files
	assert B + "test-edited-by-pr.R" in files and B + "test-fast-widget-kernel-shape-reference.R" in files
	assert B + "test-widget-golden.R" not in files and B + "test-helper-user.R" not in files
	dropped = {e["test_file"] for e in report["bulk_dropped_for_budget"]}
	assert dropped == {B + "test-widget-golden.R", B + "test-helper-user.R"}, dropped
	assert report["bulk_spent_seconds"] <= 150

	# A budget too small even for the PR's own edited test: it is dropped but LOUDLY --
	# flagged as a changed test in the report and in the console summary.
	shard, report, out = run(root, changed, budget=40)
	assert B + "test-edited-by-pr.R" not in shard["test_files"]
	assert any(e["kind"] == "changed_test" for e in report["bulk_dropped_for_budget"])
	assert "INCLUDING 1 tests this PR edits" in out, out
	# The fast tier is never subject to the budget.
	assert F + "test-a.R" in shard["test_files"] and F + "test-b.R" in shard["test_files"]

	# No source change at all (docs-only / test-only PR): fast tier + edited bulk test only.
	shard, report, out = run(root, ["README.md", B + "test-edited-by-pr.R"], budget=10_000)
	assert sorted(shard["test_files"]) == sorted([F + "test-a.R", F + "test-b.R", B + "test-edited-by-pr.R"]), shard
	assert report["tokens"] == [] and all(e["kind"] == "changed_test" for e in report["bulk_selected"])

	# A change ONLY to a generated file selects nothing beyond the fast tier.
	shard, report, out = run(root, ["R/EDI/R/RcppExports.R"], budget=10_000)
	assert sorted(shard["test_files"]) == [F + "test-a.R", F + "test-b.R"], shard
	assert report["changed_source_files"] == [] and report["generated_files_ignored"] == ["R/EDI/R/RcppExports.R"]

print("select_pr_coverage_tests regression checks passed.")
