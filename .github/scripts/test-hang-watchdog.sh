#!/usr/bin/env bash
# Diagnostic watchdog for the intermittent ubuntu "checking tests" hangs
# (see R-CMD-check.yaml's timeout-minutes comments; runs 33366557367,
# 33421678891, 33437466317, 33457950194 each lost 1-2 random ubuntu legs
# to a silent multi-hour stall inside "Running 'testthat.R'"). R CMD
# check buffers all test output until the suite finishes, so a
# timed-out job's log never says which test file hung -- this watchdog
# exists purely to capture that missing evidence, not to fix anything.
#
# Started in the background right after checkout and left running for
# the whole job. Every 5 minutes it appends to $RUNNER_TEMP/hang-watch.log:
# a timestamp, the tail of every tests/testthat.Rout* under the check
# dir (testthat's check reporter appends a line per completed test file,
# so the tail names the last file to finish -- the hung one is the next
# in alphabetical order), and the R process table. If the .Rout tails
# stop changing for 4 consecutive samples (~20 minutes) while R
# processes are still alive, it also captures one round of
# `gdb thread apply all bt` stack dumps of every R process -- taken
# while the hang is live, since job cancellation kills the processes
# before any post-mortem step could inspect them. The companion
# "Dump test-hang watchdog log" step (if: always()) prints the log even
# when the job is cancelled by timeout.
set -u

LOG="${RUNNER_TEMP:-/tmp}/hang-watch.log"
last_sig=""
stall_count=0
dumped=0

echo "test-hang-watchdog started $(date -u '+%F %T') (pid $$)" >> "$LOG"

while true; do
	sleep 300
	routs=$(find "${GITHUB_WORKSPACE:-.}" -path '*check*' -name 'testthat.Rout*' 2>/dev/null)
	sig=$( { for f in $routs; do stat -c '%n %s' "$f" 2>/dev/null; done; } | md5sum)
	{
		echo "===== $(date -u '+%F %T') ====="
		if [ -z "$routs" ]; then
			echo "(no testthat.Rout* under check dir yet)"
		fi
		for f in $routs; do
			echo "--- $f ($(stat -c%s "$f" 2>/dev/null) bytes), last lines: ---"
			tail -c 2000 "$f" 2>/dev/null
			echo
		done
		echo "--- R processes ---"
		ps -eo pid,ppid,etime,stat,pcpu,time,wchan:30,args --no-headers | grep -E 'exec/R|[R]script|EDI\.Rcheck' | grep -v grep || echo "(none)"
	} >> "$LOG" 2>&1

	if [ -n "$routs" ]; then
		if [ "$sig" = "$last_sig" ]; then
			stall_count=$((stall_count + 1))
		else
			stall_count=0
			dumped=0
		fi
	fi
	last_sig="$sig"

	if [ "$stall_count" -ge 4 ] && [ "$dumped" -eq 0 ]; then
		dumped=1
		{
			echo "===== STALL DETECTED $(date -u '+%F %T'): testthat.Rout unchanged ~20 min ====="
			echo "--- open sockets of R processes (mirai/cluster handshake state) ---"
			ss -tnp 2>/dev/null || sudo ss -tnp 2>/dev/null || true
			echo "--- per-thread state + kernel wait channels ---"
			for pid in $(pgrep -f 'exec/R' || true); do
				echo "pid $pid cmdline: $(tr '\0' ' ' < "/proc/$pid/cmdline" 2>/dev/null)"
				grep -E 'State|Threads' "/proc/$pid/status" 2>/dev/null
				for t in /proc/$pid/task/*; do
					echo "  tid $(basename "$t") wchan=$(cat "$t/wchan" 2>/dev/null) stat=$(awk '{print $3}' "$t/stat" 2>/dev/null)"
				done
			done
			# gdb isn't preinstalled on the runners (learned from run
			# 33476039617's dump: "sudo: gdb: command not found") -- install
			# it lazily, only once a stall is already confirmed, so the
			# happy path never pays for it.
			if ! command -v gdb >/dev/null 2>&1; then
				echo "--- installing gdb (not preinstalled on runner) ---"
				sudo apt-get install -y gdb >/dev/null 2>&1 || sudo apt-get update -y >/dev/null 2>&1 && sudo apt-get install -y gdb >/dev/null 2>&1
			fi
			echo "--- gdb C-level stack dumps ---"
			for pid in $(pgrep -f 'exec/R' || true); do
				echo "--- pid $pid: $(tr '\0' ' ' < "/proc/$pid/cmdline" 2>/dev/null) ---"
				sudo gdb --batch -p "$pid" -ex 'thread apply all bt' 2>&1 | head -300
			done
		} >> "$LOG" 2>&1
	fi
done
