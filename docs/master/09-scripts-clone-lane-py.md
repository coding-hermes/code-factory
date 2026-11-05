# 09. scripts/clone_lane.py

| Field | Value |
|---|---|
| Path | `/home/kara/code-factory/scripts/clone_lane.py` |
| Repository | `code-factory` |
| Revision | `3c4c639` |
| Status | **VERIFIED — source reviewed; key claims carry `file:line` locators** |

## 1. Purpose and why it matters

- What breaks if this module is absent: New workdirs in families the scheduler recognises but has no workdir root for (`docs`, `readme`, `perf`, `review`) remain offboarded. Source: `/home/kara/code-factory/scripts/clone_lane.py:4-7` verbatim:

  > the scheduler's lane-onboarding gate refuses EVERY workdir for families it
  > recognises but has no workdir root for (docs, readme, perf, review — SCHED-GAP-1733 criterion 2
  > keeps them "offboarded"). Existing live lanes in those families predate the gate. So the only
  > way to give a new project the same shape is to clone a live row.
