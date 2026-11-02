# mirai pool lifecycle spec

`MiraiLifecycle.tla` models how `Inference$par_lapply()` drives the mirai pool:
repeated calls to `ensure_mirai_daemons()` then `run_mirai_window()`, while
daemons die or wedge at any moment. It is optional. The
`.github/workflows/formal-spec-tlc.yml` workflow runs it, but that is not a
required check, it is not in the pre-push hook, and contributors do not need
TLA+.

TLC checks this model, not the R code, so a green run does not show the R code
still matches. The workflow also triggers on `R/EDI/R/globals.R` only as a
prompt: if you change `ensure_mirai_daemons()`, `start_mirai_daemons_bounded()`
or `run_mirai_window()`, update the spec by hand.

## Running it

Needs Java and `tla2tools.jar` from the
[v1.7.4 release](https://github.com/tlaplus/tlaplus/releases/tag/v1.7.4), the
version CI pins.
This runs every config and checks each gives the result below:

```sh
bash run_configs.sh /path/to/tla2tools.jar
```

| Config | Change from the current code | Expected result |
|---|---|---|
| `MiraiLifecycle.cfg` | none | all properties hold |
| `MiraiLifecycle_old_guard.cfg` | old `n_running != n` reuse test | `NoChurn` violated |
| `MiraiLifecycle_no_error_check.cfg` | no `errorValue` check in the window | `NoLostResults` violated |
| `MiraiLifecycle_wedged.cfg` | one daemon stays connected but never answers | all properties hold |
| `MiraiLifecycle_no_stall_timeout.cfg` | wedged daemon, no `stall_secs` limit | `Termination` violated |

The `old_guard`, `no_error_check` and `no_stall_timeout` configs each put back a
bug, which confirms the spec can detect it.

## What it assumes about mirai

- A chunk on a daemon that dies resolves at once to an `errorValue`, while other
  daemons live on. Observed with mirai 2.7.2 by killing a daemon mid-task.
- `mirai::status()$connections` drops when a daemon dies, and a wedged daemon
  still counts as connected.
- The stall timer may fire on a chunk that is merely slow. The spec shows that
  ends in an error, not a wrong result; it does not show that
  `EDI.mirai_stall_timeout_secs` is long enough for real chunks.
- Stopping the pool takes a wedged daemon out of the pool, which is all the spec
  needs. The process exits through mirai's `autoexit`, which its docs say forces
  termination after a 200ms grace period. A daemon sleeping in R exited this way.
  One frozen with `SIGSTOP` did not, because `autoexit` runs inside that process.
- The launcher's wait, including its 90s deadline and single relaunch, is one
  step in which any number of daemons from 0 to `Global` connect.

## Not modeled

- `SimulationFramework$run()`, which may grow the pool and passes
  `always_configure = TRUE`. Its polling goes through the same
  `poll_mirai_tasks()` as `par_lapply`, but with a 5s liveness throttle and a
  rolling window that can be twice `num_cores`.
- Fork clusters, and nanonext internals. The 2026 CI hang was an unbounded wait
  inside nanonext's C code, which this spec cannot see.
