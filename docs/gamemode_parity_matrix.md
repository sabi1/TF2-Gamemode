# TF2 Gamemode Parity Matrix

This file tracks actual implementation status in the addon, not just whether a mode name or logic entity exists.

Status meanings:
- `implemented`: mode has substantive gameplay logic and map entity support
- `partial`: enough support exists for some maps or flows, but parity is incomplete
- `stub`: entity or detection exists, but the actual mode logic is largely unimplemented

## Core modes

| Mode | TF2 map prefixes / logic | Status | Notes |
| --- | --- | --- | --- |
| Control Points | `cp_`, `tc_`, `team_control_point_master` | partial | Core CP entities exist; `team_numcap_*`, blocked/revert reconciliation, and CP/KOTH HUD progress state are now source-backed, but full round-rule validation and announcer parity still remain. |
| Capture the Flag | `ctf_`, `item_teamflag` | partial | Base flag logic exists; own-flag-at-home capture blocking and enemy-cap notifications are now in place, but full source parity still is not verified. |
| King of the Hill | `koth_`, `tf_logic_koth` | partial | Real logic exists in `tf_logic_koth`; `unlock_point` setup lock and timer setup-state behavior are now implemented, but warning/announcer parity is still incomplete. |
| Payload / Payload Race | `pl_`, `plr_`, `team_train_watcher`, `tf_logic_multiple_escort` | partial | Cart/watcher support exists, overtime/timeout resolution now follows live watcher state, and the escort HUD is closer to Valve's implementation; full payload-race and hill/teardrop parity still need more work. |
| Arena | `arena_`, `tf_logic_arena` | partial | Arena round-start and cap-enable outputs now follow map delay or `tf_arena_override_cap_enable_time`; full queue / spectate / first-blood parity is still incomplete. |
| Mann vs Machine | `mvm_`, `tf_logic_mann_vs_machine`, `item_teamflag_mvm` | partial | Large bespoke implementation exists, but cannot be called 1:1 complete yet. |

## Secondary / special modes

| Mode | TF2 map prefixes / logic | Status | Notes |
| --- | --- | --- | --- |
| Special Delivery | `sd_` | partial | Prefix and neutral-flag detection exist, neutral captures now resolve as team wins instead of CTF scoring, and flag detection zones now expose TF-style flag touch / pickup / drop outputs; full round/entity parity and HUD validation still need more work. |
| PASSTIME | `pass_`, `passtime_logic` | partial | `passtime_logic`, spawn/goal/trigger entities, goalie zones, no-ball zones, server game events, and most HUD reticle/offscreen state now exist; full TF2 ball physics/effects parity still needs live validation. |
| Player Destruction | `pd_`, `tf_logic_player_destruction` | partial | Score tracking, countdown, dynamic max-score updates, and team outputs exist; PD logic now filters only PD flag events, but full map-rule and HUD parity still need validation. |
| Robot Destruction | `rd_`, `tf_logic_robot_destruction` | partial | Score and stolen-core output logic exists, and RD logic now filters only RD flag events; full robot-mode rules and HUD parity still need validation. |
| Mannpower | `powerup_`, `tf_logic_mannpower`, `info_powerup_spawn`, `item_powerup_crit`, `item_powerup_uber`, `func_powerupvolume` | partial | Mode flagging, grappling-hook enablement, temp powerup pickups, rune logic, and powerup volume behavior now exist; official-style map powerups still depend on authored `info_powerup_spawn` entities, and remaining gameplay parity is incomplete. |
| Hybrid CTF-CP | `tf_logic_hybrid_ctf_cp` | partial | Logic entity now exposes real enable/disable state and shared mode flags, and the shared HUD mode resolver now prefers live runtime state over prefix heuristics; full ruleset parity is still incomplete. |
| Medieval Mode | `tf_logic_medieval` | partial | Medieval logic now applies melee-only restrictions and allows medieval-marked weapons, but full source parity is not complete. |

## Supporting logic already present

| Logic | Status | Notes |
| --- | --- | --- |
| `tf_logic_cp_timer` | partial | Countdown logic exists and fires outputs. |
| `tf_logic_competitive` | partial | Competitive spawn-door outputs are wired. |
| `tf_logic_holiday` | partial | Halloween-specific global behavior exists. |
| `tf_logic_multiple_escort` | partial | Logic entity now exposes real enable/disable state and shared mode flags. |

## Immediate implementation order

1. Fill stub mode logic entities with real behavior and outputs where TF2 maps depend on them.
2. Unify map/mode detection so HUD, rules, and entities all resolve the same mode state.
3. Implement medium-complexity modes next: Special Delivery, Medieval, Hybrid CTF-CP, Multiple Escort.
4. Implement large bespoke systems last: PASSTIME, Player Destruction, Robot Destruction, Mannpower.
