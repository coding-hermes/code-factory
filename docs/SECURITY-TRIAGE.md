# Security triage — GitHub secret-scanning alerts

One record per GitHub secret-scanning alert on this **public** repository. The purpose is not to
narrate: it is so a later release-engineering tick can **re-measure** an alert instead of
**re-deciding** its triage. Every record therefore carries the alert number, the exact location and
commit the scan named, the resolution GitHub stores, and the command that reads the resolution back.

Newest alert last. Do not delete a record when an alert is dismissed — the dismissal is the record.

## Alert 1 — `slack_api_token` (Slack)

| field | value |
|---|---|
| alert | 1 |
| secret type | `slack_api_token` (Slack API Token) |
| provider | Slack |
| opened | 2026-11-02T11:22:58Z |
| location | `.hermes/scripts/test_secret_scrub.py`, line 30 |
| commit named by the scan | `8edba9fa7c27c394fac34f127a6c57b4702b4bbb` |
| blob named by the scan | `7d38bc75d6071de0ad2f3c4344cc128fd668df0d` (git blob sha) |
| in the current tree | no — the path is absent |
| resolution | `used_in_tests` |
| resolved by | `code-factory-releng tick 2026-11-04-02-59-07` |
| resolved at | 2026-11-04T03:41:09Z |

### Why the dismissal is correct

The hit is a **secret-scrubber test fixture, not a live credential**.

`.hermes/scripts/test_secret_scrub.py` was a table of token-shaped inputs used to prove that the
scrubber recognises and redacts them. A table that tests redaction has to contain shapes the detector
recognises — that is the whole point of the table. Its neighbours in the same table are documented
public placeholders, not secrets: AWS's own published example access-key id, the sha1 and sha256
digests of the empty string, and a literal fake password. The Slack-shaped entry sits in that
sequence, in the same fixture role.

Three independent measurements agree that nothing live is exposed:

1. The path is absent from the current tree — `git ls-files --error-unmatch
   .hermes/scripts/test_secret_scrub.py` fails.
2. The commit and the blob the alert named are still reachable in history (`git cat-file -e`
   succeeds), which is why the alert can stay open against a file that no longer exists; the alert
   is about history, and public history is not retracted by deleting the file.
3. No file in the current tree carries the shape at all, so there is no successor value to rotate
   and no consumer to re-key.

Because the value was a fixture rather than a credential, the correct triage is dismissal, **not**
rotation. Rotating a fixture that was never a credential would break the scrubber's own test.

### Re-measure (do not re-decide)

```bash
# expect 0
gh api 'repos/coding-hermes/code-factory/secret-scanning/alerts?state=open' --jq 'length'

# expect used_in_tests
gh api repos/coding-hermes/code-factory/secret-scanning/alerts/1 --jq '.resolution'
```

If the first command prints `0` and the second prints `used_in_tests`, the triage above still holds
and there is nothing to do. If the alert has **re-opened**, re-confirm the three measurements above
before touching anything: a re-opened alert against the same fixture is re-dismissed, not rotated. If
a **new** alert names a different path or commit, write a new record here and triage it on its own
evidence — do not inherit this dismissal.

### Standing instruction for future editors

- **Do not "fix" this alert by rotating.** No credential is involved. Rotating on a re-opened
  fixture alert is the wrong action and destroys test coverage.
- **Do not reintroduce a token-shaped literal** into this tree — not in a test fixture, not in a
  document, not in a commit message. Scrubber tests must build recognisable shapes at runtime or
  from documented placeholders, never by pasting a shape that trips secret scanning on a public repo.
- **If the detector shape must be named in prose**, spell it as a bracket expression — e.g.
  `xox[bprs]-` — so this document does not itself match the pattern. A bracket expression does not
  match its own literal text; a pasted literal does. Never paste the literal.
- **This file contains no absolute host paths and no token-shaped literals on purpose.** Both are
  gates on this repository, not style preferences.

ch:trace row=CF-156 spec=none:row-carries-no-spec-anchor wave=none:single-worker-tick test=tests/selftest.sh::full-suite doc=docs/SECURITY-TRIAGE.md prompt=none:foreman-tick-prompt evidence=docs/SECURITY-TRIAGE.md witness=gh api repos/coding-hermes/code-factory/secret-scanning/alerts/1 --jq .resolution verdict=none:judged-after-commit commit=none:this-commit-is-the-fix memory=none:foreman-writes-it

STATUS: complete
TIER: T2
EVIDENCE: docs/SECURITY-TRIAGE.md + the gh api readbacks above
