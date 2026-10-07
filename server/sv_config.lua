---------------------------------------------------------------
-- SERVER ONLY webhook config (never loaded on clients, so your
-- webhook URLs cannot be read by players)
---------------------------------------------------------------
SvConfig = {}

SvConfig.Webhooks = {
    Enabled     = true,
    BotName     = 'Auto Medic',
    AvatarUrl   = '',          -- optional image url for the bot avatar
    FooterText  = 'rsg-medic automedic',
    ServerName  = 'My RedM Server',
    ShowCoords  = true,
    ShowIdentifiers = true,    -- license / discord / citizenid
    RateLimitMs = 1200,        -- delay between queued sends (Discord limit safety)

    -- one url can be reused for every channel, or split per channel
    Urls = {
        default = 'https://discord.com/api/webhooks/CHANGE_ME',
        revive  = '',          -- blank = falls back to default
        denied  = '',
        admin   = '',
    },

    -- toggle each log type and set the channel + embed colour (decimal)
    -- embed titles/labels are translated in locales/*.json (wh_title_<event>)
    Events = {
        called       = { enabled = true,  channel = 'default', color = 3447003 },
        spawned      = { enabled = false, channel = 'default', color = 10181046 },
        arrived      = { enabled = false, channel = 'default', color = 15105570 },
        revived      = { enabled = true,  channel = 'revive',  color = 3066993 },
        cancelled    = { enabled = true,  channel = 'default', color = 9807270 },
        spawn_failed = { enabled = true,  channel = 'admin',   color = 15158332 },
        not_dead     = { enabled = true,  channel = 'denied',  color = 15844367 },
        cooldown     = { enabled = true,  channel = 'denied',  color = 15844367 },
        medics_online= { enabled = true,  channel = 'denied',  color = 15844367 },
        no_money     = { enabled = true,  channel = 'denied',  color = 15844367 },
        payment_failed={ enabled = true,  channel = 'admin',   color = 15158332 },
        exploit      = { enabled = true,  channel = 'admin',   color = 10038562 },
        finished     = { enabled = false, channel = 'default', color = 9807270 },
    },
}
