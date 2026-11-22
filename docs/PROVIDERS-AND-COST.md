# Providers and cost

This page describes pins and defaults in this repository, not a live account or a
promise about what a router currently serves. A harness, provider lane and model
are distinct choices; a requested model is not proof of the served model
(`specs/HARNESS-MATRIX.md:25`, `specs/ENVELOPE.md:114`).

## Lane-to-model table

| Lane or role | Provider lane | Model id | Source citation |
|---|---|---|---|
| Master-doc fill, API | `deepseek` | `deepseek-v4-flash` | `scripts/master_doc_fill.py:49-54` |
| Master-doc fill, API | `xkiro` | `openai/gpt-6.1-sol` | `scripts/master_doc_fill.py:55-59` |
| Master-doc review, `sol` seat | `xkiro` | `openai/gpt-6.1-sol` | `scripts/master_doc_panel.py:30-31` |
| Master-doc review, `k3` seat | `xkiro` | `moonshotai/kimi-k3-agent` | `scripts/master_doc_panel.py:30-32` |
| Master-doc review, `flash` seat | `deepseek` | `deepseek-v4-flash` | `scripts/master_doc_panel.py:30-33` |
| Handbook panel writer, overrideable default | `deepseek` | `deepseek-v4-pro` | `scripts/panel_loop.py:38-39` |
| Master-doc fill, Hermes engine default | selected by `--provider` (default `deepseek`) | `openai/gpt-6.1-sol` | `scripts/master_doc_fill.py:399`, `scripts/master_doc_fill.py:410-416`, `scripts/master_doc_fill.py:454-457` |
| Dispatch example, not a fleet-wide pin | `xkiro` | `openai/gpt-6.1-sol` | `specs/ENVELOPE.md:16-20` |

The fill API defaults to `deepseek` but permits either listed provider; the
Hermes-engine model default can be overridden independently. The handbook
writer's default is likewise environment-overridable, not a universal lane pin.
The family-lane provisioner preserves existing scheduler model and provider
values rather than naming defaults (`scripts/add_family_lanes.py:127-142`);
`load_lane_config.py` updates other lane fields, not model pins
(`scripts/load_lane_config.py:36-53`). The node example uses a proxy provider
and a model placeholder, not an additional model pin (`config/node.env.example:24-27`).

## Payment classes

A subscription or flat-rate bucket is a prepaid or fixed-cost entitlement: using
it consumes whatever allowance or contractual capacity the operator has arranged.
Pay-as-you-go (PAYG) is usage-billed; selecting it can create incremental charges.
Operators should check their own terms, available capacity and authorization before
choosing a lane. This tree supplies no prices, quotas or account-specific terms.

The fill script states that this project uses xkiro and DeepSeek PAYG and does not
spend Ollama credits (`scripts/master_doc_fill.py:47-48`); the panel describes
the same policy (`scripts/master_doc_panel.py:15-16`). The source does not establish
that xkiro is a subscription bucket, so do not assume its billing class from its
name. The historical handbook writer default above is a separate script default,
not a claim that every execution follows the fill script's policy.

## Fallback tiers

The harness contract receives `CF_MODEL` from the directive as the model requested
by task-router; `CF_BASE_URL` is optional and defaults to the node router
(`specs/HARNESS-MATRIX.md:143-153`). Thus model routing and fallback belong at the
router tier rather than being inferred as a provider failover chain in harness
calling code. Actual router configuration and availability are outside this tree;
an alternate gateway or shim may be supplied explicitly.

No explicit provider/model fallback chain exists in this tree. The explicit
`directive.harness` → `lane.harness` → family matrix → `hermes` rule is a
**harness-selection** fallback, not a provider or model fallback
(`specs/HARNESS-MATRIX.md:124-139`). The direct fill API call selects one
provider from `PROVIDERS` (`scripts/master_doc_fill.py:87-88`), and its CLI
selects the provider (`scripts/master_doc_fill.py:395-399`); these are not a
failover sequence.

## Pin authority and recording

A lane pin may only be changed through the owner-authorized path, and the change
must be recorded. Obtain owner authorization before changing a source pin or a
node's declared model configuration; retain a reviewable change record and verify
what the target actually received. This is an operator rule, not a claim that the
scripts enforce owner identity.

For node configuration, `ALLOWED_CONFIG` includes `model.name` and
`model.provider` (`scripts/node_env.py:59-68`); `parse_config_sets` rejects keys
outside that allow-list (`scripts/node_env.py:245-256`). `plan_config` calls
`set_scalar` to prepare leaf changes (`scripts/node_env.py:382-420`), and `main`
writes the resulting config through `write_atomic` on apply
(`scripts/node_env.py:426-441`, `scripts/node_env.py:588-595`). Check mode prints
a diff without writing (`scripts/node_env.py:24-28`); config changes are printed
as `DIFF` rows (`scripts/node_env.py:547-555`).

**Gap:** this path does not itself authenticate the owner or persist an audit
record of authorization or changes; its output is not a durable change log.
The operator must arrange and retain that record separately. Do not confuse the
current configuration file or an emitted diff with an automatic audit trail.
