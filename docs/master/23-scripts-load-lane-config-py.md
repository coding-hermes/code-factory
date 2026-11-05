# 23. scripts/load_lane_config.py

| Field | Value |
|---|---|
| Path | `/home/kara/code-factory/scripts/load_lane_config.py` |
| Repository | `code-factory` |
| Revision | `3c4c639` |
| Status | **RED — no verification recorded** |

## 1. Purpose and why it matters

- What breaks if this module is absent: The `UPDATE` at `scripts/load_lane_config.py:33-36` never runs. That statement is the only writer in the source for `namespace_id`, `admission_mode`, `prompt`, and `prompt_mode='append'` on the CFG project rows listed at `scripts/load_lane_config.py:20-27`. Without it, those lanes keep their previous values and the prompt files under `ROOT/prompts/<prompt_name>.md` are not copied into `projects.prompt`; the copy is the same `UPDATE`, using text read at `scripts/load_lane_config.py:32`.
- What breaks if it lies: The
