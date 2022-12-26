local RSGCore = exports['rsg-core']:GetCoreObject()
local isHealingPerson = false

-- Functions
local function loadAnimDict(dict)
    while (not HasAnimDictLoaded(dict)) do
        RequestAnimDict(dict)
        Wait(5)
    end
end

-----------------------------------------------------------------------------------

-- get closest player
local function GetClosestPlayer()
    local closestPlayers = RSGCore.Functions.GetPlayersFromCoords()
    local closestDistance = -1
    local closestPlayer = -1
    local coords = GetEntityCoords(PlayerPedId())
    for i=1, #closestPlayers, 1 do
        if closestPlayers[i] ~= PlayerId() then
            local pos = GetEntityCoords(GetPlayerPed(closestPlayers[i]))
            local distance = #(pos - coords)
            if closestDistance == -1 or closestDistance > distance then
                closestPlayer = closestPlayers[i]
                closestDistance = distance
            end
        end
    end
    return closestPlayer, closestDistance
end

-----------------------------------------------------------------------------------

-- medic revive player
RegisterNetEvent('rsg-medic:client:RevivePlayer', function()
    local hasItem = RSGCore.Functions.HasItem('firstaid', 1)
    if hasItem then
        local player, distance = GetClosestPlayer()
        if player ~= -1 and distance < 5.0 then
            local playerId = GetPlayerServerId(player)
            isHealingPerson = true
            local dict = loadAnimDict('script_re@gold_panner@gold_success')
            TaskPlayAnim(PlayerPedId(), dict, 'SEARCH01', 8.0, 8.0, -1, 1, false, false, false)
            FreezeEntityPosition(PlayerPedId(), true)
            RSGCore.Functions.Progressbar("reviving", "Reviving...", Config.MedicReviveTime, false, true, {
                disableMovement = true,
                disableCarMovement = true,
                disableMouse = false,
                disableCombat = true,
            }, {}, {}, {}, function()
                ClearPedTasks(PlayerPedId())
                TriggerServerEvent('rsg-medic:server:RevivePlayer', playerId)
                FreezeEntityPosition(PlayerPedId(), false)
                isHealingPerson = false
            end)
        else
            RSGCore.Functions.Notify(Lang:t('error.no_player'), 'error')
        end
    else
        RSGCore.Functions.Notify(Lang:t('error.no_firstaid'), 'error')
    end
end)

-----------------------------------------------------------------------------------
