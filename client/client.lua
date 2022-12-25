local RSGCore = exports['rsg-core']:GetCoreObject()
local deathSecondsRemaining = 0
local deathTimerStarted = false
local deathactive = false

------------------------------------------------------------------------------------------------------------------------

-- register death
CreateThread(function()
    while true do
        Wait(0)
        local player = PlayerId()
        if NetworkIsPlayerActive(player) then
            local playerPed = PlayerPedId()
            if IsEntityDead(playerPed) and not deathactive then
                exports.spawnmanager:setAutoSpawn(false)
                deathTimerStarted = true
                deathTimer()
                deathactive = true
            end
        end
    end
end)

------------------------------------------------------------------------------------------------------------------------

-- display respawn message and countdown
CreateThread(function()
    while true do
        Wait(0)
        if deathTimerStarted == true and deathSecondsRemaining > 0 then
            DrawTxt('RESPAWN IN '..deathSecondsRemaining..' SECONDS..', 0.50, 0.80, 0.5, 0.5, true, 104, 244, 120, 200, true)
        end
        if deathTimerStarted == true and deathSecondsRemaining == 0 then
            DrawTxt('PRESS [E] TO RESPAWN', 0.50, 0.80, 0.5, 0.5, true, 104, 244, 120, 200, true)
        end
        if deathTimerStarted == true and deathSecondsRemaining == 0 and IsControlPressed(0, RSGCore.Shared.Keybinds['E']) then
            deathTimerStarted = false
            TriggerEvent('rsg-medic:clent:revive')
            TriggerServerEvent('rsg-medic::server:deathactions')
        end
    end
end)

------------------------------------------------------------------------------------------------------------------------

RegisterNetEvent('rsg-medic:clent:revive', function()
    local player = PlayerPedId()
    if deathactive == true then
        DoScreenFadeOut(500)
        Wait(1000)
        local pos = GetEntityCoords(player, true)
        NetworkResurrectLocalPlayer(pos.x, pos.y, pos.z, GetEntityHeading(player), true, false)
        SetEntityInvincible(player, false)
        Wait(1500)
        DoScreenFadeIn(1800)
        Citizen.InvokeNative(0xC6258F41D86676E0, player, 0, 100) -- SetAttributeCoreValue
        Citizen.InvokeNative(0xC6258F41D86676E0, player, 1, 100) -- SetAttributeCoreValue
        Citizen.InvokeNative(0xC6258F41D86676E0, player, 2, 100) -- SetAttributeCoreValue
        TriggerServerEvent("RSGCore:Server:SetMetaData", "hunger", RSGCore.Functions.GetPlayerData().metadata["hunger"] + 100)
        TriggerServerEvent("RSGCore:Server:SetMetaData", "thirst", RSGCore.Functions.GetPlayerData().metadata["thirst"] + 100)
        ClearPedBloodDamage(player)
        SetCurrentPedWeapon(player, `WEAPON_UNARMED`, true)
        RemoveAllPedWeapons(player, true, true)
        deathactive = false
    end
end)

------------------------------------------------------------------------------------------------------------------------

-- death timer
function deathTimer()
    deathSecondsRemaining = Config.DeathTimer
    Citizen.CreateThread(function()
        while deathSecondsRemaining > 0 do
            Wait(1000)
            deathSecondsRemaining = deathSecondsRemaining - 1
        end
    end)
end

-- resouces
function DrawTxt(str, x, y, w, h, enableShadow, col1, col2, col3, a, centre)
    local str = CreateVarString(10, "LITERAL_STRING", str)
    SetTextScale(w, h)
    SetTextColor(math.floor(col1), math.floor(col2), math.floor(col3), math.floor(a))
    SetTextCentre(centre)
    if enableShadow then SetTextDropshadow(1, 0, 0, 0, 255) end
    DisplayText(str, x, y)
end

------------------------------------------------------------------------------------------------------------------------
