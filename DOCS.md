# rsg-medic — Developer & Server Owner Docs

Version 3.1.0 · Dependencies: rsg-core, rsg-inventory (optional rsg-bossmenu)

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

## rsg-reputation integration

`Config.Reputation = { Enabled, Action }`. After a server-validated revive in the finish handler (patient dead, item used, distance checked), the server calls `ApplyAction(src, 'revive')` for the medic. No region is passed, so only honor changes. Skipped when rsg-reputation is not started.


Support the Project : https://rexshack.tebex.store/

<!-- BEGIN AUTO-REFERENCE (generated from the code; re-run the generator instead of editing by hand) -->

## Technical reference

Generated from the source of **rsg-medic 3.1.0**. Names, arguments and defaults below are read straight from the code.

### Dependencies

`rsg-core`, `rsg-inventory`

### Configuration

| Option | Default | Notes |
|---|---|---|
| `Config.MedicJobs` | `{ 'medic' }` | job names treated as medics |
| `Config.RequireDuty` | `true` | medics must be on duty to use field actions / supplies |
| `Config.DeathTimer` | `300` | seconds before a downed player may respawn at the doctor |
| `Config.RespawnFee` | `25` | charged on hospital respawn (cash, then bank); 0 = free |
| `Config.AlertCooldown` | `60` | seconds between "call for a medic" alerts |
| `Config.AlertBlipTime` | `120` | seconds an alert blip stays on medics' maps |
| `Config.DeathCam` | `table` | keys (RedM control hashes) |
| `Config.Enabled` | `true` |  |
| `Config.Distance` | `3.5` |  |
| `Config.MinDistance` | `1.5` |  |
| `Config.MaxDistance` | `8.0` |  |
| `Config.Sensitivity` | `6.0` |  |
| `Config.Keys` | `table` |  |
| `Config.ActionDistance` | `3.0` | metres between medic and patient |
| `Config.FieldRange` | `10.0` | metres to list nearby patients in the field menu |
| `Config.UiCommand` | `'medicui'` | toggles UI move mode (drag panels by their header, double-click to reset) |
| `Config.FieldCommand` | `'medic'` | opens the field menu for on-duty medics |
| `Config.Revive` | `table` |  |
| `Config.Treat` | `table` |  |
| `Config.Bandage` | `table` | self-use bandage item for anyone |
| `Config.Supplies` | `table` |  |
| `Config.MaxBuyAmount` | `50` |  |
| `Config.Stash` | `{ slots = 50, maxweight = 400000 }` |  |
| `Config.BossMenuEvent` | `'rsg-bossmenu:client:mainmenu'` | client event opened for boss grades; nil to hide |
| `Config.BlipSprite` | ``blip_shop_doctor`` |  |
| `Config.AlertBlipSprite` | ``blip_ambient_companion`` |  |
| `Config.Locations` | `table` |  |
| `Config.AutoMedic` | `table` |  |
| `Config.Debug` | `false` |  |
| `Config.Command` | `'automedic'` |  |
| `Config.Cost` | `50` |  |
| `Config.MoneyType` | `'cash'` |  |
| `Config.Cooldown` | `300` |  |
| `Config.MaxMedicsOnDuty` | `0` |  |
| `Config.DoctorModel` | `'u_m_m_rhddoctor_01'` |  |
| `Config.HorseModel` | `'a_c_horse_kentuckysaddle_black'` |  |
| `Config.SpawnDistance` | `80.0` |  |
| `Config.DismountDistance` | `8.0` |  |
| `Config.ReviveDistance` | `1.5` |  |
| `Config.DespawnDistance` | `120.0` |  |
| `Config.RideSpeed` | `3.0` |  |
| `Config.ReviveTime` | `8000` |  |
| `Config.ArrivalTimeout` | `90` |  |
| `Config.LeaveTimeout` | `45` |  |
| `Config.ShowBlip` | `true` |  |
| `Config.Reputation` | `table` | rsg-reputation integration (optional). Needs the rsg-reputation resource; does nothing when it is not started. |
| `Config.Action` | `'revive'` |  |

