# Parity Exceptions Ledger

Use this file for known parity gaps that cannot be solved immediately.

## Format
- `ID`:
- `Mode`:
- `Area`: HUD / mechanics / audio / FX
- `Expected TF2`:
- `Current addon`:
- `Root cause`:
- `Decision`: defer / emulate / blocked
- `Owner`:
- `Evidence`:

## Open
- EX-CP-001:
  - Mode: CP
  - Area: mechanics + HUD messaging
  - Expected TF2: `PlayerMayCapturePoint`-driven message reasons for all edge conditions.
  - Current addon: partial approximation from trigger/owner/capper state.
  - Root cause: full TF2 game-rules checks are not yet mirrored in one shared server contract.
  - Decision: emulate with expanded server-side reason codes in Phase A follow-up.
  - Owner: parity phase A.
  - Evidence: pending.
