local RSGCore = exports['rsg-core']:GetCoreObject()
lib.locale()
--------------------
-- send To Discord
-------------------

local function sendToDiscord(color, name, message, footer, type)
    local embed = {
        {   ['color'] = color,
            ['title'] = '**'.. name ..'**',
            ['description'] = message,
            ['footer'] = {
                ['text'] = footer
            }
        }
    }
    if type == 'death' then
        PerformHttpRequest(Config['Webhooks']['death'], function(err, text, headers) end, 'POST', json.encode({username = name, embeds = embed}), { ['Content-Type'] = 'application/json' })
    elseif type == 'deathic' then
        PerformHttpRequest(Config['Webhooks']['death'], function(err, text, headers) end, 'POST', json.encode({username = name, embeds = embed}), { ['Content-Type'] = 'application/json' })
    end
end

RegisterNetEvent('rsg-medic:server:sendToDiscord', function(msgDiscordA, msgDiscordB)
    local src = source
    sendToDiscord(16753920,	locale('discord_priv'), msgDiscordA ..'\n'.. msgDiscordB, locale('discord_end'), 'death')
    sendToDiscord(16753920,	locale('discord_public'), msgDiscordB, locale('discord_end_p'), 'deathic')
end)

-----------------------
-- use bandage
-----------------------
RSGCore.Functions.CreateUseableItem('bandage', function(source, item)
    local src = source
    TriggerClientEvent('rsg-medic:client:usebandage', src, item.name)
end)

---------------------------------
-- medic storage
---------------------------------
RegisterNetEvent('rsg-medic:server:openstash', function(location)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end
    local data = { label = locale('sv_medical_storage'), maxweight = Config.StorageMaxWeight, slots = Config.StorageMaxSlots }
    local stashName = 'medic_' .. location
    exports['rsg-inventory']:OpenInventory(src, stashName, data)
end)

----------------------------------
-- Admin Revive Player
----------------------------------
RSGCore.Commands.Add('revive', locale('sv_revive'), {{name = 'id', help = locale('sv_revive_2')}}, false, function(source, args)
    local src = source

    if not args[1] then
        TriggerClientEvent('rsg-medic:client:playerRevive', src)
        return
    end

    local Player = RSGCore.Functions.GetPlayer(tonumber(args[1]))
    if not Player then
        TriggerClientEvent('ox_lib:notify', src, {title = locale('sv_no_online'), type = 'error', duration = 7000 })
        return
    end

    TriggerClientEvent('rsg-medic:client:adminRevive', Player.PlayerData.source)
end, 'admin')

-- Admin Kill Player
RSGCore.Commands.Add('kill', locale('sv_kill'), {{name = 'id', help = locale('sv_kill_id')}}, true, function(source, args)
    local src = source
    local target = tonumber(args[1])

    local Player = RSGCore.Functions.GetPlayer(target)
    if not Player then
        TriggerClientEvent('ox_lib:notify', src, {title = locale('sv_no_online'), type = 'error', duration = 7000 })
        return
    end

    TriggerClientEvent('rsg-medic:client:KillPlayer', Player.PlayerData.source)
end, 'admin')

----------------------
-- EVENTS 
-----------------------
-- Death Actions: Remove Inventory / Cash
RegisterNetEvent('rsg-medic:server:deathactions', function()
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)

    if Config.WipeInventoryOnRespawn then
        Player.Functions.ClearInventory()
        MySQL.Async.execute('UPDATE players SET inventory = ? WHERE citizenid = ?', { json.encode({}), Player.PlayerData.citizenid })
        TriggerClientEvent('ox_lib:notify', src, {title = locale('sv_lost_all'), type = 'info', duration = 7000 })
    end

    if Config.WipeCashOnRespawn then
        Player.Functions.SetMoney('cash', 0)
        TriggerClientEvent('ox_lib:notify', src, {title = locale('sv_lost_cash'), type = 'info', duration = 7000 })
    end
    if Config.WipeBloodmoneyOnRespawn then
        Player.Functions.SetMoney('bloodmoney', 0)
        TriggerClientEvent('ox_lib:notify', src, {title = locale('sv_lost_bloodmoney'), type = 'info', duration = 7000 })
    end
    if Config.WipeExperienceOnRespawn then
        Player.Functions.SetMoney('experience', 0)
        TriggerClientEvent('ox_lib:notify', src, {title = locale('sv_lost_exp'), type = 'info', duration = 7000 })
    end
    if Config.WipeGoldcoinOnRespawn then
        Player.Functions.SetMoney('goldcoin', 0)
        TriggerClientEvent('ox_lib:notify', src, {title = locale('sv_lost_goldcoin'), type = 'info', duration = 7000 })
    end
