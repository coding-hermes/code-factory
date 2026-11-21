# HARDWARE PLAN — inference for the bunker fleet

Census date: 2026-11-21. Every number below carries its source; numbers without
a source are deleted, not softened. The topology this plan serves is
`specs/NODE-PHYSICAL.md` (one bunker = one project = one physical system;
multiple bunkers per unit allowed; bunkers CPU-only).

## 1. Measured demand (control-host ledger, 2026-10-22 → 2026-11-21)

Source: Hermes `state.db` `session_model_usage` (all seats) and the scheduler
`ticks` table (15,500 ticks).

| Metric | 30-day value | Per day |
|---|---|---|
| API calls | 1,402,273 | ~46.7K |
| Input tokens (new) | 10.017B | 334M |
| Cache-read tokens | 204.25B | 6.81B |
| Output tokens | 719.27M | 24.0M (peak 44.3M, Nov 16) |
| Ticks | 15,500 (500/day) | — |
| Worker sessions | 3,471 (avg 5.9M in+cache, 22K out each) | ~116 |

Split frontier-vs-grunt (frontier = GPT-sub seats + deepseek-v4-pro/k3-pro
class): frontier 188.7M out (26.2%), grunt 530.6M out (73.8%). Output has grown
3× in the final two weeks of the window (14.6M/day Nov 8 → 44.3M/day Nov 16).

## 2. Unconstrained projection (all 77 families, all lanes, no gates)

All 36 paused families resume; every lane at its configured cadence
(foreman 6h, sync 6h, qa 12h, pm/ops/releng daily, docs/readme/perf/review
weekly, dogfood 3-day); ~2 worker waves per foreman tick.

- ~1,060 ticks/day (measured 500/day throttled)
- Lane tick: 4.15M in+cache + 9.3K out; worker: 5.9M in+cache + 22K out
  (both measured, source: ticks table + worktree-cwd sessions, 30d)
- **Fleet: ~17B in+cache/day + ~56M output/day**
- Decode: 650 tok/s (24h flat) → 1.3K tok/s (12h workday) → **2-4K tok/s burst**
- Prefill: 17B/day naive (197K tok/s avg) → **~1-2B/day with resident lane
  caches** (see NODE-PHYSICAL.md; this is the binding constraint, not decode)
- KV: 15-20 concurrent streams × 128K context ≈ 100GB at int8 KV

## 3. Current hardware census (owned, Nov 2026)

- 5× RTX 3090 (24GB, 936GB/s, NVLink-capable in pairs)
- 3-4× RTX 4090 (24GB, 1008GB/s)
- RTX 2080 Ti 22GB mods (Turing; 69 tok/s median on Qwen3.6-35B-A3B,
  source: llamaperf.com/gpu/rtx-2080-ti-22gb, Nov 2026)
- DDR4 hoard (sufficient for EPYC-class big-RAM boxes: 384-512GB each)
- ~20 bunker units on order (agent nodes, CPU-only per NODE-PHYSICAL.md)
- **GPU purchase target: zero for agents.** Buy list is platform-only (EPYC
  board/CPU/PSU/chassis for the big-RAM rig; optional one NVLink bridge for a
  3090 dense-70B TP pair — measured +50% on 2-GPU TP, ~nothing for MoE offload).

## 4. Serving plan

**Central inference racks on the orchestration LAN** (not per-bunker GPUs —
central placement is what makes resident lane caches and shared prefix reuse
possible; 20 per-bunker GPUs would need 20+ cards at worse utilization).

| Tier | Model + engine | Rig | Measured/cited speed |
|---|---|---|---|
| Heavy grunt | DeepSeek-V4.1-Flash (Basalt or llama.cpp) | used EPYC + 384-512GB DDR4 | 62 tok/s decode at 125-141K agentic context (Basalt docs, Nov 2026); needs ~320GB+ RAM for experts |
| Bulk grunt | Qwen3.8-Flash-Next 125B MoE NVFP4 (Basalt on Blackwell / Strata on Ampere) | 4×4090 rig + 5×3090 rig + 128-256GB DDR4 | 110-124 tok/s single-stream on 4090 w/ MTP (community, HN thread 49953495); ~75-100 tok/s on one 3090 at IQ3_S/Q2_0; 300 tok/s prose, 600 struct, 10K tok/s prefill on 5090+5060Ti (Basalt 0.2.0 release notes) |
| Cheap lanes | Qwen3.6-35B-A3B (llama.cpp, MTP drafting) | 2080 Ti 22GB mods | 69 tok/s median (llamaperf, 2026-11-20) |
| Frontier (stays cloud) | gpt-6.1-terra / gpt-6-luna subs + deepseek-v4-pro PAYG | control host | planning, verification, tier-2 judges only — the 26% bucket |

Capacity verdict: the owned 9 GPUs (5×3090 + 4×4090) cover roughly 600-1,000
tok/s aggregate batched decode — about one third of the unconstrained 2-4K tok/s
burst target. Reaching the target needs **16-24 GPUs central**, i.e. 2-3 more
racks of used 3090/4090 class. Prefill headroom rides the same racks once
resident lane caches land; without them prefill is the infeasible leg.

## 5. Sequencing

1. Bring up one inference rack on the existing 9 GPUs; point 3-5 pilot bunkers
   at it; verify resident-cache hit rate per lane (measurable: prefill tok/tick
   before vs after).
2. Land the EPYC big-RAM rig from the DDR4 hoard; serve DeepSeek-V4.1-Flash.
3. Scale racks to 16-24 GPUs (used market) while DRAM/GPU prices are still
   climbing quarter-over-quarter (TrendForce 2026-11-18: contract gains shrink
   but keep rising through Q1 2027).
4. Re-enable the 36 paused families as rack capacity lands, batch by batch,
   watching the load gate as a circuit breaker rather than a steady-state limit.

## 6. Deliberately not bought

- New consumer GPUs at 3× MSRP (RTX 5090 street $6.2-7.4K, Tom's Hardware
  2026-11: cheapest Newegg card $6,599) — the used tier plus owned cards wins.
- Per-bunker GPUs — violates the CPU-only node; 20+ cards at worse utilization.
- A prefill-only farm — resident caches make it unnecessary; revisit only if
  measured cache hit rate per lane stays below ~80%.
