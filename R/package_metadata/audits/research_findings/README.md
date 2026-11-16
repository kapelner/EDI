# Algorithm research findings

One file per research run (`<date>-run<run id>.md`, plus `<date>-run<run id>-searches.md`: what each agent actually searched; before 2026-11-17 files were named `<date>.md`), written by the `research-pr` job of
`.github/workflows/algorithm-audit-drift.yml` and delivered as a pull request together with
the inventory updates it could apply.

- **Faster-algorithm findings are unverified** web claims (speedups are the sources' numbers,
  not measurements). To act on one, confirm it (benchmark or the A/B harness), add a TODO to
  the right `future_release_plans/release_vX_Y_Z.md` citing this file, then annotate the
  finding here with that TODO (`TODO-<n>-v<version>`).
- **"Needs a human"** lists inventory corrections the job could not apply mechanically; apply
  them to `../algorithm_inventory.csv` by hand.
- Findings flagged "may affect the verdict" need a re-review of that audit row
  (`../../new_feature_plans/v1_0_5/algorithm_audit_runbook.md`, "Re-review procedure").

Merging a research PR means its findings file has been read and its inventory changes accepted.
