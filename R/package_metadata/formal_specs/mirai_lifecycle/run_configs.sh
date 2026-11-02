#!/usr/bin/env bash
# Runs TLC on every config and checks each gives its expected result. Three
# configs must fail, so TLC's exit code alone cannot judge them: each needs the
# specific violation in its log, not just any error such as a parse failure.
# "Stuttering" ends a liveness counter-example: the host can never move again.
# TLC's headline for that failure is worded differently between versions.
#
# Usage: run_configs.sh /path/to/tla2tools.jar
set -u

jar=${1:?usage: run_configs.sh /path/to/tla2tools.jar}
cd "$(dirname "$0")" || exit 2
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

expected_results=(
	"MiraiLifecycle|Model checking completed. No error has been found."
	"MiraiLifecycle_old_guard|Error: Invariant NoChurn is violated"
	"MiraiLifecycle_no_error_check|Error: Invariant NoLostResults is violated"
	"MiraiLifecycle_wedged|Model checking completed. No error has been found."
	"MiraiLifecycle_no_stall_timeout|Stuttering"
)

failures=0
for entry in "${expected_results[@]}"; do
	config=${entry%%|*}
	expected=${entry#*|}
	log="$work/$config.log"
	java -XX:+UseParallelGC -Xmx2g -cp "$jar" tlc2.TLC -workers auto \
		-metadir "$work/$config" \
		-config "$config.cfg" MiraiLifecycle.tla > "$log" 2>&1
	if grep -qF "$expected" "$log"; then
		echo "ok    $config: $expected"
	else
		echo "FAIL  $config: expected \"$expected\" in the TLC output"
		tail -n 40 "$log"
		failures=$((failures + 1))
	fi
done

if [ "$failures" -gt 0 ]; then
	echo "$failures config(s) did not give the expected result"
	exit 1
fi
