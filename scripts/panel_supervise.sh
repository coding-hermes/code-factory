#!/usr/bin/env bash
# panel_supervise.sh — keep the handbook loop running until it actually converges.
#
# A round cap is a budget for one session, not a definition of done. This wrapper
# owns the loop: it waits for any in-flight run to exit, then runs panel_loop.py
# with no cap and restarts it if it dies. It exits ONLY when STATE.json records a
# real stop condition:
#
#   unanimous-pass        every family returned PASS
#   no-new-defect-class   two consecutive rounds surfaced no new class
#
# Anything else — crash, cap, kill, provider outage — is restarted. The loop is
# idempotent: it resumes from STATE.json's round counter and rewrites chapters in
# place, so a restart costs one writer pass, never the whole document.
set -uo pipefail

REPO=${PANEL_ROOT:-$HOME/code-factory}
LOG=$HOME/.hermes/logs/panel-supervisor.log
STATE=$REPO/docs/handbook/_panel/STATE.json
WAIT_PID=${1:-}

cd "$REPO" || exit 1
echo "$(date -Is) supervisor start (wait_pid=${WAIT_PID:-none})" >> "$LOG"

if [[ -n "$WAIT_PID" ]]; then
  while kill -0 "$WAIT_PID" 2>/dev/null; do sleep 30; done
  echo "$(date -Is) in-flight run $WAIT_PID exited" >> "$LOG"
fi

while true; do
  status=$(python3 -c "import json,sys;print(json.load(open('$STATE')).get('status','idle'))" 2>/dev/null || echo idle)
  case "$status" in
    unanimous-pass|no-new-defect-class)
      echo "$(date -Is) STOP: $status" >> "$LOG"
      exit 0
      ;;
  esac

  python3 scripts/reap_orphan_writers.py >> "$LOG" 2>&1
  echo "$(date -Is) launching panel_loop (no cap), prior status=$status" >> "$LOG"
  python3 scripts/panel_loop.py --rounds 0 --max-seconds 0 \
    --parallel "${PANEL_PARALLEL:-3}" \
    --groups "${PANEL_GROUPS:-}" >> "$LOG" 2>&1
  rc=$?
  echo "$(date -Is) panel_loop exited rc=$rc" >> "$LOG"
  sleep 30
done
