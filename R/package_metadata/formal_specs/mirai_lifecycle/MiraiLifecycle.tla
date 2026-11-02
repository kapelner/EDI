-------------------------- MODULE MiraiLifecycle --------------------------
(***************************************************************************)
(* The mirai pool as driven by Inference$par_lapply(): repeated calls that *)
(* each run ensure_mirai_daemons(global) and then run_mirai_window(), while *)
(* daemons die or wedge at any moment. Models R/EDI/R/globals.R and the     *)
(* mirai branch of R/EDI/R/inference_all_abstract.R. It checks this model,  *)
(* not the R code: change one and update the other. Assumptions about      *)
(* mirai itself are listed in README.md.                                    *)
(***************************************************************************)
EXTENDS Naturals

CONSTANTS
    Global,       \* size par_lapply asks ensure_mirai_daemons for
    Chunks,       \* chunks per par_lapply call
    Window,       \* run_mirai_window's limit on chunks in flight
    MaxCalls,     \* par_lapply calls explored
    MaxDeaths,    \* daemon deaths explored
    MaxWedges,    \* daemons that stay connected but never answer
    OldGuard,     \* TRUE models the old `n_running != n` reuse test
    CheckErrors,  \* FALSE drops run_mirai_window's errorValue check
    StallTimeout  \* FALSE drops run_mirai_window's stall_secs limit

VARIABLES
    conns,        \* connected daemons, as mirai::status() reports them
    target,       \* edi_env$mirai_pool_target; 0 stands for NULL
    pc,           \* where the host process is
    attempt,      \* ensure_mirai_daemons' attempt counter
    calls,        \* par_lapply calls started
    pending,      \* chunks not yet submitted
    inflight,     \* chunks submitted and still able to resolve
    stuck,        \* chunks on a wedged daemon, never resolving
    completed,    \* chunks that resolved with a real result
    lost,         \* a chunk died with its daemon during this call
    deaths,       \* daemon deaths so far
    wedges,       \* wedges so far
    launches,     \* launches in this call (history for NoChurn)
    clean,        \* pool unchanged since an ensure accepted it (history)
    startedClean  \* clean held at call start, no death since (history)

vars == <<conns, target, pc, attempt, calls, pending, inflight, stuck,
          completed, lost, deaths, wedges, launches, clean, startedClean>>

\* ensure_mirai_daemons: reuse a full pool, or a short one launched for n.
Reusable ==
    \/ conns = Global
    \/ /\ ~OldGuard
       /\ conns >= 1 /\ conns < Global
       /\ target = Global

Init ==
    /\ conns \in 0..Global              \* whatever set_num_cores left behind
    /\ target = IF conns > 0 THEN Global ELSE 0
    /\ pc = "start"
    /\ attempt = 1
    /\ calls = 0
    /\ pending = 0 /\ inflight = 0 /\ stuck = 0 /\ completed = 0
    /\ lost = FALSE
    /\ deaths = 0 /\ wedges = 0
    /\ launches = 0
    /\ clean = (conns > 0)
    /\ startedClean = FALSE

(***************************************************************************)
(* Host steps                                                              *)
(***************************************************************************)
StartCall ==
    /\ pc = "start"
    /\ IF calls = MaxCalls
       THEN /\ pc' = "finished"
            /\ UNCHANGED <<calls, attempt, pending, inflight, stuck, completed,
                           lost, launches, startedClean>>
       ELSE /\ pc' = "check"
            /\ calls' = calls + 1
            /\ attempt' = 1
            /\ pending' = Chunks
            /\ inflight' = 0 /\ stuck' = 0 /\ completed' = 0
            /\ lost' = FALSE
            /\ launches' = 0
            /\ startedClean' = clean
    /\ UNCHANGED <<conns, target, deaths, wedges, clean>>

Check ==
    /\ pc = "check"
    /\ IF Reusable
       THEN /\ pc' = "window"
            /\ clean' = TRUE
            /\ conns' = conns
       ELSE /\ pc' = "launch"            \* daemons(0), then the launcher
            /\ clean' = FALSE
            /\ conns' = 0
    /\ UNCHANGED <<target, attempt, calls, pending, inflight, stuck, completed,
                   lost, deaths, wedges, launches, startedClean>>

\* start_mirai_daemons_bounded: any number may connect before its deadline.
\* Zero is its stop(), which attempt 1 catches and retries.
Launch ==
    /\ pc = "launch"
    /\ \E got \in 0..Global :
        /\ conns' = got
        /\ target' = IF got >= 1 THEN Global ELSE 0
        /\ launches' = launches + 1
        /\ IF got >= 1
           THEN /\ pc' = "setup" /\ attempt' = attempt
           ELSE IF attempt = 1
                THEN /\ pc' = "check" /\ attempt' = 2
                ELSE /\ pc' = "raised" /\ attempt' = attempt
    /\ UNCHANGED <<calls, pending, inflight, stuck, completed, lost, deaths,
                   wedges, clean, startedClean>>

SetupOk ==
    /\ pc = "setup"
    /\ conns >= 1
    /\ pc' = "window"
    /\ clean' = TRUE
    /\ UNCHANGED <<conns, target, attempt, calls, pending, inflight, stuck,
                   completed, lost, deaths, wedges, launches, startedClean>>

