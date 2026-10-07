local RSGCore = exports['rsg-core']:GetCoreObject()
lib.locale()

local isDead     = false
local isBusy     = false
local nuiOpen    = false
local alertUntil = 0
local PlayerJob  = {}
local blips      = {}
local promptGroup = GetRandomIntInRange(0, 0xffffff)
local menuPrompt

local isMedicJob = {}
for _, name in ipairs(Config.MedicJobs) do isMedicJob[name] = true end

---------------------------------
-- helpers
---------------------------------
local function Notify(key, nType, ...)
    lib.notify({ title = locale('title'), description = locale(key, ...), type = nType, duration = 5000 })
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
    local info = lib.callback.await('rsg-medic:server:getDeathInfo', false)
    local deadline = GetGameTimer() + info.remaining * 1000
    local medics = info.medics
    local lastSync, lastPush = GetGameTimer(), 0

    SendNUIMessage({ action = 'death', show = true, fee = Config.RespawnFee })

    while isDead do
        local now = GetGameTimer()

        if now - lastSync > 15000 then -- resync timer + medic count with the server
            lastSync = now
            CreateThread(function()
                local i = lib.callback.await('rsg-medic:server:getDeathInfo', false)
                if i then deadline, medics = GetGameTimer() + i.remaining * 1000, i.medics end
            end)
        end

        local remaining = math.max(0, math.ceil((deadline - now) / 1000))
        local alertWait = math.max(0, math.ceil((alertUntil - now) / 1000))

        local useAutoMedic = Config.AutoMedic and Config.AutoMedic.Enabled and medics <= 0

        if now - lastPush >= 1000 then
            lastPush = now
            SendNUIMessage({ action = 'deathUpdate', remaining = remaining, total = Config.DeathTimer, medics = medics, alertWait = alertWait, autoMedic = useAutoMedic, autoMedicCost = useAutoMedic and Config.AutoMedic.Cost or 0 })
        end

        if remaining == 0 and (IsControlJustReleased(0, Config.Keys.respawn) or IsDisabledControlJustReleased(0, Config.Keys.respawn)) then
            TriggerServerEvent('rsg-medic:server:respawn')
            Wait(2000)
        elseif alertWait == 0 and (IsControlJustReleased(0, Config.Keys.alert) or IsDisabledControlJustReleased(0, Config.Keys.alert)) then
            if useAutoMedic then
                ExecuteCommand(Config.AutoMedic.Command) -- no doctors on duty: send the NPC doctor
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
    local heading = GetGameplayCamRelativeHeading() + GetEntityHeading(cache.ped)
    local pitch, dist = -20.0, cfg.Distance
    local cam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
    SetCamFov(cam, 60.0)
    RenderScriptCams(true, true, 500, true, true)

    while isDead do
        heading = heading - GetDisabledControlNormal(0, 0xA987235F) * cfg.Sensitivity -- look left/right
        pitch = math.max(-80.0, math.min(10.0, pitch - GetDisabledControlNormal(0, 0xD2047988) * cfg.Sensitivity)) -- look up/down
        if IsDisabledControlJustPressed(0, 0x62800C92) then dist = math.max(cfg.MinDistance, dist - 0.5) end -- scroll up
        if IsDisabledControlJustPressed(0, 0x8BDE7443) then dist = math.min(cfg.MaxDistance, dist + 0.5) end -- scroll down

        local target = GetEntityCoords(cache.ped) + vector3(0.0, 0.0, 0.3)
        local h, p = math.rad(heading), math.rad(pitch)
        local offset = vector3(math.sin(h) * math.cos(p) * dist, -math.cos(h) * math.cos(p) * dist, -math.sin(p) * dist) -- behind and above the body
        local pos = target + offset

        -- stop the camera clipping through walls/terrain
        local ray = StartShapeTestRay(target.x, target.y, target.z, pos.x, pos.y, pos.z, -1, cache.ped, 0)
        local _, hit, hitPos = GetShapeTestResult(ray)
        if hit == 1 then pos = target + (hitPos - target) * 0.9 end

        SetCamCoord(cam, pos.x, pos.y, pos.z)
        PointCamAtCoord(cam, target.x, target.y, target.z)
        Wait(0)
    end

    RenderScriptCams(false, true, 500, true, true)
    DestroyCam(cam, false)
end

local function OnDeath()
    if isDead then return end
    isDead = true
    if nuiOpen then SetNui(false) SendNUIMessage({ action = 'closeAll' }) end
    LocalPlayer.state:set('inv_busy', true, true)
    TriggerServerEvent('rsg-medic:server:setDead')
    CreateThread(DeathScreen)
    if Config.DeathCam and Config.DeathCam.Enabled then CreateThread(DeathCam) end
