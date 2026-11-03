# CF-065 verbatim run of the README lanes census block
# extracted from: README.md @ ac30ceb8265726b27200aebb3a98576d5047b22b
# run at: 2026-11-03T15:43:02Z  host: Linux 7.0.0-38-generic
--- block begin ---
total=$(curl -s 'http://127.0.0.1:9090/api/v1/projects?limit=1' | jq -r '.total // empty')
[ -n "$total" ] || { echo 'census: the scheduler answered without a total; refusing to count' >&2; exit 1; }
off=0; : > /tmp/cf-lanes.txt
while [ "$off" -lt "$total" ]; do
  curl -s "http://127.0.0.1:9090/api/v1/projects?limit=500&offset=$off" \
    | jq -r '.projects[] | select(.name|startswith("code-factory"))
             | "\(.name) enabled=\(.enabled) admission=\(.admission_mode) parent=\(.parent // "-")"' \
    >> /tmp/cf-lanes.txt
  off=$((off + 500))
done
wc -l < /tmp/cf-lanes.txt; cat /tmp/cf-lanes.txt
--- block end ---
19
code-factory enabled=true admission=tasks parent=
code-factory-docs enabled=true admission=cooldown parent=code-factory
code-factory-docs-qa enabled=true admission=cooldown parent=code-factory
code-factory-dogfood enabled=true admission=cooldown parent=code-factory
code-factory-duckbrain enabled=true admission=tasks parent=code-factory
code-factory-duckbrain-dogfood enabled=true admission=cooldown parent=code-factory
code-factory-duckbrain-pm enabled=true admission=cooldown parent=code-factory
code-factory-duckbrain-qa enabled=true admission=cooldown parent=code-factory
code-factory-duckbrain-releng enabled=true admission=cooldown parent=code-factory
code-factory-duckbrain-sync enabled=true admission=cooldown parent=code-factory
code-factory-perf enabled=true admission=cooldown parent=code-factory
code-factory-pm enabled=true admission=cooldown parent=code-factory
code-factory-qa enabled=true admission=cooldown parent=code-factory
code-factory-readme enabled=true admission=cooldown parent=code-factory
code-factory-readme-qa enabled=true admission=cooldown parent=code-factory
code-factory-releng enabled=true admission=cooldown parent=code-factory
code-factory-releng-qa enabled=true admission=cooldown parent=code-factory
code-factory-review enabled=true admission=cooldown parent=code-factory
code-factory-sync enabled=true admission=cooldown parent=code-factory
RC=0
