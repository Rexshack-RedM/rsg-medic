local RSGCore = exports['rsg-core']:GetCoreObject()
local createdEntries = {}
local isLoggedIn = false
local deathSecondsRemaining = 0
local deathTimerStarted = false
local deathactive = false
local mediclocation = nil
local medicsonduty = 0
local healthset = false
local closestRespawn = nil
local medicCalled = false
local Dead = false
local deadcam = nil
local angleY = 0.0
local angleZ = 0.0

---------------------------------------------------------------------
-- death timer
---------------------------------------------------------------------
local deathTimer = function()
    deathSecondsRemaining = Config.DeathTimer

    CreateThread(function()
        while deathSecondsRemaining > 0 do
            Wait(1000)

            deathSecondsRemaining = deathSecondsRemaining - 1

            TriggerEvent("rsg-medic:client:GetMedicsOnDuty")
        end
    end)
end

---------------------------------------------------------------------
-- drawtext for countdown
---------------------------------------------------------------------
local DrawTxt = function(str, x, y, w, h, enableShadow, col1, col2, col3, a, centre)
    local string = CreateVarString(10, "LITERAL_STRING", str)

    SetTextScale(w, h)
    SetTextColor(math.floor(col1), math.floor(col2), math.floor(col3), math.floor(a))
    SetTextCentre(centre)

    if enableShadow then
        SetTextDropshadow(1, 0, 0, 0, 255)
    end

    DisplayText(string, x, y)
end

---------------------------------------------------------------------
-- start death cam
---------------------------------------------------------------------
local StartDeathCam = function()
    ClearFocus()

    local coords = GetEntityCoords(cache.ped)
    local fov = GetGameplayCamFov()

    deadcam = CreateCamWithParams("DEFAULT_SCRIPTED_CAMERA", coords, 0, 0, 0, fov)

    SetCamActive(deadcam, true)
    RenderScriptCams(true, true, 1000, true, false)
end

---------------------------------------------------------------------
-- end death cam
---------------------------------------------------------------------
local EndDeathCam = function()
    ClearFocus()

    RenderScriptCams(false, false, 0, true, false)
    DestroyCam(deadcam, false)
    DestroyAllCams(true)

    deadcam = nil
end

---------------------------------------------------------------------
-- update death cam position
---------------------------------------------------------------------
local ProcessNewPosition = function()
    local mouseX = 0.0
    local mouseY = 0.0

    if IsInputDisabled(0) then
        mouseX = GetDisabledControlNormal(1, 0x6BC904FC) * 8.0
        mouseY = GetDisabledControlNormal(1, 0x84574AE8) * 8.0
    else
        mouseX = GetDisabledControlNormal(1, 0x6BC904FC) * 0.5
        mouseY = GetDisabledControlNormal(1, 0x84574AE8) * 0.5
    end

    angleZ = angleZ - mouseX
    angleY = angleY + mouseY

    if angleY > 89.0 then
        angleY = 89.0
    elseif angleY < -89.0 then
        angleY = -89.0
    end

    local pCoords = GetEntityCoords(cache.ped)

    local behindCam =
    {
        x = pCoords.x + ((Cos(angleZ) * Cos(angleY)) + (Cos(angleY) * Cos(angleZ))) / 2 * (0.5 + 0.5),
        y = pCoords.y + ((Sin(angleZ) * Cos(angleY)) + (Cos(angleY) * Sin(angleZ))) / 2 * (0.5 + 0.5),
        z = pCoords.z + ((Sin(angleY))) * (0.5 + 0.5)
    }

    local rayHandle = StartShapeTestRay(pCoords.x, pCoords.y, pCoords.z + 0.5, behindCam.x, behindCam.y, behindCam.z, -1, ped, 0)

    local _, hitBool, hitCoords, _, _ = GetShapeTestResult(rayHandle)

    local maxRadius = 3.5

    if (hitBool and Vdist(pCoords.x, pCoords.y, pCoords.z + 0.0, hitCoords) < 0.5 + 0.5) then
        maxRadius = Vdist(pCoords.x, pCoords.y, pCoords.z + 0.0, hitCoords)
    end

    local offset =
    {
        x = ((Cos(angleZ) * Cos(angleY)) + (Cos(angleY) * Cos(angleZ))) / 2 * maxRadius,
        y = ((Sin(angleZ) * Cos(angleY)) + (Cos(angleY) * Sin(angleZ))) / 2 * maxRadius,
        z = ((Sin(angleY))) * maxRadius
    }

    local pos =
    {
        x = pCoords.x + offset.x,
        y = pCoords.y + offset.y,
        z = pCoords.z + offset.z
    }

    return pos
end

