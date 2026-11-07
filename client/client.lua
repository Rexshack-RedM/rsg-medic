local RSGCore = exports['rsg-core']:GetCoreObject()

local isDead     = false
local isBusy     = false
local nuiOpen    = false
local alertUntil = 0
local PlayerJob  = {}
local blips      = {} -- office blips
local alertBlips = {} -- [blip] = true, patient alerts
local promptGroup = GetRandomIntInRange(0, 0xffffff)
local menuPrompt
local deathCam
local opening = false
local uiEditing = false

local isMedicJob = {}
for _, name in ipairs(Config.MedicJobs) do isMedicJob[name] = true end

---------------------------------
-- helpers
---------------------------------
local function Notify(key, nType, ...)
    RSGCore.Functions.Notify({ title = locale('title'), description = locale(key, ...), type = nType, duration = 5000 })
end

local function IsMedic(needDuty)
    if not isMedicJob[PlayerJob.name] then return false end
    return not (needDuty and Config.RequireDuty and not PlayerJob.onduty)
end

local function SetBlipLabel(blip, text)
    Citizen.InvokeNative(0x9CB1A1623062F402, blip, text) -- SetBlipName
end

local function SetNui(open)
    nuiOpen = open
    SetNuiFocus(open, open)
end

local function FullHeal(ped)
    SetEntityHealth(ped, GetEntityMaxHealth(ped))
    Citizen.InvokeNative(0xC6258F41D86676E0, ped, 0, 100) -- health core
    Citizen.InvokeNative(0xC6258F41D86676E0, ped, 1, 100) -- stamina core
    ClearPedBloodDamage(ped)
end

---------------------------------
-- death screen
---------------------------------
local function DeathScreen()
    local info = RSGCore.Functions.AwaitCallback('rsg-medic:server:getDeathInfo') or { remaining = Config.DeathTimer, medics = 0 }
    local deadline = GetGameTimer() + info.remaining * 1000
    local medics = info.medics
    local lastSync, lastPush = GetGameTimer(), 0

    SendNUIMessage({ action = 'death', show = true, fee = Config.RespawnFee })

    local am = Config.AutoMedic
    while isDead do
        local now = GetGameTimer()
        local useAutoMedic = am.Enabled and medics <= 0 and (am.MaxMedicsOnDuty < 0 or medics <= am.MaxMedicsOnDuty)

        if now - lastSync > 15000 then -- resync timer + medic count with the server
            lastSync = now
            CreateThread(function()
                local i = RSGCore.Functions.AwaitCallback('rsg-medic:server:getDeathInfo')
                if i then deadline, medics = GetGameTimer() + i.remaining * 1000, i.medics end
            end)
        end

        local remaining = math.max(0, math.ceil((deadline - now) / 1000))
        local alertWait = math.max(0, math.ceil((alertUntil - now) / 1000))


        if now - lastPush >= 1000 then
            lastPush = now
            SendNUIMessage({ action = 'deathUpdate', remaining = remaining, total = Config.DeathTimer, medics = medics, alertWait = alertWait, autoMedic = useAutoMedic, autoMedicCost = useAutoMedic and am.Cost or 0 })
        end

        if remaining == 0 and (IsControlJustReleased(0, Config.Keys.respawn) or IsDisabledControlJustReleased(0, Config.Keys.respawn)) then
            TriggerServerEvent('rsg-medic:server:respawn')
            Wait(2000)
        elseif alertWait == 0 and (IsControlJustReleased(0, Config.Keys.alert) or IsDisabledControlJustReleased(0, Config.Keys.alert)) then
            if useAutoMedic then
                ExecuteCommand(am.Command) -- no doctors on duty: send the NPC doctor
                alertUntil = now + 5000
            else
                TriggerServerEvent('rsg-medic:server:alert')
                alertUntil = now + 2000 -- debounce until the server answers
            end
        end

        Wait(0)
    end

    SendNUIMessage({ action = 'death', show = false })
end

