local RSGCore = exports['rsg-core']:GetCoreObject()

-- Admin Revive Player
RSGCore.Commands.Add("revive", Lang:t('server.lang_1'), {{name = "id", help = Lang:t('server.lang_2')}}, false, function(source, args)
    local src = source

    if not args[1] then
        TriggerClientEvent('rsg-medic:client:playerRevive', src)

        return
    end

    local Player = RSGCore.Functions.GetPlayer(tonumber(args[1]))

    if not Player then
        TriggerClientEvent('ox_lib:notify', src, {title = Lang:t('server.lang_3'), type = 'error', duration = 7000 })
        return
    end

    TriggerClientEvent('rsg-medic:client:adminRevive', Player.PlayerData.source)
end, "admin")

-- Admin Kill Player
RSGCore.Commands.Add("kill", Lang:t('server.lang_4'), {{name = "id", help = Lang:t('server.lang_5')}}, true, function(source, args)
    local src = source
    local target = tonumber(args[1])

    local Player = RSGCore.Functions.GetPlayer(target)

    if not Player then
        TriggerClientEvent('ox_lib:notify', src, {title = Lang:t('server.lang_6'), type = 'error', duration = 7000 })
        return
    end

    TriggerClientEvent('rsg-medic:client:KillPlayer', Player.PlayerData.source)
end, "admin")


-------------------------------------------------------- EVENTS --------------------------------------------------------


-- Death Actions: Remove Inventory / Cash
RegisterNetEvent('rsg-medic:server:deathactions', function()
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)

    if Config.WipeInventoryOnRespawn then
        Player.Functions.ClearInventory()
        MySQL.Async.execute('UPDATE players SET inventory = ? WHERE citizenid = ?', { json.encode({}), Player.PlayerData.citizenid })
        TriggerClientEvent('ox_lib:notify', src, {title = Lang:t('server.lang_7'), type = 'info', duration = 7000 })
    end

    if Config.WipeCashOnRespawn then
        Player.Functions.SetMoney('cash', 0)
        TriggerClientEvent('ox_lib:notify', src, {title = Lang:t('server.lang_8'), type = 'info', duration = 7000 })
    end
end)

-- Get Players Health
RSGCore.Functions.CreateCallback('rsg-medic:server:getplayerhealth', function(source, cb)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    local health = Player.PlayerData.metadata["health"]
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

    Player.Functions.SetMetaData("health", amount)
end)

-- Medic Revive Player
RegisterNetEvent('rsg-medic:server:RevivePlayer', function(playerId)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    local Patient = RSGCore.Functions.GetPlayer(playerId)

    if not Patient then return end

    if Player.PlayerData.job.name ~= Config.JobRequired then
        TriggerClientEvent('ox_lib:notify', src, {title = Lang:t('server.lang_9'), type = 'error', duration = 7000 })
        return
    end

    if Player.Functions.RemoveItem('firstaid', 1) then
        TriggerClientEvent('inventory:client:ItemBox', src, RSGCore.Shared.Items['firstaid'], "remove")
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
        TriggerClientEvent('ox_lib:notify', src, {title = Lang:t('server.lang_9'), type = 'error', duration = 7000 })
        return
    end

    if Player.Functions.RemoveItem('bandage', 1) then
        TriggerClientEvent('inventory:client:ItemBox', src, RSGCore.Shared.Items['bandage'], "remove")
        TriggerClientEvent('rsg-medic:client:HealInjuries', Patient.PlayerData.source, "full")
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


------------------------------------------------------ CALLBACKS -------------------------------------------------------


-- Medics On-Duty Callback
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
-- medic stash
---------------------------------
RegisterNetEvent('rsg-medic:server:openstash', function(location)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end
    local data = {
        maxweight = Config.StorageMaxWeight,
        slots = Config.StorageMaxSlots
    }
    local stashName = 'medic_' .. location
    exports['rsg-inventory']:OpenInventory(src, stashName, data)
end)
