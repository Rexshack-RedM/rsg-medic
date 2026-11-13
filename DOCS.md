# rsg-medic — Developer & Server Owner Docs

Version 3.0.4 · Dependencies: rsg-core, rsg-inventory (optional rsg-bossmenu)

## Contents
1. Files
2. Death flow
3. Medic actions
4. Auto medic
5. Events & callbacks
6. Exports
7. Items & data
8. Security model
9. How-tos
10. Troubleshooting

## 1. Files
| File | Purpose |
|---|---|
| `shared/config.lua` | All gameplay settings (jobs, timers, items, prices, locations, auto medic) |
| `server/sv_config.lua` | Discord webhook URLs (server only) |
| `server/server.lua` | Death state, respawn, alerts, office menu, duty, supplies, stash, revive/treat, bandage, `/revive`. Defines the `RSGMedic` server table used by `automedic.lua` |
| `server/automedic.lua` | `/automedic` command, payment, call tracking |
| `server/automedic_webhooks.lua` | Queued Discord logging, `SendAutomedicLog` |
| `server/versionchecker.lua` | GitHub version check |
| `client/client.lua` | Death detection, death screen + camera, office prompt, field menu, progress actions, NUI bridge |
| `client/automedic.lua` | NPC doctor spawn, ride, dismount, treat, ride away |
| `html/` | NUI (death screen, office, field menu, buy modal, movable panels) |

No database tables — death state is stored in player metadata `isdead`.

## 2. Death flow
1. Client sees the live ped dead for 500 ms → `rsg-medic:server:setDead`.
2. Server only accepts it if the ped's health is 0 server-side, then sets `isdead = true` and starts the timer.
3. Death screen syncs remaining time and medic count every 15 s (`rsg-medic:server:getDeathInfo`).
4. `[G]` sends an alert (cooldown `Config.AlertCooldown`) or, with no doctors on duty, runs `/automedic`.
5. After `Config.DeathTimer`, `[E]` → `rsg-medic:server:respawn`: fee from cash then bank (free if neither covers it), revived at the nearest `Config.Locations[].spawn`.
6. Logging in with `isdead` re-applies death.

## 3. Medic actions
- **Office** (hold `[E]` at `point`, medic jobs only): duty toggle, supplies (`Config.Supplies`, cash), stash `medic_<id>`, boss menu (`Config.BossMenuEvent`, boss grades).
- **Field menu** (`/medic`, on duty): patients within `Config.FieldRange`.
- **Revive / treat**: `beginAction` callback opens a server session → progress bar → `finishAction` re-checks timing, duty, distance and items. Revive uses one medical bag charge (`Config.Revive.uses`, stored in item info `uses`); treat consumes `Config.Treat.item` and heals to full. Both pay `reward` cash.
- **Bandage** (anyone): using the item starts a server timer; `bandageDone` only heals if `Config.Bandage.duration` has passed.

## 4. Auto medic
`/automedic` (while downed): checks active call (stale after ~arrival+leave+treat+90 s), cooldown per citizenid, on-duty medics vs `MaxMedicsOnDuty`, and funds. The client spawns the doctor; `rsg-medic:automedic:server:treated` revives in place (requires an active call and at least `ReviveTime`), then charges `Cost` in `MoneyType`.

## 5. Events & callbacks
| Name | Side | Notes |
|---|---|---|
| `rsg-medic:client:revive (spawn?)` | client | Revive; optional `vec4` respawn point. Also clear `isdead` on the server |
| `rsg-medic:client:heal (amount)` | client | `-1` = full heal |
| `rsg-medic:client:alert (coords)` | client | Alert blip for medics |
| `rsg-medic:server:reviveInPlace (src)` | server-only (`AddEventHandler`) | Revive a downed player where they are |
| `rsg-medic:server:setDead / respawn / alert / toggleDuty / buy / openStash / finishAction / cancelAction / bandageDone / bandageCancel` | net | All validated server-side |
| `rsg-medic:server:getDeathInfo / getMenu / getPatients / beginAction` | rsg-core callbacks | |

Example — revive from another resource (server):
```lua
TriggerEvent('rsg-medic:server:reviveInPlace', targetSrc)
```

## 6. Exports
`exports['rsg-medic']:SendAutomedicLog(event, source, fields?, description?)` (server) — `event` is a key of `SvConfig.Webhooks.Events`; `fields` is a list of `{ name, value, inline? }`.

## 7. Items & data
`bandage` (useable), `tool_medicalbag` (info `{ uses = n }`). Definitions in `installation/shared_items.lua`.

## 8. Security model
- Never trusts client amounts, prices, items or targets: prices come from `Config.Supplies`, targets are re-checked for distance/state.
- Job + duty checked on every medic event and callback; office actions require being within 5 m of a location.
- Revive/treat/bandage are server-timed; respawn timer is server-side.
- `setDead` requires a dead ped server-side.
- Webhook URLs never reach clients.
- Other scripts calling `rsg-medic:client:revive` must also set `isdead = false` on the server (or use `reviveInPlace`).

## 9. How-tos
- **Add a doctor's office:** append to `Config.Locations` with a unique `id`, `point` and `spawn`.
- **Change language:** `setr rsg:locale de` in server.cfg.
- **Disable the NPC doctor:** `Config.AutoMedic.Enabled = false`.
- **Free respawns:** `Config.RespawnFee = 0`.

## 10. Troubleshooting
| Problem | Fix |
|---|---|
| UI shows key names | Check `locales/*.json` is valid JSON and `rsg:locale` is set with `setr` |
| No office prompt | Your job must be in `Config.MedicJobs` and you must be within 2 m of `point` |
| Death screen never appears | Another death script is running; only one should handle death |
| Webhooks don't send | Replace `CHANGE_ME` URLs in `server/sv_config.lua` |
| `/automedic` says medics online | Raise `MaxMedicsOnDuty` or set `-1` |

Support the Project : https://rexshack.tebex.store/