### Exports

**Server**

| Export | Arguments | File |
|---|---|---|
| `SendAutomedicLog` | `` | `server/automedic_webhooks.lua` |

```lua
-- example
local result = exports['rsg-medic']:SendAutomedicLog()
```

### Callbacks

| Callback | Side | Arguments | File |
|---|---|---|---|
| `rsg-medic:server:getDeathInfo` | server | `src, cb` | `server/server.lua` |
| `rsg-medic:server:getMenu` | server | `src, cb, locId` | `server/server.lua` |
| `rsg-medic:server:getPatients` | server | `src, cb` | `server/server.lua` |
| `rsg-medic:server:beginAction` | server | `src, cb, kind, target` | `server/server.lua` |

```lua
-- client side
RSGCore.Functions.TriggerCallback('rsg-medic:server:getDeathInfo', function(result)
    -- use result
end)
```

### Events

Server events can be fired by any client, so every handler re-validates the player, the arguments and any permission, distance or cooldown on the server. Never add a reward to a handler without those checks.

| Event | Side | Arguments | File |
|---|---|---|---|
| `rsg-medic:automedic:client:callDoctor` | client | `` | `client/automedic.lua` |
| `rsg-medic:client:alertSent` | client | `cooldown` | `client/client.lua` |
| `rsg-medic:client:revive` | client | `spawn` | `client/client.lua` |
| `rsg-medic:client:heal` | client | `amount` | `client/client.lua` |
| `RSGCore:Client:OnPlayerLoaded` | client | `` | `client/client.lua` |
| `RSGCore:Client:OnJobUpdate` | client | `job` | `client/client.lua` |
| `RSGCore:Client:SetDuty` | client | `duty` | `client/client.lua` |
| `RSGCore:Client:OnPlayerUnload` | client | `` | `client/client.lua` |
| `rsg-medic:client:alert` | client | `coords` | `client/client.lua` |
| `rsg-medic:client:useBandage` | client | `` | `client/client.lua` |
| `rsg-medic:automedic:server:treated` | server | `` | `server/automedic.lua` |
| `rsg-medic:automedic:server:stage` | server | `stage` | `server/automedic.lua` |
| `rsg-medic:automedic:server:finished` | server | `` | `server/automedic.lua` |
| `rsg-medic:server:setDead` | server | `` | `server/server.lua` |
| `rsg-medic:server:respawn` | server | `` | `server/server.lua` |
| `rsg-medic:server:alert` | server | `` | `server/server.lua` |
| `rsg-medic:server:toggleDuty` | server | `` | `server/server.lua` |
| `rsg-medic:server:buy` | server | `item, amount` | `server/server.lua` |
| `rsg-medic:server:openStash` | server | `` | `server/server.lua` |
| `rsg-medic:server:cancelAction` | server | `` | `server/server.lua` |
| `rsg-medic:server:finishAction` | server | `` | `server/server.lua` |
| `rsg-medic:server:bandageCancel` | server | `` | `server/server.lua` |
| `rsg-medic:server:bandageDone` | server | `` | `server/server.lua` |

```lua
-- from a client script
TriggerServerEvent('rsg-medic:automedic:server:treated')
-- from a server script
TriggerClientEvent('rsg-medic:automedic:client:callDoctor', source)
```

### Commands

| Command | Notes | File |
|---|---|---|
| `/revive` | locale('cmd_revive_help') | `server/server.lua` |

### Locales

Language files in `locales/`: `de`, `el`, `en`, `es`, `fr`, `ja`, `nl`, `pl`, `pt-br`, `ro`, `ru`. Set the language with `setr rsg:locale "en"`.

<!-- END AUTO-REFERENCE -->
