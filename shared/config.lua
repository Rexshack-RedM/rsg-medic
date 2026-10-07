Config = {}

---------------------------------
-- jobs
---------------------------------
Config.MedicJobs = { 'medic' }   -- job names treated as medics
Config.RequireDuty = true        -- medics must be on duty to use field actions / supplies

---------------------------------
-- death
---------------------------------
Config.DeathTimer      = 300     -- seconds before a downed player may respawn at the doctor
Config.RespawnFee      = 25      -- charged on hospital respawn (cash, then bank); 0 = free
Config.AlertCooldown   = 60      -- seconds between "call for a medic" alerts
Config.AlertBlipTime   = 120     -- seconds an alert blip stays on medics' maps

-- keys (RedM control hashes)
Config.DeathCam = {
    Enabled     = true,  -- let dead players look around their body with the mouse
    Distance    = 3.5,   -- starting distance from the body
    MinDistance = 1.5,   -- closest zoom (scroll up)
    MaxDistance = 8.0,   -- furthest zoom (scroll down)
    Sensitivity = 6.0,   -- mouse look speed
}

Config.Keys = {
    respawn = 0xCEFD9220, -- E
    alert   = 0x760A9C6F, -- G
    prompt  = 0xCEFD9220, -- E (hold) at doctor locations
}

---------------------------------
-- medic actions
---------------------------------
Config.ActionDistance = 3.0      -- metres between medic and patient
Config.FieldRange     = 10.0     -- metres to list nearby patients in the field menu
Config.UiCommand      = 'medicui' -- toggles UI move mode (drag panels by their header, double-click to reset)
Config.FieldCommand   = 'medic'  -- opens the field menu for on-duty medics

Config.Revive = {
    duration = 10000,            -- ms
    item     = 'medicalbag',     -- required (not consumed); nil = none
    reward   = 10,               -- cash paid to the medic; 0 = none
}

Config.Treat = {
    duration = 6000,
    item     = 'bandage',        -- consumed; nil = none
    reward   = 3,
}

Config.Bandage = {               -- self-use bandage item for anyone
    item     = 'bandage',
    duration = 4000,
    heal     = 35,               -- health points restored
}

---------------------------------
-- supplies sold at the doctor (medics only)
---------------------------------
Config.Supplies = {
    { item = 'bandage',    price = 1 },
    { item = 'medicalbag', price = 15 },
}
Config.MaxBuyAmount = 50

---------------------------------
-- stash / boss menu
---------------------------------
Config.Stash = { slots = 50, maxweight = 400000 }
Config.BossMenuEvent = 'rsg-bossmenu:client:mainmenu' -- client event opened for boss grades; nil to hide

---------------------------------
-- blips
---------------------------------
Config.BlipSprite      = `blip_shop_doctor`
Config.AlertBlipSprite = `blip_ambient_companion`

---------------------------------
-- doctor locations (verify coords on your map)
-- point = medic menu prompt, spawn = hospital respawn position (x, y, z, heading)
---------------------------------
Config.Locations = {
    { id = 'valentine',  label = 'Valentine Doctor',  point = vec3(-288.82, 808.44, 119.44),  spawn = vec4(-286.83, 806.38, 119.39, 280.0) },
    { id = 'saintdenis', label = 'Saint Denis Doctor', point = vec3(2721.29, -1233.60, 50.37), spawn = vec4(2725.10, -1230.73, 50.37, 90.0) },
    { id = 'strawberry', label = 'Strawberry Doctor', point = vec3(-1803.33, -432.35, 158.83), spawn = vec4(-1806.50, -430.50, 158.83, 330.0) },
}

---------------------------------
-- auto medic (NPC doctor rides in and revives a downed player)
-- discord webhooks for it are in server/sv_config.lua
---------------------------------
Config.AutoMedic = {
    Enabled          = true,
    Debug            = false,
    Command          = 'automedic',
    Cost             = 50,        -- fee taken after a successful revive (0 = free)
    MoneyType        = 'cash',    -- 'cash' | 'bank'
    Cooldown         = 300,       -- seconds between uses per player
    MaxMedicsOnDuty  = 0,         -- only works if on-duty medics (Config.MedicJobs) <= this (-1 = always)

    DoctorModel      = 'u_m_m_rhddoctor_01',
    HorseModel       = 'a_c_horse_kentuckysaddle_black',

    SpawnDistance    = 80.0,      -- how far away the doctor spawns
    DismountDistance = 8.0,       -- distance from player where doctor dismounts
    ReviveDistance   = 1.5,       -- distance doctor walks to before treating
    DespawnDistance  = 120.0,     -- distance at which the leaving doctor despawns
    RideSpeed        = 3.0,       -- 1.0 walk, 2.0 trot, 3.0 gallop
    ReviveTime       = 8000,      -- ms the doctor spends treating
    ArrivalTimeout   = 90,        -- seconds before a stuck doctor is warped closer
    LeaveTimeout     = 45,        -- seconds before a leaving doctor is force despawned

    ShowBlip         = true,
    BlipSprite       = `blip_mp_travelling_saleswoman`,
}
