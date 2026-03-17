# TF2 Gamemode Parity Matrix

This file tracks actual implementation status in the addon, not just whether a mode name or logic entity exists.

Status meanings:
- `implemented`: mode has substantive gameplay logic and map entity support
- `partial`: enough support exists for some maps or flows, but parity is incomplete
- `stub`: entity or detection exists, but the actual mode logic is largely unimplemented

## Core modes

| Mode | TF2 map prefixes / logic | Status | Notes |
| --- | --- | --- | --- |
| Control Points | `cp_`, `tc_`, `team_control_point_master` | partial | Core CP entities exist; parity still needs full round-rule validation. |
| Capture the Flag | `ctf_`, `item_teamflag` | partial | Base flag logic exists; full source parity still not verified. |
| King of the Hill | `koth_`, `tf_logic_koth` | partial | Real logic exists in `tf_logic_koth`, but still needs source-side validation. |
| Payload / Payload Race | `pl_`, `plr_`, `team_train_watcher`, `tf_logic_multiple_escort` | partial | Cart/watcher support exists, and `tf_logic_multiple_escort` now exposes shared mode state; full payload-race parity still needs validation. |
| Arena | `arena_`, `tf_logic_arena` | partial | Basic arena outputs exist; full class/team/round lock parity not complete. |
| Mann vs Machine | `mvm_`, `tf_logic_mann_vs_machine`, `item_teamflag_mvm` | partial | Large bespoke implementation exists, but cannot be called 1:1 complete yet. |

## Secondary / special modes

| Mode | TF2 map prefixes / logic | Status | Notes |
| --- | --- | --- | --- |
| Special Delivery | `sd_` | partial | Prefix and neutral-flag detection exist, and neutral captures now resolve as team wins instead of CTF scoring; full round/entity parity still needs validation. |
| PASSTIME | `pass_`, `passtime_logic` | partial | `passtime_logic`, spawn/goal/trigger entities, goalie zones, and no-ball zones now expose real server-side state, scoring, catches, and out-of-bounds handling; full TF2 ball physics and HUD parity are still incomplete. |
| Player Destruction | `pd_`, `tf_logic_player_destruction` | partial | Score tracking, countdown, and team outputs exist, but full map-rule and HUD parity still needs validation. |
| Robot Destruction | `rd_`, `tf_logic_robot_destruction` | partial | Score and stolen-core output logic exists, but full robot-mode rules and HUD parity still needs validation. |
| Mannpower | `powerup_`, `tf_logic_mannpower`, `info_powerup_spawn`, `item_powerup_crit`, `item_powerup_uber`, `func_powerupvolume` | partial | Mode flagging, grappling-hook enablement, temp powerup pickups, and powerup volume behavior now exist; full rune spawning and dominant-state parity are still incomplete. |
| Hybrid CTF-CP | `tf_logic_hybrid_ctf_cp` | partial | Logic entity now exposes real enable/disable state and shared mode flags; full ruleset parity is still incomplete. |
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
