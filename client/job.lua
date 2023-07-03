local RSGCore = exports['rsg-core']:GetCoreObject()

local blipEntries = {}
local transG = Config.DeathTimer
local medicbox = nil


------------------------------------------------------ FUNCTIONS -------------------------------------------------------


-- Get Closest Player
local GetClosestPlayer = function()
    local playerPed = PlayerPedId()
    local coords = GetEntityCoords(playerPed)
    local closestDistance = -1
    local closestPlayer = -1
    local closestPlayers = RSGCore.Functions.GetPlayersFromCoords()

    for i = 1, #closestPlayers, 1 do
        if closestPlayers[i] ~= PlayerId() then
            local ped = GetPlayerPed(closestPlayers[i])
            local pos = GetEntityCoords(ped)
            local distance = #(pos - coords)

            if closestDistance == -1 or closestDistance > distance then
                closestPlayer = closestPlayers[i]
                closestDistance = distance
            end
        end
    end

    return closestPlayer, closestDistance
end


-------------------------------------------------------- EVENTS --------------------------------------------------------


-- Toggle On-Duty
AddEventHandler('rsg-medic:client:ToggleDuty', function()
    RSGCore.Functions.GetPlayerData(function(PlayerData)
        local PlayerJob = PlayerData.job

        if PlayerJob.name ~= Config.JobRequired then
            RSGCore.Functions.Notify(Lang:t('error.not_medic'), 'error')

            return
        end

        TriggerServerEvent("RSGCore:ToggleDuty")
    end)
end)

-- Medic Revive Player
AddEventHandler('rsg-medic:client:RevivePlayer', function()
    local hasItem = RSGCore.Functions.HasItem('firstaid', 1)

    if not hasItem then
        RSGCore.Functions.Notify(Lang:t('error.no_firstaid'), 'error')

        return
    end

    local player, distance = GetClosestPlayer()

    if player == -1 or distance >= 5.0 then
        RSGCore.Functions.Notify(Lang:t('error.no_player'), 'error')

        return
    end

    local ped = PlayerPedId()
    local playerId = GetPlayerServerId(player)
    local tped = GetPlayerPed(GetPlayerFromServerId(playerId))

    Citizen.InvokeNative(0x5AD23D40115353AC, ped, tped, -1)

    Wait(3000)

    FreezeEntityPosition(ped, true)
    TaskStartScenarioInPlace(ped, `WORLD_HUMAN_CROUCH_INSPECT`, -1, true, false, false, false)

    Wait(5000)

    ExecuteCommand('me Reviving')

    RSGCore.Functions.Progressbar("reviving", "Reviving...", Config.MedicReviveTime, false, true,
    {
        disableMovement = true,
        disableCarMovement = true,
        disableMouse = false,
        disableCombat = true,
    }, {}, {}, {}, function()
        ClearPedTasks(ped)
        FreezeEntityPosition(ped, false)

        TriggerServerEvent('rsg-medic:server:RevivePlayer', playerId)

        transG = 0
    end)
end)

-- Medic Treat Wounds
AddEventHandler('rsg-medic:client:TreatWounds', function()
    local hasItem = RSGCore.Functions.HasItem('bandage', 1)

    if not hasItem then
        RSGCore.Functions.Notify(Lang:t('error.no_bandage'), 'error')

        return
    end

    local player, distance = GetClosestPlayer()

    if player == -1 or distance >= 5.0 then
        RSGCore.Functions.Notify(Lang:t('error.no_player'), 'error')

        return
    end

    local ped = PlayerPedId()
    local playerId = GetPlayerServerId(player)
    local tped = GetPlayerPed(GetPlayerFromServerId(playerId))

    Citizen.InvokeNative(0x5AD23D40115353AC, ped, tped, -1)

    Wait(3000)

    FreezeEntityPosition(ped, true)
    TaskStartScenarioInPlace(ped, `WORLD_HUMAN_CROUCH_INSPECT`, -1, true, false, false, false)

    Wait(5000)

    ExecuteCommand('me Treating Wounds')

    RSGCore.Functions.Progressbar("treating", "Treating Wounds...", Config.MedicTreatTime, false, true,
    {
        disableMovement = true,
        disableCarMovement = true,
        disableMouse = false,
        disableCombat = true,
    }, {}, {}, {}, function()
        ClearPedTasks(ped)
        FreezeEntityPosition(ped, false)

        TriggerServerEvent('rsg-medic:server:TreatWounds', playerId)

        transG = 0
    end)
end)

-- Medic Treat Wounds
RegisterNetEvent('rsg-medic:client:HealInjuries', function()
    local player = PlayerPedId()

    Citizen.InvokeNative(0xC6258F41D86676E0, player, 0, 100) -- SetAttributeCoreValue
    Citizen.InvokeNative(0xC6258F41D86676E0, player, 1, 100) -- SetAttributeCoreValue
    TriggerServerEvent("RSGCore:Server:SetMetaData", "hunger", RSGCore.Functions.GetPlayerData().metadata["hunger"] + 100)
    TriggerServerEvent("RSGCore:Server:SetMetaData", "thirst", RSGCore.Functions.GetPlayerData().metadata["thirst"] + 100)
    ClearPedBloodDamage(player)
end)

-- Medic Alert
RegisterNetEvent('rsg-medic:client:medicAlert', function(coords, text)
    RSGCore.Functions.Notify(text, 'medic')

    local blip = Citizen.InvokeNative(0x554D9D53F696D002, 1664425300, coords.x, coords.y, coords.z)
    local blip2 = Citizen.InvokeNative(0x554D9D53F696D002, 1664425300, coords.x, coords.y, coords.z)
    local blipText = Lang:t('info.blip_text', {value = text})

    SetBlipSprite(blip, 1109348405, 1)
    SetBlipSprite(blip2, -184692826, 1)
    Citizen.InvokeNative(0x662D364ABF16DE2F, blip, GetHashKey('BLIP_MODIFIER_AREA_PULSE'))
    Citizen.InvokeNative(0x662D364ABF16DE2F, blip2, GetHashKey('BLIP_MODIFIER_AREA_PULSE'))
    SetBlipScale(blip, 0.8)
    SetBlipScale(blip2, 2.0)
    Citizen.InvokeNative(0x9CB1A1623062F402, blip, blipText)

    blipEntries[#blipEntries + 1] = {type = "BLIP", handle = blip}
    blipEntries[#blipEntries + 1] = {type = "BLIP", handle = blip2}

    -- Add GPS Route

    if Config.AddGPSRoute then
        StartGpsMultiRoute(`COLOR_GREEN`, true, true)
        AddPointToGpsMultiRoute(coords)
        SetGpsMultiRouteRender(true)
    end

    CreateThread(function ()
        while transG ~= 0 do
            Wait(180 * 4)

            transG = transG - 1

            if transG < 0 then
                transG = 0
            end

            if transG <= 0 then
                for i = 1, #blipEntries do
                    if blipEntries[i].type == "BLIP" then
                        RemoveBlip(blipEntries[i].handle)
                    end
                end

                transG = Config.DeathTimer

                if Config.AddGPSRoute then
                    ClearGpsMultiRoute(coords)
                end

                return
            end
        end
    end)
end)

-- Cleanup
AddEventHandler("onResourceStop", function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end

    for i = 1, #blipEntries do
        if blipEntries[i].type == "BLIP" then
            RemoveBlip(blipEntries[i].handle)
        end
    end
end)