---------------------------------------------------------------------
-- process camera controls
---------------------------------------------------------------------
local ProcessCamControls = function()

    local playerCoords = GetEntityCoords(cache.ped)

    -- disable 1st person as the 1st person camera can cause some glitches
    DisableOnFootFirstPersonViewThisUpdate()

    -- calculate new position
    local newPos = ProcessNewPosition()

    -- set coords of cam
    SetCamCoord(deadcam, newPos.x, newPos.y, newPos.z)

    -- set rotation
    PointCamAtCoord(deadcam, playerCoords.x, playerCoords.y, playerCoords.z)
end

---------------------------------------------------------------------
-- medic call delay
---------------------------------------------------------------------
local MedicCalled = function()
    local delay = Config.MedicCallDelay * 1000

    CreateThread(function()
        while true do
            Wait(delay)

            medicCalled = false

            return
        end
    end)
end

---------------------------------------------------------------------
-- set closest respawn
---------------------------------------------------------------------
local function SetClosestRespawn()
    local pos = GetEntityCoords(cache.ped, true)
    local current = nil
    local dist = nil

    for k, _ in pairs(Config.RespawnLocations) do
        local dest = vector3(Config.RespawnLocations[k].coords.x, Config.RespawnLocations[k].coords.y, Config.RespawnLocations[k].coords.z)
        local dist2 = #(pos - dest)

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