---------------------------------
-- free-look death camera (orbits the body, mouse to look, scroll to zoom)
---------------------------------
local function DeathCam()
    local cfg = Config.DeathCam
    local heading = GetGameplayCamRelativeHeading() + GetEntityHeading(PlayerPedId())
    local pitch, dist = -20.0, cfg.Distance
    local cam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
    deathCam = cam
    SetCamFov(cam, 60.0)
    RenderScriptCams(true, true, 500, true, true)

    while isDead do
        heading = heading - GetDisabledControlNormal(0, 0xA987235F) * cfg.Sensitivity -- look left/right
        pitch = math.max(-80.0, math.min(10.0, pitch - GetDisabledControlNormal(0, 0xD2047988) * cfg.Sensitivity)) -- look up/down
        if IsDisabledControlJustPressed(0, 0x62800C92) then dist = math.max(cfg.MinDistance, dist - 0.5) end -- scroll up
        if IsDisabledControlJustPressed(0, 0x8BDE7443) then dist = math.min(cfg.MaxDistance, dist + 0.5) end -- scroll down

        local ped = PlayerPedId()
        local target = GetEntityCoords(ped) + vector3(0.0, 0.0, 0.3)
        local h, p = math.rad(heading), math.rad(pitch)
        local offset = vector3(math.sin(h) * math.cos(p) * dist, -math.cos(h) * math.cos(p) * dist, -math.sin(p) * dist) -- behind and above the body
        local pos = target + offset

        -- stop the camera clipping through walls/terrain
        local ray = StartShapeTestRay(target.x, target.y, target.z, pos.x, pos.y, pos.z, -1, ped, 0)
        local _, hit, hitPos = GetShapeTestResult(ray)
        if hit == 1 then pos = target + (hitPos - target) * 0.9 end

        SetCamCoord(cam, pos.x, pos.y, pos.z)
        PointCamAtCoord(cam, target.x, target.y, target.z)
        Wait(0)
    end

    RenderScriptCams(false, true, 500, true, true)
    DestroyCam(cam, false)
    deathCam = nil
end

local function OnDeath()
    if isDead then return end
    isDead = true
    if nuiOpen then SetNui(false) SendNUIMessage({ action = 'closeAll' }) end
    if uiEditing then uiEditing = false SetNuiFocus(false, false) SendNUIMessage({ action = 'editMode', enabled = false }) end
    LocalPlayer.state:set('inv_busy', true, true)
    TriggerServerEvent('rsg-medic:server:setDead')
    CreateThread(DeathScreen)
    if Config.DeathCam and Config.DeathCam.Enabled then CreateThread(DeathCam) end
end

CreateThread(function()
    while true do
        if not isDead and LocalPlayer.state.isLoggedIn and not LocalPlayer.state.isLoadingSkin then
            -- always use the live ped: a model swap (/loadskin) replaces the player ped
            local ped = PlayerPedId()
            if DoesEntityExist(ped) and IsEntityDead(ped) then
                Wait(500) -- confirm, so a brief ped swap can't trigger the death screen
                ped = PlayerPedId()
                if not LocalPlayer.state.isLoadingSkin and DoesEntityExist(ped) and IsEntityDead(ped) then OnDeath() end
            end
        end
        Wait(isDead and 1000 or 500)
    end
end)

RegisterNetEvent('rsg-medic:client:alertSent', function(cooldown)
    alertUntil = GetGameTimer() + cooldown * 1000
end)

RegisterNetEvent('rsg-medic:client:revive', function(spawn)
    DoScreenFadeOut(500)
    while not IsScreenFadedOut() do Wait(10) end

    local ped = PlayerPedId()
    local c = spawn or GetEntityCoords(ped)
    local heading = spawn and spawn.w or GetEntityHeading(ped)

    NetworkResurrectLocalPlayer(c.x, c.y, c.z, heading, true, false)
    ped = PlayerPedId()
    if spawn then
        SetEntityCoords(ped, c.x, c.y, c.z, false, false, false, false)
        SetEntityHeading(ped, heading)
    end
    ClearPedTasksImmediately(ped)
    FullHeal(ped)

    isDead = false
    LocalPlayer.state:set('inv_busy', false, true)
    Wait(500)
    DoScreenFadeIn(1000)
end)

RegisterNetEvent('rsg-medic:client:heal', function(amount)
    if isDead then return end
    local ped = PlayerPedId()
    if amount == -1 then return FullHeal(ped) end
    SetEntityHealth(ped, math.min(GetEntityMaxHealth(ped), GetEntityHealth(ped) + amount))
end)

-- re-apply death if the character logged out while downed
local function CheckLoadedState()
    local pd = RSGCore.Functions.GetPlayerData()
    PlayerJob = pd.job or {}
    if pd.metadata and pd.metadata.isdead then
        Wait(1000)
        SetEntityHealth(PlayerPedId(), 0)
    end
end

RegisterNetEvent('RSGCore:Client:OnPlayerLoaded', function() CreateThread(CheckLoadedState) end)
RegisterNetEvent('RSGCore:Client:OnJobUpdate', function(job) PlayerJob = job end)
RegisterNetEvent('RSGCore:Client:SetDuty', function(duty) PlayerJob.onduty = duty end)
RegisterNetEvent('RSGCore:Client:OnPlayerUnload', function() PlayerJob = {} end)

