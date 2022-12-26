local RSGCore = exports['rsg-core']:GetCoreObject()

------------------------------------------------------------------------------------------------------------------------

-- death actions remove inventory / cash
RegisterNetEvent('rsg-medic:server:deathactions', function()
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if Config.WipeInventoryOnRespawn == true then
        Player.Functions.ClearInventory()
        MySQL.Async.execute('UPDATE players SET inventory = ? WHERE citizenid = ?', { json.encode({}), Player.PlayerData.citizenid })
        TriggerClientEvent('RSGCore:Notify', src, 'you lost all your possessions!', 'primary')
    end
    if Config.WipeCashOnRespawn == true then
        Player.Functions.SetMoney('cash', 0)
        TriggerClientEvent('RSGCore:Notify', src, 'you lost all your cash!', 'primary')
    end
end)

------------------------------------------------------------------------------------------------------------------------

RSGCore.Commands.Add("revive", Lang:t('info.revive_player_a'), {{name = "id", help = Lang:t('info.player_id')}}, false, function(source, args)
    local src = source
    if args[1] then
        local Player = RSGCore.Functions.GetPlayer(tonumber(args[1]))
        if Player then
            TriggerClientEvent('rsg-medic:clent:adminRevive', Player.PlayerData.source)
        else
            TriggerClientEvent('RSGCore:Notify', src, Lang:t('error.not_online'), 'error')
        end
    else
        TriggerClientEvent('rsg-medic:clent:playerRevive', src)
    end
end, "admin")

------------------------------------------------------------------------------------------------------------------------

-- set player health
RegisterNetEvent('rsg-medic:server:SetHealth', function(amount)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if Player then
        amount = tonumber(amount)
        if amount < 1 then
            amount = 1
        elseif amount > Config.MaxHealth then
            amount = Config.MaxHealth
        end
        Player.Functions.SetMetaData("health", amount)
    end
end)

------------------------------------------------------------------------------------------------------------------------

RegisterNetEvent('rsg-medic:server:RevivePlayer', function(playerId)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    local Patient = RSGCore.Functions.GetPlayer(playerId)
    if Patient then
        Player.Functions.RemoveItem('firstaid', 1)
        TriggerClientEvent('inventory:client:ItemBox', src, RSGCore.Shared.Items['firstaid'], "remove")
        TriggerClientEvent('rsg-medic:clent:playerRevive', Patient.PlayerData.source)
    end
end)

------------------------------------------------------------------------------------------------------------------------