end

CreateThread(function()
    while true do
        if not isDead and LocalPlayer.state.isLoggedIn and IsEntityDead(cache.ped) then OnDeath() end
        Wait(isDead and 1000 or 500)
    end
end)

RegisterNetEvent('rsg-medic:client:alertSent', function(cooldown)
    alertUntil = GetGameTimer() + cooldown * 1000
end)

RegisterNetEvent('rsg-medic:client:revive', function(spawn)
    DoScreenFadeOut(500)
    while not IsScreenFadedOut() do Wait(10) end

    local ped = cache.ped
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
    local ped = cache.ped
    if amount == -1 then return FullHeal(ped) end
    SetEntityHealth(ped, math.min(GetEntityMaxHealth(ped), GetEntityHealth(ped) + amount))
end)

-- re-apply death if the character logged out while downed
local function CheckLoadedState()
    local pd = RSGCore.Functions.GetPlayerData()
    PlayerJob = pd.job or {}
    if pd.metadata and pd.metadata.isdead then
        Wait(1000)
        SetEntityHealth(cache.ped, 0)
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
    blips[#blips + 1] = blip
    SetTimeout(Config.AlertBlipTime * 1000, function()
        if DoesBlipExist(blip) then RemoveBlip(blip) end
    end)
end)

---------------------------------
-- timed medic actions
---------------------------------
local function DoAction(kind, target)
    if isBusy or isDead then return end
    local duration = lib.callback.await('rsg-medic:server:beginAction', false, kind, target)
    if not duration then return end

    isBusy = true
    local targetPed = GetPlayerPed(GetPlayerFromServerId(target))
    if targetPed ~= 0 then TaskTurnPedToFaceEntity(cache.ped, targetPed, 1000) Wait(1000) end
    TaskStartScenarioInPlace(cache.ped, `WORLD_HUMAN_CROUCH_INSPECT`, -1, true, false, false, false)

    local ok = lib.progressBar({
        duration  = duration,
        label     = locale(kind == 'revive' and 'progress_revive' or 'progress_treat'),
        canCancel = true,
        disable   = { move = true, car = true, combat = true },
    })

    ClearPedTasks(cache.ped)
    isBusy = false
    if ok then
        TriggerServerEvent('rsg-medic:server:finishAction')
    else
        TriggerServerEvent('rsg-medic:server:cancelAction')
        Notify('cancelled', 'inform')
    end
end

RegisterNetEvent('rsg-medic:client:useBandage', function()
    if isBusy or isDead then return end
    local ped = cache.ped
    if GetEntityHealth(ped) >= GetEntityMaxHealth(ped) then return Notify('full_health', 'inform') end

    isBusy = true
    local ok = lib.progressBar({
        duration  = Config.Bandage.duration,
        label     = locale('progress_bandage'),
        canCancel = true,
        disable   = { car = true, combat = true },
    })
    isBusy = false
    if ok then TriggerServerEvent('rsg-medic:server:bandageDone') else Notify('cancelled', 'inform') end
end)

---------------------------------
-- field menu
---------------------------------
local function OpenFieldMenu(refresh)
    if isDead or isBusy then return end
    if not IsMedic() then return Notify('not_medic', 'error') end
    if not IsMedic(true) then return Notify('not_on_duty', 'error') end

    local patients = lib.callback.await('rsg-medic:server:getPatients', false) or {}
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
local uiEditing = false
RegisterCommand(Config.UiCommand, function()
    if nuiOpen then return end -- menus can already be dragged while open
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
    local data = lib.callback.await('rsg-medic:server:getMenu', false, loc.id)
    if not data then return Notify('not_medic', 'error') end
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

        lib.points.new({
            coords = loc.point,
            distance = 2.0,
            nearby = function()
                if nuiOpen or isDead or not IsMedic() then return end
                PromptSetActiveGroupThisFrame(promptGroup, CreateVarString(10, 'LITERAL_STRING', loc.label))
                if PromptHasHoldModeCompleted(menuPrompt) then
                    CreateThread(function() OpenOfficeMenu(loc) end)
                end
            end,
        })
    end
end)

---------------------------------
-- NUI callbacks
---------------------------------
RegisterNUICallback('ready', function(_, cb)
    local strings = {}
    for k, v in pairs(lib.getLocales()) do
        if k:sub(1, 3) == 'ui_' then strings[k] = v end
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
    if menuPrompt then PromptDelete(menuPrompt) end
    if nuiOpen then SetNuiFocus(false, false) end
    if isDead then LocalPlayer.state:set('inv_busy', false, true) end
end)
