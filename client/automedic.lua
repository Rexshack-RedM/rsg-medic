---------------------------------------------------------------
-- Auto medic (NPC doctor) - merged from rex-automedic
---------------------------------------------------------------
if not Config.AutoMedic.Enabled then return end
local RSGCore = exports['rsg-core']:GetCoreObject()

local doctor, horse, blip = nil, nil, nil
local active = false

---------------------------------
-- helpers
---------------------------------
local function debug(msg)
    if Config.AutoMedic.Debug then print('[rsg-medic:automedic] ' .. msg) end
end

local function notify(desc, ntype)
    lib.notify({ title = locale('am_sv_title'), description = desc, type = ntype or 'info', duration = 5000 })
end

local function loadModel(model)
    local hash = type(model) == 'string' and joaat(model) or model
    if not IsModelValid(hash) then return nil end
    RequestModel(hash, false)
    local timeout = GetGameTimer() + 10000
    while not HasModelLoaded(hash) do
        if GetGameTimer() > timeout then return nil end
        Wait(10)
    end
    return hash
end

local function isPlayerDead()
    -- rsg-medic tracks death in player metadata
    local PlayerData = RSGCore.Functions.GetPlayerData()
    if PlayerData and PlayerData.metadata and PlayerData.metadata['isdead'] then
        debug('dead via metadata') return true
    end
    local ped = cache.ped or PlayerPedId()
    if IsEntityDead(ped) or GetEntityHealth(ped) <= 0 then
        debug('dead via native') return true
    end
    return false
end

-- death-screen status panel
local function status(stage, data)
    data = data or {}
    data.action, data.stage = 'automedic', stage
    SendNUIMessage(data)
end

local function report(stage)
    TriggerServerEvent('rsg-medic:automedic:server:stage', stage)
end

local function cleanup()
    if blip and DoesBlipExist(blip) then RemoveBlip(blip) end
    if doctor and DoesEntityExist(doctor) then DeleteEntity(doctor) end
    if horse and DoesEntityExist(horse) then DeleteEntity(horse) end
    doctor, horse, blip = nil, nil, nil
    status('hide')
    if active then
        active = false
        TriggerServerEvent('rsg-medic:automedic:server:finished')
    end
end

local function getSpawnPoint(origin)
    for _ = 1, 15 do
        local angle = math.random() * 2.0 * math.pi
        local x = origin.x + math.cos(angle) * Config.AutoMedic.SpawnDistance
        local y = origin.y + math.sin(angle) * Config.AutoMedic.SpawnDistance
        -- try to use a nearby road so the horse has a path
        local found, node = GetClosestVehicleNode(x, y, origin.z, 1, 3.0, 0)
        if found and #(vector3(node.x, node.y, node.z) - origin) > Config.AutoMedic.SpawnDistance * 0.5 then
            return vector3(node.x, node.y, node.z)
        end
        RequestCollisionAtCoord(x, y, origin.z)
        local ok, groundZ = GetGroundZFor_3dCoord(x, y, origin.z + 50.0, false)
        if ok then return vector3(x, y, groundZ) end
    end
    return nil
end

