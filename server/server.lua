local RSGCore = exports['rsg-core']:GetCoreObject()


------------------------------------------------------- COMMANDS -------------------------------------------------------


-- Admin Revive Player
RSGCore.Commands.Add("revive", Lang:t('info.revive_player_a'), {{name = "id", help = Lang:t('info.player_id')}}, false, function(source, args)
    local src = source

    if not args[1] then
        TriggerClientEvent('rsg-medic:client:playerRevive', src)

        return
    end

    local Player = RSGCore.Functions.GetPlayer(tonumber(args[1]))

    if not Player then
        TriggerClientEvent('RSGCore:Notify', src, Lang:t('error.not_online'), 'error')

        return
    end

    TriggerClientEvent('rsg-medic:client:adminRevive', Player.PlayerData.source)
end, "admin")

-- Admin Kill Player
RSGCore.Commands.Add("kill", Lang:t('info.kill_player'), {{name = "id", help = Lang:t('info.player_id')}}, true, function(source, args)
    local src = source
    local target = tonumber(args[1])

    local Player = RSGCore.Functions.GetPlayer(target)

    if not Player then
        RSGCore.Functions.Notify(src, Lang:t('error.not_online'), 'error')

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

        TriggerClientEvent('RSGCore:Notify', src, 'you lost all your possessions!', 'primary')
    end

    if Config.WipeCashOnRespawn then
        Player.Functions.SetMoney('cash', 0)

        TriggerClientEvent('RSGCore:Notify', src, 'you lost all your cash!', 'primary')
    end
end)

-- Set Player Health
RegisterNetEvent('rsg-medic:server:SetHealth', function(amount)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)

    if not Player then return end

    amount = tonumber(amount)

    if amount < 1 then
        amount = 1
    elseif amount > Config.MaxHealth then
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
        TriggerClientEvent('RSGCore:Notify', src, Lang:t('error.not_medic'), 'error')

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
        TriggerClientEvent('RSGCore:Notify', src, Lang:t('error.not_medic'), 'error')

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