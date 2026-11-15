#!/usr/bin/env bash
# CF-440 red-proof fixture: deliberately malformed so `bash -n` fails.
# Section 1 of tests/selftest.sh asserts every scripts/*.sh parses, so a hosted
# run of the gate against this commit must go red and name this file.
cf440_redproof() {
  if [ "${1:-}" = "probe" ]; then
    echo "probe"
  fi
