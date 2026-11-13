P5G-11 uncertain native-start recovery evidence

Scope

This is deterministic specification-model evidence for M2 §15.2 and the M11 §16
identity cross-reference. It does not qualify a live supervisor, native launcher,
or production adapter. The executable model owns the authoritative journal state,
performs exact recovery lookups, and counts native launches to prove that uncertain
starts are never relaunched.

Normative answer

The resident supervisor is the authoritative actor. Its durable execution journal
is authoritative, with one record containing `execution_key`, `native_name`,
`input_digest`, state, and optional `boot_id`, process start ticks,
`process_instance_id`, `native_session_id`, release evidence and result reference.
The lookup first matches `execution_key`, exact `native_name` and `input_digest`;
where a process incarnation is relevant it also matches boot ID, start ticks and
native session ID. The ordering is durable RESERVED, durable START_INTENT, native
creation/discovery, durable STARTED, then release. If the native launch may have
succeeded but acknowledgement or identity was lost, the supervisor discovers the
exact existing session or result and never launches again. If it cannot prove
absence or exact identity, it returns START_UNKNOWN, quarantines/fences the
attempt, and never relaunches the same attempt. Only RESERVED with authoritative
proof of no START_INTENT may perform the one create-or-discover operation.

Deterministic state table

| Case | Durable/native evidence | Recovery result | Native launches |
|---|---|---|---:|
| 1 | RESERVED; no START_INTENT proven | create-or-discover with same execution_key | 1 |
| 2 | START_INTENT; child exists and is gated | discover by exact identity, persist STARTED, release | 1 |
| 3 | STARTED; release outcome unknown | discover exact native session; RUNNING/no relaunch | 1 |
| 4 | release/native output before parent STARTED | recover identity; RUNNING/no relaunch | 1 |
| 5 | new boot; no child and no terminal/release proof | START_UNKNOWN/quarantine/no relaunch | 1 |
| 6 | terminal journal/result | replay result/outbox; no native invocation | 1 |
| 7 | same execution key/name with changed input digest | LAUNCH_CONFLICT | 0 |

Reproducible procedure and exact output

Run from the repository root:

    python3 docs/audits/p5g11-native-start-recovery.py

Observed output:

    PASS RESERVED/no START_INTENT -> UNSTARTED, create-or-discover once
    PASS START_INTENT gated child -> discover, STARTED, release
    PASS STARTED/release unknown -> exact session, no relaunch
    PASS release/native output before parent STARTED -> RUNNING
    PASS new boot/no child or terminal proof -> START_UNKNOWN quarantine
    PASS terminal result -> replay only, no native invocation
    PASS changed input under same key/name -> LAUNCH_CONFLICT
    PASS mismatched process/native identity -> no relaunch
    PASS exact identity: execution_key + native_name + input_digest + process identity
    PASS deterministic model only; live supervisor qualification UNVERIFIED

The script asserts each result and the native-launch count. It also asserts that
recovery lookups carry execution_key, native_name, input_digest, and, for process
identity checks, boot_id, process start ticks and native_session_id. Repeated
same-key/same-digest lookup does not increment the native-launch count.

Additional verification commands and observed results

    python3 scripts/handbook_lint.py
    handbook_lint: clean
    exit 0

    python3 -m py_compile docs/audits/p5g11-native-start-recovery.py
    exit 0

    git diff --check
    exit 0

The changed handbook surfaces are M2 §15.2 and the directly cited M11 §16
identity paragraph. No live supervisor qualification was attempted; the witness
is repository-local specification evidence only.

ch:trace row=P5G-11 spec=docs/handbook/chapters/M2-dispatch.md#15-normative-launch-and-return-contract wave=none:serial test=docs/audits/p5g11-native-start-recovery.py doc=docs/handbook/chapters/M2-dispatch.md evidence=docs/audits/p5g11-native-start-recovery.md witness=none:repository-local-spec-only verdict=none commit=none:pending-worker-commit memory=none:foreman-writes
STATUS: complete
TIER: T1
EVIDENCE: docs/audits/p5g11-native-start-recovery.md
