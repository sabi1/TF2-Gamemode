# Phase A Checklist (CP + KOTH)

## Mechanics
- [ ] CP capture starts/stops only when allowed by ownership/lock/team-can-cap rules.
- [ ] CP required cappers (`team_numcap_*`) gate capture progress/messages correctly.
- [ ] CP blocked/revert states are represented consistently in server snapshot + HUD.
- [ ] KOTH point lock/unlock timing uses `unlock_point`.
- [ ] KOTH active clock team switches with point ownership transitions.
- [ ] Overtime/wait/setup transitions are represented in timer state.

## HUD / RES
- [ ] CP icon layout uses `controlpointicon.res` values.
- [ ] CP progress bubble uses `controlpointprogressbar.res` values.
- [ ] CP progress ring is animated radial progress while capping.
- [ ] KOTH timer panel uses `hudobjectivekothtimepanel.res` values.
- [ ] HUD visibility/state transitions match objective state (active, blocked, locked).

## Audio
- [ ] CP contested warning audience is team-correct (defenders for owned point).
- [ ] Neutral CP contested warning uses neutral variant and excludes capping team.
- [ ] KOTH setup/round timer warning lines are timing-correct.

## Proof / Regression
- [ ] `tf_parity_dump_objectives` JSON captured for each state scenario.
- [ ] `tf_parity_dump_hud_state` JSON captured with matching HUD state.
- [ ] Screenshot/video pairs compared against TF2 references.
- [ ] No regressions in existing payload/ctf HUD visibility gates.
