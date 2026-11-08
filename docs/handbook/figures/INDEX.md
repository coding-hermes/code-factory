# Figures

Generated from `docs/SYSTEM-MODEL.yaml` by `scripts/gen_handbook_figures.py`.
Genre: nasa-handbook line drafting — black ink, line-style state, Routed Gothic labels.
Every label is verified >= 2.05 mm at the builder's print scale; ink is black/white only.

| figure | what it answers |
|---|---|
| `system-map.svg` | 28 components in 6 layers; every edge is a numbered contract |
| `module-M0.svg` | M0 SHARED CONTRACT — inputs left, outputs right, flows below |
| `module-M1.svg` | M1 PROVISIONING — inputs left, outputs right, flows below |
| `module-M2.svg` | M2 DISPATCH (NODE SIDE) — inputs left, outputs right, flows below |
| `module-M3.svg` | M3 REPOSITORY — inputs left, outputs right, flows below |
| `module-M4.svg` | M4 BOARD — inputs left, outputs right, flows below |
| `module-M5.svg` | M5 HARNESS — inputs left, outputs right, flows below |
| `module-M6.svg` | M6 DOCUMENTATION — inputs left, outputs right, flows below |
| `module-M7.svg` | M7 GITHUB — inputs left, outputs right, flows below |
| `module-M8.svg` | M8 SAFETY — inputs left, outputs right, flows below |
| `module-M9.svg` | M9 SCHEDULER — inputs left, outputs right, flows below |
| `module-M10.svg` | M10 CRIER — inputs left, outputs right, flows below |
| `module-M11.svg` | M11 DISPATCHER — inputs left, outputs right, flows below |
| `module-M12.svg` | M12 INFERENCE PROXY — inputs left, outputs right, flows below |
| `F1.svg` | F1 DISPATCH — How does a board row become settled, published work? |
| `F2.svg` | F2 PROVISIONING — How does a bare host become a node? |
| `F3.svg` | F3 MEMORY — How does a run become searchable? |
| `F4.svg` | F4 DOCUMENTATION — How does a component become an approved document? |
| `F5.svg` | F5 LANDING — How does work reach main? |
| `F6.svg` | F6 MAINTENANCE — What keeps disks, branches, caches and freshness honest? |
| `F7.svg` | F7 MONITORING — How does anyone learn the machine is unwell? |
| `F8.svg` | F8 RECOVERY — What happens after a crash, restart or orphaned run? |
| `F9.svg` | F9 DEGRADATION — A dependency is gone — what does the system do? |
| `F10.svg` | F10 TEARDOWN / REBUILD — How is a node or lane removed without residue? |
| `F11.svg` | F11 SCHEDULING ADMISSION — Does a lane's tick get admitted, and why not? |
| `F12.svg` | F12 CREDENTIAL LIFECYCLE — How does a credential stay fresh, scoped and out of argv? |
| `F13.svg` | F13 UPGRADE AND MIGRATION — How does a pinned bump or schema change reach the running system? |
| `F14.svg` | F14 OBSERVABILITY INGESTION — Where does a tick, turn or message become a visible, attributed line? |
| `F15.svg` | F15 BACKUP AND RESTORE — Can an artifact be restored and proven? |
| `F16.svg` | F16 MULTI-NODE FAN-OUT — How does one directive reach several nodes, each with its own receipt? |
| `board-lifecycle.svg` | board row state — including the paths that are not 'forward' |
| `tick-lifecycle.svg` | scheduler tick state — admission, dispatch, settlement (M9 §3) |
