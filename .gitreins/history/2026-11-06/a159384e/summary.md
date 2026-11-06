# Verdict: CF-227

**Task:** codex conformance smoke must measure the installed harness, not the host's ambient ~/.codex config
**Evaluated:** 2026-11-06T15:22:38.359501
**Result:** ✓ PASS

## Pipeline Stages

- ✓ **tier1**
  -   ✓ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: scanners=gitleaks+builtin cross-check
  ✓ tests: scanners: nice=nice -n 10
- ✓ **tier2**
  - COMPLETE
  ✓ bash tests/harness-conformance.sh --only codex prints 'PASS  codex:smoke' naming the pinned provider and model and the turn's artifact, and bash tests/selftest.sh stays green including a new arm that proves the codex smoke invocation pins provider+model on argv (a fake codex on PATH records argv).: Ran `bash tests/harness-conformance.sh --only codex` (exit 0): prints `PASS  codex:smoke — smoke.txt contains CF-CONF-codex-cb3eb0 (21 B, sha256 49f7ee7f1a44..., exit 0; token sha256 5e0a374861aa...; provider openai, model gpt-6-luna; binary /home/kara/.local/codex/0.166.0/bin/codex (the path its --check measured))` — names pinned provider (openai), pinned model (gpt-6-luna) and the turn's artifact (smoke.txt, byte count, sha256). Ran `bash tests/selftest.sh` (exit 0, tail `SELFTEST: PASS`, 178 PASS arms; the 36 'FAIL' strings are intentional fixture rows). New §45 arms pass: 'PASS codex smoke argv carries -c model_provider="openai" -m fixture-codex-model and the needle; the FAIL names the provider and its base_url', 'PASS codex exiting 0 with no artifact -> FAIL exited 0 without writing smoke.txt', and the falsifiability control 'PASS the pin-removed control records an argv with no model_provider -> the arm above can fail'. The arm installs a fake codex at $tmpd/codexpin/bin/codex on PATH that appends `$*` to FAKE_CODEX_ARGV and asserts the recorded argv contains `-c model_provider="openai"` and `-m fixture-codex-model`. Implementation in tests/harness-conformance.sh: CODEX_PROVIDER=openai, CODEX_MODEL=${HC_CODEX_MODEL:-gpt-6-luna}, codex arm `codex exec --skip-git-repo-check -s workspace-write -c "model_provider=\"$CODEX_PROVIDER\"" -m "$CODEX_MODEL" -- "$prompt"`; docs/HARNESS-CONFORMANCE.md:19,57 and specs/HARNESS-MATRIX.md:54 record the pin.
Both legs verified by actual runs: the codex conformance cell passes naming provider openai, model gpt-6-luna and the smoke.txt artifact, and the full selftest is green with a new fake-codex-on-PATH arm proving the argv pin (plus a pin-removed control).

## Summary

Judge Result: CF-227

Stage tier1: PASS
    ✓ lint: scanners: nice=nice -n 10
  ✓ secrets: secrets: scanners=gitleaks+builtin cross-check
  ✓ tests: scanners: nice=nice -n 10

Stage tier2: PASS
  COMPLETE
  ✓ bash tests/harness-conformance.sh --only codex prints 'PASS  codex:smoke' naming the pinned provider and model and the turn's artifact, and bash tests/selftest.sh stays green including a new arm that proves the codex smoke invocation pins provider+model on argv (a fake codex on PATH records argv).: Ran `bash tests/harness-conformance.sh --only codex` (exit 0): prints `PASS  codex:smoke — smoke.txt contains CF-CONF-codex-cb3eb0 (21 B, sha256 49f7ee7f1a44..., exit 0; token sha256 5e0a374861aa...; provider openai, model gpt-6-luna; binary /home/kara/.local/codex/0.166.0/bin/codex (the path its --check measured))` — names pinned provider (openai), pinned model (gpt-6-luna) and the turn's artifact (smoke.txt, byte count, sha256). Ran `bash tests/selftest.sh` (exit 0, tail `SELFTEST: PASS`, 178 PASS arms; the 36 'FAIL' strings are intentional fixture rows). New §45 arms pass: 'PASS codex smoke argv carries -c model_provider="openai" -m fixture-codex-model and the needle; the FAIL names the provider and its base_url', 'PASS codex exiting 0 with no artifact -> FAIL exited 0 without writing smoke.txt', and the falsifiability control 'PASS the pin-removed control records an argv with no model_provider -> the arm above can fail'. The arm installs a fake codex at $tmpd/codexpin/bin/codex on PATH that appends `$*` to FAKE_CODEX_ARGV and asserts the recorded argv contains `-c model_provider="openai"` and `-m fixture-codex-model`. Implementation in tests/harness-conformance.sh: CODEX_PROVIDER=openai, CODEX_MODEL=${HC_CODEX_MODEL:-gpt-6-luna}, codex arm `codex exec --skip-git-repo-check -s workspace-write -c "model_provider=\"$CODEX_PROVIDER\"" -m "$CODEX_MODEL" -- "$prompt"`; docs/HARNESS-CONFORMANCE.md:19,57 and specs/HARNESS-MATRIX.md:54 record the pin.
Both legs verified by actual runs: the codex conformance cell passes naming provider openai, model gpt-6-luna and the smoke.txt artifact, and the full selftest is green with a new fake-codex-on-PATH arm proving the argv pin (plus a pin-removed control).

Overall: PASS ✓
