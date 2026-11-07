---------------------------------------------------------------
-- Auto medic (NPC doctor) - merged from rex-automedic
---------------------------------------------------------------
if not Config.AutoMedic.Enabled then return end
local RSGCore = exports['rsg-core']:GetCoreObject()

local cooldowns = {} -- [citizenid] = os.time() when the player may call again (survives relogs)
local activeCalls = {}
local validStages = { spawned = true, arrived = true, cancelled = true, spawn_failed = true, not_dead = true }

local function notify(src, desc, ntype)
    TriggerClientEvent('RSGCore:Client:Notify', src, { title = locale('am_sv_title'), description = desc, type = ntype or 'inform', duration = 5000 })
end

local isDead = RSGMedic.IsDead
local function countMedicsOnDuty() return #RSGMedic.GetOnDutyMedics() end

-- a call older than this is treated as stale (client crashed / never reported finished)
local CALL_TTL = Config.AutoMedic.ArrivalTimeout + Config.AutoMedic.LeaveTimeout + math.ceil(Config.AutoMedic.ReviveTime / 1000) + 90

---------------------------------
-- command
---------------------------------
RSGCore.Commands.Add(Config.AutoMedic.Command, locale('am_sv_command_help'), {}, false, function(source)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end

    if activeCalls[src] and os.time() - activeCalls[src].started > CALL_TTL then activeCalls[src] = nil end
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
    local cd = cooldowns[Player.PlayerData.citizenid]
    if cd and cd > now then
        notify(src, locale('am_sv_cooldown', cd - now), 'error')
        SendAutomedicLog('cooldown', src, { { name = locale('am_wh_field_remaining'), value = locale('am_wh_seconds', cd - now) } })
        return
    end

    local medics = countMedicsOnDuty()
    if Config.AutoMedic.MaxMedicsOnDuty >= 0 and medics > Config.AutoMedic.MaxMedicsOnDuty then
        notify(src, locale('am_sv_medics_online'), 'error')
        SendAutomedicLog('medics_online', src, { { name = locale('am_wh_field_medics'), value = medics } })
        return
    end

    if Config.AutoMedic.Cost > 0 then
        local balance = Player.Functions.GetMoney(Config.AutoMedic.MoneyType) or 0
        if balance < Config.AutoMedic.Cost then
            notify(src, locale('am_sv_no_money', Config.AutoMedic.Cost), 'error')
            SendAutomedicLog('no_money', src, {
                { name = locale('am_wh_field_cost'), value = '$' .. Config.AutoMedic.Cost },
                { name = locale('am_wh_field_balance'), value = '$' .. balance },
            })
            return
        end
    end

    activeCalls[src] = { started = os.time() }
    SendAutomedicLog('called', src, {
        { name = locale('am_wh_field_cost'), value = '$' .. Config.AutoMedic.Cost .. ' (' .. Config.AutoMedic.MoneyType .. ')' },
        { name = locale('am_wh_field_medics'), value = medics },
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
    cooldowns[Player.PlayerData.citizenid] = os.time() + Config.AutoMedic.Cooldown
    local paid = locale('am_wh_free')
    if Config.AutoMedic.Cost > 0 then
        if Player.Functions.RemoveMoney(Config.AutoMedic.MoneyType, Config.AutoMedic.Cost, 'automedic-revive') then
            notify(src, locale('am_sv_paid', Config.AutoMedic.Cost), 'success')
            paid = '$' .. Config.AutoMedic.Cost .. ' (' .. Config.AutoMedic.MoneyType .. ')'
        else
            paid = locale('am_wh_failed')
            SendAutomedicLog('payment_failed', src, { { name = locale('am_wh_field_cost'), value = '$' .. Config.AutoMedic.Cost } })
        end
    end
    SendAutomedicLog('revived', src, {
        { name = locale('am_wh_field_paid'), value = paid },
        { name = locale('am_wh_field_response'), value = locale('am_wh_seconds', os.time() - call.started) },
    })
end)

RegisterNetEvent('rsg-medic:automedic:server:stage', function(stage)
    local src = source
    if type(stage) ~= 'string' or not validStages[stage] then return end
    if not activeCalls[src] then return end
    local call = activeCalls[src]
    SendAutomedicLog(stage, src, { { name = locale('am_wh_field_elapsed'), value = locale('am_wh_seconds', os.time() - call.started) } })
end)

RegisterNetEvent('rsg-medic:automedic:server:finished', function()
    local src = source
    local call = activeCalls[src]
    if call then
        SendAutomedicLog('finished', src, {
            { name = locale('am_wh_field_total'), value = locale('am_wh_seconds', os.time() - call.started) },
            { name = locale('am_wh_field_revived'), value = call.treated and locale('am_wh_yes') or locale('am_wh_no') },
        })
    end
    activeCalls[src] = nil
end)

AddEventHandler('playerDropped', function()
    activeCalls[source] = nil -- cooldowns are kept so relogging can't skip them
end)
