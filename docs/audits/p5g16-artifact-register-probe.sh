#!/usr/bin/env bash
# P5G-16 artifact-register probe — can one place answer the canonical-bytes and
# signature-transcript question for every artifact class, and are its answers
# checkable from the tree alone?
#
# The row's filed question reads: "What canonical byte sequence and signature
# transcript is used for each brief, report, payload, manifest, tree and webhook,
# including key id, audience, timestamp, replay and rotation rules?" That is prose;
# this script is the same requirement as a command with an exit status.
#
# Arms (all must hold for exit 0):
#   A  the register subsection exists, is titled as an artifact register, carries one
#      table row per artifact class, and every value cell of those rows names the
#      section that owns it (a `§` citation or a CV vector id)
#   B  every section id the register cites resolves to a real heading in the tree this
#      script reads
#   C  the register introduces no `CF2A-*` profile id and no `cf.*` domain tag that is
#      not already present elsewhere in the corpus
#   D  published bytes recompute to published digests: the three IV.2.3 rows, the
#      CV-01-B brief digest chain and brief_ref, and the CV-18-A custody pair — with a
#      negative control that the newline-separated tag spelling the register retires
#      does NOT produce the published value
#
# Self-match guard: this script lives under docs/audits and its own pattern lines quote
# the strings it searches for, so every corpus grep runs against a scratch copy with
# this script and the evidence file removed (the P5G-36 probe shipped a bug where its
# own pattern line counted as a hit; this one does not).
#
# Usage: bash docs/audits/p5g16-artifact-register-probe.sh              (any cwd)
#        P5G16_ROOT=/path bash docs/audits/p5g16-artifact-register-probe.sh  (fixture)
# Exit: 0 criterion holds, 1 it does not (failing arms named), 2 bad root.
set -uo pipefail

ROOT=${P5G16_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || true)}
[ -n "$ROOT" ] && [ -d "$ROOT/docs" ] || {
  echo "P5G-16: no repository root (P5G16_ROOT=${ROOT:-<empty>})" >&2
  exit 2
}
cd "$ROOT" || exit 2

REGISTER=docs/handbook/parts/IV-contract-register.md
VECTORS=docs/handbook/contract-vectors.json
SELF=docs/audits/p5g16-artifact-register-probe.sh
EVIDENCE=docs/handbook/evidence/P5G-16-artifact-register.md
HEADING='### IV.2.9 '
CLASSES='brief report payload manifest tree webhook'

FAILED=''
arm_fail() { FAILED="${FAILED}${FAILED:+,}$1"; }

TMP=$(mktemp -d) || { echo "P5G-16: cannot create a scratch dir" >&2; exit 2; }
trap 'rm -rf "$TMP"' EXIT

# ---------------------------------------------------------------- locate the register
START=0
NEXT=0
if [ -r "$REGISTER" ]; then
  loc=$(awk -v h="$HEADING" 'index($0,h)==1 {printf "%d %d\n", NR, 0; exit}' "$REGISTER")
  START=${loc%% *}
  START=${START:-0}
  if [ "$START" -gt 0 ]; then
    NEXT=$(awk -v s="$START" 'NR>s && /^#{1,3} / {print NR; exit}' "$REGISTER")
    NEXT=${NEXT:-$(( $(wc -l < "$REGISTER") + 1 ))}
  fi
fi
END=$(( NEXT - 1 ))
: > "$TMP/section.md"
if [ "$START" -gt 0 ]; then
  sed -n "${START},${END}p" "$REGISTER" > "$TMP/section.md"
fi

echo "=== ARM A: one register subsection names all six artifact classes, every cell cited ==="
if [ "$START" -gt 0 ]; then
  echo "  section=${HEADING% } ($REGISTER:${START}-${END})"
else
  echo "  MISSING: no '${HEADING% }' heading in $REGISTER"
  arm_fail A
fi