local function setupPed(ped)
    SetEntityAsMissionEntity(ped, true, true)
    Citizen.InvokeNative(0x283978A15512B2FE, ped, true) -- SetRandomOutfitVariation
    SetEntityInvincible(ped, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    SetPedCanRagdoll(ped, false)
    SetPedKeepTask(ped, true)
end

local function stillNeeded()
    if not active then return false end
    if not DoesEntityExist(doctor) or not DoesEntityExist(horse) then return false end
    return true
end

-- doctor leaves the player and despawns once far enough away
local function rideAway()
    if not doctor or not DoesEntityExist(doctor) then cleanup() return end

    ClearPedTasks(doctor)
    if horse and DoesEntityExist(horse) and not IsPedOnMount(doctor) then
        Citizen.InvokeNative(0x92DB0739813C5186, doctor, horse, -1, -1, 2.0, 1, 0, 0) -- TaskMountAnimal
        local timeout = GetGameTimer() + 15000
        while not IsPedOnMount(doctor) and GetGameTimer() < timeout do Wait(250) end
        if not IsPedOnMount(doctor) then
            Citizen.InvokeNative(0x028F76B6E78246EB, doctor, horse, -1, true) -- SetPedOntoMount
        end
    end

    local pCoords = GetEntityCoords(cache.ped)
    local dCoords = GetEntityCoords(doctor)
    local dir = dCoords - pCoords
    if #dir < 0.1 then dir = vector3(1.0, 0.0, 0.0) end
    dir = dir / #dir
    local target = pCoords + dir * (Config.AutoMedic.DespawnDistance + 50.0)

    TaskGoToCoordAnyMeans(doctor, target.x, target.y, target.z, Config.AutoMedic.RideSpeed, 0, false, 786603, 0xbf800000)

    local timeout = GetGameTimer() + Config.AutoMedic.LeaveTimeout * 1000
    while DoesEntityExist(doctor) do
        if #(GetEntityCoords(doctor) - GetEntityCoords(cache.ped)) > Config.AutoMedic.DespawnDistance then break end
        if GetGameTimer() > timeout then break end
        Wait(1000)
    end
    debug('doctor despawned')
    cleanup()
end

---------------------------------
-- main flow
---------------------------------
RegisterNetEvent('rsg-medic:automedic:client:callDoctor', function()
    if active then notify(locale('am_cl_already_active'), 'error') return end
    if not isPlayerDead() then
        notify(locale('am_cl_not_dead'), 'error')
        report('not_dead')
        TriggerServerEvent('rsg-medic:automedic:server:finished')
        return
    end
    active = true
    status('dispatched')

    local playerPed = cache.ped
    local pCoords = GetEntityCoords(playerPed)
    local spawn = getSpawnPoint(pCoords)
    local doctorHash = loadModel(Config.AutoMedic.DoctorModel)
    local horseHash = loadModel(Config.AutoMedic.HorseModel)

    if not spawn or not doctorHash or not horseHash then
        notify(locale('am_cl_spawn_failed'), 'error')
        status('failed')
        report('spawn_failed')
        cleanup()
        return
    end

    local heading = GetHeadingFromVector_2d(pCoords.x - spawn.x, pCoords.y - spawn.y)
    horse = CreatePed(horseHash, spawn.x, spawn.y, spawn.z, heading, true, true, false, false)
    doctor = CreatePed(doctorHash, spawn.x, spawn.y, spawn.z + 1.0, heading, true, true, false, false)
    SetModelAsNoLongerNeeded(doctorHash)
    SetModelAsNoLongerNeeded(horseHash)

    if not DoesEntityExist(horse) or not DoesEntityExist(doctor) then
        notify(locale('am_cl_spawn_failed'), 'error')
        status('failed')
        report('spawn_failed')
        cleanup()
        return
    end

    setupPed(horse)
    setupPed(doctor)
    Citizen.InvokeNative(0xD3A7B003ED343FD9, horse, 0x20359E53, true, true, true) -- saddle
    Citizen.InvokeNative(0x028F76B6E78246EB, doctor, horse, -1, true)             -- SetPedOntoMount

    if Config.AutoMedic.ShowBlip then
        blip = Citizen.InvokeNative(0x23F74C2FDA6E7C61, 1664425300, doctor) -- BlipAddForEntity
        SetBlipSprite(blip, Config.AutoMedic.BlipSprite, true)
        SetBlipName(blip, locale('am_cl_blip_name'))
    end

    notify(locale('am_cl_on_way'), 'info')
    report('spawned')
    debug(('doctor spawned at %.1f %.1f %.1f'):format(spawn.x, spawn.y, spawn.z))

    ---------------------------------
    -- ride to player
    ---------------------------------
    local deadline = GetGameTimer() + Config.AutoMedic.ArrivalTimeout * 1000
    local lastTask = 0
    local startDist = math.max(1.0, #(GetEntityCoords(doctor) - pCoords) - Config.AutoMedic.DismountDistance)
    while stillNeeded() do
        if not isPlayerDead() then notify(locale('am_cl_cancelled'), 'info') status('cancelled') report('cancelled') rideAway() return end

        pCoords = GetEntityCoords(playerPed)
        local dist = #(GetEntityCoords(doctor) - pCoords)
        if dist <= Config.AutoMedic.DismountDistance then break end
        status('riding', { distance = math.floor(dist), progress = math.max(0, math.min(1, 1 - (dist - Config.AutoMedic.DismountDistance) / startDist)) })

        if GetGameTimer() > deadline then
            -- stuck: warp the doctor closer and continue
            local warp = getSpawnPoint(pCoords) or pCoords
            local dirV = warp - pCoords
            if #dirV > 0.1 then warp = pCoords + (dirV / #dirV) * (Config.AutoMedic.DismountDistance + 10.0) end
            local ok, gz = GetGroundZFor_3dCoord(warp.x, warp.y, pCoords.z + 10.0, false)
            SetEntityCoords(horse, warp.x, warp.y, ok and gz or pCoords.z, false, false, false, false)
            deadline = GetGameTimer() + 20000
            lastTask = 0
        end

        -- re-issue task every few seconds in case the player's body moved
        if GetGameTimer() - lastTask > 5000 then
            TaskGoToCoordAnyMeans(doctor, pCoords.x, pCoords.y, pCoords.z, Config.AutoMedic.RideSpeed, 0, false, 786603, 0xbf800000)
            lastTask = GetGameTimer()
        end
        Wait(500)
    end
    if not stillNeeded() then cleanup() return end

    ---------------------------------
    -- dismount
    ---------------------------------
    status('arrived')
    ClearPedTasks(doctor)
    Citizen.InvokeNative(0x48E92D3DDE23C23A, doctor, 0, 0, 0, 0, 0) -- TaskDismountAnimal
    local timeout = GetGameTimer() + 8000
    while IsPedOnMount(doctor) and GetGameTimer() < timeout do Wait(200) end
    if IsPedOnMount(doctor) then
        Citizen.InvokeNative(0x5337B721C51883A9, doctor, false, false) -- RemovePedFromMount
    end
    notify(locale('am_cl_arrived'), 'info')
    report('arrived')

    ---------------------------------
    -- walk to player
    ---------------------------------
    status('walking')
    TaskGoToEntity(doctor, playerPed, -1, Config.AutoMedic.ReviveDistance, 1.0, 0, 0)
    timeout = GetGameTimer() + 20000
    while stillNeeded() do
        if not isPlayerDead() then notify(locale('am_cl_cancelled'), 'info') status('cancelled') report('cancelled') rideAway() return end
        if #(GetEntityCoords(doctor) - GetEntityCoords(playerPed)) <= Config.AutoMedic.ReviveDistance + 0.5 then break end
        if GetGameTimer() > timeout then
            local pc = GetOffsetFromEntityInWorldCoords(playerPed, 0.0, Config.AutoMedic.ReviveDistance, 0.0)
            SetEntityCoords(doctor, pc.x, pc.y, pc.z, false, false, false, false)
            break
        end
        Wait(250)
    end
    if not stillNeeded() then cleanup() return end

    ---------------------------------
    -- treat player
    ---------------------------------
    ClearPedTasks(doctor)
    TaskTurnPedToFaceEntity(doctor, playerPed, 1500)
    Wait(1500)
    TaskStartScenarioInPlace(doctor, joaat('WORLD_HUMAN_CROUCH_INSPECT'), -1, true, false, false, false)
    notify(locale('am_cl_treating'), 'info')

    local finish = GetGameTimer() + Config.AutoMedic.ReviveTime
    while GetGameTimer() < finish do
        status('treating', { progress = 1 - (finish - GetGameTimer()) / Config.AutoMedic.ReviveTime })
        if not stillNeeded() then cleanup() return end
        if not isPlayerDead() then notify(locale('am_cl_cancelled'), 'info') status('cancelled') report('cancelled') rideAway() return end
        Wait(250)
    end

    status('treating', { progress = 1 })
    TriggerServerEvent('rsg-medic:automedic:server:treated')
    Wait(3000) -- revive fade

    ---------------------------------
    -- leave
    ---------------------------------
    rideAway()
end)

---------------------------------
-- cleanup
---------------------------------
AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    cleanup()
end)

AddEventHandler('RSGCore:Client:OnPlayerUnload', function()
    cleanup()
end)
