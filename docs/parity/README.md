# TF2 Parity Program

This folder tracks objective parity progress against retail TF2 behavior.

## Authority order
1. Retail TF2 runtime behavior and VPK assets (`resource/ui/*.res`, sounds, materials).
2. TF2 source references for behavior disambiguation.
3. Existing addon behavior only when 1/2 are unavailable.

## Workflow
1. Implement a single phase (start with CP/KOTH).
2. Run targeted parity checks.
3. Update `parity_matrix.csv` with proof references.
4. Log unavoidable differences in `parity_exceptions.md`.

## Runtime tooling
- Server snapshot: `tf_parity_dump_objectives`
- Client HUD snapshot: `tf_parity_dump_hud_state`
- CP overlay debug: `tf_parity_cp_overlay 1`
- Existing debug bridge files:
  - `data/tf_debug/server_state.json`
  - `data/tf_debug/server_events.jsonl`
  - `data/tf_debug_state.json`
  - `data/tf_debug_events.jsonl`