end)

-- Get Players Health
RSGCore.Functions.CreateCallback('rsg-medic:server:getplayerhealth', function(source, cb)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    local health = Player.PlayerData.metadata['health']
    cb(health)
end)

-- Set Player Health
RegisterNetEvent('rsg-medic:server:SetHealth', function(amount)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)

    if not Player then return end

    amount = tonumber(amount)

    if amount > Config.MaxHealth then
        amount = Config.MaxHealth
    end

    Player.Functions.SetMetaData('health', amount)
end)

-- Medic Revive Player
RegisterNetEvent('rsg-medic:server:RevivePlayer', function(playerId)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    local Patient = RSGCore.Functions.GetPlayer(playerId)

    if not Patient then return end

    if Player.PlayerData.job.name ~= Config.JobRequired then
        TriggerClientEvent('ox_lib:notify', src, {title = locale('sv_not_medic'), type = 'error', duration = 7000 })
        return
    end

    if Player.Functions.RemoveItem('firstaid', 1) then
        TriggerClientEvent('rsg-inventory:client:ItemBox', src, RSGCore.Shared.Items['firstaid'], 'remove')
        TriggerClientEvent('rsg-medic:client:playerRevive', Patient.PlayerData.source)
    end
end)

-- Medic Treat Wounds
RegisterNetEvent('rsg-medic:server:TreatWounds', function(playerId)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    local Patient = RSGCore.Functions.GetPlayer(playerId)

    if not Patient then return end

    if Player.PlayerData.job.name ~= Config.JobRequired then
        TriggerClientEvent('ox_lib:notify', src, {title = locale('sv_not_medic'), type = 'error', duration = 7000 })
        return
    end

    if Player.Functions.RemoveItem('bandage', 1) then
        TriggerClientEvent('rsg-inventory:client:ItemBox', src, RSGCore.Shared.Items['bandage'], 'remove')
        TriggerClientEvent('rsg-medic:client:HealInjuries', Patient.PlayerData.source, 'full')
    end
end)

-- Medic Alert
RegisterNetEvent('rsg-medic:server:medicAlert', function(text)
    local src = source
    local ped = GetPlayerPed(src)
    local coords = GetEntityCoords(ped)
    local players = RSGCore.Functions.GetRSGPlayers()

    for _, v in pairs(players) do
        if v.PlayerData.job.name == 'medic' and v.PlayerData.job.onduty then
            TriggerClientEvent('rsg-medic:client:medicAlert', v.PlayerData.source, coords, text)
        end
    end
end)

--------------------------
-- Medics On-Duty Callback
-------------------------
RSGCore.Functions.CreateCallback('rsg-medic:server:getmedics', function(source, cb)
    local amount = 0
    local players = RSGCore.Functions.GetRSGPlayers()
    for k, v in pairs(players) do
        if v.PlayerData.job.name == Config.JobRequired and v.PlayerData.job.onduty then
            amount = amount + 1
        end
    end
    cb(amount)
end)

---------------------------------
-- remove item
---------------------------------
RegisterServerEvent('rsg-medic:server:removeitem', function(item, amount)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end
    Player.Functions.RemoveItem(item, amount)
    TriggerClientEvent('rsg-inventory:client:ItemBox', src, RSGCore.Shared.Items[item], 'remove', amount)
end)