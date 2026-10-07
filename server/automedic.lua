---------------------------------------------------------------
-- Auto medic (NPC doctor) - merged from rex-automedic
---------------------------------------------------------------
if not Config.AutoMedic.Enabled then return end
local RSGCore = exports['rsg-core']:GetCoreObject()

local cooldowns = {}
local activeCalls = {}
local validStages = { spawned = true, arrived = true, cancelled = true, spawn_failed = true, not_dead = true }

local function notify(src, desc, ntype)
    TriggerClientEvent('ox_lib:notify', src, { title = locale('am_sv_title'), description = desc, type = ntype or 'info', duration = 5000 })
end

local isMedicJob = {}
for _, name in ipairs(Config.MedicJobs) do isMedicJob[name] = true end

local function countMedicsOnDuty()
    local count = 0
    for _, Player in pairs(RSGCore.Functions.GetRSGPlayers()) do
        local job = Player.PlayerData.job
        if job and isMedicJob[job.name] and job.onduty then
            count = count + 1
        end
    end
    return count
end

local function isDead(Player)
    return Player and Player.PlayerData.metadata.isdead == true
end

---------------------------------
-- command
---------------------------------
RSGCore.Commands.Add(Config.AutoMedic.Command, locale('am_sv_command_help'), {}, false, function(source)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end

    if activeCalls[src] then
        notify(src, locale('am_cl_already_active'), 'error')
        return
    end

    if not isDead(Player) then
        notify(src, locale('am_cl_not_dead'), 'error')
        SendAutomedicLog('not_dead', src)
        return
    end

    local now = os.time()
    if cooldowns[src] and cooldowns[src] > now then
        notify(src, locale('am_sv_cooldown'):format(cooldowns[src] - now), 'error')
        SendAutomedicLog('cooldown', src, { { name = locale('am_wh_field_remaining'), value = locale('am_wh_seconds'):format(cooldowns[src] - now) } })
        return
    end

    if Config.AutoMedic.MaxMedicsOnDuty >= 0 and countMedicsOnDuty() > Config.AutoMedic.MaxMedicsOnDuty then
        notify(src, locale('am_sv_medics_online'), 'error')
        SendAutomedicLog('medics_online', src, { { name = locale('am_wh_field_medics'), value = countMedicsOnDuty() } })
        return
    end

    if Config.AutoMedic.Cost > 0 then
        if Player.PlayerData.money[Config.AutoMedic.MoneyType] < Config.AutoMedic.Cost then
            notify(src, locale('am_sv_no_money'):format(Config.AutoMedic.Cost), 'error')
            SendAutomedicLog('no_money', src, {
                { name = locale('am_wh_field_cost'), value = '$' .. Config.AutoMedic.Cost },
                { name = locale('am_wh_field_balance'), value = '$' .. Player.PlayerData.money[Config.AutoMedic.MoneyType] },
            })
            return
        end
    end

    activeCalls[src] = { started = os.time() }
    SendAutomedicLog('called', src, {
        { name = locale('am_wh_field_cost'), value = '$' .. Config.AutoMedic.Cost .. ' (' .. Config.AutoMedic.MoneyType .. ')' },
        { name = locale('am_wh_field_medics'), value = countMedicsOnDuty() },
    })
    TriggerClientEvent('rsg-medic:automedic:client:callDoctor', src)
end)

---------------------------------
-- doctor finished treating: take payment
---------------------------------
RegisterNetEvent('rsg-medic:automedic:server:treated', function()
    local src = source
    local call = activeCalls[src]
    if not call then
        SendAutomedicLog('exploit', src, { { name = locale('am_wh_field_event'), value = 'rsg-medic:automedic:server:treated' } }, locale('am_wh_exploit_desc'))
        return
    end
    if call.treated then return end
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player or not isDead(Player) then return end
    -- doctor must have had time to ride in and treat
    if os.time() - call.started < math.floor(Config.AutoMedic.ReviveTime / 1000) then
        SendAutomedicLog('exploit', src, { { name = locale('am_wh_field_event'), value = 'rsg-medic:automedic:server:treated (too fast)' } }, locale('am_wh_exploit_desc'))
        return
    end
    call.treated = true
    TriggerEvent('rsg-medic:server:reviveInPlace', src)
    notify(src, locale('am_cl_revived'), 'success')
    cooldowns[src] = os.time() + Config.AutoMedic.Cooldown
    local paid = locale('am_wh_free')
    if Config.AutoMedic.Cost > 0 then
        if Player.Functions.RemoveMoney(Config.AutoMedic.MoneyType, Config.AutoMedic.Cost, 'automedic-revive') then
            notify(src, locale('am_sv_paid'):format(Config.AutoMedic.Cost), 'success')
            paid = '$' .. Config.AutoMedic.Cost .. ' (' .. Config.AutoMedic.MoneyType .. ')'
        else
            paid = locale('am_wh_failed')
            SendAutomedicLog('payment_failed', src, { { name = locale('am_wh_field_cost'), value = '$' .. Config.AutoMedic.Cost } })
        end
    end
    SendAutomedicLog('revived', src, {
        { name = locale('am_wh_field_paid'), value = paid },
        { name = locale('am_wh_field_response'), value = locale('am_wh_seconds'):format(os.time() - call.started) },
    })
end)

RegisterNetEvent('rsg-medic:automedic:server:stage', function(stage)
    local src = source
    if type(stage) ~= 'string' or not validStages[stage] then return end
    if not activeCalls[src] then return end
    local call = activeCalls[src]
    SendAutomedicLog(stage, src, { { name = locale('am_wh_field_elapsed'), value = locale('am_wh_seconds'):format(os.time() - call.started) } })
end)

RegisterNetEvent('rsg-medic:automedic:server:finished', function()
    local src = source
    local call = activeCalls[src]
    if call then
        SendAutomedicLog('finished', src, {
            { name = locale('am_wh_field_total'), value = locale('am_wh_seconds'):format(os.time() - call.started) },
            { name = locale('am_wh_field_revived'), value = call.treated and locale('am_wh_yes') or locale('am_wh_no') },
        })
    end
    activeCalls[src] = nil
end)

AddEventHandler('playerDropped', function()
    activeCalls[source] = nil
    cooldowns[source] = nil
end)