---------------------------------
-- medic alerts
---------------------------------
RegisterNetEvent('rsg-medic:client:alert', function(coords)
    if not IsMedic(true) then return end
    Notify('alert_received', 'warning')
    local blip = BlipAddForCoords(1664425300, coords.x, coords.y, coords.z)
    SetBlipSprite(blip, Config.AlertBlipSprite, true)
    SetBlipLabel(blip, locale('alert_blip'))
    alertBlips[blip] = true
    SetTimeout(Config.AlertBlipTime * 1000, function()
        alertBlips[blip] = nil
        if DoesBlipExist(blip) then RemoveBlip(blip) end
    end)
end)

---------------------------------
-- timed medic actions
---------------------------------
local function DoAction(kind, target)
    if isBusy or isDead then return end
    isBusy = true
    local duration = RSGCore.Functions.AwaitCallback('rsg-medic:server:beginAction', nil, kind, target)
    if not duration then isBusy = false return end

    local ped = PlayerPedId()
    local targetPed = GetPlayerPed(GetPlayerFromServerId(target))
    if targetPed ~= 0 then TaskTurnPedToFaceEntity(ped, targetPed, 1000) Wait(1000) end
    TaskStartScenarioInPlace(ped, `WORLD_HUMAN_CROUCH_INSPECT`, -1, true, false, false, false)

    local ok = RSGCore.Functions.ProgressBar({
        duration  = duration,
        label     = locale(kind == 'revive' and 'progress_revive' or 'progress_treat'),
        canCancel = true,
        disable   = { move = true, mount = true, combat = true },
    })

    ClearPedTasks(ped)
    isBusy = false
    if ok then
        TriggerServerEvent('rsg-medic:server:finishAction')
    else
        TriggerServerEvent('rsg-medic:server:cancelAction')
        Notify('cancelled', 'inform')
    end
end

RegisterNetEvent('rsg-medic:client:useBandage', function()
    if isBusy or isDead then return TriggerServerEvent('rsg-medic:server:bandageCancel') end
    local ped = PlayerPedId()
    if GetEntityHealth(ped) >= GetEntityMaxHealth(ped) then
        TriggerServerEvent('rsg-medic:server:bandageCancel')
        return Notify('full_health', 'inform')
    end

    isBusy = true
    local ok = RSGCore.Functions.ProgressBar({
        duration  = Config.Bandage.duration,
        label     = locale('progress_bandage'),
        canCancel = true,
        disable   = { mount = true, combat = true },
    })
    isBusy = false
    if ok then
        TriggerServerEvent('rsg-medic:server:bandageDone')
    else
        TriggerServerEvent('rsg-medic:server:bandageCancel')
        Notify('cancelled', 'inform')
    end
end)

---------------------------------
-- field menu
---------------------------------
local function OpenFieldMenu(refresh)
    if isDead or isBusy then return end
    if not IsMedic() then return Notify('not_medic', 'error') end
    if not IsMedic(true) then return Notify('not_on_duty', 'error') end

    local patients = RSGCore.Functions.AwaitCallback('rsg-medic:server:getPatients') or {}
    for _, p in ipairs(patients) do
        local ped = GetPlayerPed(GetPlayerFromServerId(p.id))
        if ped ~= 0 and not p.dead then
            p.health = math.floor(GetEntityHealth(ped) / math.max(1, GetEntityMaxHealth(ped)) * 100)
        else
            p.health = 0
        end
        p.dist = math.floor(p.dist * 10) / 10
    end

    if not refresh then SetNui(true) end
    SendNUIMessage({ action = 'field', patients = patients })
end

---------------------------------
-- UI move mode
---------------------------------
RegisterCommand(Config.UiCommand, function()
    if nuiOpen or isDead then return end -- menus can already be dragged while open
    uiEditing = not uiEditing
    SetNuiFocus(uiEditing, uiEditing)
    SendNUIMessage({ action = 'editMode', enabled = uiEditing })
end, false)

RegisterNUICallback('editDone', function(_, cb)
    uiEditing = false
    if not nuiOpen then SetNuiFocus(false, false) end
    cb('ok')
end)

RegisterCommand(Config.FieldCommand, function() OpenFieldMenu(false) end, false)
TriggerEvent('chat:addSuggestion', '/' .. Config.FieldCommand, locale('cmd_medic_help'))

---------------------------------
-- doctor's office
---------------------------------
local currentLoc

