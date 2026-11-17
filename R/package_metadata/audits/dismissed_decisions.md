# Dismissed audit decisions

The scheduled audits (`.github/workflows/audit-*.yml`) list each open decision under "Decisions for you"
with an id such as `rd-d1a2b3c4d`, and keep listing it, run after run, until a run no longer finds it,
an open release TODO cites the id, or the id is listed here. Add one line per dismissed decision, with
the reason, so the next reader knows why it was let go:

- `<audit>-d<hex>`: reason (date)

