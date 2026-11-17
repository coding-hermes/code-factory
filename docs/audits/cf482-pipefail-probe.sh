#!/usr/bin/env bash
# CF-482 probe: does `printf | grep -q` under pipefail flip a MATCH into a failed pipeline?
# Same logical assertion, three shapes, on a payload where grep exits before the producer ends.
set -uo pipefail

say() { printf '%s\n' "$*"; }

early=$(printf 'MATCH-TARGET\n')
tail=$(head -c "${TAILBYTES:-2000000}" /dev/zero | tr '\0' 'x')
out=$(printf '%s\n%s\n' "$early" "$tail")
tries=${TRIES:-30}

say "payload_bytes=${#out}  (match on line 1, the rest is tail)"

pipe_matches=0
pipe_rc141=0
herestring_matches=0
case_matches=0

for _ in $(seq 1 "$tries"); do
  # (1) the shape section 7b shipped
  printf '%s\n' "$out" | grep -Fq 'MATCH-TARGET'
  [ "$?" -eq 0 ] && pipe_matches=$((pipe_matches + 1))
  printf '%s\n' "$out" | grep -Fq 'MATCH-TARGET'
  [ "$?" -eq 141 ] && pipe_rc141=$((pipe_rc141 + 1))

  # (2) here-string: no producer process, so no SIGPIPE
  grep -Fq 'MATCH-TARGET' <<<"$out" && herestring_matches=$((herestring_matches + 1))

  # (3) case glob: no pipeline at all
  found=0
  case "$out" in *MATCH-TARGET*) found=1 ;; esac
  [ "$found" -eq 1 ] && case_matches=$((case_matches + 1))
done

say "over $tries iterations of the identical logical assertion:"
say "  shipped shape (printf | grep -Fq): matched=$pipe_matches/$tries   rc=141=$pipe_rc141/$tries"
say "  here-string  (grep -Fq <<<):       matched=$herestring_matches/$tries"
say "  case glob    (no pipeline):        matched=$case_matches/$tries"
if [ "$pipe_matches" -lt "$tries" ]; then
  say "VERDICT: REPRODUCED -- the shipped shape reports a FALSE NEGATIVE on a payload that matches."
  exit 0
fi
say "VERDICT: not reproduced at this payload size on this host"
exit 0
