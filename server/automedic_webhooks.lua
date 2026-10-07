---------------------------------------------------------------
-- Discord webhook system for the rsg-medic auto medic
---------------------------------------------------------------
local RSGCore = exports['rsg-core']:GetCoreObject()
local W = SvConfig.Webhooks
local queue, sending = {}, false

local function getUrl(channel)
    local url = W.Urls[channel]
    if not url or url == '' then url = W.Urls.default end
    if not url or url == '' or url:find('CHANGE_ME') then return nil end
    return url
end

local function processQueue()
    if sending then return end
    sending = true
    CreateThread(function()
        while #queue > 0 do
            local item = table.remove(queue, 1)
            PerformHttpRequest(item.url, function(code, body)
                if code == 429 then
                    table.insert(queue, 1, item) -- rate limited, retry
                    Wait(5000)
                elseif code ~= 200 and code ~= 204 and Config.AutoMedic.Debug then
                    print(('[rsg-medic:automedic] webhook error %s: %s'):format(code, body or ''))
                end
            end, 'POST', json.encode(item.payload), { ['Content-Type'] = 'application/json' })
            Wait(W.RateLimitMs)
        end
        sending = false
    end)
end

local function getIdentifier(src, prefix)
    for _, id in ipairs(GetPlayerIdentifiers(src)) do
        if id:sub(1, #prefix) == prefix then return id end
    end
    return 'n/a'
end

local function buildPlayerFields(src)
    local fields = {}
    local Player = RSGCore.Functions.GetPlayer(src)
    local charName = locale('am_wh_unknown')
    local citizenid = 'n/a'
    if Player then
        local ci = Player.PlayerData.charinfo or {}
        charName = ((ci.firstname or '') .. ' ' .. (ci.lastname or '')):gsub('^%s+', '')
        citizenid = Player.PlayerData.citizenid
    end
    fields[#fields + 1] = { name = locale('am_wh_field_player'), value = locale('am_wh_player_value'):format(GetPlayerName(src) or locale('am_wh_unknown'), src), inline = true }
    fields[#fields + 1] = { name = locale('am_wh_field_character'), value = charName ~= '' and charName or locale('am_wh_unknown'), inline = true }

    if W.ShowIdentifiers then
        local discord = getIdentifier(src, 'discord:')
        fields[#fields + 1] = { name = locale('am_wh_field_citizenid'), value = citizenid, inline = true }
        fields[#fields + 1] = { name = locale('am_wh_field_license'), value = getIdentifier(src, 'license:'), inline = false }
        fields[#fields + 1] = { name = locale('am_wh_field_discord'), value = discord ~= 'n/a' and ('<@%s>'):format(discord:gsub('discord:', '')) or 'n/a', inline = true }
    end

    if W.ShowCoords then
        local ped = GetPlayerPed(src)
        if ped and ped ~= 0 then
            local c = GetEntityCoords(ped)
            fields[#fields + 1] = { name = locale('am_wh_field_coords'), value = ('vector3(%.2f, %.2f, %.2f)'):format(c.x, c.y, c.z), inline = false }
        end
    end
    return fields
end

---@param event string key in SvConfig.Webhooks.Events
---@param src number player source
---@param extra table|nil list of extra { name, value, inline } fields
---@param description string|nil
function SendAutomedicLog(event, src, extra, description)
    if not W.Enabled then return end
    local cfg = W.Events[event]
    if not cfg or not cfg.enabled then return end
    local url = getUrl(cfg.channel)
    if not url then return end

    local fields = buildPlayerFields(src)
    if extra then
        for _, f in ipairs(extra) do
            fields[#fields + 1] = { name = f.name, value = tostring(f.value), inline = f.inline ~= false }
        end
    end

    queue[#queue + 1] = {
        url = url,
        payload = {
            username = W.BotName,
            avatar_url = W.AvatarUrl ~= '' and W.AvatarUrl or nil,
            embeds = { {
                title = locale('am_wh_title_' .. event),
                description = description,
                color = cfg.color,
                fields = fields,
                footer = { text = ('%s • %s'):format(W.ServerName, W.FooterText) },
                timestamp = os.date('!%Y-%m-%dT%H:%M:%SZ'),
            } },
        },
    }
    processQueue()
end

exports('SendAutomedicLog', SendAutomedicLog)
