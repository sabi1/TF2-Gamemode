# Taunt Parity Audit

This document tracks TF2 taunt parity work against the local Valve references already stored in this repository.

## Source Of Truth

- `tmp/source-sdk-2013/src/game/client/tf/clientmode_tf.cpp`
  - `TauntHandlesKeyInput`: TF2 stops taunts on `+jump`, `+taunt`, and `weapon_taunt`.
- `tmp/source-sdk-2013/src/game/client/tf/tf_hud_menu_taunt_selection.cpp`
  - `CHudMenuTauntSelection`: 8-slot taunt HUD behavior, weapon taunt fallback, cancel behavior, slot input handling.
- `tmp/source-sdk-2013/src/game/client/tf/tf_hud_menu_taunt_selection.h`
  - Defines `NUM_TAUNT_SLOTS = 8`.
- `C:/Users/Seb/Documents/source-sdk-2013/src/game/server/tf/tf_player.cpp`
  - `PlayTauntSceneFromItem`, `PlayTauntRemapInputScene`, `StopTaunt`, `EndLongTaunt`, and partner-taunt flow are the strict server-side taunt reference for intro sounds, delayed loop starts, remap timing, and stop behavior.
- `tmp/tf2_extract/scripts/hudlayout.res`
  - `HudMenuTauntSelection` layout placement.
- `gamemodes/tf/gamemode/items/items_game_nomount.lua`
  - Taunt schema data, per-class scenes, outro scenes, move/hold flags, input remaps.
- `tmp/tf2_extract/scripts/items` and `tf2_dump/loose/scripts/items/items_game.txt`
  - Additional item/econ taunt reference material.
- `gamemodes/tf/gamemode/contents/game_sounds_player.lua`
- `gamemodes/tf/gamemode/contents/game_sounds_taunt_workshop.lua`
  - Exact local sound script names used by newer taunts when item schema alone is not enough.

## Completed In This Pass

- Added a shared server-side `stop_taunt` path in `gamemodes/tf/gamemode/shd_taunts.lua`.
- Added `weapon_taunt` command parity in `gamemodes/tf/gamemode/init.lua`.
- Updated client bind handling in `gamemodes/tf/gamemode/cl_hud.lua` so:
  - `+jump`, `+taunt`, and `weapon_taunt` stop taunts while taunting.
  - `weapon_taunt` performs weapon taunt while the taunt HUD is open.
  - `lastinv`, `invnext`, `invprev`, and `+attack` close the taunt HUD like Valve.
- Prevented taunt HUD opening while in Halloween kart mode in `gamemodes/tf/gamemode/vgui/hud_menutaunt.lua`.
- Earlier pass already ensured jump cancels legacy looping taunts via server command handling.
- Added schema-partner taunt cancellation state so partner taunts and "waiting for partner" intros can now be cancelled through the unified stop path.
- Added schema sound fallbacks for released taunts whose workshop/local sound scripts exist but whose item schema does not expose a usable taunt sound attribute in this addon:
  - `Taunt: The Balloonibouncer`
  - `Taunt: Didgeridrongo`
  - `Taunt: Scotsmann's Stagger`
  - `Taunt: Runner's Rhythm`
  - `Taunt: Luxury Lounge`
  - `Taunt: The Pooped Deck`
  - `Taunt: Scorcher's Solo`
- Added schema sound-profile support for:
  - periodic ambient taunt sounds while a schema hold taunt is active
  - input-remap sounds for schema taunts that use `IN_ATTACK` / `IN_ATTACK2` tricks
- Applied the new input-remap / start-stop sound path to:
  - `Taunt: Spin-to-Win`
  - `Taunt: The Bunnyhopper`
  - `Taunt: Rocket Jockey`
  - `Taunt: The Hot Wheeler`
  - `Taunt: The Road Rager`
- Added stricter controlled-movement loop handling for tank-style schema taunts so loop audio can switch between forward / reverse / idle states instead of staying on one flat loop.
- Added stricter Skating Scorcher scene-sound approximation using the exact local workshop/player sound script entries already present in the repository.
- Ported the core `tf_player.cpp` long-taunt runtime behavior into the schema path:
  - `taunt success sound` and `taunt success sound loop` are now treated as separate channels with their own offsets
  - loop sounds no longer start early when a taunt has a delayed loop offset
  - input-remap taunts now keep their remap scene active instead of auto-resetting to the main loop on a timer
  - released remap scenes are now supported for taunts that define them, including forward-hold taunts like `Taunt: The Boxtrot`
  - remap processing now follows Valve's "pressed first, then held, then released-from-current-pressed-scene" flow more closely