local function OpenOfficeMenu(loc, refresh)
    local data = RSGCore.Functions.AwaitCallback('rsg-medic:server:getMenu', nil, loc.id)
    if not data then return Notify('not_medic', 'error') end
    if isDead then return end
    currentLoc = loc
    data.maxAmount = Config.MaxBuyAmount
    if not refresh then SetNui(true) end
    SendNUIMessage({ action = 'menu', data = data })
end

local function CreatePrompt()
    menuPrompt = PromptRegisterBegin()
    PromptSetControlAction(menuPrompt, Config.Keys.prompt)
    PromptSetText(menuPrompt, CreateVarString(10, 'LITERAL_STRING', locale('prompt_menu')))
    PromptSetEnabled(menuPrompt, true)
    PromptSetVisible(menuPrompt, true)
    PromptSetHoldMode(menuPrompt, 1000)
    PromptSetGroup(menuPrompt, promptGroup, 0)
    PromptRegisterEnd(menuPrompt)
end

CreateThread(function()
    CreatePrompt()
    for _, loc in ipairs(Config.Locations) do
        local blip = BlipAddForCoords(1664425300, loc.point.x, loc.point.y, loc.point.z)
        SetBlipSprite(blip, Config.BlipSprite, true)
        SetBlipScale(blip, 0.2)
        SetBlipLabel(blip, loc.label)
        blips[#blips + 1] = blip
    end

    -- office prompt: sleeps unless a medic is standing at a doctor's office
    while true do
        local sleep = 1000
        if not nuiOpen and not isDead and not opening and IsMedic() then
            local coords = GetEntityCoords(PlayerPedId())
            for _, loc in ipairs(Config.Locations) do
                if #(coords - loc.point) <= 2.0 then
                    sleep = 0
                    PromptSetActiveGroupThisFrame(promptGroup, CreateVarString(10, 'LITERAL_STRING', loc.label))
                    if PromptHasHoldModeCompleted(menuPrompt) then
                        opening = true -- hold stays "completed" for a few frames; open once
                        CreateThread(function()
                            OpenOfficeMenu(loc)
                            Wait(500)
                            opening = false
                        end)
                    end
                    break
                end
            end
        end
        Wait(sleep)
    end
end)

---------------------------------
-- NUI callbacks
---------------------------------
RegisterNUICallback('ready', function(_, cb)
    -- send every ui_ key (en.json is the master list; locale() falls back to English per key)
    local strings = {}
    local ok, en = pcall(json.decode, LoadResourceFile(GetCurrentResourceName(), 'locales/en.json') or '{}')
    for k in pairs(ok and en or {}) do
        if k:sub(1, 3) == 'ui_' then strings[k] = locale(k) end
    end
    cb(strings)
end)

RegisterNUICallback('close', function(_, cb)
    SetNui(false)
    cb('ok')
end)

RegisterNUICallback('toggleDuty', function(_, cb)
    cb('ok')
    TriggerServerEvent('rsg-medic:server:toggleDuty')
    Wait(400)
    if currentLoc and nuiOpen then OpenOfficeMenu(currentLoc, true) end
end)

RegisterNUICallback('buy', function(data, cb)
    cb('ok')
    TriggerServerEvent('rsg-medic:server:buy', data.item, tonumber(data.amount))
end)

RegisterNUICallback('stash', function(_, cb)
    cb('ok')
    SetNui(false)
    TriggerServerEvent('rsg-medic:server:openStash')
end)

RegisterNUICallback('boss', function(_, cb)
    cb('ok')
    SetNui(false)
    if Config.BossMenuEvent then TriggerEvent(Config.BossMenuEvent) end
end)

RegisterNUICallback('refreshField', function(_, cb)
    cb('ok')
    OpenFieldMenu(true)
end)

RegisterNUICallback('action', function(data, cb)
    cb('ok')
    if data.kind ~= 'revive' and data.kind ~= 'treat' then return end
    SetNui(false)
    DoAction(data.kind, tonumber(data.id))
end)

---------------------------------
-- startup / cleanup
---------------------------------
AddEventHandler('onResourceStart', function(res)
    if res ~= GetCurrentResourceName() then return end
    if LocalPlayer.state.isLoggedIn then CreateThread(CheckLoadedState) end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for _, b in ipairs(blips) do if DoesBlipExist(b) then RemoveBlip(b) end end
    for b in pairs(alertBlips) do if DoesBlipExist(b) then RemoveBlip(b) end end
    if menuPrompt then PromptDelete(menuPrompt) end
    if deathCam then RenderScriptCams(false, false, 0, true, true) DestroyCam(deathCam, false) end
    if nuiOpen or uiEditing then SetNuiFocus(false, false) end
    if isDead then LocalPlayer.state:set('inv_busy', false, true) end
end)
