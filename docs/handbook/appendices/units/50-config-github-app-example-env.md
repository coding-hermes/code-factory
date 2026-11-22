# 50. config/github-app.example.env — the App credential pointers

| Field | Value |
|---|---|
| Path | `~/code-factory/config/github-app.example.env` |
| Repository | `code-factory` |
| Revision | `8f77667b` |
| Status | **VERIFIED — the example is described alongside the two scripts that read and mint from it; both consumers' lines were read at this revision** |

## 1. Purpose and why it matters

The pointer file for GitHub App authentication: App id, installation id, private-key path,
slug, repo, and the token output path. Its header draws the line that makes it committable:
this file holds POINTERS, never secrets — the private key stays where it is and the file
names the path; still mode 600 because it tells a reader where a credential lives
(`config/github-app.example.env:1-8`) [fact: FACT-05]. What breaks if it is absent: nodes
fall back to a long-lived PAT, the exact asset the App mode exists to retire. What breaks
if it lies: a node provisions with App mode armed and silently loses push rights one hour
later — the token is valid for ONE HOUR and the refresh timer is part of the contract
(`config/github-app.example.env:25-27`).

## 2. Dependencies and library contracts

| Dependency | Provider | Contract relied on | If it changes |
|---|---|---|---|
| `scripts/github-app-setup.sh` | this repo | resolves the env file (default `~/.config/code-factory/github-app.env`) and can write it from flags (`scripts/github-app-setup.sh:32,308-309`) | the example's key names drift from the writer |
| `scripts/github-app-token.py` | this repo | reads `GITHUB_APP_ID` from the file and refuses by name when unset (`scripts/github-app-token.py:295-300`) | a renamed key produces an unset-value refusal instead of a token |
| `scripts/github-app-refresh.sh` | this repo | re-mints on a timer (`--min-age 2400`, every 20 minutes) | the node loses push rights an hour after provisioning |
| `config/bunker.example.conf` | this repo | the `#GITHUB_AUTH_MODE=app` arm names this file (`config/bunker.example.conf:30-31`) | the two files disagree on the env path |

## 3. Verification

| Check | Command | Expected | Last run | Result |
|---|---|---|---|---|
| every locator on this page resolves | `python3 scripts/master_doc_check.py docs/handbook/appendices/units --only 50- --strict` | `MASTER-DOC: PASS` | 2026-11-22 | PASS |
| the example carries pointers, not secrets | `grep -c "FILE=" config/github-app.example.env` and inspect | credential-shaped values are `*_FILE` paths; the key path is the only secret-bearing line and it is a pointer | 2026-11-22 at `8f77667b` | PASS |
| the consumer refuses an unset App id by name | `scripts/github-app-token.py:295-300` | the refusal names the key and the remedy | 2026-11-22 (read) | PASS |

## 4. Metrics emitted

None. The observable output is the minted token's lifecycle (one hour) and the consumers'
rows — the setup script's written-env block (`scripts/github-app-setup.sh:308-309`) and the
token script's named refusals.

## 5. Log lines it can generate

- Nothing by itself. Through its consumers: the setup script's `GITHUB_APP_ID=...` /
  `GITHUB_APP_INSTALLATION_ID=...` write-back (`scripts/github-app-setup.sh:308-309`) and
  the token script's refusal naming `GITHUB_APP_ID is unset` with the remedy
  (`scripts/github-app-token.py:295-300`).

## 6. Failure modes

| Failure | Presents as | Distinguished from | Recovery |
|---|---|---|---|
| Private key pasted into the file | a committable credential | the header rule: the key stays where it is; the file names its path (`config/github-app.example.env:3-8`) | replace with the pointer; rotate the key on GitHub |
| No refresh timer armed | pushes fail ~1 h after provisioning | the one-hour token rule + the 20-minute refresh command (`config/github-app.example.env:25-27`) | arm `scripts/github-app-refresh.sh --min-age 2400` |
| Installation id read from the wrong place | mint fails after App setup succeeded | the header's per-value sourcing table: the id lives at `.../installations/<NUMBER>` (`:10-16`) | re-read the installation page, not the App page |

## 7. Environment and settings it reads

| setting | source | requirement |
|---|---|---|
| `GITHUB_APP_ENV_FILE` | environment override in both consumers (`scripts/github-app-setup.sh:32`, `scripts/github-app-token.py:110`) | defaults to `~/.config/code-factory/github-app.env` |
| App permissions | declared on GitHub (Contents + Pull requests + Metadata) | listed in the file's comment block (`config/github-app.example.env:18-23`) |
| token output | `GITHUB_APP_TOKEN_FILE`, mode 600, never committed (`:31-32`) | the same path the bunker conf names |

## 8. Evidence of record

- The example: pointer rule `config/github-app.example.env:1-8`, per-value sourcing
  `:10-16`, permissions `:18-23`, one-hour + refresh rule `:25-27`, output path `:31-32`.
- The consumers: `scripts/github-app-setup.sh:32,308-309`; `scripts/github-app-token.py:110,295-300`.
- The credential discipline this file implements: fact: FACT-05; the provisioner arm that
  arms App mode: record 49.
