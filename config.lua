Config = {}

Config.Debug                    = false

-- Settings
Config.JobRequired              = 'medic'
Config.StorageMaxWeight         = 4000000
Config.StorageMaxSlots          = 48
Config.DeathTimer               = 300 -- 300 = 5 mins / testing 60 = 1 min
Config.WipeInventoryOnRespawn   = false
Config.WipeCashOnRespawn        = false
Config.MaxHealth                = 600
Config.MedicReviveTime          = 5000
Config.MedicTreatTime           = 5000
Config.AddGPSRoute              = true
Config.MedicCallDelay           = 60 -- delay in seconds before calling medic again

-- Blip Settings
Config.Blip =
{
    blipName                    = 'Medic', -- Config.Blip.blipName
    blipSprite                  = 'blip_shop_doctor', -- Config.Blip.blipSprite
    blipScale                   = 0.2 -- Config.Blip.blipScale
}

-- Prompt Locations
Config.MedicJobLocations =
{
    {name = 'Valentine Medic', prompt = 'valmedic', coords = vector3(-287.59, 811.28, 119.39 -0.8), showblip = true} -- Valentine
}

-- Respawn Locations
Config.RespawnLocations =
{
    [1] = {coords = vector4(-242.69, 796.27, 121.16, 110.18)}, -- Valentine
    [2] = {coords = vector4(-733.28, -1242.97, 44.73, 87.64)}, -- Blackwater
    [3] = {coords = vector4(-1801.98, -366.95, 161.66, 236.04)}, -- Strawberry
    [4] = {coords = vector4(-3613.85, -2640.1, -11.73, 47.92)}, -- Armadillo
    [5] = {coords = vector4(-5436.5, -2930.96, 0.69, 182.25)}, -- Tumbleweed
    [6] = {coords = vector4(2725.33, -1067.42, 47.4, 168.42)}, -- Staint Denis
    [7] = {coords = vector4(1291.85, -1236.22, 80.93, 210.67)}, -- Rhodes
    [8] = {coords = vector4(3033.01, 433.82, 63.81, 65.9)}, -- Van Horn
    [9] = {coords = vector4(3016.71, 1345.64, 42.69, 67.85)} -- Annesburg
}