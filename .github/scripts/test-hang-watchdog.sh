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
		ps auxww | grep -E 'exec/R|[R]script|EDI\.Rcheck' || echo "(none)"
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
			echo "===== STALL DETECTED $(date -u '+%F %T'): testthat.Rout unchanged ~20 min -- gdb stack dumps ====="
			for pid in $(pgrep -f 'exec/R|EDI\.Rcheck' || true); do
				echo "--- pid $pid: $(tr '\0' ' ' < "/proc/$pid/cmdline" 2>/dev/null) ---"
				sudo gdb --batch -p "$pid" -ex 'thread apply all bt' 2>&1 | head -300
			done
		} >> "$LOG" 2>&1
	fi
done
