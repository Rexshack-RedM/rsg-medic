local RSGCore = exports['rsg-core']:GetCoreObject()
lib.locale()

local deathTimes   = {} -- [src] = os.time() when the player went down
local alertTimes   = {} -- [src] = os.time() of last medic alert
local pending      = {} -- [medicSrc] = { target, kind, start, duration }  in-progress revive/treat
local actionCD     = {} -- [src] = GetGameTimer() of last bandage use

local isMedicJob = {}
for _, name in ipairs(Config.MedicJobs) do isMedicJob[name] = true end

---------------------------------
-- helpers
---------------------------------
local function Notify(src, key, nType, ...)
    TriggerClientEvent('ox_lib:notify', src, {
        title = locale('title'), description = locale(key, ...), type = nType, duration = 5000,
    })
end

local function IsMedic(Player, needDuty)
    local job = Player and Player.PlayerData.job
    if not job or not isMedicJob[job.name] then return false end
    if needDuty and Config.RequireDuty and not job.onduty then return false end
    return true
end

local function IsDead(Player)
    return Player and Player.PlayerData.metadata.isdead == true
end

local function PedCoords(src)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return nil end
    return GetEntityCoords(ped)
end

local function Distance(a, b)
    local ca, cb = PedCoords(a), PedCoords(b)
    if not ca or not cb then return math.huge end
    return #(ca - cb)
end

local function CharName(Player)
    local c = Player.PlayerData.charinfo
    return ('%s %s'):format(c.firstname, c.lastname)
end

local function ItemLabel(item)
    local d = RSGCore.Shared.Items[item]
    return d and d.label or item
end

local function HasItem(src, item)
    if not item then return true end
    return exports['rsg-inventory']:HasItem(src, item, 1)
end

