# Windows counterpart of test-hang-watchdog.sh, for the separate, still-
# unexplained windows-latest-only hang in "checking examples with
# --run-donttest" (see R-CMD-check.yaml's timeout-minutes comment: a
# 2026-08-09 run stalled there 5.5+ hours before GitHub's 6h hard kill; a
# 2026-08-17 static audit of every \donttest{} block found no blocking call
# and no culprit example; OpenBLAS/OpenMP changes since then didn't fix it
# either). The Linux watchdog (test-hang-watchdog.sh) cannot cover this: it
# shells out to gdb/stat -c/md5sum, none of which exist in the Windows
# Git-Bash environment, which is exactly why every prior Windows occurrence
# of this hang produced zero diagnostic evidence.
#
# This script does NOT attempt a gdb-equivalent native stack dump -- there is
# no lightweight, pre-installed way to get one on a stock windows-latest
# runner (procdump/WinDbg would need a separate install-and-later-analyze
# step this workflow has no way to consume). Its job is the same as the
# Linux watchdog's minimum bar: capture *something* -- which R process is
# still alive, how much CPU/wall time it has burned, and whether the
# examples output file is still growing -- since right now a hang here
# leaves absolutely no trace. That alone is enough to tell "stuck on one
# specific example" from "R process gone / spinning with 0% CPU" from
# "genuinely still making progress, just slow this run", which the next
# hang can then be triaged from instead of starting blind again.
#
# Started detached (Start-Process, not a job tied to this step's process
# tree) right after checkout and left running for the whole job. Every 5
# minutes it appends to $env:RUNNER_TEMP\hang-watch.log: a timestamp, the
# tail of every *.Rout*/*.Rout.fail under the check dir (R CMD check's
# combined --run-donttest pass writes <pkg>-Ex.Rout incrementally), and a
# snapshot of every R/Rscript/Rterm process with elapsed time and CPU time.
# The companion "Dump test-hang watchdog log" step (if: always()) prints the
# log even when the job is cancelled by timeout.

$ErrorActionPreference = "Continue"

function Utc-Now-String {
	(Get-Date).ToUniversalTime().ToString('yyyy-MM-dd HH:mm:ss')
}

$tempDir = $env:RUNNER_TEMP
if (-not $tempDir) { $tempDir = $env:TEMP }
$logPath = Join-Path $tempDir "hang-watch.log"
$workspace = $env:GITHUB_WORKSPACE
if (-not $workspace) { $workspace = "." }

"test-hang-watchdog.ps1 started $(Utc-Now-String) (pid $PID)" |
	Out-File -FilePath $logPath -Append -Encoding utf8

while ($true) {
	Start-Sleep -Seconds 300

	$routFiles = Get-ChildItem -Path $workspace -Recurse -File -ErrorAction SilentlyContinue |
		Where-Object { $_.FullName -match '\.Rcheck[\\/]' -and $_.Name -match '\.Rout(\.fail)?$' }

	$lines = New-Object System.Collections.Generic.List[string]
	$lines.Add("===== $(Utc-Now-String) =====")

	if (-not $routFiles) {
		$lines.Add("(no *.Rout* under check dir yet)")
	}
	foreach ($f in $routFiles) {
		$lines.Add("--- $($f.FullName) ($($f.Length) bytes, last write $($f.LastWriteTimeUtc.ToString('yyyy-MM-dd HH:mm:ss'))Z), last lines: ---")
		try {
			Get-Content -LiteralPath $f.FullName -Tail 40 -ErrorAction Stop | ForEach-Object { $lines.Add($_) }
		} catch {
			$lines.Add("(could not read: $($_.Exception.Message))")
		}
	}

	$lines.Add("--- R processes ---")
	$procs = Get-Process -Name "R", "Rscript", "Rterm" -ErrorAction SilentlyContinue
	if (-not $procs) {
		$lines.Add("(none)")
	} else {
		foreach ($p in $procs) {
			try {
				$elapsed = (Get-Date) - $p.StartTime
				$lines.Add(("pid={0} name={1} elapsed={2:hh\:mm\:ss} cpu_time={3:hh\:mm\:ss} working_set_mb={4:N0}" -f `
					$p.Id, $p.ProcessName, $elapsed, $p.TotalProcessorTime, ($p.WorkingSet64 / 1MB)))
			} catch {
				$lines.Add("pid=$($p.Id) name=$($p.ProcessName) (could not read timing: $($_.Exception.Message))")
			}
		}
	}

	$lines | Out-File -FilePath $logPath -Append -Encoding utf8
}