\* settle_mirai_tasks returned NULL (daemons gone or 60s), or none alive.
SetupFail ==
    /\ pc = "setup"
    /\ conns' = 0
    /\ target' = 0
    /\ IF attempt = 1
       THEN /\ pc' = "check" /\ attempt' = 2
       ELSE /\ pc' = "raised" /\ attempt' = attempt
    /\ UNCHANGED <<calls, pending, inflight, stuck, completed, lost, deaths,
                   wedges, launches, clean, startedClean>>

Submit ==
    /\ pc = "window"
    /\ pending > 0
    /\ inflight + stuck < Window
    /\ pending' = pending - 1
    /\ inflight' = inflight + 1
    /\ UNCHANGED <<conns, target, pc, attempt, calls, stuck, completed, lost,
                   deaths, wedges, launches, clean, startedClean>>

Complete ==
    /\ pc = "window"
    /\ inflight > 0
    /\ conns >= 1
    /\ inflight' = inflight - 1
    /\ completed' = completed + 1
    /\ UNCHANGED <<conns, target, pc, attempt, calls, pending, stuck, lost,
                   deaths, wedges, launches, clean, startedClean>>

\* mirai_daemons_alive() is FALSE with work outstanding: the helper's NULL.
AllDead ==
    /\ pc = "window"
    /\ conns = 0
    /\ inflight + stuck > 0
    /\ pc' = "raised"
    /\ UNCHANGED <<conns, target, attempt, calls, pending, inflight, stuck,
                   completed, lost, deaths, wedges, launches, clean,
                   startedClean>>

\* stall_secs elapsed with no chunk finishing. The timer cannot tell a wedged
\* daemon from a slow chunk, so this may fire on either: a false abort is an
\* error, never a wrong result. The pool goes down so the next call relaunches.
Stall ==
    /\ pc = "window"
    /\ StallTimeout
    /\ conns >= 1
    /\ inflight + stuck > 0
    /\ pc' = "raised"
    /\ conns' = 0
    /\ target' = 0
    /\ clean' = FALSE
    /\ UNCHANGED <<attempt, calls, pending, inflight, stuck, completed, lost,
                   deaths, wedges, launches, startedClean>>

WindowDone ==
    /\ pc = "window"
    /\ pending = 0 /\ inflight = 0 /\ stuck = 0
    /\ pc' = IF lost /\ CheckErrors THEN "raised" ELSE "returned"
    /\ UNCHANGED <<conns, target, attempt, calls, pending, inflight, stuck,
                   completed, lost, deaths, wedges, launches, clean,
                   startedClean>>

Report ==
    /\ pc \in {"returned", "raised"}
    /\ pc' = "start"
    /\ UNCHANGED <<conns, target, attempt, calls, pending, inflight, stuck,
                   completed, lost, deaths, wedges, launches, clean,
                   startedClean>>

Host ==
    \/ StartCall \/ Check \/ Launch \/ SetupOk \/ SetupFail
    \/ Submit \/ Complete \/ AllDead \/ Stall \/ WindowDone \/ Report

(***************************************************************************)
(* Environment steps: bounded so the state space is finite, unfair so      *)
(* they may never happen.                                                  *)
(***************************************************************************)

\* An idle daemon dies, or one takes its chunk with it. A lost chunk resolves
\* at once to an errorValue while other daemons live on (observed 2026-11-02).
Die ==
    /\ conns > 0
    /\ deaths < MaxDeaths
    /\ pc # "finished"
    /\ conns' = conns - 1
    /\ deaths' = deaths + 1
    /\ clean' = FALSE
    /\ startedClean' = FALSE
    /\ \/ /\ inflight > 0
          /\ inflight' = inflight - 1
          /\ lost' = TRUE
       \/ /\ inflight' = inflight
          /\ lost' = lost
    /\ UNCHANGED <<target, pc, attempt, calls, pending, stuck, completed,
                   wedges, launches>>

\* The daemon stays connected and its chunk never resolves.
Wedge ==
    /\ inflight > 0
    /\ wedges < MaxWedges
    /\ inflight' = inflight - 1
    /\ stuck' = stuck + 1
    /\ wedges' = wedges + 1
    /\ UNCHANGED <<conns, target, pc, attempt, calls, pending, completed, lost,
                   deaths, launches, clean, startedClean>>

Next == Host \/ Die \/ Wedge

Spec == Init /\ [][Next]_vars /\ WF_vars(Host)

(***************************************************************************)
(* Properties                                                              *)
(***************************************************************************)
TypeOK ==
    /\ conns \in 0..Global
    /\ target \in {0, Global}
    /\ pc \in {"start", "check", "launch", "setup", "window",
               "returned", "raised", "finished"}
    /\ attempt \in {1, 2}
    /\ inflight + stuck <= Chunks

\* A pool nothing has disturbed since an ensure accepted it is never rebuilt.
\* This is the degraded-pool bug: OldGuard = TRUE must violate it.
NoChurn == startedClean => launches = 0

\* The retry is one relaunch, never a loop.
LaunchesBounded == launches <= 2

\* The window never exceeds its limit, wedged chunks included.
WindowRespected == inflight + stuck <= Window

\* A call that returns has a real result for every chunk.
NoLostResults == pc = "returned" => completed = Chunks

\* Every wait ends: the calls finish rather than hang.
Termination == <>(pc = "finished")
============================================================================
