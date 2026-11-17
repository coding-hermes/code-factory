#!/usr/bin/env bash
# code-factory dogfood tick: file the two findings rows and annotate CF-057.
set -uo pipefail
EV=~/.hermes/cache/scratch/cf-dogfood-2026-11-17-10-10-24-a1
P=$EV/payload
cd ~/code-factory || exit 9

echo "=== board tail before ==="
tail -1 .coding-hermes/board/tasks.jsonl | head -c 200; echo
echo "=== line count before: $(wc -l < .coding-hermes/board/tasks.jsonl) ==="

ID1=CF-483
ID2=CF-484
if grep -q "\"id\":\"$ID1\"" .coding-hermes/board/tasks.jsonl; then echo "ABORT: $ID1 already exists"; exit 3; fi
if grep -q "\"id\":\"$ID2\"" .coding-hermes/board/tasks.jsonl; then echo "ABORT: $ID2 already exists"; exit 3; fi

boardctl -C . create --id "$ID1" --type bug --status pending --priority P3 --complexity 1 \
  --capability-tags 'check-honesty,control-host,M1.S1' \
  --title "$(cat "$P/r1-title.txt")" \
  --reasoning "$(cat "$P/r1-reason.txt")" \
  --acceptance-criteria "$(cat "$P/r1-ac.txt")"
echo "CREATE1_RC=$?"

boardctl -C . create --id "$ID2" --type chore --status pending --priority P3 --complexity 2 \
  --capability-tags 'docs,readme,M6' \
  --title "$(cat "$P/r2-title.txt")" \
  --reasoning "$(cat "$P/r2-reason.txt")" \
  --acceptance-criteria "$(cat "$P/r2-ac.txt")"
echo "CREATE2_RC=$?"

boardctl -C . update CF-057 --status pending --note "$(cat "$P/cf057-note.txt")"
echo "UPDATE_RC=$?"

echo "=== line count after: $(wc -l < .coding-hermes/board/tasks.jsonl) ==="
echo "=== verify rows ==="
grep -c "\"id\":\"$ID1\"" .coding-hermes/board/tasks.jsonl
grep -c "\"id\":\"$ID2\"" .coding-hermes/board/tasks.jsonl
tail -2 .coding-hermes/board/tasks.jsonl | jq -r '"\(.id)\t\(.status)\t\(.type)\t\(.priority)\treason_chars=\((.reasoning|tostring)|length)\tac_chars=\((.acceptance_criteria|tostring)|length)"'
echo "=== CF-057 note chars ==="
grep '"id":"CF-057"' .coding-hermes/board/tasks.jsonl | jq -r '(.foreman_note|tostring)|length'
