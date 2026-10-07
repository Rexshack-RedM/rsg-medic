# rsg-medic

Death system and doctor job for the RSG Framework (RedM), with a custom NUI in the RDR2 leather & gold theme.

## Features

**Death**
- Downed players see a death screen with a bleed-out timer, the number of doctors on duty and the respawn fee
- `[G]` call for a doctor (cooldown, sends a map blip to on-duty doctors)
- `[E]` wake up at the nearest doctor once the timer runs out (fee taken from cash, then bank)
- Death state is saved in player metadata, so logging out while downed doesn't revive you

**Doctor job**
- Hold `[E]` at a doctor's office: clock in/out, buy supplies, shared medicine cabinet (stash), management (boss grades)
- `/medic` field menu: lists nearby patients with health bars and unconscious status, revive or treat with one click
- Revive needs a medical bag; treating uses a bandage; both pay the doctor a configurable fee

**Auto medic (NPC doctor)**
- Downed players can type `/automedic`; an NPC doctor rides in on horseback, dismounts, treats and revives them where they lie, then rides off and despawns
- Only available when few/no doctors are on duty (`Config.AutoMedic.MaxMedicsOnDuty`), with a fee and cooldown
- Revive is done server-side and validated (must be downed, active call, minimum treatment time)
- Optional Discord webhook logging — set URLs in `server/sv_config.lua` (server-only, never sent to clients)
- Export: `exports['rsg-medic']:SendAutomedicLog(event, source, fields, description)`

**Everyone**
- Useable `bandage` item heals a set amount
- Admin `/revive [id]`

**Security**
- All revives, heals, respawns, purchases and stash access are checked on the server (job, duty, distance, items, money, inventory space)
- Revive/treat use a server-timed session, so skipping the progress bar doesn't work
- Respawn timer is tracked server-side

## Dependencies

- [rsg-core](https://github.com/Rexshack-RedM/rsg-core)
- [rsg-inventory](https://github.com/Rexshack-RedM/rsg-inventory)
- [ox_lib](https://github.com/overextended/ox_lib)
- Optional: `rsg-bossmenu` for the management button

## Installation

1. Put `rsg-medic` in your resources folder. The auto medic is built in, so remove `rex-automedic` if you have it. If you use another death/medic script, remove it — only one should handle death.
2. Add the items from `installation/shared_items.lua` to `rsg-core/shared/items.lua` (skip any that exist), and add `bandage.png` / `medicalbag.png` to `rsg-inventory/html/images/`.
3. Make sure a `medic` job exists in `rsg-core/shared/jobs.lua` (or change `Config.MedicJobs`).
4. Add `ensure rsg-medic` to `server.cfg` after `rsg-core`, `rsg-inventory` and `ox_lib`.
5. Check the coordinates in `Config.Locations` on your map and adjust as needed.

## Configuration

Everything is in `shared/config.lua`:

| Option | What it does |
|--------|--------------|
| `MedicJobs`, `RequireDuty` | Which jobs count as doctors and whether they must be on duty |
| `DeathTimer`, `RespawnFee` | Bleed-out time (seconds) and hospital fee |
| `AlertCooldown`, `AlertBlipTime` | Call-for-doctor cooldown and how long the blip lasts |
| `Keys` | Respawn, alert and office prompt keys |
| `ActionDistance`, `FieldRange`, `FieldCommand` | Revive/treat range, field menu range and command |
| `Revive`, `Treat`, `Bandage` | Durations, items and rewards |
| `Supplies`, `MaxBuyAmount` | Items doctors can buy and the max per purchase |
| `Stash`, `BossMenuEvent` | Medicine cabinet size and the boss menu client event |
| `AutoMedic` | NPC doctor: command, fee, cooldown, medic limit, models, distances, timings, blip |
| `Locations` | Office prompt point and respawn position per doctor |

## Events for other scripts

- Server → client `rsg-medic:client:revive` (optional `vec4` spawn) — revive a player. Also clear `isdead` metadata on the server.
- Server → client `rsg-medic:client:heal` (amount, `-1` = full)

## Locales

All text, including the NUI, is in `locales/en.json` (UI strings use the `ui_` prefix). To add a language, copy it to `locales/<code>.json`, translate the values, and set `setr ox:locale <code>`.

Auto medic strings use the `am_` prefix and ship in de, el, es, fr, ja, nl, pl, pt-br and ro; other text in those languages falls back to English.
