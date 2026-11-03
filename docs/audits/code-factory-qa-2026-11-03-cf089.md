# QA — CF-065 re-verified, and the page that the census cannot see

Lane: `code-factory-readme-qa` · tick `code-factory-readme-qa-2026-11-03-16-51-21`
Tree: `0fbfe1f` on `main` (before this tick's filing commit)

## What was re-verified (CF-065, `complete`)

CF-065 closed the README "The lanes" census on the claim that the recipe paginates the
inventory instead of reading one page. Re-ran it verbatim from the repo root at `0fbfe1f`:

```
$ bash tests/selftest.sh | tail -1
SELFTEST: PASS

$ bash docs/audits/cf089-census-recipe.sh          # README.md lines 155-169, verbatim
19
code-factory enabled=true admission=tasks parent=
code-factory-docs ... code-factory-sync enabled=true admission=cooldown parent=code-factory
RC=0
```

- The nineteen rows the README promises are printed: the fourteen shipped family rows plus
  the five `code-factory-duckbrain-*` satellites, with `code-factory-duckbrain admission=tasks`
  against the `cooldown` the loader writes — the drift the command exists to expose. **Reproduces.**
- The negative control CF-065 shipped also reproduces: a scheduler answer with no `total`
  prints `census: the scheduler answered without a total; refusing to count` and exits 1.

CF-065 is therefore not re-opened. Its evidence is real. What it did not test is below.

## The failure it did not test: a page that fails is counted as a page that is empty

The loop advances `off` by 500 and appends whatever `jq` manages to extract from each page.
`curl -s` and `jq -r` exit codes are discarded, there is no status check, no `.projects` shape
check, and no assertion that the number of enumerated project rows equals the `total` the
first request reported. A page that answers 5xx, times out, or returns an error body therefore
contributes **zero rows** and the census still exits 0 with a smaller number.

The realistic trigger is the one the recipe's own control does not cover: the scheduler
restarts or sheds load between two pages. A whole 500-row page disappears and the printed
count is short — silently, and plausibly.

Proved with a stand-in that mimics the real endpoint shape (`{projects,total,limit,offset}`,
500-row cap) and holds exactly two matching rows, at index 0 and index 600. Row 600 is only
reachable through the second page, which answers 502:

```
$ curl -s ".../projects?limit=500&offset=0" | jq -r '.total'
866
$ curl -s -o /dev/null -w 'http=%{http_code}\n' ".../projects?limit=500&offset=500"
http=502

$ BASE=http://127.0.0.1:18999 bash docs/audits/cf089-census-recipe.sh
jq: error (at <stdin>:0): Cannot iterate over null (null)
1
code-factory enabled=true admission=cooldown parent=x
RC=0
```

Ground truth 2, printed count 1, exit 0. The only signal is a `jq` stderr line that changes
neither the number nor the status — the reader of a count sees one row and no failure.

Full transcript: `docs/audits/code-factory-qa-2026-11-03-cf089.probe.txt`.
Re-run it with `bash docs/audits/cf089-census-standin.py &` and
`bash docs/audits/cf089-make-transcript.sh`.

## Filed

`CF-089` — the printed census recipe must treat a failed page as a failure: named message,
nonzero exit, and a coverage assertion against `total`, with one `tests/selftest.sh` arm per
failure shape (fetch error, non-2xx, body without `.projects`) and one for the short page.
The fixture must be able to go green, per AGENTS.md rule 2.

## Not done in this tick

- No live-scheduler failure was induced (a restart mid-census is not something a QA tick
  should stage against the shared scheduler); the failure shape is exercised against the
  committed stand-in instead, and the row's acceptance criteria require the fixed recipe to
  fail against that same stand-in.
- The other pending gap rows (`CF-081`, `CF-086`, `CF-087`, `CF-088`) were not re-measured
  this tick.