---------------------------------------------------------------------
-- prompts and blips
---------------------------------------------------------------------
CreateThread(function()
    for i = 1, #Config.MedicJobLocations do
        local loc = Config.MedicJobLocations[i]

        exports['rsg-core']:createPrompt(loc.prompt, loc.coords, RSGCore.Shared.Keybinds['J'], Lang:t('client.lang_1')..loc.name,
        {
            type = 'client',
            event = 'rsg-medic:client:mainmenu',
            args = {loc.prompt, loc.name}
        })

        createdEntries[#createdEntries + 1] = {type = "PROMPT", handle = loc.prompt}

        if loc.showblip then
            local MedicBlip = BlipAddForCoords(1664425300, loc.coords)

            SetBlipSprite(MedicBlip, GetHashKey(Config.Blip.blipSprite), true)
            SetBlipScale(MedicBlip, Config.Blip.blipScale)
            SetBlipName(MedicBlip, Config.Blip.blipName)

            createdEntries[#createdEntries + 1] = {type = "BLIP", handle = MedicBlip}
        end
    end
end)

---------------------------------------------------------------------
-- player dealth loop
---------------------------------------------------------------------
CreateThread(function()
    while true do
        local health = GetEntityHealth(cache.ped)
        if health == 0 and deathactive == false then
            exports.spawnmanager:setAutoSpawn(false)
            deathTimerStarted = true
            deathTimer()
            deathactive = true
            TriggerServerEvent("RSGCore:Server:SetMetaData", "isdead", true)
            TriggerEvent('rsg-medic:client:DeathCam')
        end
        Wait(1000)
    end
end)

---------------------------------------------------------------------
-- player update health loop
---------------------------------------------------------------------
CreateThread(function()
    repeat Wait(1000) until LocalPlayer.state['isLoggedIn']
    while true do
        local health = GetEntityHealth(cache.ped)
        TriggerServerEvent('rsg-medic:server:SetHealth', health)
        Wait(1000)
    end
end)

---------------------------------------------------------------------
-- display respawn message and countdown
---------------------------------------------------------------------
CreateThread(function()
    while true do
        local t = 1000

        if deathactive then
            t = 4

            if deathTimerStarted and deathSecondsRemaining > 0 then
                DrawTxt(Lang:t('client.lang_2')..deathSecondsRemaining..Lang:t('client.lang_3'), 0.50, 0.80, 0.5, 0.5, true, 104, 244, 120, 200, true)
            end

            if deathTimerStarted and deathSecondsRemaining == 0 and medicsonduty == 0 then
                DrawTxt(Lang:t('client.lang_4'), 0.50, 0.85, 0.5, 0.5, true, 104, 244, 120, 200, true)
            end

            if deathTimerStarted and deathSecondsRemaining < Config.DeathTimer and medicsonduty > 0 and not medicCalled then
                if deathSecondsRemaining == 0 then
                    DrawTxt(Lang:t('client.lang_5'), 0.50, 0.85, 0.5, 0.5, true, 104, 244, 120, 200, true)
                else
                    DrawTxt(Lang:t('client.lang_6'), 0.50, 0.85, 0.5, 0.5, true, 104, 244, 120, 200, true)
                end
            end

            if deathTimerStarted and deathSecondsRemaining == 0 and IsControlPressed(0, RSGCore.Shared.Keybinds['E']) then
                deathTimerStarted = false

                TriggerEvent('rsg-medic:client:revive')
                TriggerServerEvent('rsg-medic:server:deathactions')
            end

            if deathactive and deathTimerStarted and deathSecondsRemaining < Config.DeathTimer and IsControlPressed(0, RSGCore.Shared.Keybinds['J']) and not medicCalled then
                medicCalled = true

                if medicsonduty == 0 then
                    MedicCalled()

                    goto continue
                end

                local text = Lang:t('client.lang_7')

                TriggerServerEvent('rsg-medic:server:medicAlert', text)

                lib.notify({
                    title = Lang:t('client.lang_8'),
                    type = 'success',
                    icon = 'fa-solid fa-kit-medical',
                    iconAnimation = 'shake',
                    duration = 7000
                })

                MedicCalled()

                ::continue::
            end
        end

        if Config.Debug then
            print('deathTimerStarted: '..tostring(deathTimerStarted))
            print('deathSecondsRemaining: '..tostring(deathSecondsRemaining))
            print('medicsonduty: '..tostring(medicsonduty))
        end

        Wait(t)
    end
end)

-------------------------------------------------------- EVENTS --------------------------------------------------------

---------------------------------------------------------------------
-- medic menu
---------------------------------------------------------------------
AddEventHandler('rsg-medic:client:mainmenu', function(location, name)
    local job = RSGCore.Functions.GetPlayerData().job.name

    if job ~= Config.JobRequired then
        lib.notify({
            title = Lang:t('client.lang_9'),
            type = 'error',
            icon = 'fa-solid fa-kit-medical',
            iconAnimation = 'shake',
            duration = 7000
        })
        return
    end

    mediclocation = location

    lib.registerContext({
        id = "medic_mainmenu",
        title = name,
        options = {
             {   title = Lang:t('client.lang_10'),
                icon = 'fa-solid fa-list',
                description = Lang:t('client.lang_11'),
                event = 'rsg-bossmenu:client:mainmenu',
                isBoss = true
            }, 
            {   title = Lang:t('client.lang_12'),
                icon = 'fa-solid fa-shield-heart',
                description = '',
                event = 'rsg-medic:client:ToggleDuty',
                arrow = true
            },
            {   title = Lang:t('client.lang_13'), 
                icon = 'fa-solid fa-pills',
                description = '',
                event = 'rsg-medic:client:OpenMedicSupplies',
                arrow = true
            },
            {   title = Lang:t('client.lang_14'),
                icon = 'fa-solid fa-box-open',
                description = '',
                event = 'rsg-medic:client:storage',
                arrow = true
            },
        }
    })
    lib.showContext("medic_mainmenu")
end)

---------------------------------------------------------------------
-- death cam
---------------------------------------------------------------------
AddEventHandler('rsg-medic:client:DeathCam', function()
    CreateThread(function()
        while true do
            Wait(1000)

            if not Dead and deathactive then
                Dead = true

                StartDeathCam()
            elseif Dead and not deathactive then
                Dead = false

                EndDeathCam()
            end

            if deathSecondsRemaining <= 0 and not deathactive then
                Dead = false

                EndDeathCam()

                return
            end
        end
    end)

    CreateThread(function()
        while true do
            Wait(4)

            if deadcam and Dead then
                ProcessCamControls()
            end

            if deathactive and not deadcam then
                StartDeathCam()
            end

            if deathSecondsRemaining <= 0 and not deathactive then return end
        end
    end)
end)

---------------------------------------------------------------------
-- get medics on-duty
---------------------------------------------------------------------
AddEventHandler('rsg-medic:client:GetMedicsOnDuty', function()
    RSGCore.Functions.TriggerCallback('rsg-medic:server:getmedics', function(mediccount)
        medicsonduty = mediccount
    end)
end)

-- Player Revive After Pressing [E]
AddEventHandler('rsg-medic:client:revive', function()
    SetClosestRespawn()

    if deathactive then
        DoScreenFadeOut(500)

        Wait(1000)

        local respawnPos = Config.RespawnLocations[closestRespawn].coords
        NetworkResurrectLocalPlayer(respawnPos, true, false)
        SetEntityInvincible(cache.ped, false)
        ClearPedBloodDamage(cache.ped)
        SetAttributeCoreValue(cache.ped, 0, 100)
        SetAttributeCoreValue(cache.ped, 1, 100)
        TriggerServerEvent("RSGCore:Server:SetMetaData", "hunger", 100)
        TriggerServerEvent("RSGCore:Server:SetMetaData", "thirst", 100)
        TriggerServerEvent("RSGCore:Server:SetMetaData", "cleanliness", 100)
        TriggerServerEvent('rsg-medic:server:SetHealth', Config.MaxHealth)

        -- Reset Death Timer
        deathactive = false
        deathTimerStarted = false
        medicCalled = false
        deathSecondsRemaining = 0

        Wait(1500)

        DoScreenFadeIn(1800)

        TriggerServerEvent("RSGCore:Server:SetMetaData", "isdead", false)
    end
end)

---------------------------------------------------------------------
-- admin revive
---------------------------------------------------------------------
-- Admin Revive
RegisterNetEvent('rsg-medic:client:adminRevive', function()
    local player = PlayerPedId()
    local pos = GetEntityCoords(cache.ped, true)

    DoScreenFadeOut(500)

    Wait(1000)

    NetworkResurrectLocalPlayer(pos.x, pos.y, pos.z, GetEntityHeading(player), true, false)
    SetEntityInvincible(cache.ped, false)
    ClearPedBloodDamage(cache.ped)
    SetAttributeCoreValue(cache.ped, 0, 100) -- SetAttributeCoreValue
    SetAttributeCoreValue(cache.ped, 1, 100) -- SetAttributeCoreValue
    TriggerServerEvent("RSGCore:Server:SetMetaData", "hunger", 100)
    TriggerServerEvent("RSGCore:Server:SetMetaData", "thirst", 100)
    TriggerServerEvent("RSGCore:Server:SetMetaData", "cleanliness", 100)

    -- Reset Death Timer
    deathactive = false
    deathTimerStarted = false
    medicCalled = false
    deathSecondsRemaining = 0

    Wait(1500)

    DoScreenFadeIn(1800)

    TriggerServerEvent("RSGCore:Server:SetMetaData", "isdead", false)
end)

---------------------------------------------------------------------
-- player revive
---------------------------------------------------------------------
RegisterNetEvent('rsg-medic:client:playerRevive', function()

    local pos = GetEntityCoords(cache.ped, true)

    DoScreenFadeOut(500)

    Wait(1000)

    NetworkResurrectLocalPlayer(pos.x, pos.y, pos.z, GetEntityHeading(cache.ped), true, false)
    SetEntityInvincible(cache.ped, false)
    ClearPedBloodDamage(cache.ped)
    SetAttributeCoreValue(cache.ped, 0, 100) -- SetAttributeCoreValue
    SetAttributeCoreValue(cache.ped, 1, 100) -- SetAttributeCoreValue
    TriggerServerEvent("RSGCore:Server:SetMetaData", "hunger", 100)
    TriggerServerEvent("RSGCore:Server:SetMetaData", "thirst", 100)
    TriggerServerEvent("RSGCore:Server:SetMetaData", "cleanliness", 100)
    TriggerServerEvent('rsg-medic:server:SetHealth', Config.MaxHealth)
    
    -- Reset Death Timer
    deathactive = false
    deathTimerStarted = false
    medicCalled = false
    deathSecondsRemaining = 0

    Wait(1500)

    DoScreenFadeIn(1800)

    TriggerServerEvent("RSGCore:Server:SetMetaData", "isdead", false)
end)

---------------------------------------------------------------------
-- medic supplies
---------------------------------------------------------------------
AddEventHandler('rsg-medic:client:OpenMedicSupplies', function()
    local job = RSGCore.Functions.GetPlayerData().job.name

    if job ~= Config.JobRequired then return end

    local ShopItems = {}
    ShopItems.label = "Medic Supplies"
    ShopItems.items = Config.MedicSupplies
    ShopItems.slots = #Config.MedicSupplies

    TriggerServerEvent("inventory:server:OpenInventory", "shop", "MedicSupplies_"..math.random(1, 99), ShopItems)
end)

---------------------------------------------------------------------
-- medic storage
---------------------------------------------------------------------
AddEventHandler('rsg-medic:client:storage', function()
    local job = RSGCore.Functions.GetPlayerData().job.name
    local stashloc = mediclocation

    if job ~= Config.JobRequired then return end

    TriggerServerEvent("inventory:server:OpenInventory", "stash", stashloc,
    {
        maxweight = Config.StorageMaxWeight,
        slots = Config.StorageMaxSlots,
    })

    TriggerEvent("inventory:client:SetCurrentStash", stashloc)
end)

---------------------------------------------------------------------
-- kill player
---------------------------------------------------------------------
RegisterNetEvent('rsg-medic:client:KillPlayer')
AddEventHandler('rsg-medic:client:KillPlayer', function()
    SetEntityHealth(cache.ped, 0)
end)

---------------------------------------------------------------------
-- cleanup
---------------------------------------------------------------------
AddEventHandler("onResourceStop", function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end

    DestroyAllCams(true)

    for i = 1, #createdEntries do
        if createdEntries[i].type == "BLIP" then
            if createdEntries[i].handle then
                RemoveBlip(createdEntries[i].handle)
            end
        end

        if createdEntries[i].type == "PROMPT" then
            if createdEntries[i].handle then
                exports['rsg-core']:deletePrompt(createdEntries[i].handle)
            end
        end
    end
end)