## Current State

### Gameplay

- Schema-backed taunts are the closest to Valve parity because they consume item schema data directly.
- Several older manual taunts still exist beside the schema path.
- Legacy/manual taunts now stop more like TF2, but their animation/sound/event wiring is still mixed between:
  - hardcoded commands in `shd_taunts.lua`
  - schema-driven execution in `shd_taunts.lua`
  - generic weapon taunts in `ply_extension.lua`
- Partner taunts now share the same cancel path as schema taunts, but some per-item partner positioning and scene/audio polish may still differ from TF2.
- A subset of workshop taunts now has explicit sound-script fallbacks where TF2 relies on scene-authored audio events that Garry's Mod is not reproducing automatically here.
- Controlled movement taunts with richer scene-event-driven sound timing still need more item-by-item parity work, especially for taunts whose sounds are tied to tricks, landings, or prop animation milestones.
- Vehicle-style taunts are closer now, but some movement-dependent transitions may still differ from TF2 because Source scene event timing is being approximated with schema/runtime hooks instead of native VCD event playback.
- The schema runtime now matches `tf_player.cpp` much more closely for intro sound timing, delayed loop start, and input-remap scene transitions, but exact scene-event-authored sound timing still depends on data Garry's Mod is not playing natively from TF2 VCD scene events.
- The repo currently exposes item schema and sound scripts for these taunts, but the actual extracted workshop VCD scene event data does not appear to be locally available for the newer taunts audited in this pass. Where that data is missing, the addon is using the closest technically feasible timing based on schema control flow and local sound script names.

### Taunt HUD

- The addon already has an 8-slot taunt selector in `gamemodes/tf/gamemode/vgui/hud_menutaunt.lua`.
- Current HUD behavior is closer to TF2 after this pass, but it is still visually simplified compared with Valve's `CHudMenuTauntSelection`.
- Remaining parity gaps:
  - item model/icon panel presentation is simplified to text cells instead of TF2-style item panels
  - Steam Controller / controller navigation parity is not implemented
  - hide/show priority behavior is approximated, not exact

### Backpack / Loadout

- The standalone backpack in `gamemodes/tf/gamemode/vgui/menu_charinfoloadoutsubpanel.lua` already uses:
  - 8 taunt slots
  - forced-slot filtering for taunt equips
  - `resource/ui/econ/backpackpanel.res` metrics
  - synced Steam inventory cache
- Remaining parity gaps:
  - taunt loadout UX is split between a dedicated taunt panel and the standalone backpack instead of mirroring TF2 exactly
  - backpack taunt presentation is functional, but not yet a full clone of TF2 econ item panels and taunt-specific affordances
  - loadout persistence still relies heavily on client convars and sync glue instead of a more TF2-like inventory/loadout authority path

## Highest-Priority Remaining Work

1. Replace remaining hardcoded manual looping taunts with schema-driven execution wherever Valve item schema data exists.
2. Upgrade `hud_menutaunt.lua` from text cards to TF2-style item model/icon panels with no-item state parity.
3. Audit backpack taunt equip flow against TF2 taunt loadout expectations:
   - slot-to-slot equip behavior
   - empty-slot handling
   - inspect/equip affordances
   - quality/border/item-name parity
4. Audit partner taunts and waiting states against Valve:
   - stop conditions
   - nearby partner detection
   - cancellation timing
   - sound loop start/stop behavior
5. Unify all taunt entry points so the same stop/start rules apply whether launched from:
   - `+taunt`
   - `weapon_taunt`
   - taunt HUD
   - backpack loadout
   - direct item command

## Notes

- "100% parity" is achievable only as an iterative project here, not a single safe edit, because taunts span gameplay, HUD, inventory, econ data, partner interactions, props, sounds, and movement code.
- When behavior differs, prefer the Valve references above over current addon behavior unless Garry's Mod engine limits make an exact port impossible.