if [ -s "$TMP/section.md" ]; then
  if grep -qi 'artifact register' "$TMP/section.md"; then
    echo "  title names an artifact register"
  else
    echo "  MISSING: the section does not title itself an artifact register"
    arm_fail A
  fi

  awk '/^\| Artifact class \|/ {t=1} t && /^$/ {exit} t {print}' "$TMP/section.md" > "$TMP/table.md"
  if [ -s "$TMP/table.md" ]; then
    echo "  artifact-class rows: $(($(wc -l < "$TMP/table.md") - 2))"
  else
    echo "  MISSING: no table headed '| Artifact class |'"
    arm_fail A
  fi

  for cls in $CLASSES; do
    report=$(awk -F'|' -v cls="$cls" '
      index($0, "| " cls " |") == 1 {
        found = 1
        cells = 0
        for (i = 3; i <= NF - 1; i++) {
          cells++
          if ($i !~ /§/ && $i !~ /CV-/) {
            printf "  MISSING-CITATION %s value cell %d\n", cls, i - 2
            bad = 1
          }
        }
        if (cells != 6) { printf "  WRONG-CELL-COUNT %s (%d, want 6)\n", cls, cells; bad = 1 }
      }
      END { if (!found) { printf "  MISSING-ROW %s\n", cls; bad = 1 } exit bad + 0 }
    ' "$TMP/table.md")
    if [ -z "$report" ]; then
      echo "  ok: $cls row present, 6 value cells, all cited"
    else
      printf '%s\n' "$report"
      arm_fail A
    fi
  done
fi

echo
echo "=== ARM B: every cited section id resolves to a real heading ==="
cites=$(grep -oE 'M[0-9]+ §[0-9]+(\.[0-9]+)*|§IV\.[0-9]+(\.[0-9]+)*|§V\.[0-9]+(\.[0-9]+)*|V §V\.[0-9]+(\.[0-9]+)*|VI §[0-9]+(\.[0-9]+)*|I §[0-9]+(\.[0-9]+)*' \
        "$TMP/section.md" 2>/dev/null | sort -u)
if [ -z "$cites" ]; then
  echo "  MISSING: the register cites no section id at all"
  arm_fail B
else
  echo "  distinct citations: $(printf '%s\n' "$cites" | wc -l)"
fi
printf '%s\n' "$cites" > "$TMP/cites.txt"
while IFS= read -r c; do
  [ -n "$c" ] || continue
  file=''
  id=''
  case $c in
    '§IV.'*) file=$REGISTER;                                  id=${c#§} ;;
    '§V.'*)  file=docs/handbook/parts/V-settings.md;          id=${c#§} ;;
    'V §'*)  file=docs/handbook/parts/V-settings.md;          id=${c##*§} ;;
    'I §'*)  file=docs/handbook/parts/I-system-arrangement.md; id=${c##*§} ;;
    'VI §'*) file=docs/handbook/parts/VI-failure-risk.md;     id=${c##*§} ;;
    'M'*' §'*)
      n=${c%% *}; n=${n#M}; id=${c##*§}
      file=$(ls docs/handbook/chapters/M"$n"-*.md 2>/dev/null | head -1) ;;
  esac
  if [ -z "$file" ] || [ ! -r "$file" ]; then
    echo "  UNRESOLVED $c — no chapter file for it"
    arm_fail B
    continue
  fi
  esc=${id//./\\.}
  if grep -qE "^#{2,4} ${esc}[. ]" "$file"; then
    printf '  ok: %-14s -> %s (heading %s)\n' "$c" "$file" "$id"
  else
    printf '  UNRESOLVED %-14s -> %s has no heading %s\n' "$c" "$file" "$id"
    arm_fail B
  fi
done < "$TMP/cites.txt"

echo
echo "=== ARM C: no new CF2A-* profile id and no new cf.* domain tag ==="
mkdir -p "$TMP/corpus"
cp -a docs "$TMP/corpus/docs" 2>/dev/null
awk -v s="$START" -v n="$NEXT" 'NR < s || NR >= n' "$REGISTER" \
  > "$TMP/corpus/$REGISTER" 2>/dev/null || : > "$TMP/corpus/$REGISTER"
rm -f "$TMP/corpus/$SELF" "$TMP/corpus/$EVIDENCE"

ids=$(grep -oE '(^|[^[:alnum:]-])CF2A-[A-Z0-9-]+' "$TMP/section.md" 2>/dev/null \
      | sed 's/^[^C]*//' | sed 's/[-]*$//' | sort -u)
if [ -z "$ids" ]; then
  echo "  no CF2A-* id cited (allowed; the webhook profile has none)"
fi
printf '%s\n' "$ids" > "$TMP/ids.txt"
while IFS= read -r id; do
  [ -n "$id" ] || continue
  hits=$(grep -rlF -- "$id" "$TMP/corpus" 2>/dev/null | wc -l)
  if [ "${hits:-0}" -ge 1 ]; then
    printf '  ok: %-18s present elsewhere in the corpus (%s files)\n' "$id" "$hits"
  else
    printf '  INTRODUCED %-18s appears nowhere but the register\n' "$id"
    arm_fail C
  fi
done < "$TMP/ids.txt"

tags=$(grep -oE 'cf\.[a-z0-9.-]+' "$TMP/section.md" 2>/dev/null | sed 's/[.-]*$//' | sort -u)
printf '%s\n' "$tags" > "$TMP/tags.txt"
while IFS= read -r tag; do
  [ -n "$tag" ] || continue
  hits=$(grep -rlF -- "$tag" "$TMP/corpus" 2>/dev/null | wc -l)
  if [ "${hits:-0}" -ge 1 ]; then
    printf '  ok: %-28s present elsewhere in the corpus (%s files)\n' "$tag" "$hits"
  else
    printf '  INTRODUCED %-28s appears nowhere but the register\n' "$tag"
    arm_fail C
  fi
done < "$TMP/tags.txt"

echo
echo "=== ARM D: published bytes recompute to published digests ==="
row_digest() { grep -F -- "$1" "$REGISTER" 2>/dev/null | head -1 | grep -oE '[0-9a-f]{64}' | head -1; }
check_digest() { # $1=label $2=expected $3=computed
  if [ -z "$2" ]; then
    echo "  MISSING: $1 publishes no digest in $REGISTER"
    arm_fail D
  elif [ "$2" = "$3" ]; then
    printf '  ok: %-26s %s\n' "$1" "$3"
  else
    printf '  MISMATCH %-26s published=%s recomputed=%s\n' "$1" "$2" "$3"
    arm_fail D
  fi
}

check_digest 'sha256("")'        "$(row_digest '| empty byte sequence |')"  "$(printf '%s' '' | sha256sum | cut -d' ' -f1)"
check_digest 'sha256("abc")'     "$(row_digest '| `abc` |')"               "$(printf '%s' 'abc' | sha256sum | cut -d' ' -f1)"
check_digest 'sha256("[]")'      "$(row_digest '| `[]` (empty canonical tree) |')" \
                                  "$(printf '%s' '[]' | sha256sum | cut -d' ' -f1)"

if [ -r "$VECTORS" ] && command -v jq >/dev/null 2>&1; then
  q='.vectors[]|select(.id=="CV-01-B")|.related_objects'
  brief_exp=$(jq -r "$q.brief_input_sha256" "$VECTORS" 2>/dev/null)
  brief_ref=$(jq -r "$q.brief_ref" "$VECTORS" 2>/dev/null)
  brief_got=$(jq -j "$q.brief_input_canonical_json" "$VECTORS" 2>/dev/null | sha256sum | cut -d' ' -f1)
  check_digest 'CV-01-B brief digest' "$brief_exp" "$brief_got"
  case $brief_ref in
    *"$brief_got") printf '  ok: %-26s %s\n' 'CV-01-B brief_ref' "$brief_ref" ;;
    '') echo "  MISSING: CV-01-B publishes no brief_ref"; arm_fail D ;;
    *)  printf '  MISMATCH CV-01-B brief_ref %s does not address %s\n' "$brief_ref" "$brief_got"; arm_fail D ;;
  esac

  # Custody pair: JCS of the published object, bare domain tag, no separator.
  jq -j -cS '.vectors[]|select(.id=="CV-18-A")|.payload' "$VECTORS" > "$TMP/payload.jcs" 2>/dev/null
  jq -j -cS '.vectors[]|select(.id=="CV-18-A")|.receipt' "$VECTORS" > "$TMP/receipt.jcs" 2>/dev/null
  body_exp=$(jq -r '.vectors[]|select(.id=="CV-18-A")|.response_body_digest' "$VECTORS" 2>/dev/null)
  rcpt_exp=$(jq -r '.vectors[]|select(.id=="CV-18-A")|.receipt_digest' "$VECTORS" 2>/dev/null)
  body_got=$({ printf '%s' 'cf.crier.response-body.v1'; cat "$TMP/payload.jcs"; } | sha256sum | cut -d' ' -f1)
  rcpt_got=$({ printf '%s' 'cf.crier.receipt.v1'; cat "$TMP/receipt.jcs"; } | sha256sum | cut -d' ' -f1)
  check_digest 'CV-18-A response_body_digest' "$body_exp" "$body_got"
  check_digest 'CV-18-A receipt_digest' "$rcpt_exp" "$rcpt_got"

  # Negative control: the retired newline-separated spelling must NOT reproduce them.
  body_nl=$({ printf '%s\n' 'cf.crier.response-body.v1'; cat "$TMP/payload.jcs"; } | sha256sum | cut -d' ' -f1)
  rcpt_nl=$({ printf '%s\n' 'cf.crier.receipt.v1'; cat "$TMP/receipt.jcs"; } | sha256sum | cut -d' ' -f1)
  if [ "$body_nl" != "$body_exp" ] && [ "$rcpt_nl" != "$rcpt_exp" ]; then
    echo "  ok: the retired newline-separated tag spelling reproduces neither digest"
  else
    echo "  NOT DECISIVE: a newline-separated tag also reproduces the published digest"
    arm_fail D
  fi
else
  echo "  MISSING: $VECTORS or jq is unavailable; the brief and custody chains are unchecked"
  arm_fail D
fi

echo
if [ -z "$FAILED" ]; then
  echo "P5G-16: PASS — one artifact register answers all six classes, cites resolvable owners, mints no profile or tag, and its published bytes recompute"
  exit 0
fi
echo "P5G-16: FAIL — arms $FAILED do not hold at this tree"
exit 1
