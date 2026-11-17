# Dogfood log — code-factory

One entry per dogfood tick: what was walked, what it cost, what broke, what was filed.
Newest last. Run ids are the tick ids, so `grep -n '<tick-id>'` finds the record.

## 2026-11-17 — run `code-factory-dogfood-2026-11-17-10-10-24`

- **Verdict**: 🟡 PROMISING-BUT-ROUGH. Every documented control-host command runs and refuses
  by name with the missing value; two of the outputs misstate their own measurement.
- **Tip walked**: `0014b76ac0b5a33081068d743e52754b928b4e0c` (origin/main, parity 0/0, clean tree).
- **Promise tested**: "a stranger on a fresh host runs the three Quick start commands and each one
  either works or fails naming the value to supply."
- **Time to first success**: `bunker-server-install.sh --check` → `RESULT: PASS` in **0.92 s** once
  `BUNKER_SERVER` names a configured server (0.00 s / 0.03 s on the two refusal arms).
  `project-node.sh --check` → `NODE: FAIL (5)` in **38.16 s** (cost owned by CF-387).
- **Top findings**:
  1. `CF-483` — the `residue` row is a substring match on the word "orphan", so it WARNs on a host
     the server reports as *0 orphan homes, 0 orphan keys* and can never report a real leak.
  2. `CF-484` — README Quick start step 2 says "the same check with an explicit interpreter
     passes"; measured `NODE: FAIL (7)` (two MORE failures than the default arm's 5).
  3. `CF-057` annotated — `--json` is parsed into a variable nothing reads: the documented
     machine-readable surface does not exist.
- **Not filed**: the `node-create.sh` spawn row already owns its message quality (`CF-469`); the
  README's `bunker-provision --check` transcript is `CF-467`; step-2 cost is `CF-387`.
- **Unverified this fire**: a live node create (would spawn a real agent on `bunker-las-03`, which
  reported 0/8 agents); one probe arm was refused by the unattended command gate and is recorded as
  UNVERIFIED in the report, not retried in another form.
- **Artifacts**: `docs/dogfood/2026-11-17-dogfood-path.md`,
  `.coding-hermes/evidence/code-factory-dogfood-2026-11-17-10-10-24/`.
