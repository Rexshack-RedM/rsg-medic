local RSGCore = exports['rsg-core']:GetCoreObject()
local deathSecondsRemaining = 0
local deathTimerStarted = false
local deathactive = false
local mediclocation
local medicsonduty = 0
local healthset = false
local closestRespawn = nil
local medicCalled = false
local cam = nil
local blipEntries = {}
-----------------------------------------------------------------------------------

-- prompts and blips
CreateThread(function()
    for medic, v in pairs(Config.MedicJobLocations) do
        exports['rsg-core']:createPrompt(v.prompt, v.coords, RSGCore.Shared.Keybinds['J'], 'Open ' .. v.name, {
            type = 'client',
            event = 'rsg-medic:client:mainmenu',
            args = { v.prompt },
        })
        if v.showblip == true then
            local MedicBlip = Citizen.InvokeNative(0x554D9D53F696D002, 1664425300, v.coords)
            SetBlipSprite(MedicBlip, GetHashKey(Config.Blip.blipSprite), true)
            SetBlipScale(MedicBlip, Config.Blip.blipScale)
            Citizen.InvokeNative(0x9CB1A1623062F402, MedicBlip, Config.Blip.blipName)

            blipEntries[#blipEntries + 1] = { type = "BLIP", handle = MedicBlip }
        end
    end
end)

-- medic menu
RegisterNetEvent('rsg-medic:client:mainmenu', function(location)
    local job = RSGCore.Functions.GetPlayerData().job.name
    if job == Config.JobRequired then
        mediclocation = location
        exports['rsg-menu']:openMenu({
            {
                header = 'Medic Menu',
                isMenuHeader = true,
            },
            {
                header = "Toggle Duty",
                txt = "",
                icon = "fas fa-user-circle",
                params = {
                    event = 'rsg-medic:clent:ToggleDuty',
                    isServer = false,
                }
            },
            {
                header = "Medical Supplies",
                txt = "",
                icon = "fas fa-heartbeat",
                params = {
                    event = 'rsg-medic:clent:OpenMedicSupplies',
                    isServer = false,
                }
            },
            {
                header = "Medic Storage",
                txt = "",
                icon = "fas fa-box",
                params = {
                    event = 'rsg-medic:clent:storage',
                    isServer = false,
                    args = {},
                }
            },
            {
                header = "Job Management",
                txt = "",
                icon = "fas fa-user-circle",
                params = {
                    event = 'rsg-bossmenu:client:OpenMenu',
                    isServer = false,
                    args = {},
                }
            },
            {
                header = ">> Close Menu <<",
                txt = '',
                params = {
                    event = 'rsg-menu:closeMenu',
                }
            },
        })
    else
        RSGCore.Functions.Notify('you are not a Medic!', 'error')
    end
end)

------------------------------------------------------------------------------------------------------------------------

-- register death
CreateThread(function()
    while true do
        Wait(1000)
        local player = PlayerId()
        if NetworkIsPlayerActive(player) then
            local playerPed = PlayerPedId()
            if IsEntityDead(playerPed) and not deathactive then
                local heading = GetEntityHeading(playerPed)
                cam = CreateCam("DEFAULT_SCRIPTED_CAMERA", 1)

                SetCamActive(cam, true)
                RenderScriptCams(true, false, 3000, true, true)
                AttachCamToEntity(cam, playerPed, 0.0, 2.0, 1.0, false)
                SetCamFov(cam, 90.0)
                heading = (heading > 180) and heading - 180 or heading + 180
                SetCamRot(cam, -20.0, 0.0, heading, 2)

                exports.spawnmanager:setAutoSpawn(false)
                deathTimerStarted = true
                deathTimer()
                deathactive = true
                TriggerServerEvent("RSGCore:Server:SetMetaData", "isdead", true)
            end
        end
    end
end)

------------------------------------------------------------------------------------------------------------------------

-- get medics on-duty
AddEventHandler('rsg-medic:client:GetMedicsOnDuty', function()
    RSGCore.Functions.TriggerCallback('rsg-medic:server:getmedics', function(mediccount)
        medicsonduty = mediccount
    end)
end)

-- Medic Call delay
local MedicCalled = function()
    Citizen.CreateThread(function()
        while true do
            Wait(30000)
            medicCalled = false
            return
        end
    end)
end

-- display respawn message and countdown
CreateThread(function()
    while true do
        Wait(0)
        if deathactive == true then
            TriggerEvent("rsg-medic:client:GetMedicsOnDuty")
            if deathTimerStarted == true and deathSecondsRemaining > 0 then
                DrawTxt('RESPAWN IN '..deathSecondsRemaining..' SECONDS..', 0.50, 0.80, 0.5, 0.5, true, 104, 244, 120, 200, true)
            end
            if deathTimerStarted == true and deathSecondsRemaining == 0 and medicsonduty == 0 then
                DrawTxt('PRESS [E] TO RESPAWN', 0.50, 0.80, 0.5, 0.5, true, 104, 244, 120, 200, true)
            end
            if deathTimerStarted == true and deathSecondsRemaining == 0 and medicsonduty > 0 and not medicCalled then
                DrawTxt('PRESS [E] TO RESPAWN - PRESS [J] TO CALL FOR ASSISTANCE', 0.50, 0.80, 0.5, 0.5, true, 104, 244, 120, 200, true)
            end
            if deathTimerStarted == true and deathSecondsRemaining == 0 and IsControlPressed(0, RSGCore.Shared.Keybinds['E']) then
                deathTimerStarted = false
                TriggerEvent('rsg-medic:clent:revive')
                TriggerServerEvent('rsg-medic:server:deathactions')
            end
            if deathactive and deathTimerStarted and deathSecondsRemaining < Config.DeathTimer and IsControlPressed(0, RSGCore.Shared.Keybinds['J']) and not medicCalled then
                
                medicCalled = true

                TriggerEvent("rsg-medic:client:GetMedicsOnDuty")

                if medicsonduty == 0 then
                    MedicCalled()
                    goto continue
                end

                local player = PlayerPedId()
                local coords = GetEntityCoords(player, true)
                local text = 'A person needs medical help!'

                TriggerServerEvent('rsg-medic:server:medicAlert', coords, text)

                RSGCore.Functions.Notify('Medic has been called!', 'success', 5000)

                MedicCalled()

                ::continue::
            end
        end
    end
end)

------------------------------------------------------------------------------------------------------------------------

-- set closest respawn
local function SetClosestRespawn()
    local pos = GetEntityCoords(PlayerPedId(), true)
    local current = nil
    local dist = nil
    for k, v in pairs(Config.RespawnLocations) do
        local dist2 = #(pos - vector3(Config.RespawnLocations[k].coords.x, Config.RespawnLocations[k].coords.y, Config.RespawnLocations[k].coords.z))
        if current then
            if dist2 < dist then
                current = k
                dist = dist2
            end
        else
            dist = dist2
            current = k
        end
    end
    if current ~= closestRespawn then
        closestRespawn = current
    end
end

------------------------------------------------------------------------------------------------------------------------

-- player revive after pressing [E]
RegisterNetEvent('rsg-medic:clent:revive', function()
    SetClosestRespawn()
    local player = PlayerPedId()
    if deathactive == true then
        DoScreenFadeOut(500)
        Wait(1000)
        local respawnPos = Config.RespawnLocations[closestRespawn].coords
        NetworkResurrectLocalPlayer(respawnPos, true, false)
        SetEntityInvincible(player, false)
        ClearPedBloodDamage(player)
        Citizen.InvokeNative(0xC6258F41D86676E0, player, 0, 100) -- SetAttributeCoreValue
        Citizen.InvokeNative(0xC6258F41D86676E0, player, 1, 100) -- SetAttributeCoreValue
        TriggerServerEvent("RSGCore:Server:SetMetaData", "hunger", 100)
        TriggerServerEvent("RSGCore:Server:SetMetaData", "thirst", 100)
        SetCurrentPedWeapon(player, `WEAPON_UNARMED`, true)
        RemoveAllPedWeapons(player, true, true)
        -- reset death timer
        deathactive = false
        deathTimerStarted = false
        medicCalled = false
        RenderScriptCams(0, true, 200, true, true)
        DestroyCam(cam, false)
        deathSecondsRemaining = 0
        Wait(1500)
        DoScreenFadeIn(1800)
        TriggerServerEvent("RSGCore:Server:SetMetaData", "isdead", false)
    end
end)

------------------------------------------------------------------------------------------------------------------------

-- admin revive
RegisterNetEvent('rsg-medic:clent:adminRevive', function()
    local player = PlayerPedId()
    DoScreenFadeOut(500)
    Wait(1000)
    local pos = GetEntityCoords(player, true)
    NetworkResurrectLocalPlayer(pos.x, pos.y, pos.z, GetEntityHeading(player), true, false)
    SetEntityInvincible(player, false)
    ClearPedBloodDamage(player)
    Citizen.InvokeNative(0xC6258F41D86676E0, player, 0, 100) -- SetAttributeCoreValue
    Citizen.InvokeNative(0xC6258F41D86676E0, player, 1, 100) -- SetAttributeCoreValue
    TriggerServerEvent("RSGCore:Server:SetMetaData", "hunger", RSGCore.Functions.GetPlayerData().metadata["hunger"] + 100)
    TriggerServerEvent("RSGCore:Server:SetMetaData", "thirst", RSGCore.Functions.GetPlayerData().metadata["thirst"] + 100)
    SetCurrentPedWeapon(player, `WEAPON_UNARMED`, true)
    RemoveAllPedWeapons(player, true, true)
    -- reset death timer
    deathactive = false
    deathTimerStarted = false
    medicCalled = false
    RenderScriptCams(0, true, 200, true, true)
    DestroyCam(cam, false)
    deathSecondsRemaining = 0
    Wait(1500)
    DoScreenFadeIn(1800)
    TriggerServerEvent("RSGCore:Server:SetMetaData", "isdead", false)
end)

------------------------------------------------------------------------------------------------------------------------

-- player revive
RegisterNetEvent('rsg-medic:clent:playerRevive', function()
    local player = PlayerPedId()
    DoScreenFadeOut(500)
    Wait(1000)
    local pos = GetEntityCoords(player, true)
    NetworkResurrectLocalPlayer(pos.x, pos.y, pos.z, GetEntityHeading(player), true, false)
    SetEntityInvincible(player, false)
    ClearPedBloodDamage(player)
    Citizen.InvokeNative(0xC6258F41D86676E0, player, 0, 100) -- SetAttributeCoreValue
    Citizen.InvokeNative(0xC6258F41D86676E0, player, 1, 100) -- SetAttributeCoreValue
    TriggerServerEvent("RSGCore:Server:SetMetaData", "hunger", RSGCore.Functions.GetPlayerData().metadata["hunger"] + 100)
    TriggerServerEvent("RSGCore:Server:SetMetaData", "thirst", RSGCore.Functions.GetPlayerData().metadata["thirst"] + 100)
    SetCurrentPedWeapon(player, `WEAPON_UNARMED`, true)
    RemoveAllPedWeapons(player, true, true)
    -- reset death timer
    deathactive = false
    deathTimerStarted = false
    medicCalled = false
    RenderScriptCams(0, true, 200, true, true)
    DestroyCam(cam, false)
    deathSecondsRemaining = 0
    Wait(1500)
    DoScreenFadeIn(1800)
    TriggerServerEvent("RSGCore:Server:SetMetaData", "isdead", false)
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

-- drawtext for countdown
function DrawTxt(str, x, y, w, h, enableShadow, col1, col2, col3, a, centre)
    local str = CreateVarString(10, "LITERAL_STRING", str)
    SetTextScale(w, h)
    SetTextColor(math.floor(col1), math.floor(col2), math.floor(col3), math.floor(a))
    SetTextCentre(centre)
    if enableShadow then SetTextDropshadow(1, 0, 0, 0, 255) end
    DisplayText(str, x, y)
end

------------------------------------------------------------------------------------------------------------------------

-- setup stored health on restart
RegisterNetEvent('RSGCore:Client:OnPlayerLoaded', function()
    print('player health adjusted')

    local healthcore = Citizen.InvokeNative(0x36731AC041289BB1, PlayerPedId(), 0)
    local savedhealth = RSGCore.Functions.GetPlayerData().metadata["health"]

    while not healthset do
        Wait(1000)

        if healthcore < 100 then
            Citizen.InvokeNative(0xC6258F41D86676E0, PlayerPedId(), 0, 100) -- SetAttributeCoreValue
            SetEntityHealth(PlayerPedId(), savedhealth, 0)
            healthset = true
        else
            Wait(1000)
            healthset = true
        end
    end

    if Config.DisableRegeneration then
        Citizen.InvokeNative(0x8899C244EBCF70DE, PlayerId(), 0.0)
    end
end)

-- health update loop
CreateThread(function()
    while true do
        if healthset == true then
            local health = GetEntityHealth(PlayerPedId())
            if lastHealth ~= health then
                TriggerServerEvent('rsg-medic:server:SetHealth', health)
            end
            lastHealth = health
            Wait(1000)
        else
            Wait(5000)
        end
    end
end)

------------------------------------------------------------------------------------------------------------------------

-- medic supplies
RegisterNetEvent('rsg-medic:clent:OpenMedicSupplies')
AddEventHandler('rsg-medic:clent:OpenMedicSupplies', function()
    local ShopItems = {}
    ShopItems.label = "Medic Supplies"
    ShopItems.items = Config.MedicSupplies
    ShopItems.slots = #Config.MedicSupplies
    TriggerServerEvent("inventory:server:OpenInventory", "shop", "MedicSupplies_"..math.random(1, 99), ShopItems)
end)

-- medic storage
RegisterNetEvent('rsg-medic:clent:storage', function()
    local job = RSGCore.Functions.GetPlayerData().job.name
    local stashloc = mediclocation
    if job == Config.JobRequired then
        TriggerServerEvent("inventory:server:OpenInventory", "stash", stashloc, {
            maxweight = Config.StorageMaxWeight,
            slots = Config.StorageMaxSlots,
        })
        TriggerEvent("inventory:client:SetCurrentStash", stashloc)
    end
end)

------------------------------------------------------------------------------------------------------------------------

-- Cleanup
AddEventHandler("onResourceStop", function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end

    for i = 1, #Config.MedicJobLocations do
        local pos = Config.MedicJobLocations[i]

        exports['rsg-core']:deletePrompt(pos.prompt)
    end

    for i = 1, #blipEntries do
        if blipEntries[i].type == "BLIP" then
            RemoveBlip(blipEntries[i].handle)
        end
    end
end)