local function GetOnDutyMedics()
    local list = {}
    for src, Player in pairs(RSGCore.Functions.GetRSGPlayers()) do
        if IsMedic(Player, true) then list[#list + 1] = src end
    end
    return list
end

local function NearestLocation(src)
    local coords = PedCoords(src)
    local best, bestDist = Config.Locations[1], math.huge
    if coords then
        for _, loc in ipairs(Config.Locations) do
            local d = #(coords - loc.point)
            if d < bestDist then best, bestDist = loc, d end
        end
    end
    return best
end

local function GetLocation(id)
    for _, loc in ipairs(Config.Locations) do
        if loc.id == id then return loc end
    end
end

local function NearLocation(src, loc)
    local c = PedCoords(src)
    return c and loc and #(c - loc.point) <= 5.0
end

local function SetAlive(src, Player)
    Player.Functions.SetMetaData('isdead', false)
    deathTimes[src] = nil
end

local function Pay(src, Player, amount)
    if amount and amount > 0 then
        Player.Functions.AddMoney('cash', amount, 'rsg-medic-reward')
        Notify(src, 'reward', 'success', amount)
    end
end

---------------------------------
-- death state
---------------------------------
RegisterNetEvent('rsg-medic:server:setDead', function()
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player or IsDead(Player) then return end
    Player.Functions.SetMetaData('isdead', true)
    deathTimes[src] = os.time()
end)

lib.callback.register('rsg-medic:server:getDeathInfo', function(src)
    local Player = RSGCore.Functions.GetPlayer(src)
    if IsDead(Player) and not deathTimes[src] then deathTimes[src] = os.time() end -- reconnect / restart
    local remaining = 0
    if deathTimes[src] then
        remaining = math.max(0, Config.DeathTimer - (os.time() - deathTimes[src]))
    end
    return { remaining = remaining, medics = #GetOnDutyMedics() }
end)

RegisterNetEvent('rsg-medic:server:respawn', function()
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if not IsDead(Player) then return end

    local downedAt = deathTimes[src]
    if not downedAt or os.time() - downedAt < Config.DeathTimer then return end

    local fee = Config.RespawnFee
    if fee > 0 then
        if Player.Functions.GetMoney('cash') >= fee then
            Player.Functions.RemoveMoney('cash', fee, 'rsg-medic-respawn')
        elseif Player.Functions.GetMoney('bank') >= fee then
            Player.Functions.RemoveMoney('bank', fee, 'rsg-medic-respawn')
        else
            fee = 0
        end
    end

    SetAlive(src, Player)
    local loc = NearestLocation(src)
    TriggerClientEvent('rsg-medic:client:revive', src, loc.spawn)
    Notify(src, 'respawned', 'inform')
    if fee > 0 then Notify(src, 'respawn_fee', 'inform', fee) end
end)

RegisterNetEvent('rsg-medic:server:alert', function()
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if not IsDead(Player) then return end

    local now = os.time()
    if alertTimes[src] and now - alertTimes[src] < Config.AlertCooldown then
        return Notify(src, 'alert_cooldown', 'error', Config.AlertCooldown - (now - alertTimes[src]))
    end

    local medics = GetOnDutyMedics()
    if #medics == 0 then return Notify(src, 'no_medics', 'error') end

    local coords = PedCoords(src)
    if not coords then return end
    alertTimes[src] = now

    for _, medic in ipairs(medics) do
        TriggerClientEvent('rsg-medic:client:alert', medic, coords)
    end
    Notify(src, 'alert_sent', 'success')
    TriggerClientEvent('rsg-medic:client:alertSent', src, Config.AlertCooldown)
end)

---------------------------------
-- doctor's office
---------------------------------
lib.callback.register('rsg-medic:server:getMenu', function(src, locId)
    local Player = RSGCore.Functions.GetPlayer(src)
    local loc = GetLocation(locId)
    if not IsMedic(Player) or not NearLocation(src, loc) then return nil end

    local items = {}
    for _, s in ipairs(Config.Supplies) do
        items[#items + 1] = { item = s.item, label = ItemLabel(s.item), price = s.price }
    end

    local job = Player.PlayerData.job
    return {
        location = loc.label,
        onduty   = job.onduty,
        isBoss   = job.isboss == true and Config.BossMenuEvent ~= nil,
        items    = items,
    }
end)

RegisterNetEvent('rsg-medic:server:toggleDuty', function()
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if not IsMedic(Player) or not NearLocation(src, NearestLocation(src)) then return end
    local onduty = not Player.PlayerData.job.onduty
    Player.Functions.SetJobDuty(onduty)
    TriggerClientEvent('RSGCore:Client:SetDuty', src, onduty)
    Notify(src, onduty and 'on_duty' or 'off_duty', 'inform')
end)

RegisterNetEvent('rsg-medic:server:buy', function(item, amount)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if not IsMedic(Player, true) then return Notify(src, 'not_on_duty', 'error') end
    if not NearLocation(src, NearestLocation(src)) then return end

    amount = math.floor(tonumber(amount) or 0)
    if amount < 1 or amount > Config.MaxBuyAmount then return Notify(src, 'invalid_amount', 'error') end

    local price
    for _, s in ipairs(Config.Supplies) do
        if s.item == item then price = s.price break end
    end
    if not price or not RSGCore.Shared.Items[item] then return end

    local total = price * amount
    if Player.Functions.GetMoney('cash') < total then return Notify(src, 'no_money', 'error') end
    if not exports['rsg-inventory']:CanAddItem(src, item, amount) then return Notify(src, 'inventory_full', 'error') end

    if Player.Functions.RemoveMoney('cash', total, 'rsg-medic-supplies') then
        exports['rsg-inventory']:AddItem(src, item, amount, nil, nil, 'rsg-medic-supplies')
        TriggerClientEvent('rsg-inventory:client:ItemBox', src, RSGCore.Shared.Items[item], 'add', amount)
        Notify(src, 'bought', 'success', amount, ItemLabel(item), total)
    end
end)

RegisterNetEvent('rsg-medic:server:openStash', function()
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if not IsMedic(Player, true) then return Notify(src, 'not_on_duty', 'error') end
    local loc = NearestLocation(src)
    if not NearLocation(src, loc) then return end
    exports['rsg-inventory']:OpenInventory(src, 'medic_' .. loc.id, {
        label = loc.label, maxweight = Config.Stash.maxweight, slots = Config.Stash.slots,
    })
end)

---------------------------------
-- field medicine
---------------------------------
lib.callback.register('rsg-medic:server:getPatients', function(src)
    local Medic = RSGCore.Functions.GetPlayer(src)
    if not IsMedic(Medic, true) then return nil end

    local list = {}
    for id, Player in pairs(RSGCore.Functions.GetRSGPlayers()) do
        if id ~= src then
            local d = Distance(src, id)
            if d <= Config.FieldRange then
                list[#list + 1] = { id = id, name = CharName(Player), dead = IsDead(Player), dist = d }
            end
        end
    end
    table.sort(list, function(a, b) return a.dist < b.dist end)
    return list
end)

-- step 1: validate and open a timed action
lib.callback.register('rsg-medic:server:beginAction', function(src, kind, target)
    local Medic = RSGCore.Functions.GetPlayer(src)
    if kind ~= 'revive' and kind ~= 'treat' then return false end
    if not IsMedic(Medic, true) then Notify(src, 'not_on_duty', 'error') return false end
    if pending[src] then Notify(src, 'busy', 'error') return false end

    target = tonumber(target)
    local Patient = target and RSGCore.Functions.GetPlayer(target)
    if not Patient or target == src then Notify(src, 'no_patient', 'error') return false end
    if Distance(src, target) > Config.ActionDistance then Notify(src, 'patient_too_far', 'error') return false end

    local cfg = kind == 'revive' and Config.Revive or Config.Treat
    if kind == 'revive' and not IsDead(Patient) then Notify(src, 'patient_not_dead', 'error') return false end
    if kind == 'treat' and IsDead(Patient) then Notify(src, 'patient_dead', 'error') return false end
    if not HasItem(src, cfg.item) then Notify(src, 'need_item', 'error', ItemLabel(cfg.item)) return false end

    pending[src] = { target = target, kind = kind, start = GetGameTimer(), duration = cfg.duration }
    return cfg.duration
end)

RegisterNetEvent('rsg-medic:server:cancelAction', function()
    pending[source] = nil
end)

-- step 2: progress bar finished, re-validate and apply
RegisterNetEvent('rsg-medic:server:finishAction', function()
    local src = source
    local p = pending[src]
    pending[src] = nil
    if not p then return end
    if GetGameTimer() - p.start < p.duration - 500 then return end

    local Medic   = RSGCore.Functions.GetPlayer(src)
    local Patient = RSGCore.Functions.GetPlayer(p.target)
    if not IsMedic(Medic, true) or not Patient then return end
    if Distance(src, p.target) > Config.ActionDistance + 1.0 then return Notify(src, 'patient_too_far', 'error') end

    if p.kind == 'revive' then
        if not IsDead(Patient) then return end
        if not HasItem(src, Config.Revive.item) then return Notify(src, 'need_item', 'error', ItemLabel(Config.Revive.item)) end
        SetAlive(p.target, Patient)
        TriggerClientEvent('rsg-medic:client:revive', p.target)
        Notify(p.target, 'you_were_revived', 'success')
        Notify(src, 'revived_patient', 'success', CharName(Patient))
        Pay(src, Medic, Config.Revive.reward)
    else
        if IsDead(Patient) then return end
        local item = Config.Treat.item
        if item then
            if not exports['rsg-inventory']:RemoveItem(src, item, 1, nil, 'rsg-medic-treat') then
                return Notify(src, 'need_item', 'error', ItemLabel(item))
            end
            TriggerClientEvent('rsg-inventory:client:ItemBox', src, RSGCore.Shared.Items[item], 'remove', 1)
        end
        TriggerClientEvent('rsg-medic:client:heal', p.target, -1) -- -1 = full health
        Notify(p.target, 'you_were_treated', 'success')
        Notify(src, 'treated_patient', 'success', CharName(Patient))
        Pay(src, Medic, Config.Treat.reward)
    end
end)

---------------------------------
-- bandage (anyone)
---------------------------------
RSGCore.Functions.CreateUseableItem(Config.Bandage.item, function(source)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player or IsDead(Player) then return end
    TriggerClientEvent('rsg-medic:client:useBandage', src)
end)

RegisterNetEvent('rsg-medic:server:bandageDone', function()
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player or IsDead(Player) then return end

    local now = GetGameTimer()
    if actionCD[src] and now - actionCD[src] < Config.Bandage.duration then return end
    actionCD[src] = now

    if not exports['rsg-inventory']:RemoveItem(src, Config.Bandage.item, 1, nil, 'rsg-medic-bandage') then return end
    TriggerClientEvent('rsg-inventory:client:ItemBox', src, RSGCore.Shared.Items[Config.Bandage.item], 'remove', 1)
    TriggerClientEvent('rsg-medic:client:heal', src, Config.Bandage.heal)
    Notify(src, 'bandaged', 'success')
end)

-- server-only revive in place (used by the auto medic; not callable by clients)
AddEventHandler('rsg-medic:server:reviveInPlace', function(src)
    local Player = RSGCore.Functions.GetPlayer(src)
    if not IsDead(Player) then return end
    SetAlive(src, Player)
    TriggerClientEvent('rsg-medic:client:revive', src)
end)

---------------------------------
-- admin
---------------------------------
RSGCore.Commands.Add('revive', locale('cmd_revive_help'), { { name = 'id', help = locale('cmd_revive_arg') } }, false, function(source, args)
    local target = tonumber(args[1]) or source
    local Player = RSGCore.Functions.GetPlayer(target)
    if not Player then return Notify(source, 'player_not_found', 'error') end
    SetAlive(target, Player)
    TriggerClientEvent('rsg-medic:client:revive', target)
    if source > 0 then Notify(source, 'admin_revived', 'success', target) end
end, 'admin')

---------------------------------
-- cleanup
---------------------------------
AddEventHandler('playerDropped', function()
    local src = source
    deathTimes[src], alertTimes[src], pending[src], actionCD[src] = nil, nil, nil, nil
end)
